BEGIN;
SELECT plan(43);

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------
INSERT INTO auth.users (id, email) VALUES
  ('17000000-0000-0000-0000-000000000001', 'm81c-owner@test.local'),
  ('17000000-0000-0000-0000-000000000002', 'm81c-collab@test.local')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.weddings (id, name, cultural_context, exact_date, status)
VALUES ('17010000-0000-0000-0000-000000000001', 'M8.1C Wedding', 'TUY_CHON', '2027-08-17', 'ACTIVE');

INSERT INTO public.wedding_members
  (id, wedding_id, user_id, display_name, profile_email, role, status)
VALUES
  ('17020000-0000-0000-0000-000000000001', '17010000-0000-0000-0000-000000000001', '17000000-0000-0000-0000-000000000001', 'M8.1C Owner', 'm81c-owner@test.local', 'OWNER', 'ACTIVE'),
  ('17020000-0000-0000-0000-000000000002', '17010000-0000-0000-0000-000000000001', '17000000-0000-0000-0000-000000000002', 'M8.1C Collaborator', 'm81c-collab@test.local', 'COLLABORATOR', 'ACTIVE');

INSERT INTO public.wedding_events
  (id, wedding_id, name, exact_date, map_link, lifecycle_status, is_main_event)
VALUES
  ('17030000-0000-0000-0000-000000000001', '17010000-0000-0000-0000-000000000001', 'Public Event', '2027-08-17', 'https://maps.example/m81c', 'ACTIVE', true),
  ('17030000-0000-0000-0000-000000000002', '17010000-0000-0000-0000-000000000001', 'Removed Event', '2027-08-18', NULL, 'REMOVED', false);

INSERT INTO public.invitation_parties (id, wedding_id, display_name, invited_count)
VALUES ('17040000-0000-0000-0000-000000000001', '17010000-0000-0000-0000-000000000001', 'M8.1C Party', 2);

INSERT INTO public.invitations (id, wedding_id, invitation_party_id, status)
VALUES ('17050000-0000-0000-0000-000000000001', '17010000-0000-0000-0000-000000000001', '17040000-0000-0000-0000-000000000001', 'DRAFT');

INSERT INTO public.budget_items (id, wedding_id, name, confirmed_cost, status)
VALUES ('17060000-0000-0000-0000-000000000001', '17010000-0000-0000-0000-000000000001', 'M8.1C Item', 100.00, 'ACTIVE');

INSERT INTO public.installments (id, budget_item_id, amount, due_date, status)
VALUES ('17070000-0000-0000-0000-000000000001', '17060000-0000-0000-0000-000000000001', 100.00, '2027-08-01', 'PENDING');

INSERT INTO public.guests (id, wedding_id, name)
VALUES ('17080000-0000-0000-0000-000000000001', '17010000-0000-0000-0000-000000000001', 'Normalized Guest');

-- ---------------------------------------------------------------------------
-- map_link contract
-- ---------------------------------------------------------------------------
SELECT is(
  EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.wedding_events'::regclass
      AND conname = 'chk_wedding_events_map_link_https'
      AND contype = 'c'
  ),
  true,
  'map_link has a server-side HTTPS allowlist constraint.'
);

