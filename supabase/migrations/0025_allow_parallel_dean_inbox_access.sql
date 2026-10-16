BEGIN;

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
                  OR (
                    active_approval.approval_stage = 'dean'
                    AND earlier_approval.approval_stage = 'office'
                    AND EXISTS (
                      SELECT 1
                      FROM public.reservation_approvals AS chair_peer
                      WHERE chair_peer.reservation_id =
                            active_approval.reservation_id
                        AND chair_peer.approval_stage = 'program_chair'
                        AND chair_peer.created_at = active_approval.created_at
                        AND chair_peer.approval_id <
                            earlier_approval.approval_id
                    )
                  )
                )
              )
          )
      )
    );
$$;

COMMIT;
