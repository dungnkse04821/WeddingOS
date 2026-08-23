BEGIN;
SELECT plan(27); -- 27 assertions for BATCH-05 (Guest Impact Operations)

-- ===========================================================================
-- TEST SETUP
-- ===========================================================================

-- 1. Create test users
INSERT INTO auth.users (id, email)
VALUES ('11111111-1111-1111-1111-111111111111', 'organizer.a@example.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO auth.users (id, email)
VALUES ('22222222-2222-2222-2222-222222222222', 'organizer.b@example.com')
ON CONFLICT (id) DO NOTHING;

-- 2. Create test weddings
INSERT INTO public.weddings (id, name, target_budget, cultural_context, exact_date)
VALUES 
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Wedding A', 500000000, 'TUY_CHON', '2026-12-18'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Wedding B', 600000000, 'TUY_CHON', '2026-12-25')
ON CONFLICT (id) DO NOTHING;

-- 3. Create active members
INSERT INTO public.wedding_members (id, wedding_id, user_id, role, status, display_name, profile_email)
VALUES 
  ('88888888-8888-8888-8888-888888888888', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'OWNER', 'ACTIVE', 'USER A', 'organizer.a@example.com'),
  ('99999999-9999-9999-9999-999999999999', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', 'OWNER', 'ACTIVE', 'USER B', 'organizer.b@example.com')
ON CONFLICT (id) DO NOTHING;

-- Trusted execution authority must not be available to ordinary client roles.
SELECT is(
  (SELECT rolcanlogin FROM pg_roles WHERE rolname = 'trusted_function_owner'),
  false,
  'Security role: trusted_function_owner must remain NOLOGIN.'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM pg_auth_members am
    JOIN pg_roles parent_role ON parent_role.oid = am.roleid
    JOIN pg_roles member_role ON member_role.oid = am.member
    WHERE parent_role.rolname = 'trusted_function_owner'
      AND member_role.rolname IN ('authenticated', 'anon')
  ),
  0,
  'Security role: authenticated/anon must not inherit or SET ROLE trusted_function_owner.'
);

-- Setup session
SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

-- Create Groups, Parties and Guests in Wedding A (via normal commands as authenticated/superuser)
RESET ROLE;
INSERT INTO public.primary_groups (id, wedding_id, name)
VALUES ('d1111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Bạn Đại Học');

INSERT INTO public.invitation_parties (id, wedding_id, display_name, invited_count)
VALUES 
  ('c1111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Gia đình Bác An', 4),
  ('c2222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Hộ Chị Bình', 2);

INSERT INTO public.guests (id, wedding_id, name, phone, email, side, guest_source, primary_group_id, invitation_party_id)
VALUES 
  ('e1111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Khách Nhóm 1', '0911111111', 'guest1@example.com', 'COMMON', 'BRIDE', 'd1111111-1111-1111-1111-111111111111', 'c1111111-1111-1111-1111-111111111111'),
  ('e2222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Khách Nhóm 2', '0922222222', 'guest2@example.com', 'BRIDE_SIDE', 'GROOM', NULL, 'c2222222-2222-2222-2222-222222222222');

-- Set authenticated role again for tests
SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

-- ===========================================================================
-- 1. TOP-GUE-001: PRIMARYGROUP DELETE PREVIEW & COMMIT
-- ===========================================================================

-- 1. Preview PrimaryGroup Delete
SELECT is(
  (api_v1.preview_primary_group_delete('d1111111-1111-1111-1111-111111111111') ->> 'affected_guest_count')::integer,
  1,
  'Preview: Affected guest count must be exactly 1.'
);

-- 2. Stale fingerprint block on Commit
SELECT throws_ok(
  $$
  SELECT api_v1.commit_primary_group_delete('d1111111-1111-1111-1111-111111111111', 'invalid_fingerprint');
  $$,
  '40001',
  'STALE_IMPACT: The planning workspace state has changed since the preview was generated.',
  'Commit: Must throw STALE_IMPACT if the fingerprint does not match.'
);

-- 3. Successful Commit Group Delete
SELECT lives_ok(
  $$
  SELECT api_v1.commit_primary_group_delete(
    'd1111111-1111-1111-1111-111111111111',
    api_v1.preview_primary_group_delete('d1111111-1111-1111-1111-111111111111') ->> 'impact_fingerprint'
  );
  $$,
  'Commit: Deleting primary group with valid fingerprint must succeed.'
);

-- 4. Verify detaches guests
SELECT is(
  (SELECT count(*)::integer FROM public.primary_groups WHERE id = 'd1111111-1111-1111-1111-111111111111'),
  0,
  'After commit: Primary group must be deleted.'
);

-- 5. Verify detaches guests from primary group
SELECT is(
  (SELECT primary_group_id FROM public.guests WHERE id = 'e1111111-1111-1111-1111-111111111111'),
  NULL,
  'After commit: Affected guests must have primary_group_id set to NULL.'
);

