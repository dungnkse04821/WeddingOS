BEGIN;
SELECT plan(23); -- 23 assertions for BATCH-04 (Guest Foundation & Transition Limits)

-- ===========================================================================
-- TEST SETUP
-- ===========================================================================

-- 1. Create test users
INSERT INTO auth.users (id, email)
VALUES ('11111111-1111-1111-1111-111111111111', 'user.a@example.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO auth.users (id, email)
VALUES ('22222222-2222-2222-2222-222222222222', 'user.b@example.com')
ON CONFLICT (id) DO NOTHING;

-- 2. Create test wedding A & B
INSERT INTO public.weddings (id, name, target_budget, cultural_context, exact_date)
VALUES 
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Wedding A', 500000000, 'TUY_CHON', '2026-12-18'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Wedding B', 600000000, 'TUY_CHON', '2026-12-25')
ON CONFLICT (id) DO NOTHING;

-- 3. Create active member A in Wedding A (OWNER)
INSERT INTO public.wedding_members (id, wedding_id, user_id, role, status, display_name, profile_email)
VALUES (
  '88888888-8888-8888-8888-888888888888',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '11111111-1111-1111-1111-111111111111',
  'OWNER',
  'ACTIVE',
  'USER A',
  'user.a@example.com'
) ON CONFLICT (id) DO NOTHING;

-- 4. Create active member B in Wedding B (OWNER)
INSERT INTO public.wedding_members (id, wedding_id, user_id, role, status, display_name, profile_email)
VALUES (
  '99999999-9999-9999-9999-999999999999',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  '22222222-2222-2222-2222-222222222222',
  'OWNER',
  'ACTIVE',
  'USER B',
  'user.b@example.com'
) ON CONFLICT (id) DO NOTHING;

-- ===========================================================================
-- SECTION 1: COLUMN CONTROLS & LIFECYCLE AUDITS
-- ===========================================================================

-- 1. Verify guests table has NO unapproved 'status' or 'is_active' lifecycle columns
SELECT results_eq(
  $$
  SELECT count(*)::integer
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'guests'
    AND column_name IN ('status', 'is_active');
  $$,
  $$
  VALUES (0);
  $$,
  'Approved design: guests table must not contain lifecycle status or is_active fields.'
);

-- 2. Client is blocked from directly writing to normalized_phone and normalized_email columns
SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

SELECT throws_ok(
  $$
  INSERT INTO public.guests (wedding_id, name, normalized_phone)
  VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Hacker', '0912345678');
  $$,
  '42501',
  NULL,
  'Client must be blocked from writing directly to normalized_phone column.'
);

-- 3. Blocked writing to normalized_email
SELECT throws_ok(
  $$
  INSERT INTO public.guests (wedding_id, name, normalized_email)
  VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Hacker', 'hacker@example.com');
  $$,
  '42501',
  NULL,
  'Client must be blocked from writing directly to normalized_email column.'
);

RESET ROLE;

-- ===========================================================================
-- SECTION 2: TRIGGER NORMALIZATION & REGRESSIONS
-- ===========================================================================

-- 4. Test phone and email normalization triggers on insert
INSERT INTO public.guests (id, wedding_id, name, phone, email)
VALUES (
  'e1111111-1111-1111-1111-111111111111',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'Nguyễn Văn A',
  ' +84 91-234 5678 ',
  '  User.A@Example.Com  '
);

SELECT results_eq(
  $$
  SELECT normalized_phone, normalized_email FROM public.guests WHERE id = 'e1111111-1111-1111-1111-111111111111';
  $$,
  $$
  VALUES ('0912345678'::varchar, 'user.a@example.com'::varchar);
  $$,
  'Phone and email must be normalized: phone only keeps digits, starts with 0; email lowercase and trimmed.'
);

-- 5. Test phone normalization starting with 84 without +
INSERT INTO public.guests (id, wedding_id, name, phone)
VALUES (
  'e2222222-2222-2222-2222-222222222222',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'Nguyễn Văn B',
  '84987654321'
);

SELECT results_eq(
  $$
  SELECT normalized_phone FROM public.guests WHERE id = 'e2222222-2222-2222-2222-222222222222';
  $$,
  $$
  VALUES ('0987654321'::varchar);
  $$,
  'Phone starting with 84 must be normalized to start with 0.'
);

-- ===========================================================================
-- SECTION 3: CONSTRAINTS & INVARIANTS
-- ===========================================================================

