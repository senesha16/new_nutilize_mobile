import { serve } from 'https://deno.land/std@0.199.0/http/server.ts';

const PROJECT_URL = Deno.env.get('PROJECT_URL');
const SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY');

serve(async (req) => {
  try {
    const payload = await req.json();
    const email = payload.email?.toString().trim();
    const password = payload.password?.toString();

    if (!email || !password || password.length < 1) {
      return new Response(JSON.stringify({ ok: false, error: 'missing_fields' }), { status: 400 });
    }

    if (!PROJECT_URL || !SERVICE_ROLE_KEY) {
      return new Response(
        JSON.stringify({ ok: false, error: 'missing_service_config' }),
        { status: 500 },
      );
    }

    const lookupUrl = `${PROJECT_URL}/rest/v1/users?email=ilike.${encodeURIComponent(email)}&select=user_id,email&limit=1`;
    const lookupResp = await fetch(lookupUrl, {
      method: 'GET',
      headers: {
        apikey: SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      },
    });

    if (!lookupResp.ok) {
      const text = await lookupResp.text();
      console.error('Reset password lookup failed:', lookupResp.status, text);
      return new Response(JSON.stringify({ ok: false, error: 'lookup_failed' }), { status: 500 });
    }

    const rows = await lookupResp.json();
    if (!Array.isArray(rows) || rows.length === 0) {
      return new Response(JSON.stringify({ ok: false, error: 'no_account' }), { status: 404 });
    }

    const authLookupUrl = `${PROJECT_URL}/auth/v1/admin/users?email=${encodeURIComponent(email)}`;
    const authLookupResp = await fetch(authLookupUrl, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        apikey: SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      },
    });

    let authUserId: string | null = null;
    if (authLookupResp.ok) {
      const authBody = await authLookupResp.json().catch(() => []);
      const authUsers = Array.isArray(authBody) ? authBody : authBody?.users;
      const match = Array.isArray(authUsers)
        ? authUsers.find((user) => user?.email?.toLowerCase() === email.toLowerCase())
        : null;
      authUserId = match?.id ?? null;
    }

    if (authUserId) {
      const adminUpdateUrl = `${PROJECT_URL}/auth/v1/admin/users/${authUserId}`;
      const adminUpdateResp = await fetch(adminUpdateUrl, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          apikey: SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
        },
        body: JSON.stringify({ password, email_confirm: true }),
      });

      if (!adminUpdateResp.ok) {
        const text = await adminUpdateResp.text();
        console.error('Reset password auth update failed:', adminUpdateResp.status, text);
        return new Response(JSON.stringify({ ok: false, error: 'auth_update_failed' }), { status: 500 });
      }
    }

    const patchUrl = `${PROJECT_URL}/rest/v1/users?email=eq.${encodeURIComponent(email)}`;
    const patchResp = await fetch(patchUrl, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        apikey: SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
        Prefer: 'return=representation',
      },
      body: JSON.stringify({ password }),
    });

    if (!patchResp.ok) {
      const text = await patchResp.text();
      console.error('Reset password update failed:', patchResp.status, text);
      if (!authUserId) {
        return new Response(JSON.stringify({ ok: false, error: 'update_failed' }), { status: 500 });
      }
      console.warn('Legacy public.users password update failed, but auth password update succeeded.');
    }

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (error) {
    console.error(error);
    return new Response(JSON.stringify({ ok: false, error: 'exception' }), { status: 500 });
  }
});
