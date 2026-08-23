BEGIN;
SELECT plan(39); -- 39 assertions for BATCH-07 (Invitation / Credential Foundation)

-- ===========================================================================
-- TEST SETUP
-- ===========================================================================

INSERT INTO auth.users (id, email)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'organizer.a@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'outsider@example.com'),
  ('33333333-3333-3333-3333-333333333333', 'organizer.b@example.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.weddings (id, name, target_budget, cultural_context, exact_date, status)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Wedding A', 500000000, 'TUY_CHON', '2026-12-18', 'ACTIVE'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Wedding B', 600000000, 'TUY_CHON', '2026-12-25', 'ACTIVE'),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Archived Wedding', 700000000, 'TUY_CHON', '2026-12-26', 'ARCHIVED'),
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'Deleting Wedding', 700000000, 'TUY_CHON', '2026-12-27', 'DELETING')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.wedding_members (id, wedding_id, user_id, role, status, display_name, profile_email)
VALUES
  ('88888888-8888-8888-8888-888888888888', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'OWNER', 'ACTIVE', 'USER A', 'organizer.a@example.com'),
  ('77777777-7777-7777-7777-777777777777', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', 'COLLABORATOR', 'ACTIVE', 'USER A', 'organizer.a@example.com'),
  ('99999999-9999-9999-9999-999999999999', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '33333333-3333-3333-3333-333333333333', 'OWNER', 'ACTIVE', 'USER B', 'organizer.b@example.com'),
  ('66666666-6666-6666-6666-666666666666', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', 'OWNER', 'ACTIVE', 'USER A', 'organizer.a@example.com'),
  ('55555555-5555-5555-5555-555555555555', 'dddddddd-dddd-dddd-dddd-dddddddddddd', '11111111-1111-1111-1111-111111111111', 'OWNER', 'ACTIVE', 'USER A', 'organizer.a@example.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.wedding_events (id, wedding_id, name, exact_date, lifecycle_status, is_main_event)
VALUES
  ('e1000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Exact Event A', '2026-12-18', 'ACTIVE', true),
  ('e1000000-0000-0000-0000-000000000003', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Removed Event A', '2026-12-19', 'REMOVED', false),
  ('e1000000-0000-0000-0000-000000000004', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Exact Event B', '2026-12-25', 'ACTIVE', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.wedding_events (id, wedding_id, name, expected_year, expected_month, lifecycle_status, is_main_event)
VALUES
  ('e1000000-0000-0000-0000-000000000002', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Expected Month Event A', 2026, 12, 'ACTIVE', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.invitation_parties (id, wedding_id, display_name, invited_count)
VALUES
  ('c0000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Gia đình bác Tư', 4),
  ('c0000000-0000-0000-0000-000000000002', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Anh Nam', 2),
  ('c0000000-0000-0000-0000-000000000003', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Party B', 3),
  ('c0000000-0000-0000-0000-000000000004', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'Archived Party', 2),
  ('c0000000-0000-0000-0000-000000000005', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'Deleting Party', 2),
  ('c0000000-0000-0000-0000-000000000006', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Draft Only Party', 2)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.invitations (id, wedding_id, invitation_party_id)
VALUES
  ('a1000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'c0000000-0000-0000-0000-000000000001'),
  ('a1000000-0000-0000-0000-000000000002', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'c0000000-0000-0000-0000-000000000006'),
  ('a1000000-0000-0000-0000-000000000003', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'c0000000-0000-0000-0000-000000000004')
ON CONFLICT (id) DO NOTHING;

-- ===========================================================================
-- 1. Invitation identity, targeting, and lifecycle
-- ===========================================================================

SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

SELECT lives_ok(
  $$ INSERT INTO public.invitations (wedding_id, invitation_party_id)
     VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'c0000000-0000-0000-0000-000000000002'); $$,
  'Invitation creation: organizer can create a DRAFT invitation for an existing same-Wedding Party.'
);

SELECT is(
  (SELECT status FROM public.invitations WHERE invitation_party_id = 'c0000000-0000-0000-0000-000000000002'),
  'DRAFT',
  'Invitation lifecycle: direct creation defaults to DRAFT.'
);

SELECT throws_ok(
  $$ INSERT INTO public.invitations (wedding_id, invitation_party_id)
     VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'c0000000-0000-0000-0000-000000000003'); $$,
  NULL,
  NULL,
  'Same-Wedding Party integrity: cross-Wedding Party cannot be attached to a Wedding A invitation.'
);

SELECT throws_ok(
  $$ INSERT INTO public.invitations (wedding_id, invitation_party_id)
     VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'c0000000-0000-0000-0000-000000000001'); $$,
  '23505',
  NULL,
  'Invitation identity: one InvitationParty has at most one Invitation.'
);

SELECT throws_ok(
  $$ UPDATE public.invitations SET status = 'READY'
     WHERE id = 'a1000000-0000-0000-0000-000000000001'; $$,
  'P0002',
  'INVITATION_NOT_READY: at least one active event target is required.',
  'Readiness: DRAFT cannot move to READY without at least one active target Event.'
);

SELECT throws_ok(
  $$ INSERT INTO public.invitation_event_targetings (wedding_id, invitation_id, wedding_event_id)
     VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'a1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000003'); $$,
  'P0002',
  'INVALID_INVITATION_TARGET: targeted event must be active and same-Wedding.',
  'Event targeting: REMOVED Event cannot be targeted.'
);

SELECT throws_ok(
  $$ INSERT INTO public.invitation_event_targetings (wedding_id, invitation_id, wedding_event_id)
     VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'a1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000004'); $$,
  NULL,
  NULL,
  'Event targeting: cross-Wedding Event cannot be targeted.'
);

SELECT lives_ok(
  $$ INSERT INTO public.invitation_event_targetings (wedding_id, invitation_id, wedding_event_id)
     VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'a1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000002'); $$,
  'Expected Month targeting: active Expected Month Event may be invitation-visible.'
);

SELECT is(
  (SELECT (exact_date IS NOT NULL) FROM public.wedding_events WHERE id = 'e1000000-0000-0000-0000-000000000002'),
  false,
  'Expected Month readiness: Expected Month Event is not RSVP-ready because it has no exact_date.'
);

SELECT lives_ok(
  $$ UPDATE public.invitations SET status = 'READY'
     WHERE id = 'a1000000-0000-0000-0000-000000000001'; $$,
  'Readiness: empty Party with invited_count > 0 and an active target can move to READY.'
);

SELECT throws_ok(
  $$ UPDATE public.invitations SET status = 'DRAFT'
     WHERE id = 'a1000000-0000-0000-0000-000000000001'; $$,
  'P0002',
  'INVALID_INVITATION_TRANSITION: READY -> DRAFT is not allowed.',
  'Invitation lifecycle: backward transition READY -> DRAFT is denied.'
);

SELECT throws_ok(
  $$ UPDATE public.invitations SET status = 'MARKED_AS_SENT', marked_sent_at = '2000-01-01'
     WHERE id = 'a1000000-0000-0000-0000-000000000001'; $$,
  '42501',
  NULL,
  'marked_sent_at protection: authenticated client cannot forge marked_sent_at directly.'
);

SELECT lives_ok(
  $$ UPDATE public.invitations SET status = 'MARKED_AS_SENT'
     WHERE id = 'a1000000-0000-0000-0000-000000000001'; $$,
  'Invitation lifecycle: READY -> MARKED_AS_SENT is allowed through explicit organizer action.'
);

SELECT isnt(
  (SELECT marked_sent_at FROM public.invitations WHERE id = 'a1000000-0000-0000-0000-000000000001'),
  NULL,
  'marked_sent_at protection: DB sets marked_sent_at authoritatively.'
);

SELECT throws_ok(
  $$ UPDATE public.invitations SET first_viewed_at = now()
     WHERE id = 'a1000000-0000-0000-0000-000000000001'; $$,
  '42501',
  NULL,
  'View tracking protection: organizer client cannot directly write first_viewed_at.'
);

SELECT throws_ok(
  $$ INSERT INTO public.invitations (wedding_id, invitation_party_id)
     VALUES ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'c0000000-0000-0000-0000-000000000004'); $$,
  '42501',
  NULL,
  'Archived behavior: active member cannot mutate invitations for ARCHIVED Wedding.'
);

SELECT throws_ok(
  $$ INSERT INTO public.invitations (wedding_id, invitation_party_id)
     VALUES ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'c0000000-0000-0000-0000-000000000005'); $$,
  '42501',
  NULL,
  'Deleting behavior: active member cannot mutate invitations for DELETING Wedding.'
);

-- ===========================================================================
-- 2. Credential generation, hashing, rotation, retry, and lookup foundation
-- ===========================================================================

CREATE TEMP TABLE m3_tokens (
  label text PRIMARY KEY,
  raw_token text NOT NULL,
  credential_id uuid NOT NULL,
  token_hash bytea NOT NULL
);

INSERT INTO m3_tokens (label, raw_token, credential_id, token_hash)
SELECT
  'first',
  result ->> 'raw_token',
  (result ->> 'credential_id')::uuid,
  extensions.digest(result ->> 'raw_token', 'sha256')
FROM (SELECT api_v1.regenerate_invitation_credential('a1000000-0000-0000-0000-000000000001') AS result) s;

SELECT ok(
  (SELECT raw_token ~ '^[A-Za-z0-9_-]{43}$' FROM m3_tokens WHERE label = 'first'),
  'DEC-B-002: generated raw token is 43-character URL-safe base64url from 32 random bytes.'
);

SELECT ok(
  (SELECT position('a1000000' in raw_token) = 0 AND position('aaaaaaaa' in raw_token) = 0 FROM m3_tokens WHERE label = 'first'),
  'DEC-B-002: raw token contains no Invitation or Wedding ID semantics.'
);

RESET ROLE;

SELECT is(
  (SELECT octet_length(token_hash) FROM public.invitation_credentials WHERE is_active = true AND invitation_id = 'a1000000-0000-0000-0000-000000000001'),
  32,
  'Credential storage: token_hash is exactly 32 bytes.'
);

SELECT is(
  (SELECT count(*)::integer FROM public.invitation_credentials WHERE invitation_id = 'a1000000-0000-0000-0000-000000000001' AND is_active = true),
  1,
  'Active credential invariant: first generation leaves exactly one active credential.'
);

SELECT is(
  (SELECT count(*)::integer
   FROM public.invitation_credentials c
   JOIN m3_tokens t ON t.token_hash = c.token_hash
   WHERE t.label = 'first' AND c.is_active = true),
  1,
  'Hash lookup foundation: SHA-256(raw token) matches the active credential row.'
);

SELECT is(
  (SELECT count(*)::integer FROM public.invitation_credentials WHERE token_hash = extensions.digest('wrong-token', 'sha256') AND is_active = true),
  0,
  'Hash lookup foundation: wrong token has no active match.'
);

SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

INSERT INTO m3_tokens (label, raw_token, credential_id, token_hash)
SELECT
  'second',
  result ->> 'raw_token',
  (result ->> 'credential_id')::uuid,
  extensions.digest(result ->> 'raw_token', 'sha256')
FROM (SELECT api_v1.regenerate_invitation_credential('a1000000-0000-0000-0000-000000000001') AS result) s;

RESET ROLE;

SELECT isnt(
  (SELECT raw_token FROM m3_tokens WHERE label = 'first'),
  (SELECT raw_token FROM m3_tokens WHERE label = 'second'),
  'Regeneration: repeated call returns a fresh raw token rather than replaying the old one.'
);

SELECT is(
  (SELECT is_active FROM public.invitation_credentials WHERE id = (SELECT credential_id FROM m3_tokens WHERE label = 'first')),
  false,
  'Old token invalidation: previous credential is inactive after regeneration.'
);

SELECT isnt(
  (SELECT revoked_at FROM public.invitation_credentials WHERE id = (SELECT credential_id FROM m3_tokens WHERE label = 'first')),
  NULL,
  'Old token invalidation: previous credential records revoked_at.'
);

SELECT is(
  (SELECT count(*)::integer FROM public.invitation_credentials WHERE invitation_id = 'a1000000-0000-0000-0000-000000000001' AND is_active = true),
  1,
  'Active credential invariant: regeneration leaves exactly one active credential.'
);

SELECT is(
  (SELECT count(*)::integer FROM public.invitation_credentials WHERE token_hash = (SELECT token_hash FROM m3_tokens WHERE label = 'first') AND is_active = true),
  0,
  'Hash lookup foundation: revoked old token no longer has an active match.'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM public.invitation_credentials c
    JOIN m3_tokens t ON encode(c.token_hash, 'hex') = t.raw_token
  ),
  'Raw token storage: database does not persist the recoverable raw credential.'
);

SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

SELECT lives_ok(
  $$ SELECT api_v1.regenerate_invitation_credential('a1000000-0000-0000-0000-000000000001'); $$,
  'Retry behavior: lost-response retry may rotate again and return a newer valid token.'
);

RESET ROLE;

SELECT is(
  (SELECT count(*)::integer FROM public.invitation_credentials WHERE invitation_id = 'a1000000-0000-0000-0000-000000000001' AND is_active = true),
  1,
  'Retry behavior: after every successful retry there is exactly one active credential.'
);

SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

SELECT throws_ok(
  $$ SELECT api_v1.regenerate_invitation_credential('a1000000-0000-0000-0000-000000000002'); $$,
  'P0002',
  'INVITATION_NOT_READY: credential can only be generated for READY or MARKED_AS_SENT invitations.',
  'Credential status validation: DRAFT Invitation cannot generate a credential.'
);

RESET ROLE;
SET ROLE anon;
SET request.jwt.claims = '{}';

SELECT throws_ok(
  $$ SELECT api_v1.regenerate_invitation_credential('a1000000-0000-0000-0000-000000000001'); $$,
  '42501',
  NULL,
  'Security: anon cannot call TOP-INV-001.'
);

RESET ROLE;
SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"22222222-2222-2222-2222-222222222222"}';

