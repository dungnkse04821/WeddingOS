BEGIN;
SELECT plan(24);

-- M6 fixture: two tenants and both authorized organizer roles.
INSERT INTO auth.users (id, email) VALUES
  ('6a000000-0000-0000-0000-000000000001', 'm6-owner@example.com'),
  ('6a000000-0000-0000-0000-000000000002', 'm6-collaborator@example.com'),
  ('6a000000-0000-0000-0000-000000000003', 'm6-outsider@example.com')
ON CONFLICT DO NOTHING;
INSERT INTO public.weddings (id, name, cultural_context, exact_date) VALUES
  ('6b000000-0000-0000-0000-000000000001', 'M6 Active', 'TUY_CHON', '2026-12-12'),
  ('6b000000-0000-0000-0000-000000000002', 'M6 Archived', 'TUY_CHON', '2026-12-13'),
  ('6b000000-0000-0000-0000-000000000003', 'M6 Other', 'TUY_CHON', '2026-12-14')
ON CONFLICT DO NOTHING;
UPDATE public.weddings SET status = 'ARCHIVED' WHERE id = '6b000000-0000-0000-0000-000000000002';
INSERT INTO public.wedding_members (wedding_id, user_id, display_name, profile_email, role, status) VALUES
  ('6b000000-0000-0000-0000-000000000001', '6a000000-0000-0000-0000-000000000001', 'M6 Owner', 'm6-owner@example.com', 'OWNER', 'ACTIVE'),
  ('6b000000-0000-0000-0000-000000000001', '6a000000-0000-0000-0000-000000000002', 'M6 Collaborator', 'm6-collaborator@example.com', 'COLLABORATOR', 'ACTIVE'),
  ('6b000000-0000-0000-0000-000000000002', '6a000000-0000-0000-0000-000000000001', 'M6 Owner', 'm6-owner@example.com', 'OWNER', 'ACTIVE'),
  ('6b000000-0000-0000-0000-000000000002', '6a000000-0000-0000-0000-000000000002', 'M6 Collaborator', 'm6-collaborator@example.com', 'COLLABORATOR', 'ACTIVE')
ON CONFLICT DO NOTHING;

SELECT is((SELECT public FROM storage.buckets WHERE id = 'wedding_media'), false, 'M6 bucket is private.');
SELECT is((SELECT file_size_limit FROM storage.buckets WHERE id = 'wedding_media'), 5242880::bigint, 'M6 bucket enforces the 5 MiB final upload limit.');
SELECT is((SELECT allowed_mime_types::text FROM storage.buckets WHERE id = 'wedding_media'), '{image/webp}', 'M6 bucket accepts only image/webp.');

SELECT ok(security.is_wedding_cover_path('weddings/6b000000-0000-0000-0000-000000000001/cover.webp'), 'Exact deterministic cover slot is valid.');
SELECT ok(NOT security.is_wedding_cover_path('weddings/6b000000-0000-0000-0000-000000000001/other.webp'), 'Wrong basename is rejected.');
SELECT ok(NOT security.is_wedding_cover_path('weddings/6b000000-0000-0000-0000-000000000001/cover.png'), 'Wrong extension is rejected.');
SELECT ok(NOT security.is_wedding_cover_path('weddings/6b000000-0000-0000-0000-000000000001/extra/cover.webp'), 'Extra path nesting is rejected.');
SELECT ok(NOT security.is_wedding_cover_path('weddings/not-a-uuid/cover.webp'), 'Invalid Wedding folder is rejected.');

SELECT ok(EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'm6 members read wedding cover'), 'Read policy exists.');
SELECT ok(EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'm6 members insert wedding cover'), 'Insert policy exists.');
SELECT ok(EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'm6 members update wedding cover'), 'Update policy exists.');
SELECT ok(NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND cmd = 'DELETE' AND policyname LIKE 'm6 %'), 'M6 deliberately grants no organizer delete policy.');

SELECT set_config('request.jwt.claims', '{"sub":"6a000000-0000-0000-0000-000000000001"}', true);
SET ROLE authenticated;
SELECT lives_ok(
  $$INSERT INTO storage.objects (bucket_id, name, owner, metadata) VALUES ('wedding_media', 'weddings/6b000000-0000-0000-0000-000000000001/cover.webp', auth.uid(), '{}'::jsonb)$$,
  'Active Owner can upload the exact own-Wedding cover slot.'
);
RESET ROLE;

