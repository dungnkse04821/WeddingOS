# WeddingOS MVP Release Runbook

## Scope and prerequisites

This runbook releases the delivered practical M8 scope. It does not begin the
later original-plan release-candidate/smoke milestone. Run the CI workflow and
the local commands below from a clean checkout before promoting any build.

Required operator access is held outside this repository:

- an isolated Supabase staging project and its Auth, Storage, and Edge settings;
- a Cloudflare Pages staging project whose root directory is `guest_web`;
- a signed Android release key and Google OAuth staging client; and
- the provider backup/restore and deployment rollback controls.

No client configuration may contain `SUPABASE_SERVICE_ROLE_KEY`.

## Deterministic release gates

```powershell
npx supabase db reset
npx supabase test db
deno test --allow-env --allow-net --allow-read supabase/functions/_shared/edge_safety_test.ts supabase/functions/_shared/operational_log_test.ts supabase/functions/invitation-resolve/index_test.ts supabase/functions/invitation-rsvp/index_test.ts supabase/functions/wedding-delete/index_test.ts
./supabase/tests/m8_3_tracked_secret_scan.ps1
Set-Location organizer_app; flutter test; flutter analyze
Set-Location ../guest_web; npm ci; npm test; npm run lint; npm run build
```

GitHub Actions in `.github/workflows/ci.yml` runs these deterministic gates on
every pull request and push to `main`. It uses local Supabase only and never
requires production credentials.

## Public configuration and routing

Flutter is built with public, publishable values only:

```powershell
flutter build appbundle `
  --dart-define=SUPABASE_URL=https://<staging-project>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<publishable-anon-key> `
  --dart-define=GOOGLE_WEB_CLIENT_ID=<google-web-client-id>
```

Guest Web is deployed from the `guest_web` directory. The Pages Functions in
`functions/v1/invitation/` implement fixed same-origin routes:

- `POST /v1/invitation/resolve` -> `https://<staging-project>.supabase.co/functions/v1/invitation-resolve`
- `POST /v1/invitation/rsvp` -> `https://<staging-project>.supabase.co/functions/v1/invitation-rsvp`

Set these Pages runtime variables through the deployment provider, not source:

- `SUPABASE_FUNCTIONS_ORIGIN=https://<staging-project>.supabase.co`
- `SUPABASE_ANON_KEY=<publishable-anon-key>`

The proxy rejects invalid upstream configuration, accepts only POST/OPTIONS,
and does not forward `X-Forwarded-For` or `X-Real-IP`. Cloudflare supplies
`CF-Connecting-IP`; the staging proof must show it cannot be replaced by a
client-supplied value before Edge uses it for rate-limit partitioning.

`guest_web/public/_headers` is copied to the Pages build output. It supplies
the CSP, `nosniff`, referrer, permissions, frame, and cache controls. The
staging deployment must be checked with `curl -I https://<staging-guest-host>/`.

## Deployment order and smoke

1. Run CI and confirm a clean, reviewed commit.
2. Configure the PostgREST exposed schemas as `public`, `api_v1`, and
   `edge_api` only; do not expose `internal` or `security`. Apply the approved
   migrations to the isolated target with the operator's Supabase deployment
   workflow; deploy the three Edge functions. Batch 19 is required for direct
   organizer Guest insert/update: it grants only the documented client columns
   and retains normalization/timestamp protection.
3. Configure Edge `GUEST_WEB_ALLOWED_ORIGINS` to the exact staging Pages
   origin. Set service credentials only in Edge provider configuration.
4. Deploy Guest Web from `guest_web`, with output `dist`, Pages Functions
   enabled, and the two public runtime variables above.
5. Build the organizer app with the three Flutter defines and the staging Android
   signing/OAuth configuration.
6. Use synthetic fixtures only: organizer, Wedding, Event, Guest/Party,
   invitation credential, basic Finance row, and optional cover.
7. Verify organizer login, Wedding creation/selection, task/guest/Finance
   write-read, cover upload-read, archive, and disposable-Wedding delete.
8. Verify deployed Guest resolve, RSVP, reload, cover fallback, credential
   revocation/expiration, VietQR gating, CORS/preflight, and header set.

## Google Sign-In readiness

Before an Android staging smoke, create a staging OAuth client for application
ID `com.vibecode.weddingos.organizer_app`, register the staging SHA-1/SHA-256
signing fingerprints, set the authorized Supabase redirect/domain, and enable
the matching Google provider in the isolated Supabase project. Release signing
must replace the current debug release signing configuration. Do not place an
OAuth client secret, keystore, or fingerprint in this repository.

The implemented Android flow initializes `google_sign_in` with the public Web
OAuth client ID as `serverClientId`, then exchanges its native ID token with
Supabase `signInWithIdToken`; it does not use an Android browser callback/deep
link. `google_sign_in` 7.2.0 exposes only the ID token from this authentication
flow, so the optional Supabase access-token parameter is intentionally omitted.
After installing a build with all three public defines, verify on a Google
Play-services-capable device: signed-out launch, Google login, Supabase session,
authenticated Wedding-selector read, background/resume revalidation, sign-out,
and loss of authenticated access. Record only device/build identity and
pass/fail outcomes. Never capture OAuth secrets, access/refresh/ID tokens, raw
callback data, or account identifiers.

## Rollback and recovery

- Guest Web: retain the last known-good Pages deployment and use the provider's
  rollback control; then rerun resolve/RSVP/header smoke.
- Edge: redeploy the previous tagged function source; verify Class-D and
  organizer delete retry paths.
- Flutter: stop promotion and reissue the prior signed artifact. Public config
  is per build and cannot be changed inside an installed artifact.
- Database: use forward fixes for normal migration issues. For a system-level
  incident use provider backup/PITR only in an isolated recovery target before
  a controlled cutover. Do not promise a down migration.

The MVP target is RPO <= 24 hours and RTO <= 4 hours only when the chosen
provider tier documents and the operator verifies that backup/PITR capability.
Permanent Wedding deletion remains irreversible to the user and is not an
individual-data restore mechanism.

## Incident first steps

Authentication, Postgres, Storage, and Edge failures fail closed and surface
bounded retry states. Capture only correlation IDs and redacted platform event
categories. Do not collect bearer tokens, invitation credentials, signed URLs,
guest PII, service keys, or raw provider payloads in tickets or logs.
