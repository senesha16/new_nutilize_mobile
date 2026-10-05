BEGIN;

ALTER TABLE public.email_otps
  ADD COLUMN IF NOT EXISTS purpose text NOT NULL DEFAULT 'verification';

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS auth_user_id uuid;

UPDATE public.users AS profile
SET auth_user_id = auth_user.id
FROM auth.users AS auth_user
WHERE profile.auth_user_id IS NULL
  AND lower(trim(profile.email)) = lower(trim(auth_user.email));

ALTER TABLE public.reservation_rooms
  ADD COLUMN IF NOT EXISTS reservation_id bigint;
ALTER TABLE public.reservation_items
  ADD COLUMN IF NOT EXISTS reservation_id bigint;

UPDATE public.reservation_rooms AS room_link
SET reservation_id = detail.reservation_id
FROM public.reservation_details AS detail
WHERE detail.reservation_rooms_id = room_link.reservation_rooms_id
  AND room_link.reservation_id IS NULL;

UPDATE public.reservation_items AS item_link
SET reservation_id = detail.reservation_id
FROM public.reservation_details AS detail
WHERE detail.reservation_items_id = item_link.reservation_items_id
  AND item_link.reservation_id IS NULL;

CREATE INDEX IF NOT EXISTS reservation_rooms_reservation_id_idx
  ON public.reservation_rooms (reservation_id);
CREATE INDEX IF NOT EXISTS reservation_items_reservation_id_idx
  ON public.reservation_items (reservation_id);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'reservation_rooms_reservation_id_fkey'
      AND conrelid = 'public.reservation_rooms'::regclass
  ) THEN
    ALTER TABLE public.reservation_rooms
      ADD CONSTRAINT reservation_rooms_reservation_id_fkey
      FOREIGN KEY (reservation_id) REFERENCES public.reservations(reservation_id)
      ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'reservation_items_reservation_id_fkey'
      AND conrelid = 'public.reservation_items'::regclass
  ) THEN
    ALTER TABLE public.reservation_items
      ADD CONSTRAINT reservation_items_reservation_id_fkey
      FOREIGN KEY (reservation_id) REFERENCES public.reservations(reservation_id)
      ON DELETE CASCADE;
  END IF;
END;
$$;

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA private TO authenticated, service_role;

CREATE OR REPLACE FUNCTION private.current_profile_id()
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT u.user_id
  FROM public.users AS u
  WHERE u.auth_user_id = auth.uid()
     OR lower(trim(u.email)) = lower(trim(coalesce(
       nullif(auth.jwt() ->> 'email', ''),
       nullif(auth.email(), '')
     )))
  ORDER BY u.user_id
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION private.current_profile_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT u.role
  FROM public.users AS u
  WHERE u.auth_user_id = auth.uid()
     OR lower(trim(u.email)) = lower(trim(coalesce(
       nullif(auth.jwt() ->> 'email', ''),
       nullif(auth.email(), '')
     )))
  ORDER BY u.user_id
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION private.current_profile_office_id()
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT u.office_id
  FROM public.users AS u
  WHERE u.auth_user_id = auth.uid()
     OR lower(trim(u.email)) = lower(trim(coalesce(
       nullif(auth.jwt() ->> 'email', ''),
       nullif(auth.email(), '')
     )))
  ORDER BY u.user_id
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION private.is_global_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT lower(coalesce(private.current_profile_role(), '')) IN ('admin', 'pc_admin');
$$;

CREATE OR REPLACE FUNCTION private.owns_reservation(target_reservation_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.reservations AS reservation
    WHERE reservation.reservation_id = target_reservation_id
      AND reservation.user_id = private.current_profile_id()
  );
$$;

CREATE OR REPLACE FUNCTION private.can_access_reservation(target_reservation_id bigint)
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
        AND approval.office_id = private.current_profile_office_id()
    )
    OR EXISTS (
      SELECT 1
      FROM public.reservation_approvals AS approval
      JOIN public.item_owners AS owner
        ON owner.owner_id = approval.owner_id
      WHERE approval.reservation_id = target_reservation_id
        AND owner.user_id = private.current_profile_id()
    );
$$;