SELECT set_config('request.jwt.claims', '{"sub":"6a000000-0000-0000-0000-000000000002"}', true);
SET ROLE authenticated;
SELECT results_eq(
  $$SELECT name FROM storage.objects WHERE bucket_id = 'wedding_media' AND name = 'weddings/6b000000-0000-0000-0000-000000000001/cover.webp'$$,
  ARRAY['weddings/6b000000-0000-0000-0000-000000000001/cover.webp'::text],
  'Active Collaborator can read the own-Wedding cover.'
);
SELECT lives_ok(
  $$UPDATE storage.objects SET metadata = '{"m6":"replacement"}'::jsonb WHERE bucket_id = 'wedding_media' AND name = 'weddings/6b000000-0000-0000-0000-000000000001/cover.webp'$$,
  'Active Collaborator can replace the own-Wedding cover without DELETE.'
);
RESET ROLE;

INSERT INTO storage.objects (bucket_id, name, owner, metadata)
VALUES ('wedding_media', 'weddings/6b000000-0000-0000-0000-000000000002/cover.webp', '6a000000-0000-0000-0000-000000000001', '{}'::jsonb);

SELECT set_config('request.jwt.claims', '{"sub":"6a000000-0000-0000-0000-000000000001"}', true);
SET ROLE authenticated;
SELECT results_eq(
  $$SELECT name FROM storage.objects WHERE bucket_id = 'wedding_media' AND name = 'weddings/6b000000-0000-0000-0000-000000000002/cover.webp'$$,
  ARRAY['weddings/6b000000-0000-0000-0000-000000000002/cover.webp'::text],
  'Archived Owner can still read an existing cover.'
);
SELECT throws_ok(
  $$INSERT INTO storage.objects (bucket_id, name, owner, metadata) VALUES ('wedding_media', 'weddings/6b000000-0000-0000-0000-000000000002/cover.webp', auth.uid(), '{}'::jsonb)$$,
  '42501', NULL, 'Archived Owner cannot upload a cover.'
);
SELECT lives_ok(
  $$UPDATE storage.objects SET metadata = '{"m6":"blocked"}'::jsonb WHERE bucket_id = 'wedding_media' AND name = 'weddings/6b000000-0000-0000-0000-000000000002/cover.webp'$$,
  'Archived Owner cannot replace a cover because RLS exposes no mutable row.'
);
SELECT is(
  (SELECT metadata ->> 'm6' FROM storage.objects WHERE bucket_id = 'wedding_media' AND name = 'weddings/6b000000-0000-0000-0000-000000000002/cover.webp'),
  NULL,
  'Archived replace leaves the stored cover unchanged.'
);
SELECT throws_ok(
  $$DELETE FROM storage.objects WHERE bucket_id = 'wedding_media' AND name = 'weddings/6b000000-0000-0000-0000-000000000001/cover.webp'$$,
  '42501', NULL, 'Organizer DELETE is denied.'
);
RESET ROLE;

SELECT set_config('request.jwt.claims', '{"sub":"6a000000-0000-0000-0000-000000000003"}', true);
SET ROLE authenticated;
SELECT is_empty(
  $$SELECT name FROM storage.objects WHERE bucket_id = 'wedding_media'$$,
  'Cross-Wedding outsider cannot read any M6 object.'
);
SELECT throws_ok(
  $$INSERT INTO storage.objects (bucket_id, name, owner, metadata) VALUES ('wedding_media', 'weddings/6b000000-0000-0000-0000-000000000001/cover.webp', auth.uid(), '{}'::jsonb)$$,
  '42501', NULL, 'Cross-Wedding outsider cannot upload.'
);
RESET ROLE;

SET ROLE anon;
SELECT is_empty($$SELECT * FROM storage.objects WHERE bucket_id = 'wedding_media'$$, 'Anon cannot directly read private objects.');
SELECT throws_ok($$INSERT INTO storage.objects (bucket_id, name) VALUES ('wedding_media', 'weddings/6b000000-0000-0000-0000-000000000001/cover.webp')$$, '42501', NULL, 'Anon cannot upload.');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
