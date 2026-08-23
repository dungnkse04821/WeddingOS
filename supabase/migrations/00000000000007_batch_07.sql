-- =============================================================================
-- BATCH-07: M3 Invitation / Credential Foundation
-- =============================================================================

-- ---------------------------------------------------------------------------
-- SECTION 1: BUSINESS TABLES
-- ---------------------------------------------------------------------------

CREATE TABLE public.invitations (
  id                  uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id          uuid         NOT NULL REFERENCES public.weddings (id) ON DELETE CASCADE,
  invitation_party_id uuid         NOT NULL,
  status              varchar(50)  NOT NULL DEFAULT 'DRAFT',
  marked_sent_at      timestamptz,
  first_viewed_at     timestamptz,
  last_viewed_at      timestamptz,
  created_at          timestamptz  NOT NULL DEFAULT now(),
  updated_at          timestamptz  NOT NULL DEFAULT now(),
  CONSTRAINT chk_invitations_status CHECK (status IN ('DRAFT', 'READY', 'MARKED_AS_SENT')),
  CONSTRAINT fk_invitations_party_wedding FOREIGN KEY (wedding_id, invitation_party_id)
    REFERENCES public.invitation_parties (wedding_id, id) ON DELETE RESTRICT,
  CONSTRAINT uq_invitations_wedding_key UNIQUE (wedding_id, id)
);

CREATE UNIQUE INDEX uq_invitation_party
  ON public.invitations (invitation_party_id);

CREATE TABLE public.invitation_event_targetings (
  wedding_id       uuid NOT NULL,
  invitation_id    uuid NOT NULL,
  wedding_event_id uuid NOT NULL,
  CONSTRAINT pk_invitation_event_targeting PRIMARY KEY (invitation_id, wedding_event_id),
  CONSTRAINT fk_targeting_invitation_wedding FOREIGN KEY (wedding_id, invitation_id)
    REFERENCES public.invitations (wedding_id, id) ON DELETE CASCADE,
  CONSTRAINT fk_targeting_event_wedding FOREIGN KEY (wedding_id, wedding_event_id)
    REFERENCES public.wedding_events (wedding_id, id) ON DELETE CASCADE
);

CREATE TABLE public.invitation_credentials (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  invitation_id uuid        NOT NULL REFERENCES public.invitations (id) ON DELETE CASCADE,
  token_hash    bytea       NOT NULL UNIQUE,
  is_active     boolean     NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  revoked_at    timestamptz,
  CONSTRAINT chk_credential_hash_length CHECK (octet_length(token_hash) = 32),
  CONSTRAINT chk_credential_revocation CHECK (
    (is_active = true AND revoked_at IS NULL) OR
    (is_active = false AND revoked_at IS NOT NULL)
  )
);

CREATE UNIQUE INDEX uq_active_credential
  ON public.invitation_credentials (invitation_id)
  WHERE (is_active = true);

CREATE INDEX idx_credentials_hash
  ON public.invitation_credentials (token_hash);

-- ---------------------------------------------------------------------------
-- SECTION 2: TRIGGERS
-- ---------------------------------------------------------------------------