CREATE OR REPLACE FUNCTION private.is_assigned_approver(
  target_office_id bigint,
  target_owner_id bigint
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT private.is_global_admin()
    OR target_office_id = private.current_profile_office_id()
    OR EXISTS (
      SELECT 1
      FROM public.item_owners AS owner
      WHERE owner.owner_id = target_owner_id
        AND owner.user_id = private.current_profile_id()
    );
$$;

CREATE OR REPLACE FUNCTION private.guard_user_profile_changes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
BEGIN
  IF auth.jwt() ->> 'role' = 'service_role'
     OR private.is_global_admin() THEN
    RETURN NEW;
  END IF;

  IF NEW.user_id IS DISTINCT FROM OLD.user_id
     OR lower(NEW.email) IS DISTINCT FROM lower(OLD.email)
     OR NEW.username IS DISTINCT FROM OLD.username
     OR NEW.role IS DISTINCT FROM OLD.role
     OR NEW.office_id IS DISTINCT FROM OLD.office_id
     OR NEW.is_active IS DISTINCT FROM OLD.is_active
     OR NEW.status_changed_at IS DISTINCT FROM OLD.status_changed_at
     OR NEW.password IS DISTINCT FROM OLD.password THEN
    RAISE EXCEPTION 'Only administrators may change protected profile fields.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_user_profile_changes ON public.users;
CREATE TRIGGER guard_user_profile_changes
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION private.guard_user_profile_changes();

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

DO $$
DECLARE
  table_row record;
  policy_row record;
BEGIN
  FOR policy_row IN
    SELECT tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
  LOOP
    EXECUTE format(
      'DROP POLICY %I ON public.%I',
      policy_row.policyname,
      policy_row.tablename
    );
  END LOOP;

  FOR table_row IN
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
  LOOP
    EXECUTE format(
      'ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',
      table_row.tablename
    );

    IF table_row.tablename NOT IN (
      'email_otps', 'password_reset_tokens', 'cache', 'cache_locks',
      'migrations', 'sessions'
    ) THEN
      EXECUTE format(
        'CREATE POLICY nutilize_global_admin_all ON public.%I FOR ALL TO authenticated USING (private.is_global_admin()) WITH CHECK (private.is_global_admin())',
        table_row.tablename
      );
    END IF;
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION private.current_profile_id() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.current_profile_role() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.current_profile_office_id() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.is_global_admin() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.owns_reservation(bigint) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.can_access_reservation(bigint) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.is_assigned_approver(bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.current_profile_id() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.current_profile_role() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.current_profile_office_id() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.is_global_admin() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.owns_reservation(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.can_access_reservation(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.is_assigned_approver(bigint, bigint) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.create_reservation_header(
  p_user_id bigint,
  p_activity_name text,
  p_date_of_activity text,
  p_start_of_activity text,
  p_end_of_activity text,
  p_outside_participants boolean,
  p_proof_of_consent_url text DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private, auth
AS $$
DECLARE
  created_reservation_id bigint;
BEGIN
  IF auth.uid() IS NULL OR p_user_id IS DISTINCT FROM private.current_profile_id() THEN
    RAISE EXCEPTION 'The authenticated user cannot create a reservation for this profile.'
      USING ERRCODE = '42501';
  END IF;

  IF p_date_of_activity::date < (current_date + 3) THEN
    RAISE EXCEPTION 'Reservations must be submitted at least two days before the activity date.'
      USING ERRCODE = '22023';
  END IF;

  EXECUTE format(
    'INSERT INTO public.reservations (
       user_id, activity_name, overall_status, %I, %I, %I,
       created_at, updated_at, outside_participants, proof_of_consent_url
     ) VALUES ($1, $2, $3, $4::timestamp, $5::timestamp, $6::timestamp,
       now(), now(), $7, $8)
     RETURNING reservation_id',
    'Date_of_Activity',
    'Start_of_activity',
    'End_of_Activity'
  )
  INTO created_reservation_id
  USING
    p_user_id,
    p_activity_name,
    'Pending Approval',
    p_date_of_activity,
    p_start_of_activity,
    p_end_of_activity,
    p_outside_participants,
    p_proof_of_consent_url;

  RETURN created_reservation_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_reservation_header(
  bigint, text, text, text, text, boolean, text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_reservation_header(
  bigint, text, text, text, text, boolean, text
) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.delete_account_data(target_user_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private, storage
AS $$
BEGIN
  CREATE TEMP TABLE account_reservations ON COMMIT DROP AS
    SELECT reservation_id FROM public.reservations WHERE user_id = target_user_id;

  DELETE FROM public.report_targets
  WHERE report_id IN (SELECT report_id FROM public.reports WHERE user_id = target_user_id);
  DELETE FROM public.reports WHERE user_id = target_user_id;

  DELETE FROM public.reservation_item_units
  WHERE reservation_items_id IN (
    SELECT reservation_items_id FROM public.reservation_items
    WHERE reservation_id IN (SELECT reservation_id FROM account_reservations)
  );
  DELETE FROM public.reservation_details
  WHERE reservation_id IN (SELECT reservation_id FROM account_reservations);
  DELETE FROM public.reservation_approval_histories
  WHERE reservation_id IN (SELECT reservation_id FROM account_reservations);
  DELETE FROM public.reservation_approvals
  WHERE reservation_id IN (SELECT reservation_id FROM account_reservations);
  DELETE FROM public.reservation_rooms
  WHERE reservation_id IN (SELECT reservation_id FROM account_reservations);
  DELETE FROM public.reservation_items
  WHERE reservation_id IN (SELECT reservation_id FROM account_reservations);
  DELETE FROM public.reservations
  WHERE reservation_id IN (SELECT reservation_id FROM account_reservations);

  DELETE FROM public.notifications WHERE user_id = target_user_id;
  DELETE FROM public.reservation_issues WHERE user_id = target_user_id;
  DELETE FROM public.schedule_import_details
  WHERE import_id IN (SELECT import_id FROM public.schedule_imports WHERE user_id = target_user_id);
  DELETE FROM public.schedule_imports WHERE user_id = target_user_id;
  DELETE FROM public.account_setup_tokens WHERE user_id = target_user_id;
  DELETE FROM public.sessions WHERE user_id = target_user_id;
  DELETE FROM public.admin_activity_logs WHERE user_id = target_user_id;
  UPDATE public.item_owners
  SET user_id = NULL
  WHERE user_id = target_user_id;

  DELETE FROM public.users WHERE user_id = target_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_account_data(bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.delete_account_data(bigint) TO service_role;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_publication
    WHERE pubname = 'supabase_realtime'
  ) AND NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'announcements'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.announcements;
  END IF;
END;
$$;

DROP POLICY IF EXISTS reports_authenticated_insert_own ON storage.objects;
CREATE POLICY reports_authenticated_insert_own
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'reports'
    AND (storage.foldername(name))[1] = private.current_profile_id()::text
  );

DROP POLICY IF EXISTS reports_authenticated_update_own ON storage.objects;
CREATE POLICY reports_authenticated_update_own
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'reports'
    AND (storage.foldername(name))[1] = private.current_profile_id()::text
  )
  WITH CHECK (
    bucket_id = 'reports'
    AND (storage.foldername(name))[1] = private.current_profile_id()::text
  );

CREATE POLICY users_select_own_profile
  ON public.users FOR SELECT TO authenticated
  USING (lower(email) = lower(auth.jwt() ->> 'email'));
CREATE POLICY users_update_own_profile
  ON public.users FOR UPDATE TO authenticated
  USING (lower(email) = lower(auth.jwt() ->> 'email'))
  WITH CHECK (lower(email) = lower(auth.jwt() ->> 'email'));
CREATE POLICY users_select_profiles_for_assigned_reservations
  ON public.users FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.reservations AS reservation
      JOIN public.reservation_approvals AS approval
        ON approval.reservation_id = reservation.reservation_id
      WHERE reservation.user_id = users.user_id
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

CREATE POLICY academic_programs_authenticated_read
  ON public.academic_programs FOR SELECT TO authenticated USING (true);
CREATE POLICY announcements_authenticated_read
  ON public.announcements FOR SELECT TO authenticated USING (true);
CREATE POLICY item_categories_authenticated_read
  ON public.item_categories FOR SELECT TO authenticated USING (true);
CREATE POLICY item_owners_authenticated_read
  ON public.item_owners FOR SELECT TO authenticated USING (true);
CREATE POLICY item_units_authenticated_read
  ON public.item_units FOR SELECT TO authenticated USING (true);
CREATE POLICY items_authenticated_read
  ON public.items FOR SELECT TO authenticated USING (true);
CREATE POLICY maintenance_authenticated_read
  ON public.maintenance FOR SELECT TO authenticated USING (true);
CREATE POLICY offices_authenticated_read
  ON public.offices FOR SELECT TO authenticated USING (true);
CREATE POLICY room_approver_offices_authenticated_read
  ON public.room_approver_offices FOR SELECT TO authenticated USING (true);
CREATE POLICY rooms_authenticated_read
  ON public.rooms FOR SELECT TO authenticated USING (true);

CREATE POLICY reservations_select_authorized
  ON public.reservations FOR SELECT TO authenticated
  USING (private.can_access_reservation(reservation_id));
CREATE POLICY reservations_insert_own_pending
  ON public.reservations FOR INSERT TO authenticated
  WITH CHECK (
    user_id = private.current_profile_id()
    AND lower(coalesce(overall_status, 'pending approval')) = 'pending approval'
  );
CREATE POLICY reservations_update_own_lifecycle
  ON public.reservations FOR UPDATE TO authenticated
  USING (user_id = private.current_profile_id())
  WITH CHECK (
    user_id = private.current_profile_id()
    AND lower(coalesce(overall_status, '')) IN ('cancelled', 'timed out', 'to return')
  );
REVOKE UPDATE ON public.reservations FROM authenticated;
GRANT UPDATE (overall_status, updated_at) ON public.reservations TO authenticated;

CREATE POLICY reservation_rooms_select_authorized
  ON public.reservation_rooms FOR SELECT TO authenticated
  USING (private.can_access_reservation(reservation_id));
CREATE POLICY reservation_rooms_insert_owner
  ON public.reservation_rooms FOR INSERT TO authenticated
  WITH CHECK (private.owns_reservation(reservation_id));

CREATE POLICY reservation_items_select_authorized
  ON public.reservation_items FOR SELECT TO authenticated
  USING (private.can_access_reservation(reservation_id));
CREATE POLICY reservation_items_insert_owner
  ON public.reservation_items FOR INSERT TO authenticated
  WITH CHECK (private.owns_reservation(reservation_id));

CREATE POLICY reservation_details_select_authorized
  ON public.reservation_details FOR SELECT TO authenticated
  USING (private.can_access_reservation(reservation_id));
CREATE POLICY reservation_details_insert_owner
  ON public.reservation_details FOR INSERT TO authenticated
  WITH CHECK (private.owns_reservation(reservation_id));

CREATE POLICY reservation_item_units_select_authorized
  ON public.reservation_item_units FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.reservation_items AS item_link
      WHERE item_link.reservation_items_id = reservation_item_units.reservation_items_id
        AND private.can_access_reservation(item_link.reservation_id)
    )
  );
CREATE POLICY reservation_item_units_insert_owner
  ON public.reservation_item_units FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.reservation_items AS item_link
      WHERE item_link.reservation_items_id = reservation_item_units.reservation_items_id
        AND private.owns_reservation(item_link.reservation_id)
    )
  );

