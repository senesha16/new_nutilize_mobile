-- Lets a student see whether a room is already taken without reading
-- another person's reservation. Pending and approved bookings still block
-- the overlapping time. Rejected, cancelled, and finished times do not.
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
DECLARE
  requested_date date;
  requested_start timestamp;
  requested_end timestamp;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required.'
      USING ERRCODE = '42501';
  END IF;

  requested_date := p_date_of_activity::timestamp::date;
  requested_start := p_start_of_activity::timestamp;
  requested_end := p_end_of_activity::timestamp;

  IF requested_end <= requested_start THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.reservations AS reservation
    JOIN public.reservation_details AS detail
      ON detail.reservation_id = reservation.reservation_id
    JOIN public.reservation_rooms AS room_link
      ON room_link.reservation_rooms_id = detail.reservation_rooms_id
    WHERE room_link.room_id = p_room_id
      AND reservation."Date_of_Activity"::date = requested_date
      AND reservation."Start_of_activity" < requested_end
      AND reservation."End_of_Activity" > requested_start
      AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%cancelled%'
      AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%canceled%'
      AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%rejected%'
      AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%denied%'
      AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%timed out%'
      AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%returned%'
      AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%void%'
      AND NOT EXISTS (
        SELECT 1
        FROM public.reservation_approvals AS approval
        WHERE approval.reservation_id = reservation.reservation_id
          AND (
            lower(coalesce(approval.status, '')) LIKE '%rejected%'
            OR lower(coalesce(approval.status, '')) LIKE '%denied%'
            OR lower(coalesce(approval.status, '')) LIKE '%cancel%'
          )
      )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.room_time_is_taken(bigint, text, text, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.room_time_is_taken(bigint, text, text, text)
  TO authenticated, service_role;
