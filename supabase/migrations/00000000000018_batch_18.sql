-- M8.3: all SECURITY DEFINER security helpers use the established trusted owner.
ALTER FUNCTION security.can_mutate_wedding(uuid) OWNER TO trusted_function_owner;
ALTER FUNCTION security.can_owner_delete_wedding(uuid) OWNER TO trusted_function_owner;
ALTER FUNCTION security.can_owner_mutate_wedding(uuid) OWNER TO trusted_function_owner;
ALTER FUNCTION security.is_wedding_cover_path(text) OWNER TO trusted_function_owner;