-- 6. Retry Commit Group Delete returns replayed = true
SELECT is(
  (api_v1.commit_primary_group_delete('d1111111-1111-1111-1111-111111111111', 'any_fingerprint') ->> 'replayed')::boolean,
  true,
  'Retry: Commit on already deleted group must return replayed = true success.'
);

-- ===========================================================================
-- 2. TOP-GUE-002: PARTY MOVE/REMOVE
-- ===========================================================================

-- 7. Preview Guest Party Move
SELECT is(
  (api_v1.preview_guest_party_move('e1111111-1111-1111-1111-111111111111', 'c2222222-2222-2222-2222-222222222222') ->> 'target_invited_count')::integer,
  2,
  'Preview: Target invited count must be loaded correctly.'
);

-- 8. Cross-wedding Target Party in Preview throws error
RESET ROLE;
INSERT INTO public.invitation_parties (id, wedding_id, display_name, invited_count)
VALUES ('c9999999-9999-9999-9999-999999999999', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Party Wedding B', 5);
SET ROLE authenticated;

SELECT throws_ok(
  $$
  SELECT api_v1.preview_guest_party_move('e1111111-1111-1111-1111-111111111111', 'c9999999-9999-9999-9999-999999999999');
  $$,
  '44000',
  'Target party not found or belongs to a different wedding.',
  'Preview: Must reject cross-wedding party target.'
);

-- 9. Adversarial GUC attempt cannot bypass Party -> NULL protection
SELECT set_config('weddingos.trusted_operation', 'true', true);

SELECT throws_ok(
  $$
  UPDATE public.guests
  SET invitation_party_id = NULL
  WHERE id = 'e1111111-1111-1111-1111-111111111111';
  $$,
  '42501',
  'Direct unassignment or transition from an existing invitation party is blocked. Must use trusted operations.',
  'Class B adversarial: Client-set weddingos.trusted_operation=true must not allow Party -> NULL.'
);

-- 10. Adversarial GUC attempt cannot bypass Party A -> Party B protection
SELECT throws_ok(
  $$
  UPDATE public.guests
  SET invitation_party_id = 'c2222222-2222-2222-2222-222222222222'
  WHERE id = 'e1111111-1111-1111-1111-111111111111';
  $$,
  '42501',
  'Direct unassignment or transition from an existing invitation party is blocked. Must use trusted operations.',
  'Class B adversarial: Client-set weddingos.trusted_operation=true must not allow Party A -> Party B.'
);

-- 11. Commit Party Move succeeds
SELECT lives_ok(
  $$
  SELECT api_v1.commit_guest_party_move(
    'e1111111-1111-1111-1111-111111111111',
    'c2222222-2222-2222-2222-222222222222',
    api_v1.preview_guest_party_move('e1111111-1111-1111-1111-111111111111', 'c2222222-2222-2222-2222-222222222222') ->> 'impact_fingerprint'
  );
  $$,
  'Commit: Moving guest party with valid fingerprint must succeed.'
);

-- 12. Check guest is moved
SELECT is(
  (SELECT invitation_party_id FROM public.guests WHERE id = 'e1111111-1111-1111-1111-111111111111'),
  'c2222222-2222-2222-2222-222222222222'::uuid,
  'After commit: Guest must be moved to target party.'
);

-- 13. Check Invited Counts are unchanged (Independence check - Source)
SELECT is(
  (SELECT invited_count FROM public.invitation_parties WHERE id = 'c1111111-1111-1111-1111-111111111111'),
  4,
  'Invited Count of source party must remain 4.'
);

-- 14. Check Invited Counts are unchanged (Independence check - Target)
SELECT is(
  (SELECT invited_count FROM public.invitation_parties WHERE id = 'c2222222-2222-2222-2222-222222222222'),
  2,
  'Invited Count of target party must remain 2.'
);

-- 15. Retry Party Move returns replayed = true
SELECT is(
  (api_v1.commit_guest_party_move('e1111111-1111-1111-1111-111111111111', 'c2222222-2222-2222-2222-222222222222', 'any_fingerprint') ->> 'replayed')::boolean,
  true,
  'Retry: Commit with already matching state returns replayed success.'
);

-- 16. Ordinary update still blocked (Class B trigger block remains active)
SELECT throws_ok(
  $$
  UPDATE public.guests
  SET invitation_party_id = 'c1111111-1111-1111-1111-111111111111'
  WHERE id = 'e1111111-1111-1111-1111-111111111111';
  $$,
  '42501',
  'Direct unassignment or transition from an existing invitation party is blocked. Must use trusted operations.',
  'Class B block: Direct update of invitation_party_id on active guest must fail.'
);

-- ===========================================================================
-- 3. TOP-GUE-003: GUEST DUPLICATE MERGE
-- ===========================================================================

-- 17. Preview Guest Merge
SELECT is(
  (api_v1.preview_guest_merge('e1111111-1111-1111-1111-111111111111', 'e2222222-2222-2222-2222-222222222222') -> 'conflicts' -> 'side' ->> 'has_conflict')::boolean,
  true,
  'Preview: Conflict on Side must be detected because they are different.'
);

-- 18. Commit Guest Merge fails on invalid candidate value
SELECT throws_ok(
  $$
  SELECT api_v1.commit_guest_merge(
    'e1111111-1111-1111-1111-111111111111',
    'e2222222-2222-2222-2222-222222222222',
    'Khách Nhóm 1',
    '0911111111',
    'guest1@example.com',
    'GROOM_SIDE', -- Invalid candidate!
    'BRIDE',
    NULL,
    'c2222222-2222-2222-2222-222222222222',
    api_v1.preview_guest_merge('e1111111-1111-1111-1111-111111111111', 'e2222222-2222-2222-2222-222222222222') ->> 'impact_fingerprint'
  );
  $$,
  '23514',
  'Invalid resolution candidate for side.',
  'Commit: Reject candidate if it does not belong to either guest.'
);

-- 19. Commit Guest Merge succeeds with valid candidate choices
SELECT lives_ok(
  $$
  SELECT api_v1.commit_guest_merge(
    'e1111111-1111-1111-1111-111111111111', -- Survivor
    'e2222222-2222-2222-2222-222222222222', -- Secondary
    'Khách Nhóm 1',
    '0911111111',
    'guest1@example.com',
    'BRIDE_SIDE', -- Guest 2 choice
    'GROOM',       -- Guest 2 choice
    NULL,
    'c2222222-2222-2222-2222-222222222222', -- Guest 2 choice
    api_v1.preview_guest_merge('e1111111-1111-1111-1111-111111111111', 'e2222222-2222-2222-2222-222222222222') ->> 'impact_fingerprint'
  );
  $$,
  'Commit: Merge with valid resolutions and fingerprint must succeed.'
);

-- 20. Verify survivor is updated and secondary is deleted
SELECT results_eq(
  $$
  SELECT name, side, guest_source, invitation_party_id FROM public.guests WHERE id = 'e1111111-1111-1111-1111-111111111111';
  $$,
  $$
  VALUES ('Khách Nhóm 1'::varchar, 'BRIDE_SIDE'::varchar, 'GROOM'::varchar, 'c2222222-2222-2222-2222-222222222222'::uuid);
  $$,
  'After merge: Survivor must take on the resolved values.'
);

-- 21. Verify secondary guest is physically deleted
SELECT is(
  (SELECT count(*)::integer FROM public.guests WHERE id = 'e2222222-2222-2222-2222-222222222222'),
  0,
  'After merge: Secondary guest must be physically deleted.'
);

-- 22. Retry check: absent secondary + matching survivor is ambiguous without durable proof
SELECT throws_ok(
  $$
  SELECT api_v1.commit_guest_merge(
    'e1111111-1111-1111-1111-111111111111',
    'e2222222-2222-2222-2222-222222222222',
    'Khách Nhóm 1',
    '0911111111',
    'guest1@example.com',
    'BRIDE_SIDE',
    'GROOM',
    NULL,
    'c2222222-2222-2222-2222-222222222222',
    'any_fingerprint'
  );
  $$,
  '40009',
  'CONFLICT: The secondary guest is absent and this merge retry cannot be proven from an approved durable source.',
  'Retry: Merge must not return replayed=true from secondary absence plus matching survivor fields.'
);

-- 23. Ambiguous state check: unrelated absent secondary also cannot be inferred as replay
SELECT throws_ok(
  $$
  SELECT api_v1.commit_guest_merge(
    'e1111111-1111-1111-1111-111111111111',
    'e3333333-3333-3333-3333-333333333333',
    'Khách Nhóm 1',
    '0911111111',
    'guest1@example.com',
    'BRIDE_SIDE',
    'GROOM',
    NULL,
    'c2222222-2222-2222-2222-222222222222',
    'any_fingerprint'
  );
  $$,
  '40009',
  'CONFLICT: The secondary guest is absent and this merge retry cannot be proven from an approved durable source.',
  'Ambiguous state: Matching survivor plus absent secondary must fail closed without durable proof.'
);

-- 24. Retry check: Calling commit again with different attributes returns conflict
SELECT throws_ok(
  $$
  SELECT api_v1.commit_guest_merge(
    'e1111111-1111-1111-1111-111111111111',
    'e2222222-2222-2222-2222-222222222222',
    'Khách Nhóm 1',
    '0911111111',
    'different_email@example.com', -- Different resolution!
    'BRIDE_SIDE',
    'GROOM',
    NULL,
    'c2222222-2222-2222-2222-222222222222',
    'any_fingerprint'
  );
  $$,
  '40009',
  'CONFLICT: The secondary guest is absent and this merge retry cannot be proven from an approved durable source.',
  'Retry: Must throw CONFLICT when secondary absence makes the merge retry ambiguous.'
);

-- 25. Direct guest DELETE is still denied for clients
SELECT throws_ok(
  $$
  DELETE FROM public.guests WHERE id = 'e1111111-1111-1111-1111-111111111111';
  $$,
  '42501',
  NULL,
  'Mutation boundary: Client cannot directly DELETE a guest.'
);

RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
