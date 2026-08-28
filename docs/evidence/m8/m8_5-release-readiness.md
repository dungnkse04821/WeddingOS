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
