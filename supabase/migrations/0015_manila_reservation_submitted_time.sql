-- Store the moment a reservation is submitted as Manila wall-clock time.
-- created_at is timestamp without time zone, and now() was saving UTC.
CREATE OR REPLACE FUNCTION public.create_reservation_header(
  p_user_id bigint,
  p_activity_name text,
  p_date_of_activity text,
  p_start_of_activity text,
  p_end_of_activity text,
  p_outside_participants boolean,
  p_proof_of_consent_url text DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private, auth
AS $$
DECLARE
  created_reservation_id bigint;
  manila_now timestamp without time zone :=
    timezone('Asia/Manila', clock_timestamp());
BEGIN
  IF auth.uid() IS NULL OR p_user_id IS DISTINCT FROM private.current_profile_id() THEN
    RAISE EXCEPTION 'The authenticated user cannot create a reservation for this profile.'
      USING ERRCODE = '42501';
  END IF;

  IF p_date_of_activity::date < (current_date + 3) THEN
    RAISE EXCEPTION 'Reservations must be submitted at least two days before the activity date.'
      USING ERRCODE = '22023';
  END IF;

  EXECUTE format(
    'INSERT INTO public.reservations (
       user_id, activity_name, overall_status, %I, %I, %I,
       created_at, updated_at, outside_participants, proof_of_consent_url
     ) VALUES ($1, $2, $3, $4::timestamp, $5::timestamp, $6::timestamp,
       $9, $9, $7, $8)
     RETURNING reservation_id',
    'Date_of_Activity',
    'Start_of_activity',
    'End_of_Activity'
  )
  INTO created_reservation_id
  USING
    p_user_id,
    p_activity_name,
    'Pending Approval',
    p_date_of_activity,
    p_start_of_activity,
    p_end_of_activity,
    p_outside_participants,
    p_proof_of_consent_url,
    manila_now;

  RETURN created_reservation_id;
END;
$$;

-- Existing submitted times were stored in UTC. Shift them to Manila once.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_description AS description
    JOIN pg_proc AS procedure ON procedure.oid = description.objoid
    WHERE procedure.proname = 'create_reservation_header'
      AND description.description = 'manila-submitted-time-v1'
  ) THEN
    UPDATE public.reservations
    SET created_at = created_at + interval '8 hours'
    WHERE created_at IS NOT NULL;
  END IF;
END;
$$;

COMMENT ON FUNCTION public.create_reservation_header(
  bigint, text, text, text, text, boolean, text
) IS 'manila-submitted-time-v1';
