export async function isRegistrationEmailTaken(
  projectUrl: string,
  serviceRoleKey: string,
  email: string,
): Promise<boolean> {
  const normalizedEmail = email.trim().toLowerCase();
  const headers = {
    apikey: serviceRoleKey,
    Authorization: ['Bearer', serviceRoleKey].join(' '),
  };

  const profileResponse = await fetch(
    `${projectUrl}/rest/v1/users?select=user_id&email=ilike.${encodeURIComponent(normalizedEmail)}&limit=1`,
    { headers },
  );
  if (!profileResponse.ok) {
    console.error('Registration profile lookup failed:', profileResponse.status);
    throw new Error('registration_email_lookup_failed');
  }

  const profiles = await profileResponse.json();
  if (!Array.isArray(profiles)) {
    throw new Error('registration_email_lookup_failed');
  }
  if (profiles.length > 0) return true;

  const pageSize = 1000;
  for (let page = 1; ; page += 1) {
    const authResponse = await fetch(
      `${projectUrl}/auth/v1/admin/users?page=${page}&per_page=${pageSize}`,
      { headers },
    );
    if (!authResponse.ok) {
      console.error('Registration Auth lookup failed:', authResponse.status);
      throw new Error('registration_email_lookup_failed');
    }

    const authBody = await authResponse.json();
    const authUsers = Array.isArray(authBody) ? authBody : authBody?.users;
    if (!Array.isArray(authUsers)) {
      throw new Error('registration_email_lookup_failed');
    }
    if (
      authUsers.some(
        (user) => user?.email?.trim().toLowerCase() === normalizedEmail,
      )
    ) {
      return true;
    }
    if (authUsers.length < pageSize) return false;
  }
}