CREATE TRIGGER trg_invitations_updated_at
  BEFORE UPDATE ON public.invitations
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.fn_invitation_lifecycle_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_party public.invitation_parties%ROWTYPE;
  v_target_count integer;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.status <> 'DRAFT' THEN
      RAISE EXCEPTION 'INVALID_INVITATION_STATUS: invitations must be created as DRAFT.'
        USING ERRCODE = 'P0002';
    END IF;
    NEW.marked_sent_at := NULL;
    NEW.first_viewed_at := NULL;
    NEW.last_viewed_at := NULL;
    RETURN NEW;
  END IF;

  IF NEW.wedding_id IS DISTINCT FROM OLD.wedding_id
     OR NEW.invitation_party_id IS DISTINCT FROM OLD.invitation_party_id THEN
    RAISE EXCEPTION 'INVALID_INVITATION_UPDATE: invitation identity cannot be changed.'
      USING ERRCODE = '42501';
  END IF;

  -- View tracking belongs to future trusted Class-D resolve, never ordinary Class-B edits.
  IF current_user <> 'trusted_function_owner' THEN
    NEW.first_viewed_at := OLD.first_viewed_at;
    NEW.last_viewed_at := OLD.last_viewed_at;
  END IF;

  IF NEW.status = OLD.status THEN
    IF NEW.marked_sent_at IS DISTINCT FROM OLD.marked_sent_at THEN
      NEW.marked_sent_at := OLD.marked_sent_at;
    END IF;
    RETURN NEW;
  END IF;

  IF OLD.status = 'DRAFT' AND NEW.status = 'READY' THEN
    SELECT * INTO v_party
    FROM public.invitation_parties
    WHERE id = OLD.invitation_party_id
      AND wedding_id = OLD.wedding_id;

    IF v_party.id IS NULL OR trim(v_party.display_name) = '' OR v_party.invited_count <= 0 THEN
      RAISE EXCEPTION 'INVITATION_NOT_READY: party display name and invited_count are required.'
        USING ERRCODE = 'P0002';
    END IF;

    SELECT count(*) INTO v_target_count
    FROM public.invitation_event_targetings t
    JOIN public.wedding_events e
      ON e.id = t.wedding_event_id
     AND e.wedding_id = t.wedding_id
    WHERE t.invitation_id = OLD.id
      AND t.wedding_id = OLD.wedding_id
      AND e.lifecycle_status = 'ACTIVE';

    IF v_target_count = 0 THEN
      RAISE EXCEPTION 'INVITATION_NOT_READY: at least one active event target is required.'
        USING ERRCODE = 'P0002';
    END IF;

    NEW.marked_sent_at := NULL;
    RETURN NEW;
  END IF;

  IF OLD.status = 'READY' AND NEW.status = 'MARKED_AS_SENT' THEN
    NEW.marked_sent_at := COALESCE(OLD.marked_sent_at, now());
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'INVALID_INVITATION_TRANSITION: % -> % is not allowed.', OLD.status, NEW.status
    USING ERRCODE = 'P0002';
END;
$$;

CREATE TRIGGER trg_invitation_lifecycle_guard
  BEFORE INSERT OR UPDATE ON public.invitations
  FOR EACH ROW EXECUTE FUNCTION public.fn_invitation_lifecycle_guard();

CREATE OR REPLACE FUNCTION public.fn_invitation_targeting_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.wedding_events
    WHERE id = NEW.wedding_event_id
      AND wedding_id = NEW.wedding_id
      AND lifecycle_status = 'ACTIVE'
  ) THEN
    RAISE EXCEPTION 'INVALID_INVITATION_TARGET: targeted event must be active and same-Wedding.'
      USING ERRCODE = 'P0002';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_invitation_targeting_guard
  BEFORE INSERT OR UPDATE ON public.invitation_event_targetings
  FOR EACH ROW EXECUTE FUNCTION public.fn_invitation_targeting_guard();

-- ---------------------------------------------------------------------------
-- SECTION 3: ROW LEVEL SECURITY & GRANTS
-- ---------------------------------------------------------------------------

ALTER TABLE public.invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invitation_event_targetings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invitation_credentials ENABLE ROW LEVEL SECURITY;

CREATE POLICY select_invitations_if_member ON public.invitations
  FOR SELECT TO authenticated
  USING (security.is_active_wedding_member(wedding_id));

CREATE POLICY insert_invitations_if_member ON public.invitations
  FOR INSERT TO authenticated
  WITH CHECK (security.can_mutate_wedding(wedding_id));

CREATE POLICY update_invitations_if_member ON public.invitations
  FOR UPDATE TO authenticated
  USING (security.can_mutate_wedding(wedding_id))
  WITH CHECK (security.can_mutate_wedding(wedding_id));

CREATE POLICY select_targetings_if_member ON public.invitation_event_targetings
  FOR SELECT TO authenticated
  USING (security.is_active_wedding_member(wedding_id));

