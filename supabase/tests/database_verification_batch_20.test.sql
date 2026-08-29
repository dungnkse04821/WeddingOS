BEGIN;
SELECT plan(26);

INSERT INTO auth.users (id, email) VALUES
  ('20000000-0000-0000-0000-000000000001', 'm85b-delete-owner@test.local'),
  ('20000000-0000-0000-0000-000000000002', 'm85b-delete-collaborator@test.local')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.weddings (id, name, cultural_context, exact_date, status)
VALUES
  ('20010000-0000-0000-0000-000000000001', 'M85B Full Graph', 'TUY_CHON', '2027-11-01', 'ACTIVE'),
  ('20010000-0000-0000-0000-000000000002', 'M85B Active Finalize Denied', 'TUY_CHON', '2027-11-02', 'ACTIVE'),
  ('20010000-0000-0000-0000-000000000003', 'M85B Unrelated', 'TUY_CHON', '2027-11-03', 'ACTIVE');

INSERT INTO public.wedding_members (id, wedding_id, user_id, display_name, profile_email, role, status)
VALUES
  ('20020000-0000-0000-0000-000000000001', '20010000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'Delete Owner', 'm85b-delete-owner@test.local', 'OWNER', 'ACTIVE'),
  ('20020000-0000-0000-0000-000000000002', '20010000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002', 'Delete Collaborator', 'm85b-delete-collaborator@test.local', 'COLLABORATOR', 'ACTIVE'),
  ('20020000-0000-0000-0000-000000000003', '20010000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', 'Delete Owner', 'm85b-delete-owner@test.local', 'OWNER', 'ACTIVE'),
  ('20020000-0000-0000-0000-000000000004', '20010000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002', 'Unrelated Owner', 'm85b-delete-collaborator@test.local', 'OWNER', 'ACTIVE');

INSERT INTO public.wedding_events (id, wedding_id, name, exact_date, lifecycle_status, is_main_event)
VALUES
  ('20030000-0000-0000-0000-000000000001', '20010000-0000-0000-0000-000000000001', 'Full Graph Event', '2027-11-01', 'ACTIVE', true),
  ('20030000-0000-0000-0000-000000000002', '20010000-0000-0000-0000-000000000003', 'Unrelated Event', '2027-11-03', 'ACTIVE', true);

INSERT INTO public.invitation_parties (id, wedding_id, display_name, invited_count)
VALUES ('20040000-0000-0000-0000-000000000001', '20010000-0000-0000-0000-000000000001', 'Full Graph Party', 1);

INSERT INTO public.primary_groups (id, wedding_id, name)
VALUES ('20041000-0000-0000-0000-000000000001', '20010000-0000-0000-0000-000000000001', 'Full Graph Group');

INSERT INTO public.guests (id, wedding_id, invitation_party_id, primary_group_id, name)
VALUES ('20050000-0000-0000-0000-000000000001', '20010000-0000-0000-0000-000000000001', '20040000-0000-0000-0000-000000000001', '20041000-0000-0000-0000-000000000001', 'Full Graph Guest');

INSERT INTO public.invitations (id, wedding_id, invitation_party_id, status)
VALUES ('20060000-0000-0000-0000-000000000001', '20010000-0000-0000-0000-000000000001', '20040000-0000-0000-0000-000000000001', 'DRAFT');

INSERT INTO public.invitation_event_targetings (wedding_id, invitation_id, wedding_event_id)
VALUES ('20010000-0000-0000-0000-000000000001', '20060000-0000-0000-0000-000000000001', '20030000-0000-0000-0000-000000000001');

INSERT INTO public.invitation_credentials (id, invitation_id, token_hash, is_active, revoked_at)
VALUES
  ('20070000-0000-0000-0000-000000000001', '20060000-0000-0000-0000-000000000001', extensions.digest('m85b-full-graph-old', 'sha256'), false, now()),
  ('20070000-0000-0000-0000-000000000002', '20060000-0000-0000-0000-000000000001', extensions.digest('m85b-full-graph-active', 'sha256'), true, NULL);

INSERT INTO public.rsvps (id, invitation_id)
VALUES ('20080000-0000-0000-0000-000000000001', '20060000-0000-0000-0000-000000000001');

INSERT INTO public.event_responses (id, rsvp_id, wedding_event_id, is_attending, attending_count)
VALUES ('20090000-0000-0000-0000-000000000001', '20080000-0000-0000-0000-000000000001', '20030000-0000-0000-0000-000000000001', true, 1);

INSERT INTO public.tasks (id, wedding_id, wedding_event_id, name, status, deadline_intent, date_offset, task_source, side)
VALUES
  ('20100000-0000-0000-0000-000000000001', '20010000-0000-0000-0000-000000000001', '20030000-0000-0000-0000-000000000001', 'Full Graph Task', 'TODO', 'USER_RELATIVE', 1, 'USER', 'COMMON'),
  ('20100000-0000-0000-0000-000000000002', '20010000-0000-0000-0000-000000000003', '20030000-0000-0000-0000-000000000002', 'Unrelated Task', 'TODO', 'USER_RELATIVE', 1, 'USER', 'COMMON');

INSERT INTO public.budget_items (id, wedding_id, wedding_event_id, name, estimated_cost, status, side)
VALUES ('20110000-0000-0000-0000-000000000001', '20010000-0000-0000-0000-000000000001', '20030000-0000-0000-0000-000000000001', 'Full Graph Budget', 100.00, 'ACTIVE', 'COMMON');

INSERT INTO public.installments (id, budget_item_id, amount, due_date, status)
VALUES ('20120000-0000-0000-0000-000000000001', '20110000-0000-0000-0000-000000000001', 100.00, '2027-10-01', 'PENDING');

INSERT INTO public.payments (id, budget_item_id, installment_id, amount, payment_date, payer_display_name, status)
VALUES ('20130000-0000-0000-0000-000000000001', '20110000-0000-0000-0000-000000000001', '20120000-0000-0000-0000-000000000001', 100.00, '2027-10-01', 'Fixture Payer', 'ACTIVE');

INSERT INTO public.refunds (id, budget_item_id, amount, refund_date, receiver, status)
VALUES ('20140000-0000-0000-0000-000000000001', '20110000-0000-0000-0000-000000000001', 1.00, '2027-10-02', 'Fixture Receiver', 'ACTIVE');

INSERT INTO private.trusted_operation_receipts (id, operation_type, actor_user_id, request_id, wedding_id, request_hash)
VALUES ('20150000-0000-0000-0000-000000000001', 'M85B-FULL-GRAPH', '20000000-0000-0000-0000-000000000001', '20160000-0000-0000-0000-000000000001', '20010000-0000-0000-0000-000000000001', repeat('a', 64));

SELECT is(
  (SELECT confdeltype FROM pg_constraint WHERE conname = 'event_responses_wedding_event_id_fkey'),
  'r',
  'RSVP response/Event same-graph RESTRICT semantics remain unchanged.'
);

SET ROLE service_role;
SELECT throws_ok(
  $$SELECT edge_api.finalize_wedding_delete('20010000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001')$$,
  '42501', NULL, 'Non-DELETING Wedding cannot finalize.'
);
SELECT is(
  edge_api.begin_wedding_delete('20010000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001')->>'status',
  'DELETING',
  'Full Guest/Invitation/RSVP graph enters DELETING through the service-only bridge.'
);
SELECT throws_ok(
  $$SELECT edge_api.finalize_wedding_delete('20010000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002')$$,
  '42501', NULL, 'Wrong actor cannot finalize the deleting Wedding.'
);
SELECT is(
  edge_api.finalize_wedding_delete('20010000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001')->>'status',
  'DELETED',
  'Dependency-ordered trusted finalizer succeeds for the populated full graph.'
);

RESET ROLE;
SELECT is((SELECT count(*) FROM public.weddings WHERE id = '20010000-0000-0000-0000-000000000001'), 0::bigint, 'Wedding root is removed.');
SELECT is((SELECT count(*) FROM public.guests WHERE id = '20050000-0000-0000-0000-000000000001'), 0::bigint, 'Guest is purged.');
SELECT is((SELECT count(*) FROM public.invitation_parties WHERE id = '20040000-0000-0000-0000-000000000001'), 0::bigint, 'InvitationParty is purged.');
SELECT is((SELECT count(*) FROM public.primary_groups WHERE id = '20041000-0000-0000-0000-000000000001'), 0::bigint, 'PrimaryGroup is purged.');
SELECT is((SELECT count(*) FROM public.invitations WHERE id = '20060000-0000-0000-0000-000000000001'), 0::bigint, 'Invitation is purged.');
SELECT is((SELECT count(*) FROM public.invitation_credentials WHERE invitation_id = '20060000-0000-0000-0000-000000000001'), 0::bigint, 'Active and revoked invitation credential history is purged.');
SELECT is((SELECT count(*) FROM public.rsvps WHERE id = '20080000-0000-0000-0000-000000000001'), 0::bigint, 'RSVP is purged.');
SELECT is((SELECT count(*) FROM public.event_responses WHERE id = '20090000-0000-0000-0000-000000000001'), 0::bigint, 'RSVP EventResponse is purged before its Event.');
SELECT is((SELECT count(*) FROM public.invitation_event_targetings WHERE invitation_id = '20060000-0000-0000-0000-000000000001'), 0::bigint, 'Invitation targeting is purged.');
SELECT is((SELECT count(*) FROM public.wedding_events WHERE id = '20030000-0000-0000-0000-000000000001'), 0::bigint, 'WeddingEvent is purged after Task, Budget, and RSVP response dependencies.');
SELECT is((SELECT count(*) FROM public.tasks WHERE id = '20100000-0000-0000-0000-000000000001'), 0::bigint, 'Task/Event RESTRICT branch is purged.');
SELECT is((SELECT count(*) FROM public.budget_items WHERE id = '20110000-0000-0000-0000-000000000001'), 0::bigint, 'Budget/Event RESTRICT branch is purged.');
SELECT is((SELECT count(*) FROM public.installments WHERE id = '20120000-0000-0000-0000-000000000001'), 0::bigint, 'Installment is purged.');
SELECT is((SELECT count(*) FROM public.payments WHERE id = '20130000-0000-0000-0000-000000000001'), 0::bigint, 'Payment/Budget RESTRICT branch is purged.');
SELECT is((SELECT count(*) FROM public.refunds WHERE id = '20140000-0000-0000-0000-000000000001'), 0::bigint, 'Refund/Budget RESTRICT branch is purged.');
SELECT is((SELECT count(*) FROM public.wedding_members WHERE wedding_id = '20010000-0000-0000-0000-000000000001'), 0::bigint, 'Wedding memberships are purged.');
SELECT is((SELECT count(*) FROM private.trusted_operation_receipts WHERE wedding_id = '20010000-0000-0000-0000-000000000001'), 0::bigint, 'Wedding trusted-operation receipts are purged.');
SELECT is((SELECT count(*) FROM public.weddings WHERE id = '20010000-0000-0000-0000-000000000003'), 1::bigint, 'Unrelated Wedding remains.');
SELECT is((SELECT count(*) FROM public.tasks WHERE id = '20100000-0000-0000-0000-000000000002'), 1::bigint, 'Unrelated Wedding child remains.');
SELECT is((SELECT count(*) FROM auth.users WHERE id = '20000000-0000-0000-0000-000000000001'), 1::bigint, 'Auth user is preserved.');

SET ROLE service_role;
SELECT is(
  edge_api.begin_wedding_delete('20010000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001')->>'status',
  'DELETED',
  'Retry after physical deletion preserves generic terminal success.'
);

RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
