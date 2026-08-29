BEGIN;
SELECT plan(14);

INSERT INTO auth.users (id, email) VALUES
  ('19000000-0000-0000-0000-000000000001', 'm85b-guest-owner@test.local'),
  ('19000000-0000-0000-0000-000000000002', 'm85b-guest-outsider@test.local')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.weddings (id, name, cultural_context, exact_date, status)
VALUES
  ('19010000-0000-0000-0000-000000000001', 'M85B Active', 'TUY_CHON', '2027-10-01', 'ACTIVE'),
  ('19010000-0000-0000-0000-000000000002', 'M85B Archived', 'TUY_CHON', '2027-10-02', 'ARCHIVED'),
  ('19010000-0000-0000-0000-000000000003', 'M85B Deleting', 'TUY_CHON', '2027-10-03', 'DELETING'),
  ('19010000-0000-0000-0000-000000000004', 'M85B Outsider', 'TUY_CHON', '2027-10-04', 'ACTIVE');

INSERT INTO public.wedding_members (id, wedding_id, user_id, display_name, profile_email, role, status)
VALUES
  ('19020000-0000-0000-0000-000000000001', '19010000-0000-0000-0000-000000000001', '19000000-0000-0000-0000-000000000001', 'Guest Owner', 'm85b-guest-owner@test.local', 'OWNER', 'ACTIVE'),
  ('19020000-0000-0000-0000-000000000002', '19010000-0000-0000-0000-000000000002', '19000000-0000-0000-0000-000000000001', 'Guest Owner', 'm85b-guest-owner@test.local', 'OWNER', 'ACTIVE'),
  ('19020000-0000-0000-0000-000000000003', '19010000-0000-0000-0000-000000000003', '19000000-0000-0000-0000-000000000001', 'Guest Owner', 'm85b-guest-owner@test.local', 'OWNER', 'ACTIVE'),
  ('19020000-0000-0000-0000-000000000004', '19010000-0000-0000-0000-000000000004', '19000000-0000-0000-0000-000000000002', 'Guest Outsider', 'm85b-guest-outsider@test.local', 'OWNER', 'ACTIVE');

SELECT ok(
  has_column_privilege('authenticated', 'public.guests', 'wedding_id', 'INSERT')
  AND has_column_privilege('authenticated', 'public.guests', 'invitation_party_id', 'INSERT')
  AND has_column_privilege('authenticated', 'public.guests', 'primary_group_id', 'INSERT')
  AND has_column_privilege('authenticated', 'public.guests', 'name', 'INSERT')
  AND has_column_privilege('authenticated', 'public.guests', 'phone', 'INSERT')
  AND has_column_privilege('authenticated', 'public.guests', 'email', 'INSERT')
  AND has_column_privilege('authenticated', 'public.guests', 'side', 'INSERT')
  AND has_column_privilege('authenticated', 'public.guests', 'guest_source', 'INSERT'),
  'Guest INSERT is granted only to the approved client payload columns.'
);
SELECT ok(
  has_column_privilege('authenticated', 'public.guests', 'wedding_id', 'UPDATE')
  AND has_column_privilege('authenticated', 'public.guests', 'invitation_party_id', 'UPDATE')
  AND has_column_privilege('authenticated', 'public.guests', 'primary_group_id', 'UPDATE')
  AND has_column_privilege('authenticated', 'public.guests', 'name', 'UPDATE')
  AND has_column_privilege('authenticated', 'public.guests', 'phone', 'UPDATE')
  AND has_column_privilege('authenticated', 'public.guests', 'email', 'UPDATE')
  AND has_column_privilege('authenticated', 'public.guests', 'side', 'UPDATE')
  AND has_column_privilege('authenticated', 'public.guests', 'guest_source', 'UPDATE'),
  'Guest UPDATE is granted only to the approved client payload columns.'
);
SELECT is(has_table_privilege('authenticated', 'public.guests', 'INSERT'), false, 'Guest INSERT has no broad table-level grant.');
SELECT ok(
  NOT has_column_privilege('authenticated', 'public.guests', 'normalized_phone', 'INSERT')
  AND NOT has_column_privilege('authenticated', 'public.guests', 'normalized_email', 'INSERT'),
  'Normalized columns cannot be inserted by authenticated clients.'
);
SELECT ok(
  NOT has_column_privilege('authenticated', 'public.guests', 'normalized_phone', 'UPDATE')
  AND NOT has_column_privilege('authenticated', 'public.guests', 'normalized_email', 'UPDATE'),
  'Normalized columns cannot be updated by authenticated clients.'
);
SELECT is(has_table_privilege('authenticated', 'public.guests', 'DELETE'), false, 'Guest DELETE remains unavailable to authenticated clients.');

SELECT set_config('request.jwt.claims', '{"sub":"19000000-0000-0000-0000-000000000001"}', true);
SET ROLE authenticated;

SELECT lives_ok(
  $$INSERT INTO public.guests (wedding_id, name, phone, email, side, guest_source)
    VALUES ('19010000-0000-0000-0000-000000000001', 'Allowed Guest', '+84 912 345 678', ' Allowed@Example.COM ', 'COMMON', 'OTHER')$$,
  'An active same-Wedding member can create an ordinary Guest through the explicit column grant.'
);
SELECT is(
  (SELECT normalized_phone || '|' || normalized_email FROM public.guests WHERE wedding_id = '19010000-0000-0000-0000-000000000001' AND name = 'Allowed Guest'),
  '0912345678|allowed@example.com',
  'Normalization trigger still derives protected values from allowed phone and email input.'
);
SELECT lives_ok(
  $$UPDATE public.guests SET name = 'Updated Guest' WHERE wedding_id = '19010000-0000-0000-0000-000000000001' AND name = 'Allowed Guest'$$,
  'An active same-Wedding member can update an allowed Guest field.'
);
SELECT throws_ok(
  $$INSERT INTO public.guests (wedding_id, name, normalized_phone)
    VALUES ('19010000-0000-0000-0000-000000000001', 'Blocked Normalized Insert', '0912345678')$$,
  '42501', NULL, 'Authenticated client cannot directly insert normalized_phone.'
);
SELECT throws_ok(
  $$UPDATE public.guests SET normalized_email = 'blocked@example.com'
    WHERE wedding_id = '19010000-0000-0000-0000-000000000001' AND name = 'Updated Guest'$$,
  '42501', NULL, 'Authenticated client cannot directly update normalized_email.'
);
SELECT throws_ok(
  $$INSERT INTO public.guests (wedding_id, name)
    VALUES ('19010000-0000-0000-0000-000000000002', 'Archived Guest')$$,
  '42501', NULL, 'ARCHIVED Wedding guest insert remains denied by lifecycle RLS.'
);
SELECT throws_ok(
  $$INSERT INTO public.guests (wedding_id, name)
    VALUES ('19010000-0000-0000-0000-000000000003', 'Deleting Guest')$$,
  '42501', NULL, 'DELETING Wedding guest insert remains denied by lifecycle RLS.'
);

RESET ROLE;
SELECT set_config('request.jwt.claims', '{"sub":"19000000-0000-0000-0000-000000000002"}', true);
SET ROLE authenticated;
SELECT throws_ok(
  $$INSERT INTO public.guests (wedding_id, name)
    VALUES ('19010000-0000-0000-0000-000000000001', 'Outsider Guest')$$,
  '42501', NULL, 'Outsider Guest insert remains denied by RLS.'
);

RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
