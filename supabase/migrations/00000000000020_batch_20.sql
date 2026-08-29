-- =============================================================================
-- BATCH-20: Full-graph Wedding delete finalization
-- =============================================================================

-- Permanent Wedding deletion is a trusted lifecycle operation. Same-Wedding
-- RESTRICT constraints continue to protect ordinary mutations, so finalization
-- removes each Wedding-owned dependency before deleting the root.
CREATE OR REPLACE FUNCTION internal.finalize_wedding_delete(
  p_wedding_id uuid,
  p_verified_actor_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM 1
  FROM public.weddings w
  JOIN public.wedding_members m ON m.wedding_id = w.id
  WHERE w.id = p_wedding_id
    AND w.status = 'DELETING'
    AND m.user_id = p_verified_actor_user_id
    AND m.status = 'ACTIVE'
    AND m.role = 'OWNER'
  FOR UPDATE OF w;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'WEDDING_NOT_DELETING_OR_FORBIDDEN' USING ERRCODE = '42501';
  END IF;

  -- RSVP/event response and Invitation leaves must go before their Event and
  -- Invitation parents, whose same-Wedding integrity FKs intentionally RESTRICT.
  DELETE FROM public.event_responses er
  USING public.rsvps r, public.invitations i
  WHERE er.rsvp_id = r.id
    AND r.invitation_id = i.id
    AND i.wedding_id = p_wedding_id;

  DELETE FROM public.rsvps r
  USING public.invitations i
  WHERE r.invitation_id = i.id
    AND i.wedding_id = p_wedding_id;

  DELETE FROM public.invitation_credentials c
  USING public.invitations i
  WHERE c.invitation_id = i.id
    AND i.wedding_id = p_wedding_id;

  DELETE FROM public.invitation_event_targetings
  WHERE wedding_id = p_wedding_id;

  DELETE FROM public.invitations
  WHERE wedding_id = p_wedding_id;

  DELETE FROM public.guests
  WHERE wedding_id = p_wedding_id;

  -- Finance history guards allow this SECURITY DEFINER owner to purge the
  -- destructive lifecycle graph, after RESTRICTing payment/refund leaves.
  DELETE FROM public.payments p
  USING public.budget_items b
  WHERE p.budget_item_id = b.id
    AND b.wedding_id = p_wedding_id;

  DELETE FROM public.refunds r
  USING public.budget_items b
  WHERE r.budget_item_id = b.id
    AND b.wedding_id = p_wedding_id;

  DELETE FROM public.installments i
  USING public.budget_items b
  WHERE i.budget_item_id = b.id
    AND b.wedding_id = p_wedding_id;

  DELETE FROM public.budget_items
  WHERE wedding_id = p_wedding_id;

  DELETE FROM public.tasks
  WHERE wedding_id = p_wedding_id;

  DELETE FROM public.invitation_parties
  WHERE wedding_id = p_wedding_id;

  DELETE FROM public.primary_groups
  WHERE wedding_id = p_wedding_id;

  DELETE FROM public.wedding_events
  WHERE wedding_id = p_wedding_id;

  DELETE FROM public.pending_collaborator_invitations
  WHERE wedding_id = p_wedding_id;

  DELETE FROM private.trusted_operation_receipts
  WHERE wedding_id = p_wedding_id;

  DELETE FROM public.wedding_members
  WHERE wedding_id = p_wedding_id;

  DELETE FROM public.weddings
  WHERE id = p_wedding_id;

  RETURN jsonb_build_object('status', 'DELETED');
END;
$$;

REVOKE EXECUTE ON FUNCTION internal.finalize_wedding_delete(uuid, uuid)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION edge_api.finalize_wedding_delete(uuid, uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION edge_api.finalize_wedding_delete(uuid, uuid)
  TO service_role;
ALTER FUNCTION internal.finalize_wedding_delete(uuid, uuid)
  OWNER TO trusted_function_owner;
ALTER FUNCTION edge_api.finalize_wedding_delete(uuid, uuid)
  OWNER TO trusted_function_owner;