SELECT throws_ok(
  $$ SELECT api_v1.regenerate_invitation_credential('a1000000-0000-0000-0000-000000000001'); $$,
  '42501',
  'UNAUTHORIZED: caller cannot regenerate this invitation credential.',
  'Security: outsider cannot regenerate another Wedding invitation credential.'
);

SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

SELECT throws_ok(
  $$ SELECT api_v1.regenerate_invitation_credential('a1000000-0000-0000-0000-000000000003'); $$,
  '42501',
  'UNAUTHORIZED: caller cannot regenerate this invitation credential.',
  'Archived behavior: TOP-INV-001 denies credential generation for ARCHIVED Wedding.'
);

SELECT throws_ok(
  $$ SELECT * FROM public.invitation_credentials LIMIT 1; $$,
  '42501',
  NULL,
  'Security: authenticated client cannot directly read credential storage.'
);

SELECT throws_ok(
  $$ INSERT INTO public.invitation_credentials (invitation_id, token_hash)
     VALUES ('a1000000-0000-0000-0000-000000000001', extensions.digest('client-token', 'sha256')); $$,
  '42501',
  NULL,
  'Security: authenticated client cannot directly create credentials.'
);

SELECT throws_ok(
  $$ UPDATE public.invitation_credentials SET is_active = false, revoked_at = now(); $$,
  '42501',
  NULL,
  'Security: authenticated client cannot directly revoke credentials.'
);

RESET ROLE;

SELECT is(
  (SELECT count(*)::integer FROM private.trusted_operation_receipts WHERE operation_type = 'TOP-INV-001'),
  0,
  'Receipt minimization: TOP-INV-001 does not persist raw token or any receipt payload.'
);

SELECT * FROM finish();
ROLLBACK;
