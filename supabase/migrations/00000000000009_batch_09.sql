-- =============================================================================
-- BATCH-09: M4.2 Public RSVP Submit (D-RSV-001)
-- =============================================================================

CREATE TABLE public.rsvps (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  invitation_id   uuid        NOT NULL REFERENCES public.invitations (id) ON DELETE CASCADE,
  submitted_at    timestamptz NOT NULL DEFAULT now(),
  notes           text,
  companion_names text[],
  dietary_info    text,
  guest_message   text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_rsvps_invitation UNIQUE (invitation_id)
);

CREATE INDEX idx_rsvps_invitation ON public.rsvps (invitation_id);

CREATE TABLE public.event_responses (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  rsvp_id          uuid        NOT NULL REFERENCES public.rsvps (id) ON DELETE CASCADE,
  wedding_event_id uuid        NOT NULL REFERENCES public.wedding_events (id) ON DELETE RESTRICT,
  is_attending     boolean     NOT NULL,
  attending_count  integer     NOT NULL DEFAULT 0,
  created_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_event_responses_count_nonnegative CHECK (attending_count >= 0),
  CONSTRAINT chk_event_responses_attendance CHECK (
    (is_attending = true AND attending_count >= 1)
    OR (is_attending = false AND attending_count = 0)
  ),
  CONSTRAINT uq_event_responses_rsvp_event UNIQUE (rsvp_id, wedding_event_id)
);

ALTER TABLE public.rsvps OWNER TO trusted_function_owner;
ALTER TABLE public.event_responses OWNER TO trusted_function_owner;
ALTER TABLE public.rsvps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_responses ENABLE ROW LEVEL SECURITY;

CREATE POLICY select_rsvps_if_member ON public.rsvps
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.invitations i
      WHERE i.id = invitation_id AND security.is_active_wedding_member(i.wedding_id)
    )
  );

CREATE POLICY select_event_responses_if_member ON public.event_responses
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.rsvps r
      JOIN public.invitations i ON i.id = r.invitation_id
      WHERE r.id = rsvp_id AND security.is_active_wedding_member(i.wedding_id)
    )
  );

GRANT SELECT ON public.rsvps, public.event_responses TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.rsvps, public.event_responses TO trusted_function_owner;

CREATE OR REPLACE FUNCTION internal.public_rsvp_state(
  p_invitation_id uuid,
  p_wedding_id uuid,
  p_invited_count integer
)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  WITH ready_events AS (
    SELECT t.wedding_event_id
    FROM public.invitation_event_targetings t
    JOIN public.wedding_events e
      ON e.id = t.wedding_event_id AND e.wedding_id = t.wedding_id
    WHERE t.invitation_id = p_invitation_id
      AND t.wedding_id = p_wedding_id
      AND e.lifecycle_status = 'ACTIVE'
      AND e.exact_date IS NOT NULL
  ), current_rsvp AS (
    SELECT r.* FROM public.rsvps r WHERE r.invitation_id = p_invitation_id
  ), active_responses AS (
    SELECT er.*
    FROM public.event_responses er
    JOIN current_rsvp r ON r.id = er.rsvp_id
    JOIN ready_events re ON re.wedding_event_id = er.wedding_event_id
  ), counts AS (
    SELECT
      (SELECT count(*) FROM ready_events) AS ready_count,
      (SELECT count(*) FROM active_responses) AS response_count,
      COALESCE((SELECT sum(attending_count) FROM active_responses), 0) AS attending_total
  )
  SELECT jsonb_build_object(
    'summary', CASE
      WHEN counts.ready_count = 0 OR counts.response_count = 0 THEN 'PENDING'
      WHEN counts.response_count = counts.ready_count THEN 'RESPONDED'
      ELSE 'PARTIAL'
    END,
    'companion_names', COALESCE((SELECT to_jsonb(companion_names) FROM current_rsvp), 'null'::jsonb),
    'dietary_info', COALESCE((SELECT to_jsonb(dietary_info) FROM current_rsvp), 'null'::jsonb),
    'guest_message', COALESCE((SELECT to_jsonb(guest_message) FROM current_rsvp), 'null'::jsonb),
    'note', COALESCE((SELECT to_jsonb(notes) FROM current_rsvp), 'null'::jsonb),
    'event_responses', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'event_id', wedding_event_id,
        'response_status', CASE WHEN is_attending THEN 'ATTENDING' ELSE 'NOT_ATTENDING' END,
        'attending_count', attending_count
      ) ORDER BY wedding_event_id)
      FROM active_responses
    ), '[]'::jsonb),
    'warnings', CASE WHEN counts.attending_total > p_invited_count
      THEN jsonb_build_array('RSVP_OVERCOUNT') ELSE '[]'::jsonb END
  )
  FROM counts;
