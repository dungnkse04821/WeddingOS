# M8.5 Release Readiness Evidence

Date: 2026-08-29

## Source-controlled readiness

- `.github/workflows/ci.yml` defines deterministic GitHub Actions jobs for
  local Supabase reset/pgTAP, Deno Edge tests, Flutter test/analyze, Guest Web
  test/lint/build, and the tracked-secret scan. It pins Deno 2.9.5, Flutter
  3.47.1, Node 24.17.0, and Supabase CLI 2.116.0.
- `guest_web/functions/v1/invitation/resolve.ts` and `rsvp.ts` make the
  existing same-origin `/v1/invitation/*` contract deployable through
  Cloudflare Pages Functions. They target fixed Supabase function paths, strip
  `X-Forwarded-For` and `X-Real-IP`, and propagate only provider-injected
  `CF-Connecting-IP`.
- `docs/release/mvp-release-runbook.md` documents public configuration,
  deployment order, staging fixture constraints, smoke checks, rollback, and
  the RPO/RTO target. It contains no credential values.

## Local release evidence

| Gate | Result |
| --- | --- |
| Clean database reset | PASS through `00000000000018_batch_18.sql` |
| pgTAP | PASS: 16 files, 538 assertions, 0 failures |
| Deno 2.9.5 | PASS: 5 files, 33 tests, 0 failures |
| Flutter | PASS: 57 tests, 0 failures; analyzer 0 errors, 0 warnings, 212 existing INFOs |
| Guest Web | PASS: 5 files, 18 tests, 0 failures; ESLint PASS; build 758 ms, 203.23 kB JS / 64.36 kB gzip |
| Tracked-secret scan | PASS: 5 categories, 0 tracked environment files |
| Production npm audit | PASS: 0 vulnerabilities (`--omit=dev --audit-level=high`) |
| Real PostgREST lifecycle/Storage matrix | PASS: ARCHIVED read-only, DELETING recovery-only, cross-Wedding and anon denied; no effective organizer delete authority |
| Real PostgREST map-link matrix | PASS: HTTPS accepted, unsafe schemes rejected, public resolve retained valid link |
| Real Class-D/Storage smoke | PASS: resolve 62 ms, RSVP 60 ms, delete 214 ms; actual Storage pages 100 + 1, fresh list empty, Auth user preserved |

## Environment evidence attempt

The local host has no staging deployment authority or runtime:

- `npx supabase projects list` returned `LegacyPlatformAuthRequiredError`:
  no Supabase access token is configured.
- No relevant environment variable names for Supabase, Cloudflare, staging,
  Google, or Android deployment were present. Values were not inspected.
- `wrangler`, `gh`, `adb`, and `emulator` are unavailable; no Android SDK/device
  is installed. Only local ADB key files exist.
- The repository contains no Cloudflare project binding, staging URL, provider
  backup tier/configuration, Google OAuth staging metadata, or release signing
  key. No deployment endpoint can therefore be queried for CSP headers,
  proxy/header provenance, CORS, E2E behavior, staging 4G performance, or a
  rollback/restore drill.

## Release-blocking external gates

`M8-P1-006` is **OPEN / BLOCKED** until an operator provides an isolated
staging Supabase project, Cloudflare Pages project/domain, and time-bounded
access to deploy synthetic fixtures. The operator must then execute the
runbook's deployed checks, including a spoofed forwarding-header test that
proves Cloudflare owns `CF-Connecting-IP` at Pages and Edge.

The following evidence is also unavailable and cannot be fabricated:

- Android reference-device/emulator 500-task and 300-guest measurements;
- staging Guest Web useful-content measurement under the approved 4G profile;
- Google Sign-In end-to-end setup (OAuth client, signing fingerprints, Supabase
  provider, authorized domain/redirect); and
- provider-tier backup/PITR capability, isolated restore drill, measured
  RPO <= 24 hours/RTO <= 4 hours, and deployed rollback drill.

These are environmental release gates, not local code defects. M8 must remain
in progress and must not be committed as complete until the evidence exists.

## Cloudflare Pages import correction

A real staging deployment proved Vite production build and Pages Functions
discovery, then failed Pages Functions compilation because the entrypoints used
`../../../_shared/invitation_proxy`. The helper is actually located at
`guest_web/functions/_shared/invitation_proxy.ts`, so the entrypoints under
`guest_web/functions/v1/invitation/` now import it through
`../../_shared/invitation_proxy`. This is a source-controlled import-resolution
fix only. Deployment CSP, routing, CORS, and forwarding-header provenance
remain **IN PROGRESS** until Cloudflare redeploys and verifies the pushed fix.

## Class-D gateway JWT correction