CREATE POLICY reservation_approvals_select_authorized
  ON public.reservation_approvals FOR SELECT TO authenticated
  USING (private.can_access_reservation(reservation_id));
CREATE POLICY reservation_approvals_insert_owner_pending
  ON public.reservation_approvals FOR INSERT TO authenticated
  WITH CHECK (
    private.owns_reservation(reservation_id)
    AND lower(status) = 'pending'
  );
CREATE POLICY reservation_approvals_update_assigned
  ON public.reservation_approvals FOR UPDATE TO authenticated
  USING (
    private.is_assigned_approver(office_id, owner_id)
    OR private.owns_reservation(reservation_id)
  )
  WITH CHECK (
    (private.owns_reservation(reservation_id) AND lower(status) = 'cancelled')
    OR (
      private.is_assigned_approver(office_id, owner_id)
      AND lower(status) IN ('approved', 'rejected', 'denied', 'returned', 'pending')
      AND (approved_by_user_id IS NULL OR approved_by_user_id = private.current_profile_id())
    )
  );
REVOKE UPDATE ON public.reservation_approvals FROM authenticated;
GRANT UPDATE (
  status, approved_at, updated_at, approved_by_user_id, rejection_reason,
  follow_up_requested, follow_up_requested_at, follow_up_requested_by
) ON public.reservation_approvals TO authenticated;

