import { serve } from 'https://deno.land/std@0.199.0/http/server.ts';

const PROJECT_URL = Deno.env.get('PROJECT_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY')!;

serve(async (req) => {
  try {
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ ok: false, error: 'method_not_allowed' }),
        { status: 405 },
      );
    }

    const payload = await req.json();
    const email = payload.email?.toString().trim();
    const code = payload.code?.toString().trim();
    const purpose = payload.purpose?.toString() || 'verification';
    if (!email || !code) {
      return new Response(
        JSON.stringify({ ok: false, error: 'missing_fields' }),
        { status: 400 },
      );
    }

    const query =
      `${PROJECT_URL}/rest/v1/email_otps?email=eq.${encodeURIComponent(email)}` +
      `&code=eq.${encodeURIComponent(code)}` +
      `&purpose=eq.${encodeURIComponent(purpose)}` +
      `&expires_at=gt.${encodeURIComponent(new Date().toISOString())}&select=id`;
    const response = await fetch(query, {
      headers: {
        apikey: SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      },
    });

    if (!response.ok) {
      console.error('OTP query failed:', response.status);
      return new Response(
        JSON.stringify({ ok: false, error: 'otp_query_failed' }),
        { status: 500 },
      );
    }

    const rows = await response.json();
    if (!Array.isArray(rows) || rows.length === 0) {
      return new Response(
        JSON.stringify({ ok: false, ok_code: false }),
        { status: 200 },
      );
    }

    // Signup and reset codes are consumed by their write operation so the
    // verification step cannot be replayed or separated from that operation.
    if (purpose !== 'password_reset' && purpose !== 'verification') {
      const deleteResponse = await fetch(
        `${PROJECT_URL}/rest/v1/email_otps?id=eq.${encodeURIComponent(rows[0].id)}`,
        {
          method: 'DELETE',
          headers: {
            apikey: SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
          },
        },
      );
      if (!deleteResponse.ok) {
        console.error('OTP deletion failed:', deleteResponse.status);
        return new Response(
          JSON.stringify({ ok: false, error: 'otp_consume_failed' }),
          { status: 500 },
        );
      }
    }

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (error) {
    console.error(error);
    return new Response(
      JSON.stringify({ ok: false, error: 'exception' }),
      { status: 500 },
    );
  }
});
