-- Passwords are managed by Supabase Auth; the legacy profile column is unused.
-- Apply this migration only to security_db while validating the new project.
ALTER TABLE public.users
  ALTER COLUMN password DROP NOT NULL;
