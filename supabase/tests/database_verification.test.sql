BEGIN;
SELECT plan(31);

-- =============================================================================
-- TEST SETUP
-- =============================================================================

-- Create mock users in auth.users for testing
INSERT INTO auth.users (id, email, raw_user_meta_data)
VALUES 
  ('aaaaaaa1-1111-1111-1111-111111111111', 'user.a@example.com', '{"full_name": "User A"}'),
  ('bbbbbbb2-2222-2222-2222-222222222222', 'user.b@example.com', '{"full_name": "User B"}');

-- =============================================================================
-- PART 1: FUNCTION & SCHEMA AUTHORIZATION (GRANTS)
-- =============================================================================

-- 1. authenticated can EXECUTE api_v1.create_wedding
SELECT ok(
  has_function_privilege('authenticated', 'api_v1.create_wedding(uuid, varchar, varchar, date, integer, integer, varchar, numeric)', 'EXECUTE'),
  'authenticated has EXECUTE on api_v1.create_wedding'
);

-- 2. anon cannot EXECUTE it
SELECT ok(
  NOT has_function_privilege('anon', 'api_v1.create_wedding(uuid, varchar, varchar, date, integer, integer, varchar, numeric)', 'EXECUTE'),
  'anon has no EXECUTE on api_v1.create_wedding'
);

-- 3. PUBLIC has no unintended EXECUTE
SELECT ok(
  NOT has_function_privilege('public', 'api_v1.create_wedding(uuid, varchar, varchar, date, integer, integer, varchar, numeric)', 'EXECUTE'),
  'PUBLIC has no EXECUTE on api_v1.create_wedding'
);

-- 4. security/internal/private are not directly client-accessible (no USAGE)
SELECT ok(NOT has_schema_privilege('authenticated', 'security', 'USAGE'), 'authenticated has no USAGE on security schema');
SELECT ok(NOT has_schema_privilege('authenticated', 'internal', 'USAGE'), 'authenticated has no USAGE on internal schema');
SELECT ok(NOT has_schema_privilege('authenticated', 'private', 'USAGE'), 'authenticated has no USAGE on private schema');

SELECT ok(NOT has_schema_privilege('anon', 'security', 'USAGE'), 'anon has no USAGE on security schema');
SELECT ok(NOT has_schema_privilege('anon', 'internal', 'USAGE'), 'anon has no USAGE on internal schema');
SELECT ok(NOT has_schema_privilege('anon', 'private', 'USAGE'), 'anon has no USAGE on private schema');

-- 5. trusted_function_owner privileges are not inherited by authenticated or anon
SELECT ok(NOT pg_has_role('authenticated', 'trusted_function_owner', 'MEMBER'), 'authenticated does not inherit trusted_function_owner');
SELECT ok(NOT pg_has_role('anon', 'trusted_function_owner', 'MEMBER'), 'anon does not inherit trusted_function_owner');

-- =============================================================================
-- PART 2: ATOMICITY OF create_wedding
-- =============================================================================

-- Set authenticated User A context
SELECT set_config('request.jwt.claims', '{"sub": "aaaaaaa1-1111-1111-1111-111111111111", "email": "user.a@example.com"}', true);
SET ROLE authenticated;

-- Call create_wedding first time
SELECT api_v1.create_wedding(
  'c0a1a1a1-1111-1111-1111-111111111111',
  'Wedding A',
  'TUY_CHON',
  '2027-06-15'::date,
  NULL,
  NULL,
  'Asia/Ho_Chi_Minh',
  100000000.00
);

RESET ROLE;

-- Verify database state for atomicity (req 8)
SELECT is(COUNT(*)::integer, 1, 'Exactly one Wedding created') FROM public.weddings;
SELECT is(COUNT(*)::integer, 1, 'Exactly one Member created') FROM public.wedding_members;
SELECT is(COUNT(*)::integer, 1, 'Exactly one Receipt created') FROM private.trusted_operation_receipts;

-- =============================================================================
-- PART 3: TENANT ISOLATION (RLS)
-- =============================================================================

-- Set role to authenticated User A
SELECT set_config('request.jwt.claims', '{"sub": "aaaaaaa1-1111-1111-1111-111111111111"}', true);
SET ROLE authenticated;
SELECT is(COUNT(*)::integer, 1, 'User A can read Wedding A via RLS') FROM public.weddings;
SELECT is(COUNT(*)::integer, 1, 'User A can read own membership') FROM public.wedding_members;

-- Set role to authenticated User B
SELECT set_config('request.jwt.claims', '{"sub": "bbbbbbb2-2222-2222-2222-222222222222"}', true);
SET ROLE authenticated;
SELECT is(COUNT(*)::integer, 0, 'User B cannot read Wedding A') FROM public.weddings;
SELECT is(COUNT(*)::integer, 0, 'User B cannot read User A''s membership') FROM public.wedding_members;

-- Set role to anon
SELECT set_config('request.jwt.claims', '{}', true);
SET ROLE anon;
SELECT throws_ok(
  'SELECT * FROM public.weddings',
  '42501', -- permission denied
  NULL,
  'anonymous cannot read weddings due to no SELECT grant'
);

