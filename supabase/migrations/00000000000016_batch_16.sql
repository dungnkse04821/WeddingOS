-- =============================================================================
-- BATCH-16: M8.1B Wedding create concurrency and DELETING read matrix
-- =============================================================================

-- Normal organizer graph reads are available only while the Wedding is ACTIVE
-- or ARCHIVED. Membership status remains independently enforced.
CREATE OR REPLACE FUNCTION security.is_active_wedding_member(wedding_id_param uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.wedding_members m
    JOIN public.weddings w ON w.id = m.wedding_id
    WHERE m.wedding_id = wedding_id_param
      AND m.user_id = auth.uid()
      AND m.status = 'ACTIVE'
      AND w.status IN ('ACTIVE', 'ARCHIVED')
  );
END;
$$;
ALTER FUNCTION security.is_active_wedding_member(uuid)
  OWNER TO trusted_function_owner;

CREATE OR REPLACE FUNCTION security.is_wedding_owner(wedding_id_param uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.wedding_members m
    JOIN public.weddings w ON w.id = m.wedding_id
    WHERE m.wedding_id = wedding_id_param
      AND m.user_id = auth.uid()
      AND m.role = 'OWNER'
      AND m.status = 'ACTIVE'
      AND w.status IN ('ACTIVE', 'ARCHIVED')
  );
END;
$$;
ALTER FUNCTION security.is_wedding_owner(uuid)
  OWNER TO trusted_function_owner;

CREATE OR REPLACE FUNCTION security.can_owner_recover_deleting_wedding(wedding_id_param uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.wedding_members m
    JOIN public.weddings w ON w.id = m.wedding_id
    WHERE m.wedding_id = wedding_id_param
      AND m.user_id = auth.uid()
      AND m.role = 'OWNER'
      AND m.status = 'ACTIVE'
      AND w.status = 'DELETING'
  );
END;
$$;

ALTER FUNCTION security.can_owner_recover_deleting_wedding(uuid)
  OWNER TO trusted_function_owner;
