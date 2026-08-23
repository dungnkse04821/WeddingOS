-- =============================================================================
-- BATCH-05: M2B.2 Guest Impact Operations
-- =============================================================================

-- Redefine trigger function to check GUC setting before raising exception
CREATE OR REPLACE FUNCTION public.fn_enforce_guest_party_transition()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  -- Allow if GUC trusted_operation is set to 'true'
  IF current_setting('weddingos.trusted_operation', true) = 'true' THEN
    RETURN NEW;
  END IF;

  IF OLD.invitation_party_id IS NOT NULL AND OLD.invitation_party_id IS DISTINCT FROM NEW.invitation_party_id THEN
    RAISE EXCEPTION 'Direct unassignment or transition from an existing invitation party is blocked. Must use trusted operations.'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

-- Grant permissions to trusted_function_owner
GRANT SELECT, INSERT, UPDATE, DELETE ON public.primary_groups TO trusted_function_owner;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.invitation_parties TO trusted_function_owner;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.guests TO trusted_function_owner;

-- ===========================================================================
-- TOP-GUE-001: PRIMARYGROUP DELETE PREVIEW & COMMIT
-- ===========================================================================

CREATE OR REPLACE FUNCTION api_v1.preview_primary_group_delete(p_group_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_group_name         varchar(100);
  v_wedding_id         uuid;
  v_caller_role        varchar(50);
  v_affected_count     integer;
  v_affected_guests    json;
  v_fingerprint        text;
BEGIN
  -- Load group
  SELECT name, wedding_id INTO v_group_name, v_wedding_id FROM public.primary_groups WHERE id = p_group_id;
  IF v_group_name IS NULL THEN
    RAISE EXCEPTION 'Group not found.' USING ERRCODE = '44000';
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

  -- Count affected guests
  SELECT COUNT(*)::integer INTO v_affected_count
  FROM public.guests
  WHERE primary_group_id = p_group_id;

  -- Fetch list of affected guests
  SELECT COALESCE(json_agg(t), '[]'::json) INTO v_affected_guests
  FROM (
    SELECT id, name
    FROM public.guests
    WHERE primary_group_id = p_group_id
    ORDER BY name ASC, id ASC
  ) t;

  -- Calculate fingerprint: MD5(group_delete:<group_id>:<group_name>:<count>:<sorted list of guest ids>)
  SELECT md5('group_delete:' || p_group_id || ':' || v_group_name || ':' || v_affected_count || ':' || COALESCE(string_agg(id::text, ','), ''))
  INTO v_fingerprint
  FROM (
    SELECT id FROM public.guests WHERE primary_group_id = p_group_id ORDER BY id ASC
  ) g;

  RETURN jsonb_build_object(
    'group_id', p_group_id,
    'group_name', v_group_name,
    'affected_guest_count', v_affected_count,
    'affected_guests', v_affected_guests,
    'impact_fingerprint', v_fingerprint
  );
END;
$$;

CREATE OR REPLACE FUNCTION api_v1.commit_primary_group_delete(
  p_group_id uuid,
  p_impact_fingerprint text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_group_name         varchar(100);
  v_wedding_id         uuid;
  v_caller_role        varchar(50);
  v_affected_count     integer;
  v_fingerprint        text;
BEGIN
  -- Load group
  SELECT name, wedding_id INTO v_group_name, v_wedding_id FROM public.primary_groups WHERE id = p_group_id;
  
  -- Retry guard: If group already deleted, return terminal success
  IF v_group_name IS NULL THEN
    RETURN jsonb_build_object(
      'replayed', true,
      'group_id', p_group_id,
      'success', true
    );
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

  -- Lock wedding
  PERFORM id FROM public.weddings WHERE id = v_wedding_id FOR UPDATE;

  -- Recompute fingerprint
  SELECT COUNT(*)::integer INTO v_affected_count
  FROM public.guests
  WHERE primary_group_id = p_group_id;

  SELECT md5('group_delete:' || p_group_id || ':' || v_group_name || ':' || v_affected_count || ':' || COALESCE(string_agg(id::text, ','), ''))
  INTO v_fingerprint
  FROM (
    SELECT id FROM public.guests WHERE primary_group_id = p_group_id ORDER BY id ASC
  ) g;

  IF v_fingerprint IS DISTINCT FROM p_impact_fingerprint THEN
    RAISE EXCEPTION 'STALE_IMPACT: The planning workspace state has changed since the preview was generated.'
      USING ERRCODE = '40001';
  END IF;

  -- Detach guests
  UPDATE public.guests
  SET primary_group_id = NULL,
      updated_at = now()
  WHERE primary_group_id = p_group_id;

  -- Delete primary group
  DELETE FROM public.primary_groups WHERE id = p_group_id;

  RETURN jsonb_build_object(
    'replayed', false,
    'group_id', p_group_id,
    'success', true
  );
END;
$$;

-- ===========================================================================
-- TOP-GUE-002: PARTY MOVE/REMOVE PREVIEW & COMMIT
-- ===========================================================================

CREATE OR REPLACE FUNCTION api_v1.preview_guest_party_move(
  p_guest_id uuid,
  p_target_party_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_guest_name            varchar(255);
  v_wedding_id            uuid;
  v_current_party_id      uuid;
  v_caller_role           varchar(50);
  
  v_source_party_name     varchar(255);
  v_source_invited_count  integer := 0;
  
  v_target_party_name     varchar(255);
  v_target_invited_count  integer := 0;
  
  v_fingerprint           text;
BEGIN
  -- Load guest
  SELECT name, wedding_id, invitation_party_id INTO v_guest_name, v_wedding_id, v_current_party_id
  FROM public.guests WHERE id = p_guest_id;
  
  IF v_guest_name IS NULL THEN
    RAISE EXCEPTION 'Guest not found.' USING ERRCODE = '44000';
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

  -- Load source party if exists
  IF v_current_party_id IS NOT NULL THEN
    SELECT display_name, invited_count INTO v_source_party_name, v_source_invited_count
    FROM public.invitation_parties WHERE id = v_current_party_id AND wedding_id = v_wedding_id;
  END IF;

  -- Load target party if exists
  IF p_target_party_id IS NOT NULL THEN
    SELECT display_name, invited_count INTO v_target_party_name, v_target_invited_count
    FROM public.invitation_parties WHERE id = p_target_party_id AND wedding_id = v_wedding_id;
    IF v_target_party_name IS NULL THEN
      RAISE EXCEPTION 'Target party not found or belongs to a different wedding.'
        USING ERRCODE = '44000';
    END IF;
  END IF;

  -- Calculate fingerprint: MD5(party_move:<guest_id>:<src_party_id>:<src_invited>:<tgt_party_id>:<tgt_invited>)
  v_fingerprint := md5('party_move:' || p_guest_id || ':' || 
                       COALESCE(v_current_party_id::text, 'null') || ':' || 
                       v_source_invited_count || ':' || 
                       COALESCE(p_target_party_id::text, 'null') || ':' || 
                       v_target_invited_count);

  RETURN jsonb_build_object(
    'guest_id', p_guest_id,
    'guest_name', v_guest_name,
    'source_party_id', v_current_party_id,
    'source_party_name', v_source_party_name,
    'source_invited_count', v_source_invited_count,
    'target_party_id', p_target_party_id,
    'target_party_name', v_target_party_name,
    'target_invited_count', v_target_invited_count,
    'impact_fingerprint', v_fingerprint
  );
END;
$$;

CREATE OR REPLACE FUNCTION api_v1.commit_guest_party_move(
  p_guest_id uuid,
  p_target_party_id uuid,
  p_impact_fingerprint text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_guest_name            varchar(255);
  v_wedding_id            uuid;
  v_current_party_id      uuid;
  v_caller_role           varchar(50);
  
  v_source_invited_count  integer := 0;
  v_target_invited_count  integer := 0;
  v_fingerprint           text;
BEGIN
  -- Load guest
  SELECT name, wedding_id, invitation_party_id INTO v_guest_name, v_wedding_id, v_current_party_id
  FROM public.guests WHERE id = p_guest_id;
  
  IF v_guest_name IS NULL THEN
    RAISE EXCEPTION 'Guest not found.' USING ERRCODE = '44000';
  END IF;

  -- Retry guard: if current state already equals target, return terminal success
  IF v_current_party_id IS NOT DISTINCT FROM p_target_party_id THEN
    RETURN jsonb_build_object(
      'replayed', true,
      'guest_id', p_guest_id,
      'invitation_party_id', p_target_party_id,
      'success', true
    );
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

  -- Lock wedding
  PERFORM id FROM public.weddings WHERE id = v_wedding_id FOR UPDATE;

  -- Load source invited count
  IF v_current_party_id IS NOT NULL THEN
    SELECT invited_count INTO v_source_invited_count
    FROM public.invitation_parties WHERE id = v_current_party_id;
  END IF;

  -- Load target invited count
  IF p_target_party_id IS NOT NULL THEN
    SELECT invited_count INTO v_target_invited_count
    FROM public.invitation_parties WHERE id = p_target_party_id AND wedding_id = v_wedding_id;
    IF v_target_invited_count IS NULL THEN
      RAISE EXCEPTION 'Target party not found or belongs to a different wedding.'
        USING ERRCODE = '44000';
    END IF;
  END IF;

  -- Recompute fingerprint
  v_fingerprint := md5('party_move:' || p_guest_id || ':' || 
                       COALESCE(v_current_party_id::text, 'null') || ':' || 
                       v_source_invited_count || ':' || 
                       COALESCE(p_target_party_id::text, 'null') || ':' || 
                       v_target_invited_count);

  IF v_fingerprint IS DISTINCT FROM p_impact_fingerprint THEN
    RAISE EXCEPTION 'STALE_IMPACT: The planning workspace state has changed since the preview was generated.'
      USING ERRCODE = '40001';
  END IF;

  -- Set GUC trusted operation bypass to true local to the transaction
  PERFORM set_config('weddingos.trusted_operation', 'true', true);

  -- Perform the update (no recalculation of invited counts!)
  UPDATE public.guests
  SET invitation_party_id = p_target_party_id,
      updated_at = now()
  WHERE id = p_guest_id;

  RETURN jsonb_build_object(
    'replayed', false,
    'guest_id', p_guest_id,
    'invitation_party_id', p_target_party_id,
    'success', true
  );
END;
$$;

-- ===========================================================================
-- TOP-GUE-003: GUEST DUPLICATE MERGE PREVIEW & COMMIT
-- ===========================================================================

CREATE OR REPLACE FUNCTION api_v1.preview_guest_merge(
  p_guest_id_1 uuid,
  p_guest_id_2 uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_guest_1            public.guests%ROWTYPE;
  v_guest_2            public.guests%ROWTYPE;
  v_caller_role        varchar(50);
  v_fingerprint        text;
  
  v_conflicts          jsonb;
BEGIN
  -- Load guests
  SELECT * INTO v_guest_1 FROM public.guests WHERE id = p_guest_id_1;
  SELECT * INTO v_guest_2 FROM public.guests WHERE id = p_guest_id_2;

  IF v_guest_1.id IS NULL OR v_guest_2.id IS NULL THEN
    RAISE EXCEPTION 'One or both guests not found.' USING ERRCODE = '44000';
  END IF;

  IF v_guest_1.wedding_id <> v_guest_2.wedding_id THEN
    RAISE EXCEPTION 'Guests belong to different weddings.' USING ERRCODE = '42501';
  END IF;

  -- Authenticate & Authorize
  SELECT role INTO v_caller_role
  FROM public.wedding_members
  WHERE wedding_id = v_guest_1.wedding_id
    AND user_id = auth.uid()
    AND status = 'ACTIVE';

  IF v_caller_role IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: Caller is not an active member of this wedding.'
      USING ERRCODE = '42501';
  END IF;

  -- Determine conflicts
  v_conflicts := jsonb_build_object(
    'name', jsonb_build_object(
      'has_conflict', v_guest_1.name IS DISTINCT FROM v_guest_2.name,
      'candidates', jsonb_build_array(v_guest_1.name, v_guest_2.name)
    ),
    'phone', jsonb_build_object(
      'has_conflict', v_guest_1.phone IS DISTINCT FROM v_guest_2.phone,
      'candidates', jsonb_build_array(v_guest_1.phone, v_guest_2.phone)
    ),
    'email', jsonb_build_object(
      'has_conflict', v_guest_1.email IS DISTINCT FROM v_guest_2.email,
      'candidates', jsonb_build_array(v_guest_1.email, v_guest_2.email)
    ),
    'side', jsonb_build_object(
      'has_conflict', v_guest_1.side IS DISTINCT FROM v_guest_2.side,
      'candidates', jsonb_build_array(v_guest_1.side, v_guest_2.side)
    ),
    'guest_source', jsonb_build_object(
      'has_conflict', v_guest_1.guest_source IS DISTINCT FROM v_guest_2.guest_source,
      'candidates', jsonb_build_array(v_guest_1.guest_source, v_guest_2.guest_source)
    ),
    'primary_group_id', jsonb_build_object(
      'has_conflict', v_guest_1.primary_group_id IS DISTINCT FROM v_guest_2.primary_group_id,
      'candidates', jsonb_build_array(v_guest_1.primary_group_id, v_guest_2.primary_group_id)
    ),
    'invitation_party_id', jsonb_build_object(
      'has_conflict', v_guest_1.invitation_party_id IS DISTINCT FROM v_guest_2.invitation_party_id,
      'candidates', jsonb_build_array(v_guest_1.invitation_party_id, v_guest_2.invitation_party_id)
    )
  );

  -- Calculate fingerprint: MD5(guest_merge:<g1_state>:<g2_state>)
  v_fingerprint := md5('guest_merge:' || 
                       v_guest_1.id || ':' || v_guest_1.name || ':' || COALESCE(v_guest_1.phone, '') || ':' || COALESCE(v_guest_1.email, '') || ':' || v_guest_1.side || ':' || v_guest_1.guest_source || ':' || COALESCE(v_guest_1.primary_group_id::text, '') || ':' || COALESCE(v_guest_1.invitation_party_id::text, '') || ':' ||
                       v_guest_2.id || ':' || v_guest_2.name || ':' || COALESCE(v_guest_2.phone, '') || ':' || COALESCE(v_guest_2.email, '') || ':' || v_guest_2.side || ':' || v_guest_2.guest_source || ':' || COALESCE(v_guest_2.primary_group_id::text, '') || ':' || COALESCE(v_guest_2.invitation_party_id::text, ''));

  RETURN jsonb_build_object(
    'guest_1', jsonb_build_object(
      'id', v_guest_1.id,
      'name', v_guest_1.name,
      'phone', v_guest_1.phone,
      'email', v_guest_1.email,
      'side', v_guest_1.side,
      'guest_source', v_guest_1.guest_source,
      'primary_group_id', v_guest_1.primary_group_id,
      'invitation_party_id', v_guest_1.invitation_party_id
    ),
    'guest_2', jsonb_build_object(
      'id', v_guest_2.id,
      'name', v_guest_2.name,
      'phone', v_guest_2.phone,
      'email', v_guest_2.email,
      'side', v_guest_2.side,
      'guest_source', v_guest_2.guest_source,
      'primary_group_id', v_guest_2.primary_group_id,
      'invitation_party_id', v_guest_2.invitation_party_id
    ),
    'conflicts', v_conflicts,
    'impact_fingerprint', v_fingerprint
  );
END;
$$;

CREATE OR REPLACE FUNCTION api_v1.commit_guest_merge(
  p_survivor_guest_id uuid,
  p_secondary_guest_id uuid,
  p_resolved_name varchar,
  p_resolved_phone varchar,
  p_resolved_email varchar,
  p_resolved_side varchar,
  p_resolved_guest_source varchar,
  p_resolved_primary_group_id uuid,
  p_resolved_invitation_party_id uuid,
  p_impact_fingerprint text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_survivor           public.guests%ROWTYPE;
  v_secondary          public.guests%ROWTYPE;
  v_caller_role        varchar(50);
  v_fingerprint        text;
BEGIN
  -- Load survivor
  SELECT * INTO v_survivor FROM public.guests WHERE id = p_survivor_guest_id;
  
  -- Load secondary
  SELECT * INTO v_secondary FROM public.guests WHERE id = p_secondary_guest_id;

  -- Retry/Replay Check:
  -- "If secondary guest is already deleted, compare survivor's current values with resolutions.
  --  Replays success if all match; returns STALE_STATE or CONFLICT otherwise."
  IF v_survivor.id IS NOT NULL AND v_secondary.id IS NULL THEN
    IF v_survivor.name IS NOT DISTINCT FROM p_resolved_name AND
       v_survivor.phone IS NOT DISTINCT FROM p_resolved_phone AND
       v_survivor.email IS NOT DISTINCT FROM p_resolved_email AND
       v_survivor.side IS NOT DISTINCT FROM p_resolved_side AND
       v_survivor.guest_source IS NOT DISTINCT FROM p_resolved_guest_source AND
       v_survivor.primary_group_id IS NOT DISTINCT FROM p_resolved_primary_group_id AND
       v_survivor.invitation_party_id IS NOT DISTINCT FROM p_resolved_invitation_party_id THEN
       
       RETURN jsonb_build_object(
         'replayed', true,
         'survivor_guest_id', p_survivor_guest_id,
         'success', true
       );
    ELSE
       RAISE EXCEPTION 'CONFLICT: The survivor guest attributes do not match the expected resolved merge values.'
         USING ERRCODE = '40009';
    END IF;
  END IF;

  -- Regular Checks
  IF v_survivor.id IS NULL OR v_secondary.id IS NULL THEN
    RAISE EXCEPTION 'One or both guests not found.' USING ERRCODE = '44000';
  END IF;

  IF v_survivor.wedding_id <> v_secondary.wedding_id THEN
    RAISE EXCEPTION 'Guests belong to different weddings.' USING ERRCODE = '42501';
  END IF;

  -- Authenticate & Authorize
  SELECT role INTO v_caller_role
  FROM public.wedding_members
  WHERE wedding_id = v_survivor.wedding_id
    AND user_id = auth.uid()
    AND status = 'ACTIVE';

  IF v_caller_role IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: Caller is not an active member of this wedding.'
      USING ERRCODE = '42501';
  END IF;

  -- Validate resolved values match candidates
  IF p_resolved_name NOT IN (v_survivor.name, v_secondary.name) THEN
    RAISE EXCEPTION 'Invalid resolution candidate for name.' USING ERRCODE = '23514';
  END IF;

  IF (p_resolved_phone IS DISTINCT FROM v_survivor.phone AND p_resolved_phone IS DISTINCT FROM v_secondary.phone) THEN
    RAISE EXCEPTION 'Invalid resolution candidate for phone.' USING ERRCODE = '23514';
  END IF;

  IF (p_resolved_email IS DISTINCT FROM v_survivor.email AND p_resolved_email IS DISTINCT FROM v_secondary.email) THEN
    RAISE EXCEPTION 'Invalid resolution candidate for email.' USING ERRCODE = '23514';
  END IF;

  IF p_resolved_side NOT IN (v_survivor.side, v_secondary.side) THEN
    RAISE EXCEPTION 'Invalid resolution candidate for side.' USING ERRCODE = '23514';
  END IF;

  IF p_resolved_guest_source NOT IN (v_survivor.guest_source, v_secondary.guest_source) THEN
    RAISE EXCEPTION 'Invalid resolution candidate for guest_source.' USING ERRCODE = '23514';
  END IF;

  IF (p_resolved_primary_group_id IS DISTINCT FROM v_survivor.primary_group_id AND p_resolved_primary_group_id IS DISTINCT FROM v_secondary.primary_group_id) THEN
    RAISE EXCEPTION 'Invalid resolution candidate for primary_group_id.' USING ERRCODE = '23514';
  END IF;

  IF (p_resolved_invitation_party_id IS DISTINCT FROM v_survivor.invitation_party_id AND p_resolved_invitation_party_id IS DISTINCT FROM v_secondary.invitation_party_id) THEN
    RAISE EXCEPTION 'Invalid resolution candidate for invitation_party_id.' USING ERRCODE = '23514';
  END IF;

  -- Lock wedding
  PERFORM id FROM public.weddings WHERE id = v_survivor.wedding_id FOR UPDATE;

  -- Recompute fingerprint
  v_fingerprint := md5('guest_merge:' || 
                       v_survivor.id || ':' || v_survivor.name || ':' || COALESCE(v_survivor.phone, '') || ':' || COALESCE(v_survivor.email, '') || ':' || v_survivor.side || ':' || v_survivor.guest_source || ':' || COALESCE(v_survivor.primary_group_id::text, '') || ':' || COALESCE(v_survivor.invitation_party_id::text, '') || ':' ||
                       v_secondary.id || ':' || v_secondary.name || ':' || COALESCE(v_secondary.phone, '') || ':' || COALESCE(v_secondary.email, '') || ':' || v_secondary.side || ':' || v_secondary.guest_source || ':' || COALESCE(v_secondary.primary_group_id::text, '') || ':' || COALESCE(v_secondary.invitation_party_id::text, ''));

  IF v_fingerprint IS DISTINCT FROM p_impact_fingerprint THEN
    RAISE EXCEPTION 'STALE_IMPACT: The planning workspace state has changed since the preview was generated.'
      USING ERRCODE = '40001';
  END IF;

  -- Set GUC trusted operation bypass to true local to the transaction
  PERFORM set_config('weddingos.trusted_operation', 'true', true);

  -- Update survivor guest with resolved values
  UPDATE public.guests
  SET name = p_resolved_name,
      phone = p_resolved_phone,
      email = p_resolved_email,
      side = p_resolved_side,
      guest_source = p_resolved_guest_source,
      primary_group_id = p_resolved_primary_group_id,
      invitation_party_id = p_resolved_invitation_party_id,
      updated_at = now()
  WHERE id = p_survivor_guest_id;

  -- Physically delete secondary guest
  DELETE FROM public.guests WHERE id = p_secondary_guest_id;

  RETURN jsonb_build_object(
    'replayed', false,
    'survivor_guest_id', p_survivor_guest_id,
    'success', true
  );
END;
$$;

-- Configure Security Definer functions and ownership

REVOKE EXECUTE ON FUNCTION api_v1.preview_primary_group_delete(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION api_v1.commit_primary_group_delete(uuid, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION api_v1.preview_guest_party_move(uuid, uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION api_v1.commit_guest_party_move(uuid, uuid, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION api_v1.preview_guest_merge(uuid, uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION api_v1.commit_guest_merge(uuid, uuid, varchar, varchar, varchar, varchar, varchar, uuid, uuid, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION api_v1.preview_primary_group_delete(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION api_v1.commit_primary_group_delete(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION api_v1.preview_guest_party_move(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION api_v1.commit_guest_party_move(uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION api_v1.preview_guest_merge(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION api_v1.commit_guest_merge(uuid, uuid, varchar, varchar, varchar, varchar, varchar, uuid, uuid, text) TO authenticated;

ALTER FUNCTION api_v1.preview_primary_group_delete(uuid) OWNER TO trusted_function_owner;
ALTER FUNCTION api_v1.commit_primary_group_delete(uuid, text) OWNER TO trusted_function_owner;
ALTER FUNCTION api_v1.preview_guest_party_move(uuid, uuid) OWNER TO trusted_function_owner;
ALTER FUNCTION api_v1.commit_guest_party_move(uuid, uuid, text) OWNER TO trusted_function_owner;
ALTER FUNCTION api_v1.preview_guest_merge(uuid, uuid) OWNER TO trusted_function_owner;
ALTER FUNCTION api_v1.commit_guest_merge(uuid, uuid, varchar, varchar, varchar, varchar, varchar, uuid, uuid, text) OWNER TO trusted_function_owner;