CREATE POLICY item_units_update_linked_reservation
  ON public.item_units FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.reservation_item_units AS unit_link
      JOIN public.reservation_items AS item_link
        ON item_link.reservation_items_id = unit_link.reservation_items_id
      WHERE unit_link.unit_id = item_units.unit_id
        AND private.owns_reservation(item_link.reservation_id)
    )
  )
  WITH CHECK (
    lower(status) IN ('in_use', 'available', 'reserved', 'borrowed')
    AND EXISTS (
      SELECT 1
      FROM public.reservation_item_units AS unit_link
      JOIN public.reservation_items AS item_link
        ON item_link.reservation_items_id = unit_link.reservation_items_id
      WHERE unit_link.unit_id = item_units.unit_id
        AND private.owns_reservation(item_link.reservation_id)
    )
  );
REVOKE UPDATE ON public.item_units FROM authenticated;
GRANT UPDATE (status, updated_at) ON public.item_units TO authenticated;

CREATE POLICY reservation_issues_select_own
  ON public.reservation_issues FOR SELECT TO authenticated
  USING (
    user_id = private.current_profile_id()
    OR lower(reported_by) = lower(auth.jwt() ->> 'email')
  );
CREATE POLICY reservation_issues_insert_own
  ON public.reservation_issues FOR INSERT TO authenticated
  WITH CHECK (
    user_id = private.current_profile_id()
    OR lower(reported_by) = lower(auth.jwt() ->> 'email')
  );

