-- BATCH-03: Event Date Change & Event Removal Impact Review (TOP-EVT-002, TOP-EVT-003)
-- IMPL-CONFLICT-004 RESOLVED: USER_ABSOLUTE tasks are calendar-fixed and excluded from all
--   event date change cascades and fingerprints.
-- IMPL-CONFLICT-005 RESOLVED: Event removal task classification is server-authoritative.
--   Client p_explicit_choices parameter removed.
-- IMPL-CONFLICT-006 RESOLVED: invitation_event_targetings has NO is_active column per
--   approved Physical Design (Table 14). Targeting rows are preserved as historical
--   relationship records. Class D availability derives from WeddingEvent.lifecycle_status,
--   not from any targeting soft-delete flag.
-- IMPL-GAP-003 RESOLVED: BudgetItems are preserved (wedding_event_id unlinked).
--   Invitation targeting rows are preserved intact (no mutation on event removal).

-- ===========================================================================
-- 1. TOP-EVT-002: PREVIEW EVENT DATE CHANGE
-- ===========================================================================
CREATE OR REPLACE FUNCTION api_v1.preview_event_date_change(
  p_event_id uuid,
  p_target_exact_date date,
  p_target_expected_year integer,
  p_target_expected_month integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_caller_role              varchar(50);
  v_wedding_id               uuid;
  v_current_exact_date       date;
  v_current_expected_year    integer;
  v_current_expected_month   integer;
  v_is_main_event            boolean;
  v_lifecycle_status         varchar(50);

  v_fingerprint              text;
  v_recalculated_json        json;
  v_preserved_json           json;
  v_unresolved_json          json;
  v_absolute_tasks_count     integer := 0;
BEGIN
  -- Load authoritative current Event state
  SELECT wedding_id, exact_date, expected_year, expected_month, is_main_event, lifecycle_status
  INTO v_wedding_id, v_current_exact_date, v_current_expected_year, v_current_expected_month, v_is_main_event, v_lifecycle_status
  FROM public.wedding_events
  WHERE id = p_event_id;

  IF v_wedding_id IS NULL THEN
    RAISE EXCEPTION 'Event not found.' USING ERRCODE = '44000';
  END IF;

  IF v_lifecycle_status = 'REMOVED' THEN
    RAISE EXCEPTION 'Cannot operate on a removed event.' USING ERRCODE = '45000';
  END IF;

  -- 1. Authenticate & Authorize caller
  SELECT role INTO v_caller_role
  FROM public.wedding_members
  WHERE wedding_id = v_wedding_id
    AND user_id = auth.uid()
    AND status = 'ACTIVE';

  IF v_caller_role IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: Caller is not an active member of this wedding.'
      USING ERRCODE = '42501';
  END IF;

  -- Validate proposed target precision/date XOR
  IF (p_target_exact_date IS NOT NULL AND (p_target_expected_year IS NOT NULL OR p_target_expected_month IS NOT NULL)) OR
     (p_target_exact_date IS NULL AND (p_target_expected_year IS NULL OR p_target_expected_month IS NULL)) THEN
    RAISE EXCEPTION 'Date precision constraint violation: Must specify exact_date OR expected_year + expected_month.'
      USING ERRCODE = '23514';
  END IF;

  IF p_target_expected_month IS NOT NULL AND (p_target_expected_month < 1 OR p_target_expected_month > 12) THEN
    RAISE EXCEPTION 'Expected month must be between 1 and 12.' USING ERRCODE = '23514';
  END IF;

  -- 2. Derive material impact fingerprint (covers event state + relative tasks only)
  --    USER_ABSOLUTE and NO_DEADLINE tasks are excluded: they are never touched by EVT-002.
  SELECT md5(string_agg(row_data, '|')) INTO v_fingerprint
  FROM (
    SELECT 'event:' || id || ':' || lifecycle_status || ':' || COALESCE(exact_date::text, 'null') || ':' || COALESCE(expected_year::text, 'null') || ':' || COALESCE(expected_month::text, 'null') || ':' || is_main_event::text AS row_data
    FROM public.wedding_events
    WHERE id = p_event_id
    UNION ALL
    SELECT 'task:' || id || ':' || status || ':' || deadline_intent || ':' || COALESCE(date_offset::text, 'null') || ':' || COALESCE(resolved_deadline_at::text, 'null') || ':' || is_user_modified::text || ':' || task_source
    FROM public.tasks
    WHERE wedding_event_id = p_event_id
      AND deadline_intent IN ('SYSTEM_RELATIVE', 'USER_RELATIVE')
    ORDER BY 1
  ) s;

  -- 3. Recalculated relative tasks (only if target is exact date — active relative tasks get new resolved date)
  SELECT COALESCE(json_agg(t), '[]'::json) INTO v_recalculated_json
  FROM (
    SELECT
      id, name, deadline_intent, date_offset, resolved_deadline_at AS old_resolved_deadline_at,
      p_target_exact_date + date_offset AS new_resolved_deadline_at
    FROM public.tasks
    WHERE wedding_event_id = p_event_id
      AND status IN ('TODO', 'IN_PROGRESS')
      AND deadline_intent IN ('SYSTEM_RELATIVE', 'USER_RELATIVE')
      AND p_target_exact_date IS NOT NULL
    ORDER BY id
  ) t;

  -- 4. Preserved tasks (completed tasks preserving history — untouched for ALL transitions)
  SELECT COALESCE(json_agg(t), '[]'::json) INTO v_preserved_json
  FROM (
    SELECT id, name, status, deadline_intent, resolved_deadline_at
    FROM public.tasks
    WHERE wedding_event_id = p_event_id
      AND status = 'COMPLETED'
    ORDER BY id
  ) t;

  -- 5. Unresolved tasks (relative active tasks losing exact dates on Exact→Month transition)
  SELECT COALESCE(json_agg(t), '[]'::json) INTO v_unresolved_json
  FROM (
    SELECT
      id, name, deadline_intent, date_offset, resolved_deadline_at AS old_resolved_deadline_at
    FROM public.tasks
    WHERE wedding_event_id = p_event_id
      AND status IN ('TODO', 'IN_PROGRESS')
      AND deadline_intent IN ('SYSTEM_RELATIVE', 'USER_RELATIVE')
      AND p_target_exact_date IS NULL
    ORDER BY id
  ) t;

  -- 6. Informational: count of USER_ABSOLUTE tasks in this wedding (unchanged for all transitions)
  SELECT count(*)::integer INTO v_absolute_tasks_count
  FROM public.tasks
  WHERE wedding_id = v_wedding_id
    AND deadline_intent = 'USER_ABSOLUTE'
    AND status IN ('TODO', 'IN_PROGRESS');

  RETURN jsonb_build_object(
    'event_id', p_event_id,
    'current_precision', CASE WHEN v_current_exact_date IS NOT NULL THEN 'EXACT' ELSE 'MONTH' END,
    'target_precision', CASE WHEN p_target_exact_date IS NOT NULL THEN 'EXACT' ELSE 'MONTH' END,
    'impact_fingerprint', v_fingerprint,
    'recalculated_tasks', v_recalculated_json,
    'preserved_tasks', v_preserved_json,
    'unresolved_tasks', v_unresolved_json,
    'absolute_tasks_unchanged_count', v_absolute_tasks_count
  );
END;
$$;


-- ===========================================================================
-- 2. TOP-EVT-002: COMMIT EVENT DATE CHANGE
-- ===========================================================================
-- IMPL-CONFLICT-004: p_batch_action_c removed. USER_ABSOLUTE tasks are calendar-fixed
-- and are NEVER shifted, moved, or adjusted as part of any event date transition.
CREATE OR REPLACE FUNCTION api_v1.commit_event_date_change(
  p_event_id uuid,
  p_target_exact_date date,
  p_target_expected_year integer,
  p_target_expected_month integer,
  p_impact_fingerprint text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_caller_role              varchar(50);
  v_wedding_id               uuid;
  v_current_exact_date       date;
  v_current_expected_year    integer;
  v_current_expected_month   integer;
  v_is_main_event            boolean;
  v_lifecycle_status         varchar(50);

  v_fingerprint              text;
  v_tasks_json               jsonb;
  v_events_json              jsonb;
  v_initial_plan_generated   timestamptz;
BEGIN
  -- Load Event
  SELECT wedding_id, exact_date, expected_year, expected_month, is_main_event, lifecycle_status
  INTO v_wedding_id, v_current_exact_date, v_current_expected_year, v_current_expected_month, v_is_main_event, v_lifecycle_status
  FROM public.wedding_events
  WHERE id = p_event_id;

  IF v_wedding_id IS NULL THEN
    RAISE EXCEPTION 'Event not found.' USING ERRCODE = '44000';
  END IF;

  IF v_lifecycle_status = 'REMOVED' THEN
    RAISE EXCEPTION 'Cannot operate on a removed event.' USING ERRCODE = '45000';
  END IF;

  -- Authenticate & Authorize
  SELECT role INTO v_caller_role
  FROM public.wedding_members
  WHERE wedding_id = v_wedding_id
    AND user_id = auth.uid()
    AND status = 'ACTIVE';

  IF v_caller_role IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: Caller is not an active member of this wedding.'
      USING ERRCODE = '42501';
  END IF;

  -- Lock target wedding row
  SELECT initial_plan_generated_at INTO v_initial_plan_generated
  FROM public.weddings
  WHERE id = v_wedding_id
  FOR UPDATE;

  -- Validate proposed target XOR precision
  IF (p_target_exact_date IS NOT NULL AND (p_target_expected_year IS NOT NULL OR p_target_expected_month IS NOT NULL)) OR
     (p_target_exact_date IS NULL AND (p_target_expected_year IS NULL OR p_target_expected_month IS NULL)) THEN
    RAISE EXCEPTION 'Date precision constraint violation: Must specify exact_date OR expected_year + expected_month.'
      USING ERRCODE = '23514';
  END IF;

  -- 1. Retry Guard: If target state already matches current state, replay current result
  IF v_current_exact_date IS NOT DISTINCT FROM p_target_exact_date AND
     v_current_expected_year IS NOT DISTINCT FROM p_target_expected_year AND
     v_current_expected_month IS NOT DISTINCT FROM p_target_expected_month THEN

     SELECT json_agg(t) INTO v_tasks_json
     FROM (
       SELECT id, name, status, deadline_intent, date_offset, resolved_deadline_at, task_source, side, assignee_wedding_member_id, wedding_event_id
       FROM public.tasks
       WHERE wedding_id = v_wedding_id
       ORDER BY created_at ASC
     ) t;

     SELECT json_agg(e) INTO v_events_json
     FROM (
       SELECT id, name, expected_year, expected_month, exact_date, start_time, location, map_link, is_main_event, lifecycle_status
       FROM public.wedding_events
       WHERE wedding_id = v_wedding_id
       ORDER BY created_at ASC
     ) e;

     RETURN jsonb_build_object(
       'initial_plan_generated_at', v_initial_plan_generated,
       'replayed', true,
       'tasks', COALESCE(v_tasks_json, '[]'::jsonb),
       'events', COALESCE(v_events_json, '[]'::jsonb)
     );
  END IF;

  -- 2. Verify current material state fingerprint (detect concurrent updates)
  --    Fingerprint covers event state and relative tasks only.
  --    USER_ABSOLUTE tasks are excluded: they are not part of EVT-002 impact scope.
  SELECT md5(string_agg(row_data, '|')) INTO v_fingerprint
  FROM (
    SELECT 'event:' || id || ':' || lifecycle_status || ':' || COALESCE(exact_date::text, 'null') || ':' || COALESCE(expected_year::text, 'null') || ':' || COALESCE(expected_month::text, 'null') || ':' || is_main_event::text AS row_data
    FROM public.wedding_events
    WHERE id = p_event_id
    UNION ALL
    SELECT 'task:' || id || ':' || status || ':' || deadline_intent || ':' || COALESCE(date_offset::text, 'null') || ':' || COALESCE(resolved_deadline_at::text, 'null') || ':' || is_user_modified::text || ':' || task_source
    FROM public.tasks
    WHERE wedding_event_id = p_event_id
      AND deadline_intent IN ('SYSTEM_RELATIVE', 'USER_RELATIVE')
    ORDER BY 1
  ) s;

  IF v_fingerprint IS DISTINCT FROM p_impact_fingerprint THEN
    RAISE EXCEPTION 'STALE_IMPACT: The planning workspace state has changed since the preview was generated.'
      USING ERRCODE = '40001';
  END IF;

  -- 3. Apply Date change to the Event
  UPDATE public.wedding_events
  SET exact_date = p_target_exact_date,
      expected_year = p_target_expected_year,
      expected_month = p_target_expected_month,
      updated_at = now()
  WHERE id = p_event_id;

  -- 4. Cascade to active relative tasks only (SYSTEM_RELATIVE and USER_RELATIVE).
  --    USER_ABSOLUTE and NO_DEADLINE are calendar-fixed and are NOT touched.
  --    Completed tasks are excluded (status check).
  UPDATE public.tasks
  SET resolved_deadline_at = (CASE WHEN p_target_exact_date IS NOT NULL THEN p_target_exact_date + date_offset ELSE NULL END)
  WHERE wedding_event_id = p_event_id
    AND status IN ('TODO', 'IN_PROGRESS')
    AND deadline_intent IN ('SYSTEM_RELATIVE', 'USER_RELATIVE');

  -- 5. Query and return updated lists
  SELECT json_agg(t) INTO v_tasks_json
  FROM (
    SELECT id, name, status, deadline_intent, date_offset, resolved_deadline_at, task_source, side, assignee_wedding_member_id, wedding_event_id
    FROM public.tasks
    WHERE wedding_id = v_wedding_id
    ORDER BY created_at ASC
  ) t;

  SELECT json_agg(e) INTO v_events_json
  FROM (
    SELECT id, name, expected_year, expected_month, exact_date, start_time, location, map_link, is_main_event, lifecycle_status
    FROM public.wedding_events
    WHERE wedding_id = v_wedding_id
    ORDER BY created_at ASC
  ) e;

  RETURN jsonb_build_object(
    'initial_plan_generated_at', v_initial_plan_generated,
    'replayed', false,
    'tasks', COALESCE(v_tasks_json, '[]'::jsonb),
    'events', COALESCE(v_events_json, '[]'::jsonb)
  );
END;
$$;


-- ===========================================================================
-- 3. TOP-EVT-003: PREVIEW EVENT REMOVAL
-- ===========================================================================
CREATE OR REPLACE FUNCTION api_v1.preview_event_removal(
  p_event_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_caller_role              varchar(50);
  v_wedding_id               uuid;
  v_is_main_event            boolean;
  v_lifecycle_status         varchar(50);
  v_main_events_count        integer;

  v_fingerprint              text;
  v_blocking_invariants      text[] := '{}';
  v_deletion_candidates      json;
  v_preservation_tasks       json;
  v_budget_count             integer := 0;
  v_invitations_count        integer := 0;
BEGIN
  -- Load Event
  SELECT wedding_id, is_main_event, lifecycle_status
  INTO v_wedding_id, v_is_main_event, v_lifecycle_status
  FROM public.wedding_events
  WHERE id = p_event_id;

  IF v_wedding_id IS NULL THEN
    RAISE EXCEPTION 'Event not found.' USING ERRCODE = '44000';
  END IF;

  IF v_lifecycle_status = 'REMOVED' THEN
    RAISE EXCEPTION 'Event already removed.' USING ERRCODE = '45000';
  END IF;

  -- Authenticate & Authorize
  SELECT role INTO v_caller_role
  FROM public.wedding_members
  WHERE wedding_id = v_wedding_id
    AND user_id = auth.uid()
    AND status = 'ACTIVE';

  IF v_caller_role IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: Caller is not an active member of this wedding.'
      USING ERRCODE = '42501';
  END IF;

  -- Validate final Main Event protection: cannot delete if it is the only active Main Event
  IF v_is_main_event = true THEN
    SELECT count(*) INTO v_main_events_count
    FROM public.wedding_events
    WHERE wedding_id = v_wedding_id
      AND is_main_event = true
      AND lifecycle_status = 'ACTIVE';

    IF v_main_events_count <= 1 THEN
      v_blocking_invariants := array_append(v_blocking_invariants, 'FINAL_MAIN_EVENT_INVARIANT');
    END IF;
  END IF;

  -- Inspect dynamic BudgetItems count (cross-domain safely)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'budget_items') THEN
    EXECUTE 'SELECT count(*)::integer FROM public.budget_items WHERE wedding_event_id = $1' INTO v_budget_count USING p_event_id;
  END IF;

  -- Inspect dynamic Invitation targeting count (cross-domain safely)
  -- Count is total targetings for this event (no is_active filter — not in Physical Design).
  -- Class D availability derives from WeddingEvent.lifecycle_status, not a targeting flag.
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'invitation_event_targetings') THEN
    EXECUTE 'SELECT count(*)::integer FROM public.invitation_event_targetings WHERE wedding_event_id = $1' INTO v_invitations_count USING p_event_id;
  END IF;

  -- Compute material fingerprint
  SELECT md5(string_agg(row_data, '|')) INTO v_fingerprint
  FROM (
    SELECT 'event:' || id || ':' || lifecycle_status || ':' || is_main_event::text AS row_data
    FROM public.wedding_events
    WHERE id = p_event_id
    UNION ALL
    SELECT 'task:' || id || ':' || status || ':' || task_source || ':' || is_user_modified::text || ':' || deadline_intent || ':' || COALESCE(resolved_deadline_at::text, 'null')
    FROM public.tasks
    WHERE wedding_event_id = p_event_id
    UNION ALL
    SELECT 'budget:' || v_budget_count::text
    UNION ALL
    SELECT 'invitations:' || v_invitations_count::text
    ORDER BY 1
  ) s;

  -- Server-authoritative classification of tasks:
  -- Deletion candidates: active untouched system/recommendation tasks
  SELECT COALESCE(json_agg(t), '[]'::json) INTO v_deletion_candidates
  FROM (
    SELECT id, name
    FROM public.tasks
    WHERE wedding_event_id = p_event_id
      AND status IN ('TODO', 'IN_PROGRESS')
      AND task_source IN ('SYSTEM_TEMPLATE', 'RECOMMENDATION')
      AND is_user_modified = false
    ORDER BY id
  ) t;

  -- Preservation tasks: user-created, user-modified, or completed tasks
  SELECT COALESCE(json_agg(t), '[]'::json) INTO v_preservation_tasks
  FROM (
    SELECT
      id, name, status, task_source, is_user_modified, deadline_intent,
      CASE
        WHEN status = 'COMPLETED' THEN
          CASE WHEN resolved_deadline_at IS NOT NULL THEN 'USER_ABSOLUTE' ELSE 'NO_DEADLINE' END
        ELSE
          CASE
            WHEN deadline_intent IN ('SYSTEM_RELATIVE', 'USER_RELATIVE') THEN
              CASE WHEN resolved_deadline_at IS NOT NULL THEN 'USER_ABSOLUTE' ELSE 'NO_DEADLINE' END
            ELSE deadline_intent
          END
      END AS new_deadline_intent,
      CASE
        WHEN status = 'COMPLETED' THEN
          resolved_deadline_at
        ELSE
          CASE
            WHEN deadline_intent IN ('SYSTEM_RELATIVE', 'USER_RELATIVE') THEN
              resolved_deadline_at
            ELSE custom_override_date
          END
      END AS new_resolved_deadline_at
    FROM public.tasks
    WHERE wedding_event_id = p_event_id
      AND NOT (
        status IN ('TODO', 'IN_PROGRESS')
        AND task_source IN ('SYSTEM_TEMPLATE', 'RECOMMENDATION')
        AND is_user_modified = false
      )
    ORDER BY id
  ) t;

  RETURN jsonb_build_object(
    'event_id', p_event_id,
    'is_main_event', v_is_main_event,
    'blocking_invariants', v_blocking_invariants,
    'impact_fingerprint', v_fingerprint,
    'deletion_candidates', v_deletion_candidates,
    'preservation_tasks', v_preservation_tasks,
    'budget_items_count', v_budget_count,
    'invitations_count', v_invitations_count
  );
END;
$$;


-- ===========================================================================
-- 4. TOP-EVT-003: COMMIT EVENT REMOVAL
-- ===========================================================================
-- IMPL-CONFLICT-005: p_explicit_choices removed. Task classification is server-authoritative.
--   Deletion candidates are determined exclusively by the server rules (untouched active
--   SYSTEM_TEMPLATE/RECOMMENDATION tasks). Clients cannot override this classification.
-- IMPL-CONFLICT-006: invitation_event_targetings rows are NOT mutated on event removal.
--   No is_active column exists in the approved Physical Design (Table 14). Targeting rows
--   remain as historical relationship records. The REMOVED event lifecycle_status is the
--   authoritative gate for Class D availability (D-INV-001, D-RSV-001 validate event status).
-- IMPL-GAP-003: BudgetItems are preserved with event link unlinked (wedding_event_id = NULL).
CREATE OR REPLACE FUNCTION api_v1.commit_event_removal(
  p_event_id uuid,
  p_impact_fingerprint text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_caller_role              varchar(50);
  v_wedding_id               uuid;
  v_is_main_event            boolean;
  v_lifecycle_status         varchar(50);
  v_main_events_count        integer;

  v_fingerprint              text;
  v_budget_count             integer := 0;
  v_invitations_count        integer := 0;
  v_tasks_json               jsonb;
  v_events_json              jsonb;
  v_initial_plan_generated   timestamptz;
BEGIN
  -- Load Event
  SELECT wedding_id, is_main_event, lifecycle_status
  INTO v_wedding_id, v_is_main_event, v_lifecycle_status
  FROM public.wedding_events
  WHERE id = p_event_id;

  IF v_wedding_id IS NULL THEN
    RAISE EXCEPTION 'Event not found.' USING ERRCODE = '44000';
  END IF;

  -- Authenticate & Authorize
  SELECT role INTO v_caller_role
  FROM public.wedding_members
  WHERE wedding_id = v_wedding_id
    AND user_id = auth.uid()
    AND status = 'ACTIVE';

  IF v_caller_role IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: Caller is not an active member of this wedding.'
      USING ERRCODE = '42501';
  END IF;

  -- Lock target wedding row
  SELECT initial_plan_generated_at INTO v_initial_plan_generated
  FROM public.weddings
  WHERE id = v_wedding_id
  FOR UPDATE;

  -- 1. Retry Guard: If event already REMOVED, return current authoritative state (stable/no side-effects)
  IF v_lifecycle_status = 'REMOVED' THEN
     SELECT json_agg(t) INTO v_tasks_json
     FROM (
       SELECT id, name, status, deadline_intent, date_offset, resolved_deadline_at, task_source, side, assignee_wedding_member_id, wedding_event_id
       FROM public.tasks
       WHERE wedding_id = v_wedding_id
       ORDER BY created_at ASC
     ) t;

     SELECT json_agg(e) INTO v_events_json
     FROM (
       SELECT id, name, expected_year, expected_month, exact_date, start_time, location, map_link, is_main_event, lifecycle_status
       FROM public.wedding_events
       WHERE wedding_id = v_wedding_id
       ORDER BY created_at ASC
     ) e;

     RETURN jsonb_build_object(
       'initial_plan_generated_at', v_initial_plan_generated,
       'replayed', true,
       'tasks', COALESCE(v_tasks_json, '[]'::jsonb),
       'events', COALESCE(v_events_json, '[]'::jsonb)
     );
  END IF;

  -- 2. Validate final Main Event protection
  IF v_is_main_event = true THEN
    SELECT count(*) INTO v_main_events_count
    FROM public.wedding_events
    WHERE wedding_id = v_wedding_id
      AND is_main_event = true
      AND lifecycle_status = 'ACTIVE';

    IF v_main_events_count <= 1 THEN
      RAISE EXCEPTION 'FINAL_MAIN_EVENT_INVARIANT: Cannot remove the final active Main Event of the wedding.'
        USING ERRCODE = '45000';
    END IF;
  END IF;

  -- 3. Verify material state fingerprint
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'budget_items') THEN
    EXECUTE 'SELECT count(*)::integer FROM public.budget_items WHERE wedding_event_id = $1' INTO v_budget_count USING p_event_id;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'invitation_event_targetings') THEN
    -- Total targeting count (no is_active filter — column not in approved Physical Design Table 14).
    EXECUTE 'SELECT count(*)::integer FROM public.invitation_event_targetings WHERE wedding_event_id = $1' INTO v_invitations_count USING p_event_id;
  END IF;

  SELECT md5(string_agg(row_data, '|')) INTO v_fingerprint
  FROM (
    SELECT 'event:' || id || ':' || lifecycle_status || ':' || is_main_event::text AS row_data
    FROM public.wedding_events
    WHERE id = p_event_id
    UNION ALL
    SELECT 'task:' || id || ':' || status || ':' || task_source || ':' || is_user_modified::text || ':' || deadline_intent || ':' || COALESCE(resolved_deadline_at::text, 'null')
    FROM public.tasks
    WHERE wedding_event_id = p_event_id
    UNION ALL
    SELECT 'budget:' || v_budget_count::text
    UNION ALL
    SELECT 'invitations:' || v_invitations_count::text
    ORDER BY 1
  ) s;

  IF v_fingerprint IS DISTINCT FROM p_impact_fingerprint THEN
    RAISE EXCEPTION 'STALE_IMPACT: The planning workspace state has changed since the preview was generated.'
      USING ERRCODE = '40001';
  END IF;

  -- 4. Mark Event as REMOVED (lifecycle status)
  UPDATE public.wedding_events
  SET lifecycle_status = 'REMOVED',
      updated_at = now()
  WHERE id = p_event_id;

  -- 5. Server-authoritative deletion: delete ALL untouched active system/recommendation tasks.
  --    This classification is server-determined and cannot be overridden by the client.
  DELETE FROM public.tasks
  WHERE wedding_event_id = p_event_id
    AND status IN ('TODO', 'IN_PROGRESS')
    AND task_source IN ('SYSTEM_TEMPLATE', 'RECOMMENDATION')
    AND is_user_modified = false;

  -- 6. Detach preserved tasks (user-created, user-modified, completed) to Wedding-level
  --    and apply detach rules per §06-trusted-operations-design.md section D.
  UPDATE public.tasks
  SET
    wedding_event_id = NULL,
    deadline_intent = CASE
      WHEN status = 'COMPLETED' THEN
        CASE WHEN resolved_deadline_at IS NOT NULL THEN 'USER_ABSOLUTE' ELSE 'NO_DEADLINE' END
      ELSE
        CASE
          WHEN deadline_intent IN ('SYSTEM_RELATIVE', 'USER_RELATIVE') THEN
            CASE WHEN resolved_deadline_at IS NOT NULL THEN 'USER_ABSOLUTE' ELSE 'NO_DEADLINE' END
          ELSE deadline_intent
        END
      END,
    custom_override_date = CASE
      WHEN status = 'COMPLETED' THEN
        CASE WHEN resolved_deadline_at IS NOT NULL THEN resolved_deadline_at ELSE NULL END
      ELSE
        CASE
          WHEN deadline_intent IN ('SYSTEM_RELATIVE', 'USER_RELATIVE') THEN
            CASE WHEN resolved_deadline_at IS NOT NULL THEN resolved_deadline_at ELSE NULL END
          ELSE custom_override_date
        END
      END,
    date_offset = NULL
  WHERE wedding_event_id = p_event_id;

  -- 7. Unlink BudgetItems: preserve budget records, unlink event association (cross-domain safely)
  --    IMPL-GAP-003: BudgetItems are preserved with wedding_event_id set to NULL.
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'budget_items') THEN
    EXECUTE 'UPDATE public.budget_items SET wedding_event_id = NULL WHERE wedding_event_id = $1' USING p_event_id;
  END IF;

  -- 8. invitation_event_targetings: NO mutation performed.
  --    Per approved Physical Design (Table 14), targeting rows have no lifecycle flag.
  --    Historical targeting relationship is preserved intact.
  --    Class D (D-INV-001, D-RSV-001) derives event availability from
  --    WeddingEvent.lifecycle_status = 'ACTIVE', not from a targeting soft-delete flag.
  --    IMPL-CONFLICT-006 RESOLVED: Removed unapproved is_active soft-deactivation.

  -- 9. Query and return updated planning state
  SELECT json_agg(t) INTO v_tasks_json
  FROM (
    SELECT id, name, status, deadline_intent, date_offset, resolved_deadline_at, task_source, side, assignee_wedding_member_id, wedding_event_id
    FROM public.tasks
    WHERE wedding_id = v_wedding_id
    ORDER BY created_at ASC
  ) t;

  SELECT json_agg(e) INTO v_events_json
  FROM (
    SELECT id, name, expected_year, expected_month, exact_date, start_time, location, map_link, is_main_event, lifecycle_status
    FROM public.wedding_events
    WHERE wedding_id = v_wedding_id
    ORDER BY created_at ASC
  ) e;

  RETURN jsonb_build_object(
    'initial_plan_generated_at', v_initial_plan_generated,
    'replayed', false,
    'tasks', COALESCE(v_tasks_json, '[]'::jsonb),
    'events', COALESCE(v_events_json, '[]'::jsonb)
  );
