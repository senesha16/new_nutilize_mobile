-- Migration: add auth_user_id and reported_items to reservation_issues
-- WARNING: Review before running. Run in staging first and backup your data.

BEGIN;

-- Backup current table
CREATE TABLE IF NOT EXISTS public.reservation_issues_backup AS TABLE public.reservation_issues WITH NO DATA;
INSERT INTO public.reservation_issues_backup SELECT * FROM public.reservation_issues;

-- Add columns if missing
ALTER TABLE public.reservation_issues
  ADD COLUMN IF NOT EXISTS auth_user_id text;

ALTER TABLE public.reservation_issues
  ADD COLUMN IF NOT EXISTS reported_items jsonb;

-- Enable Row Level Security (idempotent)
ALTER TABLE public.reservation_issues ENABLE ROW LEVEL SECURITY;

-- Drop existing policies with these names if present, then create safe policies
DROP POLICY IF EXISTS insert_reservation_issues_authenticated ON public.reservation_issues;
CREATE POLICY insert_reservation_issues_authenticated
  ON public.reservation_issues
  FOR INSERT
  TO authenticated
  WITH CHECK (
    -- allow when auth uid matches auth_user_id OR when reported_by equals auth.email()
    auth.uid() = auth_user_id
    OR reported_by = auth.email()
  );

DROP POLICY IF EXISTS select_reservation_issues_authenticated ON public.reservation_issues;
CREATE POLICY select_reservation_issues_authenticated
  ON public.reservation_issues
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = auth_user_id
    OR reported_by = auth.email()
  );

COMMIT;

-- Notes:
-- 1) This migration creates a backup table `reservation_issues_backup` and copies data into it.
-- 2) The policies are intentionally conservative: authenticated users can insert or select when
--    their Auth UID matches `auth_user_id` OR their auth.email() equals the `reported_by` column.
-- 3) If your app requires different visibility (admins, staff offices), add additional policies.
-- 4) Test in a staging project before applying to production.