-- 6. Side must reject unapproved values
SELECT throws_ok(
  $$
  INSERT INTO public.guests (wedding_id, name, side)
  VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Test', 'INVALID_SIDE');
  $$,
  '23514',
  NULL,
  'Guest side must reject values other than COMMON, BRIDE_SIDE, GROOM_SIDE.'
);

-- 7. Guest Source must reject unapproved values
SELECT throws_ok(
  $$
  INSERT INTO public.guests (wedding_id, name, guest_source)
  VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Test', 'INVALID_SOURCE');
  $$,
  '23514',
  NULL,
  'Guest source must reject values other than BRIDE, GROOM, BRIDE_PARENTS, GROOM_PARENTS, OTHER.'
);

-- 8. Normalized contact fields must be non-unique (nonunique constraint check)
SELECT lives_ok(
  $$
  INSERT INTO public.guests (wedding_id, name, phone, email)
  VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Duplicate Contact User', '0912345678', 'user.a@example.com');
  $$,
  'Inserting a guest with duplicate phone/email must succeed (uniqueness is not enforced by unique constraint).'
);

-- 9. Guest may be unassigned (invitation_party_id = NULL)
SELECT results_eq(
  $$
  SELECT name FROM public.guests WHERE invitation_party_id IS NULL AND id = 'e1111111-1111-1111-1111-111111111111';
  $$,
  $$
  VALUES ('Nguyễn Văn A'::varchar);
  $$,
  'Guests are allowed to remain unassigned (invitation_party_id = NULL).'
);

-- 10. Party may exist with 0 named guests
INSERT INTO public.invitation_parties (id, wedding_id, display_name, invited_count)
VALUES ('c1111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Gia đình bác Tư', 4);

SELECT results_eq(
  $$
  SELECT count(*)::integer FROM public.guests WHERE invitation_party_id = 'c1111111-1111-1111-1111-111111111111';
  $$,
  $$
  VALUES (0);
  $$,
  'An invitation party can exist with zero named guests.'
);

-- 11. Invited Count is independent of named guests count and assignment
-- Assign a guest to party (NULL -> Party), verify invited_count is unchanged (4)
UPDATE public.guests 
SET invitation_party_id = 'c1111111-1111-1111-1111-111111111111' 
WHERE id = 'e1111111-1111-1111-1111-111111111111';

SELECT results_eq(
  $$
  SELECT invited_count FROM public.invitation_parties WHERE id = 'c1111111-1111-1111-1111-111111111111';
  $$,
  $$
  VALUES (4);
  $$,
  'Invited Count must remain unchanged (4) after assigning a guest.'
);

-- ===========================================================================
-- SECTION 4: SAME-WEDDING INTEGRITY & RLS TENANT ISOLATION
-- ===========================================================================

-- Create Group A in Wedding A, Group B in Wedding B
INSERT INTO public.primary_groups (id, wedding_id, name)
VALUES 
  ('d1111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Bạn cấp 3 A'),
  ('d2222222-2222-2222-2222-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Bạn cấp 3 B');

-- Create Party B in Wedding B
INSERT INTO public.invitation_parties (id, wedding_id, display_name, invited_count)
VALUES ('c2222222-2222-2222-2222-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Party Wedding B', 2);

-- 12. Guest A (Wedding A) cannot link to Group B (Wedding B) - Same-wedding constraint check
SELECT throws_ok(
  $$
  INSERT INTO public.guests (wedding_id, name, primary_group_id)
  VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Cross Group User', 'd2222222-2222-2222-2222-222222222222');
  $$,
  '23503',
  NULL,
  'Guest same-wedding PrimaryGroup constraint must block cross-wedding links.'
);

-- 13. Guest A (Wedding A) cannot link to Party B (Wedding B) - Same-wedding constraint check
SELECT throws_ok(
  $$
  INSERT INTO public.guests (wedding_id, name, invitation_party_id)
  VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Cross Party User', 'c2222222-2222-2222-2222-222222222222');
  $$,
  '23503',
  NULL,
  'Guest same-wedding Party constraint must block cross-wedding links.'
);

-- 14. RLS: Wedding A organizer cannot select Wedding B guests
SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