CREATE POLICY notifications_select_own
  ON public.notifications FOR SELECT TO authenticated
  USING (user_id = private.current_profile_id());
CREATE POLICY notifications_update_own_read_state
  ON public.notifications FOR UPDATE TO authenticated
  USING (user_id = private.current_profile_id())
  WITH CHECK (user_id = private.current_profile_id());
REVOKE UPDATE ON public.notifications FROM authenticated;
GRANT UPDATE (read, updated_at) ON public.notifications TO authenticated;

CREATE POLICY reports_select_own
  ON public.reports FOR SELECT TO authenticated
  USING (user_id = private.current_profile_id());
CREATE POLICY reports_insert_own
  ON public.reports FOR INSERT TO authenticated
  WITH CHECK (user_id = private.current_profile_id());
CREATE POLICY report_targets_select_own
  ON public.report_targets FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.reports AS report
      WHERE report.report_id = report_targets.report_id
        AND report.user_id = private.current_profile_id()
    )
  );

CREATE POLICY schedule_imports_select_own
  ON public.schedule_imports FOR SELECT TO authenticated
  USING (user_id = private.current_profile_id());
CREATE POLICY schedule_imports_insert_own
  ON public.schedule_imports FOR INSERT TO authenticated
  WITH CHECK (user_id = private.current_profile_id());
CREATE POLICY schedule_import_details_select_own
  ON public.schedule_import_details FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.schedule_imports AS import
      WHERE import.import_id = schedule_import_details.import_id
        AND import.user_id = private.current_profile_id()
    )
  );
CREATE POLICY reservation_approval_histories_select_authorized
  ON public.reservation_approval_histories FOR SELECT TO authenticated
  USING (private.can_access_reservation(reservation_id));

CREATE POLICY sessions_select_own
  ON public.sessions FOR SELECT TO authenticated
  USING (user_id::text = auth.uid()::text);

REVOKE UPDATE ON public.users FROM authenticated;
GRANT UPDATE (
  first_name, middle_initial, last_name, suffix, full_name,
  contact_number, phone_number, affiliation, program_id,
  role, office_id, is_active, status_changed_at
) ON public.users TO authenticated;

CREATE OR REPLACE FUNCTION private.recalculate_item_usage()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  changed_item_id bigint;
BEGIN
  IF TG_OP = 'DELETE' THEN
    changed_item_id := OLD.item_id;
  ELSE
    changed_item_id := NEW.item_id;
  END IF;

  UPDATE public.items AS item
  SET quantity_in_use = (
        SELECT count(*)::integer
        FROM public.item_units AS unit
        WHERE unit.item_id = changed_item_id
          AND lower(coalesce(unit.status, '')) NOT IN
            ('available', 'free', 'ready', 'active', 'new', 'in_stock', 'instock')
      ),
      updated_at = now()
  WHERE item.item_id = changed_item_id;

  IF TG_OP = 'UPDATE' AND OLD.item_id IS DISTINCT FROM NEW.item_id THEN
    UPDATE public.items AS item
    SET quantity_in_use = (
          SELECT count(*)::integer
          FROM public.item_units AS unit
          WHERE unit.item_id = OLD.item_id
            AND lower(coalesce(unit.status, '')) NOT IN
              ('available', 'free', 'ready', 'active', 'new', 'in_stock', 'instock')
        ),
        updated_at = now()
    WHERE item.item_id = OLD.item_id;
  END IF;

  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION private.recalculate_item_usage() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS recalculate_item_usage_after_unit_change ON public.item_units;
CREATE TRIGGER recalculate_item_usage_after_unit_change
  AFTER INSERT OR UPDATE OF status, item_id OR DELETE ON public.item_units
  FOR EACH ROW EXECUTE FUNCTION private.recalculate_item_usage();

COMMIT;
