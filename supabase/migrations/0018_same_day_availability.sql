-- A booking only blocks the same calendar day, and only while its time
-- still overlaps and has not finished. Another day is free. Cancelled,
-- rejected, returned, and timed out bookings are free too.
DROP FUNCTION IF EXISTS public.room_time_is_taken(bigint, text, text, text);
DROP FUNCTION IF EXISTS public.taken_room_ids(text, text);

CREATE OR REPLACE FUNCTION public.taken_room_ids(
  p_start_of_activity text,
  p_end_of_activity text
)
RETURNS TABLE(room_id bigint)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  requested_start timestamp;
  requested_end timestamp;
  manila_now timestamp;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required.'
      USING ERRCODE = '42501';
  END IF;

  requested_start := p_start_of_activity::timestamp;
  requested_end := p_end_of_activity::timestamp;
  manila_now := timezone('Asia/Manila', clock_timestamp());

  IF requested_end <= requested_start THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT DISTINCT room_link.room_id
  FROM public.reservations AS reservation
  JOIN public.reservation_rooms AS room_link
    ON room_link.reservation_id = reservation.reservation_id
    OR EXISTS (
      SELECT 1
      FROM public.reservation_details AS detail
      WHERE detail.reservation_id = reservation.reservation_id
        AND detail.reservation_rooms_id = room_link.reservation_rooms_id
    )
  WHERE room_link.room_id IS NOT NULL
    AND (
      reservation."Date_of_Activity"::date = requested_start::date
      OR reservation."Start_of_activity"::date = requested_start::date
    )
    AND reservation."Start_of_activity"::time < requested_end::time
    AND reservation."End_of_Activity"::time > requested_start::time
    AND reservation."End_of_Activity" > manila_now
    AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%cancelled%'
    AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%canceled%'
    AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%rejected%'
    AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%denied%'
    AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%timed out%'
    AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%returned%'
    AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%void%';
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
  RETURN EXISTS (
    SELECT 1
    FROM public.taken_room_ids(p_start_of_activity, p_end_of_activity) AS taken
    WHERE taken.room_id = p_room_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.reserved_item_unit_ids(
  p_item_ids bigint[],
  p_start_of_activity text,
  p_end_of_activity text
)
RETURNS TABLE(item_id bigint, unit_id bigint)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  requested_start timestamp;
  requested_end timestamp;
  manila_now timestamp;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required.'
      USING ERRCODE = '42501';
  END IF;

  IF p_item_ids IS NULL OR cardinality(p_item_ids) = 0 THEN
    RETURN;
  END IF;

  requested_start := p_start_of_activity::timestamp;
  requested_end := p_end_of_activity::timestamp;
  manila_now := timezone('Asia/Manila', clock_timestamp());

  IF requested_end <= requested_start THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT item_link.item_id, unit_link.unit_id
  FROM public.reservation_item_units AS unit_link
  JOIN public.reservation_items AS item_link
    ON item_link.reservation_items_id = unit_link.reservation_items_id
  JOIN public.reservations AS reservation
    ON reservation.reservation_id = item_link.reservation_id
  WHERE item_link.item_id = ANY(p_item_ids)
    AND (
      reservation."Date_of_Activity"::date = requested_start::date
      OR reservation."Start_of_activity"::date = requested_start::date
    )
    AND reservation."Start_of_activity"::time < requested_end::time
    AND reservation."End_of_Activity"::time > requested_start::time
    AND reservation."End_of_Activity" > manila_now
    AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%cancelled%'
    AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%canceled%'
    AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%rejected%'
    AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%denied%'
    AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%timed out%'
    AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%returned%'
    AND lower(coalesce(reservation.overall_status, '')) NOT LIKE '%void%';
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

REVOKE ALL ON FUNCTION public.reserved_item_unit_ids(bigint[], text, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reserved_item_unit_ids(bigint[], text, text)
  TO authenticated, service_role;
ALTER FUNCTION public.reserved_item_unit_ids(bigint[], text, text)
  OWNER TO postgres;
