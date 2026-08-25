# M6 Storage & Media Foundation

## Implementation

Batch 12 creates the private `wedding_media` bucket with a 5 MiB limit and `image/webp` as its only accepted MIME type. The sole organizer slot is `weddings/{wedding_id}/cover.webp`; policies validate its exact folder hierarchy and filename.

Active same-Wedding owners and collaborators can read, insert, and update the slot. Archived memberships retain read access but cannot mutate. There is deliberately no organizer DELETE policy. M6 does not implement archive, deletion, gallery, video, general media, or R2.

The Flutter service accepts decoded JPEG, PNG, and WebP sources, rejects SVG/unsupported bytes, normalizes to WebP, enforces the final 5 MiB limit, and uploads with `FileOptions(contentType: 'image/webp', upsert: true)`. The Organizer cover screen exposes upload/change only and reloads after ambiguous network outcomes.

D-INV-001 adds nullable `cover_photo_signed_url`; the Edge creates a 1,800-second private signed URL only after existing invitation checks. A missing cover becomes JSON null, fixing an M6 wrapper defect where `jsonb_set` would otherwise return SQL NULL. Guest Web renders the image with a graceful failure fallback.

## Provider Evidence

Using the local Storage HTTP object API with temporary authenticated fixture users: active owner initial upload, owner upsert, and collaborator upsert each returned HTTP 200. Cross-Wedding and archived writes returned HTTP 400. Upsert succeeded with no organizer DELETE policy. No credentials, JWTs, signed URLs, or real media were retained.

## Verification

Clean reset and database suite: 12 files, 417 assertions, PASS. Flutter: 21 tests PASS; analyzer has 0 errors, 0 warnings, 204 existing info diagnostics. Guest Web: 9 tests PASS, lint PASS, build PASS (670 ms, 64.16 kB gzip JS).

## Security Audit

Bucket remains private; exact paths, active membership, lifecycle mutation restrictions, cross-Wedding isolation, anon denial, and organizer DELETE denial are enforced. Service role remains Edge-only; no public route or `api_v1` surface was added, and VietQR is unchanged.
