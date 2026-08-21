-- BATCH-03: Event Date Change & Event Removal Impact Review (TOP-EVT-002, TOP-EVT-003)

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
  v_review_json              json;
  v_preserved_json           json;
  v_unresolved_json          json;
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

  -- 2. Derive material impact fingerprint
  SELECT md5(string_agg(row_data, '|')) INTO v_fingerprint
  FROM (
    SELECT 'event:' || id || ':' || lifecycle_status || ':' || COALESCE(exact_date::text, 'null') || ':' || COALESCE(expected_year::text, 'null') || ':' || COALESCE(expected_month::text, 'null') || ':' || is_main_event::text AS row_data
    FROM public.wedding_events
    WHERE id = p_event_id
    UNION ALL
    SELECT 'task:' || id || ':' || status || ':' || deadline_intent || ':' || COALESCE(date_offset::text, 'null') || ':' || COALESCE(custom_override_date::text, 'null') || ':' || COALESCE(resolved_deadline_at::text, 'null') || ':' || is_user_modified::text || ':' || task_source
    FROM public.tasks
    WHERE (wedding_event_id = p_event_id OR (wedding_event_id IS NULL AND wedding_id = v_wedding_id AND deadline_intent = 'USER_ABSOLUTE' AND v_is_main_event = true))
    ORDER BY 1
  ) s;

  -- 3. Recalculated relative tasks (only if target is exact date)
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

  -- 4. Review tasks (active absolute tasks that will NOT automatically shift)
  SELECT COALESCE(json_agg(t), '[]'::json) INTO v_review_json
  FROM (
    SELECT id, name, deadline_intent, custom_override_date AS resolved_deadline_at
    FROM public.tasks
    WHERE wedding_id = v_wedding_id
      AND status IN ('TODO', 'IN_PROGRESS')
      AND deadline_intent = 'USER_ABSOLUTE'
      AND v_is_main_event = true
    ORDER BY id
  ) t;

  -- 5. Preserved tasks (completed tasks preserving history)
  SELECT COALESCE(json_agg(t), '[]'::json) INTO v_preserved_json
  FROM (
    SELECT id, name, status, deadline_intent, resolved_deadline_at
    FROM public.tasks
    WHERE wedding_event_id = p_event_id
      AND status = 'COMPLETED'
    ORDER BY id
  ) t;

  -- 6. Unresolved tasks (relative tasks that will lose exact dates in Exact -> Month transition)
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

  RETURN jsonb_build_object(
    'event_id', p_event_id,
    'current_precision', CASE WHEN v_current_exact_date IS NOT NULL THEN 'EXACT' ELSE 'MONTH' END,
    'target_precision', CASE WHEN p_target_exact_date IS NOT NULL THEN 'EXACT' ELSE 'MONTH' END,
    'impact_fingerprint', v_fingerprint,
    'recalculated_tasks', v_recalculated_json,
    'review_tasks', v_review_json,
    'preserved_tasks', v_preserved_json,
    'unresolved_tasks', v_unresolved_json
  );
END;
$$;


