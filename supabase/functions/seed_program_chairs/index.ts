import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.58.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const programs = [
  { id: 1, role: 'PC_MultimediaArts', name: 'B Multimedia Arts', email: 'pc.multimediaarts@nu-lipa.edu.ph' },
  { id: 2, role: 'PC_Architecture', name: 'BS Architecture', email: 'pc.architecture@nu-lipa.edu.ph' },
  { id: 3, role: 'PC_CivilEngineering', name: 'BS Civil Engineering', email: 'pc.civilengineering@nu-lipa.edu.ph' },
  { id: 4, role: 'PC_ComputerScience', name: 'BS Computer Science', email: 'pc.computerscience@nu-lipa.edu.ph' },
  { id: 5, role: 'PC_ComputerEngineering', name: 'BS Computer Engineering', email: 'pc.computerengineering@nu-lipa.edu.ph' },
  { id: 6, role: 'PC_InformationTechnology', name: 'BS Information Technology', email: 'pc.informationtechnology@nu-lipa.edu.ph' },
  { id: 7, role: 'PC_Accountancy', name: 'BS Accountancy', email: 'pc.accountancy@nu-lipa.edu.ph' },
  { id: 8, role: 'PC_FinancialManagement', name: 'BSBA Major in Financial Management', email: 'pc.financialmanagement@nu-lipa.edu.ph' },
  { id: 9, role: 'PC_MarketingManagement', name: 'BSBA Major in Marketing Management', email: 'pc.marketingmanagement@nu-lipa.edu.ph' },
  { id: 10, role: 'PC_ManagementAccounting', name: 'BS Management Accounting', email: 'pc.managementaccounting@nu-lipa.edu.ph' },
  { id: 11, role: 'PC_TourismManagement', name: 'BS Tourism Management', email: 'pc.tourismmanagement@nu-lipa.edu.ph' },
  { id: 12, role: 'PC_Psychology', name: 'BS Psychology', email: 'pc.psychology@nu-lipa.edu.ph' },
  { id: 13, role: 'PC_MedicalTechnology', name: 'BS Medical Technology', email: 'pc.medicaltechnology@nu-lipa.edu.ph' },
  { id: 14, role: 'PC_Nursing', name: 'BS Nursing', email: 'pc.nursing@nu-lipa.edu.ph' },
] as const;

type Program = (typeof programs)[number];

