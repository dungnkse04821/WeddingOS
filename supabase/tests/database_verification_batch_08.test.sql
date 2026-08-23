BEGIN;
SELECT plan(54); -- 54 assertions for BATCH-08 (Public Invitation Resolve)

-- ===========================================================================
-- TEST SETUP
-- ===========================================================================

INSERT INTO public.weddings (id, name, target_budget, cultural_context, exact_date, status, public_contact_phone, public_contact_email)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Active Wedding', 500000000, 'TUY_CHON', '2026-12-18', 'ACTIVE', '0900000000', 'hello@example.com'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Archived Wedding', 600000000, 'TUY_CHON', '2026-12-25', 'ARCHIVED', NULL, NULL),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Deleting Wedding', 600000000, 'TUY_CHON', '2026-12-26', 'DELETING', NULL, NULL)
ON CONFLICT (id) DO NOTHING;

INSERT INTO auth.users (id, email)
VALUES
  ('d1000000-0000-0000-0000-000000000001', 'm4.organizer@example.com'),
  ('d1000000-0000-0000-0000-000000000002', 'm4.outsider@example.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.wedding_members (wedding_id, user_id, display_name, profile_email, role, status)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'd1000000-0000-0000-0000-000000000001', 'M4 Organizer', 'm4.organizer@example.com', 'OWNER', 'ACTIVE')
ON CONFLICT (wedding_id, user_id) DO NOTHING;

INSERT INTO public.wedding_events (id, wedding_id, name, exact_date, start_time, location, map_link, lifecycle_status, is_main_event)
VALUES
  ('e1000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Exact Event', '2026-12-18', '18:00', 'Main Hall', 'https://maps.example/event', 'ACTIVE', true),
  ('e1000000-0000-0000-0000-000000000003', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Removed Event', '2026-12-19', '18:00', 'Old Hall', NULL, 'ACTIVE', false),
  ('e1000000-0000-0000-0000-000000000004', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Archived Event', '2026-12-25', NULL, NULL, NULL, 'ACTIVE', true),
  ('e1000000-0000-0000-0000-000000000005', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'Deleting Event', '2026-12-26', NULL, NULL, NULL, 'ACTIVE', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.wedding_events (id, wedding_id, name, expected_year, expected_month, lifecycle_status, is_main_event)
VALUES
  ('e1000000-0000-0000-0000-000000000002', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Expected Month Event', 2026, 12, 'ACTIVE', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.invitation_parties (id, wedding_id, display_name, invited_count)
VALUES
  ('c0000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Gia đình bác Tư', 4),
  ('c0000000-0000-0000-0000-000000000002', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Draft Party', 2),
  ('c0000000-0000-0000-0000-000000000003', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Archived Party', 3),
  ('c0000000-0000-0000-0000-000000000004', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'Deleting Party', 3)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.invitations (id, wedding_id, invitation_party_id, status)
VALUES
  ('a1000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'c0000000-0000-0000-0000-000000000001', 'DRAFT'),
  ('a1000000-0000-0000-0000-000000000002', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'c0000000-0000-0000-0000-000000000002', 'DRAFT'),
  ('a1000000-0000-0000-0000-000000000003', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'c0000000-0000-0000-0000-000000000003', 'DRAFT'),
  ('a1000000-0000-0000-0000-000000000004', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'c0000000-0000-0000-0000-000000000004', 'DRAFT')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.invitation_event_targetings (wedding_id, invitation_id, wedding_event_id)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'a1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'a1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000002'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'a1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000003'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'a1000000-0000-0000-0000-000000000003', 'e1000000-0000-0000-0000-000000000004'),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'a1000000-0000-0000-0000-000000000004', 'e1000000-0000-0000-0000-000000000005')
ON CONFLICT DO NOTHING;

UPDATE public.wedding_events
SET lifecycle_status = 'REMOVED'
WHERE id = 'e1000000-0000-0000-0000-000000000003';

UPDATE public.invitations SET status = 'READY' WHERE id = 'a1000000-0000-0000-0000-000000000001';
UPDATE public.invitations SET status = 'READY' WHERE id = 'a1000000-0000-0000-0000-000000000003';
UPDATE public.invitations SET status = 'MARKED_AS_SENT' WHERE id = 'a1000000-0000-0000-0000-000000000003';
UPDATE public.invitations SET status = 'READY' WHERE id = 'a1000000-0000-0000-0000-000000000004';
UPDATE public.invitations SET status = 'MARKED_AS_SENT' WHERE id = 'a1000000-0000-0000-0000-000000000004';

CREATE TEMP TABLE m4_tokens (
  label text PRIMARY KEY,
  raw_token text NOT NULL,
  invitation_id uuid NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  revoked_at timestamptz
);

INSERT INTO m4_tokens (label, raw_token, invitation_id, is_active, revoked_at)
VALUES
  ('ready',    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345', 'a1000000-0000-0000-0000-000000000001', true, NULL),
  ('draft',    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012346', 'a1000000-0000-0000-0000-000000000002', true, NULL),
  ('archived', 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012347', 'a1000000-0000-0000-0000-000000000003', true, NULL),
  ('deleting', 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012348', 'a1000000-0000-0000-0000-000000000004', true, NULL),
  ('revoked',  'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012349', 'a1000000-0000-0000-0000-000000000001', false, clock_timestamp());

INSERT INTO public.invitation_credentials (invitation_id, token_hash, is_active, revoked_at)
SELECT invitation_id, extensions.digest(raw_token, 'sha256'), is_active, revoked_at
FROM m4_tokens;

CREATE TEMP TABLE m4_results AS
SELECT
  label,
  internal.resolve_public_invitation(raw_token, 'test-' || label, 30) AS result
FROM m4_tokens
WHERE label <> 'revoked';

INSERT INTO m4_results (label, result)
SELECT 'revoked', internal.resolve_public_invitation(raw_token, 'test-revoked', 30)
FROM m4_tokens WHERE label = 'revoked';

INSERT INTO m4_results (label, result)
VALUES
  ('wrong', internal.resolve_public_invitation('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012350', 'test-wrong', 30)),
  ('malformed', internal.resolve_public_invitation('not-a-valid-token', 'test-malformed', 30));

-- ===========================================================================
-- 1. Valid resolve and sanitized DTO
-- ===========================================================================

SELECT is(
  (SELECT (result ->> 'ok')::boolean FROM m4_results WHERE label = 'ready'),
  true,
  'D-INV-001: READY Invitation resolves successfully.'
);

SELECT is(
  (SELECT result #>> '{invitation,status}' FROM m4_results WHERE label = 'ready'),
  'READY',
  'Lifecycle: READY does not require MARKED_AS_SENT to resolve.'
);

SELECT is(
  (SELECT result #>> '{invitation,wedding,name}' FROM m4_results WHERE label = 'ready'),
  'Active Wedding',
  'DTO: public Wedding display name is returned.'
);

SELECT is(
  (SELECT result #>> '{invitation,party,display_name}' FROM m4_results WHERE label = 'ready'),
  'Gia đình bác Tư',
  'DTO: InvitationParty display context is returned.'
);

SELECT is(
  (SELECT (result #>> '{invitation,party,invited_count}')::integer FROM m4_results WHERE label = 'ready'),
  4,
  'Invited Count: DTO uses Party invited_count, not named Guest count.'
);

SELECT is(
  (SELECT jsonb_array_length(result #> '{invitation,events}') FROM m4_results WHERE label = 'ready'),
  2,
  'Event filtering: REMOVED targeted Event is excluded from public DTO.'
);

SELECT is(
  (SELECT (result #> '{invitation,events}' -> 0 ->> 'date_precision') FROM m4_results WHERE label = 'ready'),
  'EXACT',
  'Exact Event: DTO marks Exact Date precision.'
);

SELECT is(
  (SELECT (result #> '{invitation,events}' -> 0 ->> 'rsvp_ready')::boolean FROM m4_results WHERE label = 'ready'),
  true,
  'Exact Event: rsvp_ready is true for exact-date Event foundation.'
);

SELECT is(
  (SELECT (result #> '{invitation,events}' -> 1 ->> 'date_precision') FROM m4_results WHERE label = 'ready'),
  'EXPECTED_MONTH',
  'Expected Month Event: DTO marks Expected Month precision.'
);

SELECT is(
  (SELECT (result #> '{invitation,events}' -> 1 ->> 'exact_date') FROM m4_results WHERE label = 'ready'),
  NULL,
  'Expected Month Event: DTO does not invent a fake exact_date.'
);

SELECT is(
  (SELECT (result #> '{invitation,events}' -> 1 ->> 'expected_year')::integer FROM m4_results WHERE label = 'ready'),
  2026,
  'Expected Month Event: DTO returns expected_year.'
);

SELECT is(
  (SELECT (result #> '{invitation,events}' -> 1 ->> 'expected_month')::integer FROM m4_results WHERE label = 'ready'),
  12,
  'Expected Month Event: DTO returns expected_month.'
);

SELECT is(
  (SELECT (result #> '{invitation,events}' -> 1 ->> 'rsvp_ready')::boolean FROM m4_results WHERE label = 'ready'),
  false,
  'Expected Month Event: rsvp_ready is false.'
);

SELECT is(
  (SELECT (result #> '{invitation}' ? 'wedding_id') FROM m4_results WHERE label = 'ready'),
  false,
  'DTO sanitization: internal wedding_id is not returned.'
);

SELECT is(
  (SELECT (result::text LIKE '%token_hash%' OR result::text LIKE '%credential_id%' OR result::text LIKE '%ABCDEFGHIJKLMNOPQRSTUVWXYZ%') FROM m4_results WHERE label = 'ready'),
  false,
  'DTO sanitization: token_hash, credential_id, and raw token are not returned.'
);

SELECT is(
  (SELECT result #>> '{invitation,wedding,public_contact_email}' FROM m4_results WHERE label = 'ready'),
  'hello@example.com',
  'Public contact: only configured public contact email is returned.'
);

-- ===========================================================================
-- 2. View tracking and retry-safe resolve
-- ===========================================================================

SELECT isnt(
  (SELECT first_viewed_at FROM public.invitations WHERE id = 'a1000000-0000-0000-0000-000000000001'),
  NULL,
  'View tracking: first_viewed_at is set on successful resolve.'
);

CREATE TEMP TABLE m4_view_before AS
SELECT first_viewed_at, last_viewed_at
FROM public.invitations
WHERE id = 'a1000000-0000-0000-0000-000000000001';

SELECT pg_sleep(0.02);

SELECT is(
  (SELECT (internal.resolve_public_invitation(raw_token, 'test-ready-repeat', 30) ->> 'ok')::boolean FROM m4_tokens WHERE label = 'ready'),
  true,
  'Resolve retry: repeated valid resolve remains successful.'
);

SELECT is(
  (SELECT i.first_viewed_at = b.first_viewed_at FROM public.invitations i CROSS JOIN m4_view_before b WHERE i.id = 'a1000000-0000-0000-0000-000000000001'),
  true,
  'View tracking: first_viewed_at is set only once.'
);

SELECT is(
  (SELECT i.last_viewed_at > b.last_viewed_at FROM public.invitations i CROSS JOIN m4_view_before b WHERE i.id = 'a1000000-0000-0000-0000-000000000001'),
  true,
  'View tracking: last_viewed_at updates on repeat resolve.'
);

-- ===========================================================================
-- 3. Unavailable, enumeration-safe, and rate-limited responses
-- ===========================================================================

SELECT is(
  (SELECT result ->> 'error_code' FROM m4_results WHERE label = 'draft'),
  'INVITATION_UNAVAILABLE',
  'DRAFT Invitation: public resolve returns generic unavailable.'
);

SELECT is(
  (SELECT result ->> 'error_code' FROM m4_results WHERE label = 'revoked'),
  'INVITATION_UNAVAILABLE',
  'Revoked credential: public resolve returns generic unavailable.'
);

SELECT is(
  (SELECT result ->> 'error_code' FROM m4_results WHERE label = 'wrong'),
  'INVITATION_UNAVAILABLE',
  'Wrong token: public resolve returns generic unavailable.'
);

SELECT is(
  (SELECT result ->> 'error_code' FROM m4_results WHERE label = 'malformed'),
  'INVITATION_UNAVAILABLE',
  'Malformed token: public resolve returns generic unavailable.'
);

SELECT is(
  (SELECT result ->> 'error_code' FROM m4_results WHERE label = 'archived'),
  'INVITATION_UNAVAILABLE',
  'ARCHIVED Wedding: M4 public resolve returns generic unavailable.'
);

SELECT is(
  (SELECT result ->> 'error_code' FROM m4_results WHERE label = 'deleting'),
  'INVITATION_UNAVAILABLE',
  'DELETING Wedding: public resolve returns generic unavailable.'
);

SELECT is(
  (SELECT count(DISTINCT result ->> 'error_code')::integer FROM m4_results WHERE label IN ('draft', 'revoked', 'wrong', 'archived')),
  1,
  'Enumeration safety: DRAFT, revoked, wrong token, and archived responses share the same public error code.'
);

SELECT is(
  (SELECT internal.resolve_public_invitation(raw_token, 'limited-key', 2) ->> 'error_code' FROM m4_tokens WHERE label = 'ready'),
  NULL,
  'Rate limit: first request under threshold is not rate limited.'
);

SELECT is(
  (SELECT internal.resolve_public_invitation(raw_token, 'limited-key', 2) ->> 'error_code' FROM m4_tokens WHERE label = 'ready'),
  NULL,
  'Rate limit: second request at threshold is not rate limited.'
);

SELECT is(
  (SELECT internal.resolve_public_invitation(raw_token, 'limited-key', 2) ->> 'error_code' FROM m4_tokens WHERE label = 'ready'),
  'RATE_LIMITED',
  'Rate limit: excess request returns safe RATE_LIMITED response.'
);

SELECT is(
  (SELECT count(*)::integer FROM private.class_d_rate_limits WHERE limiter_key LIKE '%ABCDEFGHIJKLMNOPQRSTUVWXYZ%'),
  0,
  'Rate limit privacy: limiter table does not persist raw token text.'
);

UPDATE private.class_d_rate_limits
SET window_start = clock_timestamp() - interval '61 seconds'
WHERE limiter_key = 'limited-key';

SELECT is(
  (SELECT internal.resolve_public_invitation(raw_token, 'limited-key', 2) ->> 'error_code' FROM m4_tokens WHERE label = 'ready'),
  NULL,
  'Rate limit: a new fixed window allows requests again.'
);

INSERT INTO private.class_d_rate_limits (limiter_key, window_start, request_count, updated_at)
VALUES
  ('stale-cleanup-1', clock_timestamp() - interval '11 minutes', 5, clock_timestamp() - interval '11 minutes'),
  ('stale-cleanup-2', clock_timestamp() - interval '11 minutes', 5, clock_timestamp() - interval '11 minutes')
ON CONFLICT (limiter_key) DO UPDATE
SET window_start = EXCLUDED.window_start,
    request_count = EXCLUDED.request_count,
    updated_at = EXCLUDED.updated_at;

SELECT is(
  (SELECT internal.resolve_public_invitation(raw_token, 'cleanup-key', 30) ->> 'error_code' FROM m4_tokens WHERE label = 'ready'),
  NULL,
  'Rate limit cleanup: resolve still succeeds while opportunistic cleanup runs.'
);

SELECT is(
  (SELECT count(*)::integer FROM private.class_d_rate_limits WHERE limiter_key LIKE 'stale-cleanup-%'),
  0,
  'Rate limit cleanup: expired fixed-window rows are opportunistically removed.'
);

-- ===========================================================================
-- 4. Token hash and Class-D helper boundary
-- ===========================================================================

SELECT is(
  (SELECT count(*)::integer
   FROM public.invitation_credentials c
   JOIN m4_tokens t ON c.token_hash = extensions.digest(t.raw_token, 'sha256')
   WHERE t.label = 'ready' AND c.is_active = true),
  1,
  'Token hash lookup: SHA-256(raw token) matches active token_hash.'
);

SELECT is(
  to_regprocedure('api_v1.resolve_public_invitation(text, character varying, integer)') IS NULL,
  true,
  'IMPL-CONFLICT-012: resolve helper is not present in organizer api_v1 schema.'
);

SELECT is(
  has_function_privilege('anon', 'internal.resolve_public_invitation(text, character varying, integer)', 'EXECUTE'),
  false,
  'Class-D helper grants: anon has no EXECUTE privilege.'
);

SELECT is(
  has_function_privilege('authenticated', 'internal.resolve_public_invitation(text, character varying, integer)', 'EXECUTE'),
  false,
  'Class-D helper grants: authenticated has no EXECUTE privilege.'
);

SELECT is(
  has_function_privilege('service_role', 'internal.resolve_public_invitation(text, character varying, integer)', 'EXECUTE'),
  true,
  'Class-D helper grants: service_role has the narrow required EXECUTE privilege.'
);

SELECT is(
  has_function_privilege('public', 'internal.resolve_public_invitation(text, character varying, integer)', 'EXECUTE'),
  false,
  'Class-D helper grants: PUBLIC execute is absent.'
);

RESET ROLE;
SET ROLE service_role;

SELECT is(
  (internal.resolve_public_invitation('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345', 'service-role-call', 30) ->> 'ok')::boolean,
  true,
  'Class-D helper boundary: service_role can invoke the server-only bridge.'
);

RESET ROLE;
SET ROLE anon;
SET request.jwt.claims = '{}';

SELECT throws_ok(
  $$ SELECT internal.resolve_public_invitation('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345', 'client-chosen-key', 30); $$,
  '42501',
  NULL,
  'Class-D helper boundary: anon cannot directly invoke the server-only bridge.'
);

SELECT throws_ok($$ SELECT * FROM public.invitation_credentials LIMIT 1; $$, '42501', NULL, 'Security: anon cannot SELECT invitation_credentials.');
SELECT throws_ok($$ SELECT * FROM public.invitations LIMIT 1; $$, '42501', NULL, 'Security: anon cannot SELECT invitations.');
SELECT throws_ok($$ SELECT * FROM public.invitation_parties LIMIT 1; $$, '42501', NULL, 'Security: anon cannot SELECT invitation_parties.');
SELECT throws_ok($$ SELECT * FROM public.guests LIMIT 1; $$, '42501', NULL, 'Security: anon cannot SELECT guests.');
SELECT throws_ok($$ SELECT * FROM public.wedding_events LIMIT 1; $$, '42501', NULL, 'Security: anon cannot SELECT wedding_events.');
SELECT throws_ok($$ SELECT * FROM public.wedding_members LIMIT 1; $$, '42501', NULL, 'Security: anon cannot SELECT wedding_members.');
SELECT throws_ok($$ SELECT * FROM private.class_d_rate_limits LIMIT 1; $$, '42501', NULL, 'Security: anon cannot SELECT limiter persistence.');

RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub": "d1000000-0000-0000-0000-000000000001"}', true);

SELECT throws_ok(
  $$ SELECT internal.resolve_public_invitation('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345', 'organizer-chosen-key', 30); $$,
  '42501',
  NULL,
  'Class-D helper boundary: authenticated organizer cannot directly invoke the server-only bridge.'
);

SELECT throws_ok(
  $$ UPDATE private.class_d_rate_limits SET request_count = 0 WHERE limiter_key = 'limited-key'; $$,
  '42501',
  NULL,
  'Rate limiter authority: authenticated organizer cannot reset limiter counters.'
);

SELECT throws_ok(
  $$ DELETE FROM private.class_d_rate_limits WHERE limiter_key = 'limited-key'; $$,
  '42501',
  NULL,
  'Rate limiter authority: authenticated organizer cannot delete limiter state.'
);

RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub": "d1000000-0000-0000-0000-000000000002"}', true);

SELECT throws_ok(
  $$ SELECT internal.resolve_public_invitation('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345', 'outsider-chosen-key', 30); $$,
  '42501',
  NULL,
  'Class-D helper boundary: authenticated outsider cannot directly invoke the server-only bridge.'
);

RESET ROLE;

SELECT is(
  (SELECT count(*)::integer
   FROM private.class_d_rate_limits
   WHERE limiter_key IN ('client-chosen-key', 'organizer-chosen-key', 'outsider-chosen-key')),
  0,
  'Rate limiter authority: denied clients cannot choose or persist limiter keys.'
);

RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
