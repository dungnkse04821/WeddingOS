-- =============================================================================
-- BATCH-01: M1 Vertical Slice -- Core Wedding Workspace Foundation
-- =============================================================================

-- ---------------------------------------------------------------------------
-- SECTION 1: CORE BUSINESS TABLES
-- ---------------------------------------------------------------------------

CREATE TABLE public.weddings (
  id                        uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  name                      varchar(255)  NOT NULL,
  target_budget             numeric(15,2),
  expected_year             integer,
  expected_month            integer,
  exact_date                date,
  cultural_context          varchar(50)   NOT NULL DEFAULT 'TUY_CHON',
  rsvp_cutoff_date          date,
  timezone                  varchar(50)   NOT NULL DEFAULT 'Asia/Ho_Chi_Minh',
  cover_photo_key           text,
  vietqr_bank_id            varchar(50),
  vietqr_account_no         varchar(100),
  vietqr_account_name       varchar(255),
  vietqr_enabled            boolean       NOT NULL DEFAULT false,
  vietqr_photo_key          text,
  public_contact_phone      varchar(50),
  public_contact_email      varchar(255),
  status                    varchar(50)   NOT NULL DEFAULT 'ACTIVE',
  initial_plan_generated_at timestamptz,
  created_at                timestamptz   NOT NULL DEFAULT now(),
  updated_at                timestamptz   NOT NULL DEFAULT now(),
  CONSTRAINT chk_weddings_status         CHECK (status IN ('ACTIVE', 'ARCHIVED', 'DELETING')),
  CONSTRAINT chk_weddings_budget_pos     CHECK (target_budget > 0),
  CONSTRAINT chk_weddings_expected_month CHECK (expected_month BETWEEN 1 AND 12),
  CONSTRAINT chk_wedding_date_precision  CHECK (
    (exact_date IS NOT NULL AND expected_year IS NULL AND expected_month IS NULL)
    OR
    (exact_date IS NULL AND expected_year IS NOT NULL AND expected_month IS NOT NULL)
  )
);

CREATE TABLE public.wedding_members (
  id            uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id    uuid          NOT NULL REFERENCES public.weddings (id) ON DELETE CASCADE,
  user_id       uuid          NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
  display_name  varchar(255)  NOT NULL,
  profile_email varchar(255)  NOT NULL,
  role          varchar(50)   NOT NULL,
  status        varchar(50)   NOT NULL DEFAULT 'ACTIVE',
  created_at    timestamptz   NOT NULL DEFAULT now(),
  updated_at    timestamptz   NOT NULL DEFAULT now(),
  CONSTRAINT chk_members_role_enum   CHECK (role IN ('OWNER', 'COLLABORATOR')),
  CONSTRAINT chk_members_status_enum CHECK (status IN ('ACTIVE', 'REVOKED')),
  CONSTRAINT uq_wedding_member       UNIQUE (wedding_id, user_id),
  CONSTRAINT uq_member_wedding_key   UNIQUE (wedding_id, id)
);

CREATE TABLE public.pending_collaborator_invitations (
  id                       uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id               uuid          NOT NULL REFERENCES public.weddings (id) ON DELETE CASCADE,
  invited_email            varchar(255)  NOT NULL,
  normalized_invited_email varchar(255)  NOT NULL,
  role                     varchar(50)   NOT NULL DEFAULT 'COLLABORATOR',
  status                   varchar(50)   NOT NULL DEFAULT 'PENDING',
  created_at               timestamptz   NOT NULL DEFAULT now(),
  accepted_at              timestamptz,
  accepted_user_id         uuid          REFERENCES auth.users (id) ON DELETE SET NULL,
  CONSTRAINT chk_invitations_status_enum CHECK (status IN ('PENDING', 'ACCEPTED', 'REVOKED'))
);

CREATE UNIQUE INDEX uq_pending_collaborator
  ON public.pending_collaborator_invitations (wedding_id, normalized_invited_email)
  WHERE (status = 'PENDING');

CREATE TABLE private.trusted_operation_receipts (
  id                  uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  operation_type      varchar(100)  NOT NULL,
  actor_user_id       uuid          NOT NULL,
  request_id          uuid          NOT NULL,
  wedding_id          uuid          REFERENCES public.weddings (id) ON DELETE CASCADE,
  request_hash        varchar(64)   NOT NULL,
  result_resource_id  uuid,
  result_summary      jsonb,
  created_at          timestamptz   NOT NULL DEFAULT now(),
  CONSTRAINT uq_operation_receipt UNIQUE (operation_type, actor_user_id, request_id)
);