$$;

REVOKE EXECUTE ON FUNCTION internal.public_rsvp_state(uuid, uuid, integer) FROM PUBLIC, anon, authenticated, service_role;
ALTER FUNCTION internal.public_rsvp_state(uuid, uuid, integer) OWNER TO trusted_function_owner;

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
  v_rsvp jsonb;
  v_can_submit boolean;
  v_view_time timestamptz := clock_timestamp();
BEGIN
  v_limiter := private.check_class_d_rate_limit(
    COALESCE(NULLIF(trim(p_limiter_key), ''), 'D-INV-001:unknown-network'), 60,
    COALESCE(p_rate_limit_threshold, 30)
  );
  IF COALESCE((v_limiter ->> 'allowed')::boolean, false) = false THEN
    RETURN jsonb_build_object('ok', false, 'http_status', 429, 'error_code', 'RATE_LIMITED',
      'retry_after_seconds', (v_limiter ->> 'retry_after_seconds')::integer);
  END IF;
  IF p_raw_token IS NULL OR p_raw_token !~ '^[A-Za-z0-9_-]{43}$' THEN
    RETURN jsonb_build_object('ok', false, 'http_status', 404, 'error_code', 'INVITATION_UNAVAILABLE');
  END IF;

  v_token_hash := extensions.digest(p_raw_token, 'sha256');
  SELECT c.id AS credential_id, i.id AS invitation_id, i.status AS invitation_status,
         i.wedding_id, w.name AS wedding_name, w.timezone, w.rsvp_cutoff_date,
         w.status AS wedding_status, w.public_contact_phone, w.public_contact_email,
         p.display_name AS party_display_name, p.invited_count
  INTO v_record
  FROM public.invitation_credentials c
  JOIN public.invitations i ON i.id = c.invitation_id
  JOIN public.weddings w ON w.id = i.wedding_id
  JOIN public.invitation_parties p ON p.id = i.invitation_party_id
  WHERE c.token_hash = v_token_hash AND c.is_active = true AND c.revoked_at IS NULL
  LIMIT 1;
  IF v_record.invitation_id IS NULL OR v_record.wedding_status <> 'ACTIVE'
     OR v_record.invitation_status NOT IN ('READY', 'MARKED_AS_SENT') THEN
    RETURN jsonb_build_object('ok', false, 'http_status', 404, 'error_code', 'INVITATION_UNAVAILABLE');
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', e.id, 'name', e.name,
    'date_precision', CASE WHEN e.exact_date IS NOT NULL THEN 'EXACT' ELSE 'EXPECTED_MONTH' END,
    'exact_date', e.exact_date, 'expected_year', e.expected_year, 'expected_month', e.expected_month,
    'start_time', e.start_time, 'location', e.location, 'map_link', e.map_link,
    'rsvp_ready', e.exact_date IS NOT NULL
  ) ORDER BY e.created_at ASC), '[]'::jsonb)
  INTO v_events
  FROM public.invitation_event_targetings t
  JOIN public.wedding_events e ON e.id = t.wedding_event_id AND e.wedding_id = t.wedding_id
  WHERE t.invitation_id = v_record.invitation_id AND t.wedding_id = v_record.wedding_id
    AND e.lifecycle_status = 'ACTIVE';

  v_can_submit := v_record.rsvp_cutoff_date IS NULL
    OR (clock_timestamp() AT TIME ZONE v_record.timezone)::date <= v_record.rsvp_cutoff_date;
  v_rsvp := internal.public_rsvp_state(v_record.invitation_id, v_record.wedding_id, v_record.invited_count);
  BEGIN
    UPDATE public.invitations
    SET first_viewed_at = COALESCE(first_viewed_at, v_view_time), last_viewed_at = v_view_time
    WHERE id = v_record.invitation_id;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN jsonb_build_object('ok', true, 'http_status', 200, 'invitation', jsonb_build_object(
    'wedding', jsonb_build_object('name', v_record.wedding_name, 'timezone', v_record.timezone,
      'rsvp_cutoff_date', v_record.rsvp_cutoff_date, 'public_contact_phone', v_record.public_contact_phone,
      'public_contact_email', v_record.public_contact_email),
    'party', jsonb_build_object('display_name', v_record.party_display_name, 'invited_count', v_record.invited_count),
    'status', v_record.invitation_status, 'can_submit_rsvp', v_can_submit, 'events', v_events, 'rsvp', v_rsvp
  ));