REVOKE EXECUTE ON FUNCTION security.can_owner_recover_deleting_wedding(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION security.can_owner_recover_deleting_wedding(uuid) TO authenticated;

DROP POLICY select_wedding_if_member ON public.weddings;
CREATE POLICY select_wedding_if_member
  ON public.weddings FOR SELECT TO authenticated
  USING (
    security.is_active_wedding_member(id)
    OR security.can_owner_recover_deleting_wedding(id)
  );

DROP POLICY select_members_if_same_wedding ON public.wedding_members;
CREATE POLICY select_members_if_same_wedding
  ON public.wedding_members FOR SELECT TO authenticated
  USING (
    security.is_active_wedding_member(wedding_id)
    OR (
      user_id = auth.uid()
      AND security.can_owner_recover_deleting_wedding(wedding_id)
    )
  );

-- TOP-WED-001 retains auth.uid() actor authority and live-state replay. The
-- transaction lock serializes one receipt identity before the receipt lookup,
-- so a concurrent caller observes the committed receipt instead of creating a
-- second Wedding and losing an ignored receipt insert conflict.
CREATE OR REPLACE FUNCTION api_v1.create_wedding(
  p_request_id       uuid,
  p_name             varchar(255),
  p_cultural_context varchar(50)   DEFAULT 'TUY_CHON',
  p_exact_date       date          DEFAULT NULL,
  p_expected_year    integer       DEFAULT NULL,
  p_expected_month   integer       DEFAULT NULL,
  p_timezone         varchar(50)   DEFAULT 'Asia/Ho_Chi_Minh',
  p_target_budget    numeric(15,2) DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id         uuid;
  v_actor_email      text;
  v_actor_name       text;
  v_request_hash     varchar(64);
  v_existing_receipt private.trusted_operation_receipts%ROWTYPE;
  v_wedding_id       uuid;
  v_wedding          public.weddings%ROWTYPE;
  v_member           public.wedding_members%ROWTYPE;
  v_canonical        text;
BEGIN
  v_actor_id := auth.uid();
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'UNAUTHORIZED: caller is not authenticated' USING ERRCODE = 'P0001';
  END IF;

  SELECT
    COALESCE(raw_user_meta_data->>'full_name',
             raw_user_meta_data->>'name',
             email, v_actor_id::text),
    COALESCE(email, '')
  INTO v_actor_name, v_actor_email
  FROM auth.users
  WHERE id = v_actor_id;

  v_canonical := json_build_object(
    'cultural_context', COALESCE(p_cultural_context, 'TUY_CHON'),
    'exact_date',       p_exact_date::text,
    'expected_month',   p_expected_month::text,
    'expected_year',    p_expected_year::text,
    'name',             p_name,
    'target_budget',    CASE WHEN p_target_budget IS NOT NULL
                             THEN to_char(p_target_budget, 'FM9999999999999.00')
                             ELSE NULL END,
    'timezone',         COALESCE(p_timezone, 'Asia/Ho_Chi_Minh')
  )::text;
  v_request_hash := encode(extensions.digest(v_canonical, 'sha256'), 'hex');

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'TOP-WED-001:' || v_actor_id::text || ':' || p_request_id::text,
      0
    )
  );

  SELECT * INTO v_existing_receipt
  FROM private.trusted_operation_receipts
  WHERE operation_type = 'TOP-WED-001'
    AND actor_user_id = v_actor_id
    AND request_id = p_request_id;

  IF FOUND AND v_existing_receipt.result_resource_id IS NOT NULL THEN
    IF v_existing_receipt.request_hash <> v_request_hash THEN
      RAISE EXCEPTION 'REQUEST_ID_REUSED: request_id has already been used for a different request'
        USING ERRCODE = '40900';
    END IF;

    SELECT * INTO v_wedding
    FROM public.weddings
    WHERE id = v_existing_receipt.result_resource_id;
    SELECT * INTO v_member
    FROM public.wedding_members
    WHERE wedding_id = v_wedding.id
      AND user_id = v_actor_id;

    RETURN jsonb_build_object(
      'replayed', true,
      'wedding', row_to_json(v_wedding),
      'membership', row_to_json(v_member)
    );
  END IF;

  IF p_name IS NULL OR trim(p_name) = '' THEN
    RAISE EXCEPTION 'INVALID_INPUT: name is required' USING ERRCODE = 'P0002';
  END IF;
  IF p_exact_date IS NOT NULL THEN
    IF p_expected_year IS NOT NULL OR p_expected_month IS NOT NULL THEN
      RAISE EXCEPTION 'INVALID_INPUT: exact_date cannot be combined with expected_year/month'
        USING ERRCODE = 'P0002';
    END IF;
  ELSE
    IF p_expected_year IS NULL OR p_expected_month IS NULL THEN
      RAISE EXCEPTION 'INVALID_INPUT: expected_year and expected_month required when exact_date absent'
        USING ERRCODE = 'P0002';
    END IF;
    IF p_expected_month < 1 OR p_expected_month > 12 THEN
      RAISE EXCEPTION 'INVALID_INPUT: expected_month must be 1-12' USING ERRCODE = 'P0002';
    END IF;
  END IF;
  IF p_target_budget IS NOT NULL AND p_target_budget <= 0 THEN
    RAISE EXCEPTION 'INVALID_INPUT: target_budget must be positive' USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO public.weddings (
    name, cultural_context, exact_date, expected_year, expected_month,
    timezone, target_budget, status
  ) VALUES (
    trim(p_name),
    COALESCE(p_cultural_context, 'TUY_CHON'),
    p_exact_date, p_expected_year, p_expected_month,
    COALESCE(p_timezone, 'Asia/Ho_Chi_Minh'),
    p_target_budget, 'ACTIVE'
  ) RETURNING id INTO v_wedding_id;

  INSERT INTO public.wedding_members (
    wedding_id, user_id, display_name, profile_email, role, status
  ) VALUES (
    v_wedding_id, v_actor_id,
    v_actor_name, v_actor_email,
    'OWNER', 'ACTIVE'
  );

  INSERT INTO private.trusted_operation_receipts (
    operation_type, actor_user_id, request_id, wedding_id,
    request_hash, result_resource_id, result_summary
  ) VALUES (
    'TOP-WED-001', v_actor_id, p_request_id, v_wedding_id,
    v_request_hash, v_wedding_id,
    jsonb_build_object('wedding_id', v_wedding_id, 'status', 'ACTIVE')
  );

  SELECT * INTO v_wedding
  FROM public.weddings
  WHERE id = v_wedding_id;
  SELECT * INTO v_member
  FROM public.wedding_members
  WHERE wedding_id = v_wedding_id
    AND user_id = v_actor_id;

  RETURN jsonb_build_object(
    'replayed', false,
    'wedding', row_to_json(v_wedding),
    'membership', row_to_json(v_member)
  );
END;
$$;
