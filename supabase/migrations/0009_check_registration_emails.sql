BEGIN;

CREATE OR REPLACE FUNCTION public.is_registration_email_taken(
  candidate_email text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users AS profile
    WHERE lower(trim(profile.email)) = lower(trim(candidate_email))
  )
  OR EXISTS (
    SELECT 1
    FROM auth.users AS auth_user
    WHERE lower(trim(auth_user.email)) = lower(trim(candidate_email))
  );
$$;

REVOKE ALL ON FUNCTION public.is_registration_email_taken(text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_registration_email_taken(text)
  TO service_role;

COMMIT;
