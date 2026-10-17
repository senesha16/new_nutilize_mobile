BEGIN;

CREATE OR REPLACE FUNCTION private.guard_reservation_room_schedule()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private
AS $$
DECLARE
  requested_start timestamp without time zone;
  requested_end timestamp without time zone;
BEGIN
  IF NEW.room_id IS NULL THEN
    RETURN NEW;
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended('nutilize:room:' || NEW.room_id::text, 0)
  );

  IF EXISTS (
    SELECT 1
    FROM public.institutional_event_requests AS event_request
    WHERE event_request.reservation_id = NEW.reservation_id
  ) THEN
    RETURN NEW;
  END IF;

  SELECT reservation."Start_of_activity", reservation."End_of_Activity"
  INTO requested_start, requested_end
  FROM public.reservations AS reservation
  WHERE reservation.reservation_id = NEW.reservation_id;

  IF requested_start IS NULL
     OR requested_end IS NULL
     OR requested_end <= requested_start THEN
    RAISE EXCEPTION 'The reservation needs a valid start and end time.'
      USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.reservation_rooms AS existing_room
    JOIN public.reservations AS existing_reservation
      ON existing_reservation.reservation_id = existing_room.reservation_id
    WHERE existing_room.room_id = NEW.room_id
      AND existing_room.reservation_id <> NEW.reservation_id
      AND NOT EXISTS (
        SELECT 1
        FROM public.institutional_event_requests AS event_request
        WHERE event_request.reservation_id =
          existing_reservation.reservation_id
      )
      AND existing_reservation."Start_of_activity" < requested_end
      AND existing_reservation."End_of_Activity" > requested_start
      AND lower(coalesce(existing_reservation.overall_status, '')) NOT LIKE
        ANY (ARRAY['%cancelled%', '%canceled%', '%rejected%', '%denied%',
                   '%timed out%', '%returned%', '%void%'])
  ) OR EXISTS (
    SELECT 1
    FROM public.institutional_event_venues AS existing_venue
    JOIN public.reservations AS existing_reservation
      ON existing_reservation.reservation_id =
         existing_venue.reservation_id
    WHERE existing_venue.room_id = NEW.room_id
      AND existing_venue.reservation_id <> NEW.reservation_id
      AND existing_venue.status = 'included'
      AND existing_venue.start_time < requested_end
      AND existing_venue.end_time > requested_start
      AND lower(coalesce(existing_reservation.overall_status, '')) NOT LIKE
        ANY (ARRAY['%cancelled%', '%canceled%', '%rejected%', '%denied%',
                   '%timed out%', '%returned%', '%void%'])
  ) THEN
    RAISE EXCEPTION
      'This room is already reserved for an overlapping time. Choose a different date or time.'
      USING ERRCODE = '23P01';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.guard_institutional_event_venue_schedule()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private
AS $$
BEGIN
  PERFORM pg_advisory_xact_lock(
    hashtextextended('nutilize:room:' || NEW.room_id::text, 0)
  );

  IF NEW.status <> 'included' THEN
    RETURN NEW;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.reservation_rooms AS existing_room
    JOIN public.reservations AS existing_reservation
      ON existing_reservation.reservation_id = existing_room.reservation_id
    WHERE existing_room.room_id = NEW.room_id
      AND existing_room.reservation_id <> NEW.reservation_id
      AND NOT EXISTS (
        SELECT 1
        FROM public.institutional_event_requests AS event_request
        WHERE event_request.reservation_id =
          existing_reservation.reservation_id
      )
      AND existing_reservation."Start_of_activity" < NEW.end_time
      AND existing_reservation."End_of_Activity" > NEW.start_time
      AND lower(coalesce(existing_reservation.overall_status, '')) NOT LIKE
        ANY (ARRAY['%cancelled%', '%canceled%', '%rejected%', '%denied%',
                   '%timed out%', '%returned%', '%void%'])
  ) OR EXISTS (
    SELECT 1
    FROM public.institutional_event_venues AS existing_venue
    JOIN public.reservations AS existing_reservation
      ON existing_reservation.reservation_id =
         existing_venue.reservation_id
    WHERE existing_venue.room_id = NEW.room_id
      AND existing_venue.reservation_id <> NEW.reservation_id
      AND existing_venue.status = 'included'
      AND existing_venue.start_time < NEW.end_time
      AND existing_venue.end_time > NEW.start_time
      AND lower(coalesce(existing_reservation.overall_status, '')) NOT LIKE
        ANY (ARRAY['%cancelled%', '%canceled%', '%rejected%', '%denied%',
                   '%timed out%', '%returned%', '%void%'])
  ) THEN
    RAISE EXCEPTION
      'This venue is already reserved for an overlapping time. Choose a different date or time.'
      USING ERRCODE = '23P01';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.guard_reservation_header_schedule()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private
