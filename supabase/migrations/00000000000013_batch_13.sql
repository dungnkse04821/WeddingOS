-- M7.1: Wedding lifecycle authority. Storage orchestration is deliberately deferred.
CREATE OR REPLACE FUNCTION api_v1.archive_wedding(p_wedding_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_status varchar;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'UNAUTHENTICATED' USING ERRCODE='42501'; END IF;
  SELECT w.status INTO v_status FROM public.weddings w
  JOIN public.wedding_members m ON m.wedding_id=w.id
  WHERE w.id=p_wedding_id AND m.user_id=auth.uid() AND m.status='ACTIVE' AND m.role='OWNER' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'WEDDING_NOT_FOUND_OR_FORBIDDEN' USING ERRCODE='42501'; END IF;
  IF v_status='ARCHIVED' THEN RETURN jsonb_build_object('status','ARCHIVED','replayed',true); END IF;
  IF v_status<>'ACTIVE' THEN RAISE EXCEPTION 'INVALID_WEDDING_LIFECYCLE' USING ERRCODE='40900'; END IF;
  UPDATE public.weddings SET status='ARCHIVED' WHERE id=p_wedding_id;
  RETURN jsonb_build_object('status','ARCHIVED','replayed',false);
END; $$;
REVOKE EXECUTE ON FUNCTION api_v1.archive_wedding(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION api_v1.archive_wedding(uuid) TO authenticated;
ALTER FUNCTION api_v1.archive_wedding(uuid) OWNER TO trusted_function_owner;

CREATE OR REPLACE FUNCTION internal.begin_wedding_delete(p_wedding_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_status varchar;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'UNAUTHENTICATED' USING ERRCODE='42501'; END IF;
  SELECT w.status INTO v_status FROM public.weddings w JOIN public.wedding_members m ON m.wedding_id=w.id
  WHERE w.id=p_wedding_id AND m.user_id=auth.uid() AND m.status='ACTIVE' AND m.role='OWNER' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'WEDDING_NOT_FOUND_OR_FORBIDDEN' USING ERRCODE='42501'; END IF;
  IF v_status IN ('ACTIVE','ARCHIVED') THEN UPDATE public.weddings SET status='DELETING' WHERE id=p_wedding_id; END IF;
  RETURN jsonb_build_object('status','DELETING','wedding_id',p_wedding_id);
END; $$;
REVOKE EXECUTE ON FUNCTION internal.begin_wedding_delete(uuid) FROM PUBLIC, anon, authenticated, service_role;
ALTER FUNCTION internal.begin_wedding_delete(uuid) OWNER TO trusted_function_owner;

CREATE OR REPLACE FUNCTION internal.finalize_wedding_delete(p_wedding_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'UNAUTHENTICATED' USING ERRCODE='42501'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.weddings w JOIN public.wedding_members m ON m.wedding_id=w.id WHERE w.id=p_wedding_id AND w.status='DELETING' AND m.user_id=auth.uid() AND m.status='ACTIVE' AND m.role='OWNER') THEN RAISE EXCEPTION 'WEDDING_NOT_DELETING_OR_FORBIDDEN' USING ERRCODE='42501'; END IF;
  DELETE FROM private.trusted_operation_receipts WHERE wedding_id=p_wedding_id;
  DELETE FROM public.weddings WHERE id=p_wedding_id;
  RETURN jsonb_build_object('status','DELETED');
END; $$;
REVOKE EXECUTE ON FUNCTION internal.finalize_wedding_delete(uuid) FROM PUBLIC, anon, authenticated, service_role;
ALTER FUNCTION internal.finalize_wedding_delete(uuid) OWNER TO trusted_function_owner;
