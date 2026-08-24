-- =============================================================================
-- BATCH-10: M4.3 VietQR Gating (STORY-07-02)
-- =============================================================================

-- VietQR is Wedding-level static display configuration.  A QR image key may be
-- retained for the existing Media checkpoint, but this checkpoint does not
-- expose or upload media; bank display facts are sufficient for the public DTO.
CREATE OR REPLACE FUNCTION public.validate_vietqr_configuration()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF NEW.vietqr_enabled AND (
    NULLIF(trim(NEW.vietqr_bank_id), '') IS NULL
    OR NULLIF(trim(NEW.vietqr_account_no), '') IS NULL
    OR NULLIF(trim(NEW.vietqr_account_name), '') IS NULL
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'INVALID_VIETQR_CONFIGURATION';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_weddings_validate_vietqr_configuration
  BEFORE INSERT OR UPDATE OF vietqr_enabled, vietqr_bank_id, vietqr_account_no, vietqr_account_name
  ON public.weddings
  FOR EACH ROW EXECUTE FUNCTION public.validate_vietqr_configuration();

-- The resolver owns the public disclosure decision.  It deliberately returns
-- only an availability flag until all three approved conditions are true.
CREATE OR REPLACE FUNCTION internal.public_vietqr_state(
  p_invitation_id uuid,
  p_wedding_id uuid,
  p_rsvp_state jsonb
)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT CASE WHEN EXISTS (
    SELECT 1
    FROM public.weddings w
    WHERE w.id = p_wedding_id
      AND w.status = 'ACTIVE'
      AND w.vietqr_enabled = true
      AND NULLIF(trim(w.vietqr_bank_id), '') IS NOT NULL
      AND NULLIF(trim(w.vietqr_account_no), '') IS NOT NULL
      AND NULLIF(trim(w.vietqr_account_name), '') IS NOT NULL
      AND p_rsvp_state ->> 'summary' = 'RESPONDED'
      AND EXISTS (
        SELECT 1
        FROM public.invitation_event_targetings t
        JOIN public.wedding_events e
          ON e.id = t.wedding_event_id AND e.wedding_id = t.wedding_id
        WHERE t.invitation_id = p_invitation_id
          AND t.wedding_id = p_wedding_id
          AND e.lifecycle_status = 'ACTIVE'
          AND e.exact_date IS NOT NULL
      )
  ) THEN (
    SELECT jsonb_build_object(
      'available', true,
      'bank_id', w.vietqr_bank_id,
      'account_no', w.vietqr_account_no,
      'account_name', w.vietqr_account_name
    ) FROM public.weddings w WHERE w.id = p_wedding_id
  ) ELSE jsonb_build_object('available', false) END;
$$;

REVOKE EXECUTE ON FUNCTION internal.public_vietqr_state(uuid, uuid, jsonb) FROM PUBLIC, anon, authenticated, service_role;
ALTER FUNCTION internal.public_vietqr_state(uuid, uuid, jsonb) OWNER TO trusted_function_owner;

-- Preserve the M4.1/M4.2 implementations as hidden bases and add only the
-- authorized M4.3 DTO fields after their existing validation and rate limits.
ALTER FUNCTION internal.resolve_public_invitation(text, varchar, integer)
  RENAME TO resolve_public_invitation_base;

CREATE FUNCTION internal.resolve_public_invitation(
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
  v_result jsonb;
  v_invitation record;
  v_rsvp jsonb;
BEGIN
  v_result := internal.resolve_public_invitation_base(p_raw_token, p_limiter_key, p_rate_limit_threshold);
  IF COALESCE((v_result ->> 'ok')::boolean, false) = false THEN RETURN v_result; END IF;

  SELECT i.id, i.wedding_id, p.invited_count
  INTO v_invitation
  FROM public.invitation_credentials c
  JOIN public.invitations i ON i.id = c.invitation_id
  JOIN public.invitation_parties p ON p.id = i.invitation_party_id
  WHERE c.token_hash = extensions.digest(p_raw_token, 'sha256')
    AND c.is_active = true AND c.revoked_at IS NULL;
  v_rsvp := v_result #> '{invitation,rsvp}';
  RETURN jsonb_set(v_result, '{invitation,vietqr}',
    internal.public_vietqr_state(v_invitation.id, v_invitation.wedding_id, v_rsvp), true);
END;
$$;

REVOKE EXECUTE ON FUNCTION internal.resolve_public_invitation_base(text, varchar, integer) FROM PUBLIC, anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION internal.resolve_public_invitation(text, varchar, integer) FROM PUBLIC, anon, authenticated, service_role;
ALTER FUNCTION internal.resolve_public_invitation_base(text, varchar, integer) OWNER TO trusted_function_owner;
ALTER FUNCTION internal.resolve_public_invitation(text, varchar, integer) OWNER TO trusted_function_owner;

ALTER FUNCTION internal.submit_public_rsvp(text, jsonb, jsonb, varchar, integer)
  RENAME TO submit_public_rsvp_base;

CREATE FUNCTION internal.submit_public_rsvp(
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
  v_result jsonb;
  v_invitation record;
BEGIN
  v_result := internal.submit_public_rsvp_base(
    p_raw_token, p_responses, p_optional_fields, p_limiter_key, p_rate_limit_threshold);
  IF COALESCE((v_result ->> 'ok')::boolean, false) = false THEN RETURN v_result; END IF;

  SELECT i.id, i.wedding_id
  INTO v_invitation
  FROM public.invitation_credentials c
  JOIN public.invitations i ON i.id = c.invitation_id
  WHERE c.token_hash = extensions.digest(p_raw_token, 'sha256')
    AND c.is_active = true AND c.revoked_at IS NULL;
  RETURN jsonb_set(v_result, '{vietqr}', internal.public_vietqr_state(
    v_invitation.id, v_invitation.wedding_id, v_result -> 'rsvp'), true);
END;
$$;

REVOKE EXECUTE ON FUNCTION internal.submit_public_rsvp_base(text, jsonb, jsonb, varchar, integer) FROM PUBLIC, anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION internal.submit_public_rsvp(text, jsonb, jsonb, varchar, integer) FROM PUBLIC, anon, authenticated, service_role;
ALTER FUNCTION internal.submit_public_rsvp_base(text, jsonb, jsonb, varchar, integer) OWNER TO trusted_function_owner;
ALTER FUNCTION internal.submit_public_rsvp(text, jsonb, jsonb, varchar, integer) OWNER TO trusted_function_owner;
