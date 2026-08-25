-- M7-AUTH-BRIDGE-001: service-only verified actor bridge for TOP-WED-004.
CREATE OR REPLACE FUNCTION internal.begin_wedding_delete(p_wedding_id uuid, p_verified_actor_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_status varchar;
BEGIN
 SELECT w.status INTO v_status FROM public.weddings w JOIN public.wedding_members m ON m.wedding_id=w.id
 WHERE w.id=p_wedding_id AND m.user_id=p_verified_actor_user_id AND m.status='ACTIVE' AND m.role='OWNER' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'WEDDING_NOT_FOUND_OR_FORBIDDEN' USING ERRCODE='42501'; END IF;
 IF v_status IN ('ACTIVE','ARCHIVED') THEN UPDATE public.weddings SET status='DELETING' WHERE id=p_wedding_id; END IF;
 RETURN jsonb_build_object('status','DELETING','wedding_id',p_wedding_id);
END; $$;
CREATE OR REPLACE FUNCTION internal.finalize_wedding_delete(p_wedding_id uuid, p_verified_actor_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.weddings w JOIN public.wedding_members m ON m.wedding_id=w.id WHERE w.id=p_wedding_id AND w.status='DELETING' AND m.user_id=p_verified_actor_user_id AND m.status='ACTIVE' AND m.role='OWNER') THEN RAISE EXCEPTION 'WEDDING_NOT_DELETING_OR_FORBIDDEN' USING ERRCODE='42501'; END IF;
 DELETE FROM private.trusted_operation_receipts WHERE wedding_id=p_wedding_id;
 DELETE FROM public.weddings WHERE id=p_wedding_id;
 RETURN jsonb_build_object('status','DELETED');
END; $$;
CREATE OR REPLACE FUNCTION edge_api.begin_wedding_delete(p_wedding_id uuid,p_verified_actor_user_id uuid)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT internal.begin_wedding_delete(p_wedding_id,p_verified_actor_user_id) $$;
CREATE OR REPLACE FUNCTION edge_api.finalize_wedding_delete(p_wedding_id uuid,p_verified_actor_user_id uuid)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT internal.finalize_wedding_delete(p_wedding_id,p_verified_actor_user_id) $$;
REVOKE EXECUTE ON FUNCTION internal.begin_wedding_delete(uuid,uuid),internal.finalize_wedding_delete(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
REVOKE EXECUTE ON FUNCTION edge_api.begin_wedding_delete(uuid,uuid),edge_api.finalize_wedding_delete(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION edge_api.begin_wedding_delete(uuid,uuid),edge_api.finalize_wedding_delete(uuid,uuid) TO service_role;
ALTER FUNCTION internal.begin_wedding_delete(uuid,uuid) OWNER TO trusted_function_owner;
ALTER FUNCTION internal.finalize_wedding_delete(uuid,uuid) OWNER TO trusted_function_owner;
ALTER FUNCTION edge_api.begin_wedding_delete(uuid,uuid) OWNER TO trusted_function_owner;
ALTER FUNCTION edge_api.finalize_wedding_delete(uuid,uuid) OWNER TO trusted_function_owner;
