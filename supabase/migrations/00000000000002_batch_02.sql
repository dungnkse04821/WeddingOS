-- BATCH-02: Planning Core & Initial Plan
CREATE SCHEMA IF NOT EXISTS internal;

-- Ensure trusted_function_owner has access to internal schema
GRANT USAGE ON SCHEMA internal TO trusted_function_owner;

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
-- 3. PLAN TEMPLATES CONFIG (DEC-B-001)
-- ==========================================
CREATE TABLE internal.plan_template_tasks (
  id               serial       PRIMARY KEY,
  cultural_context varchar(50)  NOT NULL,
  name             varchar(255) NOT NULL,
  date_offset      integer      NOT NULL,
  deadline_intent  varchar(50)  NOT NULL DEFAULT 'SYSTEM_RELATIVE',
  side             varchar(50)  NOT NULL DEFAULT 'COMMON'
);

-- Only trusted operation owner can read template configs
ALTER TABLE internal.plan_template_tasks OWNER TO trusted_function_owner;

-- Populate default plan templates
INSERT INTO internal.plan_template_tasks (cultural_context, name, date_offset, deadline_intent, side) VALUES
  ('TUY_CHON', 'Chốt nhà hàng và đặt cọc nơi tổ chức', -180, 'SYSTEM_RELATIVE', 'COMMON'),
  ('TUY_CHON', 'Lập danh sách khách mời sơ bộ', -120, 'SYSTEM_RELATIVE', 'COMMON'),
  ('TUY_CHON', 'Thuê trang phục cưới & chụp ảnh', -90, 'SYSTEM_RELATIVE', 'COMMON'),
  ('TUY_CHON', 'Gửi thiệp cưới đến bạn bè & người thân', -30, 'SYSTEM_RELATIVE', 'COMMON'),
  ('TUY_CHON', 'Họp mặt ban tổ chức & MC', -7, 'SYSTEM_RELATIVE', 'COMMON'),
  
  ('VIETNAMESE', 'Chốt nhà hàng và đặt cọc nơi tổ chức', -180, 'SYSTEM_RELATIVE', 'COMMON'),
  ('VIETNAMESE', 'Lập danh sách khách mời sơ bộ', -120, 'SYSTEM_RELATIVE', 'COMMON'),
  ('VIETNAMESE', 'Thuê trang phục cưới & chụp ảnh ngoại cảnh', -90, 'SYSTEM_RELATIVE', 'COMMON'),
  ('VIETNAMESE', 'Chuẩn bị mâm quả & sính lễ đám hỏi', -45, 'SYSTEM_RELATIVE', 'COMMON'),
  ('VIETNAMESE', 'Gửi thiệp cưới đến họ hàng & bạn bè', -30, 'SYSTEM_RELATIVE', 'COMMON'),
  ('VIETNAMESE', 'Lễ dạm ngõ & họp mặt hai gia đình', -14, 'SYSTEM_RELATIVE', 'COMMON'),
  ('VIETNAMESE', 'Họp mặt ban tổ chức & MC', -7, 'SYSTEM_RELATIVE', 'COMMON'),

  ('WESTERN', 'Book Wedding Venue & Catering deposit', -180, 'SYSTEM_RELATIVE', 'COMMON'),
  ('WESTERN', 'Draft tentative guest list', -120, 'SYSTEM_RELATIVE', 'COMMON'),
  ('WESTERN', 'Wedding gown and tuxedo fittings', -90, 'SYSTEM_RELATIVE', 'COMMON'),
  ('WESTERN', 'Send out formal invitations', -45, 'SYSTEM_RELATIVE', 'COMMON'),
  ('WESTERN', 'Rehearsal dinner & MC sync', -7, 'SYSTEM_RELATIVE', 'COMMON');

-- ==========================================
-- 4. TRIGGERS FOR SECURITY & BUSINESS RULES
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
  -- If executed via trusted system path (owned by trusted_function_owner)
  IF CURRENT_USER = 'trusted_function_owner' THEN
    RETURN NEW;
  END IF;

  -- Otherwise, it is a client direct Class-B operation
  IF TG_OP = 'INSERT' THEN
    NEW.task_source := 'USER';
    NEW.is_user_modified := false;
  ELSIF TG_OP = 'UPDATE' THEN
    -- Prevent modification of task_source
    NEW.task_source := OLD.task_source;
    
    -- If core fields are modified, set is_user_modified = true
    IF (OLD.name IS DISTINCT FROM NEW.name OR
        OLD.deadline_intent IS DISTINCT FROM NEW.deadline_intent OR
        OLD.date_offset IS DISTINCT FROM NEW.date_offset OR
        OLD.custom_override_date IS DISTINCT FROM NEW.custom_override_date OR
        OLD.side IS DISTINCT FROM NEW.side OR
        OLD.assignee_wedding_member_id IS DISTINCT FROM NEW.assignee_wedding_member_id OR
        OLD.wedding_event_id IS DISTINCT FROM NEW.wedding_event_id) THEN
      NEW.is_user_modified := true;
    ELSE
      -- Maintain old value if no core fields modified
      NEW.is_user_modified := OLD.is_user_modified;
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
-- 5. TRUSTED RPC OPERATION (TOP-WED-002)
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
  v_task_count               integer;
  v_tasks_json               jsonb;
