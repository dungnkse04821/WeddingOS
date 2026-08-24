-- =============================================================================
-- BATCH-08: M4 Public Guest Invitation Resolve
-- =============================================================================

-- M3 created this trigger as SECURITY DEFINER, which makes current_user inside
-- the trigger equal the trigger owner instead of the actual mutating execution
-- role. Class-D view tracking needs the existing current_user authority check
-- to distinguish trusted_function_owner from ordinary clients.
ALTER FUNCTION public.fn_invitation_lifecycle_guard() SECURITY INVOKER;

CREATE SCHEMA IF NOT EXISTS edge_api;
ALTER SCHEMA edge_api OWNER TO trusted_function_owner;
REVOKE ALL ON SCHEMA edge_api FROM PUBLIC;
REVOKE ALL ON SCHEMA edge_api FROM anon;
REVOKE ALL ON SCHEMA edge_api FROM authenticated;
GRANT USAGE ON SCHEMA edge_api TO service_role;

-- ---------------------------------------------------------------------------
-- SECTION 1: CLASS-D ABUSE CONTROL STATE
-- ---------------------------------------------------------------------------

CREATE TABLE private.class_d_rate_limits (
  limiter_key  varchar(128) PRIMARY KEY,
  window_start timestamptz  NOT NULL,
  request_count integer     NOT NULL,
  updated_at   timestamptz  NOT NULL DEFAULT now()
);

CREATE INDEX idx_class_d_rate_limits_window_start
  ON private.class_d_rate_limits (window_start);

ALTER TABLE private.class_d_rate_limits OWNER TO trusted_function_owner;
REVOKE ALL ON private.class_d_rate_limits FROM PUBLIC;
REVOKE ALL ON private.class_d_rate_limits FROM anon;
REVOKE ALL ON private.class_d_rate_limits FROM authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON private.class_d_rate_limits TO trusted_function_owner;

