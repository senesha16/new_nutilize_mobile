-- Students cannot read one another's reservations, so equipment stock
-- calculated in the app only saw the current account. This returns the
-- unit ids already held for an overlapping time, without the reservation.
-- Pending and approved bookings still hold the units. Rejected, cancelled,
-- timed out, and returned bookings do not. A later time on the same day
-- does not overlap.
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
          OR lower(coalesce(approval.status, '')) LIKE '%returned%'
          OR lower(coalesce(approval.status, '')) LIKE '%timed out%'
        )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.reserved_item_unit_ids(bigint[], text, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reserved_item_unit_ids(bigint[], text, text)
  TO authenticated, service_role;

ALTER FUNCTION public.reserved_item_unit_ids(bigint[], text, text)
  OWNER TO postgres;
