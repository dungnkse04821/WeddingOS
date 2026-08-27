BEGIN;
SELECT plan(48);

INSERT INTO auth.users (id, email, raw_user_meta_data)
VALUES
  ('16000000-0000-0000-0000-000000000001', 'm81b-owner@test.local', '{"full_name":"M81B Owner"}'),
  ('16000000-0000-0000-0000-000000000002', 'm81b-collab@test.local', '{"full_name":"M81B Collaborator"}'),
  ('16000000-0000-0000-0000-000000000003', 'm81b-outsider@test.local', '{"full_name":"M81B Outsider"}')
ON CONFLICT DO NOTHING;

INSERT INTO public.weddings (id, name, cultural_context, exact_date, status)
VALUES
  ('16100000-0000-0000-0000-000000000001', 'M81B Active', 'TUY_CHON', '2027-03-01', 'ACTIVE'),
  ('16100000-0000-0000-0000-000000000002', 'M81B Archived', 'TUY_CHON', '2027-03-02', 'ACTIVE'),
  ('16100000-0000-0000-0000-000000000003', 'M81B Deleting', 'TUY_CHON', '2027-03-03', 'ACTIVE'),
  ('16100000-0000-0000-0000-000000000004', 'M81B Unrelated', 'TUY_CHON', '2027-03-04', 'ACTIVE');

INSERT INTO public.wedding_members (
  id, wedding_id, user_id, display_name, profile_email, role, status
)
VALUES
  ('16200000-0000-0000-0000-000000000001', '16100000-0000-0000-0000-000000000001', '16000000-0000-0000-0000-000000000001', 'Owner', 'm81b-owner@test.local', 'OWNER', 'ACTIVE'),
  ('16200000-0000-0000-0000-000000000002', '16100000-0000-0000-0000-000000000001', '16000000-0000-0000-0000-000000000002', 'Collaborator', 'm81b-collab@test.local', 'COLLABORATOR', 'ACTIVE'),
  ('16200000-0000-0000-0000-000000000003', '16100000-0000-0000-0000-000000000002', '16000000-0000-0000-0000-000000000001', 'Owner', 'm81b-owner@test.local', 'OWNER', 'ACTIVE'),
  ('16200000-0000-0000-0000-000000000004', '16100000-0000-0000-0000-000000000002', '16000000-0000-0000-0000-000000000002', 'Collaborator', 'm81b-collab@test.local', 'COLLABORATOR', 'ACTIVE'),
  ('16200000-0000-0000-0000-000000000005', '16100000-0000-0000-0000-000000000003', '16000000-0000-0000-0000-000000000001', 'Owner', 'm81b-owner@test.local', 'OWNER', 'ACTIVE'),
  ('16200000-0000-0000-0000-000000000006', '16100000-0000-0000-0000-000000000003', '16000000-0000-0000-0000-000000000002', 'Collaborator', 'm81b-collab@test.local', 'COLLABORATOR', 'ACTIVE'),
  ('16200000-0000-0000-0000-000000000007', '16100000-0000-0000-0000-000000000004', '16000000-0000-0000-0000-000000000003', 'Outsider', 'm81b-outsider@test.local', 'OWNER', 'ACTIVE');

INSERT INTO public.wedding_events (id, wedding_id, name, exact_date, lifecycle_status, is_main_event)
VALUES
  ('16300000-0000-0000-0000-000000000001', '16100000-0000-0000-0000-000000000001', 'Active Event', '2027-03-01', 'ACTIVE', true),
  ('16300000-0000-0000-0000-000000000002', '16100000-0000-0000-0000-000000000002', 'Archived Event', '2027-03-02', 'ACTIVE', true),
  ('16300000-0000-0000-0000-000000000003', '16100000-0000-0000-0000-000000000003', 'Deleting Event', '2027-03-03', 'ACTIVE', true);

INSERT INTO public.tasks (id, wedding_id, name, status, deadline_intent, task_source, side)
VALUES
  ('16400000-0000-0000-0000-000000000001', '16100000-0000-0000-0000-000000000001', 'Active Task', 'TODO', 'NO_DEADLINE', 'USER', 'COMMON'),
  ('16400000-0000-0000-0000-000000000002', '16100000-0000-0000-0000-000000000002', 'Archived Task', 'TODO', 'NO_DEADLINE', 'USER', 'COMMON'),
  ('16400000-0000-0000-0000-000000000003', '16100000-0000-0000-0000-000000000003', 'Deleting Task', 'TODO', 'NO_DEADLINE', 'USER', 'COMMON');

