BEGIN;
SELECT plan(32);

-- ---------------------------------------------------------------------------
-- 0. TEST SETUP
-- ---------------------------------------------------------------------------
SELECT set_config('role', 'postgres', true);
INSERT INTO auth.users (id, email) VALUES ('aaaaaaa1-1111-1111-1111-111111111111', 'owner@test.com') ON CONFLICT DO NOTHING;
INSERT INTO auth.users (id, email) VALUES ('bbbbbbb2-2222-2222-2222-222222222222', 'collab@test.com') ON CONFLICT DO NOTHING;
INSERT INTO auth.users (id, email) VALUES ('ccccccc3-3333-3333-3333-333333333333', 'outsider@test.com') ON CONFLICT DO NOTHING;

INSERT INTO public.weddings (id, name, status, exact_date, target_budget) VALUES ('c0a1a1a1-1111-1111-1111-111111111111', 'Test Wedding', 'ACTIVE', '2026-12-01', 500000.00) ON CONFLICT DO NOTHING;
INSERT INTO public.wedding_members (id, wedding_id, user_id, display_name, profile_email, role, status) VALUES
  ('d1111111-1111-1111-1111-111111111111', 'c0a1a1a1-1111-1111-1111-111111111111', 'aaaaaaa1-1111-1111-1111-111111111111', 'Owner', 'owner@test.com', 'OWNER', 'ACTIVE'),
  ('d2222222-2222-2222-2222-222222222222', 'c0a1a1a1-1111-1111-1111-111111111111', 'bbbbbbb2-2222-2222-2222-222222222222', 'Collab', 'collab@test.com', 'COLLABORATOR', 'ACTIVE')
ON CONFLICT DO NOTHING;

-- Create BudgetItem
INSERT INTO public.budget_items (id, wedding_id, name, estimated_cost, confirmed_cost, side, status) VALUES 
  ('22222222-2222-2222-2222-222222222222', 'c0a1a1a1-1111-1111-1111-111111111111', 'Venue', 10000.00, 12000.00, 'COMMON', 'ACTIVE');

-- Create Installment
INSERT INTO public.installments (id, budget_item_id, amount, due_date, status) VALUES 
  ('33333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222', 5000.00, '2026-12-01', 'PENDING');

-- ---------------------------------------------------------------------------
-- 1. SECURITY & RLS TESTS
-- ---------------------------------------------------------------------------
SELECT set_config('role', 'authenticated', true);
SELECT set_config('request.jwt.claims', '{"sub": "aaaaaaa1-1111-1111-1111-111111111111"}', true); -- Owner

SELECT results_eq(
  'SELECT name FROM public.budget_items WHERE id = ''22222222-2222-2222-2222-222222222222''',
  ARRAY['Venue'::varchar],
  'Owner can read budget items'
);

SELECT set_config('request.jwt.claims', '{"sub": "bbbbbbb2-2222-2222-2222-222222222222"}', true); -- Collab
SELECT is_empty(
  'SELECT name FROM public.budget_items WHERE id = ''22222222-2222-2222-2222-222222222222''',
  'Collaborator cannot read budget items (Deny sensitive)'
);

SELECT set_config('request.jwt.claims', '{"sub": "ccccccc3-3333-3333-3333-333333333333"}', true); -- Outsider
SELECT is_empty(
  'SELECT name FROM public.budget_items WHERE id = ''22222222-2222-2222-2222-222222222222''',
  'Outsider cannot read budget items'
);

-- ---------------------------------------------------------------------------
-- 2. DIRECT CUD SECURITY
-- ---------------------------------------------------------------------------
SELECT set_config('request.jwt.claims', '{"sub": "aaaaaaa1-1111-1111-1111-111111111111"}', true); -- Owner

SELECT throws_ok(
  'INSERT INTO public.payments (id, budget_item_id, installment_id, amount, payment_date, payer_wedding_member_id, status) VALUES (gen_random_uuid(), ''22222222-2222-2222-2222-222222222222'', ''33333333-3333-3333-3333-333333333333'', 100, current_date, ''d1111111-1111-1111-1111-111111111111'', ''ACTIVE'')',
  '42501', -- Insufficient privilege
  NULL,
  'Authenticated cannot INSERT payment directly'
);

