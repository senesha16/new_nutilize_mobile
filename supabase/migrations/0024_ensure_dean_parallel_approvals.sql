BEGIN;

CREATE OR REPLACE FUNCTION private.ensure_dean_parallel_approval()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private
AS $$
BEGIN
  IF current_setting('nutilize.syncing_dean_approval', true) = 'on' THEN
    RETURN NULL;
  END IF;

  PERFORM set_config('nutilize.syncing_dean_approval', 'on', true);

  INSERT INTO public.reservation_approvals (
    reservation_id,
    office_id,
    approval_stage,
    status,
    created_at,
    updated_at
  )
  SELECT DISTINCT ON (chair.reservation_id)
    chair.reservation_id,
    dean_office.office_id,
    'dean',
    chair.status,
    chair.created_at,
    chair.updated_at
  FROM inserted_approvals AS chair
  JOIN public.reservations AS reservation
    ON reservation.reservation_id = chair.reservation_id
  JOIN public.users AS requester
    ON requester.user_id = reservation.user_id
  JOIN public.dean_program_assignments AS assignment
    ON assignment.program_id =
       private.program_id_for_affiliation(requester.affiliation)
  JOIN public.dean_role_offices AS dean_office
    ON dean_office.dean_role = assignment.dean_role
  WHERE chair.approval_stage = 'program_chair'
    AND lower(chair.status) IN ('pending', 'waiting')
    AND NOT private.is_program_chair_profile(requester.user_id)
    AND NOT private.is_dean_profile(requester.user_id)
    AND NOT EXISTS (
      SELECT 1
      FROM public.reservation_approvals AS existing_dean
      WHERE existing_dean.reservation_id = chair.reservation_id
        AND existing_dean.approval_stage = 'dean'
    )
  ORDER BY chair.reservation_id, chair.created_at, chair.approval_id
  ON CONFLICT (reservation_id) WHERE approval_stage = 'dean'
  DO NOTHING;

  PERFORM set_config('nutilize.syncing_dean_approval', 'off', true);

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS reservation_approvals_ensure_dean_peer
  ON public.reservation_approvals;
CREATE TRIGGER reservation_approvals_ensure_dean_peer
  AFTER INSERT ON public.reservation_approvals
  REFERENCING NEW TABLE AS inserted_approvals
  FOR EACH STATEMENT
  EXECUTE FUNCTION private.ensure_dean_parallel_approval();

INSERT INTO public.reservation_approvals (
  reservation_id,
  office_id,
  approval_stage,
  status,
  created_at,
  updated_at
)
SELECT DISTINCT ON (chair.reservation_id)
  chair.reservation_id,
  dean_office.office_id,
  'dean',
  chair.status,
  chair.created_at,
  chair.updated_at
FROM public.reservation_approvals AS chair
JOIN public.reservations AS reservation
  ON reservation.reservation_id = chair.reservation_id
JOIN public.users AS requester
  ON requester.user_id = reservation.user_id
JOIN public.dean_program_assignments AS assignment
  ON assignment.program_id =
     private.program_id_for_affiliation(requester.affiliation)
JOIN public.dean_role_offices AS dean_office
  ON dean_office.dean_role = assignment.dean_role
WHERE chair.approval_stage = 'program_chair'
  AND lower(chair.status) IN ('pending', 'waiting')
  AND NOT private.is_program_chair_profile(requester.user_id)
  AND NOT private.is_dean_profile(requester.user_id)
  AND NOT EXISTS (
    SELECT 1
    FROM public.reservation_approvals AS existing_dean
    WHERE existing_dean.reservation_id = chair.reservation_id
      AND existing_dean.approval_stage = 'dean'
  )
ORDER BY chair.reservation_id, chair.created_at, chair.approval_id
ON CONFLICT (reservation_id) WHERE approval_stage = 'dean'
DO NOTHING;

COMMIT;