function response(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function generateTemporaryPassword(): string {
  const alphabet =
    'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@$%*-_';
  const bytes = new Uint8Array(24);
  const limit = Math.floor(256 / alphabet.length) * alphabet.length;
  let password = '';

  while (password.length < 24) {
    crypto.getRandomValues(bytes);
    for (const byte of bytes) {
      if (byte >= limit) continue;
      password += alphabet[byte % alphabet.length];
      if (password.length === 24) break;
    }
  }
  return password;
}

function isAlreadyRegisteredError(message: string): boolean {
  return /already been registered|already exists|duplicate key/i.test(message);
}

async function createOrLinkAccount(
  admin: ReturnType<typeof createClient>,
  program: Program,
) {
  const { data: programRow, error: programError } = await admin
    .from('academic_programs')
    .select('office_id, name')
    .eq('program_id', program.id)
    .single();
  if (programError) throw programError;

  const { data: profileRows, error: profileError } = await admin
    .from('users')
    .select('user_id, role, auth_user_id, email, office_id')
    .eq('program_id', program.id)
    .in('role', ['pc_admin', program.role, program.role.toLowerCase()])
    .limit(2);
  if (profileError) throw profileError;
  if ((profileRows?.length ?? 0) > 1) {
    throw new Error(`More than one Program Chair profile exists for ${program.name}.`);
  }

  const existingProfile = profileRows?.[0] as
    | { user_id: number; role: string; auth_user_id: string | null; email: string; office_id: number | null }
    | undefined;

  if (existingProfile?.auth_user_id) {
    const { data: existingAuth, error: existingAuthError } =
      await admin.auth.admin.getUserById(existingProfile.auth_user_id);
    if (existingAuthError) throw existingAuthError;
    if (
      existingAuth.user?.email?.toLowerCase() === program.email.toLowerCase()
    ) {
      return {
        program: program.name,
        email: program.email,
        temporaryPassword: null,
        created: false,
        note: 'An Auth account is already linked; no password was changed.',
      };
    }
    throw new Error(`The profile for ${program.name} is linked to a missing or unexpected Auth account; resolve that link before retrying.`);
  }

  const temporaryPassword = generateTemporaryPassword();
  let authUserId: string;
  const { data: authResult, error: authError } =
    await admin.auth.admin.createUser({
      email: program.email,
      password: temporaryPassword,
      email_confirm: true,
      user_metadata: { program_chair: true, program_id: program.id },
    });

  if (authError) {
    if (!isAlreadyRegisteredError(authError.message)) throw authError;
    throw new Error(
      `The Auth email ${program.email} is already in use but is not linked to this Program Chair profile. Review it manually; no password or existing account was changed.`,
    );
  } else {
    authUserId = authResult.user.id;
  }

  const profile = {
    username: program.email,
    role: program.role,
    email: program.email,
    affiliation: program.name,
    program_id: program.id,
    office_id: programRow.office_id,
    auth_user_id: authUserId,
    is_active: true,
    full_name: `Program Chair - ${program.name}`,
    first_name: 'Program Chair',
    last_name: program.name,
  };

  const saveResult = existingProfile
    ? await admin.from('users').update(profile).eq('user_id', existingProfile.user_id)
    : await admin.from('users').insert(profile);
  if (saveResult.error) {
    if (!authError) {
      await admin.auth.admin.deleteUser(authUserId);
    }
    throw saveResult.error;
  }

  return {
    program: program.name,
    email: program.email,
    temporaryPassword: authError ? null : temporaryPassword,
    created: !authError,
    note: 'Unique one-time temporary password. Share it with the assigned chair through a secure channel.',
  };
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') {
    return response({ error: 'method_not_allowed' }, 405);
  }

  const projectUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey =
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ??
    Deno.env.get('SERVICE_ROLE_KEY');
  if (!projectUrl || !serviceRoleKey) {
    return response({ error: 'server_configuration_missing' }, 500);
  }

  const authorization = request.headers.get('Authorization');
  if (!authorization?.startsWith('Bearer ')) {
    return response({ error: 'authentication_required' }, 401);
  }

  const admin = createClient(projectUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const token = authorization.slice('Bearer '.length);
  const { data: userResult, error: userError } = await admin.auth.getUser(token);
  if (userError || !userResult.user) {
    return response({ error: 'invalid_session' }, 401);
  }

  const { data: linkedProfile, error: linkedProfileError } = await admin
    .from('users')
    .select('role, is_active')
    .eq('auth_user_id', userResult.user.id)
    .limit(1)
    .maybeSingle();
  if (linkedProfileError) {
    return response({ error: 'admin_profile_lookup_failed' }, 500);
  }
  let profile = linkedProfile;
  if (!profile && userResult.user.email) {
    const { data: emailProfile, error: emailProfileError } = await admin
      .from('users')
      .select('role, is_active')
      .ilike('email', userResult.user.email)
      .limit(1)
      .maybeSingle();
    if (emailProfileError) {
      return response({ error: 'admin_profile_lookup_failed' }, 500);
    }
    profile = emailProfile;
  }
  if (
    !profile ||
    !profile.is_active ||
    (profile.role as string).toLowerCase() !== 'admin'
  ) {
    return response({ error: 'administrator_access_required' }, 403);
  }

  const accounts = [];
  try {
    for (const program of programs) {
      accounts.push(await createOrLinkAccount(admin, program));
    }
    return response({
      accounts,
      warning:
        'Passwords are unique per account and are shown only in this response. Save them securely now; existing account passwords are never reset or returned.',
    });
  } catch (error) {
    return response({
      error: 'program_chair_provisioning_failed',
      message: error instanceof Error ? error.message : 'Unknown provisioning error.',
      accounts,
      warning:
        'Some accounts may already have been created. Save any displayed passwords securely, resolve the error, then run setup again for the remaining accounts.',
    }, accounts.length > 0 ? 207 : 500);
  }
});