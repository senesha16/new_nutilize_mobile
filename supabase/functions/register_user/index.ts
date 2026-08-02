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

const PROGRAM_ID_BY_AFFILIATION: Record<string, number> = {
  'b multimedia arts': 1,
  'bs architecture': 2,
  'bs civil engineering': 3,
  'bs computer science': 4,
  'bs computer engineering': 5,
  'bs information technology': 6,
  'bs information technology with specialization in mobile and web applications': 6,
  'bs accountancy': 7,
  'bsba major in financial management': 8,
  'bsba major in marketing management': 9,
  'bs management accounting': 10,
  'bs tourism management': 11,
  'bs psychology': 12,
  'bs medical technology': 13,
  'bs nursing': 14,
};

function normalizeAffiliation(value: unknown): string | null {
  const normalized = String(value ?? '').trim().toLowerCase();
  return normalized ? normalized : null;
}

function programIdForAffiliation(value: unknown): number | null {
  const normalized = normalizeAffiliation(value);
  if (!normalized) return null;
  return PROGRAM_ID_BY_AFFILIATION[normalized] ?? null;
}

async function resolveProgramId(affiliation: unknown): Promise<number | null> {
  const rawAffiliation = String(affiliation ?? '').trim();
  const normalized = normalizeAffiliation(affiliation);
  if (!rawAffiliation) return null;

  const databaseLookups = [
    `name=eq.${encodeURIComponent(rawAffiliation)}`,
    `code=eq.${encodeURIComponent(rawAffiliation)}`,
    `name=ilike.${encodeURIComponent(rawAffiliation)}`,
    `code=ilike.${encodeURIComponent(rawAffiliation)}`,
  ];

  for (const query of databaseLookups) {
    const resp = await fetch(`${SUPABASE_URL}/rest/v1/academic_programs?select=program_id&${query}&limit=1`, {
      headers: {
        'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
        'apikey': SERVICE_ROLE_KEY,
        'Accept': 'application/json',
      },
    });

    if (!resp.ok) {
      continue;
    }

    const rows = await resp.json().catch(() => []);
    if (Array.isArray(rows) && rows.length > 0 && rows[0]?.program_id) {
      return Number(rows[0].program_id);
    }
  }

  return programIdForAffiliation(normalized);
}

async function sleep(ms: number): Promise<void> {
  await new Promise((resolve) => setTimeout(resolve, ms));
}

async function createSessionWithRetry(email: string, password: string, authKey: string) {
  const attempts = [0, 500];

  for (const delay of attempts) {
    if (delay > 0) {
      await sleep(delay);
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
    if (tokenResp.ok && tokenBody?.access_token) {
      return { session: tokenBody, error: null };
    }

    const errorText = tokenBody?.msg || tokenBody?.message || tokenBody?.error_description || tokenBody?.error || `Status ${tokenResp.status}`;
    if (delay === attempts[attempts.length - 1]) {
      return { session: null, error: errorText };
    }
  }

  return { session: null, error: 'Unable to create session' };
}

serve(async (req) => {
  if (!SERVICE_ROLE_KEY || !SUPABASE_URL) {
    return new Response(JSON.stringify({ error: 'Server misconfigured' }), { status: 500 });
  }

  try {
    const body = await req.json();
    const email = (body.email || '').toString().trim();
    const password = (body.password || '').toString();
    const profile = Object.assign({}, body.profile || {}, {
      affiliation: body.affiliation ?? body.profile?.affiliation,
      program_id: body.program_id ?? body.profile?.program_id,
    });

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
        // value so registration results in a usable credential.
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
          return new Response(JSON.stringify({ error: 'Existing auth user found but could not be resolved.' }), { status: 500 });
        }

        const existingId = user?.id;
        if (!existingId) {
          return new Response(JSON.stringify({ error: 'Existing auth user found but missing user id.' }), { status: 500 });
        }

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
        if (!upd.ok) {
          return new Response(JSON.stringify({ error: 'Failed to update password for existing auth user.', details: updBody }), { status: upd.status || 500 });
        }
        user = updBody || user;
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
    payload.role = incoming.role || 'student';
    if (incoming.first_name) payload.first_name = incoming.first_name;
    if (incoming.last_name) payload.last_name = incoming.last_name;
    if (incoming.contact_number) payload.contact_number = incoming.contact_number;
    if (incoming.phone_number) payload.phone_number = incoming.phone_number;
    if (incoming.full_name) payload.full_name = incoming.full_name;
    if (incoming.middle_initial) payload.middle_initial = incoming.middle_initial;
    if (incoming.suffix) payload.suffix = incoming.suffix;
    if (incoming.office_id) payload.office_id = Number(incoming.office_id);
    if (incoming.affiliation) payload.affiliation = incoming.affiliation;
    if (incoming.role) payload.role = incoming.role;
    if (incoming.program_id) {
      payload.program_id = Number(incoming.program_id);
    } else {
      const mappedProgramId = await resolveProgramId(incoming.affiliation);
      if (mappedProgramId) {
        payload.program_id = mappedProgramId;
      }
    }

    if (!payload.program_id) {
      payload.program_id = 1;
    }
    // helper to POST profile
    async function postProfile(bodyObj: any) {
      const r = await fetch(`${SUPABASE_URL}/rest/v1/users?on_conflict=email`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
          'apikey': SERVICE_ROLE_KEY,
          'Prefer': 'resolution=merge-duplicates,return=representation',
        },
        body: JSON.stringify(bodyObj),
      });
      const jb = await r.json().catch(() => ({}));
      return { resp: r, body: jb };
    }

    // Save or update the profile in one step using upsert semantics.
    const insertAttempt = await postProfile(payload);
    const insertBody: any = insertAttempt.body;
    if (!insertAttempt.resp.ok) {
      return new Response(JSON.stringify({
        error: 'Failed saving registration profile',
        details: insertBody,
      }), { status: insertAttempt.resp.status || 400 });
    }

    // 3) Skip the slow session/token creation step. The registration itself is
    // already complete and the profile has been saved. Return success immediately.
    const respBody: any = {
      ok: true,
      user,
      profile: insertBody,
      warning: 'User created and profile inserted. Please log in with your credentials.',
    };
    return new Response(JSON.stringify(respBody), { status: 201 });
  } catch (err) {
    return new Response(JSON.stringify({ error: err?.message || String(err) }), { status: 500 });
  }
});
