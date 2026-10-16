BEGIN;

ALTER TABLE public.reservation_approvals
  ADD COLUMN IF NOT EXISTS approval_stage text NOT NULL DEFAULT 'office',
  ADD COLUMN IF NOT EXISTS reconsideration_message text,
  ADD COLUMN IF NOT EXISTS requester_condition_response text,
  ADD COLUMN IF NOT EXISTS condition_responded_at timestamptz;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.reservation_approvals'::regclass
      AND conname = 'reservation_approvals_approval_stage_check'
  ) THEN
    ALTER TABLE public.reservation_approvals
      ADD CONSTRAINT reservation_approvals_approval_stage_check
      CHECK (approval_stage IN ('faculty', 'office', 'program_chair'));
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS reservation_approvals_program_chair_queue_idx
  ON public.reservation_approvals (office_id, status, created_at)
  WHERE approval_stage = 'program_chair';

CREATE UNIQUE INDEX IF NOT EXISTS reservation_approvals_single_program_chair_idx
  ON public.reservation_approvals (reservation_id)
  WHERE approval_stage = 'program_chair';

INSERT INTO public.offices (
  department_name,
  officer_name,
  short_code,
  order_sequence
)
SELECT 'Dean', 'Dean', 'DEAN', 2
WHERE NOT EXISTS (
  SELECT 1
  FROM public.offices
  WHERE lower(trim(department_name)) = 'dean'
);

CREATE OR REPLACE FUNCTION private.program_id_for_affiliation(
  target_affiliation text
)
RETURNS bigint
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT CASE lower(regexp_replace(trim(coalesce(target_affiliation, '')), '\s+', ' ', 'g'))
    WHEN 'b multimedia arts' THEN 1
    WHEN 'bs architecture' THEN 2
    WHEN 'bs civil engineering' THEN 3
    WHEN 'bs computer science' THEN 4
    WHEN 'bs computer engineering' THEN 5
    WHEN 'bs information technology' THEN 6
    WHEN 'bs information technology with specialization in mobile and web applications' THEN 6
    WHEN 'bs accountancy' THEN 7
    WHEN 'bsba major in financial management' THEN 8
    WHEN 'bsba major in marketing management' THEN 9
    WHEN 'bs management accounting' THEN 10
    WHEN 'bs tourism management' THEN 11
    WHEN 'bs psychology' THEN 12
    WHEN 'bs medical technology' THEN 13
    WHEN 'bs nursing' THEN 14
    ELSE NULL
  END::bigint;
$$;

CREATE OR REPLACE FUNCTION private.is_program_chair_profile(
  target_user_id bigint
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users AS profile
    JOIN public.academic_programs AS program
      ON program.program_id = profile.program_id
     AND program.office_id = profile.office_id
    WHERE profile.user_id = target_user_id
      AND profile.is_active
      AND lower(profile.role) = CASE profile.program_id
        WHEN 1 THEN 'pc_multimediaarts'
        WHEN 2 THEN 'pc_architecture'
        WHEN 3 THEN 'pc_civilengineering'
        WHEN 4 THEN 'pc_computerscience'
        WHEN 5 THEN 'pc_computerengineering'
        WHEN 6 THEN 'pc_informationtechnology'
        WHEN 7 THEN 'pc_accountancy'
        WHEN 8 THEN 'pc_financialmanagement'
        WHEN 9 THEN 'pc_marketingmanagement'
        WHEN 10 THEN 'pc_managementaccounting'
        WHEN 11 THEN 'pc_tourismmanagement'
        WHEN 12 THEN 'pc_psychology'
        WHEN 13 THEN 'pc_medicaltechnology'
        WHEN 14 THEN 'pc_nursing'
        ELSE ''
      END
  );
$$;

CREATE OR REPLACE FUNCTION private.validate_program_chair_assignment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private
AS $$
DECLARE
  requester_id bigint;
  requester_affiliation text;
  requester_program_id bigint;
  expected_program_id bigint;
  expected_office_id bigint;
