BEGIN;
SELECT plan(9);

SELECT results_eq(
  $$ SELECT c.relname
     FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public' AND c.relkind = 'r'
     ORDER BY c.relname $$,
  $$ VALUES ('budget_items'::name), ('event_responses'::name), ('guests'::name), ('installments'::name),
            ('invitation_credentials'::name), ('invitation_event_targetings'::name),
            ('invitation_parties'::name), ('invitations'::name), ('payments'::name),
            ('pending_collaborator_invitations'::name), ('primary_groups'::name), ('refunds'::name),
            ('rsvps'::name), ('tasks'::name), ('wedding_events'::name), ('wedding_members'::name), ('weddings'::name) $$,
  'Catalog surface: public business-table names match the approved inventory.'
);

SELECT ok(NOT EXISTS (
  SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind = 'r' AND NOT c.relrowsecurity
), 'Catalog security: every public business table has RLS enabled.');

SELECT ok(NOT EXISTS (
  SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind = 'r'
    AND has_table_privilege('anon', c.oid, 'SELECT,INSERT,UPDATE,DELETE')
), 'Catalog security: anon has no direct public business-table CUD/read grant.');

SELECT ok(
  has_schema_privilege('authenticated', 'api_v1', 'USAGE')
  AND NOT has_schema_privilege('anon', 'api_v1', 'USAGE')
  AND has_schema_privilege('service_role', 'edge_api', 'USAGE')
  AND NOT has_schema_privilege('authenticated', 'edge_api', 'USAGE')
  AND NOT has_schema_privilege('anon', 'edge_api', 'USAGE')
  AND NOT has_schema_privilege('service_role', 'internal', 'USAGE'),
  'Catalog security: API schemas retain authenticated, service-only, and hidden boundaries.'
);

SELECT ok(NOT EXISTS (
  SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname IN ('api_v1', 'edge_api', 'internal', 'security')
    AND p.prosecdef
    AND (pg_get_userbyid(p.proowner) <> 'trusted_function_owner'
      OR coalesce(array_to_string(p.proconfig, ','), '') <> 'search_path=""')
), 'Catalog security: every scoped SECURITY DEFINER function has trusted owner and empty search_path.');

SELECT ok(NOT EXISTS (
  SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'api_v1'
    AND (NOT has_function_privilege('authenticated', p.oid, 'EXECUTE')
      OR has_function_privilege('anon', p.oid, 'EXECUTE')
      OR has_function_privilege('service_role', p.oid, 'EXECUTE'))
), 'Callable surface: api_v1 functions are authenticated-only.');

SELECT ok(NOT EXISTS (
  SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'edge_api'
    AND (NOT has_function_privilege('service_role', p.oid, 'EXECUTE')
      OR has_function_privilege('anon', p.oid, 'EXECUTE')
      OR has_function_privilege('authenticated', p.oid, 'EXECUTE'))
), 'Callable surface: edge_api functions are service-role-only.');

SELECT ok(NOT EXISTS (
  SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'internal'
    AND (has_function_privilege('anon', p.oid, 'EXECUTE')
      OR has_function_privilege('authenticated', p.oid, 'EXECUTE')
      OR has_function_privilege('service_role', p.oid, 'EXECUTE'))
), 'Callable surface: internal functions are not client or bridge callable.');

SELECT ok(NOT EXISTS (
  SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'security'
    AND (has_function_privilege('anon', p.oid, 'EXECUTE')
      OR has_function_privilege('service_role', p.oid, 'EXECUTE'))
), 'Callable surface: security helpers are hidden from anon and service-role callers.');

SELECT * FROM finish();
ROLLBACK;
