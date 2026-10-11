-- One shared answer for every account: which rooms are already booked
-- for this time. Pending and approved requests still block the overlap.
-- Cancelled, rejected, returned, and timed out requests do not.
-- 8:00-10:00 does not block a request that starts at 10:00 or later,
-- and it does not block the same hours on another date.
CREATE OR REPLACE FUNCTION public.taken_room_ids(
  p_start_of_activity text,
  p_end_of_activity text
)
RETURNS bigint[]
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  requested_start timestamp;
  requested_end timestamp;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required.'
      USING ERRCODE = '42501';
  END IF;

  requested_start := p_start_of_activity::timestamp;
  requested_end := p_end_of_activity::timestamp;

  IF requested_end <= requested_start THEN
    RETURN ARRAY[]::bigint[];
  END IF;

  RETURN COALESCE(
    ARRAY(
      SELECT DISTINCT room_link.room_id
      FROM public.reservations AS reservation
      JOIN public.reservation_rooms AS room_link
        ON room_link.reservation_id = reservation.reservation_id
      WHERE room_link.room_id IS NOT NULL
        AND reservation."Start_of_activity" < requested_end
        AND reservation."End_of_Activity" > requested_start
        AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%cancelled%'
        AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%canceled%'
        AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%rejected%'
        AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%denied%'
        AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%timed out%'
        AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%returned%'
        AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%void%'
    ),
    ARRAY[]::bigint[]
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.room_time_is_taken(
  p_room_id bigint,
  p_date_of_activity text,
  p_start_of_activity text,
  p_end_of_activity text
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
BEGIN
  RETURN p_room_id = ANY (
    public.taken_room_ids(p_start_of_activity, p_end_of_activity)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.taken_room_ids(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.taken_room_ids(text, text)
  TO authenticated, service_role;
ALTER FUNCTION public.taken_room_ids(text, text) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.room_time_is_taken(bigint, text, text, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.room_time_is_taken(bigint, text, text, text)
  TO authenticated, service_role;
ALTER FUNCTION public.room_time_is_taken(bigint, text, text, text)
  OWNER TO postgres;
