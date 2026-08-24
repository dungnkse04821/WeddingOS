BEGIN;
SELECT plan(37);

INSERT INTO public.weddings (id, name, cultural_context, exact_date, timezone, status)
VALUES
  ('f9000000-0000-0000-0000-000000000001', 'RSVP Wedding', 'TUY_CHON', '2026-12-18', 'Pacific/Kiritimati', 'ACTIVE'),
  ('f9000000-0000-0000-0000-000000000002', 'Other Wedding', 'TUY_CHON', '2026-12-19', 'Asia/Ho_Chi_Minh', 'ACTIVE');

INSERT INTO public.wedding_events (id, wedding_id, name, exact_date, lifecycle_status, is_main_event)
VALUES
  ('f9100000-0000-0000-0000-000000000001', 'f9000000-0000-0000-0000-000000000001', 'Exact A', '2026-12-18', 'ACTIVE', true),
  ('f9100000-0000-0000-0000-000000000002', 'f9000000-0000-0000-0000-000000000001', 'Exact B', '2026-12-19', 'ACTIVE', false),
  ('f9100000-0000-0000-0000-000000000004', 'f9000000-0000-0000-0000-000000000002', 'Other Exact', '2026-12-20', 'ACTIVE', true);
INSERT INTO public.wedding_events (id, wedding_id, name, expected_year, expected_month, lifecycle_status, is_main_event)
VALUES ('f9100000-0000-0000-0000-000000000003', 'f9000000-0000-0000-0000-000000000001', 'Expected', 2026, 12, 'ACTIVE', false);

INSERT INTO public.invitation_parties (id, wedding_id, display_name, invited_count)
VALUES ('f9200000-0000-0000-0000-000000000001', 'f9000000-0000-0000-0000-000000000001', 'Empty RSVP Party', 2);
INSERT INTO public.invitations (id, wedding_id, invitation_party_id)
VALUES ('f9300000-0000-0000-0000-000000000001', 'f9000000-0000-0000-0000-000000000001', 'f9200000-0000-0000-0000-000000000001');
INSERT INTO public.invitation_event_targetings (wedding_id, invitation_id, wedding_event_id)
VALUES
  ('f9000000-0000-0000-0000-000000000001', 'f9300000-0000-0000-0000-000000000001', 'f9100000-0000-0000-0000-000000000001'),
  ('f9000000-0000-0000-0000-000000000001', 'f9300000-0000-0000-0000-000000000001', 'f9100000-0000-0000-0000-000000000002'),
  ('f9000000-0000-0000-0000-000000000001', 'f9300000-0000-0000-0000-000000000001', 'f9100000-0000-0000-0000-000000000003');
UPDATE public.invitations SET status = 'READY' WHERE id = 'f9300000-0000-0000-0000-000000000001';
INSERT INTO public.invitation_credentials (invitation_id, token_hash)
VALUES ('f9300000-0000-0000-0000-000000000001', extensions.digest('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345', 'sha256'));

CREATE TEMP TABLE rsvp_results (label text PRIMARY KEY, result jsonb);
INSERT INTO rsvp_results VALUES ('first', internal.submit_public_rsvp(
  'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345',
  '[{"event_id":"f9100000-0000-0000-0000-000000000001","response_status":"ATTENDING","attending_count":1}]',
  '{"guest_message":"Congratulations","companion_names":["Guest A"]}', 'm42-first', 10));

SELECT is((SELECT result ->> 'ok' FROM rsvp_results WHERE label = 'first'), 'true', 'D-RSV-001: targeted Exact event RSVP succeeds.');
SELECT is((SELECT count(*)::integer FROM public.rsvps WHERE invitation_id = 'f9300000-0000-0000-0000-000000000001'), 1, 'Current RSVP: one row is created for an empty InvitationParty.');
SELECT is((SELECT count(*)::integer FROM public.guests WHERE invitation_party_id = 'f9200000-0000-0000-0000-000000000001'), 0, 'RSVP ownership: no fake Guest is required or created.');
SELECT is((SELECT is_attending FROM public.event_responses LIMIT 1), true, 'ATTENDING maps to an attending EventResponse.');
SELECT is((SELECT attending_count FROM public.event_responses LIMIT 1), 1, 'ATTENDING count is persisted.');
SELECT is((SELECT invited_count FROM public.invitation_parties WHERE id = 'f9200000-0000-0000-0000-000000000001'), 2, 'Invited Count remains immutable RSVP capacity.');

