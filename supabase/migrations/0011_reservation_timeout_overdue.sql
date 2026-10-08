BEGIN;

CREATE INDEX IF NOT EXISTS reservations_pending_start_lifecycle_idx
  ON public.reservations ("Start_of_activity")
  WHERE lower(coalesce(overall_status, '')) IN (
    'pending approval',
    'pending office approvals',
    'pending_office_approvals',
    'pending',
    'processing',
    'waiting',
    'under review',
    'under_review'
  );

CREATE INDEX IF NOT EXISTS reservations_return_end_lifecycle_idx
  ON public.reservations ("End_of_Activity")
  WHERE lower(coalesce(overall_status, '')) IN (
    'approved',
    'completed',
    'confirmed',
    'to return',
    'overdue'
  );

CREATE OR REPLACE FUNCTION public.refresh_reservation_lifecycle_statuses()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  manila_now timestamp without time zone :=
    timezone('Asia/Manila', statement_timestamp());
BEGIN
  UPDATE public.reservations
  SET overall_status = 'Timed Out',
      updated_at = manila_now
  WHERE lower(coalesce(overall_status, '')) IN (
      'pending approval',
      'pending office approvals',
      'pending_office_approvals',
      'pending',
      'processing',
      'waiting',
      'under review',
      'under_review'
    )
    AND "Start_of_activity" IS NOT NULL
    AND "Start_of_activity" <= manila_now
    AND NOT (
      EXISTS (
        SELECT 1
        FROM public.reservation_approvals AS approval
        WHERE approval.reservation_id = reservations.reservation_id
      )
      AND NOT EXISTS (
        SELECT 1
        FROM public.reservation_approvals AS approval
        WHERE approval.reservation_id = reservations.reservation_id
          AND lower(coalesce(approval.status, '')) NOT IN (
            'approved',
            'completed',
            'complete',
            'accepted'
          )
      )
    );

  WITH timed_out_reservations AS (
    SELECT reservation_id
    FROM public.reservations
    WHERE lower(coalesce(overall_status, '')) = 'timed out'
      AND updated_at = manila_now
  ),
  released_units AS (
    UPDATE public.item_units AS unit
    SET status = 'available',
        updated_at = manila_now
    FROM public.reservation_item_units AS unit_link
    JOIN public.reservation_items AS item_link
      ON item_link.reservation_items_id = unit_link.reservation_items_id
    JOIN timed_out_reservations AS timed_out
      ON timed_out.reservation_id = item_link.reservation_id
    WHERE unit.unit_id = unit_link.unit_id
      AND lower(coalesce(unit.status, '')) = 'in_use'
    RETURNING unit.item_id
  ),
  affected_items AS (
    SELECT DISTINCT item_id FROM released_units
  )
  UPDATE public.items AS item
  SET quantity_in_use = (
    SELECT (count(*) FILTER (
      WHERE lower(coalesce(unit.status, '')) NOT IN (
        'available',
        'free',
        'ready',
        'active',
        'new',
        'in_stock',
        'instock'
      )
    ))::integer
    FROM public.item_units AS unit
    WHERE unit.item_id = item.item_id
  ),
      updated_at = manila_now
  FROM affected_items
  WHERE item.item_id = affected_items.item_id;

  UPDATE public.reservations
  SET overall_status = 'To Return',
      updated_at = manila_now
  WHERE lower(coalesce(overall_status, '')) NOT IN (
      'returned',
      'cancelled',
      'canceled',
      'rejected',
      'denied',
      'damaged',
      'timed out',
      'overdue',
      'to return'
    )
    AND "End_of_Activity" IS NOT NULL
    AND "End_of_Activity" <= manila_now
    AND (
      (
        lower(coalesce(overall_status, '')) IN (
          'approved',
          'completed',
          'complete',
          'confirmed'
        )
        AND NOT EXISTS (
          SELECT 1
          FROM public.reservation_approvals AS approval
          WHERE approval.reservation_id = reservations.reservation_id
            AND lower(coalesce(approval.status, '')) NOT IN (
              'approved',
              'completed',
              'complete',
              'accepted'
            )
        )
      )
      OR (
        EXISTS (
          SELECT 1
          FROM public.reservation_approvals AS approval
          WHERE approval.reservation_id = reservations.reservation_id
        )
        AND NOT EXISTS (
          SELECT 1
          FROM public.reservation_approvals AS approval
          WHERE approval.reservation_id = reservations.reservation_id
            AND lower(coalesce(approval.status, '')) NOT IN (
              'approved',
              'completed',
              'complete',
              'accepted'
            )
        )
      )
    );

  UPDATE public.reservations
  SET overall_status = 'Overdue',
      updated_at = manila_now
  WHERE lower(coalesce(overall_status, '')) = 'to return'
    AND "End_of_Activity" IS NOT NULL
    AND "End_of_Activity" <= manila_now - interval '24 hours';
