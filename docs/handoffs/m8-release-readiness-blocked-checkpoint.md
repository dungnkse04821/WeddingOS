# M8 Release Readiness Blocked Checkpoint

## Status

Practical M8 Security & NFR Hardening is **IN PROGRESS / EXTERNALLY BLOCKED**.
M8.1A, M8.1B, M8.1C, M8.2A, M8.2B, M8.2C, M8.3, and M8.4 are complete. M8.5
source-controlled/local readiness is complete; M8.5 external release evidence
is blocked. Do not mark M8 complete until every external gate below has real
evidence.

This is a temporary handoff, not the authoritative final M8 checkpoint.

## Completed local M8.5 work

- GitHub Actions CI: `.github/workflows/ci.yml` runs local Supabase reset and
  pgTAP, all Deno Edge tests, Flutter test/analyze, Guest Web test/lint/build,
  and the tracked-secret scan. It pins Supabase CLI 2.116.0, Deno 2.9.5,
  Flutter 3.47.1, and Node 24.17.0.
- Cloudflare Pages Functions preserve the existing same-origin routes:
  `guest_web/functions/v1/invitation/resolve.ts` and `rsvp.ts`. The shared
  proxy permits POST/OPTIONS only, uses fixed HTTPS Supabase function targets,
  removes `X-Forwarded-For`/`X-Real-IP`, and relays only `CF-Connecting-IP`.
  It has no service-role key, generic upstream path, token/body logging, or
  client-selected authority.
- A staging compiler error exposed a relative-import defect: the entrypoints
  now use `../../_shared/invitation_proxy` to reach
  `functions/_shared/invitation_proxy.ts`. Local entrypoint tests pass, but
  Cloudflare must redeploy the corresponding commit before compilation can be
  treated as verified.
- Staging then reached the Supabase Edge gateway, which rejected Class-D POSTs
  before handler execution because function JWT mode was not source controlled.
  `supabase/config.toml` now disables gateway JWT verification only for
  `invitation-resolve` and `invitation-rsvp`, and explicitly enables it for
  `wedding-delete`; `m8_5b_function_config_verification.py` parses and checks
  these settings. Redeploy both public functions and retry real POSTs before
  treating Class-D staging E2E as verified.
- `docs/release/mvp-release-runbook.md` documents deployment, public config,
  release/rollback, recovery expectations, and synthetic-only staging smoke.
- `docs/evidence/m8/m8_5-release-readiness.md` records exact local results and
  the external evidence boundary.

## Verified commands and results

```powershell
npx supabase db reset
npx supabase test db
deno test --allow-env --allow-net --allow-read supabase/functions/_shared/edge_safety_test.ts supabase/functions/_shared/operational_log_test.ts supabase/functions/invitation-resolve/index_test.ts supabase/functions/invitation-rsvp/index_test.ts supabase/functions/wedding-delete/index_test.ts
Set-Location organizer_app; flutter test; flutter analyze
Set-Location ../guest_web; npm test; npm run lint; npm run build
../supabase/tests/m8_3_tracked_secret_scan.ps1
npm audit --omit=dev --audit-level=high
```

- DB: latest migration `00000000000018_batch_18.sql`; 16 files / 538 pgTAP
  assertions / 0 failures.
- Edge: 5 files / 33 Deno tests / 0 failures.
- Flutter: 57 tests / 0 failures; analyzer 0 errors / 0 warnings / 212 existing
  INFO diagnostics.
- Guest Web: 5 files / 18 tests / 0 failures; lint pass; build pass at 758 ms
  with 203.23 kB JavaScript / 64.36 kB gzip.
- Tracked-secret scan: pass, five categories, zero tracked environment files.
- `npm audit --omit=dev --audit-level=high`: zero vulnerabilities.
- Real local PostgREST, Class-D, and Storage provider scripts pass. The storage
  fixture proves actual pages of 100 and 1 entries, fresh-empty cleanup, and
  preserved Auth users.

## Missing external capabilities

- Supabase staging access token and isolated project;
- Cloudflare Pages staging project/domain and deployment authority;
- actual deployed Pages-to-Supabase path for CSP/header, CORS/routing, and
  `CF-Connecting-IP` anti-spoof provenance checks;
- Android SDK and reference device/emulator;
- Google OAuth staging client, redirect/domain, Supabase provider, and signing
  fingerprint configuration;
- provider backup/PITR controls and isolated restore environment; and
- a deployed rollback environment with a prior known-good release.

`npx supabase projects list` was attempted and failed with no access token.
No relevant deployment environment-variable names were present, and `wrangler`,
`gh`, `adb`, and `emulator` were unavailable. No credential values were read or
recorded.

## Operator inputs and continuation

1. Provide time-bounded operator access to an isolated staging Supabase project
   and Cloudflare Pages project/domain, never production data or credentials in
   the repository.
2. Configure the Pages runtime variables from the runbook, deploy the current
   source, and verify deployed CSP headers, same-origin routing, CORS, and
   spoofed forwarding-header behavior.
3. Run synthetic organizer and Guest E2E paths, including archive/delete on a
   disposable Wedding, resolve/RSVP/reload/revocation, and cover fallback.
4. Configure and verify Android Google Sign-In, then measure the 500-task and
   300-guest fixtures on the agreed reference device/emulator.
5. Measure the deployed Guest Web resolve path under the approved 4G profile.
6. Verify the actual provider backup/PITR tier, run an isolated restore drill,
   record RPO <= 24 h/RTO <= 4 h evidence, and run a deployment rollback drill.
7. Re-run the full release gate, update the implementation log and project
   state, then create the authoritative `m8-security-nfr-hardening-checkpoint`.

## Security and stop boundary

Never commit service-role values, JWTs, OAuth secrets, signing keys, signed
URLs, real PII, provider logs, build output, or backups. Permanent Wedding
deletion remains irreversible to the user. Do not start another milestone or
mark M8 complete until the staging, device, and recovery gates have real proof.
