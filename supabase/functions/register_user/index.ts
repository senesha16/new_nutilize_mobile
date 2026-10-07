// Supabase Edge Function: register_user
// Accepts { email, password, profile } and performs:
// 1) Create user via Admin API with email_confirm true (service role key)
// 2) Insert profile into `public.users` using service role key
// 3) Sign in using password grant to obtain access_token and return it

import { serve } from "https://deno.land/std@0.201.0/http/server.ts";
import { hashPassword } from "../_shared/password_hash.ts";

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
    const verificationCode = (body.code || '').toString().trim();
    const profile = Object.assign({}, body.profile || {}, {
      affiliation: body.affiliation ?? body.profile?.affiliation,
      program_id: body.program_id ?? body.profile?.program_id,
    });

    if (!email || !password || !verificationCode) {
      return new Response(JSON.stringify({ error: 'Missing email, password, or verification code' }), { status: 400 });
    }
    if (password.length < 8) {
      return new Response(
        JSON.stringify({ error: 'Password must be at least 8 characters long.' }),
        { status: 400 },
      );
    }
    const otpQuery =
      `${SUPABASE_URL}/rest/v1/email_otps?email=eq.${encodeURIComponent(email)}` +
      `&code=eq.${encodeURIComponent(verificationCode)}` +
      `&purpose=eq.verification&expires_at=gt.${encodeURIComponent(new Date().toISOString())}&select=id`;
    const otpResponse = await fetch(otpQuery, {
      method: 'DELETE',
      headers: {
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
        apikey: SERVICE_ROLE_KEY,
        Prefer: 'return=representation',
      },
    });
    if (!otpResponse.ok) {
      console.error('Signup verification code consume failed:', otpResponse.status);
      return new Response(JSON.stringify({ error: 'verification_failed' }), { status: 500 });
    }
    const consumedCodes = await otpResponse.json().catch(() => []);
    if (!Array.isArray(consumedCodes) || consumedCodes.length === 0) {
      return new Response(JSON.stringify({ error: 'invalid_or_expired_code' }), { status: 400 });
    }

    const passwordHash = await hashPassword(password);

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
      const normalizedMessage = msg.toString().toLowerCase();
      if (
        errCode === 'email_exists' ||
        normalizedMessage.includes('already been registered') ||
        normalizedMessage.includes('already exists')
      ) {
        if (!ANON_KEY) {
          return new Response(
            JSON.stringify({
              error: 'account_already_exists',
              message:
                'An account with this email already exists. Please log in or reset your password.',
            }),
            { status: 409 },
          );
        }

        // A prior signup may have created the Auth user but failed to save its
        // public.users profile. Recover only when the submitted password proves
        // ownership and no application profile exists yet.
        const { session } = await createSessionWithRetry(email, password, ANON_KEY);
        if (!session?.access_token) {
          return new Response(
            JSON.stringify({
              error: 'account_already_exists',
              message:
                'An account with this email already exists. Please log in or reset your password.',
            }),
            { status: 409 },
          );
        }

        const profileCheck = await fetch(
          `${SUPABASE_URL}/rest/v1/users?select=user_id&email=eq.${encodeURIComponent(email)}&limit=1`,
          {
            headers: {
              'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
              'apikey': SERVICE_ROLE_KEY,
              'Accept': 'application/json',
            },
          },
        );
        const profileRows = await profileCheck.json().catch(() => null);
        if (!profileCheck.ok || !Array.isArray(profileRows)) {
          return new Response(
            JSON.stringify({
              error: 'profile_lookup_failed',
              message: 'Could not verify whether the application profile exists.',
            }),
            { status: 500 },
          );
        }
        if (profileRows.length > 0) {
          return new Response(
            JSON.stringify({
              error: 'account_already_exists',
              message:
                'An account with this email already exists. Please log in or reset your password.',
            }),
            { status: 409 },
          );
        }

        const authUserResponse = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
          headers: {
            'Authorization': `Bearer ${session.access_token}`,
            'apikey': ANON_KEY,
          },
        });
        const authUser = await authUserResponse.json().catch(() => null);
        if (!authUserResponse.ok || !authUser?.id) {
          return new Response(
            JSON.stringify({
              error: 'existing_auth_user_unresolved',
              message: 'Could not verify the existing account. Please log in.',
            }),
            { status: 409 },
          );
        }
        user = authUser;
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
    payload.password = passwordHash;
    payload.role = incoming.role || 'student';
    payload.auth_user_id = user.id;
    if (incoming.first_name) payload.first_name = incoming.first_name;
    if (incoming.last_name) payload.last_name = incoming.last_name;
    if (incoming.contact_number) payload.contact_number = incoming.contact_number;
    if (incoming.phone_number) payload.phone_number = incoming.phone_number;
    if (incoming.full_name) payload.full_name = incoming.full_name;
    if (incoming.middle_initial) payload.middle_initial = incoming.middle_initial;
    if (incoming.suffix) payload.suffix = incoming.suffix;
    if (incoming.office_id) payload.office_id = Number(incoming.office_id);
    if (incoming.affiliation) payload.affiliation = incoming.affiliation;
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
        message: insertBody?.message || insertBody?.details || 'The profile could not be saved.',
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
