# M6 Storage & Media Foundation Checkpoint

Status: COMPLETE / READY FOR PO APPROVAL. M6 adds one private WebP cover slot, not a media library. Latest migration: `00000000000012_batch_12.sql`.

Bucket: private `wedding_media`, 5 MiB, `image/webp`. Exact path: `weddings/{wedding_id}/cover.webp`. Active owner/collaborator may read/write own Wedding; archived members may read only; cross-Wedding and anon are denied; no organizer DELETE policy exists.

Local Storage HTTP evidence: authenticated owner initial upload and upsert returned 200; collaborator upsert returned 200; cross-Wedding and archived writes returned 400; archived organizer read returned 200; anonymous direct private read/write returned 400. Upsert required no DELETE policy.

Flutter uses `FileOptions` through `supabase_flutter`, normalizes supported images to WebP, enforces size, and provides upload/change UI. D-INV-001 returns nullable `cover_photo_signed_url` with a 1,800-second TTL after existing security checks. Guest Web renders it with fallback.

Evidence: final DB reset/test PASS (12 files, 417 assertions); Flutter 21 tests PASS, analyzer 0 errors/0 warnings/204 info; Guest Web 9 tests, lint, build PASS (701 ms, 64.16 kB gzip JS).

Not implemented: M7 lifecycle/delete/cleanup, TOP-WED-004, gallery, video, VietQR media migration, R2.

Next task: Product Owner review of M6. Stop boundary: do not start M7.