SELECT throws_ok(
  'UPDATE public.payments SET amount = 200',
  '42501',
  NULL,
  'Authenticated cannot UPDATE payment directly'
);

SELECT throws_ok(
  'DELETE FROM public.payments',
  '42501',
  NULL,
  'Authenticated cannot DELETE payment directly'
);

SELECT throws_ok(
  'INSERT INTO public.refunds (id, budget_item_id, amount, refund_date, receiver, status) VALUES (gen_random_uuid(), ''22222222-2222-2222-2222-222222222222'', 100, current_date, ''Test Receiver'', ''ACTIVE'')',
  '42501',
  NULL,
  'Authenticated cannot INSERT refund directly'
);

SELECT throws_ok(
  'UPDATE public.refunds SET amount = 200',
  '42501',
  NULL,
  'Authenticated cannot UPDATE refund directly'
);

SELECT throws_ok(
  'DELETE FROM public.refunds',
  '42501',
  NULL,
  'Authenticated cannot DELETE refund directly'
);

-- ---------------------------------------------------------------------------
-- 3. DELETE GUARDS
-- ---------------------------------------------------------------------------
-- Delete fails because installment exists
SELECT throws_ok(
  'DELETE FROM public.budget_items WHERE id = ''22222222-2222-2222-2222-222222222222''',
  'P0003',
  'Cannot delete budget item with financial history',
  'Delete guard blocks BudgetItem delete if installment exists'
);

-- Create a dummy refund using SUPERUSER (bypass CUD for test setup)
SELECT set_config('role', 'postgres', true);
INSERT INTO public.refunds (id, budget_item_id, amount, refund_date, receiver, status) VALUES 
  ('55555555-5555-5555-5555-555555555555', '22222222-2222-2222-2222-222222222222', 100, current_date, 'Test Receiver', 'ACTIVE');
SELECT set_config('role', 'authenticated', true);

SELECT throws_ok(
  'DELETE FROM public.budget_items WHERE id = ''22222222-2222-2222-2222-222222222222''',
  'P0003',
  'Cannot delete budget item with financial history',
  'Delete guard blocks BudgetItem delete if refund exists'
);

-- Delete dummy refund
SELECT set_config('role', 'postgres', true);
DELETE FROM public.refunds WHERE id = '55555555-5555-5555-5555-555555555555';
SELECT set_config('role', 'authenticated', true);

-- Delete installment is fine (no payments yet)
SELECT lives_ok(
  'DELETE FROM public.installments WHERE id = ''33333333-3333-3333-3333-333333333333''',
  'Installment can be deleted if no payments exist'
);

-- Now deleting budget item is fine
SELECT lives_ok(
  'DELETE FROM public.budget_items WHERE id = ''22222222-2222-2222-2222-222222222222''',
  'BudgetItem can be deleted if no history'
);

-- Re-insert for further tests
SELECT set_config('role', 'postgres', true);
INSERT INTO public.budget_items (id, wedding_id, name, estimated_cost, confirmed_cost, side, status) VALUES 
  ('22222222-2222-2222-2222-222222222222', 'c0a1a1a1-1111-1111-1111-111111111111', 'Venue', 10000.00, 12000.00, 'COMMON', 'ACTIVE');
INSERT INTO public.installments (id, budget_item_id, amount, due_date, status) VALUES 
  ('33333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222', 5000.00, current_date, 'PENDING');
SELECT set_config('role', 'authenticated', true);

-- ---------------------------------------------------------------------------
-- 4. FIN-001 & RECEIPTS
-- ---------------------------------------------------------------------------
SELECT lives_ok(
  $$SELECT api_v1.create_payment('44444444-4444-4444-4444-444444444444', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 1000.00, '2026-08-01', 'd1111111-1111-1111-1111-111111111111', NULL, 'Notes')$$,
  'FIN-001 create_payment succeeds'
);