-- =============================================================================
-- PART 4: IDEMPOTENCY (DURABLE_RECEIPT)
-- =============================================================================

-- Set context back to User A
SELECT set_config('request.jwt.claims', '{"sub": "aaaaaaa1-1111-1111-1111-111111111111", "email": "user.a@example.com"}', true);
SET ROLE authenticated;

-- same request_id + semantically equivalent request: no duplicates, returns current result
SELECT ok(
  (api_v1.create_wedding(
    'c0a1a1a1-1111-1111-1111-111111111111',
    'Wedding A',
    'TUY_CHON',
    '2027-06-15'::date,
    NULL,
    NULL,
    'Asia/Ho_Chi_Minh',
    100000000.00
  ) ->> 'replayed')::boolean,
  'Replay returns replayed: true'
);

RESET ROLE;
SELECT is(COUNT(*)::integer, 1, 'No duplicate Wedding created on replay') FROM public.weddings;
SELECT is(COUNT(*)::integer, 1, 'No duplicate Member created on replay') FROM public.wedding_members;
SELECT is(COUNT(*)::integer, 1, 'No duplicate Receipt created on replay') FROM private.trusted_operation_receipts;

-- same request_id + materially different semantic request: throws REQUEST_ID_REUSED (req 10)
SELECT set_config('request.jwt.claims', '{"sub": "aaaaaaa1-1111-1111-1111-111111111111", "email": "user.a@example.com"}', true);
SET ROLE authenticated;

SELECT throws_ok(
  $$
  SELECT api_v1.create_wedding(
    'c0a1a1a1-1111-1111-1111-111111111111',
    'Wedding B', -- different name payload
    'TUY_CHON',
    '2027-06-15'::date,
    NULL,
    NULL,
    'Asia/Ho_Chi_Minh',
    100000000.00
  )
  $$,
  '40900', -- SQLSTATE
  'REQUEST_ID_REUSED: request_id has already been used for a different request',
  'Reusing request_id with different payload throws REQUEST_ID_REUSED'
);

-- new request_id: treated as a new logical attempt (req 11)
SELECT lives_ok(
  $$
  SELECT api_v1.create_wedding(
    'c0a2a2a2-2222-2222-2222-222222222222', -- new request_id
    'Wedding A2',
    'TUY_CHON',
    '2027-07-20'::date,
    NULL,
    NULL,
    'Asia/Ho_Chi_Minh',
    150000000.00
  )
  $$,
  'New request_id successfully creates a new wedding'
);

RESET ROLE;
SELECT is(COUNT(*)::integer, 2, 'Two weddings exist after new request_id attempt') FROM public.weddings;

-- =============================================================================
-- PART 5: SECURITY RESILIENCE (RECEIPTS & SPOOFING & UPDATE COLUMNS)
-- =============================================================================

-- 12. authenticated client cannot directly read/write private.trusted_operation_receipts
SELECT set_config('request.jwt.claims', '{"sub": "aaaaaaa1-1111-1111-1111-111111111111"}', true);
SET ROLE authenticated;

SELECT throws_ok(
  'SELECT * FROM private.trusted_operation_receipts',
  '42501', -- permission denied
  NULL,
  'authenticated client cannot read trusted_operation_receipts'
);
SELECT throws_ok(
  'INSERT INTO private.trusted_operation_receipts (operation_type, actor_user_id, request_id, request_hash) VALUES (''TOP-WED-001'', ''aaaaaaa1-1111-1111-1111-111111111111'', ''00000000-0000-0000-0000-000000000000'', ''abc'')',
  '42501',
  NULL,
  'authenticated client cannot write trusted_operation_receipts'
);

-- 13. client cannot spoof actor identity (fails when auth.uid() is null)
SELECT set_config('request.jwt.claims', '{}', true);
SET ROLE authenticated;

SELECT throws_ok(
  $$
  SELECT api_v1.create_wedding(
    'c0a3a3a3-3333-3333-3333-333333333333',
    'Wedding X',
    'TUY_CHON',
    '2027-08-01'::date,
    NULL,
    NULL,
    'Asia/Ho_Chi_Minh',
    200000000.00
  )
  $$,
  'P0001', -- unauthorized
  'UNAUTHORIZED: caller is not authenticated',
  'Throws UNAUTHORIZED if auth.uid() is null'
);

-- 14. direct Wedding UPDATE policies cannot bypass approved role/lifecycle/protected-field rules
SELECT set_config('request.jwt.claims', '{"sub": "aaaaaaa1-1111-1111-1111-111111111111"}', true);
SET ROLE authenticated;

-- Try updating allowed fields (name)
SELECT lives_ok(
  $$
  UPDATE public.weddings SET name = 'New Wedding Name' WHERE name = 'Wedding A'
  $$,
  'authenticated User A can update wedding name'
);

-- Try updating status column (protected column)
SELECT throws_ok(
  $$
  UPDATE public.weddings SET status = 'ARCHIVED' WHERE name = 'New Wedding Name'
  $$,
  '42501', -- permission denied
  NULL,
  'authenticated client cannot update status column directly due to column-level grants'
);

-- Finish test transaction
SELECT * FROM finish();
ROLLBACK;
