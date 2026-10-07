BEGIN;

ALTER TABLE public.users
  ALTER COLUMN password DROP NOT NULL;

ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_password_must_be_null;

COMMIT;
