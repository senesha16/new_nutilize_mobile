BEGIN;

DROP POLICY IF EXISTS authenticated_users_upload_own_proof_of_consent
  ON storage.objects;

CREATE POLICY authenticated_users_upload_own_proof_of_consent
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'proof_of_consent'
    AND (storage.foldername(name))[1] = (
      SELECT users.user_id::text
      FROM public.users AS users
      WHERE lower(users.email) = lower(auth.jwt() ->> 'email')
      LIMIT 1
    )
  );

COMMIT;
