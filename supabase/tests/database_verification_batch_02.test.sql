BEGIN;
SELECT plan(38); -- Plan 38 assertions

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

-- 3. Create a test wedding A owned by user A
INSERT INTO public.weddings (id, name, target_budget, cultural_context, exact_date)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Wedding A', 500000000, 'TUY_CHON', '2026-12-18')
ON CONFLICT (id) DO NOTHING;

-- 4. Create member A (OWNER)
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

-- ===========================================================================
-- SECTION 1: DATE PRECISION & MAIN EVENT CONSTRAINT TESTS
-- ===========================================================================

-- 1. Fail: expected_year/expected_month both set AND exact_date set
SELECT throws_ok(
  $$
  INSERT INTO public.wedding_events (wedding_id, name, exact_date, expected_year, expected_month)
  VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Test Event', '2026-12-18', 2026, 12);
  $$,
  '23514', -- Check constraint violation SQLSTATE
  NULL,
  'Should fail expected XOR exact date constraint if both are set.'
);

-- 2. Fail: both expected and exact date are null
SELECT throws_ok(
  $$
  INSERT INTO public.wedding_events (wedding_id, name, exact_date, expected_year, expected_month)
  VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Test Event', NULL, NULL, NULL);
  $$,
  '23514',
  NULL,
  'Should fail expected XOR exact date constraint if both are NULL.'
);

-- 3. Succeed: only exact_date set
SELECT lives_ok(
  $$
  INSERT INTO public.wedding_events (id, wedding_id, name, exact_date, is_main_event)
  VALUES ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Main Wedding Ceremony', '2026-12-18', true);
  $$,
  'Should allow exact date only.'
);

-- 4. Fail: Try to add a second Main Event to Wedding A
SELECT throws_ok(
  $$
  INSERT INTO public.wedding_events (wedding_id, name, exact_date, is_main_event)
  VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Second Main Event', '2026-12-20', true);
  $$,
  '23505', -- Unique constraint violation SQLSTATE (uq_main_wedding_event index)
  NULL,
  'Should fail when inserting a second main event for the same wedding.'
);

-- ===========================================================================
-- SECTION 2: TASK CONSTRAINTS & ASSIGNEE INTEGRITY
-- ===========================================================================

-- 5. Fail: Try to assign task in Wedding A to a member in another wedding
SELECT throws_ok(
  $$
  INSERT INTO public.tasks (wedding_id, name, deadline_intent, date_offset, wedding_event_id, assignee_wedding_member_id)
  VALUES (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'Invalid Assignee Task',
    'SYSTEM_RELATIVE',
    -30,
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    '44444444-4444-4444-4444-444444444444' -- invalid member
  );
  $$,
  '45000', -- Custom integrity trigger throws active assignee check
  'Assignee member must be active and belong to the same wedding.',
  'Should reject assignee if not active member in same wedding.'
);

-- 6. Succeed: Assign task to active member in the same wedding
SELECT lives_ok(
  $$
  INSERT INTO public.tasks (id, wedding_id, name, deadline_intent, date_offset, wedding_event_id, assignee_wedding_member_id)
  VALUES (
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'Valid Assignee Task',
    'SYSTEM_RELATIVE',
    -30,
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    '88888888-8888-8888-8888-888888888888' -- OWNER (active)
  );
  $$,
  'Should succeed when assignee is active in the same wedding.'
);

-- 7. Succeed: Edit unrelated field (name) on Task with a now-REVOKED member assigned to it
-- Insert a task with member B before revocation check (simulate historical link)
INSERT INTO public.tasks (id, wedding_id, name, deadline_intent, date_offset, wedding_event_id, assignee_wedding_member_id)
VALUES (
  'd2222222-2222-2222-2222-222222222222',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'Task with Revoked Assignee',
  'SYSTEM_RELATIVE',
  -14,
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
  '99999999-9999-9999-9999-999999999999' -- User B (Active at insertion)
);

UPDATE public.wedding_members 
SET status = 'REVOKED' 
WHERE id = '99999999-9999-9999-9999-999999999999';

SELECT lives_ok(
  $$
  UPDATE public.tasks 
  SET name = 'Task with Revoked Assignee Updated' 
  WHERE id = 'd2222222-2222-2222-2222-222222222222';
  $$,
  'Updating unrelated field should succeed even if existing assignee is revoked.'
);