SELECT lives_ok($$UPDATE public.wedding_events SET map_link = NULL WHERE id = '17030000-0000-0000-0000-000000000002'$$, 'map_link remains nullable.');
SELECT lives_ok($$UPDATE public.wedding_events SET map_link = '' WHERE id = '17030000-0000-0000-0000-000000000002'$$, 'Empty map_link remains accepted.');
SELECT lives_ok($$UPDATE public.wedding_events SET map_link = '   ' WHERE id = '17030000-0000-0000-0000-000000000002'$$, 'Whitespace-only map_link preserves blank semantics.');
SELECT lives_ok($$UPDATE public.wedding_events SET map_link = 'https://maps.google.com/place/test' WHERE id = '17030000-0000-0000-0000-000000000002'$$, 'HTTPS map_link is accepted.');
SELECT lives_ok($$UPDATE public.wedding_events SET map_link = '  https://example.com/path?q=1#map  ' WHERE id = '17030000-0000-0000-0000-000000000002'$$, 'Surrounding whitespace is ignored for validation.');
SELECT lives_ok($$UPDATE public.wedding_events SET map_link = 'HTTPS://EXAMPLE.COM/MAP' WHERE id = '17030000-0000-0000-0000-000000000002'$$, 'HTTPS scheme comparison is case-insensitive.');
SELECT throws_ok($$UPDATE public.wedding_events SET map_link = 'javascript:alert(1)' WHERE id = '17030000-0000-0000-0000-000000000002'$$, '23514', NULL, 'javascript scheme is rejected.');
SELECT throws_ok($$UPDATE public.wedding_events SET map_link = 'data:text/html,test' WHERE id = '17030000-0000-0000-0000-000000000002'$$, '23514', NULL, 'data scheme is rejected.');
SELECT throws_ok($$UPDATE public.wedding_events SET map_link = 'file:///tmp/map' WHERE id = '17030000-0000-0000-0000-000000000002'$$, '23514', NULL, 'file scheme is rejected.');
SELECT throws_ok($$UPDATE public.wedding_events SET map_link = 'ftp://example.com/map' WHERE id = '17030000-0000-0000-0000-000000000002'$$, '23514', NULL, 'ftp scheme is rejected.');
SELECT throws_ok($$UPDATE public.wedding_events SET map_link = 'blob:https://example.com/id' WHERE id = '17030000-0000-0000-0000-000000000002'$$, '23514', NULL, 'blob scheme is rejected.');
SELECT throws_ok($$UPDATE public.wedding_events SET map_link = '//example.com/map' WHERE id = '17030000-0000-0000-0000-000000000002'$$, '23514', NULL, 'Scheme-relative URL is rejected.');
SELECT throws_ok($$UPDATE public.wedding_events SET map_link = 'example.com/map' WHERE id = '17030000-0000-0000-0000-000000000002'$$, '23514', NULL, 'Bare host is rejected.');
SELECT throws_ok($$UPDATE public.wedding_events SET map_link = 'httpsx://example.com/map' WHERE id = '17030000-0000-0000-0000-000000000002'$$, '23514', NULL, 'Malformed near-match scheme is rejected.');
SELECT throws_ok($$UPDATE public.wedding_events SET map_link = 'https://' WHERE id = '17030000-0000-0000-0000-000000000002'$$, '23514', NULL, 'HTTPS URL without an authority is rejected.');

SELECT set_config('role', 'authenticated', true);
SELECT set_config('request.jwt.claims', '{"sub":"17000000-0000-0000-0000-000000000001"}', true);
SELECT throws_ok($$UPDATE public.wedding_events SET map_link = 'javascript:alert(1)' WHERE id = '17030000-0000-0000-0000-000000000001'$$, '23514', NULL, 'Invalid direct Class-B mutation is rejected.');

-- ---------------------------------------------------------------------------
-- Function ownership, search path, and grant hygiene
-- ---------------------------------------------------------------------------
SELECT set_config('role', 'postgres', true);

SELECT is((SELECT pg_get_userbyid(proowner) FROM pg_proc WHERE oid = 'public.fn_normalize_guest_contacts()'::regprocedure), 'trusted_function_owner', 'Guest normalization trigger owner is trusted_function_owner.');
SELECT is((SELECT prosecdef FROM pg_proc WHERE oid = 'public.fn_normalize_guest_contacts()'::regprocedure), true, 'Guest normalization remains SECURITY DEFINER.');
SELECT is((SELECT array_to_string(proconfig, ',') FROM pg_proc WHERE oid = 'public.fn_normalize_guest_contacts()'::regprocedure), 'search_path=""', 'Guest normalization has an empty search_path.');
SELECT is(has_function_privilege('public', 'public.fn_normalize_guest_contacts()', 'EXECUTE'), false, 'PUBLIC cannot execute guest normalization.');
SELECT is(has_function_privilege('authenticated', 'public.fn_normalize_guest_contacts()', 'EXECUTE'), false, 'authenticated cannot execute guest normalization.');
SELECT is(has_function_privilege('anon', 'public.fn_normalize_guest_contacts()', 'EXECUTE'), false, 'anon cannot execute guest normalization.');

SELECT is((SELECT pg_get_userbyid(proowner) FROM pg_proc WHERE oid = 'public.fn_invitation_targeting_guard()'::regprocedure), 'trusted_function_owner', 'Targeting guard owner is trusted_function_owner.');
SELECT is((SELECT prosecdef FROM pg_proc WHERE oid = 'public.fn_invitation_targeting_guard()'::regprocedure), true, 'Targeting guard remains SECURITY DEFINER.');
SELECT is((SELECT array_to_string(proconfig, ',') FROM pg_proc WHERE oid = 'public.fn_invitation_targeting_guard()'::regprocedure), 'search_path=""', 'Targeting guard has an empty search_path.');
SELECT is(has_function_privilege('public', 'public.fn_invitation_targeting_guard()', 'EXECUTE'), false, 'PUBLIC cannot execute targeting guard.');
SELECT is(has_function_privilege('authenticated', 'public.fn_invitation_targeting_guard()', 'EXECUTE'), false, 'authenticated cannot execute targeting guard.');
SELECT is(has_function_privilege('anon', 'public.fn_invitation_targeting_guard()', 'EXECUTE'), false, 'anon cannot execute targeting guard.');