INSERT INTO public.primary_groups (id, wedding_id, name)
VALUES ('16500000-0000-0000-0000-000000000001', '16100000-0000-0000-0000-000000000003', 'Deleting Group');
INSERT INTO public.invitation_parties (id, wedding_id, display_name, invited_count)
VALUES ('16600000-0000-0000-0000-000000000001', '16100000-0000-0000-0000-000000000003', 'Deleting Party', 1);
INSERT INTO public.guests (id, wedding_id, invitation_party_id, primary_group_id, name)
VALUES ('16700000-0000-0000-0000-000000000001', '16100000-0000-0000-0000-000000000003', '16600000-0000-0000-0000-000000000001', '16500000-0000-0000-0000-000000000001', 'Deleting Guest');
INSERT INTO public.invitations (id, wedding_id, invitation_party_id, status)
VALUES ('16800000-0000-0000-0000-000000000001', '16100000-0000-0000-0000-000000000003', '16600000-0000-0000-0000-000000000001', 'DRAFT');
INSERT INTO public.invitation_event_targetings (wedding_id, invitation_id, wedding_event_id)
VALUES ('16100000-0000-0000-0000-000000000003', '16800000-0000-0000-0000-000000000001', '16300000-0000-0000-0000-000000000003');
INSERT INTO public.rsvps (id, invitation_id)
VALUES ('16900000-0000-0000-0000-000000000001', '16800000-0000-0000-0000-000000000001');
INSERT INTO public.event_responses (id, rsvp_id, wedding_event_id, is_attending, attending_count)
VALUES ('16a00000-0000-0000-0000-000000000001', '16900000-0000-0000-0000-000000000001', '16300000-0000-0000-0000-000000000003', true, 1);

INSERT INTO public.budget_items (id, wedding_id, name, estimated_cost, status)
VALUES
  ('16b00000-0000-0000-0000-000000000001', '16100000-0000-0000-0000-000000000001', 'Active Budget', 100.00, 'ACTIVE'),
  ('16b00000-0000-0000-0000-000000000002', '16100000-0000-0000-0000-000000000002', 'Archived Budget', 100.00, 'ACTIVE'),
  ('16b00000-0000-0000-0000-000000000003', '16100000-0000-0000-0000-000000000003', 'Deleting Budget', 100.00, 'ACTIVE');

INSERT INTO storage.objects (bucket_id, name, owner, metadata)
VALUES
  ('wedding_media', 'weddings/16100000-0000-0000-0000-000000000001/cover.webp', '16000000-0000-0000-0000-000000000001', '{}'::jsonb),
  ('wedding_media', 'weddings/16100000-0000-0000-0000-000000000002/cover.webp', '16000000-0000-0000-0000-000000000001', '{}'::jsonb),
  ('wedding_media', 'weddings/16100000-0000-0000-0000-000000000003/cover.webp', '16000000-0000-0000-0000-000000000001', '{}'::jsonb);

UPDATE public.weddings SET status = 'ARCHIVED' WHERE id = '16100000-0000-0000-0000-000000000002';
UPDATE public.weddings SET status = 'DELETING' WHERE id = '16100000-0000-0000-0000-000000000003';

SELECT has_function('security', 'can_owner_recover_deleting_wedding', ARRAY['uuid'], 'DELETING recovery helper exists');
SELECT ok(position('pg_advisory_xact_lock' in pg_get_functiondef('api_v1.create_wedding(uuid,varchar,varchar,date,integer,integer,varchar,numeric)'::regprocedure)) > 0, 'TOP-WED-001 serializes receipt acquisition');
SELECT ok(position('ON CONFLICT' in pg_get_functiondef('api_v1.create_wedding(uuid,varchar,varchar,date,integer,integer,varchar,numeric)'::regprocedure)) = 0, 'TOP-WED-001 no longer ignores receipt conflicts');

SELECT set_config('request.jwt.claims', '{"sub":"16000000-0000-0000-0000-000000000001"}', true);
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM public.weddings WHERE id = '16100000-0000-0000-0000-000000000001'), 1::bigint, 'ACTIVE owner reads Wedding');
SELECT is((SELECT count(*) FROM public.wedding_members WHERE wedding_id = '16100000-0000-0000-0000-000000000001'), 2::bigint, 'ACTIVE owner reads member directory');
SELECT is((SELECT count(*) FROM public.wedding_events WHERE wedding_id = '16100000-0000-0000-0000-000000000001'), 1::bigint, 'ACTIVE owner reads events');
SELECT is((SELECT count(*) FROM public.tasks WHERE wedding_id = '16100000-0000-0000-0000-000000000001'), 1::bigint, 'ACTIVE owner reads tasks');
SELECT is((SELECT count(*) FROM storage.objects WHERE name = 'weddings/16100000-0000-0000-0000-000000000001/cover.webp'), 1::bigint, 'ACTIVE owner reads cover');