Cloudflare Pages now deploys successfully after the import correction. Guest
Web, deployed CSP/security headers, approved-origin CORS, invalid-origin
fail-closed behavior, and proxy routing to Supabase Edge are verified by the
staging attempt. The two Class-D POSTs instead received gateway HTTP 401
`UNAUTHORIZED_NO_AUTH_HEADER`, with `x-served-by: supabase-edge-runtime`, before
WeddingOS handlers ran.

`supabase/config.toml` had no function-specific configuration. It now sets
`[functions.invitation-resolve]` and `[functions.invitation-rsvp]` to
`verify_jwt = false`, matching their invitation-credential capability model.
`[functions.wedding-delete] verify_jwt = true` explicitly preserves organizer
gateway authentication. `m8_5b_function_config_verification.py` parses TOML
with Python's standard library and asserts these three modes; CI runs it.

Supabase `functions deploy` honors per-function `config.toml` configuration;
`--no-verify-jwt` overrides it and must never be applied to `wedding-delete`.
The public functions must be redeployed and their real staging POSTs retried.
Class-D deployed E2E remains **IN PROGRESS**, not PASS.

## Synthetic Guest E2E fixture preparation

The deployed Class-D gateway/routing boundary is now verified: staging
`POST /v1/invitation/resolve` and `POST /v1/invitation/rsvp` with `{}` each
return bounded HTTP 404 `INVITATION_UNAVAILABLE`. This proves the Cloudflare
proxy, public Supabase gateway mode, WeddingOS handler entry, and CORS boundary
without claiming a credential-backed Guest E2E pass.

`scripts/m8_5b_staging_guest_fixture.mjs` prepares the approved synthetic path:
`api_v1.create_wedding`, Class-B Event/Party/Guest/Invitation/targeting writes,
the `DRAFT -> READY` transition, and
`api_v1.regenerate_invitation_credential`. It keeps the generated credential
only in memory, executes deployed resolve/RSVP/reload/invalid/revoked checks,
and optionally invokes the canonical organizer `wedding-delete` route with
`--cleanup`. It creates only the synthetic labels `WeddingOS Staging Test`,
`Lễ cưới thử nghiệm`, `Gia đình Test`, and `Khách Test` without phone/email.

The credential-free Node tests pass. An execution attempt stopped before any
network request because `STAGING_SUPABASE_URL`, `STAGING_SUPABASE_ANON_KEY`, and
`STAGING_ORGANIZER_ACCESS_TOKEN` are absent. An operator must provide those
values through the process environment only, run the helper, preserve the
non-sensitive returned IDs for evidence, and optionally use `--cleanup` after
inspection. Credential-backed resolve, RSVP, reload, invalid, and revoked
staging results remain **BLOCKED**, not PASS.

## Staging Guest INSERT privilege correction

A later operator-run fixture reached `create_wedding`, Event insert, and
InvitationParty insert, then received PostgREST HTTP 403 / SQLSTATE `42501` on
the approved direct Guest insert. This was a PostgreSQL table-privilege failure,
not RLS: Batch 04 granted table-level Guest `INSERT`/`UPDATE`, then its
unqualified normalization-column `REVOKE INSERT, UPDATE` removed those base
privileges. The partial synthetic state is intentionally retained for operator
cleanup through canonical Wedding delete; it is not treated as atomic or E2E
success.

Batch 19 restores only column-level `INSERT`/`UPDATE` for the actual Flutter
Guest payload: `wedding_id`, `invitation_party_id`, `primary_group_id`, `name`,
`phone`, `email`, `side`, and `guest_source`. It preserves protected
`normalized_phone`, `normalized_email`, `created_at`, and `updated_at`, no
authenticated `DELETE`, and existing RLS/lifecycle gates. The Flutter serializer
also now omits `id` from both create and update bodies; update identity remains
the existing URL filter. This prevents its empty create placeholder from being
sent as an invalid UUID.

Staging PostgREST configuration must expose exactly `public`, `api_v1`, and
`edge_api`, as reflected in `supabase/config.toml`; it must not expose
`internal` or `security`. Batch 19 still requires operator deployment and a
fresh fixture run. Credential-backed Guest E2E remains **BLOCKED**, not PASS.

Local verification after Batch 19 is green: clean `supabase db reset` applied
`00000000000019_batch_19.sql`; pgTAP passed 17 files / 552 assertions; the
Flutter suite passed 59 tests with analyzer 0 errors / 0 warnings (212 existing
INFO diagnostics); the fixture Node suite passed 2 tests; and Guest Web passed
6 files / 19 tests, lint, and production build. The real local PostgREST matrix
also passed the ACTIVE/ARCHIVED/DELETING, cross-Wedding, anonymous, and Storage
boundaries. Its environment discovery now tolerates optional local services
being stopped, but still requires returned API values; it is run with `pwsh`,
not Windows PowerShell 5.1. The fixture now reports bounded PostgREST
code/message context without emitting request credentials or tokens.
