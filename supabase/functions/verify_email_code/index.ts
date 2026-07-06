import { serve } from 'https://deno.land/std@0.199.0/http/server.ts';

const PROJECT_URL = Deno.env.get('PROJECT_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY')!;

serve(async (req) => {
  try {
    const payload = await req.json();
    const email = payload.email?.toString().trim();
    const code = payload.code?.toString().trim();
    if (!email || !code) {
      return new Response(JSON.stringify({ ok: false, error: 'missing_fields' }), { status: 400 });
    }

    const query = `${PROJECT_URL}/rest/v1/email_otps?email=eq.${encodeURIComponent(email)}&code=eq.${encodeURIComponent(code)}&expires_at=gt.${encodeURIComponent(new Date().toISOString())}&select=*`;
    const resp = await fetch(query, {
      method: 'GET',
      headers: {
        apikey: SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      },
    });

    if (!resp.ok) {
      const text = await resp.text();
      console.error('OTP query failed:', resp.status, text);
      return new Response(JSON.stringify({ ok: false, error: 'otp_query_failed' }), { status: 500 });
    }

    const rows = await resp.json();
    if (!Array.isArray(rows) || rows.length == 0) {
      return new Response(JSON.stringify({ ok: false, ok_code: false }), { status: 200 });
    }

    const id = rows[0].id;
    await fetch(`${PROJECT_URL}/rest/v1/email_otps?id=eq.${id}`, {
      method: 'DELETE',
      headers: {
        apikey: SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      },
    });

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (error) {
    console.error(error);
    return new Response(JSON.stringify({ ok: false, error: 'exception' }), { status: 500 });
  }
});
