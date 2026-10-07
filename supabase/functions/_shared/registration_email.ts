export async function isRegistrationEmailTaken(
  projectUrl: string,
  serviceRoleKey: string,
  email: string,
): Promise<boolean> {
  const response = await fetch(
    `${projectUrl}/rest/v1/rpc/is_registration_email_taken`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
      },
      body: JSON.stringify({ candidate_email: email }),
    },
  );

  if (!response.ok) {
    console.error('Registration email lookup failed:', response.status);
    throw new Error('registration_email_lookup_failed');
  }

  const result: unknown = await response.json();
  if (typeof result !== 'boolean') {
    console.error('Registration email lookup returned an invalid response.');
    throw new Error('registration_email_lookup_failed');
  }

  return result;
}