END;
$$;

REVOKE ALL ON FUNCTION public.refresh_reservation_lifecycle_statuses()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_reservation_lifecycle_statuses()
  TO service_role;

CREATE OR REPLACE FUNCTION public.get_current_reservation_return_lock()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, private
AS $$
  SELECT CASE
    WHEN count(*) = 0 THEN NULL
    ELSE
      'Please accomplish return/settle your reservation:' || E'\n\n' ||
      string_agg(
        coalesce(nullif(trim(activity_name), ''), 'Reservation #' || reservation_id::text) ||
          ' (return deadline: ' ||
          CASE
            WHEN "End_of_Activity" IS NULL THEN 'overdue'
            ELSE to_char("End_of_Activity" + interval '24 hours', 'YYYY-MM-DD HH12:MI AM')
          END ||
          ')',
        E'\n'
        ORDER BY "End_of_Activity" NULLS FIRST, reservation_id
      )
  END
  FROM public.reservations
  WHERE user_id = private.current_profile_id()
    AND (
      lower(coalesce(overall_status, '')) = 'overdue'
      OR (
        lower(coalesce(overall_status, '')) NOT IN (
          'returned',
          'cancelled',
          'canceled',
          'rejected',
          'denied',
          'damaged',
          'timed out'
        )
        AND "End_of_Activity" IS NOT NULL
        AND "End_of_Activity" <=
          timezone('Asia/Manila', statement_timestamp()) - interval '24 hours'
        AND (
          lower(coalesce(overall_status, '')) IN (
            'approved',
            'completed',
            'complete',
            'confirmed',
            'to return'
          )
          OR (
            EXISTS (
              SELECT 1
              FROM public.reservation_approvals AS approval
              WHERE approval.reservation_id = reservations.reservation_id
            )
            AND NOT EXISTS (
              SELECT 1
              FROM public.reservation_approvals AS approval
              WHERE approval.reservation_id = reservations.reservation_id
                AND lower(coalesce(approval.status, '')) NOT IN (
                  'approved',
                  'completed',
                  'complete',
                  'accepted'
                )
            )
          )
        )
      )
    );
$$;

REVOKE ALL ON FUNCTION public.get_current_reservation_return_lock()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_current_reservation_return_lock()
  TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.block_reservation_when_overdue()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  manila_now timestamp without time zone :=
    timezone('Asia/Manila', statement_timestamp());
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.reservations AS existing
    WHERE existing.user_id = NEW.user_id
      AND (
        lower(coalesce(existing.overall_status, '')) = 'overdue'
        OR (
          lower(coalesce(existing.overall_status, '')) NOT IN (
            'returned',
            'cancelled',
            'canceled',
            'rejected',
            'denied',
            'damaged',
            'timed out'
          )
          AND existing."End_of_Activity" IS NOT NULL
          AND existing."End_of_Activity" <= manila_now - interval '24 hours'
          AND (
            lower(coalesce(existing.overall_status, '')) IN (
              'approved',
              'completed',
              'complete',
              'confirmed',
              'to return'
            )
            OR (
              EXISTS (
                SELECT 1
                FROM public.reservation_approvals AS approval
                WHERE approval.reservation_id = existing.reservation_id
              )
              AND NOT EXISTS (
                SELECT 1
                FROM public.reservation_approvals AS approval
                WHERE approval.reservation_id = existing.reservation_id
                  AND lower(coalesce(approval.status, '')) NOT IN (
                    'approved',
                    'completed',
                    'complete',
                    'accepted'
                  )
              )
            )
          )
        )
      )
  ) THEN
    RAISE EXCEPTION 'Please accomplish return/settle your reservation.'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.block_reservation_when_overdue()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS reservations_block_new_request_when_overdue
  ON public.reservations;
CREATE TRIGGER reservations_block_new_request_when_overdue
  BEFORE INSERT ON public.reservations
  FOR EACH ROW
  EXECUTE FUNCTION public.block_reservation_when_overdue();

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;

DO $$
DECLARE
  existing_job record;
BEGIN
  FOR existing_job IN
    SELECT jobid
    FROM cron.job
    WHERE jobname = 'nutilize-reservation-lifecycle'
  LOOP
    PERFORM cron.unschedule(existing_job.jobid);
  END LOOP;

  PERFORM cron.schedule(
    'nutilize-reservation-lifecycle',
    '* * * * *',
    'SELECT public.refresh_reservation_lifecycle_statuses();'
  );
END;
$$;

COMMIT;
