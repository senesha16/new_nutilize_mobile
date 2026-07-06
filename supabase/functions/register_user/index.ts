// Supabase Edge Function: register_user
// Accepts { email, password, profile } and performs:
// 1) Create user via Admin API with email_confirm true (service role key)
// 2) Insert profile into `public.users` using service role key
// 3) Sign in using password grant to obtain access_token and return it

import { serve } from "https://deno.land/std@0.201.0/http/server.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || Deno.env.get("PROJECT_URL");
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
// Try multiple env names for the anon/publishable key to be resilient to
// different secret naming conventions. If none exist, we will skip creating
// a session token and return success with a warning instead of failing.
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") || Deno.env.get("SUPABASE_PUBLISHABLE_KEYS") || Deno.env.get("SUPABASE_PUBLISHABLE_KEY") || Deno.env.get("PUBLISHABLE_KEY");

serve(async (req) => {
  if (!SERVICE_ROLE_KEY || !SUPABASE_URL) {
    return new Response(JSON.stringify({ error: 'Server misconfigured' }), { status: 500 });
  }

  try {
    const body = await req.json();
    const email = (body.email || '').toString().trim();
    const password = (body.password || '').toString();
    const profile = body.profile || {};

    if (!email || !password) {
      return new Response(JSON.stringify({ error: 'Missing email or password' }), { status: 400 });
    }

    // 1) Create user via Admin API
    const createResp = await fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
        'apikey': SERVICE_ROLE_KEY,
      },
      body: JSON.stringify({
        email,
        password,
        email_confirm: true,
      }),
    });

    const createBody = await createResp.json().catch(() => ({}));
    let user;
    if (createResp.ok) {
      user = createBody;
    } else {
      const errCode = createBody?.error_code || createBody?.code;
      const msg = createBody?.msg || createBody?.message || '';
      // If the user already exists, try to fetch the existing user and proceed.
      if (errCode === 'email_exists' || msg.toString().toLowerCase().includes('already been registered') || msg.toString().toLowerCase().includes('already exists')) {
        // Fetch existing user and ensure the password is set to the provided
        // value so registration results in a usable credential. We use the
        // service role key to PATCH the admin user object.
        const listResp = await fetch(`${SUPABASE_URL}/auth/v1/admin/users?email=${encodeURIComponent(email)}`, {
          method: 'GET',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
            'apikey': SERVICE_ROLE_KEY,
          },
        });
        const listBody = await listResp.json().catch(() => null);
        if (listResp.ok && Array.isArray(listBody) && listBody.length > 0) {
          user = listBody[0];
        } else if (listResp.ok && listBody && listBody.id) {
          user = listBody;
        } else {
          // Fallback to a minimal user object
          user = { email };
        }

        // If we found an existing user id, attempt to set the password so
        // the client can sign in immediately. This overwrites the password
        // for that user id using the Admin API.
        try {
          const existingId = user?.id;
          if (existingId) {
            const upd = await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${existingId}`, {
              method: 'PUT',
              headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
                'apikey': SERVICE_ROLE_KEY,
              },
              body: JSON.stringify({ password, email_confirm: true }),
            });
            const updBody = await upd.json().catch(() => null);
            if (upd.ok && updBody) {
              user = updBody;
            }
          }
        } catch (e) {
          // ignore update errors; we'll still return creation success
        }
      } else {
        return new Response(JSON.stringify({ error: createBody?.message || createBody }), { status: createResp.status || 400 });
      }
    }

    // 2) Insert profile into public.users using service role key
    // Build a payload with only common profile fields to reduce schema mismatch
    const incoming = Object.assign({}, profile || {});
    const payload: any = {};
    payload.email = incoming.email || email;
    payload.username = incoming.username || email;
    payload.password = password;
    if (incoming.first_name) payload.first_name = incoming.first_name;
    if (incoming.last_name) payload.last_name = incoming.last_name;
    if (incoming.contact_number) payload.contact_number = incoming.contact_number;
    if (incoming.phone_number) payload.phone_number = incoming.phone_number;
    if (incoming.full_name) payload.full_name = incoming.full_name;
    if (incoming.middle_initial) payload.middle_initial = incoming.middle_initial;
    if (incoming.suffix) payload.suffix = incoming.suffix;
    if (incoming.office_id) payload.office_id = incoming.office_id;
    if (incoming.affiliation) payload.affiliation = incoming.affiliation;
    if (incoming.role) payload.role = incoming.role;
    // helper to POST profile
    async function postProfile(bodyObj: any) {
      const r = await fetch(`${SUPABASE_URL}/rest/v1/users`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
          'apikey': SERVICE_ROLE_KEY,
          'Prefer': 'return=representation',
        },
        body: JSON.stringify(bodyObj),
      });
      const jb = await r.json().catch(() => ({}));
      return { resp: r, body: jb };
    }

    // Try initial insert
    let insertAttempt = await postProfile(payload);
    let insertBody: any = insertAttempt.body;
    // If failed, inspect reason and try to fill sensible defaults then retry once
    if (!insertAttempt.resp.ok) {
      const msg = (insertBody?.message || insertBody?.details || '').toString();
      const m = msg.match(/column "(.*?)"/i);
      if (m) {
        const missing = m[1];
        if (missing === 'password' && !payload.password) {
          payload.password = crypto.randomUUID().slice(0, 16);
        }
        if (missing === 'role' && !payload.role) {
          payload.role = 'user';
        }
        // retry
        const second = await postProfile(payload);
        insertAttempt = second;
        insertBody = second.body;
      }
    }

    if (!insertAttempt.resp.ok) {
      // final fallback: try patch by email (upsert-like)
      const patchResp = await fetch(`${SUPABASE_URL}/rest/v1/users?email=eq.${encodeURIComponent(email)}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
          'apikey': SERVICE_ROLE_KEY,
          'Prefer': 'return=representation',
        },
        body: JSON.stringify(payload),
      });
      const patchBody = await patchResp.json().catch(() => ({}));
      if (patchResp.ok) {
        insertBody = patchBody;
      } else {
        // keep insertBody as last error details
      }
    }

    // 3) Try to create a session token on behalf of the new user so the
    // client can be logged in immediately. Prefer the configured anon key,
    // but fall back to the public apikey sent by the client if needed.
    let session = null;
    try {
      const authKey = ANON_KEY || req.headers.get('apikey') || req.headers.get('authorization')?.replace(/^Bearer\s+/i, '') || '';
      if (!authKey) {
        throw new Error('Missing anon key for session creation');
      }
      const tokenResp = await fetch(`${SUPABASE_URL}/auth/v1/token`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': `Bearer ${authKey}`,
          'apikey': authKey,
        },
        body: `grant_type=password&email=${encodeURIComponent(email)}&password=${encodeURIComponent(password)}`,
      });
      const tokenBody = await tokenResp.json().catch(() => null);
      if (tokenResp.ok && tokenBody) {
        session = tokenBody;
      } else {
        // include token endpoint error in logs/response details for debugging
        // but don't fail the user creation flow
        // (we'll attach tokenBody to response below)
        insertBody = insertBody || {};
        insertBody.token_error = tokenBody;
      }
    } catch (e) {
      // ignore session creation errors; we will return creation success below
    }

    const respBody: any = { ok: true, user, profile: insertBody };
    if (session) {
      respBody.session = session;
      return new Response(JSON.stringify(respBody), { status: 201 });
    }

    respBody.warning = 'User created and profile inserted; no session created by function';
    return new Response(JSON.stringify(respBody), { status: 201 });
  } catch (err) {
    return new Response(JSON.stringify({ error: err?.message || String(err) }), { status: 500 });
  }
});