-- ---------------------------------------------------------------------------
-- SECTION 2: UPDATED_AT TRIGGERS
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS
$$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_weddings_updated_at
  BEFORE UPDATE ON public.weddings
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_wedding_members_updated_at
  BEFORE UPDATE ON public.wedding_members
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- SECTION 3: SECURITY HELPER FUNCTIONS
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION security.is_active_wedding_member(wedding_id_param uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS
$$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.wedding_members
    WHERE wedding_id = wedding_id_param
      AND user_id    = auth.uid()
      AND status     = 'ACTIVE'
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION security.is_active_wedding_member(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION security.is_active_wedding_member(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION security.is_wedding_owner(wedding_id_param uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS
$$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.wedding_members
    WHERE wedding_id = wedding_id_param
      AND user_id    = auth.uid()
      AND role       = 'OWNER'
      AND status     = 'ACTIVE'
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION security.is_wedding_owner(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION security.is_wedding_owner(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION security.can_mutate_wedding(wedding_id_param uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS
$$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.wedding_members m
    JOIN public.weddings w ON m.wedding_id = w.id
    WHERE m.wedding_id = wedding_id_param
      AND m.user_id    = auth.uid()
      AND m.status     = 'ACTIVE'
      AND w.status     = 'ACTIVE'
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION security.can_mutate_wedding(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION security.can_mutate_wedding(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION security.can_owner_mutate_wedding(wedding_id_param uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS
$$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.wedding_members m
    JOIN public.weddings w ON m.wedding_id = w.id
    WHERE m.wedding_id = wedding_id_param
      AND m.user_id    = auth.uid()
      AND m.role       = 'OWNER'
      AND m.status     = 'ACTIVE'
      AND w.status     = 'ACTIVE'
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION security.can_owner_mutate_wedding(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION security.can_owner_mutate_wedding(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION security.can_owner_delete_wedding(wedding_id_param uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS
$$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.wedding_members m
    JOIN public.weddings w ON m.wedding_id = w.id
    WHERE m.wedding_id = wedding_id_param
      AND m.user_id    = auth.uid()
      AND m.role       = 'OWNER'
      AND m.status     = 'ACTIVE'
      AND w.status     IN ('ACTIVE', 'DELETING')
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION security.can_owner_delete_wedding(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION security.can_owner_delete_wedding(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- SECTION 4: MEMBER DIRECTORY VIEW
-- ---------------------------------------------------------------------------

CREATE VIEW public.member_directory WITH (security_invoker = true) AS
  SELECT id, wedding_id, display_name, role, status
  FROM public.wedding_members;

-- ---------------------------------------------------------------------------
-- SECTION 5: ROW-LEVEL SECURITY
-- ---------------------------------------------------------------------------

ALTER TABLE public.weddings ENABLE ROW LEVEL SECURITY;

CREATE POLICY select_wedding_if_member
  ON public.weddings FOR SELECT TO authenticated
  USING (security.is_active_wedding_member(id));

CREATE POLICY update_wedding_if_member
  ON public.weddings FOR UPDATE TO authenticated
  USING      (security.can_mutate_wedding(id))
  WITH CHECK (security.can_mutate_wedding(id));

ALTER TABLE public.wedding_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY select_members_if_same_wedding
  ON public.wedding_members FOR SELECT TO authenticated
  USING (security.is_active_wedding_member(wedding_id));

-- pending_collaborator_invitations: RLS enabled, zero permissive policies = Class C only
ALTER TABLE public.pending_collaborator_invitations ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- SECTION 6: POSTGRES GRANTS
-- ---------------------------------------------------------------------------

-- weddings: SELECT + column-restricted UPDATE (status excluded -- trusted path only)
GRANT SELECT ON public.weddings TO authenticated;
GRANT UPDATE (
  name, target_budget, expected_year, expected_month, exact_date,
  cultural_context, rsvp_cutoff_date, timezone, cover_photo_key,
  vietqr_bank_id, vietqr_account_no, vietqr_account_name,
  vietqr_enabled, vietqr_photo_key, public_contact_phone,
  public_contact_email, updated_at
) ON public.weddings TO authenticated;

-- wedding_members: SELECT only (all mutations are Class C)
GRANT SELECT ON public.wedding_members TO authenticated;

-- member_directory view
GRANT SELECT ON public.member_directory TO authenticated;

-- trusted_function_owner: full DML on all managed tables
GRANT SELECT, INSERT, UPDATE, DELETE ON public.weddings                         TO trusted_function_owner;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.wedding_members                  TO trusted_function_owner;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pending_collaborator_invitations TO trusted_function_owner;
GRANT SELECT, INSERT, UPDATE, DELETE ON private.trusted_operation_receipts      TO trusted_function_owner;

-- ---------------------------------------------------------------------------
-- SECTION 7: api_v1.create_wedding RPC (TOP-WED-001)
-- SECURITY DEFINER owned by trusted_function_owner (BYPASSRLS).
-- Implements DURABLE_RECEIPT idempotency via private.trusted_operation_receipts.
-- Actor resolved from auth.uid() only -- never from client-supplied params.
-- Semantic SHA-256 request_hash over canonicalised business fields only
-- (request_id excluded per ERRATA-CAPI-004).
-- ---------------------------------------------------------------------------

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
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS
$$
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
  -- 1. Actor resolution: JWT only (auth.uid() is authoritative)
  v_actor_id := auth.uid();
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'UNAUTHORIZED: caller is not authenticated' USING ERRCODE = 'P0001';
  END IF;

  -- Pull display metadata snapshot from auth.users (non-authoritative for permissions)
  SELECT
    COALESCE(raw_user_meta_data->>'full_name',
             raw_user_meta_data->>'name',
             email, v_actor_id::text),
    COALESCE(email, '')
  INTO v_actor_name, v_actor_email
  FROM auth.users WHERE id = v_actor_id;

  -- 2. Semantic canonical hash (request_id excluded per ERRATA-CAPI-004 / Section F)
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

  -- 3. DURABLE_RECEIPT idempotency check
  SELECT * INTO v_existing_receipt
  FROM private.trusted_operation_receipts
  WHERE operation_type = 'TOP-WED-001'
    AND actor_user_id  = v_actor_id
    AND request_id     = p_request_id;

  IF FOUND AND v_existing_receipt.result_resource_id IS NOT NULL THEN
    -- Verify that the semantic request hash matches the stored hash
    IF v_existing_receipt.request_hash <> v_request_hash THEN
      RAISE EXCEPTION 'REQUEST_ID_REUSED: request_id has already been used for a different request'
        USING ERRCODE = '40900';
    END IF;

    -- Replay path: return live DB state, never re-insert
    SELECT * INTO v_wedding FROM public.weddings
      WHERE id = v_existing_receipt.result_resource_id;
    SELECT * INTO v_member  FROM public.wedding_members
      WHERE wedding_id = v_wedding.id AND user_id = v_actor_id;
    RETURN jsonb_build_object(
      'replayed',   true,
      'wedding',    row_to_json(v_wedding),
      'membership', row_to_json(v_member)
    );
  END IF;

  -- 4. Business invariant validation
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

  -- 5. Atomic 3-way insert: wedding + owner member + receipt
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
  ) ON CONFLICT (operation_type, actor_user_id, request_id) DO NOTHING;

  -- 6. Return newly created state
  SELECT * INTO v_wedding FROM public.weddings
    WHERE id = v_wedding_id;
  SELECT * INTO v_member  FROM public.wedding_members
    WHERE wedding_id = v_wedding_id AND user_id = v_actor_id;

  RETURN jsonb_build_object(
    'replayed',   false,
    'wedding',    row_to_json(v_wedding),
    'membership', row_to_json(v_member)
  );
END;
$$;

-- trusted_function_owner needs USAGE + CREATE on each schema where it will own
-- functions or objects. Without CREATE, ALTER FUNCTION ... OWNER TO will fail.
GRANT USAGE, CREATE ON SCHEMA api_v1    TO trusted_function_owner;
GRANT USAGE, CREATE ON SCHEMA security  TO trusted_function_owner;
GRANT USAGE, CREATE ON SCHEMA internal  TO trusted_function_owner;
GRANT USAGE, CREATE ON SCHEMA private   TO trusted_function_owner;
GRANT USAGE, CREATE ON SCHEMA public    TO trusted_function_owner;

-- Allow trusted_function_owner to resolve auth schema functions (auth.uid) by
-- inheriting authenticated role usage, and grant select on users table.
GRANT authenticated TO trusted_function_owner;
GRANT SELECT ON auth.users TO trusted_function_owner;

-- Grant trusted_function_owner to postgres so the migration user can transfer
-- function ownership. This is required in PostgreSQL 16+ even for superusers.
-- The grant is scoped to migration execution; postgres has no runtime privileges
-- from this role beyond what it already has as superuser.
GRANT trusted_function_owner TO postgres;

ALTER FUNCTION api_v1.create_wedding(
  uuid, varchar, varchar, date, integer, integer, varchar, numeric
) OWNER TO trusted_function_owner;

REVOKE EXECUTE ON FUNCTION api_v1.create_wedding(
  uuid, varchar, varchar, date, integer, integer, varchar, numeric
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION api_v1.create_wedding(
  uuid, varchar, varchar, date, integer, integer, varchar, numeric
) TO authenticated;
