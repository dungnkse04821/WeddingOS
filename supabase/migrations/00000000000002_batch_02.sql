-- BATCH-02: Planning Core & Initial Plan

-- ==========================================
-- 1. WEDDING_EVENTS TABLE
-- ==========================================
CREATE TABLE public.wedding_events (
  id               uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id       uuid         NOT NULL REFERENCES public.weddings (id) ON DELETE CASCADE,
  name             varchar(255) NOT NULL,
  expected_year    integer,
  expected_month   integer,
  exact_date       date,
  start_time       time,
  location         text,
  map_link         text,
  is_main_event    boolean      NOT NULL DEFAULT false,
  lifecycle_status varchar(50)  NOT NULL DEFAULT 'ACTIVE',
  created_at       timestamptz  NOT NULL DEFAULT now(),
  updated_at       timestamptz  NOT NULL DEFAULT now(),
  
  CONSTRAINT chk_events_expected_month CHECK (expected_month BETWEEN 1 AND 12),
  CONSTRAINT chk_event_date_precision CHECK (
    (exact_date IS NOT NULL AND expected_year IS NULL AND expected_month IS NULL) OR 
    (exact_date IS NULL AND expected_year IS NOT NULL AND expected_month IS NOT NULL)
  ),
  CONSTRAINT chk_events_lifecycle CHECK (lifecycle_status IN ('ACTIVE', 'REMOVED')),
  -- Unique key for same-wedding compound references
  CONSTRAINT uq_events_wedding_key UNIQUE (wedding_id, id)
);

-- Index to enforce at most one active main event per wedding
CREATE UNIQUE INDEX uq_main_wedding_event 
  ON public.wedding_events (wedding_id) 
  WHERE (is_main_event = true AND lifecycle_status = 'ACTIVE');

