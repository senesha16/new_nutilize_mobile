export async function hasRegistrationProfile(
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
  return profiles.length > 0;
}
