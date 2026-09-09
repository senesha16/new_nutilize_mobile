ALTER TABLE public.reservations
ADD COLUMN IF NOT EXISTS outside_participants boolean NOT NULL DEFAULT false;