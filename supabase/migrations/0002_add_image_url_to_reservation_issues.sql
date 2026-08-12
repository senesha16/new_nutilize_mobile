BEGIN;

ALTER TABLE public.reservation_issues
  ADD COLUMN IF NOT EXISTS image_url text;

COMMIT;