BEGIN
  IF NEW.approval_stage <> 'program_chair' THEN
    RETURN NEW;
  END IF;

  SELECT reservation.user_id, requester.affiliation
  INTO requester_id, requester_affiliation
  FROM public.reservations AS reservation
  JOIN public.users AS requester
    ON requester.user_id = reservation.user_id
  WHERE reservation.reservation_id = NEW.reservation_id;

  expected_program_id :=
    private.program_id_for_affiliation(requester_affiliation);

  IF requester_id IS NULL OR expected_program_id IS NULL THEN
    RAISE EXCEPTION
      'Requester affiliation is missing or not a supported academic program; correct the profile before routing to a Program Chair.'
      USING ERRCODE = '22023';
  END IF;

  IF private.is_program_chair_profile(requester_id) THEN
    RAISE EXCEPTION
      'Program Chair reservations must use the Dean approval route.'
      USING ERRCODE = '22023';
  END IF;

  SELECT program.office_id
  INTO expected_office_id
  FROM public.academic_programs AS program
  WHERE program.program_id = expected_program_id;

  IF expected_office_id IS NULL OR NEW.office_id IS DISTINCT FROM expected_office_id THEN
    RAISE EXCEPTION
      'The Program Chair approval office does not match the requester affiliation.'
      USING ERRCODE = '22023';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS reservation_approvals_validate_program_chair
  ON public.reservation_approvals;
CREATE TRIGGER reservation_approvals_validate_program_chair
  BEFORE INSERT OR UPDATE OF approval_stage, office_id, reservation_id
  ON public.reservation_approvals
  FOR EACH ROW
  EXECUTE FUNCTION private.validate_program_chair_assignment();

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
  next_approval_id bigint;
BEGIN
  IF lower(NEW.status) <> 'approved'
     OR lower(OLD.status) NOT IN (
       'pending', 'condition accepted', 'condition rejected'
     ) THEN
    RETURN NEW;
  END IF;

  SELECT approval.approval_id
  INTO next_approval_id
  FROM public.reservation_approvals AS approval
  WHERE approval.reservation_id = NEW.reservation_id
    AND lower(approval.status) = 'waiting'
    AND (approval.created_at, approval.approval_id)
      > (NEW.created_at, NEW.approval_id)
  ORDER BY approval.created_at, approval.approval_id
  LIMIT 1
  FOR UPDATE;

  IF next_approval_id IS NOT NULL THEN
    UPDATE public.reservation_approvals
    SET status = 'Pending',
        updated_at = now()
    WHERE approval_id = next_approval_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS reservation_approvals_advance_after_approval
  ON public.reservation_approvals;
CREATE TRIGGER reservation_approvals_advance_after_approval
  AFTER UPDATE OF status
  ON public.reservation_approvals
  FOR EACH ROW
  WHEN (lower(NEW.status) = 'approved')
  EXECUTE FUNCTION private.advance_reservation_approval();

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
    SET status = 'Condition Requested',
        reconsideration_message = normalized_message,
        requester_condition_response = NULL,
        condition_responded_at = NULL,
        updated_at = now()
    WHERE approval_id = chair_approval.approval_id;
    RETURN true;
  END IF;

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
  chair_approval public.reservation_approvals%ROWTYPE;
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
  INTO chair_approval
  FROM public.reservation_approvals AS approval
  JOIN public.reservations AS reservation
    ON reservation.reservation_id = approval.reservation_id
  WHERE approval.approval_id = p_approval_id
    AND approval.approval_stage = 'program_chair'
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
  WHERE approval_id = chair_approval.approval_id;

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

REVOKE ALL ON FUNCTION private.program_id_for_affiliation(text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.program_id_for_affiliation(text)
  TO authenticated, service_role;
REVOKE ALL ON FUNCTION private.is_program_chair_profile(bigint)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.is_program_chair_profile(bigint)
  TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.respond_to_program_chair_approval(
  bigint, text, text, text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.respond_to_program_chair_approval(
  bigint, text, text, text
) TO authenticated;
REVOKE ALL ON FUNCTION public.respond_to_reconsideration(bigint, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.respond_to_reconsideration(bigint, text)
  TO authenticated;

COMMIT;