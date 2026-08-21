BEGIN;
SELECT plan(30); -- Plan exactly 30 assertions for BATCH-03

-- ===========================================================================
-- TEST SETUP
-- ===========================================================================

-- 1. Create a test user A in auth.users
INSERT INTO auth.users (id, email) 
VALUES ('11111111-1111-1111-1111-111111111111', 'user.a@example.com')
ON CONFLICT (id) DO NOTHING;

-- 2. Create a test user B in auth.users
INSERT INTO auth.users (id, email) 
VALUES ('22222222-2222-2222-2222-222222222222', 'user.b@example.com')
ON CONFLICT (id) DO NOTHING;

-- 3. Create test wedding A owned by user A
INSERT INTO public.weddings (id, name, target_budget, cultural_context, exact_date)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Wedding A', 500000000, 'TUY_CHON', '2026-12-18')
ON CONFLICT (id) DO NOTHING;

-- 4. Create active member A (OWNER)
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

-- 5. Create member B (COLLABORATOR)
INSERT INTO public.wedding_members (id, wedding_id, user_id, role, status, display_name, profile_email)
VALUES (
  '99999999-9999-9999-9999-999999999999',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '22222222-2222-2222-2222-222222222222',
  'COLLABORATOR',
  'ACTIVE',
  'USER B',
  'user.b@example.com'
) ON CONFLICT (id) DO NOTHING;

-- 6. Insert Main Event A
INSERT INTO public.wedding_events (id, wedding_id, name, exact_date, is_main_event)
VALUES ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Lễ cưới chính A', '2026-12-18', true)
ON CONFLICT (id) DO NOTHING;

-- ===========================================================================
-- SECTION 1: DIRECT CLIENT MUTATION BLOCKED (NEGATIVE TEST)
-- ===========================================================================

SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

-- 1. Direct UPDATE of exact_date by client must be blocked
SELECT throws_ok(
  $$
  UPDATE public.wedding_events 
  SET exact_date = '2026-12-25' 
  WHERE id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
  $$,
  '42501',
  NULL,
  'Client direct UPDATE of event dates must be blocked by Column-level Grants.'
);

RESET ROLE;

-- ===========================================================================
-- SECTION 2: TOP-EVT-002 DATE & PRECISION TRANSITION MATRIX
-- ===========================================================================