SELECT results_eq(
  $$SELECT (api_v1.create_payment('44444444-4444-4444-4444-444444444444', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 1000.00, '2026-08-01', 'd1111111-1111-1111-1111-111111111111', NULL, 'Notes')->>'replayed')::boolean$$,
  ARRAY[true],
  'FIN-001 replay succeeds'
);

SELECT throws_ok(
  $$SELECT api_v1.create_payment('44444444-4444-4444-4444-444444444444', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 2000.00, '2026-08-01', 'd1111111-1111-1111-1111-111111111111', NULL, 'Notes')$$,
  '40900',
  'REQUEST_ID_REUSED',
  'FIN-001 REQUEST_ID_REUSED on payload change'
);

SELECT throws_ok(
  'DELETE FROM public.installments WHERE id = ''33333333-3333-3333-3333-333333333333''',
  'P0003',
  'Cannot delete installment with payment history',
  'Installment delete guard blocks if payment exists'
);

-- ---------------------------------------------------------------------------
-- 5. MONEY PRECISION
-- ---------------------------------------------------------------------------
SELECT lives_ok(
  $$SELECT api_v1.create_payment(gen_random_uuid(), '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 0.10, '2026-08-01', 'd1111111-1111-1111-1111-111111111111', NULL, 'Small')$$,
  'Payment with 0.10 succeeds'
);

SELECT lives_ok(
  $$SELECT api_v1.create_payment(gen_random_uuid(), '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 999999999999.99, '2026-08-01', 'd1111111-1111-1111-1111-111111111111', NULL, 'Huge')$$,
  'Payment with 999999999999.99 succeeds'
);

-- Reset amounts for aggregate tests
SELECT set_config('role', 'postgres', true);
DELETE FROM public.payments WHERE amount = 0.10 OR amount = 999999999999.99;
UPDATE public.installments SET status = 'PENDING' WHERE id = '33333333-3333-3333-3333-333333333333';
SELECT set_config('role', 'authenticated', true);

-- ---------------------------------------------------------------------------
-- 6. FINANCE AGGREGATE VIEW
-- ---------------------------------------------------------------------------
SELECT results_eq(
  'SELECT net_paid FROM public.finance_summaries WHERE wedding_id = ''c0a1a1a1-1111-1111-1111-111111111111''',
  ARRAY[1000.00::numeric(15,2)],
  'Aggregate VIEW Net Paid is correct'
);

SELECT results_eq(
  'SELECT total_confirmed FROM public.finance_summaries WHERE wedding_id = ''c0a1a1a1-1111-1111-1111-111111111111''',
  ARRAY[12000.00::numeric(15,2)],
  'Aggregate VIEW Total Confirmed is correct'
);

SELECT results_eq(
  'SELECT outstanding FROM public.finance_summaries WHERE wedding_id = ''c0a1a1a1-1111-1111-1111-111111111111''',
  ARRAY[11000.00::numeric(15,2)],
  'Aggregate VIEW Outstanding is correct'
);

SELECT results_eq(
  'SELECT upcoming_7d FROM public.finance_summaries WHERE wedding_id = ''c0a1a1a1-1111-1111-1111-111111111111''',
  ARRAY[4000.00::numeric(15,2)], -- 5000 installment - 1000 paid
  'Aggregate VIEW upcoming_7d is correct'
);

SELECT results_eq(
  'SELECT target_budget FROM public.finance_summaries WHERE wedding_id = ''c0a1a1a1-1111-1111-1111-111111111111''',
  ARRAY[500000.00::numeric(15,2)],
  'Aggregate VIEW target_budget is correctly returned'
);

-- ---------------------------------------------------------------------------
-- 6b. VIEW SECURITY VISIBILITY BOUNDARIES
-- ---------------------------------------------------------------------------
-- Collaborator cannot read summaries (0 rows)
SELECT set_config('role', 'authenticated', true);
SELECT set_config('request.jwt.claims', '{"sub": "bbbbbbb2-2222-2222-2222-222222222222"}', true); -- Collab
SELECT is_empty(
  'SELECT * FROM public.finance_summaries WHERE wedding_id = ''c0a1a1a1-1111-1111-1111-111111111111''',
  'Collaborator sees 0 rows in finance_summaries'
);

-- Outsider cannot read summaries (0 rows)
SELECT set_config('request.jwt.claims', '{"sub": "ccccccc3-3333-3333-3333-333333333333"}', true); -- Outsider
SELECT is_empty(
  'SELECT * FROM public.finance_summaries WHERE wedding_id = ''c0a1a1a1-1111-1111-1111-111111111111''',
  'Outsider sees 0 rows in finance_summaries'
);

-- Anon cannot read summaries (permission denied)
SELECT set_config('role', 'anon', true);
SELECT set_config('request.jwt.claims', null, true);
SELECT throws_ok(
  'SELECT * FROM public.finance_summaries WHERE wedding_id = ''c0a1a1a1-1111-1111-1111-111111111111''',
  '42501',
  NULL,
  'Anon sees permission denied on finance_summaries'
);

-- Cross-Wedding OWNER cannot read another wedding summaries
SELECT set_config('role', 'postgres', true);
INSERT INTO public.weddings (id, name, status, exact_date, target_budget) 
  VALUES ('c0a1a1a2-2222-2222-2222-222222222222', 'Wedding 2', 'ACTIVE', '2027-01-01', 600000.00) ON CONFLICT DO NOTHING;
INSERT INTO auth.users (id, email) VALUES ('aaaaaaa2-2222-2222-2222-222222222222', 'owner2@test.com') ON CONFLICT DO NOTHING;
INSERT INTO public.wedding_members (id, wedding_id, user_id, display_name, profile_email, role, status) VALUES
  ('d3333333-3333-3333-3333-333333333333', 'c0a1a1a2-2222-2222-2222-222222222222', 'aaaaaaa2-2222-2222-2222-222222222222', 'Owner 2', 'owner2@test.com', 'OWNER', 'ACTIVE')
ON CONFLICT DO NOTHING;

SELECT set_config('role', 'authenticated', true);
SELECT set_config('request.jwt.claims', '{"sub": "aaaaaaa2-2222-2222-2222-222222222222"}', true); -- Owner 2
SELECT is_empty(
  'SELECT * FROM public.finance_summaries WHERE wedding_id = ''c0a1a1a1-1111-1111-1111-111111111111''',
  'Owner 2 cannot see Wedding 1 summaries'
);

-- Restore Owner 1 role
SELECT set_config('request.jwt.claims', '{"sub": "aaaaaaa1-1111-1111-1111-111111111111"}', true);

-- ---------------------------------------------------------------------------
-- 7. FIN-007 PREVIEW & COMMIT
-- ---------------------------------------------------------------------------
SELECT results_eq(
  $$SELECT (api_v1.preview_installment_compound('33333333-3333-3333-3333-333333333333', 6000.00)->>'proposed_amount')::numeric$$,
  ARRAY[6000.00::numeric],
  'FIN-007 Preview proposed_amount'
);

SELECT set_config('vars.fp', (api_v1.preview_installment_compound('33333333-3333-3333-3333-333333333333', 6000.00)->>'impact_fingerprint'), false);

SELECT lives_ok(
  $$SELECT api_v1.commit_installment_compound('33333333-3333-3333-3333-333333333333', current_setting('vars.fp'), 6000.00)$$,
  'FIN-007 Commit succeeds with correct fingerprint'
);

SELECT results_eq(
  'SELECT amount FROM public.installments WHERE id = ''33333333-3333-3333-3333-333333333333''',
  ARRAY[6000.00::numeric],
  'FIN-007 Commit correctly updated amount'
);

SELECT throws_ok(
  $$SELECT api_v1.commit_installment_compound('33333333-3333-3333-3333-333333333333', 'bad-fingerprint', 7000.00)$$,
  '40901',
  'STALE_IMPACT',
  'FIN-007 Commit fails on stale fingerprint'
);

SELECT * FROM finish();
ROLLBACK;