SELECT is((SELECT pg_get_userbyid(proowner) FROM pg_proc WHERE oid = 'internal.recompute_installment_status(uuid)'::regprocedure), 'trusted_function_owner', 'Finance helper owner remains trusted_function_owner.');
SELECT is((SELECT prosecdef FROM pg_proc WHERE oid = 'internal.recompute_installment_status(uuid)'::regprocedure), false, 'Finance helper remains invoker-security.');
SELECT is((SELECT array_to_string(proconfig, ',') FROM pg_proc WHERE oid = 'internal.recompute_installment_status(uuid)'::regprocedure), 'search_path=""', 'Finance helper has an empty search_path.');
SELECT is(has_function_privilege('public', 'internal.recompute_installment_status(uuid)', 'EXECUTE'), false, 'PUBLIC cannot execute Finance helper.');
SELECT is(has_function_privilege('authenticated', 'internal.recompute_installment_status(uuid)', 'EXECUTE'), false, 'authenticated cannot execute Finance helper.');
SELECT is(has_function_privilege('anon', 'internal.recompute_installment_status(uuid)', 'EXECUTE'), false, 'anon cannot execute Finance helper.');
SELECT is(
  has_function_privilege('service_role', 'public.fn_normalize_guest_contacts()', 'EXECUTE')
  OR has_function_privilege('service_role', 'public.fn_invitation_targeting_guard()', 'EXECUTE')
  OR has_function_privilege('service_role', 'internal.recompute_installment_status(uuid)', 'EXECUTE'),
  false,
  'service_role has no direct EXECUTE on the hardened helpers.'
);

-- ---------------------------------------------------------------------------
-- Trigger and trusted caller regressions
-- ---------------------------------------------------------------------------
SELECT set_config('role', 'authenticated', true);
SELECT set_config('request.jwt.claims', '{"sub":"17000000-0000-0000-0000-000000000001"}', true);

SELECT lives_ok($$UPDATE public.guests SET email = ' Guest@Example.COM ', phone = '+84 912 345 678' WHERE id = '17080000-0000-0000-0000-000000000001'$$, 'Guest normalization trigger still runs on the existing authorized update path without client EXECUTE.');
SELECT is((SELECT normalized_email || '|' || normalized_phone FROM public.guests WHERE id = '17080000-0000-0000-0000-000000000001'), 'guest@example.com|0912345678', 'Guest normalization behavior is unchanged.');
SELECT lives_ok($$INSERT INTO public.invitation_event_targetings (wedding_id, invitation_id, wedding_event_id) VALUES ('17010000-0000-0000-0000-000000000001', '17050000-0000-0000-0000-000000000001', '17030000-0000-0000-0000-000000000001')$$, 'Targeting trigger accepts an active same-Wedding event without client EXECUTE.');
SELECT throws_ok($$INSERT INTO public.invitation_event_targetings (wedding_id, invitation_id, wedding_event_id) VALUES ('17010000-0000-0000-0000-000000000001', '17050000-0000-0000-0000-000000000001', '17030000-0000-0000-0000-000000000002')$$, 'P0002', 'INVALID_INVITATION_TARGET: targeted event must be active and same-Wedding.', 'Targeting guard still rejects a removed event.');

SELECT lives_ok($$SELECT api_v1.create_payment('17090000-0000-0000-0000-000000000001', '17060000-0000-0000-0000-000000000001', '17070000-0000-0000-0000-000000000001', 100.00, '2027-08-01', '17020000-0000-0000-0000-000000000001', NULL, 'Batch 17 regression')$$, 'Trusted FIN-001 flow can invoke the hidden Finance helper.');
SELECT is((SELECT status FROM public.installments WHERE id = '17070000-0000-0000-0000-000000000001'), 'PAID', 'Finance helper still recomputes installment status.');

SELECT set_config('role', 'postgres', true);
UPDATE public.invitations SET status = 'READY' WHERE id = '17050000-0000-0000-0000-000000000001';
INSERT INTO public.invitation_credentials (invitation_id, token_hash)
VALUES ('17050000-0000-0000-0000-000000000001', extensions.digest('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345', 'sha256'));
SELECT is(
  internal.resolve_public_invitation('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345', 'm81c-map-link', 30) #>> '{invitation,events,0,map_link}',
  'https://maps.example/m81c',
  'D-INV-001 still exposes the validated HTTPS map_link.'
);

SELECT * FROM finish();
ROLLBACK;