AS $$
DECLARE
  room_record record;
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.institutional_event_requests AS event_request
    WHERE event_request.reservation_id = NEW.reservation_id
  ) THEN
    RETURN NEW;
  END IF;

  IF NEW."Start_of_activity" IS NULL
     OR NEW."End_of_Activity" IS NULL
     OR NEW."End_of_Activity" <= NEW."Start_of_activity" THEN
    RAISE EXCEPTION 'The reservation needs a valid start and end time.'
      USING ERRCODE = '22023';
  END IF;

  FOR room_record IN
    SELECT room_link.room_id
    FROM public.reservation_rooms AS room_link
    WHERE room_link.reservation_id = NEW.reservation_id
      AND room_link.room_id IS NOT NULL
    ORDER BY room_link.room_id
  LOOP
    PERFORM pg_advisory_xact_lock(
      hashtextextended('nutilize:room:' || room_record.room_id::text, 0)
    );

    IF EXISTS (
      SELECT 1
      FROM public.reservation_rooms AS existing_room
      JOIN public.reservations AS existing_reservation
        ON existing_reservation.reservation_id = existing_room.reservation_id
      WHERE existing_room.room_id = room_record.room_id
        AND existing_room.reservation_id <> NEW.reservation_id
        AND NOT EXISTS (
          SELECT 1
          FROM public.institutional_event_requests AS event_request
          WHERE event_request.reservation_id =
            existing_reservation.reservation_id
        )
        AND existing_reservation."Start_of_activity" < NEW."End_of_Activity"
        AND existing_reservation."End_of_Activity" > NEW."Start_of_activity"
        AND lower(coalesce(existing_reservation.overall_status, '')) NOT LIKE
          ANY (ARRAY['%cancelled%', '%canceled%', '%rejected%', '%denied%',
                     '%timed out%', '%returned%', '%void%'])
    ) OR EXISTS (
      SELECT 1
      FROM public.institutional_event_venues AS existing_venue
      JOIN public.reservations AS existing_reservation
        ON existing_reservation.reservation_id =
           existing_venue.reservation_id
      WHERE existing_venue.room_id = room_record.room_id
        AND existing_venue.reservation_id <> NEW.reservation_id
        AND existing_venue.status = 'included'
        AND existing_venue.start_time < NEW."End_of_Activity"
        AND existing_venue.end_time > NEW."Start_of_activity"
        AND lower(coalesce(existing_reservation.overall_status, '')) NOT LIKE
          ANY (ARRAY['%cancelled%', '%canceled%', '%rejected%', '%denied%',
                     '%timed out%', '%returned%', '%void%'])
    ) THEN
      RAISE EXCEPTION
        'This room is already reserved for an overlapping time. Choose a different date or time.'
        USING ERRCODE = '23P01';
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.guard_reservation_room_schedule()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.guard_institutional_event_venue_schedule()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.guard_reservation_header_schedule()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS reservation_rooms_guard_schedule_conflict
  ON public.reservation_rooms;
CREATE TRIGGER reservation_rooms_guard_schedule_conflict
  BEFORE INSERT OR UPDATE OF room_id ON public.reservation_rooms
  FOR EACH ROW
  EXECUTE FUNCTION private.guard_reservation_room_schedule();

DROP TRIGGER IF EXISTS institutional_event_venues_guard_schedule_conflict
  ON public.institutional_event_venues;
CREATE TRIGGER institutional_event_venues_guard_schedule_conflict
  BEFORE INSERT OR UPDATE OF room_id, start_time, end_time, status
  ON public.institutional_event_venues
  FOR EACH ROW
  EXECUTE FUNCTION private.guard_institutional_event_venue_schedule();

DROP TRIGGER IF EXISTS reservations_guard_schedule_conflict
  ON public.reservations;
CREATE TRIGGER reservations_guard_schedule_conflict
  BEFORE UPDATE OF "Start_of_activity", "End_of_Activity"
  ON public.reservations
  FOR EACH ROW
  EXECUTE FUNCTION private.guard_reservation_header_schedule();

COMMIT;
