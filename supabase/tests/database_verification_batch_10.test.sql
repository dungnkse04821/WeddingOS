BEGIN;
SELECT plan(19);

INSERT INTO auth.users (id, email) VALUES
  ('fa000000-0000-0000-0000-000000000001', 'm43.owner@example.com'),
  ('fa000000-0000-0000-0000-000000000002', 'm43.outsider@example.com');
INSERT INTO public.weddings (id, name, cultural_context, exact_date)
VALUES ('fa100000-0000-0000-0000-000000000001', 'VietQR Wedding', 'TUY_CHON', '2026-12-18');
INSERT INTO public.wedding_members (wedding_id, user_id, display_name, profile_email, role)
VALUES ('fa100000-0000-0000-0000-000000000001', 'fa000000-0000-0000-0000-000000000001', 'M43 Owner', 'm43.owner@example.com', 'OWNER');
INSERT INTO public.wedding_events (id, wedding_id, name, exact_date, lifecycle_status, is_main_event)
VALUES ('fa200000-0000-0000-0000-000000000001', 'fa100000-0000-0000-0000-000000000001', 'Exact event', '2026-12-18', 'ACTIVE', true);
INSERT INTO public.invitation_parties (id, wedding_id, display_name, invited_count)
VALUES ('fa300000-0000-0000-0000-000000000001', 'fa100000-0000-0000-0000-000000000001', 'VietQR Party', 2);
INSERT INTO public.invitations (id, wedding_id, invitation_party_id)
VALUES ('fa400000-0000-0000-0000-000000000001', 'fa100000-0000-0000-0000-000000000001', 'fa300000-0000-0000-0000-000000000001');
INSERT INTO public.invitation_event_targetings (wedding_id, invitation_id, wedding_event_id)
VALUES ('fa100000-0000-0000-0000-000000000001', 'fa400000-0000-0000-0000-000000000001', 'fa200000-0000-0000-0000-000000000001');
UPDATE public.invitations SET status = 'READY' WHERE id = 'fa400000-0000-0000-0000-000000000001';
INSERT INTO public.invitation_credentials (invitation_id, token_hash)
VALUES ('fa400000-0000-0000-0000-000000000001', extensions.digest('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345', 'sha256'));