END;
$$;

REVOKE EXECUTE ON FUNCTION internal.resolve_public_invitation(text, varchar, integer) FROM PUBLIC, anon, authenticated, service_role;
ALTER FUNCTION internal.resolve_public_invitation(text, varchar, integer) OWNER TO trusted_function_owner;

CREATE OR REPLACE FUNCTION internal.submit_public_rsvp(
  p_raw_token text,
  p_responses jsonb,
  p_optional_fields jsonb DEFAULT '{}'::jsonb,
  p_limiter_key varchar(128) DEFAULT NULL,
  p_rate_limit_threshold integer DEFAULT 10
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_limiter jsonb;
  v_token_hash bytea;
  v_invitation record;
  v_patch jsonb;
  v_event_id uuid;
  v_status text;
  v_count integer;
  v_rsvp_id uuid;
  v_companions text[];
  v_state jsonb;
BEGIN
  v_limiter := private.check_class_d_rate_limit(
    COALESCE(NULLIF(trim(p_limiter_key), ''), 'D-RSV-001:unknown-network'),
    60,
    COALESCE(p_rate_limit_threshold, 10)
  );
  IF COALESCE((v_limiter ->> 'allowed')::boolean, false) = false THEN
    RETURN jsonb_build_object('ok', false, 'http_status', 429, 'error_code', 'RATE_LIMITED',
      'retry_after_seconds', (v_limiter ->> 'retry_after_seconds')::integer);
  END IF;

  IF p_raw_token IS NULL OR p_raw_token !~ '^[A-Za-z0-9_-]{43}$' THEN
    RETURN jsonb_build_object('ok', false, 'http_status', 404, 'error_code', 'INVITATION_UNAVAILABLE');
  END IF;
  IF jsonb_typeof(p_responses) <> 'array' OR jsonb_array_length(p_responses) = 0
     OR jsonb_typeof(p_optional_fields) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'http_status', 400, 'error_code', 'INVALID_RESPONSE');
  END IF;

  v_token_hash := extensions.digest(p_raw_token, 'sha256');
  SELECT i.id, i.wedding_id, w.status AS wedding_status, w.timezone, w.rsvp_cutoff_date,
         p.invited_count
  INTO v_invitation
  FROM public.invitation_credentials c
  JOIN public.invitations i ON i.id = c.invitation_id
  JOIN public.weddings w ON w.id = i.wedding_id
  JOIN public.invitation_parties p ON p.id = i.invitation_party_id
  WHERE c.token_hash = v_token_hash AND c.is_active = true AND c.revoked_at IS NULL
    AND i.status IN ('READY', 'MARKED_AS_SENT')
  FOR UPDATE OF i;

  IF v_invitation.id IS NULL OR v_invitation.wedding_status <> 'ACTIVE' THEN
    RETURN jsonb_build_object('ok', false, 'http_status', 404, 'error_code', 'INVITATION_UNAVAILABLE');
  END IF;
  IF v_invitation.rsvp_cutoff_date IS NOT NULL
     AND (clock_timestamp() AT TIME ZONE v_invitation.timezone)::date > v_invitation.rsvp_cutoff_date THEN
    RETURN jsonb_build_object('ok', false, 'http_status', 403, 'error_code', 'RSVP_CLOSED');
  END IF;

  IF EXISTS (SELECT 1 FROM jsonb_object_keys(p_optional_fields) key
             WHERE key NOT IN ('guest_message', 'dietary_info', 'note', 'companion_names'))
     OR (p_optional_fields ? 'guest_message') AND (
    jsonb_typeof(p_optional_fields -> 'guest_message') NOT IN ('string', 'null')
    OR char_length(COALESCE(p_optional_fields ->> 'guest_message', '')) > 1000
  ) OR (p_optional_fields ? 'dietary_info') AND (
    jsonb_typeof(p_optional_fields -> 'dietary_info') NOT IN ('string', 'null')
    OR char_length(COALESCE(p_optional_fields ->> 'dietary_info', '')) > 500
  ) OR (p_optional_fields ? 'note') AND (
    jsonb_typeof(p_optional_fields -> 'note') NOT IN ('string', 'null')
    OR char_length(COALESCE(p_optional_fields ->> 'note', '')) > 1000
  ) OR (p_optional_fields ? 'companion_names') AND (
    jsonb_typeof(p_optional_fields -> 'companion_names') NOT IN ('array', 'null')
    OR CASE WHEN jsonb_typeof(p_optional_fields -> 'companion_names') = 'array' THEN
      jsonb_array_length(p_optional_fields -> 'companion_names') > 20
      OR EXISTS (SELECT 1 FROM jsonb_array_elements(p_optional_fields -> 'companion_names') e
                 WHERE jsonb_typeof(e) <> 'string' OR char_length(e #>> '{}') > 100)
    ELSE false END
  ) THEN
    RETURN jsonb_build_object('ok', false, 'http_status', 400, 'error_code', 'INVALID_RESPONSE');
  END IF;

  FOR v_patch IN SELECT value FROM jsonb_array_elements(p_responses)
  LOOP
    IF jsonb_typeof(v_patch) <> 'object' OR COALESCE(v_patch ->> 'event_id', '') !~
       '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
       OR COALESCE(v_patch ->> 'attending_count', '') !~ '^[0-9]+$' THEN
      RETURN jsonb_build_object('ok', false, 'http_status', 400, 'error_code', 'INVALID_RESPONSE');
    END IF;
    v_event_id := (v_patch ->> 'event_id')::uuid;
    v_status := v_patch ->> 'response_status';
    v_count := (v_patch ->> 'attending_count')::integer;
    IF v_status NOT IN ('ATTENDING', 'NOT_ATTENDING')
       OR (v_status = 'ATTENDING' AND v_count < 1)
       OR (v_status = 'NOT_ATTENDING' AND v_count <> 0) THEN
      RETURN jsonb_build_object('ok', false, 'http_status', 400, 'error_code', 'INVALID_RESPONSE');
    END IF;
    IF NOT EXISTS (
      SELECT 1
      FROM public.invitation_event_targetings t
      JOIN public.wedding_events e ON e.id = t.wedding_event_id AND e.wedding_id = t.wedding_id
      WHERE t.invitation_id = v_invitation.id AND t.wedding_id = v_invitation.wedding_id
        AND t.wedding_event_id = v_event_id AND e.lifecycle_status = 'ACTIVE' AND e.exact_date IS NOT NULL
    ) THEN
      RETURN jsonb_build_object('ok', false, 'http_status', 400, 'error_code', 'EVENT_NOT_AVAILABLE');
    END IF;
  END LOOP;

  IF (SELECT count(*) FROM jsonb_array_elements(p_responses) e) <>
     (SELECT count(DISTINCT value ->> 'event_id') FROM jsonb_array_elements(p_responses)) THEN
    RETURN jsonb_build_object('ok', false, 'http_status', 400, 'error_code', 'INVALID_RESPONSE');
  END IF;

  IF p_optional_fields ? 'companion_names' AND jsonb_typeof(p_optional_fields -> 'companion_names') = 'array' THEN
    SELECT array_agg(value) INTO v_companions FROM jsonb_array_elements_text(p_optional_fields -> 'companion_names');
  END IF;

  INSERT INTO public.rsvps (invitation_id, submitted_at, notes, companion_names, dietary_info, guest_message, updated_at)
  VALUES (
    v_invitation.id, clock_timestamp(),
    CASE WHEN p_optional_fields ? 'note' THEN p_optional_fields ->> 'note' END,
    CASE WHEN p_optional_fields ? 'companion_names' THEN v_companions END,
    CASE WHEN p_optional_fields ? 'dietary_info' THEN p_optional_fields ->> 'dietary_info' END,
    CASE WHEN p_optional_fields ? 'guest_message' THEN p_optional_fields ->> 'guest_message' END,
    clock_timestamp()
  )
  ON CONFLICT (invitation_id) DO UPDATE SET
    submitted_at = clock_timestamp(), updated_at = clock_timestamp(),
    notes = CASE WHEN p_optional_fields ? 'note' THEN EXCLUDED.notes ELSE public.rsvps.notes END,
    companion_names = CASE WHEN p_optional_fields ? 'companion_names' THEN EXCLUDED.companion_names ELSE public.rsvps.companion_names END,
    dietary_info = CASE WHEN p_optional_fields ? 'dietary_info' THEN EXCLUDED.dietary_info ELSE public.rsvps.dietary_info END,
    guest_message = CASE WHEN p_optional_fields ? 'guest_message' THEN EXCLUDED.guest_message ELSE public.rsvps.guest_message END
  RETURNING id INTO v_rsvp_id;

  FOR v_patch IN SELECT value FROM jsonb_array_elements(p_responses)
  LOOP
    INSERT INTO public.event_responses (rsvp_id, wedding_event_id, is_attending, attending_count)
    VALUES (v_rsvp_id, (v_patch ->> 'event_id')::uuid, (v_patch ->> 'response_status') = 'ATTENDING',
      (v_patch ->> 'attending_count')::integer)
    ON CONFLICT (rsvp_id, wedding_event_id) DO UPDATE SET
      is_attending = EXCLUDED.is_attending, attending_count = EXCLUDED.attending_count;
  END LOOP;

  v_state := internal.public_rsvp_state(v_invitation.id, v_invitation.wedding_id, v_invitation.invited_count);
  RETURN jsonb_build_object('ok', true, 'http_status', 200, 'can_submit_rsvp', true, 'rsvp', v_state);
END;
$$;

REVOKE EXECUTE ON FUNCTION internal.submit_public_rsvp(text, jsonb, jsonb, varchar, integer) FROM PUBLIC, anon, authenticated, service_role;
ALTER FUNCTION internal.submit_public_rsvp(text, jsonb, jsonb, varchar, integer) OWNER TO trusted_function_owner;

CREATE OR REPLACE FUNCTION edge_api.submit_public_rsvp(
  p_raw_token text,
  p_responses jsonb,
  p_optional_fields jsonb DEFAULT '{}'::jsonb,
  p_limiter_key varchar(128) DEFAULT NULL,
  p_rate_limit_threshold integer DEFAULT 10
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN internal.submit_public_rsvp(p_raw_token, p_responses, p_optional_fields, p_limiter_key, p_rate_limit_threshold);
END;
$$;

REVOKE EXECUTE ON FUNCTION edge_api.submit_public_rsvp(text, jsonb, jsonb, varchar, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION edge_api.submit_public_rsvp(text, jsonb, jsonb, varchar, integer) TO service_role;
ALTER FUNCTION edge_api.submit_public_rsvp(text, jsonb, jsonb, varchar, integer) OWNER TO trusted_function_owner;