-- Re-activate User B for other tests
UPDATE public.wedding_members 
SET status = 'ACTIVE' 
WHERE id = '99999999-9999-9999-9999-999999999999';

-- ===========================================================================
-- SECTION 3: TEMPLATE DATABASE TABLE REMOVAL (IMPL-CONFLICT-001)
-- ===========================================================================

-- 8. Verify no plan_template_tasks table exists in any schema
SELECT hasnt_table(
  'internal',
  'plan_template_tasks',
  'internal.plan_template_tasks table must not exist'
);

-- ===========================================================================
-- SECTION 4: TASK PROVENANCE - CREATE VS UPDATE (IMPL-CONFLICT-002)
-- ===========================================================================

-- Simulate ordinary client connection (role = authenticated)
SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

-- 9. Fail: Client tries to insert specifying task_source directly (denied by column grant)
SELECT throws_ok(
  $$
  INSERT INTO public.tasks (wedding_id, name, deadline_intent, date_offset, wedding_event_id, task_source)
  VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Task 1', 'SYSTEM_RELATIVE', -10, 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'SYSTEM_TEMPLATE');
  $$,
  '42501',
  NULL,
  'Client insert specifying task_source directly must be blocked by Column-level Grants.'
);

-- 10. Fail: Client tries to insert specifying is_user_modified directly (denied by column grant)
SELECT throws_ok(
  $$
  INSERT INTO public.tasks (wedding_id, name, deadline_intent, date_offset, wedding_event_id, is_user_modified)
  VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Task 2', 'SYSTEM_RELATIVE', -10, 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', true);
  $$,
  '42501',
  NULL,
  'Client insert specifying is_user_modified directly must be blocked by Column-level Grants.'
);

-- 11. Succeed: Client inserts task WITHOUT specifying protected columns
SELECT lives_ok(
  $$
  INSERT INTO public.tasks (id, wedding_id, name, deadline_intent, date_offset, wedding_event_id)
  VALUES (
    'd3333333-3333-3333-3333-333333333333',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'Client Inserted Task',
    'SYSTEM_RELATIVE',
    -10,
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
  );
  $$,
  'Client insert without protected columns should succeed.'
);

-- 12. Verify: Omitted columns default to USER and false via trigger
SELECT results_eq(
  $$
  SELECT task_source, is_user_modified 
  FROM public.tasks 
  WHERE id = 'd3333333-3333-3333-3333-333333333333';
  $$,
  $$
  VALUES ('USER'::varchar, false);
  $$,
  'Client insert triggers must default task_source to USER and is_user_modified to false.'
);

-- 13. Fail: Client tries to update is_user_modified directly (denied by column grant)
SELECT throws_ok(
  $$
  UPDATE public.tasks 
  SET is_user_modified = true 
  WHERE id = 'd3333333-3333-3333-3333-333333333333';
  $$,
  '42501',
  NULL,
  'Client direct updates to is_user_modified must be blocked by Column-level Grants.'
);

-- 14. Fail: Client tries to update task_source directly (denied by column grant)
SELECT throws_ok(
  $$
  UPDATE public.tasks 
  SET task_source = 'SYSTEM_TEMPLATE' 
  WHERE id = 'd3333333-3333-3333-3333-333333333333';
  $$,
  '42501',
  NULL,
  'Client direct updates to task_source must be blocked by Column-level Grants.'
);

-- 15. Succeed: Client updates core field (name)
SELECT lives_ok(
  $$
  UPDATE public.tasks 
  SET name = 'Client Modified Name' 
  WHERE id = 'd3333333-3333-3333-3333-333333333333';
  $$,
  'Client direct updates to core fields should succeed.'
);

-- 16. Verify: Trigger automatically set is_user_modified to true
SELECT results_eq(
  $$
  SELECT is_user_modified 
  FROM public.tasks 
  WHERE id = 'd3333333-3333-3333-3333-333333333333';
  $$,
  $$
  VALUES (true);
  $$,
  'Trigger must automatically set is_user_modified to true when core fields are modified.'
);