SELECT is((SELECT vietqr_enabled FROM public.weddings WHERE id = 'fa100000-0000-0000-0000-000000000001'), false, 'VietQR defaults disabled.');
SELECT throws_ok($$ UPDATE public.weddings SET vietqr_enabled = true WHERE id = 'fa100000-0000-0000-0000-000000000001'; $$, '23514', 'INVALID_VIETQR_CONFIGURATION', 'Enabled VietQR requires public display facts.');
UPDATE public.weddings SET vietqr_enabled = true, vietqr_bank_id = 'VCB', vietqr_account_no = '0123456789', vietqr_account_name = 'NGUYEN VAN A'
WHERE id = 'fa100000-0000-0000-0000-000000000001';
SELECT is((internal.resolve_public_invitation('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345', 'm43-hidden', 30) #>> '{invitation,vietqr,available}'), 'false', 'Enabled VietQR remains hidden before RSVP completion.');
SELECT is((internal.resolve_public_invitation('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345', 'm43-hidden2', 30) #>> '{invitation,vietqr,account_no}'), NULL, 'Hidden DTO contains no bank account value.');

CREATE TEMP TABLE m43_result AS SELECT internal.submit_public_rsvp(
  'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345',
  '[{"event_id":"fa200000-0000-0000-0000-000000000001","response_status":"NOT_ATTENDING","attending_count":0}]',
  '{}', 'm43-submit', 10) AS result;
SELECT is((SELECT result #>> '{rsvp,summary}' FROM m43_result), 'RESPONDED', 'Fully completed NOT_ATTENDING RSVP qualifies.');
SELECT is((SELECT result #>> '{vietqr,available}' FROM m43_result), 'true', 'D-RSV-001 returns VietQR after qualifying RSVP.');
SELECT is((SELECT result #>> '{vietqr,bank_id}' FROM m43_result), 'VCB', 'Visible DTO returns configured public bank display facts only.');
SELECT is((internal.resolve_public_invitation('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345', 'm43-visible', 30) #>> '{invitation,vietqr,available}'), 'true', 'D-INV-001 returns VietQR after qualifying RSVP.');

INSERT INTO public.wedding_events (id, wedding_id, name, exact_date, lifecycle_status, is_main_event)
VALUES ('fa200000-0000-0000-0000-000000000002', 'fa100000-0000-0000-0000-000000000001', 'New exact event', '2026-12-19', 'ACTIVE', false);
INSERT INTO public.invitation_event_targetings (wedding_id, invitation_id, wedding_event_id)
VALUES ('fa100000-0000-0000-0000-000000000001', 'fa400000-0000-0000-0000-000000000001', 'fa200000-0000-0000-0000-000000000002');
SELECT is((internal.resolve_public_invitation('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345', 'm43-partial', 30) #>> '{invitation,vietqr,available}'), 'false', 'Current PARTIAL RSVP hides VietQR again.');
UPDATE public.weddings SET vietqr_enabled = false WHERE id = 'fa100000-0000-0000-0000-000000000001';
SELECT is((internal.resolve_public_invitation('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345', 'm43-disabled', 30) #>> '{invitation,vietqr,available}'), 'false', 'Disabled config remains hidden.');

SELECT set_config('request.jwt.claims', '{"sub":"fa000000-0000-0000-0000-000000000001"}', true);
SET ROLE authenticated;
SELECT lives_ok($$ UPDATE public.weddings SET vietqr_bank_id = 'TCB' WHERE id = 'fa100000-0000-0000-0000-000000000001'; $$, 'Active same-Wedding organizer can update approved VietQR facts.');
RESET ROLE;
SELECT set_config('request.jwt.claims', '{"sub":"fa000000-0000-0000-0000-000000000002"}', true);
SET ROLE authenticated;
SELECT is((SELECT count(*)::integer FROM public.weddings WHERE id = 'fa100000-0000-0000-0000-000000000001'), 0, 'Outsider cannot read Wedding config.');
SELECT lives_ok($$ UPDATE public.weddings SET vietqr_bank_id = 'LEAK' WHERE id = 'fa100000-0000-0000-0000-000000000001'; $$, 'Outsider update affects no RLS-visible row.');
RESET ROLE;

UPDATE public.weddings SET status = 'ARCHIVED' WHERE id = 'fa100000-0000-0000-0000-000000000001';
SELECT set_config('request.jwt.claims', '{"sub":"fa000000-0000-0000-0000-000000000001"}', true);
SET ROLE authenticated;
SELECT lives_ok($$ UPDATE public.weddings SET vietqr_enabled = true WHERE id = 'fa100000-0000-0000-0000-000000000001'; $$, 'Archived mutation is blocked by RLS with no changed row.');
RESET ROLE;
SELECT is((SELECT vietqr_enabled FROM public.weddings WHERE id = 'fa100000-0000-0000-0000-000000000001'), false, 'Archived Wedding configuration remains unchanged.');

SELECT is(has_function_privilege('anon', 'edge_api.resolve_public_invitation(text, character varying, integer)', 'EXECUTE'), false, 'anon cannot execute Class-D bridge directly.');
SELECT is(has_function_privilege('authenticated', 'edge_api.resolve_public_invitation(text, character varying, integer)', 'EXECUTE'), false, 'authenticated cannot execute Class-D bridge directly.');
SELECT is(has_function_privilege('service_role', 'edge_api.resolve_public_invitation(text, character varying, integer)', 'EXECUTE'), true, 'Only service_role can execute Class-D bridge.');
SELECT is(has_table_privilege('anon', 'public.weddings', 'SELECT'), false, 'anon cannot directly read VietQR configuration.');

SELECT * FROM finish();
ROLLBACK;