INSERT INTO rsvp_results VALUES ('partial', internal.submit_public_rsvp(
  'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345',
  '[{"event_id":"f9100000-0000-0000-0000-000000000002","response_status":"NOT_ATTENDING","attending_count":0}]',
  '{}', 'm42-partial', 10));
SELECT is((SELECT count(*)::integer FROM public.event_responses), 2, 'Patch-by-event: a second included EventResponse is added.');
INSERT INTO rsvp_results VALUES ('patch', internal.submit_public_rsvp(
  'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345',
  '[{"event_id":"f9100000-0000-0000-0000-000000000001","response_status":"ATTENDING","attending_count":2}]',
  '{"guest_message":null}', 'm42-patch', 10));
SELECT is((SELECT count(*)::integer FROM public.rsvps), 1, 'Retry/update: valid updates reuse the same current RSVP row.');
SELECT is((SELECT count(*)::integer FROM public.event_responses), 2, 'Patch-by-event: omitted EventResponse is not deleted.');
SELECT is((SELECT attending_count FROM public.event_responses WHERE wedding_event_id = 'f9100000-0000-0000-0000-000000000002'), 0, 'Patch-by-event: omitted EventResponse remains unchanged.');
SELECT is((SELECT guest_message FROM public.rsvps), NULL, 'Explicit nullable RSVP field clears stored value.');
SELECT is((SELECT result #>> '{rsvp,summary}' FROM rsvp_results WHERE label = 'patch'), 'RESPONDED', 'Summary: all active Exact target Events responded is RESPONDED.');

INSERT INTO rsvp_results VALUES ('overcount', internal.submit_public_rsvp(
  'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345',
  '[{"event_id":"f9100000-0000-0000-0000-000000000001","response_status":"ATTENDING","attending_count":3}]',
  '{}', 'm42-overcount', 10));
SELECT is((SELECT result #>> '{rsvp,warnings,0}' FROM rsvp_results WHERE label = 'overcount'), 'RSVP_OVERCOUNT', 'Overcount: valid submission returns non-blocking warning.');
SELECT is((SELECT invited_count FROM public.invitation_parties WHERE id = 'f9200000-0000-0000-0000-000000000001'), 2, 'Overcount: RSVP does not mutate invited_count.');

INSERT INTO rsvp_results VALUES ('expected', internal.submit_public_rsvp(
  'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345',
  '[{"event_id":"f9100000-0000-0000-0000-000000000003","response_status":"ATTENDING","attending_count":1}]', '{}', 'm42-expected', 10));
SELECT is((SELECT result ->> 'error_code' FROM rsvp_results WHERE label = 'expected'), 'EVENT_NOT_AVAILABLE', 'Expected Month event cannot receive RSVP.');
INSERT INTO rsvp_results VALUES ('maybe', internal.submit_public_rsvp(
  'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345',
  '[{"event_id":"f9100000-0000-0000-0000-000000000001","response_status":"MAYBE","attending_count":1}]', '{}', 'm42-maybe', 10));
SELECT is((SELECT result ->> 'error_code' FROM rsvp_results WHERE label = 'maybe'), 'INVALID_RESPONSE', 'Attendance: MAYBE is not an allowed RSVP response.');
INSERT INTO rsvp_results VALUES ('cross-wedding', internal.submit_public_rsvp(
  'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345',
  '[{"event_id":"f9100000-0000-0000-0000-000000000004","response_status":"ATTENDING","attending_count":1}]', '{}', 'm42-cross', 10));
SELECT is((SELECT result ->> 'error_code' FROM rsvp_results WHERE label = 'cross-wedding'), 'EVENT_NOT_AVAILABLE', 'Cross-Wedding event is rejected without tenant leakage.');
UPDATE public.wedding_events SET lifecycle_status = 'REMOVED' WHERE id = 'f9100000-0000-0000-0000-000000000002';
INSERT INTO rsvp_results VALUES ('removed', internal.submit_public_rsvp(
  'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345',
  '[{"event_id":"f9100000-0000-0000-0000-000000000002","response_status":"ATTENDING","attending_count":1}]', '{}', 'm42-removed', 10));
SELECT is((SELECT result ->> 'error_code' FROM rsvp_results WHERE label = 'removed'), 'EVENT_NOT_AVAILABLE', 'REMOVED event rejects new RSVP updates.');
SELECT is((SELECT count(*)::integer FROM public.event_responses WHERE wedding_event_id = 'f9100000-0000-0000-0000-000000000002'), 1, 'REMOVED EventResponse history is preserved.');

CREATE TEMP TABLE atomic_before AS SELECT attending_count FROM public.event_responses WHERE wedding_event_id = 'f9100000-0000-0000-0000-000000000001';
INSERT INTO rsvp_results VALUES ('atomic-invalid', internal.submit_public_rsvp(
  'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345',
  '[{"event_id":"f9100000-0000-0000-0000-000000000001","response_status":"ATTENDING","attending_count":1},{"event_id":"f9100000-0000-0000-0000-000000000003","response_status":"ATTENDING","attending_count":1}]', '{}', 'm42-atomic', 10));
SELECT is((SELECT result ->> 'error_code' FROM rsvp_results WHERE label = 'atomic-invalid'), 'EVENT_NOT_AVAILABLE', 'Atomicity: invalid event rejects the complete request.');
SELECT is((SELECT er.attending_count = b.attending_count FROM public.event_responses er CROSS JOIN atomic_before b WHERE er.wedding_event_id = 'f9100000-0000-0000-0000-000000000001'), true, 'Atomicity: valid patch is not partially committed.');

UPDATE public.weddings SET rsvp_cutoff_date = (clock_timestamp() AT TIME ZONE 'Pacific/Kiritimati')::date WHERE id = 'f9000000-0000-0000-0000-000000000001';
INSERT INTO rsvp_results VALUES ('cutoff-on', internal.submit_public_rsvp(
  'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345',
  '[{"event_id":"f9100000-0000-0000-0000-000000000001","response_status":"ATTENDING","attending_count":1}]', '{}', 'm42-cutoff-on', 10));
SELECT is((SELECT result ->> 'ok' FROM rsvp_results WHERE label = 'cutoff-on'), 'true', 'Cutoff: submission is allowed on Wedding-local cutoff date.');
UPDATE public.weddings SET rsvp_cutoff_date = (clock_timestamp() AT TIME ZONE 'Pacific/Kiritimati')::date - 1 WHERE id = 'f9000000-0000-0000-0000-000000000001';
INSERT INTO rsvp_results VALUES ('cutoff-after', internal.submit_public_rsvp(
  'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345',
  '[{"event_id":"f9100000-0000-0000-0000-000000000001","response_status":"ATTENDING","attending_count":1}]', '{}', 'm42-cutoff-after', 10));
SELECT is((SELECT result ->> 'error_code' FROM rsvp_results WHERE label = 'cutoff-after'), 'RSVP_CLOSED', 'Cutoff: after Wedding-local cutoff date is view-only.');
UPDATE public.weddings SET rsvp_cutoff_date = NULL WHERE id = 'f9000000-0000-0000-0000-000000000001';
INSERT INTO rsvp_results VALUES ('no-cutoff', internal.submit_public_rsvp(
  'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345',
  '[{"event_id":"f9100000-0000-0000-0000-000000000001","response_status":"ATTENDING","attending_count":1}]', '{}', 'm42-no-cutoff', 10));
SELECT is((SELECT result ->> 'ok' FROM rsvp_results WHERE label = 'no-cutoff'), 'true', 'No cutoff: valid RSVP remains editable.');

SELECT throws_ok($$ INSERT INTO public.event_responses (rsvp_id, wedding_event_id, is_attending, attending_count) VALUES ((SELECT id FROM public.rsvps LIMIT 1), 'f9100000-0000-0000-0000-000000000001', true, 0); $$, '23514', NULL, 'DB constraint: ATTENDING cannot have zero count.');
SELECT throws_ok($$ INSERT INTO public.event_responses (rsvp_id, wedding_event_id, is_attending, attending_count) VALUES ((SELECT id FROM public.rsvps LIMIT 1), 'f9100000-0000-0000-0000-000000000004', false, 1); $$, '23514', NULL, 'DB constraint: NOT_ATTENDING must have zero count.');
SELECT is(has_function_privilege('anon', 'edge_api.submit_public_rsvp(text, jsonb, jsonb, character varying, integer)', 'EXECUTE'), false, 'Security: anon cannot call RSVP bridge directly.');
SELECT is(has_function_privilege('authenticated', 'edge_api.submit_public_rsvp(text, jsonb, jsonb, character varying, integer)', 'EXECUTE'), false, 'Security: authenticated cannot call RSVP bridge directly.');
SELECT is(has_function_privilege('service_role', 'edge_api.submit_public_rsvp(text, jsonb, jsonb, character varying, integer)', 'EXECUTE'), true, 'Security: only service_role has RSVP bridge execution.');
SELECT is(has_function_privilege('service_role', 'internal.submit_public_rsvp(text, jsonb, jsonb, character varying, integer)', 'EXECUTE'), false, 'Security: service_role cannot execute hidden RSVP implementation directly.');

SELECT is((internal.submit_public_rsvp('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345', '[{"event_id":"f9100000-0000-0000-0000-000000000001","response_status":"ATTENDING","attending_count":1}]', '{}', 'm42-limit', 2) ->> 'ok'), 'true', 'RSVP limiter: first request under threshold succeeds.');
SELECT is((internal.submit_public_rsvp('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345', '[{"event_id":"f9100000-0000-0000-0000-000000000001","response_status":"ATTENDING","attending_count":1}]', '{}', 'm42-limit', 2) ->> 'ok'), 'true', 'RSVP limiter: request at threshold succeeds.');
SELECT is((internal.submit_public_rsvp('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345', '[{"event_id":"f9100000-0000-0000-0000-000000000001","response_status":"ATTENDING","attending_count":1}]', '{}', 'm42-limit', 2) ->> 'error_code'), 'RATE_LIMITED', 'RSVP limiter: excess request is safely rate limited.');
UPDATE private.class_d_rate_limits SET window_start = clock_timestamp() - interval '61 seconds' WHERE limiter_key = 'm42-limit';
SELECT is((internal.submit_public_rsvp('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345', '[{"event_id":"f9100000-0000-0000-0000-000000000001","response_status":"ATTENDING","attending_count":1}]', '{}', 'm42-limit', 2) ->> 'ok'), 'true', 'RSVP limiter: new fixed window is available.');
SELECT is((SELECT count(*)::integer FROM private.class_d_rate_limits WHERE limiter_key LIKE '%ABCDEFGHIJKLMNOPQRSTUVWXYZ%'), 0, 'RSVP limiter: raw invitation token is never persisted.');

SET ROLE anon;
SELECT throws_ok($$ SELECT * FROM public.rsvps; $$, '42501', NULL, 'Security: anon cannot directly read rsvps.');
SELECT throws_ok($$ SELECT * FROM public.event_responses; $$, '42501', NULL, 'Security: anon cannot directly read event_responses.');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