-- ===========================================================================
-- 2. TOP-EVT-002: COMMIT EVENT DATE CHANGE
-- ===========================================================================
CREATE OR REPLACE FUNCTION api_v1.commit_event_date_change(
  p_event_id uuid,
  p_target_exact_date date,
  p_target_expected_year integer,
  p_target_expected_month integer,
  p_impact_fingerprint text,
  p_batch_action_c text DEFAULT 'KEEP'
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
  v_delta_days               integer;
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

  -- Lock the target wedding row
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

  -- 1. Retry Guard: check if target dates are already applied on the Event
  IF v_current_exact_date IS NOT DISTINCT FROM p_target_exact_date AND
     v_current_expected_year IS NOT DISTINCT FROM p_target_expected_year AND
     v_current_expected_month IS NOT DISTINCT FROM p_target_expected_month THEN
     
     -- Re-query and return current plan details directly (successful replay)
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
  SELECT md5(string_agg(row_data, '|')) INTO v_fingerprint
  FROM (
    SELECT 'event:' || id || ':' || lifecycle_status || ':' || COALESCE(exact_date::text, 'null') || ':' || COALESCE(expected_year::text, 'null') || ':' || COALESCE(expected_month::text, 'null') || ':' || is_main_event::text AS row_data
    FROM public.wedding_events
    WHERE id = p_event_id
    UNION ALL
    SELECT 'task:' || id || ':' || status || ':' || deadline_intent || ':' || COALESCE(date_offset::text, 'null') || ':' || COALESCE(custom_override_date::text, 'null') || ':' || COALESCE(resolved_deadline_at::text, 'null') || ':' || is_user_modified::text || ':' || task_source
    FROM public.tasks
    WHERE (wedding_event_id = p_event_id OR (wedding_event_id IS NULL AND wedding_id = v_wedding_id AND deadline_intent = 'USER_ABSOLUTE' AND v_is_main_event = true))
    ORDER BY 1
  ) s;

  IF v_fingerprint IS DISTINCT FROM p_impact_fingerprint THEN
    RAISE EXCEPTION 'STALE_IMPACT: The planning workspace state has changed since the preview was generated.'
      USING ERRCODE = '40001';
  END IF;

  -- 3. Calculate delta days if both current and target are exact
  IF v_current_exact_date IS NOT NULL AND p_target_exact_date IS NOT NULL THEN
    v_delta_days := p_target_exact_date - v_current_exact_date;
  END IF;

  -- 4. Apply Date change to the Event
  UPDATE public.wedding_events
  SET exact_date = p_target_exact_date,
      expected_year = p_target_expected_year,
      expected_month = p_target_expected_month,
      updated_at = now()
  WHERE id = p_event_id;

  -- 5. Cascade to relative active tasks (completed tasks are untouched due to status check)
  UPDATE public.tasks
  SET resolved_deadline_at = (CASE WHEN p_target_exact_date IS NOT NULL THEN p_target_exact_date + date_offset ELSE NULL END)
  WHERE wedding_event_id = p_event_id
    AND status IN ('TODO', 'IN_PROGRESS')
    AND deadline_intent IN ('SYSTEM_RELATIVE', 'USER_RELATIVE');

  -- 6. Apply Batch Action SHIFT to active absolute tasks (Nhóm C) if exact delta is available and this is the Main Event
  IF p_batch_action_c = 'SHIFT' AND v_delta_days IS NOT NULL AND v_is_main_event = true THEN
    UPDATE public.tasks
    SET custom_override_date = custom_override_date + v_delta_days,
        resolved_deadline_at = custom_override_date + v_delta_days
    WHERE wedding_id = v_wedding_id
      AND status IN ('TODO', 'IN_PROGRESS')
      AND deadline_intent = 'USER_ABSOLUTE';
  END IF;

  -- 7. Query and return updated lists
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

  -- Classify active untouched system-origin tasks (Deletion Candidates)
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

  -- Classify preserved tasks (user-created, user-modified, or completed)
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
CREATE OR REPLACE FUNCTION api_v1.commit_event_removal(
  p_event_id uuid,
  p_impact_fingerprint text,
  p_explicit_choices jsonb DEFAULT '{}'::jsonb
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

  -- 1. Retry Guard: If event is already removed, return current authoritative state (stable/no side-effects)
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

  -- 3. Cross-wedding input parameter integrity validation
  -- Ensure no tasks from other weddings are passed in the choices
  IF EXISTS (
    SELECT 1 
    FROM jsonb_array_elements_text(COALESCE(p_explicit_choices -> 'delete_tasks', '[]'::jsonb)) AS t_id
    WHERE NOT EXISTS (SELECT 1 FROM public.tasks WHERE id = t_id::uuid AND wedding_event_id = p_event_id)
  ) OR EXISTS (
    SELECT 1 
    FROM jsonb_array_elements_text(COALESCE(p_explicit_choices -> 'preserve_tasks', '[]'::jsonb)) AS t_id
    WHERE NOT EXISTS (SELECT 1 FROM public.tasks WHERE id = t_id::uuid AND wedding_event_id = p_event_id)
  ) THEN
    RAISE EXCEPTION 'Invalid task reference: All chosen tasks must belong to the event being removed.'
      USING ERRCODE = '45000';
  END IF;

  -- 4. Verify material state fingerprint
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'budget_items') THEN
    EXECUTE 'SELECT count(*)::integer FROM public.budget_items WHERE wedding_event_id = $1' INTO v_budget_count USING p_event_id;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'invitation_event_targetings') THEN
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

  -- 5. Mark Event as REMOVED (lifecycle status)
  UPDATE public.wedding_events
  SET lifecycle_status = 'REMOVED',
      updated_at = now()
  WHERE id = p_event_id;

  -- 6. Perform downstream Task deletions
  -- Delete all active untouched system tasks of this event, EXCEPT those explicitly listed to be preserved
  DELETE FROM public.tasks
  WHERE wedding_event_id = p_event_id
    AND status IN ('TODO', 'IN_PROGRESS')
    AND task_source IN ('SYSTEM_TEMPLATE', 'RECOMMENDATION')
    AND is_user_modified = false
    AND id NOT IN (
      SELECT jsonb_array_elements_text(COALESCE(p_explicit_choices -> 'preserve_tasks', '[]'::jsonb))::uuid
    );

  -- Delete any tasks explicitly chosen for deletion
  DELETE FROM public.tasks
  WHERE id = ANY(ARRAY(SELECT jsonb_array_elements_text(COALESCE(p_explicit_choices -> 'delete_tasks', '[]'::jsonb))::uuid));

  -- 7. Preserved tasks: detach to Wedding-level and apply detach rules
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

  -- 8. Unlink BudgetItems linked to this removed Event (cross-domain safely)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'budget_items') THEN
    EXECUTE 'UPDATE public.budget_items SET wedding_event_id = NULL WHERE wedding_event_id = $1' USING p_event_id;
  END IF;

  -- 9. Delete Invitation targetings linked to this removed Event (cross-domain safely)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'invitation_event_targetings') THEN
    EXECUTE 'DELETE FROM public.invitation_event_targetings WHERE wedding_event_id = $1' USING p_event_id;
  END IF;

  -- 10. Query and return updated planning state
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

-- Revoke execute from PUBLIC
REVOKE EXECUTE ON FUNCTION api_v1.preview_event_date_change(uuid, date, integer, integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION api_v1.commit_event_date_change(uuid, date, integer, integer, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION api_v1.preview_event_removal(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION api_v1.commit_event_removal(uuid, text, jsonb) FROM PUBLIC;

-- Grant execution to authenticated role
GRANT EXECUTE ON FUNCTION api_v1.preview_event_date_change(uuid, date, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION api_v1.commit_event_date_change(uuid, date, integer, integer, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION api_v1.preview_event_removal(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION api_v1.commit_event_removal(uuid, text, jsonb) TO authenticated;

-- Set Security Definer owners to trusted_function_owner
ALTER FUNCTION api_v1.preview_event_date_change(uuid, date, integer, integer) OWNER TO trusted_function_owner;
ALTER FUNCTION api_v1.commit_event_date_change(uuid, date, integer, integer, text, text) OWNER TO trusted_function_owner;
ALTER FUNCTION api_v1.preview_event_removal(uuid) OWNER TO trusted_function_owner;
ALTER FUNCTION api_v1.commit_event_removal(uuid, text, jsonb) OWNER TO trusted_function_owner;
