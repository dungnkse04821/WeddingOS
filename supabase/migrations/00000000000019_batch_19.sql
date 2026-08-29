-- =============================================================================
-- BATCH-19: Restore the approved Class-B guest column privilege boundary
-- =============================================================================

-- Batch 04 granted table-level INSERT/UPDATE and then revoked those privileges
-- while attempting to protect the normalization columns. Rebuild the boundary
-- explicitly so PostgREST can write only the GuestModel client payload.
REVOKE INSERT, UPDATE ON public.guests FROM authenticated;

GRANT INSERT (
  wedding_id,
  invitation_party_id,
  primary_group_id,
  name,
  phone,
  email,
  side,
  guest_source
) ON public.guests TO authenticated;

GRANT UPDATE (
  wedding_id,
  invitation_party_id,
  primary_group_id,
  name,
  phone,
  email,
  side,
  guest_source
) ON public.guests TO authenticated;

-- Keep normalization and timestamps owned by database triggers/defaults.
REVOKE INSERT (
  normalized_phone,
  normalized_email,
  created_at,
  updated_at
) ON public.guests FROM authenticated, anon, public;
REVOKE UPDATE (
  normalized_phone,
  normalized_email,
  created_at,
  updated_at
) ON public.guests FROM authenticated, anon, public;

-- Guest deletion remains a trusted operation only.
REVOKE DELETE ON public.guests FROM authenticated, anon, public;
