BEGIN;

INSERT INTO public.offices (
  department_name,
  officer_name,
  short_code,
  order_sequence
)
SELECT office.department_name, office.officer_name, office.short_code, 2
FROM (
  VALUES
    ('Dean of SACE', 'Dean of SACE', 'DEAN_SACE'),
    ('Dean of SABM', 'Dean of SABM', 'DEAN_SABM'),
    ('Dean of SAHS', 'Dean of SAHS', 'DEAN_SAHS')
) AS office(department_name, officer_name, short_code)
WHERE NOT EXISTS (
  SELECT 1
  FROM public.offices AS existing
  WHERE lower(existing.short_code) = lower(office.short_code)
     OR lower(trim(existing.department_name)) =
        lower(trim(office.department_name))
);

CREATE TABLE IF NOT EXISTS public.dean_role_offices (
  dean_role text PRIMARY KEY
    CHECK (dean_role IN ('dean_sace', 'dean_sabm', 'dean_sahs')),
  office_id bigint NOT NULL UNIQUE
    REFERENCES public.offices(office_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS public.dean_program_assignments (
  program_id bigint PRIMARY KEY
    REFERENCES public.academic_programs(program_id) ON DELETE RESTRICT,
  dean_role text NOT NULL
    REFERENCES public.dean_role_offices(dean_role) ON DELETE RESTRICT
);

INSERT INTO public.dean_role_offices (dean_role, office_id)
SELECT mapping.dean_role, office.office_id
FROM (
  VALUES
    ('dean_sace', 'DEAN_SACE'),
    ('dean_sabm', 'DEAN_SABM'),
    ('dean_sahs', 'DEAN_SAHS')
) AS mapping(dean_role, short_code)
JOIN public.offices AS office
  ON lower(office.short_code) = lower(mapping.short_code)
ON CONFLICT (dean_role) DO UPDATE
SET office_id = EXCLUDED.office_id;

INSERT INTO public.dean_program_assignments (program_id, dean_role)
VALUES
  (1, 'dean_sace'),
  (2, 'dean_sace'),
  (3, 'dean_sace'),
  (4, 'dean_sace'),
  (5, 'dean_sace'),
  (6, 'dean_sace'),
  (7, 'dean_sabm'),
  (8, 'dean_sabm'),
  (9, 'dean_sabm'),
  (10, 'dean_sabm'),
  (11, 'dean_sabm'),
  (12, 'dean_sahs'),
  (13, 'dean_sahs'),
  (14, 'dean_sahs')
ON CONFLICT (program_id) DO UPDATE
SET dean_role = EXCLUDED.dean_role;

ALTER TABLE public.dean_role_offices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dean_program_assignments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS dean_role_offices_select_authenticated
  ON public.dean_role_offices;
CREATE POLICY dean_role_offices_select_authenticated
  ON public.dean_role_offices FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS dean_program_assignments_select_authenticated
  ON public.dean_program_assignments;
CREATE POLICY dean_program_assignments_select_authenticated
  ON public.dean_program_assignments FOR SELECT TO authenticated
  USING (true);

GRANT SELECT ON public.dean_role_offices, public.dean_program_assignments
  TO authenticated, service_role;

ALTER TABLE public.reservation_approvals
  DROP CONSTRAINT IF EXISTS reservation_approvals_approval_stage_check;
ALTER TABLE public.reservation_approvals
  ADD CONSTRAINT reservation_approvals_approval_stage_check
  CHECK (approval_stage IN ('faculty', 'office', 'program_chair', 'dean'));

CREATE INDEX IF NOT EXISTS reservation_approvals_dean_queue_idx
  ON public.reservation_approvals (office_id, status, created_at)
  WHERE approval_stage = 'dean';

CREATE UNIQUE INDEX IF NOT EXISTS reservation_approvals_single_dean_idx
  ON public.reservation_approvals (reservation_id)
  WHERE approval_stage = 'dean';

CREATE OR REPLACE FUNCTION private.is_dean_profile(target_user_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users AS profile
    JOIN public.dean_role_offices AS dean_office
      ON dean_office.dean_role = lower(profile.role)
     AND dean_office.office_id = profile.office_id
    WHERE profile.user_id = target_user_id
      AND profile.is_active
  );
$$;

CREATE OR REPLACE FUNCTION private.validate_dean_assignment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private
AS $$
DECLARE
  requester_id bigint;
  requester_affiliation text;
  requester_program_id bigint;
  expected_dean_office_id bigint;
BEGIN
  IF NEW.approval_stage <> 'dean' THEN
    RETURN NEW;
  END IF;

  SELECT reservation.user_id, requester.affiliation
  INTO requester_id, requester_affiliation
  FROM public.reservations AS reservation
  JOIN public.users AS requester
    ON requester.user_id = reservation.user_id
  WHERE reservation.reservation_id = NEW.reservation_id;

  IF requester_id IS NULL
     OR private.is_dean_profile(requester_id) THEN
    RAISE EXCEPTION
      'Dean approval is only used for requests submitted by students, faculty, or Program Chairs.'
      USING ERRCODE = '22023';
  END IF;

  requester_program_id :=
    private.program_id_for_affiliation(requester_affiliation);

  SELECT dean_office.office_id
  INTO expected_dean_office_id
  FROM public.dean_program_assignments AS assignment
  JOIN public.dean_role_offices AS dean_office
    ON dean_office.dean_role = assignment.dean_role
  WHERE assignment.program_id = requester_program_id;

  IF expected_dean_office_id IS NULL
     OR NEW.office_id IS DISTINCT FROM expected_dean_office_id THEN
    RAISE EXCEPTION
      'The Dean approval office does not match the requester program.'
      USING ERRCODE = '22023';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS reservation_approvals_validate_dean
  ON public.reservation_approvals;
CREATE TRIGGER reservation_approvals_validate_dean
  BEFORE INSERT OR UPDATE OF approval_stage, office_id, reservation_id
  ON public.reservation_approvals
  FOR EACH ROW
  EXECUTE FUNCTION private.validate_dean_assignment();

CREATE OR REPLACE FUNCTION private.can_access_reservation(
  target_reservation_id bigint
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, private, auth
AS $$
  SELECT private.is_global_admin()
    OR private.owns_reservation(target_reservation_id)
    OR EXISTS (
      SELECT 1
      FROM public.reservation_approvals AS active_approval
      WHERE active_approval.reservation_id = target_reservation_id
        AND active_approval.approver_user_id = private.current_profile_id()
    )
    OR (
      private.faculty_approval_is_complete(target_reservation_id)
      AND EXISTS (
        SELECT 1
        FROM public.reservation_approvals AS active_approval
        WHERE active_approval.reservation_id = target_reservation_id
          AND lower(active_approval.status) IN (
            'pending', 'condition accepted', 'condition rejected'
          )
          AND (
            (
              active_approval.office_id = private.current_profile_office_id()
              AND private.is_assigned_approver(
                active_approval.office_id,
                active_approval.owner_id
              )
            )
            OR EXISTS (
              SELECT 1
              FROM public.item_owners AS owner
              WHERE owner.owner_id = active_approval.owner_id
                AND owner.user_id = private.current_profile_id()
            )
          )
          AND NOT EXISTS (
            SELECT 1
            FROM public.reservation_approvals AS earlier_approval
            WHERE earlier_approval.reservation_id =
                  active_approval.reservation_id
              AND (earlier_approval.created_at, earlier_approval.approval_id)
                < (active_approval.created_at, active_approval.approval_id)
              AND lower(earlier_approval.status) NOT IN (
                'approved', 'accepted', 'completed', 'complete'
              )
              AND NOT (
                earlier_approval.created_at = active_approval.created_at
                AND (
                  (
                    earlier_approval.approval_stage = 'program_chair'
                    AND active_approval.approval_stage = 'dean'
                  )
                  OR (
                    earlier_approval.approval_stage = 'dean'
                    AND active_approval.approval_stage = 'program_chair'
                  )
                )
              )
          )
      )
    );
$$;

CREATE OR REPLACE FUNCTION private.advance_reservation_approval()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  next_created_at timestamp without time zone;
BEGIN
  IF lower(NEW.status) <> 'approved'
     OR lower(OLD.status) NOT IN (
       'pending', 'condition accepted', 'condition rejected'
     ) THEN
    RETURN NEW;
  END IF;

  SELECT approval.created_at
  INTO next_created_at
  FROM public.reservation_approvals AS approval
  WHERE approval.reservation_id = NEW.reservation_id
    AND lower(approval.status) = 'waiting'
    AND (approval.created_at, approval.approval_id)
      > (NEW.created_at, NEW.approval_id)
  ORDER BY approval.created_at, approval.approval_id
  LIMIT 1
  FOR UPDATE;

  IF next_created_at IS NOT NULL THEN
    UPDATE public.reservation_approvals
    SET status = 'Pending',
        updated_at = now()
    WHERE reservation_id = NEW.reservation_id
      AND created_at = next_created_at
      AND lower(status) = 'waiting';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.activate_first_reservation_approval_group()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  target_reservation_id bigint;
  first_waiting_at timestamp without time zone;
BEGIN
  FOR target_reservation_id IN
    SELECT DISTINCT inserted.reservation_id
    FROM inserted_approvals AS inserted
  LOOP
    IF EXISTS (
      SELECT 1
      FROM public.reservation_approvals AS approval
      WHERE approval.reservation_id = target_reservation_id
        AND lower(approval.status) = 'pending'
    ) THEN
      CONTINUE;
    END IF;

    SELECT approval.created_at
    INTO first_waiting_at
    FROM public.reservation_approvals AS approval
    WHERE approval.reservation_id = target_reservation_id
      AND lower(approval.status) = 'waiting'
    ORDER BY approval.created_at, approval.approval_id
    LIMIT 1;

    IF first_waiting_at IS NOT NULL THEN
      UPDATE public.reservation_approvals
      SET status = 'Pending',
          updated_at = now()
      WHERE reservation_id = target_reservation_id
        AND created_at = first_waiting_at
        AND lower(status) = 'waiting';
    END IF;
  END LOOP;

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS reservation_approvals_activate_first_group
  ON public.reservation_approvals;
CREATE TRIGGER reservation_approvals_activate_first_group
  AFTER INSERT ON public.reservation_approvals
  REFERENCING NEW TABLE AS inserted_approvals
  FOR EACH STATEMENT
  EXECUTE FUNCTION private.activate_first_reservation_approval_group();

CREATE OR REPLACE FUNCTION public.respond_to_program_chair_approval(
  p_approval_id bigint,
  p_decision text,
  p_message text DEFAULT NULL,
  p_rejection_reason text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private, auth
AS $$
DECLARE
  current_user_id bigint;
  target_reservation_id bigint;
  chair_approval public.reservation_approvals%ROWTYPE;
  normalized_decision text := lower(trim(coalesce(p_decision, '')));
  normalized_message text := trim(coalesce(p_message, ''));
  reason text := trim(coalesce(p_rejection_reason, ''));
BEGIN
  current_user_id := private.current_profile_id();

  IF auth.uid() IS NULL
     OR current_user_id IS NULL
     OR NOT private.is_program_chair_profile(current_user_id) THEN
    RAISE EXCEPTION 'Only an active program chair assigned to a program may respond.'
      USING ERRCODE = '42501';
  END IF;

  IF normalized_decision NOT IN ('approve', 'reject', 'reconsider') THEN
    RAISE EXCEPTION 'Decision must be approve, reject, or reconsider.'
      USING ERRCODE = '22023';
  END IF;

  IF normalized_decision = 'reconsider'
     AND (normalized_message = '' OR length(normalized_message) > 1000) THEN
    RAISE EXCEPTION 'A reconsideration message between 1 and 1000 characters is required.'
      USING ERRCODE = '22023';
  END IF;

  IF normalized_decision = 'reject'
     AND (reason = '' OR length(reason) > 500) THEN
    RAISE EXCEPTION 'A rejection reason between 1 and 500 characters is required.'
      USING ERRCODE = '22023';
  END IF;

  SELECT approval.reservation_id
  INTO target_reservation_id
  FROM public.reservation_approvals AS approval
  WHERE approval.approval_id = p_approval_id;

  IF target_reservation_id IS NULL THEN
    RAISE EXCEPTION 'This approval does not exist.'
      USING ERRCODE = '42501';
  END IF;

  PERFORM 1
  FROM public.reservations AS reservation
  WHERE reservation.reservation_id = target_reservation_id
  FOR UPDATE;

  SELECT approval.*
  INTO chair_approval
  FROM public.reservation_approvals AS approval
  JOIN public.reservations AS reservation
    ON reservation.reservation_id = approval.reservation_id
  JOIN public.users AS requester
    ON requester.user_id = reservation.user_id
  JOIN public.academic_programs AS program
    ON program.program_id =
       private.program_id_for_affiliation(requester.affiliation)
  WHERE approval.approval_id = p_approval_id
    AND approval.approval_stage = 'program_chair'
    AND approval.office_id = program.office_id
    AND program.program_id = (
      SELECT profile.program_id
      FROM public.users AS profile
      WHERE profile.user_id = current_user_id
    )
    AND lower(approval.status) IN (
      'pending', 'condition accepted', 'condition rejected'
    )
  FOR UPDATE OF approval;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'This request is not assigned to your program or is no longer awaiting your decision.'
      USING ERRCODE = '42501';
  END IF;

  IF normalized_decision = 'reconsider' THEN
    IF lower(chair_approval.status) <> 'pending' THEN
      RAISE EXCEPTION 'A reconsideration can only be requested before the final chair decision.'
        USING ERRCODE = '22023';
    END IF;

    UPDATE public.reservation_approvals
    SET status = 'Cancelled',
        updated_at = now()
    WHERE reservation_id = chair_approval.reservation_id
      AND approval_stage = 'dean'
      AND created_at = chair_approval.created_at
      AND lower(status) IN ('pending', 'waiting');

    UPDATE public.reservation_approvals
    SET status = 'Condition Requested',
        reconsideration_message = normalized_message,
        requester_condition_response = NULL,
        condition_responded_at = NULL,
        updated_at = now()
    WHERE approval_id = chair_approval.approval_id;
    RETURN true;
  END IF;

  UPDATE public.reservation_approvals
  SET status = 'Cancelled',
      updated_at = now()
  WHERE reservation_id = chair_approval.reservation_id
    AND approval_stage = 'dean'
    AND created_at = chair_approval.created_at
    AND lower(status) IN ('pending', 'waiting');

  UPDATE public.reservation_approvals
  SET status = CASE
        WHEN normalized_decision = 'approve' THEN 'Approved'
        ELSE 'Rejected'
      END,
      approved_at = current_date,
      approved_by_user_id = current_user_id,
      rejection_reason = CASE
        WHEN normalized_decision = 'reject' THEN reason
        ELSE NULL
      END,
      updated_at = now()
  WHERE approval_id = chair_approval.approval_id;

  IF normalized_decision = 'reject' THEN
    UPDATE public.reservations
    SET overall_status = 'Rejected',
        updated_at = now()
    WHERE reservation_id = chair_approval.reservation_id;

    UPDATE public.reservation_approvals
    SET status = 'Cancelled',
        updated_at = now()
    WHERE reservation_id = chair_approval.reservation_id
      AND approval_id <> chair_approval.approval_id
      AND lower(status) IN (
        'pending', 'waiting', 'condition requested',
        'condition accepted', 'condition rejected'
      );
  END IF;

  RETURN true;
END;
$$;

DROP FUNCTION IF EXISTS public.respond_to_dean_approval(bigint, text, text);
CREATE OR REPLACE FUNCTION public.respond_to_dean_approval(
  p_approval_id bigint,
  p_decision text,
  p_rejection_reason text DEFAULT NULL,
  p_message text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private, auth
AS $$
DECLARE
  current_user_id bigint;
  current_role text;
  current_office_id bigint;
  target_reservation_id bigint;
  dean_approval public.reservation_approvals%ROWTYPE;
  normalized_decision text := lower(trim(coalesce(p_decision, '')));
  normalized_message text := trim(coalesce(p_message, ''));
  reason text := trim(coalesce(p_rejection_reason, ''));
BEGIN
  current_user_id := private.current_profile_id();

  SELECT lower(profile.role), profile.office_id
  INTO current_role, current_office_id
  FROM public.users AS profile
  WHERE profile.user_id = current_user_id
    AND profile.is_active;

  IF auth.uid() IS NULL
     OR current_user_id IS NULL
     OR (
       current_role <> 'dean'
       AND NOT private.is_dean_profile(current_user_id)
     ) THEN
    RAISE EXCEPTION 'Only an active Dean assigned to this school may respond.'
      USING ERRCODE = '42501';
  END IF;

  IF normalized_decision NOT IN ('approve', 'reject', 'reconsider') THEN
    RAISE EXCEPTION 'Decision must be approve, reject, or reconsider.'
      USING ERRCODE = '22023';
  END IF;

  IF normalized_decision = 'reconsider'
     AND (normalized_message = '' OR length(normalized_message) > 1000) THEN
    RAISE EXCEPTION 'A reconsideration message between 1 and 1000 characters is required.'
      USING ERRCODE = '22023';
  END IF;

  IF normalized_decision = 'reject'
     AND (reason = '' OR length(reason) > 500) THEN
    RAISE EXCEPTION 'A rejection reason between 1 and 500 characters is required.'
      USING ERRCODE = '22023';
  END IF;

  SELECT approval.reservation_id
  INTO target_reservation_id
  FROM public.reservation_approvals AS approval
  WHERE approval.approval_id = p_approval_id;

  IF target_reservation_id IS NULL THEN
    RAISE EXCEPTION 'This approval does not exist.'
      USING ERRCODE = '42501';
  END IF;

  PERFORM 1
  FROM public.reservations AS reservation
  WHERE reservation.reservation_id = target_reservation_id
  FOR UPDATE;

  SELECT approval.*
  INTO dean_approval
  FROM public.reservation_approvals AS approval
  JOIN public.reservations AS reservation
    ON reservation.reservation_id = approval.reservation_id
  JOIN public.users AS requester
    ON requester.user_id = reservation.user_id
  LEFT JOIN public.dean_program_assignments AS assignment
    ON assignment.program_id =
       private.program_id_for_affiliation(requester.affiliation)
  LEFT JOIN public.dean_role_offices AS dean_office
    ON dean_office.dean_role = assignment.dean_role
  WHERE approval.approval_id = p_approval_id
    AND approval.office_id = current_office_id
    AND lower(approval.status) IN (
      'pending', 'condition accepted', 'condition rejected'
    )
    AND (
      (
        current_role = 'dean'
        AND approval.approval_stage = 'office'
      )
      OR (
        private.is_dean_profile(current_user_id)
        AND approval.approval_stage = 'dean'
        AND dean_office.office_id = current_office_id
      )
    )
  FOR UPDATE OF approval;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'This request is not assigned to your school or is no longer awaiting your decision.'
      USING ERRCODE = '42501';
  END IF;

  IF normalized_decision = 'reconsider' THEN
    IF lower(dean_approval.status) <> 'pending' THEN
      RAISE EXCEPTION 'A reconsideration can only be requested before the final Dean decision.'
        USING ERRCODE = '22023';
    END IF;

    UPDATE public.reservation_approvals
    SET status = 'Cancelled',
        updated_at = now()
    WHERE reservation_id = dean_approval.reservation_id
      AND approval_stage = 'program_chair'
      AND created_at = dean_approval.created_at
      AND lower(status) IN ('pending', 'waiting');

    UPDATE public.reservation_approvals
    SET status = 'Condition Requested',
        reconsideration_message = normalized_message,
        requester_condition_response = NULL,
        condition_responded_at = NULL,
        updated_at = now()
    WHERE approval_id = dean_approval.approval_id;
    RETURN true;
  END IF;

  UPDATE public.reservation_approvals
  SET status = 'Cancelled',
      updated_at = now()
  WHERE reservation_id = dean_approval.reservation_id
    AND approval_stage = 'program_chair'
    AND created_at = dean_approval.created_at
    AND lower(status) IN ('pending', 'waiting');

  UPDATE public.reservation_approvals
  SET status = CASE
        WHEN normalized_decision = 'approve' THEN 'Approved'
        ELSE 'Rejected'
      END,
      approved_at = current_date,
      approved_by_user_id = current_user_id,
      rejection_reason = CASE
        WHEN normalized_decision = 'reject' THEN reason
        ELSE NULL
      END,
      updated_at = now()
  WHERE approval_id = dean_approval.approval_id;

  IF normalized_decision = 'reject' THEN
    UPDATE public.reservations
    SET overall_status = 'Rejected',
        updated_at = now()
    WHERE reservation_id = dean_approval.reservation_id;

    UPDATE public.reservation_approvals
    SET status = 'Cancelled',
        updated_at = now()
    WHERE reservation_id = dean_approval.reservation_id
      AND approval_id <> dean_approval.approval_id
      AND lower(status) IN (
        'pending', 'waiting', 'condition requested',
        'condition accepted', 'condition rejected'
      );
  END IF;

  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.respond_to_reconsideration(
  p_approval_id bigint,
  p_decision text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private, auth
AS $$
DECLARE
  current_user_id bigint;
  active_approval public.reservation_approvals%ROWTYPE;
  normalized_decision text := lower(trim(coalesce(p_decision, '')));
BEGIN
  current_user_id := private.current_profile_id();

  IF auth.uid() IS NULL OR current_user_id IS NULL THEN
    RAISE EXCEPTION 'Sign in before responding to a reconsideration request.'
      USING ERRCODE = '42501';
  END IF;

  IF normalized_decision NOT IN ('accept', 'reject') THEN
    RAISE EXCEPTION 'Decision must be accept or reject.'
      USING ERRCODE = '22023';
  END IF;

  SELECT approval.*
  INTO active_approval
  FROM public.reservation_approvals AS approval
  JOIN public.reservations AS reservation
    ON reservation.reservation_id = approval.reservation_id
  WHERE approval.approval_id = p_approval_id
    AND approval.approval_stage IN ('program_chair', 'dean')
    AND approval.status = 'Condition Requested'
    AND reservation.user_id = current_user_id
  FOR UPDATE OF approval;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'This reconsideration is not awaiting your response.'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.reservation_approvals
  SET status = CASE
        WHEN normalized_decision = 'accept' THEN 'Condition Accepted'
        ELSE 'Condition Rejected'
      END,
      requester_condition_response = normalized_decision,
      condition_responded_at = now(),
      updated_at = now()
  WHERE approval_id = active_approval.approval_id;

  RETURN true;
END;
$$;

DROP POLICY IF EXISTS reservation_approvals_insert_owner_pending
  ON public.reservation_approvals;
CREATE POLICY reservation_approvals_insert_owner_pending
  ON public.reservation_approvals FOR INSERT TO authenticated
  WITH CHECK (
    private.owns_reservation(reservation_id)
    AND lower(status) IN ('pending', 'waiting')
    AND (
      (
        approval_stage = 'faculty'
        AND approver_user_id IS NOT NULL
        AND office_id IS NULL
        AND owner_id IS NULL
        AND lower(status) = 'pending'
        AND lower(private.current_profile_role()) = 'student'
        AND private.is_active_faculty_profile(approver_user_id)
      )
      OR (
        approval_stage = 'program_chair'
        AND approver_user_id IS NULL
        AND owner_id IS NULL
        AND (
          (lower(private.current_profile_role()) = 'student'
            AND lower(status) = 'waiting'
            AND private.has_faculty_approval(reservation_id))
          OR (lower(private.current_profile_role()) <> 'student'
            AND (lower(status) = 'waiting'
              OR NOT EXISTS (
                SELECT 1
                FROM public.reservation_approvals AS existing
                WHERE existing.reservation_id =
                      reservation_approvals.reservation_id
              )))
        )
        AND EXISTS (
          SELECT 1
          FROM public.reservations AS reservation
          JOIN public.users AS requester
            ON requester.user_id = reservation.user_id
          JOIN public.academic_programs AS program
            ON program.program_id =
               private.program_id_for_affiliation(requester.affiliation)
          WHERE reservation.reservation_id =
                reservation_approvals.reservation_id
            AND program.office_id = reservation_approvals.office_id
            AND NOT private.is_program_chair_profile(requester.user_id)
            AND NOT private.is_dean_profile(requester.user_id)
        )
      )
      OR (
        approval_stage = 'dean'
        AND approver_user_id IS NULL
        AND owner_id IS NULL
        AND (
          (lower(private.current_profile_role()) = 'student'
            AND lower(status) = 'waiting'
            AND private.has_faculty_approval(reservation_id))
          OR (lower(private.current_profile_role()) <> 'student'
            AND (lower(status) = 'waiting'
              OR NOT EXISTS (
                SELECT 1
                FROM public.reservation_approvals AS existing
                WHERE existing.reservation_id =
                      reservation_approvals.reservation_id
              )))
        )
        AND EXISTS (
          SELECT 1
          FROM public.reservations AS reservation
          JOIN public.users AS requester
            ON requester.user_id = reservation.user_id
          JOIN public.dean_program_assignments AS assignment
            ON assignment.program_id =
               private.program_id_for_affiliation(requester.affiliation)
          JOIN public.dean_role_offices AS dean_office
            ON dean_office.dean_role = assignment.dean_role
          WHERE reservation.reservation_id =
                reservation_approvals.reservation_id
            AND dean_office.office_id = reservation_approvals.office_id
            AND NOT private.is_dean_profile(requester.user_id)
        )
      )
      OR (
        approval_stage = 'office'
        AND approver_user_id IS NULL
        AND (
          (lower(private.current_profile_role()) = 'student'
            AND lower(status) = 'waiting'
            AND private.has_faculty_approval(reservation_id))
          OR (lower(private.current_profile_role()) <> 'student'
            AND (lower(status) = 'waiting'
              OR NOT EXISTS (
                SELECT 1
                FROM public.reservation_approvals AS existing
                WHERE existing.reservation_id =
                      reservation_approvals.reservation_id
              )))
        )
      )
    )
  );

DROP POLICY IF EXISTS reservation_approvals_update_assigned
  ON public.reservation_approvals;
CREATE POLICY reservation_approvals_update_assigned
  ON public.reservation_approvals FOR UPDATE TO authenticated
  USING (
    private.owns_reservation(reservation_id)
    OR (
      approval_stage <> 'program_chair'
      AND private.can_access_reservation(reservation_id)
      AND private.is_assigned_approver(office_id, owner_id)
    )
    OR private.is_global_admin()
  )
  WITH CHECK (
    (private.owns_reservation(reservation_id) AND lower(status) = 'cancelled')
    OR (
      approval_stage <> 'program_chair'
      AND private.can_access_reservation(reservation_id)
      AND private.is_assigned_approver(office_id, owner_id)
      AND lower(status) IN (
        'approved', 'rejected', 'denied', 'returned', 'pending'
      )
      AND (
        approved_by_user_id IS NULL
        OR approved_by_user_id = private.current_profile_id()
      )
    )
    OR private.is_global_admin()
  );

REVOKE ALL ON FUNCTION private.is_dean_profile(bigint)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.is_dean_profile(bigint)
  TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.respond_to_dean_approval(
  bigint, text, text, text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.respond_to_dean_approval(
  bigint, text, text, text
) TO authenticated;

COMMIT;