END;
$$;


-- ===========================================================================
-- 5. GRANTS & ROLES CONFIGURATION
-- ===========================================================================

-- Revoke execute from PUBLIC (new signatures)
REVOKE EXECUTE ON FUNCTION api_v1.preview_event_date_change(uuid, date, integer, integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION api_v1.commit_event_date_change(uuid, date, integer, integer, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION api_v1.preview_event_removal(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION api_v1.commit_event_removal(uuid, text) FROM PUBLIC;

-- Grant execution to authenticated role
GRANT EXECUTE ON FUNCTION api_v1.preview_event_date_change(uuid, date, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION api_v1.commit_event_date_change(uuid, date, integer, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION api_v1.preview_event_removal(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION api_v1.commit_event_removal(uuid, text) TO authenticated;

-- Set Security Definer owners to trusted_function_owner
ALTER FUNCTION api_v1.preview_event_date_change(uuid, date, integer, integer) OWNER TO trusted_function_owner;
ALTER FUNCTION api_v1.commit_event_date_change(uuid, date, integer, integer, text) OWNER TO trusted_function_owner;
ALTER FUNCTION api_v1.preview_event_removal(uuid) OWNER TO trusted_function_owner;
ALTER FUNCTION api_v1.commit_event_removal(uuid, text) OWNER TO trusted_function_owner;