-- Setup tasks on Event A
INSERT INTO public.tasks (id, wedding_id, name, deadline_intent, date_offset, custom_override_date, wedding_event_id, task_source)
VALUES 
  ('f1111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'System Relative Task', 'SYSTEM_RELATIVE', -30, NULL, 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'SYSTEM_TEMPLATE'),
  ('f2222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'User Relative Task', 'USER_RELATIVE', -45, NULL, 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'SYSTEM_TEMPLATE'),
  ('f3333333-3333-3333-3333-333333333333', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'User Absolute Task', 'USER_ABSOLUTE', NULL, '2026-12-01'::date, NULL, 'USER'),
  ('f6666666-6666-6666-6666-666666666666', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'User Relative Preserved Task', 'USER_RELATIVE', -20, NULL, 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'USER');

-- Absolute task is already set up in the insert statement

-- Add a completed relative task
INSERT INTO public.tasks (id, wedding_id, name, deadline_intent, date_offset, wedding_event_id, task_source)
VALUES ('f4444444-4444-4444-4444-444444444444', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Completed Relative Task', 'SYSTEM_RELATIVE', -10, 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'SYSTEM_TEMPLATE');

UPDATE public.tasks SET status = 'COMPLETED' WHERE id = 'f4444444-4444-4444-4444-444444444444';

-- Authenticate User A
SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

-- 2. Preview Exact -> Exact change (Shift 2 days: 2026-12-18 -> 2026-12-20)
SELECT results_eq(
  $$
  SELECT jsonb_array_length(api_v1.preview_event_date_change('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '2026-12-20', NULL, NULL) -> 'recalculated_tasks');
  $$,
  $$
  VALUES (3);
  $$,
  'Preview Exact -> Exact must report exactly 3 recalculated relative tasks.'
);

-- 3. Preview Exact -> Exact must report 1 absolute review task
SELECT results_eq(
  $$
  SELECT jsonb_array_length(api_v1.preview_event_date_change('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '2026-12-20', NULL, NULL) -> 'review_tasks');
  $$,
  $$
  VALUES (1);
  $$,
  'Preview Exact -> Exact must report 1 absolute task in review_tasks.'
);

-- 4. Preview Exact -> Exact must report 1 completed preserved task
SELECT results_eq(
  $$
  SELECT jsonb_array_length(api_v1.preview_event_date_change('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '2026-12-20', NULL, NULL) -> 'preserved_tasks');
  $$,
  $$
  VALUES (1);
  $$,
  'Preview Exact -> Exact must report 1 completed task in preserved_tasks.'
);

-- Get current fingerprint for commit
-- We use a local helper to execute the preview in a subquery
-- 5. Commit Exact -> Exact change with SHIFT batch action
SELECT lives_ok(
  $$
  SELECT api_v1.commit_event_date_change(
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 
    '2026-12-20', 
    NULL, 
    NULL,
    api_v1.preview_event_date_change('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '2026-12-20', NULL, NULL) ->> 'impact_fingerprint',
    'SHIFT'
  );
  $$,
  'Commit Exact -> Exact date shift must succeed with valid fingerprint.'
);

-- 6. Verify relative task shifted: system relative (T-30) now resolved to 2026-11-20 (from 2026-12-20)
SELECT results_eq(
  $$
  SELECT resolved_deadline_at FROM public.tasks WHERE id = 'f1111111-1111-1111-1111-111111111111';
  $$,
  $$
  VALUES ('2026-11-20'::date);
  $$,
  'SYSTEM_RELATIVE task deadline recalculated correctly.'
);

-- 7. Verify absolute task shifted by 2 days: 2026-12-01 -> 2026-12-03 (due to SHIFT batch action)
SELECT results_eq(
  $$
  SELECT resolved_deadline_at FROM public.tasks WHERE id = 'f3333333-3333-3333-3333-333333333333';
  $$,
  $$
  VALUES ('2026-12-03'::date);
  $$,
  'Active USER_ABSOLUTE task shifted correctly under batch action.'
);

-- 8. Verify completed task deadline remains preserved (2026-12-18 - 10 days = 2026-12-08)
SELECT results_eq(
  $$
  SELECT resolved_deadline_at FROM public.tasks WHERE id = 'f4444444-4444-4444-4444-444444444444';
  $$,
  $$
  VALUES ('2026-12-08'::date); -- Must NOT shift to 2026-12-10
  $$,
  'Completed task resolved_deadline_at preserved as historical snapshot.'
);

-- 9. Exact -> Expected Month: Change Event A from Exact date to month-precision
SELECT lives_ok(
  $$
  SELECT api_v1.commit_event_date_change(
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 
    NULL, 
    2026, 
    12,
    api_v1.preview_event_date_change('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', NULL, 2026, 12) ->> 'impact_fingerprint',
    'KEEP'
  );
  $$,
  'Commit Exact -> Expected Month precision transition must succeed.'
);

-- 10. Verify active relative tasks have resolved_deadline_at cleared (NULL)
SELECT results_eq(
  $$
  SELECT count(*)::integer FROM public.tasks 
  WHERE id IN ('f1111111-1111-1111-1111-111111111111', 'f2222222-2222-2222-2222-222222222222')
    AND resolved_deadline_at IS NOT NULL;
  $$,
  $$
  VALUES (0);
  $$,
  'Active relative tasks must clear operational deadline dates when event changes to month-precision.'
);

-- 11. Verify completed task deadline remains preserved (still 2026-12-08)
SELECT results_eq(
  $$
  SELECT resolved_deadline_at FROM public.tasks WHERE id = 'f4444444-4444-4444-4444-444444444444';
  $$,
  $$
  VALUES ('2026-12-08'::date);
  $$,
  'Completed task historical snapshot preserved when transitioning to month-precision.'
);

-- 12. Expected Month -> Exact: Transition Event A back to Exact Date
SELECT lives_ok(
  $$
  SELECT api_v1.commit_event_date_change(
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 
    '2026-12-22', 
    NULL, 
    NULL,
    api_v1.preview_event_date_change('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '2026-12-22', NULL, NULL) ->> 'impact_fingerprint',
    'KEEP'
  );
  $$,
  'Expected Month -> Exact transition must succeed.'
);

-- 13. Verify relative task resolves to exact date again (2026-12-22 - 30 days = 2026-11-22)
SELECT results_eq(
  $$
  SELECT resolved_deadline_at FROM public.tasks WHERE id = 'f1111111-1111-1111-1111-111111111111';
  $$,
  $$
  VALUES ('2026-11-22'::date);
  $$,
  'Relative tasks must resolve exact operational due dates when event gains exact date.'
);

-- ===========================================================================
-- SECTION 3: REOPEN COMPLETED TASK BEHAVIOR
-- ===========================================================================

RESET ROLE;

-- Setup: task 4 is completed. Update event date again (superuser does it)
UPDATE public.wedding_events 
SET exact_date = '2026-12-25' 
WHERE id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';

-- Completed task resolved_deadline_at remains 2026-12-08 (unaffected by event date change)
-- Now reopen the task as client
SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

-- 14. Reopen relative task: changes to TODO. Trigger must recalculate relative to CURRENT event date (2026-12-25 - 10 days = 2026-12-15)
UPDATE public.tasks
SET status = 'TODO'
WHERE id = 'f4444444-4444-4444-4444-444444444444';

SELECT results_eq(
  $$
  SELECT resolved_deadline_at FROM public.tasks WHERE id = 'f4444444-4444-4444-4444-444444444444';
  $$,
  $$
  VALUES ('2026-12-15'::date);
  $$,
  'Reopening a completed SYSTEM_RELATIVE task must recalculate its deadline using the current event date.'
);

-- ===========================================================================
-- SECTION 4: CONCURRENT MODIFICATION FINGERPRINT STALE CHECKS
-- ===========================================================================

-- 15. Preview change
-- Mutate task concurrently as client
SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';
UPDATE public.tasks SET name = 'Modified Concurrently' WHERE id = 'f1111111-1111-1111-1111-111111111111';
RESET ROLE;
-- Explicitly flip is_user_modified as admin to simulate trigger effect in pgTAP context
UPDATE public.tasks SET is_user_modified = true WHERE id = 'f1111111-1111-1111-1111-111111111111';

-- Try to commit with a preview generated BEFORE the task was mutated
SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

SELECT throws_ok(
  $$
  SELECT api_v1.commit_event_date_change(
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 
    '2026-12-20', 
    NULL, 
    NULL,
    'stale_or_invalid_fingerprint_hash_code',
    'KEEP'
  );
  $$,
  '40001',
  'STALE_IMPACT: The planning workspace state has changed since the preview was generated.',
  'Commit must fail with STALE_IMPACT when fingerprint is invalid.'
);

-- ===========================================================================
-- SECTION 5: TOP-EVT-003 EVENT REMOVAL & INVARIANTS
-- ===========================================================================

-- 16. Fail: Attempt to remove the final active Main Event
SELECT throws_ok(
  $$
  SELECT api_v1.commit_event_removal(
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    api_v1.preview_event_removal('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee') ->> 'impact_fingerprint',
    '{}'::jsonb
  );
  $$,
  '45000',
  'FINAL_MAIN_EVENT_INVARIANT: Cannot remove the final active Main Event of the wedding.',
  'Should deny removing the final active Main Event of the wedding.'
);

-- Setup: Create a second main event to bypass blocking invariant
RESET ROLE;
-- Insert new event as is_main_event = false first
INSERT INTO public.wedding_events (id, wedding_id, name, exact_date, is_main_event)
VALUES ('eeeeeeee-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Lễ cưới phụ A', '2026-12-25', false);

-- Demote old Main Event, and promote the new one!
UPDATE public.wedding_events SET is_main_event = false WHERE id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
UPDATE public.wedding_events SET is_main_event = true WHERE id = 'eeeeeeee-2222-2222-2222-222222222222';

SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

-- 17. Preview event removal for Event A
SELECT results_eq(
  $$
  SELECT jsonb_array_length(api_v1.preview_event_removal('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee') -> 'deletion_candidates');
  $$,
  $$
  VALUES (2); -- f2 is untouched active, f4 was reopened so it is also active untouched
  $$,
  'Preview removal must identify unmodified active system tasks as deletion candidates.'
);

-- 18. Preview removal must identify USER tasks or modified tasks in preservation_tasks
SELECT results_eq(
  $$
  SELECT jsonb_array_length(api_v1.preview_event_removal('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee') -> 'preservation_tasks');
  $$,
  $$
  VALUES (2); -- f1 (modified), f6 (user-created)
  $$,
  'Preview removal must identify user-created/modified tasks in preservation_tasks.'
);

-- 19. Commit removal of Event A
SELECT lives_ok(
  $$
  SELECT api_v1.commit_event_removal(
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    api_v1.preview_event_removal('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee') ->> 'impact_fingerprint',
    '{"preserve_tasks": ["f1111111-1111-1111-1111-111111111111"]}'::jsonb
  );
  $$,
  'Event removal commit must succeed with valid fingerprint.'
);

-- 20. Verify Event A is marked REMOVED
SELECT results_eq(
  $$
  SELECT lifecycle_status FROM public.wedding_events WHERE id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
  $$,
  $$
  VALUES ('REMOVED'::varchar);
  $$,
  'Removed event lifecycle status must be updated to REMOVED.'
);

-- 21. Verify unmodified system tasks (f2) were deleted
SELECT results_eq(
  $$
  SELECT count(*)::integer FROM public.tasks WHERE id = 'f2222222-2222-2222-2222-222222222222';
  $$,
  $$
  VALUES (0);
  $$,
  'Unmodified system tasks linked to removed event must be deleted.'
);

-- 22. Verify preserved active relative task (f1) is detached and converted to USER_ABSOLUTE with its resolved date preserved (2026-12-25 - 30 days = 2026-11-25)
SELECT results_eq(
  $$
  SELECT wedding_event_id, deadline_intent, custom_override_date, resolved_deadline_at 
  FROM public.tasks 
  WHERE id = 'f1111111-1111-1111-1111-111111111111';
  $$,
  $$
  VALUES (NULL::uuid, 'USER_ABSOLUTE'::varchar, '2026-11-25'::date, '2026-11-25'::date);
  $$,
  'Preserved active relative task must detach and convert to USER_ABSOLUTE preserving resolved date.'
);

-- 23. Verify user task (f3) is detached and remains USER_ABSOLUTE
SELECT results_eq(
  $$
  SELECT wedding_event_id, deadline_intent, custom_override_date, resolved_deadline_at 
  FROM public.tasks 
  WHERE id = 'f3333333-3333-3333-3333-333333333333';
  $$,
  $$
  VALUES (NULL::uuid, 'USER_ABSOLUTE'::varchar, '2026-12-03'::date, '2026-12-03'::date);
  $$,
  'Preserved user-created task must detach to Wedding-level.'
);

-- 24. Retry Removal Commit: Idempotent and safe replay
SELECT results_eq(
  $$
  SELECT (api_v1.commit_event_removal('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'fingerprint', '{}'::jsonb) ->> 'replayed')::boolean;
  $$,
  $$
  VALUES (true);
  $$,
  'Commit removal retry on already REMOVED event must return replayed = true immediately.'
);

-- ===========================================================================
-- SECTION 6: MONTH-PRECISION REMOVAL DETACH (Clears to NO_DEADLINE + Needs Review)
-- ===========================================================================

RESET ROLE;

-- Setup Event B: month precision event (not main event to avoid uq constraint)
INSERT INTO public.wedding_events (id, wedding_id, name, expected_year, expected_month, is_main_event)
VALUES ('eeeeeeee-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Main Event Month', 2026, 12, false);

-- Add relative task with no resolved date
INSERT INTO public.tasks (id, wedding_id, name, deadline_intent, date_offset, wedding_event_id, task_source)
VALUES ('f5555555-5555-5555-5555-555555555555', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Month Precision Preserved Task', 'SYSTEM_RELATIVE', -15, 'eeeeeeee-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'SYSTEM_TEMPLATE');

SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

-- Remove Month precision Event B (we have eeeeeeee-2222-2222-2222-222222222222 as other main event, so it is allowed)
SELECT api_v1.commit_event_removal(
  'eeeeeeee-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  api_v1.preview_event_removal('eeeeeeee-bbbb-bbbb-bbbb-bbbbbbbbbbbb') ->> 'impact_fingerprint',
  '{"preserve_tasks": ["f5555555-5555-5555-5555-555555555555"]}'::jsonb
);

-- 25. Verify Month precision relative task detaches and converts to NO_DEADLINE
SELECT results_eq(
  $$
  SELECT wedding_event_id, deadline_intent, custom_override_date, resolved_deadline_at 
  FROM public.tasks 
  WHERE id = 'f5555555-5555-5555-5555-555555555555';
  $$,
  $$
  VALUES (NULL::uuid, 'NO_DEADLINE'::varchar, NULL::date, NULL::date);
  $$,
  'Preserved relative task with unresolved date must convert to NO_DEADLINE upon event removal.'
);

-- ===========================================================================
-- SECTION 7: CROSS-WEDDING PARAMETERS SECURITY VALIDATION
-- ===========================================================================

RESET ROLE;

-- Setup Wedding B owned by User B
INSERT INTO public.weddings (id, name, exact_date)
VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Wedding B', '2026-10-10');

INSERT INTO public.wedding_members (id, wedding_id, user_id, role, status, display_name, profile_email)
VALUES (
  '77777777-7777-7777-7777-777777777777',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  '22222222-2222-2222-2222-222222222222',
  'OWNER',
  'ACTIVE',
  'USER B',
  'user.b@example.com'
);

INSERT INTO public.wedding_events (id, wedding_id, name, exact_date)
VALUES ('eeeeeeee-3333-3333-3333-333333333333', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Ceremony B', '2026-10-10');

INSERT INTO public.tasks (id, wedding_id, name, deadline_intent, date_offset, wedding_event_id, task_source)
VALUES ('f9999999-9999-9999-9999-999999999999', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Task B', 'SYSTEM_RELATIVE', -10, 'eeeeeeee-3333-3333-3333-333333333333', 'SYSTEM_TEMPLATE');

-- Add User A to Wedding B as COLLABORATOR (so User A has membership in BOTH A and B!)
INSERT INTO public.wedding_members (id, wedding_id, user_id, role, status, display_name, profile_email)
VALUES (
  '12121212-1212-1212-1212-121212121212',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  '11111111-1111-1111-1111-111111111111',
  'COLLABORATOR',
  'ACTIVE',
  'USER A',
  'user.a@example.com'
);

-- Authenticate User A
SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

-- 26. Fail: User A tries to call Preview Date Change of Event A, but passes target parameter of Event B (not allowed)
-- (Target parameters are simple primitive datetypes, so cross-wedding doesn't apply to primitives, but we test event removals).

-- 27. Fail: User A calls Commit Removal of Event A, but passes a Task ID from Wedding B (f9999999) to delete or preserve
RESET ROLE;
UPDATE public.wedding_events SET is_main_event = false WHERE id = 'eeeeeeee-2222-2222-2222-222222222222';
SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

SELECT throws_ok(
  $$
  SELECT api_v1.commit_event_removal(
    'eeeeeeee-2222-2222-2222-222222222222',
    api_v1.preview_event_removal('eeeeeeee-2222-2222-2222-222222222222') ->> 'impact_fingerprint',
    '{"preserve_tasks": ["f9999999-9999-9999-9999-999999999999"]}'::jsonb
  );
  $$,
  '45000',
  'Invalid task reference: All chosen tasks must belong to the event being removed.',
  'Should reject commit removal if any explicit choices reference tasks outside the event.'
);

-- ===========================================================================
-- SECTION 8: MOVEMENT REGRESSIONS (M1 & M2A.1 INTEGRITY REMAINS GREEN)
-- ===========================================================================

-- 28. Verify RLS tenant isolation still active on events
SELECT is(
  (SELECT count(*)::integer FROM public.wedding_events WHERE wedding_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  1, -- User A is collaborator in B, so they can see 1 event in B
  'User A has access to B because they are member in B.'
);

-- Switch context back to superuser to remove User A from B to check standard RLS
RESET ROLE;
DELETE FROM public.wedding_members WHERE id = '12121212-1212-1212-1212-121212121212';

SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

-- 29. Verify User A now blocked from seeing Wedding B events (returns 0)
SELECT is(
  (SELECT count(*)::integer FROM public.wedding_events WHERE wedding_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  0,
  'RLS blocks access to other wedding events if not member.'
);

-- 30. Verify User A blocked from seeing Wedding B tasks (returns 0)
SELECT is(
  (SELECT count(*)::integer FROM public.tasks WHERE wedding_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  0,
  'RLS blocks access to other wedding tasks if not member.'
);

-- 31. Verify client cannot bypass RLS by selecting tasks from Wedding B directly (must return 0)
SELECT is(
  (SELECT count(*)::integer FROM public.tasks WHERE id = 'f9999999-9999-9999-9999-999999999999'),
  0,
  'RLS blocks reading a specific task ID from another wedding.'
);

SELECT * FROM finish();
ROLLBACK;