SELECT set_config('request.jwt.claims', '{"sub":"16000000-0000-0000-0000-000000000002"}', true);
SELECT is((SELECT count(*) FROM public.weddings WHERE id = '16100000-0000-0000-0000-000000000001'), 1::bigint, 'ACTIVE collaborator reads Wedding');
SELECT is((SELECT count(*) FROM public.wedding_events WHERE wedding_id = '16100000-0000-0000-0000-000000000001'), 1::bigint, 'ACTIVE collaborator reads graph');

SELECT set_config('request.jwt.claims', '{"sub":"16000000-0000-0000-0000-000000000001"}', true);
SELECT is((SELECT count(*) FROM public.weddings WHERE id = '16100000-0000-0000-0000-000000000002'), 1::bigint, 'ARCHIVED owner reads Wedding');
SELECT is((SELECT count(*) FROM public.wedding_members WHERE wedding_id = '16100000-0000-0000-0000-000000000002'), 2::bigint, 'ARCHIVED owner reads member directory');
SELECT is((SELECT count(*) FROM public.wedding_events WHERE wedding_id = '16100000-0000-0000-0000-000000000002'), 1::bigint, 'ARCHIVED owner reads graph');
SELECT is((SELECT count(*) FROM storage.objects WHERE name = 'weddings/16100000-0000-0000-0000-000000000002/cover.webp'), 1::bigint, 'ARCHIVED owner retains cover read');

SELECT set_config('request.jwt.claims', '{"sub":"16000000-0000-0000-0000-000000000002"}', true);
SELECT is((SELECT count(*) FROM public.weddings WHERE id = '16100000-0000-0000-0000-000000000002'), 1::bigint, 'ARCHIVED collaborator reads Wedding');
SELECT is((SELECT count(*) FROM public.wedding_events WHERE wedding_id = '16100000-0000-0000-0000-000000000002'), 1::bigint, 'ARCHIVED collaborator reads graph');
SELECT lives_ok($$UPDATE public.weddings SET name = 'blocked archived' WHERE id = '16100000-0000-0000-0000-000000000002'$$, 'ARCHIVED ordinary update is filtered by RLS');
SELECT is((SELECT name FROM public.weddings WHERE id = '16100000-0000-0000-0000-000000000002'), 'M81B Archived', 'ARCHIVED write did not change data');

SELECT set_config('request.jwt.claims', '{"sub":"16000000-0000-0000-0000-000000000001"}', true);
SELECT is((SELECT count(*) FROM public.weddings WHERE id = '16100000-0000-0000-0000-000000000003'), 1::bigint, 'DELETING owner reads recovery Wedding identity');
SELECT is((SELECT count(*) FROM public.wedding_members WHERE wedding_id = '16100000-0000-0000-0000-000000000003' AND user_id = auth.uid()), 1::bigint, 'DELETING owner reads own active OWNER identity');
SELECT is((SELECT count(*) FROM public.wedding_members WHERE wedding_id = '16100000-0000-0000-0000-000000000003'), 1::bigint, 'DELETING owner cannot read other members');
SELECT is((SELECT count(*) FROM public.wedding_events WHERE wedding_id = '16100000-0000-0000-0000-000000000003'), 0::bigint, 'DELETING owner cannot read events');
SELECT is((SELECT count(*) FROM public.tasks WHERE wedding_id = '16100000-0000-0000-0000-000000000003'), 0::bigint, 'DELETING owner cannot read tasks');
SELECT is((SELECT count(*) FROM public.guests WHERE wedding_id = '16100000-0000-0000-0000-000000000003'), 0::bigint, 'DELETING owner cannot read guests');
SELECT is((SELECT count(*) FROM public.budget_items WHERE wedding_id = '16100000-0000-0000-0000-000000000003'), 0::bigint, 'DELETING owner cannot read Finance graph');
SELECT is((SELECT count(*) FROM public.finance_summaries WHERE wedding_id = '16100000-0000-0000-0000-000000000003'), 0::bigint, 'DELETING owner cannot read Finance summary');
SELECT is((SELECT count(*) FROM storage.objects WHERE name = 'weddings/16100000-0000-0000-0000-000000000003/cover.webp'), 0::bigint, 'DELETING owner cannot read cover');
SELECT is((SELECT count(*) FROM public.invitations WHERE wedding_id = '16100000-0000-0000-0000-000000000003'), 0::bigint, 'DELETING owner cannot read invitations');
SELECT is((SELECT count(*) FROM public.invitation_event_targetings WHERE wedding_id = '16100000-0000-0000-0000-000000000003'), 0::bigint, 'DELETING owner cannot read invitation targeting');
SELECT is((SELECT count(*) FROM public.rsvps WHERE invitation_id = '16800000-0000-0000-0000-000000000001'), 0::bigint, 'DELETING owner cannot read RSVP');
SELECT is((SELECT count(*) FROM public.event_responses WHERE rsvp_id = '16900000-0000-0000-0000-000000000001'), 0::bigint, 'DELETING owner cannot read event responses');
SELECT lives_ok($$UPDATE public.weddings SET name = 'blocked deleting' WHERE id = '16100000-0000-0000-0000-000000000003'$$, 'DELETING ordinary update is filtered by RLS');
SELECT is((SELECT name FROM public.weddings WHERE id = '16100000-0000-0000-0000-000000000003'), 'M81B Deleting', 'DELETING write did not change data');

