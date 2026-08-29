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
- Empty-body deployed POSTs now reach WeddingOS and return bounded HTTP 404
  `INVITATION_UNAVAILABLE`, proving the public gateway/proxy route without
  proving a real invitation. `scripts/m8_5b_staging_guest_fixture.mjs` creates
  a synthetic fixture only through approved organizer and Class-B paths, holds
  its raw credential in memory, verifies deployed resolve/RSVP/reload/invalid/
  revoked behavior, and supports canonical delete cleanup with `--cleanup`.
  Its Node tests pass, but execution requires process-only
  `STAGING_SUPABASE_URL`, `STAGING_SUPABASE_ANON_KEY`, and
  `STAGING_ORGANIZER_ACCESS_TOKEN`; none is available on this host.
- An operator later ran the fixture and reached Wedding/Event/InvitationParty
  creation, but direct Guest insert returned PostgREST HTTP 403 / `42501`.
  This is a Batch 04 PostgreSQL privilege regression, not an RLS failure:
  table-level Guest writes were removed by the attempted normalization-column
  revoke. Batch 19 restores only the actual client payload columns
  (`wedding_id`, party/group IDs, `name`, `phone`, `email`, `side`, and
  `guest_source`), keeps normalized/timestamp fields protected, and retains no
  authenticated DELETE. It also omits Flutter's empty create `id` from request
  bodies. Batch 19 was deployed before the now-passing Guest E2E; do not grant
  table-wide privilege or manually delete the retained recovery fixture.
- Batch 19 was deployed and the credential-backed synthetic Guest E2E passed:
  deployed resolve, RSVP, current-state reload, invalid credential denial,
  regenerated credential denial, and revoked credential denial all completed
  through the approved paths. No raw credential is recorded.
- The retained full Guest/Invitation/RSVP recovery fixture previously reached
  `DELETING` with zero authoritative-prefix Storage objects and two canonical
  HTTP 503 `DELETE_RETRY_REQUIRED` responses. Local reproduction identified
  `event_responses_wedding_event_id_fkey` as the exact root-delete blocker.
  Batch 20's service-only transactional dependency purge and the updated
  `wedding-delete` Edge Function were deployed to staging. After an organizer
  session refresh, retrying the exact canonical endpoint returned HTTP 200
  `DELETED`; an organizer PostgREST query returned zero Wedding rows. No direct
  SQL cleanup or manual state repair was used. Full-graph deletion and recovery
  retry semantics are **PASS**, while normal RESTRICT business semantics remain.
- Batch 20 verification is green locally: reset applied the migration and
  pgTAP passed 18 files / 578 assertions; full Edge regression passed 5 files /
  34 tests; and the real local PostgREST lifecycle/Storage matrix passed. Run
  that matrix using `pwsh`, not Windows PowerShell 5.1.
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

- DB: latest migration `00000000000020_batch_20.sql`; 18 files / 578 pgTAP
  assertions / 0 failures.
- Edge: 5 files / 34 Deno tests / 0 failures.
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

- deployed `CF-Connecting-IP` anti-spoof provenance checks;
- deployed Guest Web useful-content evidence under the approved 4G profile;
- Android SDK and reference device/emulator;
- Google OAuth staging client, redirect/domain, Supabase provider, and signing
  fingerprint configuration;
- provider backup/PITR controls and isolated restore environment;
- a deployed rollback environment with a prior known-good release; and
- final release-readiness/CI evidence.

## Google Sign-In staging gate

**EXTERNALLY BLOCKED.** Native Android/iOS Organizer sign-in is Google
`authenticate()` followed by Supabase `signInWithIdToken`; web uses Supabase
OAuth PKCE. The Android application ID is
`com.vibecode.weddingos.organizer_app`; no native browser callback/deep-link is
configured. Supabase `user.id`, not Google profile data, remains the security
identity. Auth-state changes and sign-out clear selected Wedding state and use
bounded `AUTH_LOST` recovery.

This host lacks an Android SDK/device/emulator, staging Google OAuth client and
Supabase provider dashboard evidence, and an operator-owned Google account
session. To resume, configure the staging Android OAuth client with the actual
staging SHA-1/SHA-256 signing fingerprints, enable the matching staging
Supabase Google provider/callback configuration, install a public-configured
staging build on a Google Play-services-capable device, then prove sign-in,
Supabase session, an authenticated Wedding-selector read, resume/revalidation,
and sign-out denial. Record no OAuth secrets, tokens, callback payloads, or
account identifiers. Local Flutter evidence: 59 passing tests; analyzer 0
errors / 0 warnings / 212 existing INFO diagnostics.

`npx supabase projects list` was attempted and failed with no access token.
No relevant deployment environment-variable names were present, and `wrangler`,
`gh`, `adb`, and `emulator` were unavailable. No credential values were read or
recorded.

## Operator inputs and continuation

1. Verify deployed `CF-Connecting-IP` anti-spoof provenance through the Pages
   to Supabase path, without recording client IPs.
2. Preserve the already-passing synthetic Guest evidence and run any remaining
   organizer/archive/cover smoke only on disposable synthetic data.
3. Configure and verify Android Google Sign-In, then measure the 500-task and
   300-guest fixtures on the agreed reference device/emulator.
4. Measure the deployed Guest Web resolve path under the approved 4G profile.
5. Verify the actual provider backup/PITR tier, run an isolated restore drill,
   record RPO <= 24 h/RTO <= 4 h evidence, and run a deployment rollback drill.
6. Re-run the full release gate, update the implementation log and project
   state, then create the authoritative `m8-security-nfr-hardening-checkpoint`.

## Security and stop boundary

Never commit service-role values, JWTs, OAuth secrets, signing keys, signed
URLs, real PII, provider logs, build output, or backups. Permanent Wedding
deletion remains irreversible to the user. Do not start another milestone or
mark M8 complete until the staging, device, and recovery gates have real proof.
