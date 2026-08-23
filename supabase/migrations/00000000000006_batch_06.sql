-- =============================================================================
-- BATCH-06: M2B.3 Excel Guest Import
-- =============================================================================

-- TOP-GUE-004: Confirm Excel Import.
--
-- The client parses .xlsx locally and sends only normalized structured rows.
-- This trusted operation revalidates all material facts server-side, applies the
-- import atomically, and stores a minimized durable receipt for safe retry.

CREATE OR REPLACE FUNCTION api_v1.confirm_guest_import(
  p_request_id uuid,
  p_wedding_id uuid,
  p_rows jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid;
  v_caller_role varchar(50);
  v_request_hash varchar(64);
  v_existing_receipt private.trusted_operation_receipts%ROWTYPE;
  v_canonical_rows jsonb;
  v_canonical text;

  v_row jsonb;
  v_ord bigint;
  v_name text;
  v_phone text;
  v_email text;
  v_norm_phone text;
  v_norm_email text;
  v_side text;
  v_group_name text;
  v_party_key text;
  v_party_display_name text;
  v_invited_count integer;
  v_guest_source text;

  v_party_facts jsonb := '{}'::jsonb;
  v_party_fact jsonb;
  v_group_ids jsonb := '{}'::jsonb;
  v_party_ids jsonb := '{}'::jsonb;
  v_primary_group_id uuid;
  v_invitation_party_id uuid;

  v_guest_count integer := 0;
  v_group_count integer := 0;
  v_party_count integer := 0;
  v_warning_count integer := 0;
  v_duplicate_phone_count integer := 0;
  v_duplicate_email_count integer := 0;
  v_duplicate_name_count integer := 0;
  v_result jsonb;
BEGIN
  v_actor_id := auth.uid();
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'UNAUTHORIZED: caller is not authenticated'
      USING ERRCODE = '42501';
  END IF;

  SELECT m.role INTO v_caller_role
  FROM public.wedding_members m
  JOIN public.weddings w ON w.id = m.wedding_id
  WHERE m.wedding_id = p_wedding_id
    AND m.user_id = v_actor_id
    AND m.status = 'ACTIVE'
    AND m.role IN ('OWNER', 'COLLABORATOR')
    AND w.status = 'ACTIVE';

  IF v_caller_role IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: Caller is not an active member allowed to import guests for this wedding.'
      USING ERRCODE = '42501';
  END IF;

  IF p_rows IS NULL OR jsonb_typeof(p_rows) <> 'array' THEN
    RAISE EXCEPTION 'INVALID_IMPORT: rows must be a JSON array.'
      USING ERRCODE = 'P0002';
  END IF;

  IF jsonb_array_length(p_rows) = 0 THEN
    RAISE EXCEPTION 'INVALID_IMPORT: at least one guest row is required.'
      USING ERRCODE = 'P0002';
  END IF;

  IF jsonb_array_length(p_rows) > 300 THEN
    RAISE EXCEPTION 'INVALID_IMPORT: at most 300 rows are supported in MVP import.'
      USING ERRCODE = 'P0002';
  END IF;

  SELECT jsonb_agg(
    jsonb_build_object(
      'ordinal', ord,
      'guest_name', nullif(btrim(row_value->>'guest_name'), ''),
      'phone', nullif(btrim(row_value->>'phone'), ''),
      'email', nullif(lower(btrim(row_value->>'email')), ''),
      'side', nullif(upper(btrim(row_value->>'side')), ''),
      'primary_group_name', nullif(btrim(row_value->>'primary_group_name'), ''),
      'party_key', nullif(btrim(row_value->>'party_key'), ''),
      'party_display_name', nullif(btrim(row_value->>'party_display_name'), ''),
      'invited_count', CASE
        WHEN nullif(btrim(row_value->>'invited_count'), '') IS NULL THEN NULL
        ELSE btrim(row_value->>'invited_count')
      END,
      'guest_source', nullif(upper(btrim(row_value->>'guest_source')), '')
    )
    ORDER BY ord
  )
  INTO v_canonical_rows
  FROM jsonb_array_elements(p_rows) WITH ORDINALITY AS input_rows(row_value, ord);

  v_canonical := jsonb_build_object(
    'operation', 'TOP-GUE-004',
    'wedding_id', p_wedding_id,
    'rows', v_canonical_rows
  )::text;
  v_request_hash := encode(extensions.digest(v_canonical, 'sha256'), 'hex');

  SELECT * INTO v_existing_receipt
  FROM private.trusted_operation_receipts
  WHERE operation_type = 'TOP-GUE-004'
    AND actor_user_id = v_actor_id
    AND request_id = p_request_id;

  IF FOUND AND v_existing_receipt.result_resource_id IS NOT NULL THEN
    IF v_existing_receipt.request_hash <> v_request_hash THEN
      RAISE EXCEPTION 'REQUEST_ID_REUSED: request_id has already been used for a different import payload.'
        USING ERRCODE = '40900';
    END IF;

    RETURN jsonb_build_object(
      'replayed', true,
      'success', true,
      'wedding_id', v_existing_receipt.result_resource_id,
      'summary', v_existing_receipt.result_summary
    );
  END IF;

  -- Lock the Wedding so import business rows and receipt converge atomically.
  PERFORM id FROM public.weddings WHERE id = p_wedding_id AND status = 'ACTIVE' FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Wedding not found or not active.'
      USING ERRCODE = '44000';
  END IF;

  -- Server-authoritative row validation and party-fact consistency.
  FOR v_row, v_ord IN
    SELECT row_value, ord FROM jsonb_array_elements(p_rows) WITH ORDINALITY AS input_rows(row_value, ord)
  LOOP
    v_name := nullif(btrim(v_row->>'guest_name'), '');
    v_phone := nullif(btrim(v_row->>'phone'), '');
    v_email := nullif(lower(btrim(v_row->>'email')), '');
    v_side := COALESCE(nullif(upper(btrim(v_row->>'side')), ''), 'COMMON');
    v_group_name := nullif(btrim(v_row->>'primary_group_name'), '');
    v_party_key := nullif(btrim(v_row->>'party_key'), '');
    v_party_display_name := nullif(btrim(v_row->>'party_display_name'), '');
    v_guest_source := COALESCE(nullif(upper(btrim(v_row->>'guest_source')), ''), 'OTHER');

    IF v_name IS NULL THEN
      RAISE EXCEPTION 'INVALID_IMPORT_ROW: row % guest name is required.', v_ord
        USING ERRCODE = 'P0002';
    END IF;
    IF char_length(v_name) > 50 THEN
      RAISE EXCEPTION 'INVALID_IMPORT_ROW: row % guest name exceeds 50 characters.', v_ord
        USING ERRCODE = 'P0002';
    END IF;
    IF v_side NOT IN ('COMMON', 'BRIDE_SIDE', 'GROOM_SIDE') THEN
      RAISE EXCEPTION 'INVALID_IMPORT_ROW: row % side is invalid.', v_ord
        USING ERRCODE = 'P0002';
    END IF;
    IF v_guest_source NOT IN ('BRIDE', 'GROOM', 'BRIDE_PARENTS', 'GROOM_PARENTS', 'OTHER') THEN
      RAISE EXCEPTION 'INVALID_IMPORT_ROW: row % guest source is invalid or unmapped.', v_ord
        USING ERRCODE = 'P0002';
    END IF;
    IF v_email IS NOT NULL AND v_email !~* '^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$' THEN
      RAISE EXCEPTION 'INVALID_IMPORT_ROW: row % email is invalid.', v_ord
        USING ERRCODE = 'P0002';
    END IF;
    IF v_phone IS NOT NULL THEN
      v_norm_phone := regexp_replace(v_phone, '\D', '', 'g');
      IF v_norm_phone LIKE '84%' THEN
        v_norm_phone := '0' || substr(v_norm_phone, 3);
      END IF;
      IF char_length(v_norm_phone) < 9 OR char_length(v_norm_phone) > 11 THEN
        RAISE EXCEPTION 'INVALID_IMPORT_ROW: row % phone is invalid.', v_ord
          USING ERRCODE = 'P0002';
      END IF;
    END IF;
    IF v_group_name IS NOT NULL AND char_length(v_group_name) > 100 THEN
      RAISE EXCEPTION 'INVALID_IMPORT_ROW: row % primary group exceeds 100 characters.', v_ord
        USING ERRCODE = 'P0002';
    END IF;

    v_invited_count := NULL;
    IF nullif(btrim(v_row->>'invited_count'), '') IS NOT NULL THEN
      IF btrim(v_row->>'invited_count') !~ '^[0-9]+$' THEN
        RAISE EXCEPTION 'INVALID_IMPORT_ROW: row % invited count must be a positive integer.', v_ord
          USING ERRCODE = 'P0002';
      END IF;
      v_invited_count := (btrim(v_row->>'invited_count'))::integer;
      IF v_invited_count <= 0 THEN
        RAISE EXCEPTION 'INVALID_IMPORT_ROW: row % invited count must be greater than zero.', v_ord
          USING ERRCODE = 'P0002';
      END IF;
    END IF;

    IF v_party_key IS NULL THEN
      IF v_party_display_name IS NOT NULL OR v_invited_count IS NOT NULL THEN
        RAISE EXCEPTION 'INVALID_IMPORT_ROW: row % party facts require Party Key.', v_ord
          USING ERRCODE = 'P0002';
      END IF;
    ELSE
      IF v_party_display_name IS NULL THEN
        RAISE EXCEPTION 'INVALID_IMPORT_ROW: row % party display name is required for Party Key.', v_ord
          USING ERRCODE = 'P0002';
      END IF;
      IF char_length(v_party_display_name) > 100 THEN
        RAISE EXCEPTION 'INVALID_IMPORT_ROW: row % party display name exceeds 100 characters.', v_ord
          USING ERRCODE = 'P0002';
      END IF;
      IF v_invited_count IS NULL THEN
        RAISE EXCEPTION 'INVALID_IMPORT_ROW: row % invited count is required for Party Key.', v_ord
          USING ERRCODE = 'P0002';
      END IF;

      v_party_fact := v_party_facts -> v_party_key;
      IF v_party_fact IS NULL THEN
        v_party_facts := jsonb_set(
          v_party_facts,
          ARRAY[v_party_key],
          jsonb_build_object('display_name', v_party_display_name, 'invited_count', v_invited_count),
          true
        );
      ELSIF (v_party_fact->>'display_name') IS DISTINCT FROM v_party_display_name
         OR (v_party_fact->>'invited_count')::integer IS DISTINCT FROM v_invited_count THEN
        RAISE EXCEPTION 'INVALID_IMPORT_ROW: Party Key % has inconsistent party facts.', v_party_key
          USING ERRCODE = 'P0002';
      END IF;
    END IF;
  END LOOP;

  -- Duplicate warnings are authoritative but non-blocking.
  WITH normalized_import AS (
    SELECT
      ord,
      nullif(btrim(row_value->>'guest_name'), '') AS guest_name,
      CASE
        WHEN nullif(btrim(row_value->>'phone'), '') IS NULL THEN NULL
        WHEN regexp_replace(btrim(row_value->>'phone'), '\D', '', 'g') LIKE '84%'
          THEN '0' || substr(regexp_replace(btrim(row_value->>'phone'), '\D', '', 'g'), 3)
        ELSE regexp_replace(btrim(row_value->>'phone'), '\D', '', 'g')
      END AS normalized_phone,
      nullif(lower(btrim(row_value->>'email')), '') AS normalized_email,
      lower(nullif(btrim(row_value->>'guest_name'), '')) AS normalized_name
    FROM jsonb_array_elements(p_rows) WITH ORDINALITY AS input_rows(row_value, ord)
  )
  SELECT
    count(*) FILTER (
      WHERE normalized_phone IS NOT NULL AND (
        EXISTS (
          SELECT 1 FROM public.guests g
          WHERE g.wedding_id = p_wedding_id AND g.normalized_phone = normalized_import.normalized_phone
        )
        OR EXISTS (
          SELECT 1 FROM normalized_import other_row
          WHERE other_row.ord <> normalized_import.ord
            AND other_row.normalized_phone = normalized_import.normalized_phone
        )
      )
    )::integer,
    count(*) FILTER (
      WHERE normalized_email IS NOT NULL AND (
        EXISTS (
          SELECT 1 FROM public.guests g
          WHERE g.wedding_id = p_wedding_id AND g.normalized_email = normalized_import.normalized_email
        )
        OR EXISTS (
          SELECT 1 FROM normalized_import other_row
          WHERE other_row.ord <> normalized_import.ord
            AND other_row.normalized_email = normalized_import.normalized_email
        )
      )
    )::integer,
    count(*) FILTER (
      WHERE normalized_name IS NOT NULL AND (
        EXISTS (
          SELECT 1 FROM public.guests g
          WHERE g.wedding_id = p_wedding_id AND lower(g.name) = normalized_import.normalized_name
        )
        OR EXISTS (
          SELECT 1 FROM normalized_import other_row
          WHERE other_row.ord <> normalized_import.ord
            AND other_row.normalized_name = normalized_import.normalized_name
        )
      )
    )::integer
  INTO v_duplicate_phone_count, v_duplicate_email_count, v_duplicate_name_count
  FROM normalized_import;
  v_warning_count := v_duplicate_phone_count + v_duplicate_email_count + v_duplicate_name_count;

  -- Create missing PrimaryGroups once per exact, same-Wedding group name.
  FOR v_group_name IN
    SELECT DISTINCT nullif(btrim(row_value->>'primary_group_name'), '')
    FROM jsonb_array_elements(p_rows) AS input_rows(row_value)
    WHERE nullif(btrim(row_value->>'primary_group_name'), '') IS NOT NULL
    ORDER BY 1
  LOOP
    SELECT id INTO v_primary_group_id
    FROM public.primary_groups
    WHERE wedding_id = p_wedding_id
      AND lower(name) = lower(v_group_name)
    ORDER BY created_at ASC, id ASC
    LIMIT 1;

    IF v_primary_group_id IS NULL THEN
      INSERT INTO public.primary_groups (wedding_id, name)
      VALUES (p_wedding_id, v_group_name)
      RETURNING id INTO v_primary_group_id;
      v_group_count := v_group_count + 1;
    END IF;

    v_group_ids := jsonb_set(v_group_ids, ARRAY[v_group_name], to_jsonb(v_primary_group_id::text), true);
  END LOOP;

  -- Create a new InvitationParty once per import-local Party Key. Existing
  -- parties are never matched by display name alone.
  FOR v_party_key, v_party_fact IN
    SELECT key, value FROM jsonb_each(v_party_facts) ORDER BY key
  LOOP
    INSERT INTO public.invitation_parties (wedding_id, display_name, invited_count)
    VALUES (
      p_wedding_id,
      v_party_fact->>'display_name',
      (v_party_fact->>'invited_count')::integer
    )
    RETURNING id INTO v_invitation_party_id;

    v_party_ids := jsonb_set(v_party_ids, ARRAY[v_party_key], to_jsonb(v_invitation_party_id::text), true);
    v_party_count := v_party_count + 1;
  END LOOP;

  -- Insert Guests. Normalized phone/email columns are intentionally omitted;
  -- the database trigger remains the canonical normalization authority.
  FOR v_row, v_ord IN
    SELECT row_value, ord FROM jsonb_array_elements(p_rows) WITH ORDINALITY AS input_rows(row_value, ord)
  LOOP
    v_name := nullif(btrim(v_row->>'guest_name'), '');
    v_phone := nullif(btrim(v_row->>'phone'), '');
    v_email := nullif(lower(btrim(v_row->>'email')), '');
    v_side := COALESCE(nullif(upper(btrim(v_row->>'side')), ''), 'COMMON');
    v_group_name := nullif(btrim(v_row->>'primary_group_name'), '');
    v_party_key := nullif(btrim(v_row->>'party_key'), '');
    v_guest_source := COALESCE(nullif(upper(btrim(v_row->>'guest_source')), ''), 'OTHER');

    v_primary_group_id := NULL;
    IF v_group_name IS NOT NULL THEN
      v_primary_group_id := (v_group_ids ->> v_group_name)::uuid;
    END IF;

    v_invitation_party_id := NULL;
    IF v_party_key IS NOT NULL THEN
      v_invitation_party_id := (v_party_ids ->> v_party_key)::uuid;
    END IF;

    INSERT INTO public.guests (
      wedding_id,
      invitation_party_id,
      primary_group_id,
      name,
      phone,
      email,
      side,
      guest_source
    )
    VALUES (
      p_wedding_id,
      v_invitation_party_id,
      v_primary_group_id,
      v_name,
      v_phone,
      v_email,
      v_side,
      v_guest_source
    );

    v_guest_count := v_guest_count + 1;
  END LOOP;

  v_result := jsonb_build_object(
    'guest_count', v_guest_count,
    'new_group_count', v_group_count,
    'new_party_count', v_party_count,
    'warning_count', v_warning_count,
    'duplicate_phone_warnings', v_duplicate_phone_count,
    'duplicate_email_warnings', v_duplicate_email_count,
    'duplicate_name_warnings', v_duplicate_name_count
  );

  INSERT INTO private.trusted_operation_receipts (
    operation_type,
    actor_user_id,
    request_id,
    wedding_id,
    request_hash,
    result_resource_id,
    result_summary
  )
  VALUES (
    'TOP-GUE-004',
    v_actor_id,
    p_request_id,
    p_wedding_id,
    v_request_hash,
    p_wedding_id,
    v_result
  );

  RETURN jsonb_build_object(
    'replayed', false,
    'success', true,
    'wedding_id', p_wedding_id,
    'summary', v_result
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION api_v1.confirm_guest_import(uuid, uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api_v1.confirm_guest_import(uuid, uuid, jsonb) TO authenticated;
ALTER FUNCTION api_v1.confirm_guest_import(uuid, uuid, jsonb) OWNER TO trusted_function_owner;