BEGIN
  -- 1. Authorization: check if caller is an active member
  -- Run internal checks via explicit schema references
  SELECT role INTO v_caller_role
  FROM public.wedding_members
  WHERE wedding_id = p_wedding_id
    AND user_id = auth.uid()
    AND status = 'ACTIVE';

  IF v_caller_role IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: Caller is not an active member of this wedding.'
      USING ERRCODE = '42501';
  END IF;

  -- 2. Concurrency primitive: lock the wedding row to serialize concurrent first-generation attempts
  -- Solves concurrent TOP-WED-002 race conditions
  SELECT initial_plan_generated_at, cultural_context
  INTO v_initial_plan_generated, v_cultural_context
  FROM public.weddings
  WHERE id = p_wedding_id
  FOR UPDATE;

  -- 3. Retry guard: if plan is already generated, return current list directly (idempotency success)
  IF v_initial_plan_generated IS NOT NULL THEN
    SELECT json_agg(t) INTO v_tasks_json
    FROM (
      SELECT id, name, status, deadline_intent, date_offset, resolved_deadline_at, task_source, side, assignee_wedding_member_id
      FROM public.tasks
      WHERE wedding_id = p_wedding_id
      ORDER BY created_at ASC
    ) t;

    RETURN jsonb_build_object(
      'initial_plan_generated_at', v_initial_plan_generated,
      'replayed', true,
      'tasks', COALESCE(v_tasks_json, '[]'::jsonb)
    );
  END IF;

  -- 4. Validate Main Event context exists
  SELECT id, exact_date INTO v_main_event_id, v_main_event_exact_date
  FROM public.wedding_events
  WHERE wedding_id = p_wedding_id
    AND is_main_event = true
    AND lifecycle_status = 'ACTIVE'
  LIMIT 1;

  IF v_main_event_id IS NULL THEN
    RAISE EXCEPTION 'MAIN_EVENT_REQUIRED: Wedding must have a main event configured first.'
      USING ERRCODE = '45000';
  END IF;

  -- 5. Generate tasks from static template filtered by cultural context
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
  )
  SELECT 
    p_wedding_id,
    v_main_event_id,
    t.name,
    'TODO',
    t.deadline_intent,
    t.date_offset,
    'SYSTEM_TEMPLATE',
    false,
    t.side
  FROM internal.plan_template_tasks t
  WHERE t.cultural_context = COALESCE(v_cultural_context, 'TUY_CHON');

  -- 6. Set initial_plan_generated_at atomically
  UPDATE public.weddings
  SET initial_plan_generated_at = now()
  WHERE id = p_wedding_id;

  -- 7. Query and return generated task details
  SELECT json_agg(t) INTO v_tasks_json
  FROM (
    SELECT id, name, status, deadline_intent, date_offset, resolved_deadline_at, task_source, side, assignee_wedding_member_id
    FROM public.tasks
    WHERE wedding_id = p_wedding_id
    ORDER BY created_at ASC
  ) t;

  RETURN jsonb_build_object(
    'initial_plan_generated_at', now(),
    'replayed', false,
    'tasks', COALESCE(v_tasks_json, '[]'::jsonb)
  );

END;
$$;

-- Revoke execute from PUBLIC
REVOKE EXECUTE ON FUNCTION api_v1.generate_initial_plan(uuid) FROM PUBLIC;

-- Grant execution permissions
GRANT EXECUTE ON FUNCTION api_v1.generate_initial_plan(uuid) TO authenticated;
-- Grant trusted_function_owner membership/execution context
ALTER FUNCTION api_v1.generate_initial_plan(uuid) OWNER TO trusted_function_owner;

-- ==========================================
-- 6. GRANTS AND POLICIES FOR DATA API
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
GRANT UPDATE (name, expected_year, expected_month, exact_date, start_time, location, map_link) ON public.wedding_events TO authenticated;

GRANT SELECT ON public.tasks TO authenticated;
GRANT INSERT (id, wedding_id, wedding_event_id, assignee_wedding_member_id, name, status, deadline_intent, date_offset, custom_override_date, completed_at, resolved_deadline_at, side) ON public.tasks TO authenticated;
GRANT UPDATE (assignee_wedding_member_id, name, status, deadline_intent, date_offset, custom_override_date, completed_at, resolved_deadline_at, side) ON public.tasks TO authenticated;

-- Grants for trusted execution context role (trusted_function_owner)
GRANT ALL PRIVILEGES ON public.weddings TO trusted_function_owner;
GRANT ALL PRIVILEGES ON public.wedding_events TO trusted_function_owner;
GRANT ALL PRIVILEGES ON public.tasks TO trusted_function_owner;