-- 17. Verify: Editing SYSTEM_TEMPLATE task preserves task_source and sets is_user_modified to true
-- Setup: create system template task as postgres/owner
RESET ROLE;
INSERT INTO public.tasks (id, wedding_id, name, deadline_intent, date_offset, wedding_event_id, task_source, is_user_modified)
VALUES (
  'd6666666-6666-6666-6666-666666666666',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'Original System Task',
  'SYSTEM_RELATIVE',
  -45,
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
  'SYSTEM_TEMPLATE',
  false
);

-- As client, update task name
SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

UPDATE public.tasks 
SET name = 'Modified System Task' 
WHERE id = 'd6666666-6666-6666-6666-666666666666';

SELECT results_eq(
  $$
  SELECT task_source, is_user_modified 
  FROM public.tasks 
  WHERE id = 'd6666666-6666-6666-6666-666666666666';
  $$,
  $$
  VALUES ('SYSTEM_TEMPLATE'::varchar, true);
  $$,
  'Client edits to system template task must preserve SYSTEM_TEMPLATE source and flip is_user_modified to true.'
);

-- Restore admin context for calculations
RESET ROLE;

-- ===========================================================================
-- SECTION 5: DEADLINE CALCULATIONS & DATE CASCADE BOUNDARY (IMPL-CONFLICT-003)
-- ===========================================================================

-- 18. Relative deadline calculation: check correct date addition (2026-12-18 + (-30) = 2026-11-18)
SELECT results_eq(
  $$
  SELECT resolved_deadline_at 
  FROM public.tasks 
  WHERE id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
  $$,
  $$
  VALUES ('2026-11-18'::date);
  $$,
  'SYSTEM_RELATIVE deadline resolves correctly according to event exact_date + date_offset.'
);

