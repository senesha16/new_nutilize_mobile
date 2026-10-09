import { serve } from 'https://deno.land/std@0.199.0/http/server.ts';
import { hasRegistrationProfile } from '../_shared/registration_email.ts';

const PROJECT_URL = Deno.env.get('PROJECT_URL');
const SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY');
const SMTP_HOST = Deno.env.get('SMTP_HOST') || 'smtp.gmail.com';
const SMTP_PORT = Number(Deno.env.get('SMTP_PORT') || '465');
const SMTP_USER = Deno.env.get('SMTP_USER');
const SMTP_PASS = Deno.env.get('SMTP_PASS');
const SMTP_FROM_NAME = Deno.env.get('SMTP_FROM_NAME')?.trim() || '';
const SMTP_EHLO_DOMAIN = 'localhost';

function isNuRegistrationEmail(email: string): boolean {
  const domain = email.trim().toLowerCase().split('@').pop() ?? '';
  return domain === 'students.nu-lipa.edu.ph' || domain === 'nu-lipa.edu.ph';
}

function parseFromEmail(rawFrom: string): string {
  const angleMatch = rawFrom.match(/<([^>]+)>/);
  if (angleMatch) {
    return angleMatch[1].trim();
  }
  return rawFrom.trim();
}

function formatRfc5322Date(date = new Date()): string {
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const pad = (value: number) => value.toString().padStart(2, '0');
  const local = new Date(date.getTime() + 8 * 60 * 60 * 1000);
  return `${days[local.getUTCDay()]}, ${pad(local.getUTCDate())} ${months[local.getUTCMonth()]} ${local.getUTCFullYear()} ${pad(local.getUTCHours())}:${pad(local.getUTCMinutes())}:${pad(local.getUTCSeconds())} +0800`;
}

function spaceDigits(code: string): string {
  return code.split('').join(' ');
}

function buildFromHeader(fromEmail: string): string {
  if (!SMTP_FROM_NAME || /[\r\n<>]/.test(SMTP_FROM_NAME)) {
    return fromEmail;
  }
  return `${SMTP_FROM_NAME} <${fromEmail}>`;
}

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function generateCode() {
  const range = 900_000;
  const limit = Math.floor(0x1_0000_0000 / range) * range;
  const randomValue = new Uint32Array(1);

  do {
    crypto.getRandomValues(randomValue);
  } while (randomValue[0] >= limit);

  return (100_000 + (randomValue[0] % range)).toString();
}

type OtpPurpose = 'verification' | 'password_reset' | 'account_deletion';

