BEGIN;

ALTER TABLE public.users
  ALTER COLUMN password DROP NOT NULL;

ALTER TABLE public.users
  DISABLE TRIGGER guard_user_profile_changes;

UPDATE public.users
SET password = NULL
WHERE password IS NOT NULL;

ALTER TABLE public.users
  ENABLE TRIGGER guard_user_profile_changes;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'users_password_must_be_null'
      AND conrelid = 'public.users'::regclass
  ) THEN
    ALTER TABLE public.users
      ADD CONSTRAINT users_password_must_be_null
      CHECK (password IS NULL);
  END IF;
END;
$$;

COMMIT;
