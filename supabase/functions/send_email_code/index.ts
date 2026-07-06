import { serve } from 'https://deno.land/std@0.199.0/http/server.ts';

const PROJECT_URL = Deno.env.get('PROJECT_URL');
const SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY');
const SMTP_HOST = Deno.env.get('SMTP_HOST') || 'smtp.gmail.com';
const SMTP_PORT = Number(Deno.env.get('SMTP_PORT') || '465');
const SMTP_USER = Deno.env.get('SMTP_USER');
const SMTP_PASS = Deno.env.get('SMTP_PASS');
const SMTP_FROM = Deno.env.get('SMTP_FROM') || SMTP_USER;

function parseFromEmail(rawFrom: string): string {
  const angleMatch = rawFrom.match(/<([^>]+)>/);
  if (angleMatch) {
    return angleMatch[1].trim();
  }
  return rawFrom.trim();
}

function generateCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

async function readResponse(conn: Deno.Reader): Promise<string> {
  const decoder = new TextDecoder();
  const buffer = new Uint8Array(4096);
  let response = '';

  while (true) {
    const bytesRead = await conn.read(buffer);
    if (bytesRead === null) break;
    response += decoder.decode(buffer.subarray(0, bytesRead));

    const lines = response.split('\r\n');
    if (lines.length >= 2) {
      const lastLine = lines[lines.length - 2];
      if (/^[0-9]{3} /.test(lastLine)) {
        return response;
      }
    }
  }

  return response;
}

async function sendSmtpMail(headerFrom: string, mailFrom: string, to: string, subject: string, body: string) {
  // Support immediate TLS (port 465) and STARTTLS upgrade (port 587)
  let conn: Deno.Conn | null = null;
  try {
    if (SMTP_PORT === 587) {
      conn = await Deno.connect({ hostname: SMTP_HOST, port: SMTP_PORT });
    } else {
      conn = await Deno.connectTls({ hostname: SMTP_HOST, port: SMTP_PORT });
    }

    let response = await readResponse(conn);
    if (!response.startsWith('220')) {
      throw new Error(`SMTP server rejected connection: ${response}`);
    }

    const encoder = new TextEncoder();
    const writeLine = async (line: string) => {
      await conn!.write(encoder.encode(`${line}\r\n`));
      return await readResponse(conn!);
    };

    // If we connected plain (587) we must issue EHLO, STARTTLS, then upgrade
    response = await writeLine('EHLO localhost');
    if (!response.startsWith('250')) {
      // Some servers respond with multiple 250- lines; accept those that start with 250 or 220 after EHLO
      // We'll continue and attempt STARTTLS if port 587
      if (SMTP_PORT !== 587) {
        throw new Error(`SMTP EHLO failed: ${response}`);
      }
    }

    if (SMTP_PORT === 587) {
      response = await writeLine('STARTTLS');
      if (!response.startsWith('220')) {
        throw new Error(`SMTP STARTTLS failed: ${response}`);
      }

      // Upgrade the plain TCP connection to TLS
      conn = await Deno.startTls(conn!, { hostname: SMTP_HOST });

      // After TLS upgrade, re-run EHLO to reset capabilities
      response = await writeLine('EHLO localhost');
      if (!response.startsWith('250')) {
        throw new Error(`SMTP EHLO after STARTTLS failed: ${response}`);
      }
    }

    // Authenticate
    response = await writeLine('AUTH LOGIN');
    if (!response.startsWith('334')) {
      throw new Error(`SMTP AUTH LOGIN failed: ${response}`);
    }

    const authUser = btoa(SMTP_USER ?? '');
    const authPass = btoa(SMTP_PASS ?? '');
    response = await writeLine(authUser);
    if (!response.startsWith('334')) {
      throw new Error(`SMTP username rejected: ${response}`);
    }

    response = await writeLine(authPass);
    if (!response.startsWith('235')) {
      throw new Error(`SMTP password rejected: ${response}`);
    }

    response = await writeLine(`MAIL FROM:<${mailFrom}>`);
    if (!response.startsWith('250')) {
      throw new Error(`SMTP MAIL FROM failed: ${response}`);
    }

    response = await writeLine(`RCPT TO:<${to}>`);
    if (!response.startsWith('250') && !response.startsWith('251')) {
      throw new Error(`SMTP RCPT TO failed: ${response}`);
    }

    response = await writeLine('DATA');
    if (!response.startsWith('354')) {
      throw new Error(`SMTP DATA command failed: ${response}`);
    }

    const message = `From: ${headerFrom}\r\nTo: ${to}\r\nSubject: ${subject}\r\nContent-Type: text/plain; charset=utf-8\r\n\r\n${body}\r\n.`;
    response = await writeLine(message);
    if (!response.startsWith('250')) {
      throw new Error(`SMTP message send failed: ${response}`);
    }

    await writeLine('QUIT');
  } finally {
    try {
      conn?.close();
    } catch (_e) {
      // ignore
    }
  }
}

serve(async (req) => {
  try {
    const payload = await req.json();
    const email = payload.email?.toString().trim();
    if (!email) {
      return new Response(JSON.stringify({ ok: false, error: 'missing_email' }), { status: 400 });
    }

    if (!PROJECT_URL) {
      return new Response(
        JSON.stringify({ ok: false, error: 'missing_project_url', message: 'PROJECT_URL is not configured.' }),
        { status: 500 },
      );
    }

    if (!SERVICE_ROLE_KEY) {
      return new Response(
        JSON.stringify({ ok: false, error: 'missing_service_role_key', message: 'SERVICE_ROLE_KEY is not configured.' }),
        { status: 500 },
      );
    }

    if (!SMTP_USER || !SMTP_PASS) {
      return new Response(
        JSON.stringify({ ok: false, error: 'missing_smtp_config', message: 'SMTP_USER and SMTP_PASS are required.' }),
        { status: 500 },
      );
    }

    const code = generateCode();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

    const insertResponse = await fetch(`${PROJECT_URL}/rest/v1/email_otps`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
        Prefer: 'return=representation',
      },
      body: JSON.stringify({ email, code, expires_at: expiresAt }),
    });

    if (!insertResponse.ok) {
      const text = await insertResponse.text();
      console.error('OTP insert failed:', insertResponse.status, text);
      return new Response(JSON.stringify({ ok: false, error: 'otp_insert_failed' }), { status: 500 });
    }

    try {
      const fromEmail = parseFromEmail(SMTP_FROM ?? SMTP_USER ?? '');
      await sendSmtpMail(
        SMTP_FROM ?? fromEmail,
        fromEmail,
        email,
        'Your NUtilize verification code',
        `Your NUtilize verification code is: ${code}\n\nIt expires in 10 minutes.`,
      );
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      console.error('SMTP send failed:', message);
      return new Response(
        JSON.stringify({ ok: false, error: 'smtp_send_failed', message }),
        { status: 502 },
      );
    }

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error('Unhandled exception:', message);
    return new Response(
      JSON.stringify({ ok: false, error: 'exception', message }),
      { status: 500 },
    );
  }
});
