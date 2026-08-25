-- M7.2B2: preserve generic terminal success for an authenticated retry after
-- physical deletion. The bridge remains service-only and forbidden actors stay denied.
CREATE OR REPLACE FUNCTION internal.begin_wedding_delete(p_wedding_id uuid, p_verified_actor_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_status varchar;
BEGIN
 SELECT w.status INTO v_status FROM public.weddings w WHERE w.id=p_wedding_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','DELETED'); END IF;
 IF NOT EXISTS (
   SELECT 1 FROM public.wedding_members m
   WHERE m.wedding_id=p_wedding_id AND m.user_id=p_verified_actor_user_id
     AND m.status='ACTIVE' AND m.role='OWNER'
 ) THEN
   RAISE EXCEPTION 'WEDDING_NOT_FOUND_OR_FORBIDDEN' USING ERRCODE='42501';
 END IF;
 IF v_status IN ('ACTIVE','ARCHIVED') THEN
   UPDATE public.weddings SET status='DELETING' WHERE id=p_wedding_id;
 END IF;
 RETURN jsonb_build_object('status','DELETING','wedding_id',p_wedding_id);
END; $$;
REVOKE EXECUTE ON FUNCTION internal.begin_wedding_delete(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
ALTER FUNCTION internal.begin_wedding_delete(uuid,uuid) OWNER TO trusted_function_owner;
