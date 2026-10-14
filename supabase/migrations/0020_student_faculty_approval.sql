BEGIN;

ALTER TABLE public.reservation_approvals
  ALTER COLUMN office_id DROP NOT NULL,
  ADD COLUMN IF NOT EXISTS approver_user_id bigint
    REFERENCES public.users(user_id);

CREATE UNIQUE INDEX IF NOT EXISTS reservation_approvals_single_faculty_approver_idx
  ON public.reservation_approvals (reservation_id)
  WHERE approver_user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS reservation_approvals_faculty_pending_idx
  ON public.reservation_approvals (approver_user_id, status)
  WHERE approver_user_id IS NOT NULL;

CREATE OR REPLACE FUNCTION private.is_active_faculty_profile(target_user_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users AS profile
    WHERE profile.user_id = target_user_id
      AND profile.is_active
      AND lower(profile.role) IN ('faculty', 'teacher', 'faculty_member')
  );
$$;

CREATE OR REPLACE FUNCTION private.has_faculty_approval(target_reservation_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.reservation_approvals AS approval
    WHERE approval.reservation_id = target_reservation_id
      AND approval.approver_user_id IS NOT NULL
  );
$$;

CREATE OR REPLACE FUNCTION private.faculty_approval_is_complete(
  target_reservation_id bigint
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT NOT private.has_faculty_approval(target_reservation_id)
    OR EXISTS (
      SELECT 1
      FROM public.reservation_approvals AS approval
      WHERE approval.reservation_id = target_reservation_id
        AND approval.approver_user_id IS NOT NULL
        AND lower(approval.status) = 'approved'
    );
$$;

CREATE OR REPLACE FUNCTION private.can_access_reservation(
  target_reservation_id bigint
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT private.is_global_admin()
    OR private.owns_reservation(target_reservation_id)
    OR EXISTS (
      SELECT 1
      FROM public.reservation_approvals AS approval
      WHERE approval.reservation_id = target_reservation_id
        AND approval.approver_user_id = private.current_profile_id()
    )
    OR (
      private.faculty_approval_is_complete(target_reservation_id)
      AND (
        EXISTS (
          SELECT 1
          FROM public.reservation_approvals AS approval
          WHERE approval.reservation_id = target_reservation_id
            AND approval.office_id = private.current_profile_office_id()
        )
        OR EXISTS (
          SELECT 1
          FROM public.reservation_approvals AS approval
          JOIN public.item_owners AS owner
            ON owner.owner_id = approval.owner_id
          WHERE approval.reservation_id = target_reservation_id
            AND owner.user_id = private.current_profile_id()
        )
      )
    );
$$;

CREATE OR REPLACE FUNCTION public.search_active_faculty(p_search_query text)
RETURNS TABLE(user_id bigint, display_name text, email text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT
    profile.user_id,
    coalesce(
      nullif(trim(profile.full_name), ''),
      nullif(trim(concat_ws(
        ' ',
        profile.first_name,
        profile.middle_initial,
        profile.last_name,
        profile.suffix
      )), ''),
      profile.username
    ) AS display_name,
    profile.email
  FROM public.users AS profile
  WHERE auth.uid() IS NOT NULL
    AND profile.is_active
    AND lower(profile.role) IN ('faculty', 'teacher', 'faculty_member')
    AND length(trim(coalesce(p_search_query, ''))) >= 2
    AND position(
      lower(trim(p_search_query))
      IN lower(concat_ws(' ', profile.full_name, profile.first_name,
        profile.middle_initial, profile.last_name, profile.email))
    ) > 0
  ORDER BY display_name, profile.email
  LIMIT 25;
$$;

CREATE OR REPLACE FUNCTION public.respond_to_faculty_approval(
  p_approval_id bigint,
  p_decision text,
  p_rejection_reason text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private, auth
AS $$
DECLARE
  current_user_id bigint;
  assigned_approval public.reservation_approvals%ROWTYPE;
  normalized_decision text := lower(trim(coalesce(p_decision, '')));
  reason text := trim(coalesce(p_rejection_reason, ''));
BEGIN
  current_user_id := private.current_profile_id();

  IF auth.uid() IS NULL
     OR current_user_id IS NULL
     OR NOT private.is_active_faculty_profile(current_user_id) THEN
    RAISE EXCEPTION 'Only active faculty can respond to student approval requests.'
      USING ERRCODE = '42501';
  END IF;

  IF normalized_decision NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION 'Decision must be approve or reject.'
      USING ERRCODE = '22023';
  END IF;

  IF normalized_decision = 'reject' AND reason = '' THEN
    RAISE EXCEPTION 'A rejection reason is required.'
      USING ERRCODE = '22023';
  END IF;

  IF normalized_decision = 'reject' AND length(reason) > 500 THEN
    RAISE EXCEPTION 'The rejection reason cannot exceed 500 characters.'
      USING ERRCODE = '22023';
  END IF;

  SELECT *
  INTO assigned_approval
  FROM public.reservation_approvals AS approval
  WHERE approval.approval_id = p_approval_id
    AND approval.approver_user_id = current_user_id
    AND lower(approval.status) = 'pending'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'This approval is no longer pending or is not assigned to you.'
      USING ERRCODE = '42501';
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
  WHERE approval_id = assigned_approval.approval_id;

  IF normalized_decision = 'reject' THEN
    UPDATE public.reservations
    SET overall_status = 'Rejected',
        updated_at = now()
    WHERE reservation_id = assigned_approval.reservation_id;

    UPDATE public.reservation_approvals
    SET status = 'Cancelled',
        updated_at = now()
    WHERE reservation_id = assigned_approval.reservation_id
      AND approval_id <> assigned_approval.approval_id
      AND lower(status) IN ('pending', 'waiting');
  END IF;

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION private.is_active_faculty_profile(bigint)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.has_faculty_approval(bigint)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.faculty_approval_is_complete(bigint)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.is_active_faculty_profile(bigint)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.has_faculty_approval(bigint)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.faculty_approval_is_complete(bigint)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.search_active_faculty(text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.search_active_faculty(text)
  TO authenticated;

REVOKE ALL ON FUNCTION public.respond_to_faculty_approval(bigint, text, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.respond_to_faculty_approval(bigint, text, text)
  TO authenticated;

DROP POLICY IF EXISTS reservation_approvals_insert_owner_pending
  ON public.reservation_approvals;
CREATE POLICY reservation_approvals_insert_owner_pending
  ON public.reservation_approvals FOR INSERT TO authenticated
  WITH CHECK (
    private.owns_reservation(reservation_id)
    AND lower(status) = 'pending'
    AND (
      (
        approver_user_id IS NOT NULL
        AND office_id IS NULL
        AND owner_id IS NULL
        AND lower(private.current_profile_role()) = 'student'
        AND private.is_active_faculty_profile(approver_user_id)
      )
      OR (
        approver_user_id IS NULL
        AND (
          lower(private.current_profile_role()) <> 'student'
          OR private.has_faculty_approval(reservation_id)
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
      private.can_access_reservation(reservation_id)
      AND private.is_assigned_approver(office_id, owner_id)
    )
  )
  WITH CHECK (
    (private.owns_reservation(reservation_id) AND lower(status) = 'cancelled')
    OR (
      private.can_access_reservation(reservation_id)
      AND private.is_assigned_approver(office_id, owner_id)
      AND lower(status) IN ('approved', 'rejected', 'denied', 'returned', 'pending')
      AND (approved_by_user_id IS NULL
        OR approved_by_user_id = private.current_profile_id())
    )
  );

DROP POLICY IF EXISTS users_select_profiles_for_direct_approvals
  ON public.users;
CREATE POLICY users_select_profiles_for_direct_approvals
  ON public.users FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.reservations AS reservation
      JOIN public.reservation_approvals AS approval
        ON approval.reservation_id = reservation.reservation_id
      WHERE reservation.user_id = users.user_id
        AND approval.approver_user_id = private.current_profile_id()
    )
  );

DROP POLICY IF EXISTS users_select_profiles_for_assigned_reservations
  ON public.users;
CREATE POLICY users_select_profiles_for_assigned_reservations
  ON public.users FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.reservations AS reservation
      JOIN public.reservation_approvals AS approval
        ON approval.reservation_id = reservation.reservation_id
      WHERE reservation.user_id = users.user_id
        AND private.faculty_approval_is_complete(reservation.reservation_id)
        AND (
          approval.office_id = private.current_profile_office_id()
          OR EXISTS (
            SELECT 1
            FROM public.item_owners AS owner
            WHERE owner.owner_id = approval.owner_id
              AND owner.user_id = private.current_profile_id()
          )
        )
    )
  );

COMMIT;
