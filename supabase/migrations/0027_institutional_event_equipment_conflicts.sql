BEGIN;

CREATE OR REPLACE FUNCTION public.institutional_event_item_availability(
  p_item_ids bigint[],
  p_start_of_activity text,
  p_end_of_activity text
)
RETURNS TABLE(item_id bigint, available_quantity bigint)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  requested_start timestamp without time zone;
  requested_end timestamp without time zone;
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
    RAISE EXCEPTION 'The requested equipment schedule is invalid.'
      USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  SELECT item.item_id, count(unit.unit_id)::bigint
  FROM public.items AS item
  LEFT JOIN public.item_units AS unit
    ON unit.item_id = item.item_id
    AND lower(trim(coalesce(unit.status, ''))) IN
      ('available', 'free', 'ready', 'active', 'new', 'in_stock', 'instock')
    AND NOT EXISTS (
      SELECT 1
      FROM public.reservation_item_units AS held
      JOIN public.reservation_items AS held_item
        ON held_item.reservation_items_id = held.reservation_items_id
      JOIN public.reservations AS held_reservation
        ON held_reservation.reservation_id = held_item.reservation_id
      LEFT JOIN public.institutional_event_equipment AS held_equipment
        ON held_equipment.reservation_items_id =
           held_item.reservation_items_id
      LEFT JOIN public.institutional_event_venues AS held_venue
        ON held_venue.event_venue_id = held_equipment.event_venue_id
      WHERE held.unit_id = unit.unit_id
        AND NOT (lower(coalesce(held_reservation.overall_status, '')) LIKE
          ANY (ARRAY['%cancelled%', '%canceled%', '%rejected%', '%denied%',
                     '%timed out%', '%returned%', '%void%']))
        AND (
          (
            held_equipment.event_equipment_id IS NOT NULL
            AND held_equipment.status = 'included'
            AND held_venue.status = 'included'
            AND held_venue.start_time < requested_end
            AND held_venue.end_time > requested_start
          )
          OR (
            held_equipment.event_equipment_id IS NULL
            AND NOT EXISTS (
              SELECT 1
              FROM public.institutional_event_requests AS held_event
              WHERE held_event.reservation_id =
                held_reservation.reservation_id
            )
            AND held_reservation."Start_of_activity" < requested_end
            AND held_reservation."End_of_Activity" > requested_start
          )
        )
    )
  WHERE item.item_id = ANY(p_item_ids)
    AND item.availability_status
    AND NOT item.maintenance_status
  GROUP BY item.item_id;
END;
$$;

REVOKE ALL ON FUNCTION public.institutional_event_item_availability(
  bigint[], text, text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.institutional_event_item_availability(
  bigint[], text, text
) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION private.serialize_institutional_event_equipment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private
AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.institutional_event_requests AS event_request
    WHERE event_request.reservation_id = NEW.reservation_id
  ) THEN
    PERFORM pg_advisory_xact_lock(863621110027::bigint);
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.serialize_institutional_event_equipment()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS institutional_event_equipment_allocation_lock
  ON public.reservation_items;
CREATE TRIGGER institutional_event_equipment_allocation_lock
  BEFORE INSERT ON public.reservation_items
  FOR EACH ROW
  EXECUTE FUNCTION private.serialize_institutional_event_equipment();

COMMIT;