-- Create guest in Wedding B as superuser first
RESET ROLE;
INSERT INTO public.guests (id, wedding_id, name)
VALUES ('e9999999-9999-9999-9999-999999999999', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Guest in B');

-- Query as authenticated User A
SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

SELECT is(
  (SELECT count(*)::integer FROM public.guests WHERE wedding_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  0,
  'RLS: Organizer User A must not be allowed to read Wedding B guests.'
);

-- 15. RLS: Wedding A organizer cannot insert Wedding B guests
SELECT throws_ok(
  $$
  INSERT INTO public.guests (wedding_id, name)
  VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Guest from A');
  $$,
  '42501',
  NULL,
  'RLS: Organizer User A must not be allowed to insert guests for Wedding B.'
);

RESET ROLE;

-- ===========================================================================
-- NEW CLOSURE TESTS (IMPL-CONFLICT-007, IMPL-CONFLICT-009, IMPL-GAP-005)
-- ===========================================================================

-- 16. Invariant: invited_count must be > 0 (IMPL-CONFLICT-007)
SELECT throws_ok(
  $$
  INSERT INTO public.invitation_parties (wedding_id, display_name, invited_count)
  VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Gia đình Bác Năm', 0);
  $$,
  '23514',
  NULL,
  'Constraint: chk_parties_invited_count must reject invited_count = 0.'
);

-- 17. Transition: Initial assignment NULL -> Party A succeeds
INSERT INTO public.guests (id, wedding_id, name, invitation_party_id)
VALUES (
  'e4444444-4444-4444-4444-444444444444',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'Khách Mới Chưa Nhóm',
  NULL
);

SELECT lives_ok(
  $$
  UPDATE public.guests
  SET invitation_party_id = 'c1111111-1111-1111-1111-111111111111'
  WHERE id = 'e4444444-4444-4444-4444-444444444444';
  $$,
  'Transition NULL -> Party must succeed.'
);

-- 18. Transition: Party -> NULL (unassign) is blocked (IMPL-CONFLICT-009)
SELECT throws_ok(
  $$
  UPDATE public.guests
  SET invitation_party_id = NULL
  WHERE id = 'e4444444-4444-4444-4444-444444444444';
  $$,
  '42501',
  'Direct unassignment or transition from an existing invitation party is blocked. Must use trusted operations.',
  'Transition Party -> NULL must fail.'
);

-- 19. Transition: Party A -> Party B is blocked
-- Create Party A2
INSERT INTO public.invitation_parties (id, wedding_id, display_name, invited_count)
VALUES ('c3333333-3333-3333-3333-333333333333', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Gia đình cô út', 3);

SELECT throws_ok(
  $$
  UPDATE public.guests 
  SET invitation_party_id = 'c3333333-3333-3333-3333-333333333333' 
  WHERE id = 'e4444444-4444-4444-4444-444444444444';
  $$,
  '42501',
  'Direct unassignment or transition from an existing invitation party is blocked. Must use trusted operations.',
  'Direct transition Party A -> Party B must fail.'
);

-- 20. Mutation Boundary (Grants/Policies): authenticated client cannot direct DELETE primary_groups (IMPL-GAP-005)
SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

SELECT throws_ok(
  $$
  DELETE FROM public.primary_groups WHERE id = 'd1111111-1111-1111-1111-111111111111';
  $$,
  '42501',
  NULL,
  'Mutation boundary: direct DELETE on primary_groups is blocked for clients.'
);

-- 21. Mutation Boundary: authenticated client cannot direct DELETE invitation_parties
SELECT throws_ok(
  $$
  DELETE FROM public.invitation_parties WHERE id = 'c1111111-1111-1111-1111-111111111111';
  $$,
  '42501',
  NULL,
  'Mutation boundary: direct DELETE on invitation_parties is blocked for clients.'
);

-- 22. Mutation Boundary: authenticated client cannot direct DELETE guests
SELECT throws_ok(
  $$
  DELETE FROM public.guests WHERE id = 'e1111111-1111-1111-1111-111111111111';
  $$,
  '42501',
  NULL,
  'Mutation boundary: direct DELETE on guests is blocked for clients.'
);

RESET ROLE;

-- 23. Duplicate privacy: check_guest_duplicates function must not exist in database (IMPL-CONFLICT-008)
SELECT results_eq(
  $$
  SELECT count(*)::integer
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'api_v1'
    AND p.proname = 'check_guest_duplicates';
  $$,
  $$
  VALUES (0);
  $$,
  'Duplicate RPC check: check_guest_duplicates function must be removed from api_v1 schema.'
);

SELECT * FROM finish();
ROLLBACK;