CREATE OR REPLACE FUNCTION private.check_class_d_rate_limit(
  p_limiter_key varchar(128),
  p_window_seconds integer DEFAULT 60,
  p_threshold integer DEFAULT 30
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_now timestamptz := clock_timestamp();
  v_window_start timestamptz;
  v_count integer;
BEGIN
  IF p_limiter_key IS NULL OR trim(p_limiter_key) = '' THEN
    p_limiter_key := 'D-INV-001:unknown-network';
  END IF;

  WITH stale_rows AS (
    SELECT ctid
    FROM private.class_d_rate_limits
    WHERE window_start <= v_now - make_interval(secs => GREATEST(p_window_seconds, 60) * 10)
      AND limiter_key <> p_limiter_key
    ORDER BY window_start ASC
    LIMIT 100
  )
  DELETE FROM private.class_d_rate_limits r
  USING stale_rows s
  WHERE r.ctid = s.ctid;

  INSERT INTO private.class_d_rate_limits (limiter_key, window_start, request_count, updated_at)
  VALUES (p_limiter_key, v_now, 1, v_now)
  ON CONFLICT (limiter_key) DO UPDATE
    SET window_start = CASE
          WHEN private.class_d_rate_limits.window_start
               <= v_now - make_interval(secs => p_window_seconds)
          THEN v_now
          ELSE private.class_d_rate_limits.window_start
        END,
        request_count = CASE
          WHEN private.class_d_rate_limits.window_start
               <= v_now - make_interval(secs => p_window_seconds)
          THEN 1
          ELSE private.class_d_rate_limits.request_count + 1
        END,
        updated_at = v_now
  RETURNING window_start, request_count
  INTO v_window_start, v_count;

  RETURN jsonb_build_object(
    'allowed', v_count <= p_threshold,
    'request_count', v_count,
    'threshold', p_threshold,
    'window_seconds', p_window_seconds,
    'retry_after_seconds', CASE
      WHEN v_count <= p_threshold THEN 0
      ELSE GREATEST(1, CEIL(EXTRACT(EPOCH FROM (v_window_start + make_interval(secs => p_window_seconds) - v_now)))::integer)
    END
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION private.check_class_d_rate_limit(varchar, integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.check_class_d_rate_limit(varchar, integer, integer) TO trusted_function_owner;

-- ---------------------------------------------------------------------------
-- SECTION 2: D-INV-001 INTERNAL RESOLVE PRIMITIVE
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION internal.resolve_public_invitation(
  p_raw_token text,
  p_limiter_key varchar(128) DEFAULT NULL,
  p_rate_limit_threshold integer DEFAULT 30
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_limiter jsonb;
  v_token_hash bytea;
  v_record record;
  v_events jsonb;
  v_view_time timestamptz := clock_timestamp();
BEGIN
  v_limiter := private.check_class_d_rate_limit(
    COALESCE(NULLIF(trim(p_limiter_key), ''), 'D-INV-001:unknown-network'),
    60,
    COALESCE(p_rate_limit_threshold, 30)
  );

  IF COALESCE((v_limiter ->> 'allowed')::boolean, false) = false THEN
    RETURN jsonb_build_object(
      'ok', false,
      'http_status', 429,
      'error_code', 'RATE_LIMITED',
      'retry_after_seconds', (v_limiter ->> 'retry_after_seconds')::integer
    );
  END IF;

  IF p_raw_token IS NULL OR p_raw_token !~ '^[A-Za-z0-9_-]{43}$' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'http_status', 404,
      'error_code', 'INVITATION_UNAVAILABLE'
    );
  END IF;

  v_token_hash := extensions.digest(p_raw_token, 'sha256');

  SELECT
    c.id AS credential_id,
    i.id AS invitation_id,
    i.status AS invitation_status,
    i.first_viewed_at,
    i.wedding_id,
    w.name AS wedding_name,
    w.timezone,
    w.rsvp_cutoff_date,
    w.status AS wedding_status,
    w.public_contact_phone,
    w.public_contact_email,
    p.display_name AS party_display_name,
    p.invited_count
  INTO v_record
  FROM public.invitation_credentials c
  JOIN public.invitations i ON i.id = c.invitation_id
  JOIN public.weddings w ON w.id = i.wedding_id
  JOIN public.invitation_parties p ON p.id = i.invitation_party_id
  WHERE c.token_hash = v_token_hash
    AND c.is_active = true
    AND c.revoked_at IS NULL
  LIMIT 1;

  IF v_record.invitation_id IS NULL
     OR v_record.wedding_status <> 'ACTIVE'
     OR v_record.invitation_status NOT IN ('READY', 'MARKED_AS_SENT') THEN
    RETURN jsonb_build_object(
      'ok', false,
      'http_status', 404,
      'error_code', 'INVITATION_UNAVAILABLE'
    );
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'name', e.name,
      'date_precision', CASE WHEN e.exact_date IS NOT NULL THEN 'EXACT' ELSE 'EXPECTED_MONTH' END,
      'exact_date', e.exact_date,
      'expected_year', e.expected_year,
      'expected_month', e.expected_month,
      'start_time', e.start_time,
      'location', e.location,
      'map_link', e.map_link,
      'rsvp_ready', e.exact_date IS NOT NULL
    )
    ORDER BY e.created_at ASC
  ), '[]'::jsonb)
  INTO v_events
  FROM public.invitation_event_targetings t
  JOIN public.wedding_events e
    ON e.id = t.wedding_event_id
   AND e.wedding_id = t.wedding_id
  WHERE t.invitation_id = v_record.invitation_id
    AND t.wedding_id = v_record.wedding_id
    AND e.lifecycle_status = 'ACTIVE';

  BEGIN
    UPDATE public.invitations
    SET first_viewed_at = COALESCE(first_viewed_at, v_view_time),
        last_viewed_at = v_view_time
    WHERE id = v_record.invitation_id;
  EXCEPTION WHEN OTHERS THEN
    -- View tracking is explicitly secondary; do not block public content.
    NULL;
  END;

  RETURN jsonb_build_object(
    'ok', true,
    'http_status', 200,
    'invitation', jsonb_build_object(
      'wedding', jsonb_build_object(
        'name', v_record.wedding_name,
        'timezone', v_record.timezone,
        'rsvp_cutoff_date', v_record.rsvp_cutoff_date,
        'public_contact_phone', v_record.public_contact_phone,
        'public_contact_email', v_record.public_contact_email
      ),
      'party', jsonb_build_object(
        'display_name', v_record.party_display_name,
        'invited_count', v_record.invited_count
      ),
      'status', v_record.invitation_status,
      'can_submit_rsvp', false,
      'events', v_events
    )
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION internal.resolve_public_invitation(text, varchar, integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION internal.resolve_public_invitation(text, varchar, integer) FROM anon;
REVOKE EXECUTE ON FUNCTION internal.resolve_public_invitation(text, varchar, integer) FROM authenticated;
REVOKE EXECUTE ON FUNCTION internal.resolve_public_invitation(text, varchar, integer) FROM service_role;
ALTER FUNCTION internal.resolve_public_invitation(text, varchar, integer) OWNER TO trusted_function_owner;

CREATE OR REPLACE FUNCTION edge_api.resolve_public_invitation(
  p_raw_token text,
  p_limiter_key varchar(128) DEFAULT NULL,
  p_rate_limit_threshold integer DEFAULT 30
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN internal.resolve_public_invitation(
    p_raw_token,
    p_limiter_key,
    p_rate_limit_threshold
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION edge_api.resolve_public_invitation(text, varchar, integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION edge_api.resolve_public_invitation(text, varchar, integer) FROM anon;
REVOKE EXECUTE ON FUNCTION edge_api.resolve_public_invitation(text, varchar, integer) FROM authenticated;
GRANT EXECUTE ON FUNCTION edge_api.resolve_public_invitation(text, varchar, integer) TO service_role;
ALTER FUNCTION edge_api.resolve_public_invitation(text, varchar, integer) OWNER TO trusted_function_owner;
