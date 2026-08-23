BEGIN;
SELECT plan(27); -- 27 assertions for BATCH-06 (Excel Guest Import)

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
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Archived Wedding', 700000000, 'TUY_CHON', '2026-12-26', 'ARCHIVED')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.wedding_members (id, wedding_id, user_id, role, status, display_name, profile_email)
VALUES
  ('88888888-8888-8888-8888-888888888888', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'OWNER', 'ACTIVE', 'USER A', 'organizer.a@example.com'),
  ('77777777-7777-7777-7777-777777777777', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', 'COLLABORATOR', 'ACTIVE', 'USER A', 'organizer.a@example.com'),
  ('99999999-9999-9999-9999-999999999999', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '33333333-3333-3333-3333-333333333333', 'OWNER', 'ACTIVE', 'USER B', 'organizer.b@example.com'),
  ('66666666-6666-6666-6666-666666666666', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', 'OWNER', 'ACTIVE', 'USER A', 'organizer.a@example.com')
ON CONFLICT (id) DO NOTHING;

RESET ROLE;
INSERT INTO public.primary_groups (id, wedding_id, name)
VALUES
  ('d0000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Đại học'),
  ('d0000000-0000-0000-0000-000000000002', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Đội bóng')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.invitation_parties (id, wedding_id, display_name, invited_count)
VALUES
  ('c0000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Party Existing A', 2),
  ('c0000000-0000-0000-0000-000000000002', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Party Existing B', 3)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.guests (id, wedding_id, name, phone, email, side, guest_source, primary_group_id, invitation_party_id)
VALUES
  ('e0000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Existing Phone', '0912345678', 'existing@example.com', 'COMMON', 'OTHER', 'd0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001')
ON CONFLICT (id) DO NOTHING;

SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

-- ===========================================================================
-- 1. Valid import, blank Party Key, grouping, counts, groups, warnings
-- ===========================================================================

SELECT lives_ok(
  $$
  SELECT api_v1.confirm_guest_import(
    '90000000-0000-0000-0000-000000000001',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '[
      {"guest_name":"Nguyễn Văn A","phone":"0912345678","email":"new-a@example.com","side":"COMMON","primary_group_name":"Đại học","party_key":"","party_display_name":"","invited_count":"","guest_source":"BRIDE"},
      {"guest_name":"Trần Thị B","phone":"0922222222","email":"b@example.com","side":"BRIDE_SIDE","primary_group_name":"Bạn đá bóng","party_key":"P1","party_display_name":"Gia đình chị B","invited_count":"5","guest_source":"BRIDE_PARENTS"},
      {"guest_name":"Trần Văn C","phone":"0933333333","email":"c@example.com","side":"GROOM_SIDE","primary_group_name":"Bạn đá bóng","party_key":"P1","party_display_name":"Gia đình chị B","invited_count":"5","guest_source":"GROOM"},
      {"guest_name":"Nguyễn Văn A","phone":"0944444444","email":"c@example.com","side":"COMMON","primary_group_name":"","party_key":"P2","party_display_name":"Bạn A","invited_count":"1","guest_source":"OTHER"}
    ]'::jsonb
  );
  $$,
  'Confirm import: valid payload with warnings must commit atomically.'
);

SELECT is(
  (SELECT count(*)::integer FROM public.guests WHERE wedding_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  5,
  'Import: four imported guests plus one existing guest must exist.'
);

SELECT is(
  (SELECT count(*)::integer FROM public.guests WHERE wedding_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' AND name = 'Nguyễn Văn A' AND invitation_party_id IS NULL),
  1,
  'Blank Party Key: imported guest remains unassigned and no personal Party is synthesized.'
);

SELECT is(
  (SELECT count(*)::integer FROM public.invitation_parties WHERE wedding_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' AND display_name = 'Gia đình chị B'),
  1,
  'Party Key grouping: one new Party is created for shared Party Key P1.'
);

SELECT is(
  (SELECT invited_count FROM public.invitation_parties WHERE wedding_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' AND display_name = 'Gia đình chị B'),
  5,
  'Invited Count: party invited_count remains 5 even though there are two named Guests.'
);

SELECT is(
  (SELECT count(*)::integer FROM public.guests g JOIN public.invitation_parties p ON p.id = g.invitation_party_id WHERE p.display_name = 'Gia đình chị B'),
  2,
  'Party with unknown companions: no fake Guests are created for invited_count greater than named guest count.'
);

SELECT is(
  (SELECT count(*)::integer FROM public.primary_groups WHERE wedding_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' AND name = 'Bạn đá bóng'),
  1,
  'PrimaryGroup mapping: missing group is created once within the Wedding.'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM public.guests g
    JOIN public.primary_groups pg ON pg.id = g.primary_group_id
    WHERE pg.name = 'Bạn đá bóng' AND g.name IN ('Trần Thị B', 'Trần Văn C')
  ),
  2,
  'PrimaryGroup mapping: multiple imported Guests reference the same created Group.'
);

SELECT is(
  (
    SELECT (api_v1.confirm_guest_import(
      '90000000-0000-0000-0000-000000000001',
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '[
        {"guest_name":"Nguyễn Văn A","phone":"0912345678","email":"new-a@example.com","side":"COMMON","primary_group_name":"Đại học","party_key":"","party_display_name":"","invited_count":"","guest_source":"BRIDE"},
        {"guest_name":"Trần Thị B","phone":"0922222222","email":"b@example.com","side":"BRIDE_SIDE","primary_group_name":"Bạn đá bóng","party_key":"P1","party_display_name":"Gia đình chị B","invited_count":"5","guest_source":"BRIDE_PARENTS"},
        {"guest_name":"Trần Văn C","phone":"0933333333","email":"c@example.com","side":"GROOM_SIDE","primary_group_name":"Bạn đá bóng","party_key":"P1","party_display_name":"Gia đình chị B","invited_count":"5","guest_source":"GROOM"},
        {"guest_name":"Nguyễn Văn A","phone":"0944444444","email":"c@example.com","side":"COMMON","primary_group_name":"","party_key":"P2","party_display_name":"Bạn A","invited_count":"1","guest_source":"OTHER"}
      ]'::jsonb
    ) -> 'summary' ->> 'warning_count')::integer
  ),
  5,
  'Duplicate warnings: phone, email, and weak name warnings are returned per affected row but do not block import.'
);

SELECT is(
  (
    SELECT (api_v1.confirm_guest_import(
      '90000000-0000-0000-0000-000000000001',
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '[
        {"guest_name":"Nguyễn Văn A","phone":"0912345678","email":"new-a@example.com","side":"COMMON","primary_group_name":"Đại học","party_key":"","party_display_name":"","invited_count":"","guest_source":"BRIDE"},
        {"guest_name":"Trần Thị B","phone":"0922222222","email":"b@example.com","side":"BRIDE_SIDE","primary_group_name":"Bạn đá bóng","party_key":"P1","party_display_name":"Gia đình chị B","invited_count":"5","guest_source":"BRIDE_PARENTS"},
        {"guest_name":"Trần Văn C","phone":"0933333333","email":"c@example.com","side":"GROOM_SIDE","primary_group_name":"Bạn đá bóng","party_key":"P1","party_display_name":"Gia đình chị B","invited_count":"5","guest_source":"GROOM"},
        {"guest_name":"Nguyễn Văn A","phone":"0944444444","email":"c@example.com","side":"COMMON","primary_group_name":"","party_key":"P2","party_display_name":"Bạn A","invited_count":"1","guest_source":"OTHER"}
      ]'::jsonb
    ) ->> 'replayed')::boolean
  ),
  true,
  'Receipt retry: lost-response retry with same request_id and payload returns replayed success.'
);

SELECT is(
  (SELECT count(*)::integer FROM public.guests WHERE wedding_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  5,
  'Receipt retry: retry does not duplicate Guests.'
);

SELECT is(
  (SELECT count(*)::integer FROM public.invitation_parties WHERE wedding_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  3,
  'Receipt retry: retry does not duplicate Parties.'
);

SELECT is(
  (SELECT count(*)::integer FROM public.primary_groups WHERE wedding_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  2,
  'Receipt retry: retry does not duplicate PrimaryGroups.'
);

RESET ROLE;

SELECT is(
  (SELECT count(*)::integer FROM private.trusted_operation_receipts WHERE operation_type = 'TOP-GUE-004' AND request_id = '90000000-0000-0000-0000-000000000001'),
  1,
  'Receipt: exactly one durable receipt is stored for the logical import.'
);

SELECT is(
  (
    SELECT (result_summary ? 'rows') OR (result_summary::text LIKE '%Nguyễn%') OR (result_summary::text LIKE '%0912345678%')
    FROM private.trusted_operation_receipts
    WHERE operation_type = 'TOP-GUE-004' AND request_id = '90000000-0000-0000-0000-000000000001'
  ),
  false,
  'Receipt minimization: no raw payload, guest names, or phone numbers are stored in result_summary.'
);

SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

-- ===========================================================================
-- 2. Fatal validation and atomicity
-- ===========================================================================

SELECT throws_ok(
  $$
  SELECT api_v1.confirm_guest_import(
    '90000000-0000-0000-0000-000000000002',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '[
      {"guest_name":"Lỗi A","phone":"0955555555","email":"a2@example.com","side":"COMMON","primary_group_name":"Nhóm lỗi","party_key":"PX","party_display_name":"Party X","invited_count":"2","guest_source":"OTHER"},
      {"guest_name":"Lỗi B","phone":"0966666666","email":"b2@example.com","side":"COMMON","primary_group_name":"Nhóm lỗi","party_key":"PX","party_display_name":"Party X","invited_count":"3","guest_source":"OTHER"}
    ]'::jsonb
  );
  $$,
  'P0002',
  'INVALID_IMPORT_ROW: Party Key PX has inconsistent party facts.',
  'Party Key consistency: inconsistent invited_count is rejected.'
);

SELECT is(
  (SELECT count(*)::integer FROM public.guests WHERE name IN ('Lỗi A', 'Lỗi B')),
  0,
  'Atomicity: failed import creates no partial Guests.'
);

SELECT is(
  (SELECT count(*)::integer FROM public.primary_groups WHERE name = 'Nhóm lỗi'),
  0,
  'Atomicity: failed import creates no partial PrimaryGroups.'
);

RESET ROLE;

SELECT is(
  (SELECT count(*)::integer FROM private.trusted_operation_receipts WHERE request_id = '90000000-0000-0000-0000-000000000002'),
  0,
  'Atomicity: failed import creates no receipt.'
);

SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

SELECT throws_ok(
  $$
  SELECT api_v1.confirm_guest_import(
    '90000000-0000-0000-0000-000000000001',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '[{"guest_name":"Different","phone":"","email":"","side":"COMMON","primary_group_name":"","party_key":"","party_display_name":"","invited_count":"","guest_source":"OTHER"}]'::jsonb
  );
  $$,
  '40900',
  'REQUEST_ID_REUSED: request_id has already been used for a different import payload.',
  'REQUEST_ID_REUSED: same request_id with different semantic payload is rejected.'
);

-- ===========================================================================
-- 3. Security and same-Wedding boundaries
-- ===========================================================================

RESET ROLE;
SET ROLE anon;
SET request.jwt.claims = '{}';

SELECT throws_ok(
  $$
  SELECT api_v1.confirm_guest_import(
    '90000000-0000-0000-0000-000000000003',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '[{"guest_name":"Anon","phone":"","email":"","side":"COMMON","primary_group_name":"","party_key":"","party_display_name":"","invited_count":"","guest_source":"OTHER"}]'::jsonb
  );
  $$,
  '42501',
  NULL,
  'Security: anon cannot confirm import.'
);

RESET ROLE;
SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"22222222-2222-2222-2222-222222222222"}';

SELECT throws_ok(
  $$
  SELECT api_v1.confirm_guest_import(
    '90000000-0000-0000-0000-000000000004',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '[{"guest_name":"Outsider","phone":"","email":"","side":"COMMON","primary_group_name":"","party_key":"","party_display_name":"","invited_count":"","guest_source":"OTHER"}]'::jsonb
  );
  $$,
  '42501',
  NULL,
  'Security: outsider cannot confirm import.'
);

SET request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

SELECT throws_ok(
  $$
  SELECT api_v1.confirm_guest_import(
    '90000000-0000-0000-0000-000000000005',
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    '[{"guest_name":"Archived","phone":"","email":"","side":"COMMON","primary_group_name":"","party_key":"","party_display_name":"","invited_count":"","guest_source":"OTHER"}]'::jsonb
  );
  $$,
  '42501',
  NULL,
  'Security: ARCHIVED Wedding rejects import even for an active member.'
);

SELECT lives_ok(
  $$
  SELECT api_v1.confirm_guest_import(
    '90000000-0000-0000-0000-000000000006',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '[{"guest_name":"Same Wedding Group","phone":"","email":"","side":"COMMON","primary_group_name":"Đội bóng","party_key":"","party_display_name":"","invited_count":"","guest_source":"OTHER"}]'::jsonb
  );
  $$,
  'Same-Wedding integrity: same group name in another Wedding does not cross-link or block import.'
);

SELECT is(
  (SELECT wedding_id FROM public.primary_groups WHERE name = 'Đội bóng' AND wedding_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  'Same-Wedding integrity: imported group is created in the target Wedding, not reused cross-tenant.'
);

SELECT throws_ok(
  $$
  INSERT INTO public.guests (wedding_id, name, normalized_phone, normalized_email, side, guest_source)
  VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Bad normalized write', '0999999999', 'bad@example.com', 'COMMON', 'OTHER');
  $$,
  '42501',
  NULL,
  'Security: authenticated client cannot directly write normalized fields.'
);

SELECT throws_ok(
  $$ SELECT * FROM private.trusted_operation_receipts LIMIT 1; $$,
  '42501',
  NULL,
  'Security: authenticated client cannot access trusted operation receipts.'
);

RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