function buildOtpEmail(purpose: OtpPurpose, code: string) {
  const content = {
    verification: {
      subject: 'NUtilize',
      line: 'Use this number to continue creating your NUtilize account.',
      notice: 'If you did not start creating an account, you can ignore this email.',
    },
    password_reset: {
      subject: 'NUtilize password',
      line: 'Use this number to reset your NUtilize password.',
      notice: 'If you did not request a password reset, you can ignore this email. Your password will not change.',
    },
    account_deletion: {
      subject: 'NUtilize account',
      line: 'Use this number to delete your NUtilize account.',
      notice: 'If you did not request account deletion, do not share this number. Your account will not be deleted unless the request is verified.',
    },
  }[purpose];

  const shown = spaceDigits(code);
  const textBody = [
    'Hi,',
    '',
    content.line,
    '',
    shown,
    '',
    'It can be used for 10 minutes.',
    '',
    content.notice,
  ].join('\r\n');

  const line = escapeHtml(content.line);
  const notice = escapeHtml(content.notice);
  const htmlBody = [
    '<html>',
    '<body style="margin:0;padding:0;background-color:#f3f5fb;">',
    '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#f3f5fb;">',
    '<tr><td align="center" style="padding:24px 12px;">',
    '<table role="presentation" width="560" cellpadding="0" cellspacing="0" border="0" style="width:560px;max-width:560px;background-color:#ffffff;">',
    '<tr><td style="padding:22px 28px;background-color:#35489a;border-bottom:4px solid #f2c94c;font-family:Arial,sans-serif;">',
    '<div style="font-size:22px;font-weight:bold;color:#ffffff;">NUtilize</div>',
    '<div style="margin-top:4px;font-size:12px;color:#ffffff;">Reservation and campus services</div>',
    '</td></tr>',
    '<tr><td style="padding:28px;font-family:Arial,sans-serif;color:#1a2254;">',
    '<p style="margin:0 0 12px;font-size:16px;">Hi,</p>',
    `<p style="margin:0 0 20px;font-size:15px;line-height:1.5;">${line}</p>`,
    '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#f3f5fb;border:1px solid #e6eaf9;">',
    '<tr><td align="center" style="padding:18px 12px;font-family:Arial,sans-serif;">',
    `<div style="font-size:28px;font-weight:bold;color:#35489a;">${escapeHtml(shown)}</div>`,
    '</td></tr></table>',
    '<p style="margin:16px 0 0;font-size:13px;line-height:1.5;color:#4053a7;">It can be used for 10 minutes.</p>',
    `<p style="margin:16px 0 0;font-size:13px;line-height:1.5;color:#4053a7;">${notice}</p>`,
    '</td></tr>',
    '<tr><td style="padding:14px 28px;background-color:#fafbfe;border-top:1px solid #e6eaf9;font-family:Arial,sans-serif;font-size:12px;color:#7a8092;">',
    'NUtilize',
    '</td></tr>',
    '</table>',
    '</td></tr>',
    '</table>',
    '</body>',
    '</html>',
  ].join('\r\n');

  const boundary = `000000000000${crypto.randomUUID().replaceAll('-', '').slice(0, 16)}`;
  const mimeBody = [
    `--${boundary}`,
    'Content-Type: text/plain; charset="UTF-8"',
    '',
    textBody,
    `--${boundary}`,
    'Content-Type: text/html; charset="UTF-8"',
    '',
    htmlBody,
    `--${boundary}--`,
  ].join('\r\n');

  return { subject: content.subject, boundary, mimeBody };
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

async function sendSmtpMail(
  headerFrom: string,
  mailFrom: string,
  to: string,
  subject: string,
  body: string,
  boundary: string,
) {
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
    const writeAll = async (data: Uint8Array) => {
      let offset = 0;
      while (offset < data.length) {
        const bytesWritten = await conn!.write(data.subarray(offset));
        if (bytesWritten === 0) {
          throw new Error('SMTP connection closed while writing data.');
        }
        offset += bytesWritten;
      }
    };
    const writeLine = async (line: string) => {
      await writeAll(encoder.encode(`${line}\r\n`));
      return await readResponse(conn!);
    };

    // If we connected plain (587) we must issue EHLO, STARTTLS, then upgrade
    response = await writeLine(`EHLO ${SMTP_EHLO_DOMAIN}`);
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
      response = await writeLine(`EHLO ${SMTP_EHLO_DOMAIN}`);
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

    const message = [
      `From: ${headerFrom}`,
      `To: ${to}`,
      `Subject: ${subject}`,
      `Date: ${formatRfc5322Date()}`,
      `Message-ID: <${crypto.randomUUID().replaceAll('-', '')}@mail.gmail.com>`,
      'MIME-Version: 1.0',
      `Content-Type: multipart/alternative; boundary="${boundary}"`,
      '',
      body,
      '.',
    ].join('\r\n');
    await writeAll(encoder.encode(`${message}\r\n`));
    response = await readResponse(conn!);
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
    const purpose = payload.purpose?.toString();
    if (!email) {
      return new Response(JSON.stringify({ ok: false, error: 'missing_email' }), { status: 400 });
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return new Response(
        JSON.stringify({ ok: false, error: 'invalid_email', message: 'Enter a valid email address.' }),
        { status: 400 },
      );
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

    if (purpose === 'password_reset' || purpose === 'account_deletion') {
      const profileResponse = await fetch(
        `${PROJECT_URL}/rest/v1/users?select=user_id&email=ilike.${encodeURIComponent(email)}&limit=1`,
        {
          headers: {
            apikey: SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
            Accept: 'application/json',
          },
        },
      );

      if (!profileResponse.ok) {
        console.error('Password reset account lookup failed:', profileResponse.status);
        return new Response(
          JSON.stringify({ ok: false, error: 'account_lookup_failed' }),
          { status: 500 },
        );
      }

      const profiles = await profileResponse.json().catch(() => null);
      if (!Array.isArray(profiles) || profiles.length === 0) {
        return new Response(
          JSON.stringify({
            ok: false,
            error: 'no_account',
            message: 'No account found, register account first',
          }),
          { status: 404 },
        );
      }
    }

    const code = generateCode();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

    const otpPurpose = purpose === 'password_reset' || purpose === 'account_deletion'
      ? purpose
      : 'verification';

    if (otpPurpose === 'verification' && !isNuRegistrationEmail(email)) {
      return new Response(
        JSON.stringify({
          ok: false,
          error: 'nu_email_required',
          message: 'only NU email allowed',
        }),
        { status: 400 },
      );
    }

    if (otpPurpose === 'verification') {
      let emailTaken: boolean;
      try {
        emailTaken = await hasRegistrationProfile(
          PROJECT_URL,
          SERVICE_ROLE_KEY,
          email,
        );
      } catch {
        return new Response(
          JSON.stringify({ ok: false, error: 'account_lookup_failed' }),
          { status: 500 },
        );
      }
      if (emailTaken) {
        return new Response(
          JSON.stringify({
            ok: false,
            error: 'email_already_taken',
            message: 'Email is already taken.',
          }),
          { status: 409 },
        );
      }
    }

    if (!SMTP_USER || !SMTP_PASS) {
      return new Response(
        JSON.stringify({ ok: false, error: 'missing_smtp_config', message: 'SMTP_USER and SMTP_PASS are required.' }),
        { status: 500 },
      );
    }

    const insertResponse = await fetch(`${PROJECT_URL}/rest/v1/email_otps`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
        Prefer: 'return=representation',
      },
      body: JSON.stringify({ email, code, purpose: otpPurpose, expires_at: expiresAt }),
    });

    if (!insertResponse.ok) {
      const text = await insertResponse.text();
      console.error('OTP insert failed:', insertResponse.status, text);
      return new Response(JSON.stringify({ ok: false, error: 'otp_insert_failed' }), { status: 500 });
    }

    try {
      const fromEmail = parseFromEmail(SMTP_USER ?? '');
      if (!fromEmail) {
        throw new Error('SMTP_USER must be the authenticated sender email address.');
      }
      const fromHeader = buildFromHeader(fromEmail);
      const mailContent = buildOtpEmail(otpPurpose, code);

      await sendSmtpMail(
        fromHeader,
        fromEmail,
        email,
        mailContent.subject,
        mailContent.mimeBody,
        mailContent.boundary,
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
