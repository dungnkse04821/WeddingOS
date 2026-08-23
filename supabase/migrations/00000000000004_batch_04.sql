-- =============================================================================
-- BATCH-04: M2B.1 Guest / PrimaryGroup / InvitationParty Foundation
-- =============================================================================

-- ---------------------------------------------------------------------------
-- SECTION 1: BUSINESS TABLES
-- ---------------------------------------------------------------------------

-- Table 10: Relationship groups
CREATE TABLE public.primary_groups (
  id          uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id  uuid          NOT NULL REFERENCES public.weddings (id) ON DELETE CASCADE,
  name        varchar(100)  NOT NULL,
  created_at  timestamptz   NOT NULL DEFAULT now(),
  CONSTRAINT uq_primary_groups_wedding_key UNIQUE (wedding_id, id)
);

-- Table 11: Invitation parties / Households
CREATE TABLE public.invitation_parties (
  id            uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id    uuid          NOT NULL REFERENCES public.weddings (id) ON DELETE CASCADE,
  display_name  varchar(255)  NOT NULL,
  invited_count integer       NOT NULL DEFAULT 1,
  created_at    timestamptz   NOT NULL DEFAULT now(),
  updated_at    timestamptz   NOT NULL DEFAULT now(),
  CONSTRAINT chk_parties_invited_count CHECK (invited_count > 0),
  CONSTRAINT uq_parties_wedding_key UNIQUE (wedding_id, id)
);

-- Table 12: Individual guests
CREATE TABLE public.guests (
  id                  uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id          uuid          NOT NULL REFERENCES public.weddings (id) ON DELETE CASCADE,
  invitation_party_id uuid,
  primary_group_id    uuid,
  name                varchar(255)  NOT NULL,
  phone               varchar(50),
  normalized_phone    varchar(50),
  email               varchar(255),
  normalized_email    varchar(255),
  side                varchar(50)   NOT NULL DEFAULT 'COMMON',
  guest_source        varchar(50)   NOT NULL DEFAULT 'OTHER',
  created_at          timestamptz   NOT NULL DEFAULT now(),
  updated_at          timestamptz   NOT NULL DEFAULT now(),
  CONSTRAINT chk_guests_side CHECK (side IN ('COMMON', 'BRIDE_SIDE', 'GROOM_SIDE')),
  CONSTRAINT chk_guests_source CHECK (guest_source IN ('BRIDE', 'GROOM', 'BRIDE_PARENTS', 'GROOM_PARENTS', 'OTHER')),
  -- Composite foreign keys enforcing same-wedding integrity
  CONSTRAINT fk_guests_party_wedding FOREIGN KEY (wedding_id, invitation_party_id) 
    REFERENCES public.invitation_parties (wedding_id, id) ON DELETE RESTRICT,
  CONSTRAINT fk_guests_group_wedding FOREIGN KEY (wedding_id, primary_group_id) 
    REFERENCES public.primary_groups (wedding_id, id) ON DELETE RESTRICT
);

-- ---------------------------------------------------------------------------
-- SECTION 2: TRIGGERS
-- ---------------------------------------------------------------------------

-- updated_at triggers
CREATE TRIGGER trg_invitation_parties_updated_at
  BEFORE UPDATE ON public.invitation_parties
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_guests_updated_at
  BEFORE UPDATE ON public.guests
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Phone/email normalization trigger
CREATE OR REPLACE FUNCTION public.fn_normalize_guest_contacts()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  -- Normalize email: trim and lowercase
  IF NEW.email IS NOT NULL THEN
    NEW.normalized_email := LOWER(TRIM(NEW.email));
  ELSE
    NEW.normalized_email := NULL;
  END IF;

  -- Normalize phone: keep digits only, replace +84 or 84 at start with 0
  IF NEW.phone IS NOT NULL THEN
    DECLARE
      v_cleaned text;
    BEGIN
      -- Remove all non-digits
      v_cleaned := regexp_replace(NEW.phone, '\D', '', 'g');
      -- If it starts with 84, replace with 0
      IF v_cleaned LIKE '84%' THEN
        v_cleaned := '0' || substr(v_cleaned, 3);
      END IF;
      NEW.normalized_phone := v_cleaned;
    END;
  ELSE
    NEW.normalized_phone := NULL;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_guests_normalize_contacts
  BEFORE INSERT OR UPDATE ON public.guests
  FOR EACH ROW EXECUTE FUNCTION public.fn_normalize_guest_contacts();

-- Trigger to prevent direct party-to-party transitions and unassignments
CREATE OR REPLACE FUNCTION public.fn_enforce_guest_party_transition()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF OLD.invitation_party_id IS NOT NULL AND OLD.invitation_party_id IS DISTINCT FROM NEW.invitation_party_id THEN
    RAISE EXCEPTION 'Direct unassignment or transition from an existing invitation party is blocked. Must use trusted operations.'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_guests_party_transition
  BEFORE UPDATE OF invitation_party_id ON public.guests
  FOR EACH ROW EXECUTE FUNCTION public.fn_enforce_guest_party_transition();

-- ---------------------------------------------------------------------------
-- SECTION 3: ROW LEVEL SECURITY & GRANTS
-- ---------------------------------------------------------------------------

-- Enable RLS
ALTER TABLE public.primary_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invitation_parties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guests ENABLE ROW LEVEL SECURITY;

-- Grants (M2B.1 client mutation boundary: SELECT, INSERT, UPDATE only. No DELETE grant.)
GRANT SELECT, INSERT, UPDATE ON public.primary_groups TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.invitation_parties TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.guests TO authenticated;

-- Revoke write access to normalized columns from clients
REVOKE INSERT, UPDATE (normalized_phone, normalized_email) ON public.guests FROM authenticated, anon, public;

-- RLS Policies (SELECT, INSERT, UPDATE only. No DELETE policy.)
CREATE POLICY select_groups_if_member ON public.primary_groups
  FOR SELECT TO authenticated USING (security.is_active_wedding_member(wedding_id));

CREATE POLICY insert_group_if_member ON public.primary_groups
  FOR INSERT TO authenticated WITH CHECK (security.can_mutate_wedding(wedding_id));

CREATE POLICY update_group_if_member ON public.primary_groups
  FOR UPDATE TO authenticated USING (security.can_mutate_wedding(wedding_id)) WITH CHECK (security.can_mutate_wedding(wedding_id));


CREATE POLICY select_parties_if_member ON public.invitation_parties
  FOR SELECT TO authenticated USING (security.is_active_wedding_member(wedding_id));

CREATE POLICY insert_party_if_member ON public.invitation_parties
  FOR INSERT TO authenticated WITH CHECK (security.can_mutate_wedding(wedding_id));

CREATE POLICY update_party_if_member ON public.invitation_parties
  FOR UPDATE TO authenticated USING (security.can_mutate_wedding(wedding_id)) WITH CHECK (security.can_mutate_wedding(wedding_id));


CREATE POLICY select_guests_if_member ON public.guests
  FOR SELECT TO authenticated USING (security.is_active_wedding_member(wedding_id));

CREATE POLICY insert_guest_if_member ON public.guests
  FOR INSERT TO authenticated WITH CHECK (security.can_mutate_wedding(wedding_id));

CREATE POLICY update_guest_if_member ON public.guests
  FOR UPDATE TO authenticated USING (security.can_mutate_wedding(wedding_id)) WITH CHECK (security.can_mutate_wedding(wedding_id));