SELECT set_config('request.jwt.claims', '{"sub":"16000000-0000-0000-0000-000000000002"}', true);
SELECT is((SELECT count(*) FROM public.weddings WHERE id = '16100000-0000-0000-0000-000000000003'), 0::bigint, 'DELETING collaborator cannot read Wedding');
SELECT is((SELECT count(*) FROM public.wedding_members WHERE wedding_id = '16100000-0000-0000-0000-000000000003'), 0::bigint, 'DELETING collaborator cannot read members');
SELECT is((SELECT count(*) FROM public.wedding_events WHERE wedding_id = '16100000-0000-0000-0000-000000000003'), 0::bigint, 'DELETING collaborator cannot read graph');

SELECT set_config('request.jwt.claims', '{"sub":"16000000-0000-0000-0000-000000000003"}', true);
SELECT is((SELECT count(*) FROM public.weddings WHERE id = '16100000-0000-0000-0000-000000000003'), 0::bigint, 'Outsider cannot read DELETING Wedding');

RESET ROLE;
SET ROLE anon;
SELECT throws_ok(
  $$SELECT id FROM public.weddings WHERE id = '16100000-0000-0000-0000-000000000001'$$,
  '42501',
  NULL,
  'Anon cannot read Wedding'
);

RESET ROLE;
SET ROLE service_role;
SELECT is((edge_api.begin_wedding_delete('16100000-0000-0000-0000-000000000003', '16000000-0000-0000-0000-000000000001')->>'status'), 'DELETING', 'DELETING owner recovery bridge remains available');

RESET ROLE;
SELECT set_config('request.jwt.claims', '{"sub":"16000000-0000-0000-0000-000000000001"}', true);
SET ROLE authenticated;
SELECT is((api_v1.create_wedding('16c00000-0000-0000-0000-000000000001', 'M81B Concurrent Receipt', 'TUY_CHON', '2027-04-01')->>'replayed')::boolean, false, 'TOP-WED-001 creates initial Wedding');
SELECT is((SELECT count(*) FROM public.weddings WHERE name = 'M81B Concurrent Receipt'), 1::bigint, 'Serialized path has one Wedding');
RESET ROLE;
SELECT is((SELECT count(*) FROM private.trusted_operation_receipts WHERE operation_type = 'TOP-WED-001' AND actor_user_id = '16000000-0000-0000-0000-000000000001' AND request_id = '16c00000-0000-0000-0000-000000000001'), 1::bigint, 'Serialized path has one authoritative receipt');
SET ROLE authenticated;
SELECT is((api_v1.create_wedding('16c00000-0000-0000-0000-000000000001', 'M81B Concurrent Receipt', 'TUY_CHON', '2027-04-01')->>'replayed')::boolean, true, 'TOP-WED-001 replay converges');
SELECT is(
  api_v1.create_wedding('16c00000-0000-0000-0000-000000000001', 'M81B Concurrent Receipt', 'TUY_CHON', '2027-04-01')->'wedding'->>'id',
  api_v1.create_wedding('16c00000-0000-0000-0000-000000000001', 'M81B Concurrent Receipt', 'TUY_CHON', '2027-04-01')->'wedding'->>'id',
  'Replay rereads authoritative Wedding identity'
);
SELECT throws_ok($$SELECT api_v1.create_wedding('16c00000-0000-0000-0000-000000000001', 'Different Semantic Request', 'TUY_CHON', '2027-04-01')$$, '40900', NULL, 'Changed semantics reuse is rejected');
SELECT is((SELECT count(*) FROM public.weddings WHERE name IN ('M81B Concurrent Receipt', 'Different Semantic Request')), 1::bigint, 'Semantic mismatch creates no duplicate Wedding');
SELECT is((api_v1.archive_wedding('16100000-0000-0000-0000-000000000001')->>'status'), 'ARCHIVED', 'TOP-WED-003 still derives owner from auth.uid()');
SELECT set_config('request.jwt.claims', '{"sub":"16000000-0000-0000-0000-000000000002"}', true);
SELECT throws_ok($$SELECT api_v1.archive_wedding('16100000-0000-0000-0000-000000000004')$$, '42501', NULL, 'TOP-WED-003 does not accept another actor authority');

RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
