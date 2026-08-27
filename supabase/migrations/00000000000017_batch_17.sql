-- =============================================================================
-- BATCH-17: M8.1C Public map URL validation and function grant hygiene
-- =============================================================================

-- Existing rows are validated by this constraint. Blank values remain optional;
-- non-blank values must be absolute HTTPS URLs with a non-empty authority.
ALTER TABLE public.wedding_events
  ADD CONSTRAINT chk_wedding_events_map_link_https
  CHECK (
    map_link IS NULL
    OR btrim(map_link) = ''
    OR btrim(map_link) ~* '^https://[^[:space:]/?#]+([/?#][^[:space:]]*)?$'
  );

-- Trigger invocation does not require client EXECUTE. Keep these definer
-- functions owned by the NOLOGIN trusted role and unavailable as RPC surfaces.
ALTER FUNCTION public.fn_invitation_targeting_guard() OWNER TO trusted_function_owner;
ALTER FUNCTION public.fn_invitation_targeting_guard() SET search_path = '';
REVOKE EXECUTE ON FUNCTION public.fn_invitation_targeting_guard()
  FROM PUBLIC, anon, authenticated, service_role;

ALTER FUNCTION public.fn_normalize_guest_contacts() OWNER TO trusted_function_owner;
ALTER FUNCTION public.fn_normalize_guest_contacts() SET search_path = '';
REVOKE EXECUTE ON FUNCTION public.fn_normalize_guest_contacts()
  FROM PUBLIC, anon, authenticated, service_role;

-- The trusted Finance RPC owner invokes this helper directly. No Data API or
-- service-role caller needs independent EXECUTE authority.
ALTER FUNCTION internal.recompute_installment_status(uuid) SET search_path = '';
REVOKE EXECUTE ON FUNCTION internal.recompute_installment_status(uuid)
  FROM PUBLIC, anon, authenticated, service_role;
