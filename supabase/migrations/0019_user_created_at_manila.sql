-- Store each new account's signup time as Manila wall-clock time.
-- public.users.created_at is timestamp without time zone and had no default,
-- so registration inserts were leaving it empty.

CREATE OR REPLACE FUNCTION private.set_user_created_at_manila()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
  IF NEW.created_at IS NULL THEN
    NEW.created_at := timezone('Asia/Manila', clock_timestamp());
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS users_set_created_at_manila ON public.users;
CREATE TRIGGER users_set_created_at_manila
  BEFORE INSERT ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION private.set_user_created_at_manila();

ALTER TABLE public.users
  ALTER COLUMN created_at SET DEFAULT timezone('Asia/Manila', clock_timestamp());

REVOKE ALL ON FUNCTION private.set_user_created_at_manila() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.set_user_created_at_manila() TO authenticated, service_role;

-- Fill only blank signup times from the real Auth signup moment, in Manila.
-- Rows that already have a created_at are left unchanged.
UPDATE public.users AS profile
SET created_at = timezone('Asia/Manila', account.created_at)
FROM auth.users AS account
WHERE profile.auth_user_id = account.id
  AND profile.created_at IS NULL
  AND account.created_at IS NOT NULL;
