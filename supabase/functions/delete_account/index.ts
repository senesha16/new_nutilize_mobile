import { serve } from 'https://deno.land/std@0.201.0/http/server.ts';

const PROJECT_URL = Deno.env.get('PROJECT_URL') || Deno.env.get('SUPABASE_URL');
const SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY');

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

async function removeUserStorage(bucket: string, userId: number) {
  const listResponse = await fetch(`${PROJECT_URL}/storage/v1/object/list/${bucket}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: SERVICE_ROLE_KEY!,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
    },
    body: JSON.stringify({
      prefix: `${userId}/`,
      limit: 1000,
      offset: 0,
      sortBy: { column: 'name', order: 'asc' },
    }),
  });
  if (!listResponse.ok) {
    throw new Error(`Storage list failed for ${bucket}: ${await listResponse.text()}`);
  }

  const objects = await listResponse.json();
  const paths = Array.isArray(objects)
    ? objects
        .map((object) => object?.name?.toString())
        .filter((name): name is string => Boolean(name))
        .map((name) => `${userId}/${name}`)
    : [];

  if (paths.length === 0) return;

  const removeResponse = await fetch(`${PROJECT_URL}/storage/v1/object/${bucket}`, {
    method: 'DELETE',
    headers: {
      'Content-Type': 'application/json',
      apikey: SERVICE_ROLE_KEY!,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
    },
    body: JSON.stringify({ prefixes: paths }),
  });
  if (!removeResponse.ok) {
    throw new Error(`Storage delete failed for ${bucket}: ${await removeResponse.text()}`);
  }
}

serve(async (req) => {
  try {
    if (req.method !== 'POST' || !PROJECT_URL || !SERVICE_ROLE_KEY) {
      return json({ ok: false, error: 'invalid_request' }, 400);
    }

    const authorization = req.headers.get('Authorization');
    const userToken = authorization?.replace(/^Bearer\s+/i, '').trim();
    if (!userToken || userToken === SERVICE_ROLE_KEY) {
      return json({ ok: false, error: 'authentication_required' }, 401);
    }

    const payload = await req.json();
    const code = payload.code?.toString().trim();
    if (!code) {
      return json({ ok: false, error: 'missing_code' }, 400);
    }

    const authResponse = await fetch(`${PROJECT_URL}/auth/v1/user`, {
      headers: {
        apikey: SERVICE_ROLE_KEY,
        Authorization: `Bearer ${userToken}`,
      },
    });
    if (!authResponse.ok) {
      return json({ ok: false, error: 'invalid_session' }, 401);
    }

    const authUser = await authResponse.json();
    const authUserId = authUser?.id?.toString();
    const email = authUser?.email?.toString().trim();
    if (!authUserId || !email) {
      return json({ ok: false, error: 'invalid_account' }, 400);
    }

    const profileResponse = await fetch(
      `${PROJECT_URL}/rest/v1/users?select=user_id,auth_user_id&auth_user_id=eq.${encodeURIComponent(authUserId)}&limit=1`,
      {
        headers: {
          apikey: SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
        },
      },
    );
    const profiles = await profileResponse.json().catch(() => []);
    const profile = Array.isArray(profiles) ? profiles[0] : null;
    const userId = profile?.user_id;
    if (!userId) {
      return json({ ok: false, error: 'profile_not_found' }, 404);
    }

    const otpQuery = `${PROJECT_URL}/rest/v1/email_otps?email=eq.${encodeURIComponent(email)}&code=eq.${encodeURIComponent(code)}&purpose=eq.account_deletion&expires_at=gt.${encodeURIComponent(new Date().toISOString())}&select=id&limit=1`;
    const otpResponse = await fetch(otpQuery, {
      headers: {
        apikey: SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      },
    });
    const otpRows = await otpResponse.json().catch(() => []);
    if (!Array.isArray(otpRows) || otpRows.length === 0) {
      return json({ ok: false, error: 'invalid_code' }, 200);
    }

    await removeUserStorage('reports', userId);
    await removeUserStorage('proof_of_consent', userId);

    const deleteDataResponse = await fetch(`${PROJECT_URL}/rest/v1/rpc/delete_account_data`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      },
      body: JSON.stringify({ target_user_id: userId }),
    });
    if (!deleteDataResponse.ok) {
      const details = await deleteDataResponse.text();
      console.error('Account data deletion failed:', details);
      return json({ ok: false, error: 'data_deletion_failed', details }, 500);
    }

    const deleteAuthResponse = await fetch(
      `${PROJECT_URL}/auth/v1/admin/users/${encodeURIComponent(authUserId)}`,
      {
        method: 'DELETE',
        headers: {
          apikey: SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
        },
      },
    );
    if (!deleteAuthResponse.ok) {
      console.error('Auth account deletion failed:', await deleteAuthResponse.text());
      return json({ ok: false, error: 'auth_deletion_failed' }, 500);
    }

    const otpId = otpRows[0].id;
    await fetch(`${PROJECT_URL}/rest/v1/email_otps?id=eq.${encodeURIComponent(otpId)}`, {
      method: 'DELETE',
      headers: {
        apikey: SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      },
    });

    return json({ ok: true });
  } catch (error) {
    console.error('Account deletion exception:', error);
    return json({ ok: false, error: 'exception' }, 500);
  }
});