-- ==========================================
-- 2. TASKS TABLE
-- ==========================================
CREATE TABLE public.tasks (
  id                         uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id                 uuid         NOT NULL REFERENCES public.weddings (id) ON DELETE CASCADE,
  wedding_event_id           uuid,
  assignee_wedding_member_id uuid,
  name                       varchar(255) NOT NULL,
  status                     varchar(50)  NOT NULL DEFAULT 'TODO',
  deadline_intent            varchar(50)  NOT NULL,
  date_offset                integer,
  custom_override_date       date,
  completed_at               timestamptz,
  resolved_deadline_at       date,
  task_source                varchar(50)  NOT NULL DEFAULT 'SYSTEM_TEMPLATE',
  is_user_modified           boolean      NOT NULL DEFAULT false,
  side                       varchar(50)  NOT NULL DEFAULT 'COMMON',
  created_at                 timestamptz  NOT NULL DEFAULT now(),
  updated_at                 timestamptz  NOT NULL DEFAULT now(),
  
  CONSTRAINT chk_tasks_status_enum CHECK (status IN ('TODO', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
  CONSTRAINT chk_tasks_source_enum CHECK (task_source IN ('SYSTEM_TEMPLATE', 'RECOMMENDATION', 'USER')),
  CONSTRAINT chk_tasks_side CHECK (side IN ('COMMON', 'BRIDE_SIDE', 'GROOM_SIDE')),
  
  CONSTRAINT chk_task_deadline_intent CHECK (
    (deadline_intent = 'SYSTEM_RELATIVE' AND wedding_event_id IS NOT NULL AND date_offset IS NOT NULL AND custom_override_date IS NULL) OR
    (deadline_intent = 'USER_RELATIVE' AND wedding_event_id IS NOT NULL AND date_offset IS NOT NULL AND custom_override_date IS NULL) OR
    (deadline_intent = 'USER_ABSOLUTE' AND custom_override_date IS NOT NULL AND date_offset IS NULL AND wedding_event_id IS NULL) OR
    (deadline_intent = 'NO_DEADLINE' AND date_offset IS NULL AND custom_override_date IS NULL)
  ),
  
  -- Same-wedding assignee validation
  CONSTRAINT fk_tasks_assignee_wedding FOREIGN KEY (wedding_id, assignee_wedding_member_id) 
    REFERENCES public.wedding_members (wedding_id, id) ON DELETE SET NULL (assignee_wedding_member_id),
    
  -- Same-wedding event validation
  CONSTRAINT fk_tasks_event_wedding FOREIGN KEY (wedding_id, wedding_event_id) 
    REFERENCES public.wedding_events (wedding_id, id) ON DELETE RESTRICT
);

-- ==========================================
-- 3. TRIGGERS FOR SECURITY & BUSINESS RULES
-- ==========================================

-- A. Assignee same-wedding & active state check
CREATE OR REPLACE FUNCTION public.fn_tasks_assignee_integrity_check()
RETURNS trigger AS $$
BEGIN
  IF NEW.assignee_wedding_member_id IS NOT NULL AND 
     (TG_OP = 'INSERT' OR NEW.assignee_wedding_member_id IS DISTINCT FROM OLD.assignee_wedding_member_id) THEN
     
     IF NOT EXISTS (
       SELECT 1 
       FROM public.wedding_members 
       WHERE wedding_id = NEW.wedding_id 
         AND id = NEW.assignee_wedding_member_id 
         AND status = 'ACTIVE'
     ) THEN
       RAISE EXCEPTION 'Assignee member must be active and belong to the same wedding.' 
         USING ERRCODE = '45000';
     END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_tasks_assignee_integrity_check
  BEFORE INSERT OR UPDATE ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public.fn_tasks_assignee_integrity_check();


-- B. Provenance Protection (task_source & is_user_modified)
CREATE OR REPLACE FUNCTION public.fn_tasks_provenance_protection()
RETURNS trigger AS $$
BEGIN
  -- If executed via trusted system path (owned by trusted_function_owner or postgres superuser)
  IF CURRENT_USER IN ('trusted_function_owner', 'postgres') THEN
    RETURN NEW;
  END IF;

  -- Otherwise, it is a client direct Class-B operation
  IF TG_OP = 'INSERT' THEN
    NEW.task_source := 'USER';
    NEW.is_user_modified := false;
  ELSIF TG_OP = 'UPDATE' THEN
    -- Prevent modification of task_source
    NEW.task_source := OLD.task_source;
    
    -- Client cannot reset true -> false
    IF OLD.is_user_modified = true THEN
      NEW.is_user_modified := true;
    END IF;
    
    -- If core fields are modified, set is_user_modified = true
    IF (OLD.name IS DISTINCT FROM NEW.name OR
        OLD.deadline_intent IS DISTINCT FROM NEW.deadline_intent OR
        OLD.date_offset IS DISTINCT FROM NEW.date_offset OR
        OLD.custom_override_date IS DISTINCT FROM NEW.custom_override_date OR
        OLD.side IS DISTINCT FROM NEW.side OR
        OLD.assignee_wedding_member_id IS DISTINCT FROM NEW.assignee_wedding_member_id OR
        OLD.wedding_event_id IS DISTINCT FROM NEW.wedding_event_id) THEN
      NEW.is_user_modified := true;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_tasks_provenance_protection
  BEFORE INSERT OR UPDATE ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public.fn_tasks_provenance_protection();


-- C. Resolved Deadline calculation & completed date tracker
CREATE OR REPLACE FUNCTION public.fn_tasks_resolved_deadline()
RETURNS trigger AS $$
DECLARE
  v_exact_date date;
BEGIN
  -- Handle status transition to completed
  IF NEW.status = 'COMPLETED' THEN
    IF TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'COMPLETED' THEN
      NEW.completed_at := now();
    END IF;
    -- Preserve historical resolved_deadline_at
    IF TG_OP = 'UPDATE' THEN
      NEW.resolved_deadline_at := OLD.resolved_deadline_at;
    END IF;
    RETURN NEW;
  END IF;

  -- Handle transition out of completed (reopen)
  IF TG_OP = 'UPDATE' AND OLD.status = 'COMPLETED' AND NEW.status IS DISTINCT FROM 'COMPLETED' THEN
    NEW.completed_at := NULL;
  END IF;

  -- Calculate resolved_deadline_at based on deadline_intent
  IF NEW.deadline_intent IN ('SYSTEM_RELATIVE', 'USER_RELATIVE') THEN
    SELECT exact_date INTO v_exact_date 
    FROM public.wedding_events 
    WHERE id = NEW.wedding_event_id;
    
    IF v_exact_date IS NOT NULL THEN
      NEW.resolved_deadline_at := v_exact_date + NEW.date_offset;
    ELSE
      NEW.resolved_deadline_at := NULL;
    END IF;
    
  ELSIF NEW.deadline_intent = 'USER_ABSOLUTE' THEN
    NEW.resolved_deadline_at := NEW.custom_override_date;
  ELSE
    NEW.resolved_deadline_at := NULL;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_tasks_resolved_deadline
  BEFORE INSERT OR UPDATE ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public.fn_tasks_resolved_deadline();


-- D. Event Date Change cascade recalculation
CREATE OR REPLACE FUNCTION public.fn_events_date_change_cascade()
RETURNS trigger AS $$
BEGIN
  IF OLD.exact_date IS DISTINCT FROM NEW.exact_date THEN
    -- Update all active relative tasks linked to this event
    UPDATE public.tasks
    SET resolved_deadline_at = (CASE WHEN NEW.exact_date IS NOT NULL THEN NEW.exact_date + date_offset ELSE NULL END)
    WHERE wedding_event_id = NEW.id
      AND status IN ('TODO', 'IN_PROGRESS')
      AND deadline_intent IN ('SYSTEM_RELATIVE', 'USER_RELATIVE');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_events_date_change_cascade
  AFTER UPDATE OF exact_date ON public.wedding_events
  FOR EACH ROW EXECUTE FUNCTION public.fn_events_date_change_cascade();

-- ==========================================
-- 4. TRUSTED RPC OPERATION (TOP-WED-002)
-- ==========================================

CREATE OR REPLACE FUNCTION api_v1.generate_initial_plan(
  p_wedding_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_caller_role              varchar(50);
  v_initial_plan_generated   timestamptz;
  v_cultural_context         varchar(50);
  v_main_event_id            uuid;
  v_main_event_exact_date    date;
  v_main_event_expected_year integer;
  v_main_event_expected_month integer;
  v_tasks_json               jsonb;
  v_events_json              jsonb;
  
  -- Version-controlled configuration loaded statically
  v_templates_json jsonb := '{
    "TUY_CHON": {
      "events": [],
      "tasks": [
        {"name": "Chốt nhà hàng và đặt cọc nơi tổ chức", "date_offset": -180, "deadline_intent": "SYSTEM_RELATIVE", "side": "COMMON", "link_event": "MAIN_EVENT"},
        {"name": "Lập danh sách khách mời sơ bộ", "date_offset": -120, "deadline_intent": "SYSTEM_RELATIVE", "side": "COMMON", "link_event": "MAIN_EVENT"},
        {"name": "Thuê trang phục cưới & chụp ảnh", "date_offset": -90, "deadline_intent": "SYSTEM_RELATIVE", "side": "COMMON", "link_event": "MAIN_EVENT"},
        {"name": "Gửi thiệp cưới đến bạn bè & người thân", "date_offset": -30, "deadline_intent": "SYSTEM_RELATIVE", "side": "COMMON", "link_event": "MAIN_EVENT"},
        {"name": "Họp mặt ban tổ chức & MC", "date_offset": -7, "deadline_intent": "SYSTEM_RELATIVE", "side": "COMMON", "link_event": "MAIN_EVENT"}
      ]
    },
    "VIETNAMESE": {
      "events": [
        {"name": "Lễ dạm ngõ & họp mặt hai gia đình", "date_offset": -14},
        {"name": "Lễ ăn hỏi & đám hỏi", "date_offset": -45}
      ],
      "tasks": [
        {"name": "Chốt nhà hàng và đặt cọc nơi tổ chức", "date_offset": -180, "deadline_intent": "SYSTEM_RELATIVE", "side": "COMMON", "link_event": "MAIN_EVENT"},
        {"name": "Lập danh sách khách mời sơ bộ", "date_offset": -120, "deadline_intent": "SYSTEM_RELATIVE", "side": "COMMON", "link_event": "MAIN_EVENT"},
        {"name": "Thuê trang phục cưới & chụp ảnh ngoại cảnh", "date_offset": -90, "deadline_intent": "SYSTEM_RELATIVE", "side": "COMMON", "link_event": "MAIN_EVENT"},
        {"name": "Chuẩn bị mâm quả & sính lễ đám hỏi", "date_offset": 0, "deadline_intent": "SYSTEM_RELATIVE", "side": "COMMON", "link_event": "Lễ ăn hỏi & đám hỏi"},
        {"name": "Gửi thiệp cưới đến họ hàng & bạn bè", "date_offset": -30, "deadline_intent": "SYSTEM_RELATIVE", "side": "COMMON", "link_event": "MAIN_EVENT"},
        {"name": "Tiếp đãi khách tại Lễ dạm ngõ", "date_offset": 0, "deadline_intent": "SYSTEM_RELATIVE", "side": "COMMON", "link_event": "Lễ dạm ngõ & họp mặt hai gia đình"},
        {"name": "Họp mặt ban tổ chức & MC", "date_offset": -7, "deadline_intent": "SYSTEM_RELATIVE", "side": "COMMON", "link_event": "MAIN_EVENT"}
      ]
    },
    "WESTERN": {
      "events": [
        {"name": "Rehearsal Dinner", "date_offset": -1}
      ],
      "tasks": [
        {"name": "Book Wedding Venue & Catering deposit", "date_offset": -180, "deadline_intent": "SYSTEM_RELATIVE", "side": "COMMON", "link_event": "MAIN_EVENT"},
        {"name": "Draft tentative guest list", "date_offset": -120, "deadline_intent": "SYSTEM_RELATIVE", "side": "COMMON", "link_event": "MAIN_EVENT"},
        {"name": "Wedding gown and tuxedo fittings", "date_offset": -90, "deadline_intent": "SYSTEM_RELATIVE", "side": "COMMON", "link_event": "MAIN_EVENT"},
        {"name": "Send out formal invitations", "date_offset": -45, "deadline_intent": "SYSTEM_RELATIVE", "side": "COMMON", "link_event": "MAIN_EVENT"},
        {"name": "Final walkthrough of catering & sync", "date_offset": 0, "deadline_intent": "SYSTEM_RELATIVE", "side": "COMMON", "link_event": "Rehearsal Dinner"}
      ]
    }
  }';
  
  v_config                   jsonb;
  v_event                    jsonb;
  v_task                     jsonb;
  v_event_id                 uuid;
  v_event_name               varchar(255);
  v_event_offset             integer;
  v_mapped_event_id          uuid;
BEGIN
  -- 1. Authorization: check if caller is an active member
  SELECT role INTO v_caller_role
  FROM public.wedding_members
  WHERE wedding_id = p_wedding_id
    AND user_id = auth.uid()
    AND status = 'ACTIVE';

  IF v_caller_role IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: Caller is not an active member of this wedding.'
      USING ERRCODE = '42501';
  END IF;

  -- 2. Concurrency primitive: lock the wedding row
  SELECT initial_plan_generated_at, cultural_context
  INTO v_initial_plan_generated, v_cultural_context
  FROM public.weddings
  WHERE id = p_wedding_id
  FOR UPDATE;

  -- 3. Retry guard: if plan is already generated, return current list directly (idempotency success)
  IF v_initial_plan_generated IS NOT NULL THEN
    SELECT json_agg(t) INTO v_tasks_json
    FROM (
      SELECT id, name, status, deadline_intent, date_offset, resolved_deadline_at, task_source, side, assignee_wedding_member_id, wedding_event_id
      FROM public.tasks
      WHERE wedding_id = p_wedding_id
      ORDER BY created_at ASC
    ) t;

    SELECT json_agg(e) INTO v_events_json
    FROM (
      SELECT id, name, expected_year, expected_month, exact_date, start_time, location, map_link, is_main_event, lifecycle_status
      FROM public.wedding_events
      WHERE wedding_id = p_wedding_id
      ORDER BY created_at ASC
    ) e;

    RETURN jsonb_build_object(
      'initial_plan_generated_at', v_initial_plan_generated,
      'replayed', true,
      'tasks', COALESCE(v_tasks_json, '[]'::jsonb),
      'events', COALESCE(v_events_json, '[]'::jsonb)
    );
  END IF;

  -- 4. Validate Main Event context exists
  SELECT id, exact_date, expected_year, expected_month
  INTO v_main_event_id, v_main_event_exact_date, v_main_event_expected_year, v_main_event_expected_month
  FROM public.wedding_events
  WHERE wedding_id = p_wedding_id
    AND is_main_event = true
    AND lifecycle_status = 'ACTIVE'
  LIMIT 1;

  IF v_main_event_id IS NULL THEN
    RAISE EXCEPTION 'MAIN_EVENT_REQUIRED: Wedding must have a main event configured first.'
      USING ERRCODE = '45000';
  END IF;

  -- Get cultural configuration template from JSON
  v_config := v_templates_json -> COALESCE(v_cultural_context, 'TUY_CHON');
  IF v_config IS NULL THEN
    v_config := v_templates_json -> 'TUY_CHON';
  END IF;

  -- 5. Create local session-isolated mapping for event linkages
  CREATE TEMP TABLE IF NOT EXISTS temp_event_map (
    name varchar(255) PRIMARY KEY,
    id uuid NOT NULL
  );
  TRUNCATE temp_event_map;
  INSERT INTO temp_event_map (name, id) VALUES ('MAIN_EVENT', v_main_event_id);

  -- 6. Generate suggested WeddingEvents
  FOR v_event IN SELECT * FROM jsonb_array_elements(v_config -> 'events') LOOP
    v_event_name := v_event ->> 'name';
    v_event_offset := (v_event ->> 'date_offset')::integer;
    
    -- Check if it already exists (idempotency/retry safety)
    SELECT id INTO v_event_id
    FROM public.wedding_events
    WHERE wedding_id = p_wedding_id
      AND name = v_event_name
      AND lifecycle_status = 'ACTIVE'
    LIMIT 1;
    
    IF v_event_id IS NULL THEN
      INSERT INTO public.wedding_events (
        wedding_id,
        name,
        exact_date,
        expected_year,
        expected_month,
        is_main_event,
        lifecycle_status
      ) VALUES (
        p_wedding_id,
        v_event_name,
        CASE WHEN v_main_event_exact_date IS NOT NULL THEN v_main_event_exact_date + v_event_offset ELSE NULL END,
        CASE WHEN v_main_event_exact_date IS NULL THEN v_main_event_expected_year ELSE NULL END,
        CASE WHEN v_main_event_exact_date IS NULL THEN v_main_event_expected_month ELSE NULL END,
        false,
        'ACTIVE'
      ) RETURNING id INTO v_event_id;
    END IF;
    
    INSERT INTO temp_event_map (name, id)
    VALUES (v_event_name, v_event_id)
    ON CONFLICT (name) DO UPDATE SET id = EXCLUDED.id;
  END LOOP;

  -- 7. Generate tasks from config
  FOR v_task IN SELECT * FROM jsonb_array_elements(v_config -> 'tasks') LOOP
    SELECT id INTO v_mapped_event_id
    FROM temp_event_map
    WHERE name = (v_task ->> 'link_event');
    
    IF v_mapped_event_id IS NULL THEN
      v_mapped_event_id := v_main_event_id;
    END IF;

    INSERT INTO public.tasks (
      wedding_id,
      wedding_event_id,
      name,
      status,
      deadline_intent,
      date_offset,
      task_source,
      is_user_modified,
      side
    ) VALUES (
      p_wedding_id,
      v_mapped_event_id,
      v_task ->> 'name',
      'TODO',
      v_task ->> 'deadline_intent',
      (v_task ->> 'date_offset')::integer,
      'SYSTEM_TEMPLATE',
      false,
      COALESCE(v_task ->> 'side', 'COMMON')
    );
  END LOOP;

  -- Drop temporary table
  DROP TABLE temp_event_map;

  -- 8. Set initial_plan_generated_at atomically
  UPDATE public.weddings
  SET initial_plan_generated_at = now()
  WHERE id = p_wedding_id;

  -- 9. Query and return generated task details
  SELECT json_agg(t) INTO v_tasks_json
  FROM (
    SELECT id, name, status, deadline_intent, date_offset, resolved_deadline_at, task_source, side, assignee_wedding_member_id, wedding_event_id
    FROM public.tasks
    WHERE wedding_id = p_wedding_id
    ORDER BY created_at ASC
  ) t;

  SELECT json_agg(e) INTO v_events_json
  FROM (
    SELECT id, name, expected_year, expected_month, exact_date, start_time, location, map_link, is_main_event, lifecycle_status
    FROM public.wedding_events
    WHERE wedding_id = p_wedding_id
    ORDER BY created_at ASC
  ) e;

  RETURN jsonb_build_object(
    'initial_plan_generated_at', now(),
    'replayed', false,
    'tasks', COALESCE(v_tasks_json, '[]'::jsonb),
    'events', COALESCE(v_events_json, '[]'::jsonb)
  );

END;
$$;

-- Revoke execute from PUBLIC
REVOKE EXECUTE ON FUNCTION api_v1.generate_initial_plan(uuid) FROM PUBLIC;

-- Grant execution permissions
GRANT EXECUTE ON FUNCTION api_v1.generate_initial_plan(uuid) TO authenticated;
ALTER FUNCTION api_v1.generate_initial_plan(uuid) OWNER TO trusted_function_owner;

-- ==========================================
-- 5. GRANTS AND POLICIES FOR DATA API
-- ==========================================

-- Enable Row Level Security
ALTER TABLE public.wedding_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- Wedding Events Policies
CREATE POLICY select_events_if_member ON public.wedding_events
  FOR SELECT TO authenticated
  USING (security.is_active_wedding_member(wedding_id));

CREATE POLICY insert_events_if_member ON public.wedding_events
  FOR INSERT TO authenticated
  WITH CHECK (security.can_mutate_wedding(wedding_id));

CREATE POLICY update_events_if_member ON public.wedding_events
  FOR UPDATE TO authenticated
  USING (security.can_mutate_wedding(wedding_id))
  WITH CHECK (security.can_mutate_wedding(wedding_id));

-- Tasks Policies
CREATE POLICY select_tasks_if_member ON public.tasks
  FOR SELECT TO authenticated
  USING (security.is_active_wedding_member(wedding_id));

CREATE POLICY insert_tasks_if_member ON public.tasks
  FOR INSERT TO authenticated
  WITH CHECK (security.can_mutate_wedding(wedding_id));

CREATE POLICY update_tasks_if_member ON public.tasks
  FOR UPDATE TO authenticated
  USING (security.can_mutate_wedding(wedding_id))
  WITH CHECK (security.can_mutate_wedding(wedding_id));

-- Grants for authenticated role on Class-B columns (excl. task_source & is_user_modified)
GRANT SELECT ON public.wedding_events TO authenticated;
GRANT INSERT (id, wedding_id, name, expected_year, expected_month, exact_date, start_time, location, map_link, is_main_event) ON public.wedding_events TO authenticated;

-- CRITICAL: Omit expected_year, expected_month, exact_date to block direct client date mutation (bypassing TOP-EVT-002)
GRANT UPDATE (name, start_time, location, map_link) ON public.wedding_events TO authenticated;

GRANT SELECT ON public.tasks TO authenticated;
GRANT INSERT (id, wedding_id, wedding_event_id, assignee_wedding_member_id, name, status, deadline_intent, date_offset, custom_override_date, completed_at, resolved_deadline_at, side) ON public.tasks TO authenticated;
GRANT UPDATE (assignee_wedding_member_id, name, status, deadline_intent, date_offset, custom_override_date, completed_at, resolved_deadline_at, side) ON public.tasks TO authenticated;

-- Grants for trusted execution context role (trusted_function_owner)
GRANT ALL PRIVILEGES ON public.weddings TO trusted_function_owner;
GRANT ALL PRIVILEGES ON public.wedding_events TO trusted_function_owner;
GRANT ALL PRIVILEGES ON public.tasks TO trusted_function_owner;
