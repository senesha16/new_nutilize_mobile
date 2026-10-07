import { serve } from 'https://deno.land/std@0.199.0/http/server.ts';
import { hashPassword } from '../_shared/password_hash.ts';

const PROJECT_URL = Deno.env.get('PROJECT_URL');
const SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY');

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

serve(async (req) => {
  try {
    if (req.method !== 'POST') {
      return json({ ok: false, error: 'method_not_allowed' }, 405);
    }
    if (!PROJECT_URL || !SERVICE_ROLE_KEY) {
      return json({ ok: false, error: 'missing_service_config' }, 500);
    }

    const payload = await req.json();
    const email = payload.email?.toString().trim();
    const code = payload.code?.toString().trim();
    const password = payload.password?.toString();
    if (!email || !code || !password) {
      return json({ ok: false, error: 'missing_fields' }, 400);
    }
    if (password.length < 8) {
      return json({ ok: false, error: 'weak_password' }, 400);
    }

    const headers = {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
    };
    const profileResponse = await fetch(
      `${PROJECT_URL}/rest/v1/users?email=ilike.${encodeURIComponent(email)}&select=user_id,email,auth_user_id&limit=1`,
      { headers },
    );
    if (!profileResponse.ok) {
      console.error('Password reset profile lookup failed:', profileResponse.status);
      return json({ ok: false, error: 'account_lookup_failed' }, 500);
    }
    const profiles = await profileResponse.json();
    const profile = Array.isArray(profiles) ? profiles[0] : null;
    if (!profile?.user_id || !profile?.email) {
      return json({ ok: false, error: 'invalid_or_expired_code' }, 400);
    }

    const authLookupResponse = await fetch(
      `${PROJECT_URL}/auth/v1/admin/users?email=${encodeURIComponent(email)}`,
      { headers },
    );
    if (!authLookupResponse.ok) {
      console.error('Password reset Auth lookup failed:', authLookupResponse.status);
      return json({ ok: false, error: 'account_lookup_failed' }, 500);
    }
    const authBody = await authLookupResponse.json().catch(() => []);
    const authUsers = Array.isArray(authBody) ? authBody : authBody?.users;
    const authUser = Array.isArray(authUsers)
      ? authUsers.find(
          (user) =>
            user?.email?.toLowerCase() === email.toLowerCase() &&
            user?.email?.toLowerCase() === profile.email.toLowerCase(),
        )
      : null;
    if (!authUser?.id) {
      return json({ ok: false, error: 'invalid_or_expired_code' }, 400);
    }
    if (
      profile.auth_user_id &&
      profile.auth_user_id.toLowerCase() !== authUser.id.toLowerCase()
    ) {
      console.error('Password reset profile/Auth identity mismatch.');
      return json({ ok: false, error: 'account_identity_mismatch' }, 409);
    }

    // Consume the matching, unexpired reset code in the same operation that
    // validates it, so concurrent requests cannot reuse the OTP.
    const otpQuery =
      `${PROJECT_URL}/rest/v1/email_otps?email=eq.${encodeURIComponent(email)}` +
      `&code=eq.${encodeURIComponent(code)}` +
      '&purpose=eq.password_reset' +
      `&expires_at=gt.${encodeURIComponent(new Date().toISOString())}&select=id`;
    const otpResponse = await fetch(otpQuery, {
      method: 'DELETE',
      headers: {
        ...headers,
        Prefer: 'return=representation',
      },
    });
    if (!otpResponse.ok) {
      console.error('Password reset OTP consume failed:', otpResponse.status);
      return json({ ok: false, error: 'otp_verification_failed' }, 500);
    }
    const consumedOtps = await otpResponse.json().catch(() => []);
    if (!Array.isArray(consumedOtps) || consumedOtps.length === 0) {
      return json({ ok: false, error: 'invalid_or_expired_code' }, 400);
    }

    const passwordHash = await hashPassword(password);
    const authUpdateResponse = await fetch(
      `${PROJECT_URL}/auth/v1/admin/users/${encodeURIComponent(authUser.id)}`,
      {
        method: 'PUT',
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ password, email_confirm: true }),
      },
    );
    if (!authUpdateResponse.ok) {
      console.error(
        'Password reset Auth update failed:',
        authUpdateResponse.status,
      );
      return json({ ok: false, error: 'auth_update_failed' }, 500);
    }

    const profileUpdateResponse = await fetch(
      `${PROJECT_URL}/rest/v1/users?user_id=eq.${encodeURIComponent(profile.user_id)}`,
      {
        method: 'PATCH',
        headers: {
          ...headers,
          'Content-Type': 'application/json',
          Prefer: 'return=representation',
        },
        body: JSON.stringify({
          password: passwordHash,
          auth_user_id: authUser.id,
        }),
      },
    );
    const updatedProfiles = await profileUpdateResponse.json().catch(() => []);
    if (
      !profileUpdateResponse.ok ||
      !Array.isArray(updatedProfiles) ||
      updatedProfiles.length !== 1
    ) {
      // Supabase Auth is authoritative; a profile hash-copy failure must not
      // make the client retry with an OTP that has already been consumed.
      console.error(
        'Password reset profile hash copy update failed:',
        profileUpdateResponse.status,
      );
      return json({ ok: true, warning: 'profile_hash_copy_not_updated' });
    }

    return json({ ok: true });
  } catch (error) {
    console.error('Password reset exception:', error);
    return json({ ok: false, error: 'exception' }, 500);
  }
});
