-- M6: private, deterministic Wedding cover storage.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('wedding_media', 'wedding_media', false, 5242880, ARRAY['image/webp'])
ON CONFLICT (id) DO UPDATE SET public = false, file_size_limit = 5242880, allowed_mime_types = ARRAY['image/webp'];

CREATE OR REPLACE FUNCTION security.is_wedding_cover_path(p_name text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT array_length(storage.foldername(p_name), 1) = 2
    AND (storage.foldername(p_name))[1] = 'weddings'
    AND (storage.foldername(p_name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    AND storage.filename(p_name) = 'cover.webp';
$$;
REVOKE EXECUTE ON FUNCTION security.is_wedding_cover_path(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION security.is_wedding_cover_path(text) TO authenticated;

CREATE POLICY "m6 members read wedding cover" ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'wedding_media' AND security.is_wedding_cover_path(name)
  AND security.is_active_wedding_member((storage.foldername(name))[2]::uuid));
CREATE POLICY "m6 members insert wedding cover" ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'wedding_media' AND security.is_wedding_cover_path(name)
  AND security.can_mutate_wedding((storage.foldername(name))[2]::uuid));
CREATE POLICY "m6 members update wedding cover" ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'wedding_media' AND security.is_wedding_cover_path(name)
  AND security.can_mutate_wedding((storage.foldername(name))[2]::uuid))
WITH CHECK (bucket_id = 'wedding_media' AND security.is_wedding_cover_path(name)
  AND security.can_mutate_wedding((storage.foldername(name))[2]::uuid));

-- Do not grant or define organizer DELETE policy; M7 owns cleanup.
ALTER FUNCTION internal.resolve_public_invitation(text, varchar, integer)
  RENAME TO resolve_public_invitation_m6_base;
CREATE FUNCTION internal.resolve_public_invitation(p_raw_token text, p_limiter_key varchar(128) DEFAULT NULL, p_rate_limit_threshold integer DEFAULT 30)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_result jsonb; v_cover text;
BEGIN
  v_result := internal.resolve_public_invitation_m6_base(p_raw_token, p_limiter_key, p_rate_limit_threshold);
  IF COALESCE((v_result ->> 'ok')::boolean, false) = false THEN RETURN v_result; END IF;
  SELECT CASE WHEN EXISTS (
    SELECT 1 FROM storage.objects o
    WHERE o.bucket_id = 'wedding_media'
      AND o.name = 'weddings/' || w.id::text || '/cover.webp'
  ) THEN 'weddings/' || w.id::text || '/cover.webp' END INTO v_cover
  FROM public.invitation_credentials c
  JOIN public.invitations i ON i.id=c.invitation_id JOIN public.weddings w ON w.id=i.wedding_id
  WHERE c.token_hash=extensions.digest(p_raw_token,'sha256') AND c.is_active AND c.revoked_at IS NULL;
  -- jsonb_set returns SQL NULL when its new value is SQL NULL. Preserve the
  -- successful resolver DTO and represent a missing optional cover as JSON null.
  RETURN jsonb_set(v_result, '{cover_photo_key}', COALESCE(to_jsonb(v_cover), 'null'::jsonb), true);
END; $$;
REVOKE EXECUTE ON FUNCTION internal.resolve_public_invitation(text, varchar, integer) FROM PUBLIC, anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION internal.resolve_public_invitation_m6_base(text, varchar, integer) FROM PUBLIC, anon, authenticated, service_role;
ALTER FUNCTION internal.resolve_public_invitation(text, varchar, integer) OWNER TO trusted_function_owner;
ALTER FUNCTION internal.resolve_public_invitation_m6_base(text, varchar, integer) OWNER TO trusted_function_owner;