-- 19. Expected Month relative task deadline: exact date NULL -> resolved_deadline_at NULL (no fake exact due date)
INSERT INTO public.wedding_events (id, wedding_id, name, expected_year, expected_month)
VALUES ('d5555555-5555-5555-5555-555555555555', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Engagement expected month', 2026, 6);

INSERT INTO public.tasks (id, wedding_id, name, deadline_intent, date_offset, wedding_event_id)
VALUES (
  'd4444444-4444-4444-4444-444444444444',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'Expected Month relative task',
  'SYSTEM_RELATIVE',
  -30,
  'd5555555-5555-5555-5555-555555555555'
);

SELECT results_eq(
  $$
  SELECT resolved_deadline_at 
  FROM public.tasks 
  WHERE id = 'd4444444-4444-4444-4444-444444444444';
  $$,
  $$
  VALUES (NULL::date);
  $$,
  'Expected Month relative tasks must leave resolved_deadline_at as NULL, avoiding fake dates.'
);

-- 20. Fail: Client direct UPDATE of event dates must be blocked (IMPL-CONFLICT-003)
SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

SELECT throws_ok(
  $$
  UPDATE public.wedding_events 
  SET exact_date = '2026-12-25' 
  WHERE id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
  $$,
  '42501',
  NULL,
  'Direct Class-B UPDATE of exact_date by client must be blocked by Column-level Grants.'
);

-- Restore postgres admin role to perform system changes
RESET ROLE;

-- 21. Succeed: System/trusted update of Event exact_date cascades and updates deadlines
UPDATE public.wedding_events 
SET exact_date = '2026-12-20' 
WHERE id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';

SELECT results_eq(
  $$
  SELECT resolved_deadline_at 
  FROM public.tasks 
  WHERE id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
  $$,
  $$
  VALUES ('2026-11-20'::date);
  $$,
  'Active relative tasks must automatically cascade and update deadlines when event date changes.'
);

-- 22. Succeed: Completed task resolved deadline remains historical (not overwritten)
-- Set task to COMPLETED
UPDATE public.tasks 
SET status = 'COMPLETED' 
WHERE id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';

-- Shift event date again (2026-12-20 -> 2026-12-25)
UPDATE public.wedding_events 
SET exact_date = '2026-12-25' 
WHERE id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';

SELECT results_eq(
  $$
  SELECT resolved_deadline_at 
  FROM public.tasks 
  WHERE id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
  $$,
  $$
  VALUES ('2026-11-20'::date); -- Must NOT update to 2026-11-25
  $$,
  'Completed tasks must freeze and preserve historical resolved_deadline_at snapshots.'
);

-- Restore task status
UPDATE public.tasks 
SET status = 'TODO' 
WHERE id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';

-- ===========================================================================
-- SECTION 6: INITIAL PLAN & SUGGESTED EVENTS GENERATION
-- ===========================================================================

-- Create a new test wedding B (which has no main event yet)
INSERT INTO public.weddings (id, name, cultural_context, expected_year, expected_month)
VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Wedding B', 'VIETNAMESE', 2026, 12);

-- Create active Owner for wedding B
INSERT INTO public.wedding_members (id, wedding_id, user_id, role, status, display_name, profile_email)
VALUES (
  '77777777-7777-7777-7777-777777777777',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  '11111111-1111-1111-1111-111111111111',
  'OWNER',
  'ACTIVE',
  'USER A',
  'user.a@example.com'
);

-- Authenticated User A context
SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

-- 23. Fail: Call generate_initial_plan without main event configured
SELECT throws_ok(
  $$
  SELECT api_v1.generate_initial_plan('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
  $$,
  '45000',
  'MAIN_EVENT_REQUIRED: Wedding must have a main event configured first.',
  'Calling generate_initial_plan on a wedding with no active main event must fail.'
);

-- Restore admin
RESET ROLE;

-- Insert Main Event for Wedding B (Expected Month)
INSERT INTO public.wedding_events (id, wedding_id, name, expected_year, expected_month, is_main_event)
VALUES (
  'dddddddd-2222-2222-2222-222222222222',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'Lễ cưới chính B',
  2026,
  12,
  true
);

-- Set back to authenticated user
SET ROLE authenticated;

-- 24. Success: First-time plan generation replayed = false
SELECT results_eq(
  $$
  SELECT (api_v1.generate_initial_plan('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') ->> 'replayed')::boolean;
  $$,
  $$
  VALUES (false);
  $$,
  'First plan generation must run and return replayed = false.'
);

-- 25. Success: Verify initial_plan_generated_at timestamp is set on weddings
SELECT results_eq(
  $$
  SELECT (initial_plan_generated_at IS NOT NULL) 
  FROM public.weddings 
  WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  $$,
  $$
  VALUES (true);
  $$,
  'initial_plan_generated_at timestamp must be set on the weddings table.'
);

-- 26. Success: Verify plan task generation content (VIETNAMESE template has 7 tasks)
SELECT results_eq(
  $$
  SELECT count(*)::integer 
  FROM public.tasks 
  WHERE wedding_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  $$,
  $$
  VALUES (7);
  $$,
  'Traditional Vietnamese plan generation should generate exactly 7 template tasks.'
);

-- 27. Success: Verify suggested event generation (VIETNAMESE template has 2 suggested events)
SELECT results_eq(
  $$
  SELECT count(*)::integer 
  FROM public.wedding_events 
  WHERE wedding_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
    AND is_main_event = false;
  $$,
  $$
  VALUES (2);
  $$,
  'Traditional Vietnamese plan generation should generate exactly 2 suggested events.'
);

-- 28. Success: Verify task is linked to suggested event (e.g. Prep mâm quả linked to Lễ ăn hỏi)
SELECT results_eq(
  $$
  SELECT e.name 
  FROM public.tasks t
  JOIN public.wedding_events e ON t.wedding_event_id = e.id
  WHERE t.wedding_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
    AND t.name = 'Chuẩn bị mâm quả & sính lễ đám hỏi';
  $$,
  $$
  VALUES ('Lễ ăn hỏi & đám hỏi'::varchar);
  $$,
  'Task must be linked to its corresponding suggested event in the template.'
);

-- 29. Success: Retry plan generation: replayed = true
SELECT results_eq(
  $$
  SELECT (api_v1.generate_initial_plan('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') ->> 'replayed')::boolean;
  $$,
  $$
  VALUES (true);
  $$,
  'Subsequent calls to generate_initial_plan must return replayed = true.'
);

-- 30. Success: Verify tasks count did not change (no duplication)
SELECT results_eq(
  $$
  SELECT count(*)::integer 
  FROM public.tasks 
  WHERE wedding_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  $$,
  $$
  VALUES (7);
  $$,
  'Subsequent replayed calls must not create duplicate plan tasks.'
);

-- 31. Success: Verify budget items count is 0 (table does not exist yet under DEC-B-001 / REQ-01)
SELECT hasnt_table(
  'public',
  'budget_items',
  'budget_items table must not exist yet, ensuring no budget items are created'
);

-- 32. Success: Replay after user modification: preserves current state
-- Modify one task's name
UPDATE public.tasks 
SET name = 'Chuẩn bị mâm quả - Modified' 
WHERE wedding_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' 
  AND name = 'Chuẩn bị mâm quả & sính lễ đám hỏi';

-- Trigger generate plan replay
SELECT results_eq(
  $$
  SELECT count(*)::integer 
  FROM jsonb_to_recordset(
    (api_v1.generate_initial_plan('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') -> 'tasks')
  ) AS x(name text)
  WHERE name = 'Chuẩn bị mâm quả - Modified';
  $$,
  $$
  VALUES (1);
  $$,
  'Plan replay returns current state and does not reconstruct the original template tasks.'
);

-- ===========================================================================
-- SECTION 7: PLANNING RLS TENANT ISOLATION TESTS
-- ===========================================================================

-- Create wedding C owned by User B only
RESET ROLE;
INSERT INTO public.weddings (id, name, exact_date)
VALUES ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Wedding C', '2026-10-10');
INSERT INTO public.wedding_members (id, wedding_id, user_id, role, status, display_name, profile_email)
VALUES (
  '66666666-6666-6666-6666-666666666666',
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  '22222222-2222-2222-2222-222222222222', -- User B is owner
  'OWNER',
  'ACTIVE',
  'USER B',
  'user.b@example.com'
);
INSERT INTO public.wedding_events (id, wedding_id, name, exact_date)
VALUES ('eeeeeeee-3333-3333-3333-333333333333', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'Ceremony C', '2026-10-10');

-- Back to User A
SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

-- 33. Tenant isolation: User A SELECT from events in C (must return 0 rows)
SELECT is(
  (SELECT count(*)::integer FROM public.wedding_events WHERE wedding_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  0,
  'RLS prevents members of Wedding A/B from reading events of Wedding C.'
);

-- 34. Tenant isolation: User A SELECT from tasks in C (must return 0 rows)
SELECT is(
  (SELECT count(*)::integer FROM public.tasks WHERE wedding_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  0,
  'RLS prevents members of Wedding A/B from reading tasks of Wedding C.'
);

-- 35. Cross-referencing: User A tries to insert task in Wedding A referencing Event in C (must throw violation)
SELECT throws_ok(
  $$
  INSERT INTO public.tasks (wedding_id, name, deadline_intent, date_offset, wedding_event_id)
  VALUES (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'Cross-referencing Task',
    'SYSTEM_RELATIVE',
    -30,
    'eeeeeeee-3333-3333-3333-333333333333' -- Event in Wedding C
  );
  $$,
  '23503', -- Foreign key violation SQLSTATE (fk_tasks_event_wedding)
  NULL,
  'Should reject insertion referencing a foreign key Event of another Wedding (cross-tenant integrity).'
);

-- ===========================================================================
-- SECTION 8: CLASS-B SIMPLE MUTATION ACCESS TESTS
-- ===========================================================================

-- 36. User A can insert a new USER task directly
SELECT lives_ok(
  $$
  INSERT INTO public.tasks (wedding_id, name, deadline_intent, side)
  VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'My Direct User Task', 'NO_DEADLINE', 'BRIDE_SIDE');
  $$,
  'Ordinary authenticated member can insert USER task directly under Class-B rules.'
);

-- 37. User A can UPDATE tasks fields (status, side, assignee, name)
SELECT lives_ok(
  $$
  UPDATE public.tasks 
  SET status = 'IN_PROGRESS', side = 'GROOM_SIDE'
  WHERE name = 'My Direct User Task';
  $$,
  'Ordinary authenticated member can update task fields directly under Class-B rules.'
);

-- 38. Direct DELETE is blocked (Client cannot delete task)
SELECT throws_ok(
  $$
  DELETE FROM public.tasks WHERE name = 'My Direct User Task';
  $$,
  '42501', -- Insufficient privilege / Policy check failed
  NULL,
  'Ordinary authenticated member cannot delete tasks directly via Class-B.'
);

SELECT * FROM finish();
ROLLBACK;
