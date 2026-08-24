# M4.3 VietQR Gating

M4.3 implements STORY-07-02 without adding Finance, payment reconciliation, dynamic QR, or media upload.

## Configuration and authorization

The existing Wedding fields are used unchanged: `vietqr_enabled`, `vietqr_bank_id`, `vietqr_account_no`, `vietqr_account_name`, and the pre-existing but unused `vietqr_photo_key`. M4.3 does not expose or upload `vietqr_photo_key`; that would require the deferred Media boundary. A database trigger rejects enabled configuration without the three explicitly public bank display facts.

Configuration is a narrow Class-B `public.weddings` update. Existing column grants and `security.can_mutate_wedding` restrict it to active same-Wedding members while the Wedding is `ACTIVE`; `ARCHIVED` and `DELETING` are read-only through RLS.

## Authoritative public gate

`internal.public_vietqr_state` returns bank display fields only when all approved conditions hold:

1. the Wedding is active and VietQR is enabled with valid public facts;
2. the valid Invitation currently targets at least one active Exact-Date Event;
3. `internal.public_rsvp_state` reports `RESPONDED`.

The rule intentionally permits fully completed `NOT_ATTENDING` responses. Expected-Month-only Invitations and `PENDING`/`PARTIAL` states return only `{ "available": false }`. Current RSVP state is recalculated on every resolve and submit, so a newly targeted Exact Event returns the RSVP to `PARTIAL` and hides VietQR again.

The hidden `internal` implementation remains behind the existing service-only `edge_api` bridge. `D-INV-001` includes the gated result in its DTO, and `D-RSV-001` returns the recalculated result after a successful submission. No browser-controlled flag can unlock it; no token, hash, IDs, Finance data, member data, or hidden bank fields are returned while unavailable.

## User experience

Guest Web renders a neutral optional gift section only for `available: true`; it never renders a hidden-state bank detail. The organizer home area opens a simple Wedding-level configuration screen with enable/disable, public bank facts, validation, and safe errors. It deliberately has no QR upload or payment status.

## Verification

`npx supabase db reset` rebuilt all migrations through `00000000000010_batch_10.sql` successfully. `npx supabase test db` passed all 10 database files and 362 assertions. `database_verification_batch_10.test.sql` adds configuration, RLS, bridge, DTO privacy, qualified RSVP, non-attending, disabled, and current-state regression coverage.

Guest Web has 8 tests and passes `npm test`, `npm run lint`, and the canonical `npm run build`; the latest build completed in 650 ms with a 64.09 kB gzip JavaScript bundle. This build timing is not a 4G page-load measurement.

Organizer `flutter test` passes 14 tests. `flutter analyze` reports 0 errors, 0 warnings, and 193 existing info diagnostics. The info-level debt was not changed for this checkpoint.

## Filesystem delivery closure

The final Windows Vite failure was not an application defect. `guest_web/dist` is ignored generated output; its root was owned by `nguye`, while stale `dist/assets` and its files were owned by `CodexSandboxOffline`. The directory was neither read-only nor a symlink/junction. No repository-specific live process was identified, so none was terminated.

An attempted ACL repair was scoped only to `guest_web/dist`, but the elevated identity could not traverse the sandbox-owned children. The normal workspace identity, which owns that generated output boundary, safely removed the ignored directory. Vite then recreated `dist` and `dist/assets` as `nguye`; both now have inherited modify access and explicit full control for `nguye`. The final canonical build passed in 676 ms with the same 64.09 kB gzip JavaScript bundle. No 4G page-load claim is made.