CREATE POLICY insert_targetings_if_member ON public.invitation_event_targetings
  FOR INSERT TO authenticated
  WITH CHECK (security.can_mutate_wedding(wedding_id));

CREATE POLICY delete_targetings_if_member ON public.invitation_event_targetings
  FOR DELETE TO authenticated
  USING (security.can_mutate_wedding(wedding_id));

GRANT SELECT ON public.invitations TO authenticated;
GRANT INSERT (wedding_id, invitation_party_id) ON public.invitations TO authenticated;
GRANT UPDATE (status) ON public.invitations TO authenticated;

GRANT SELECT, INSERT, DELETE ON public.invitation_event_targetings TO authenticated;

-- Credential storage remains Class C/D only: no Data API grants or policies.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.invitations TO trusted_function_owner;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.invitation_event_targetings TO trusted_function_owner;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.invitation_credentials TO trusted_function_owner;

-- ---------------------------------------------------------------------------
-- SECTION 4: TRUSTED OPERATION TOP-INV-001
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api_v1.regenerate_invitation_credential(
  p_invitation_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid;
  v_invitation record;
  v_random_bytes bytea;
  v_raw_token text;
  v_token_hash bytea;
  v_credential_id uuid;
BEGIN
  v_actor_id := auth.uid();
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'UNAUTHORIZED: caller is not authenticated.'
      USING ERRCODE = '42501';
  END IF;

  SELECT
    i.id,
    i.wedding_id,
    i.status,
    w.status AS wedding_status
  INTO v_invitation
  FROM public.invitations i
  JOIN public.weddings w ON w.id = i.wedding_id
  WHERE i.id = p_invitation_id
  FOR UPDATE OF i;

  IF v_invitation.id IS NULL THEN
    RAISE EXCEPTION 'INVITATION_NOT_FOUND: invitation does not exist.'
      USING ERRCODE = 'P0002';
  END IF;

  IF v_invitation.wedding_status <> 'ACTIVE' OR NOT EXISTS (
    SELECT 1
    FROM public.wedding_members
    WHERE wedding_id = v_invitation.wedding_id
      AND user_id = v_actor_id
      AND role IN ('OWNER', 'COLLABORATOR')
      AND status = 'ACTIVE'
  ) THEN
    RAISE EXCEPTION 'UNAUTHORIZED: caller cannot regenerate this invitation credential.'
      USING ERRCODE = '42501';
  END IF;

  IF v_invitation.status NOT IN ('READY', 'MARKED_AS_SENT') THEN
    RAISE EXCEPTION 'INVITATION_NOT_READY: credential can only be generated for READY or MARKED_AS_SENT invitations.'
      USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.invitation_credentials
  SET is_active = false,
      revoked_at = now()
  WHERE invitation_id = p_invitation_id
    AND is_active = true;

  LOOP
    v_random_bytes := extensions.gen_random_bytes(32);
    v_raw_token := translate(rtrim(replace(encode(v_random_bytes, 'base64'), E'\n', ''), '='), '+/', '-_');
    v_token_hash := extensions.digest(v_raw_token, 'sha256');

    BEGIN
      INSERT INTO public.invitation_credentials (invitation_id, token_hash, is_active)
      VALUES (p_invitation_id, v_token_hash, true)
      RETURNING id INTO v_credential_id;
      EXIT;
    EXCEPTION WHEN unique_violation THEN
      -- Extremely unlikely; generate a fresh opaque token and retry.
      CONTINUE;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'invitation_id', p_invitation_id,
    'credential_id', v_credential_id,
    'raw_token', v_raw_token,
    'link_fragment', '#/invite/' || v_raw_token,
    'token_format', 'base64url-32-byte-random-sha256-hash'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION api_v1.regenerate_invitation_credential(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api_v1.regenerate_invitation_credential(uuid) TO authenticated;
ALTER FUNCTION api_v1.regenerate_invitation_credential(uuid) OWNER TO trusted_function_owner;
