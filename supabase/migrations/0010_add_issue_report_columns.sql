ALTER TABLE public.reservation_issues
  ADD COLUMN IF NOT EXISTS auth_user_id text;

ALTER TABLE public.reservation_issues
  ADD COLUMN IF NOT EXISTS reported_items jsonb;

NOTIFY pgrst, 'reload schema';
