BEGIN;
SELECT plan(42); -- 42 assertions for BATCH-03 (40 + 2 added for IMPL-CONFLICT-006 targeting audit)

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

-- 2. Create test wedding A (owned by user A)
INSERT INTO public.weddings (id, name, target_budget, cultural_context, exact_date)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Wedding A', 500000000, 'TUY_CHON', '2026-12-18')
ON CONFLICT (id) DO NOTHING;

-- 3. Create active member A (OWNER)
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

-- 4. Create member B (COLLABORATOR)
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

-- 5. Insert Main Event A (exact date)
INSERT INTO public.wedding_events (id, wedding_id, name, exact_date, is_main_event)
VALUES ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Lễ cưới chính A', '2026-12-18', true)
ON CONFLICT (id) DO NOTHING;

-- 6. Insert tasks: relative tasks linked to Event A, absolute task at wedding-level
INSERT INTO public.tasks (id, wedding_id, name, deadline_intent, date_offset, custom_override_date, wedding_event_id, task_source)
VALUES
  -- SYSTEM_RELATIVE: will recalculate on Exact changes
  ('f1111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'System Relative Task', 'SYSTEM_RELATIVE', -30, NULL, 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'SYSTEM_TEMPLATE'),
  -- USER_RELATIVE: will recalculate on Exact changes
  ('f2222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'User Relative Task', 'USER_RELATIVE', -45, NULL, 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'SYSTEM_TEMPLATE'),
  -- USER_ABSOLUTE: calendar-fixed, NEVER shifted by any event date change
  ('f3333333-3333-3333-3333-333333333333', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'User Absolute Task', 'USER_ABSOLUTE', NULL, '2026-12-01'::date, NULL, 'USER'),
  -- USER_RELATIVE (user-created, will go to preservation list on removal)
  ('f6666666-6666-6666-6666-666666666666', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'User Relative Preserved Task', 'USER_RELATIVE', -20, NULL, 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'USER');

-- 7. Add a completed relative task (status = COMPLETED, resolved_deadline_at set by trigger)
INSERT INTO public.tasks (id, wedding_id, name, deadline_intent, date_offset, wedding_event_id, task_source)
VALUES ('f4444444-4444-4444-4444-444444444444', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Completed Relative Task', 'SYSTEM_RELATIVE', -10, 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'SYSTEM_TEMPLATE');

UPDATE public.tasks SET status = 'COMPLETED' WHERE id = 'f4444444-4444-4444-4444-444444444444';

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

SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

-- 2. Preview Exact→Exact: must report 3 recalculated relative tasks (f1, f2, f6)
SELECT results_eq(
  $$
  SELECT jsonb_array_length(api_v1.preview_event_date_change('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '2026-12-20', NULL, NULL) -> 'recalculated_tasks');
  $$,
  $$
  VALUES (3);
  $$,
  'Preview Exact→Exact must report exactly 3 recalculated relative tasks.'
);

-- 3. Preview must report absolute_tasks_unchanged_count = 1 (f3 USER_ABSOLUTE, not touched)
SELECT results_eq(
  $$
  SELECT (api_v1.preview_event_date_change('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '2026-12-20', NULL, NULL) ->> 'absolute_tasks_unchanged_count')::integer;
  $$,
  $$
  VALUES (1);
  $$,
  'Preview must report absolute_tasks_unchanged_count = 1 (USER_ABSOLUTE tasks are informational only).'
);

-- 4. Preview Exact→Exact must report 1 completed preserved task (f4)
SELECT results_eq(
  $$
  SELECT jsonb_array_length(api_v1.preview_event_date_change('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '2026-12-20', NULL, NULL) -> 'preserved_tasks');
  $$,
  $$
  VALUES (1);
  $$,
  'Preview Exact→Exact must report 1 completed task in preserved_tasks.'
);

-- 5. Commit Exact→Exact: shift event by 2 days (2026-12-18 → 2026-12-20)
SELECT lives_ok(
  $$
  SELECT api_v1.commit_event_date_change(
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    '2026-12-20',
    NULL,
    NULL,
    api_v1.preview_event_date_change('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '2026-12-20', NULL, NULL) ->> 'impact_fingerprint'
  );
  $$,
  'Commit Exact→Exact date shift must succeed with valid fingerprint.'
);

-- 6. SYSTEM_RELATIVE task (f1, offset -30): resolved to 2026-12-20 - 30 = 2026-11-20
SELECT results_eq(
  $$
  SELECT resolved_deadline_at FROM public.tasks WHERE id = 'f1111111-1111-1111-1111-111111111111';
  $$,
  $$
  VALUES ('2026-11-20'::date);
  $$,
  'SYSTEM_RELATIVE task deadline recalculated correctly after Exact→Exact.'
);

-- 7. USER_ABSOLUTE task (f3): calendar-fixed, UNCHANGED at 2026-12-01
--    IMPL-CONFLICT-004 RESOLVED: no SHIFT batch action exists.
SELECT results_eq(
  $$
  SELECT custom_override_date FROM public.tasks WHERE id = 'f3333333-3333-3333-3333-333333333333';
  $$,
  $$
  VALUES ('2026-12-01'::date);
  $$,
  'USER_ABSOLUTE task must remain unchanged (2026-12-01) after Exact→Exact transition.'
);

-- 8. Completed task (f4, offset -10): resolved_deadline_at preserved as 2026-12-08 historical snapshot
SELECT results_eq(
  $$
  SELECT resolved_deadline_at FROM public.tasks WHERE id = 'f4444444-4444-4444-4444-444444444444';
  $$,
  $$
  VALUES ('2026-12-08'::date);
  $$,
  'Completed task resolved_deadline_at preserved as historical snapshot.'
);

-- 9. Commit Exact→Month: transition Event A to month-precision (2026, 12)
SELECT lives_ok(
  $$
  SELECT api_v1.commit_event_date_change(
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    NULL,
    2026,
    12,
    api_v1.preview_event_date_change('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', NULL, 2026, 12) ->> 'impact_fingerprint'
  );
  $$,
  'Commit Exact→Month precision transition must succeed.'
);

-- 10. Active relative tasks (f1, f2): resolved_deadline_at cleared to NULL (unresolved)
SELECT results_eq(
  $$
  SELECT count(*)::integer FROM public.tasks
  WHERE id IN ('f1111111-1111-1111-1111-111111111111', 'f2222222-2222-2222-2222-222222222222')
    AND resolved_deadline_at IS NOT NULL;
  $$,
  $$
  VALUES (0);
  $$,
  'Active relative tasks must clear operational deadline dates when event transitions to month-precision.'
);

-- 11. Completed task (f4): historical snapshot preserved (still 2026-12-08)
SELECT results_eq(
  $$
  SELECT resolved_deadline_at FROM public.tasks WHERE id = 'f4444444-4444-4444-4444-444444444444';
  $$,
  $$
  VALUES ('2026-12-08'::date);
  $$,
  'Completed task historical snapshot preserved when transitioning to month-precision.'
);

-- 12. USER_ABSOLUTE (f3): unchanged after Exact→Month. Calendar-fixed invariant verified.
SELECT results_eq(
  $$
  SELECT custom_override_date FROM public.tasks WHERE id = 'f3333333-3333-3333-3333-333333333333';
  $$,
  $$
  VALUES ('2026-12-01'::date);
  $$,
  'USER_ABSOLUTE task must remain unchanged (2026-12-01) after Exact→Month transition.'
);

-- 13. Commit Month→Exact: transition Event A back to exact date (2026-12-22)
SELECT lives_ok(
  $$
  SELECT api_v1.commit_event_date_change(
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    '2026-12-22',
    NULL,
    NULL,
    api_v1.preview_event_date_change('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '2026-12-22', NULL, NULL) ->> 'impact_fingerprint'
  );
  $$,
  'Month→Exact transition must succeed.'
);

-- 14. Relative task (f1): resolves to 2026-12-22 - 30 = 2026-11-22
SELECT results_eq(
  $$
  SELECT resolved_deadline_at FROM public.tasks WHERE id = 'f1111111-1111-1111-1111-111111111111';
  $$,
  $$
  VALUES ('2026-11-22'::date);
  $$,
  'Relative tasks must resolve exact operational due dates when event gains exact date.'
);

-- 15. USER_ABSOLUTE (f3): unchanged after Month→Exact. Calendar-fixed invariant verified.
SELECT results_eq(
  $$
  SELECT custom_override_date FROM public.tasks WHERE id = 'f3333333-3333-3333-3333-333333333333';
  $$,
  $$
  VALUES ('2026-12-01'::date);
  $$,
  'USER_ABSOLUTE task must remain unchanged (2026-12-01) after Month→Exact transition.'
);

-- ===========================================================================
-- SECTION 2B: MONTH→MONTH TRANSITION (USER_ABSOLUTE invariant)
-- ===========================================================================

-- Setup: commit Exact→Month first to get event into month precision
SELECT lives_ok(
  $$
  SELECT api_v1.commit_event_date_change(
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    NULL,
    2026,
    11,
    api_v1.preview_event_date_change('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', NULL, 2026, 11) ->> 'impact_fingerprint'
  );
  $$,
  'Commit Exact→Month (2026, 11): setup for Month→Month test.'
);

-- Now commit Month→Month (2026-11 → 2026-10)
SELECT lives_ok(
  $$
  SELECT api_v1.commit_event_date_change(
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    NULL,
    2026,
    10,
    api_v1.preview_event_date_change('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', NULL, 2026, 10) ->> 'impact_fingerprint'
  );
  $$,
  'Month→Month transition must succeed.'
);

-- 18. USER_ABSOLUTE (f3): unchanged after Month→Month. Calendar-fixed invariant verified.
SELECT results_eq(
  $$
  SELECT custom_override_date FROM public.tasks WHERE id = 'f3333333-3333-3333-3333-333333333333';
  $$,
  $$
  VALUES ('2026-12-01'::date);
  $$,
  'USER_ABSOLUTE task must remain unchanged (2026-12-01) after Month→Month transition.'
);

-- ===========================================================================
-- SECTION 3: REOPEN COMPLETED TASK BEHAVIOR
-- ===========================================================================

RESET ROLE;

-- Restore event to exact date for reopen test
UPDATE public.wedding_events
SET exact_date = '2026-12-25', expected_year = NULL, expected_month = NULL
WHERE id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';

-- Reopen completed task as client
SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

-- 19. Reopen relative task: trigger recalculates to current event date (2026-12-25 - 10 = 2026-12-15)
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
-- SECTION 4: EVT-002 POST-COMMIT RETRY IDEMPOTENCY
-- ===========================================================================

-- 20. Commit a date change
SELECT lives_ok(
  $$
  SELECT api_v1.commit_event_date_change(
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    '2026-12-28',
    NULL,
    NULL,
    api_v1.preview_event_date_change('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '2026-12-28', NULL, NULL) ->> 'impact_fingerprint'
  );
  $$,
  'EVT-002 retry setup: commit date change to 2026-12-28.'
);

-- 21. Retry the same commit: must return replayed = true (no double transformation)
SELECT results_eq(
  $$
  SELECT (api_v1.commit_event_date_change(
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    '2026-12-28',
    NULL,
    NULL,
    'any_fingerprint_value'
  ) ->> 'replayed')::boolean;
  $$,
  $$
  VALUES (true);
  $$,
  'EVT-002 post-commit retry with same target date must return replayed = true immediately.'
);

-- 22. After retry, relative task (f1, offset -30) unchanged at 2026-12-28 - 30 = 2026-11-28 (no double shift)
SELECT results_eq(
  $$
  SELECT resolved_deadline_at FROM public.tasks WHERE id = 'f1111111-1111-1111-1111-111111111111';
  $$,
  $$
  VALUES ('2026-11-28'::date);
  $$,
  'After EVT-002 retry, relative task deadline must not be shifted a second time.'
);

-- ===========================================================================
-- SECTION 5: CONCURRENT MODIFICATION FINGERPRINT STALE CHECKS
-- ===========================================================================

-- Mutate task concurrently to invalidate fingerprint
UPDATE public.tasks SET name = 'Modified Concurrently' WHERE id = 'f1111111-1111-1111-1111-111111111111';
RESET ROLE;
UPDATE public.tasks SET is_user_modified = true WHERE id = 'f1111111-1111-1111-1111-111111111111';
SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

-- 23. Commit with stale fingerprint must fail with STALE_IMPACT
SELECT throws_ok(
  $$
  SELECT api_v1.commit_event_date_change(
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    '2026-12-20',
    NULL,
    NULL,
    'stale_or_invalid_fingerprint_hash_code'
  );
  $$,
  '40001',
  'STALE_IMPACT: The planning workspace state has changed since the preview was generated.',
  'Commit must fail with STALE_IMPACT when fingerprint is invalid.'
);

-- ===========================================================================
-- SECTION 6: TOP-EVT-003 EVENT REMOVAL & INVARIANTS
-- ===========================================================================

-- 24. Fail: attempt to remove the final active Main Event
SELECT throws_ok(
  $$
  SELECT api_v1.commit_event_removal(
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    api_v1.preview_event_removal('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee') ->> 'impact_fingerprint'
  );
  $$,
  '45000',
  'FINAL_MAIN_EVENT_INVARIANT: Cannot remove the final active Main Event of the wedding.',
  'Should deny removing the final active Main Event of the wedding.'
);

-- Setup: create a second main event so the first can be removed
RESET ROLE;
INSERT INTO public.wedding_events (id, wedding_id, name, exact_date, is_main_event)
VALUES ('eeeeeeee-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Lễ cưới phụ A', '2026-12-25', false);

UPDATE public.wedding_events SET is_main_event = false WHERE id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
UPDATE public.wedding_events SET is_main_event = true WHERE id = 'eeeeeeee-2222-2222-2222-222222222222';

SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

-- 25. Preview event removal for Event A: server classifies deletion candidates
--     f2 (SYSTEM_TEMPLATE, is_user_modified=false) + f4 (SYSTEM_TEMPLATE, reopened, is_user_modified=false) = 2
SELECT results_eq(
  $$
  SELECT jsonb_array_length(api_v1.preview_event_removal('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee') -> 'deletion_candidates');
  $$,
  $$
  VALUES (2);
  $$,
  'Preview removal must identify 2 unmodified active system tasks as server-authoritative deletion candidates.'
);

-- 26. Preview removal: preservation tasks = f1 (user-modified), f6 (USER source) = 2
SELECT results_eq(
  $$
  SELECT jsonb_array_length(api_v1.preview_event_removal('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee') -> 'preservation_tasks');
  $$,
  $$
  VALUES (2);
  $$,
  'Preview removal must identify 2 user-created/modified tasks in preservation_tasks.'
);

-- 27. Commit removal of Event A (server-authoritative, no explicit_choices parameter)
SELECT lives_ok(
  $$
  SELECT api_v1.commit_event_removal(
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    api_v1.preview_event_removal('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee') ->> 'impact_fingerprint'
  );
  $$,
  'Event removal commit must succeed with valid fingerprint (no client explicit_choices).'
);

-- 28. Verify Event A is marked REMOVED
SELECT results_eq(
  $$
  SELECT lifecycle_status FROM public.wedding_events WHERE id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
  $$,
  $$
  VALUES ('REMOVED'::varchar);
  $$,
  'Removed event lifecycle status must be updated to REMOVED.'
);

-- 29. Verify unmodified system tasks (f2, f4) were deleted
SELECT results_eq(
  $$
  SELECT count(*)::integer FROM public.tasks WHERE id IN ('f2222222-2222-2222-2222-222222222222', 'f4444444-4444-4444-4444-444444444444');
  $$,
  $$
  VALUES (0);
  $$,
  'Unmodified active system tasks linked to removed event must be server-deleted.'
);

-- 30. Verify preserved active user-modified relative task (f1) is detached as USER_ABSOLUTE
--     f1: SYSTEM_RELATIVE, is_user_modified=true → preserved, detached, resolved at 2026-11-28 (from section 4)
SELECT results_eq(
  $$
  SELECT wedding_event_id, deadline_intent, custom_override_date, resolved_deadline_at
  FROM public.tasks
  WHERE id = 'f1111111-1111-1111-1111-111111111111';
  $$,
  $$
  VALUES (NULL::uuid, 'USER_ABSOLUTE'::varchar, '2026-11-28'::date, '2026-11-28'::date);
  $$,
  'User-modified relative task must be detached and converted to USER_ABSOLUTE with preserved resolved date.'
);

-- 31. Verify user-created task (f3): untouched (wedding_event_id was already NULL, calendar-fixed)
--     USER_ABSOLUTE: never shifted (IMPL-CONFLICT-004), remains at 2026-12-01
SELECT results_eq(
  $$
  SELECT wedding_event_id, deadline_intent, custom_override_date, resolved_deadline_at
  FROM public.tasks
  WHERE id = 'f3333333-3333-3333-3333-333333333333';
  $$,
  $$
  VALUES (NULL::uuid, 'USER_ABSOLUTE'::varchar, '2026-12-01'::date, '2026-12-01'::date);
  $$,
  'Wedding-level USER_ABSOLUTE task must be untouched by event removal (was never linked to the event).'
);

-- ===========================================================================
-- SECTION 7: BUDGET ITEMS PRESERVED AFTER EVENT REMOVAL (IMPL-GAP-003)
-- ===========================================================================

RESET ROLE;

-- Create budget_items table in this transaction scope (rolled back at end)
-- (No longer needed, budget_items is created in batch 11 and persists)
-- CREATE TABLE public.budget_items (
--   id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
--   wedding_id uuid,
--   wedding_event_id uuid
-- );

-- Grant access so SECURITY DEFINER functions (running as trusted_function_owner) can query it
-- GRANT SELECT, INSERT, UPDATE ON public.budget_items TO trusted_function_owner;

-- Insert a budget item linked to the NEW event (eeeeeeee-2222)
-- Since batch 11 added strict NOT NULL columns like name, side, status, etc., we must provide them
INSERT INTO public.budget_items (id, wedding_id, wedding_event_id, name, side, status)
VALUES ('b1111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'eeeeeeee-2222-2222-2222-222222222222', 'Test Venue', 'COMMON', 'ACTIVE');


-- Remove is_main_event from event 2222 so it can be deleted
UPDATE public.wedding_events SET is_main_event = false WHERE id = 'eeeeeeee-2222-2222-2222-222222222222';

-- Add another main event so we don't violate FINAL_MAIN_EVENT_INVARIANT
INSERT INTO public.wedding_events (id, wedding_id, name, exact_date, is_main_event)
VALUES ('eeeeeeee-5555-5555-5555-555555555555', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Lễ cưới thứ 3', '2026-12-30', true);

SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

SELECT api_v1.commit_event_removal(
  'eeeeeeee-2222-2222-2222-222222222222',
  api_v1.preview_event_removal('eeeeeeee-2222-2222-2222-222222222222') ->> 'impact_fingerprint'
);

-- Assertions run as superuser for test table access
RESET ROLE;

-- 32. BudgetItem record must still exist (preserved, not deleted)
SELECT results_eq(
  $$
  SELECT count(*)::integer FROM public.budget_items WHERE id = 'b1111111-1111-1111-1111-111111111111';
  $$,
  $$
  VALUES (1);
  $$,
  'BudgetItem must be preserved (not deleted) after event removal.'
);

-- 33. BudgetItem must be unlinked from event (wedding_event_id = NULL)
SELECT results_eq(
  $$
  SELECT wedding_event_id FROM public.budget_items WHERE id = 'b1111111-1111-1111-1111-111111111111';
  $$,
  $$
  VALUES (NULL::uuid);
  $$,
  'BudgetItem must have wedding_event_id = NULL after event removal (event link unlinked).'
);

-- ===========================================================================
-- SECTION 8: INVITATION TARGETING PRESERVED — IMPL-CONFLICT-006 RESOLVED
-- ===========================================================================
-- invitation_event_targetings approved Physical Design (Table 14):
--   ONLY: wedding_id, invitation_id, wedding_event_id — NO is_active.
-- On event REMOVAL: targeting row is preserved intact (no mutation).
-- Class D availability derives from WeddingEvent.lifecycle_status = 'ACTIVE',
-- not from any targeting flag.

RESET ROLE;

-- BATCH-07 now owns the real invitation_event_targetings table. Seed a valid
-- Invitation row so this historical M2A.2 preservation assertion exercises the
-- production schema rather than a test-only table.
INSERT INTO public.invitation_parties (id, wedding_id, display_name, invited_count)
VALUES (
  'cccccccc-3333-3333-3333-333333333333',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'M2A.2 targeting preservation party',
  2
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.invitations (id, wedding_id, invitation_party_id)
VALUES (
  'dddddddd-dddd-dddd-dddd-dddddddddddd',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'cccccccc-3333-3333-3333-333333333333'
)
ON CONFLICT (id) DO NOTHING;

-- Insert targeting row for event 5555 (targeting exists before removal)
INSERT INTO public.invitation_event_targetings (wedding_id, invitation_id, wedding_event_id)
VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'dddddddd-dddd-dddd-dddd-dddddddddddd',
  'eeeeeeee-5555-5555-5555-555555555555'
);

-- Need another main event so 5555 can be removed (must insert false first due to unique constraint)
INSERT INTO public.wedding_events (id, wedding_id, name, exact_date, is_main_event)
VALUES ('eeeeeeee-6666-6666-6666-666666666666', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Lễ cưới thứ 4', '2027-01-15', false);
UPDATE public.wedding_events SET is_main_event = false WHERE id = 'eeeeeeee-5555-5555-5555-555555555555';
UPDATE public.wedding_events SET is_main_event = true WHERE id = 'eeeeeeee-6666-6666-6666-666666666666';

SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

SELECT api_v1.commit_event_removal(
  'eeeeeeee-5555-5555-5555-555555555555',
  api_v1.preview_event_removal('eeeeeeee-5555-5555-5555-555555555555') ->> 'impact_fingerprint'
);

-- All targeting assertions run as superuser for test table access
RESET ROLE;

-- 34. Targeting row must still exist (historical relationship preserved, not deleted or mutated)
SELECT results_eq(
  $$
  SELECT count(*)::integer FROM public.invitation_event_targetings
  WHERE wedding_event_id = 'eeeeeeee-5555-5555-5555-555555555555';
  $$,
  $$
  VALUES (1);
  $$,
  'IMPL-CONFLICT-006: Invitation targeting row must be preserved (not deleted or mutated) after event removal.'
);

-- 35. Event lifecycle_status must be REMOVED (the authoritative availability gate for Class D)
SELECT results_eq(
  $$
  SELECT lifecycle_status FROM public.wedding_events WHERE id = 'eeeeeeee-5555-5555-5555-555555555555';
  $$,
  $$
  VALUES ('REMOVED'::varchar);
  $$,
  'IMPL-CONFLICT-006: Event lifecycle_status = REMOVED is the Class D availability gate, not a targeting flag.'
);

-- 35B. Active-target resolver (Class D equivalent): JOIN with lifecycle_status = ACTIVE
--      must return 0 rows for the REMOVED event (correct filtering without is_active).
SELECT results_eq(
  $$
  SELECT count(*)::integer
  FROM public.invitation_event_targetings iet
  JOIN public.wedding_events we ON we.id = iet.wedding_event_id
  WHERE iet.wedding_event_id = 'eeeeeeee-5555-5555-5555-555555555555'
    AND we.lifecycle_status = 'ACTIVE';
  $$,
  $$
  VALUES (0);
  $$,
  'IMPL-CONFLICT-006: Class D active-target resolver (lifecycle_status=ACTIVE join) must exclude REMOVED events.'
);

-- 36. Schema validation: invitation_event_targetings must have NO is_active column
SELECT results_eq(
  $$
  SELECT count(*)::integer
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'invitation_event_targetings'
    AND column_name = 'is_active';
  $$,
  $$
  VALUES (0);
  $$,
  'IMPL-CONFLICT-006: invitation_event_targetings must have no is_active column (not in approved Physical Design).'
);

-- ===========================================================================
-- SECTION 9: MONTH-PRECISION EVENT REMOVAL (NO_DEADLINE)
-- ===========================================================================

RESET ROLE;

-- Setup Event B: month precision, non-main
INSERT INTO public.wedding_events (id, wedding_id, name, expected_year, expected_month, is_main_event)
VALUES ('eeeeeeee-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Lễ phụ tháng', 2026, 12, false);

-- Relative task with no resolved date (month-precision event → unresolved deadline)
INSERT INTO public.tasks (id, wedding_id, name, deadline_intent, date_offset, wedding_event_id, task_source)
VALUES ('f5555555-5555-5555-5555-555555555555', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Month Precision Preserved Task', 'SYSTEM_RELATIVE', -15, 'eeeeeeee-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'SYSTEM_TEMPLATE');

-- Mark this task user-modified so it is preserved, not deleted
UPDATE public.tasks SET is_user_modified = true WHERE id = 'f5555555-5555-5555-5555-555555555555';

SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

SELECT api_v1.commit_event_removal(
  'eeeeeeee-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  api_v1.preview_event_removal('eeeeeeee-bbbb-bbbb-bbbb-bbbbbbbbbbbb') ->> 'impact_fingerprint'
);

-- 36. Month precision relative task (no resolved date): detach and convert to NO_DEADLINE
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
-- SECTION 10: EVT-003 POST-COMMIT RETRY IDEMPOTENCY
-- ===========================================================================

-- 37. Retry commit removal on already-REMOVED event (eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee): replayed = true
SELECT results_eq(
  $$
  SELECT (api_v1.commit_event_removal('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'any_fingerprint') ->> 'replayed')::boolean;
  $$,
  $$
  VALUES (true);
  $$,
  'EVT-003 post-commit retry on already REMOVED event must return replayed = true immediately.'
);

-- 38. After retry, task count in wedding A must be stable (no additional tasks deleted)
--     Expected: f3 (USER_ABSOLUTE, wedding-level) + f6 (detached from event A removal) + f5555 (detached from bbbb removal)
SELECT results_eq(
  $$
  SELECT count(*)::integer FROM public.tasks WHERE wedding_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  $$,
  $$
  VALUES (4);
  $$,
  'After EVT-003 retry, task count must remain stable (no additional deletions on retry).'
);

-- ===========================================================================
-- SECTION 11: RLS TENANT ISOLATION (M1 & M2A.1 INTEGRITY)
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

INSERT INTO public.wedding_events (id, wedding_id, name, exact_date, is_main_event)
VALUES ('eeeeeeee-3333-3333-3333-333333333333', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Ceremony B', '2026-10-10', true);

INSERT INTO public.tasks (id, wedding_id, name, deadline_intent, date_offset, wedding_event_id, task_source)
VALUES ('f9999999-9999-9999-9999-999999999999', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Task B', 'SYSTEM_RELATIVE', -10, 'eeeeeeee-3333-3333-3333-333333333333', 'SYSTEM_TEMPLATE');

-- Add User A to Wedding B as COLLABORATOR (so User A has membership in BOTH A and B)
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

SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

-- 39. User A can see Wedding B events (they are a member of B)
SELECT is(
  (SELECT count(*)::integer FROM public.wedding_events WHERE wedding_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  1,
  'User A has access to B because they are member in B.'
);

-- Remove User A from Wedding B and verify isolation
RESET ROLE;
DELETE FROM public.wedding_members WHERE id = '12121212-1212-1212-1212-121212121212';

SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

-- 40. RLS: User A now blocked from Wedding B events
SELECT is(
  (SELECT count(*)::integer FROM public.wedding_events WHERE wedding_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  0,
  'RLS blocks access to other wedding events if not member.'
);

SELECT * FROM finish();
ROLLBACK;
