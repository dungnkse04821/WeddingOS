# WeddingOS M8 Security and NFR Hardening

Status:

- M8 overall: **IN PROGRESS**
- M8.1A Finance Contract Correctness: **COMPLETE**
- M8.1B Wedding Concurrency + DELETING Read Matrix: **COMPLETE**
- M8.1C Map Validation + Function Hygiene: **COMPLETE**
- M8.1: **COMPLETE**
- M8.2A Edge Resource Bounds & Failure Envelopes: **COMPLETE**
- M8.2B Flutter Auth/Session Reliability: **COMPLETE**
- M8.2C Guest Web / Observability Reliability: **COMPLETE**
- M8.2: **COMPLETE**
- M8.3 Security Matrix & Provider Evidence: **COMPLETE**
- M8.4 NFR Benchmarks & Evidence-Based Tuning: **COMPLETE**
- M8.5 Source-Controlled / Local Release Readiness: **COMPLETE**
- M8.5 External Staging, Device & Recovery Evidence: **BLOCKED**

Date: 2026-08-26

Approved design:
`docs/superpowers/specs/2026-08-26-security-nfr-hardening-design.md`

## M8.1A Scope

This slice closes `M8-P1-001` only:

- align Flutter Payment and Refund RPC calls with the installed PostgreSQL
  functions;
- restore expected-updated-at stale-write protection;
- remove binary floating-point conversion from authoritative Finance money
  writes;
- add exact serialization and bounded-error tests.

No database behavior, Finance business semantics, RLS, Edge route, Wedding
lifecycle, performance, CSP, CI, or other M8 finding changed.

## Installed Finance Contract

The source migration and reset local PostgreSQL catalog were both inspected. The
installed `api_v1` arguments are:

| RPC | Installed arguments in order |
| --- | --- |
| `create_payment` | `p_request_id uuid`, `p_budget_item_id uuid`, `p_installment_id uuid`, `p_amount numeric`, `p_payment_date date`, `p_payer_wedding_member_id uuid`, `p_payer_display_name varchar`, `p_notes text` |
| `edit_payment` | `p_payment_id uuid`, `p_installment_id uuid`, `p_amount numeric`, `p_payment_date date`, `p_payer_wedding_member_id uuid`, `p_payer_display_name varchar`, `p_notes text`, `p_expected_updated_at timestamptz` |
| `void_payment` | `p_payment_id uuid`, `p_void_reason text` |
| `create_refund` | `p_request_id uuid`, `p_budget_item_id uuid`, `p_amount numeric`, `p_refund_date date`, `p_receiver varchar`, `p_notes text` |
| `edit_refund` | `p_refund_id uuid`, `p_amount numeric`, `p_refund_date date`, `p_receiver varchar`, `p_notes text`, `p_expected_updated_at timestamptz` |
| `void_refund` | `p_refund_id uuid`, `p_void_reason text` |
| `preview_installment_compound` | `p_installment_id uuid`, `p_new_amount numeric DEFAULT NULL`, `p_new_due_date date DEFAULT NULL` |
| `commit_installment_compound` | `p_installment_id uuid`, `p_impact_fingerprint varchar`, `p_new_amount numeric DEFAULT NULL`, `p_new_due_date date DEFAULT NULL` |

The Flutter mappings now use those names exactly. The `p_new_*` naming remains
only for FIN-007 because it is part of that installed preview/commit contract.

## Root Causes and Fixes

### Payment Edit

The previous Flutter service sent `p_new_amount`, `p_new_payment_date`,
`p_new_payer_display_name`, `p_new_payer_wedding_member_id`, and `p_new_notes`.
Those names do not exist in the installed FIN-002 RPC. It also omitted
`p_installment_id` and `p_expected_updated_at`.

The corrected call sends:

- `p_payment_id`
- `p_installment_id`
- `p_amount`
- `p_payment_date`
- `p_payer_wedding_member_id`
- `p_payer_display_name`
- `p_notes`
- `p_expected_updated_at`

`expectedUpdatedAt` is required by the Flutter service and is serialized from the
authoritative model timestamp as a UTC ISO-8601 string. The DB still implements
the converged-state check before rejecting a stale update.

### Refund Edit

The previous Flutter service sent `p_new_amount`, `p_new_refund_date`,
`p_new_receiver`, and `p_new_notes`, and omitted `p_expected_updated_at`.

The corrected call sends:

- `p_refund_id`
- `p_amount`
- `p_refund_date`
- `p_receiver`
- `p_notes`
- `p_expected_updated_at`

### Decimal-String Safety

`MoneyText` is the narrow shared validator/normalizer for current Finance writes.
It:

- trims surrounding whitespace;
- accepts only dot-decimal text;
- permits at most two fractional digits;
- enforces the 13 integer-digit bound of `numeric(15,2)`;
- rejects comma ambiguity, signs, exponent notation, and malformed values;
- enforces positive amounts for Wedding budget, installments, payments, and
  refunds;
- permits zero only for nullable BudgetItem estimated/confirmed values, matching
  their existing DB checks;
- emits a canonical two-fraction-digit string without parsing through `double`.

The canonical string is now used for:

- Wedding target budget;
- BudgetItem estimated and confirmed cost;
- Installment direct create/update;
- FIN-007 preview/commit proposed amount;
- Payment create/edit amount;
- Refund create/edit amount.

The Finance service defensively rejects non-string money supplied to direct
BudgetItem/Installment methods, preventing a future caller from reintroducing a
floating-point path.

## Preserved Finance Semantics

- Member payer IDs are still validated by the DB as ACTIVE members of the same
  Wedding, and the DB snapshots the member display name.
- External payer calls still use a null member ID and require an external display
  name.
- Payment installment relinking still sends `p_installment_id`; the DB restricts
  the target to the Payment's immutable BudgetItem.
- Payment/Refund stale conflicts map to bounded `STALE_STATE` UX without raw
  PostgREST, table, SQLSTATE, or provider text.
- Existing FIN-007 stale-impact behavior remains `STALE_IMPACT`.
- Estimate, Confirmed/Committed, Installment, Payment, Refund, Net Paid,
  Outstanding, Overpaid, FIN-001 through FIN-007, receipt behavior, and OWNER-only
  Finance authorization are unchanged.

## Test Evidence

### Focused Flutter Tests

`organizer_app/test/finance_service_contract_test.dart` adds 9 tests covering:

- exact normalization for `0.10`, `0.29`, `1.01`, `1000000.01`, and
  `9999999999999.99`;
- rejection of excess fraction digits, non-number input, comma decimals,
  negative/zero positive-only values, and out-of-range values;
- exact Payment create and edit RPC keys;
- exact Refund create and edit RPC keys;
- string, not double, amount payloads;
- Payment installment relink and payer fields;
- required expected-updated-at payloads;
- absence of Payment/Refund `p_new_*` drift;
- FIN-007 installed `p_new_amount` naming with string serialization;
- bounded Payment stale-state, FIN-007 stale-impact, and unknown Refund errors.

Final Flutter result:

- 8 test files;
- 40 tests;
- 0 failures;
- analyzer: 0 errors, 0 warnings, 208 INFO diagnostics.

The INFO diagnostics are pre-existing style/deprecation debt tracked by the M8
design and are not release-severity analyzer findings for this slice.

### Database Regression

- clean `npx supabase db reset`: PASS;
- latest migration: `00000000000015_batch_15.sql`;
- migration files: 16, Batch 00 through Batch 15;
- `npx supabase test db`: 13 files, 438 assertions, 0 failures;
- no database migration or function change was required.

## Defects Fixed During Verification

- Corrected the Payment and Refund parameter-name drift.
- Added the missing edit stale timestamps and Payment installment parameter.
- Removed all identified authoritative Finance `double.parse`/`double.tryParse`
  write paths.
- Removed six analyzer dead-code warnings introduced by the first `Never` error
  mapper cleanup.
- Preserved FIN-007's existing `STALE_IMPACT` code after separating it from the
  new Payment/Refund `STALE_STATE` mapping.
- Replaced raw Finance database/unknown error messages with bounded product text.

## Documentation Drift

`DOC-DRIFT-M8-001` is reconciled by current-state description only: Flutter
Finance services and screens were already wired, despite older M5 text describing
scaffolding. M8.1A corrected concrete RPC and decimal defects in that wired code.
Historical M5 evidence and status records were not rewritten.

## M8.1B Wedding Concurrency + DELETING Read Matrix

This slice closes `M8-P1-002` and `M8-P1-004` through
`00000000000016_batch_16.sql`.

### TOP-WED-001 Receipt Serialization

`api_v1.create_wedding` still derives its actor only from `auth.uid()`, computes
the existing semantic hash, and rereads the authoritative live Wedding on
replay. Before reading or creating the receipt, it now obtains a
transaction-scoped PostgreSQL advisory lock derived from the fixed operation
type, authenticated actor UUID, and request UUID. The prior receipt insert's
`ON CONFLICT DO NOTHING` was removed.

Consequently, concurrent identical requests serialize on one receipt identity:
the first transaction creates the Wedding/member/receipt atomically, and the
second observes that committed receipt and follows the existing replay path.
Hash collisions can only serialize unrelated operations; they cannot authorize
or merge them because the receipt unique key and semantic hash remain
authoritative. Receipt lifetime remains the Wedding lifetime, with no TTL or
cleanup change.

The repository-contained `supabase/verification/top_wed_001_concurrency.sql`
harness opens two real PostgreSQL sessions with `dblink` and dispatches both
authenticated calls before collecting either result. Final evidence:

- concurrent callers: 2;
- distinct returned Wedding IDs: 1;
- committed Weddings: 1;
- authoritative receipts: 1;
- results: one initial create and one converged replay;
- same request UUID with changed semantic payload: `REQUEST_ID_REUSED`.

### Approved DELETING Read Matrix

`M8-ARCH-PROPOSED-001` is resolved by the PO-approved recovery-only matrix.
`security.is_active_wedding_member` and `security.is_wedding_owner` now require
the Wedding lifecycle to be `ACTIVE` or `ARCHIVED`, preserving normal ACTIVE
reads and ARCHIVED read-only behavior while automatically closing existing
business-graph and Storage SELECT policies in DELETING.

The new `security.can_owner_recover_deleting_wedding` helper requires the
current `auth.uid()` to be an active OWNER of a DELETING Wedding. It is used only
to retain:

- the Wedding row needed for identity, name/status, selector, and retry UX;
- that actor's own active OWNER membership row.

All three lifecycle read helpers are `SECURITY DEFINER`, use an empty search
path and fully qualified references, and are owned by
`trusted_function_owner`; no generic administrative or actor-parameter surface
was introduced.

DELETING events, tasks, guests, groups, invitation parties, invitations,
targeting, RSVP/event responses, Finance rows/summaries, member-directory rows,
and organizer Storage objects are denied. Collaborators cannot read the
DELETING Wedding or graph. Anonymous and cross-Wedding reads remain denied. The
M7 service-only begin/finalize bridge is unaffected and OWNER delete recovery
continues to converge.

The existing Flutter flow required no production change: it fetches the Wedding
metadata row, sees `DELETING`, receives only the current OWNER membership from
the existing member query, and renders the recovery-only panel. Its task query
returns no graph rows and the normal workspace remains hidden.

### M8.1B Verification Evidence

- clean `npx supabase db reset`: PASS through
  `00000000000016_batch_16.sql`;
- local Data API auto-exposure explicitly disabled in `supabase/config.toml`,
  preserving the repository's explicit grant model under the current CLI;
- full pgTAP: 14 files / 486 assertions / 0 failures;
- dedicated Batch 16: 48 assertions covering lifecycle reads/writes, Storage,
  replay, semantic mismatch, and M7 recovery compatibility;
- real concurrency: 2 callers / 1 returned Wedding identity / 1 committed
  Wedding / 1 receipt / `REQUEST_ID_REUSED` on changed semantics;
- real local PostgREST: ACTIVE and ARCHIVED owner/member reads HTTP 200;
  DELETING OWNER recovery rows 1 and graph rows 0; DELETING collaborator rows 0;
  cross-Wedding rows 0; anonymous Wedding read HTTP 401;
- real local Storage: ACTIVE and ARCHIVED organizer reads HTTP 200; DELETING
  organizer read HTTP 400; service-role M7 cleanup authority was not changed;
- focused Flutter lifecycle/recovery suite: 10 tests / 0 failures; no Flutter
  source change or analyzer run was required.

Security review passed: ARCHIVED reads remain intact; DELETING cannot be used as
a collaborator read-only workspace; only current OWNER recovery identity is
visible; Storage read is minimized; no cross-Wedding or anonymous access was
introduced; semantic hashing and `auth.uid()` actor authority remain intact; no
custom GUC security authority, generic lock surface, or new API was added.

Defects fixed during verification:

- corrected TOP-WED-001's ignored concurrent receipt-conflict race;
- separated DELETING recovery identity from ordinary graph-read helpers;
- explicitly disabled current local CLI Data API auto-exposure so reset keeps
  the project's intended explicit grants and historical security tests;
- kept the standalone concurrency harness outside pgTAP auto-discovery;
- corrected new harness-only pgTAP and asynchronous `dblink` result handling.

## Remaining M8 Work

M8 remains IN PROGRESS. This slice does not close:

- full security matrix/provider evidence;
- NFR benchmarks and evidence-based indexing;
- CI, staging, CSP, deployment, observability, or recovery gates;
- other P2/P3 findings in the approved M8 design.

## M8.1C Map Validation + Function Hygiene

This slice closes `M8-P1-007` and `M8-P2-004` through
`00000000000017_batch_17.sql` without adding or changing any organizer, public,
Edge, or trusted API surface.

### Public Event Map URL Contract

`public.wedding_events.map_link` remains nullable and retains its existing blank
semantics. Every database write path is now covered by
`chk_wedding_events_map_link_https`:

- surrounding whitespace is ignored for validation;
- the scheme comparison is case-insensitive;
- non-blank values must be absolute `https://` URLs with a non-empty authority;
- whitespace inside the URL, bare hosts, scheme-relative values, malformed
  near-matches, and non-HTTPS schemes are rejected;
- values are not fetched, rewritten, or silently repaired.

No current row or repository `map_link` fixture used `http://`, so the PO's
conditional HTTP compatibility exception was not activated. Existing HTTPS
fixtures remain valid. The constraint protects direct Class-B inserts/updates,
trusted or template writes, and therefore the map value emitted by D-INV-001.
Guest Web receives the same DTO field and required no source change.

### Function Security Hygiene

The live pre-migration catalog showed both public trigger functions owned by
`postgres` with default broad EXECUTE, while the Finance helper was already
owned by `trusted_function_owner` but had no explicit search path and also
inherited broad EXECUTE.

Batch 17 now enforces:

| Function | Owner | Definer | Search path | Direct EXECUTE |
| --- | --- | --- | --- | --- |
| `public.fn_invitation_targeting_guard()` | `trusted_function_owner` | yes | empty | owner only |
| `public.fn_normalize_guest_contacts()` | `trusted_function_owner` | yes | empty | owner only |
| `internal.recompute_installment_status(uuid)` | `trusted_function_owner` | no | empty | owner only |

`PUBLIC`, `anon`, `authenticated`, and `service_role` have no direct EXECUTE on
these helpers. PostgreSQL trigger invocation does not require client EXECUTE,
and the Finance Class-C functions run as their shared trusted owner, so no
replacement client or service grant was needed. The normalization, targeting,
and installment recomputation behavior is unchanged.

### Verification Evidence

- clean `npx supabase db reset`: PASS through
  `00000000000017_batch_17.sql`;
- migration files: 18, Batch 00 through Batch 17;
- full pgTAP: 15 files / 529 assertions / 0 failures;
- dedicated Batch 17: 43 assertions covering URL validation, catalog ownership,
  definer/search-path state, grants, trigger callers, FIN-001 recomputation, and
  the D-INV-001 map DTO;
- real local Auth/PostgREST: OWNER HTTPS update HTTP 204; `javascript:` and
  `data:` HTTP 400; existing collaborator policy HTTP 204; cross-Wedding rows
  changed 0; anonymous update HTTP 401;
- real service-only D-INV-001 PostgREST bridge: HTTP 200 and the validated HTTPS
  map value present in the event DTO;
- invitation-resolve Deno smoke: 1 file / 4 tests / 0 failures using
  `deno test --allow-env`;
- Finance regression is included in the full DB suite, and Batch 17 directly
  proves FIN-001 can still invoke recomputation and move the paid installment to
  `PAID`.

Security review passed: unsafe schemes cannot enter server state; public output
can only contain values accepted by the database contract; trigger execution no
longer depends on broad client grants; the internal Finance helper is hidden;
RLS and cross-Wedding isolation are unchanged; and no custom GUC authority or
new callable surface was introduced.

Verification fixes were test-only: the installed pgTAP version lacked
`has_check`, so the constraint assertion uses `pg_constraint`; the Guest trigger
regression uses the existing authenticated UPDATE path because historical Batch
04 grants do not include direct Guest INSERT; and the Edge smoke command includes
its required environment-read permission. No unrelated Guest grant or Edge
behavior was changed.

## M8.2A Edge Resource Bounds & Failure Envelopes

This slice closes `M8-P1-005` and, as a directly related narrow configuration
bound, `M8-P2-007`. It changes no database business function, Class-D
authorization rule, Wedding lifecycle rule, route inventory, or Guest DTO.

### Shared Safety Boundary

`supabase/functions/_shared/edge_safety.ts` provides only the common primitives
needed by the three delivered Edge handlers:

- streamed byte counting with a declared-length fast rejection and an actual
  body-byte limit that does not trust `Content-Length`;
- bounded UTF-8 JSON parsing for inbound and provider response bodies;
- `AbortController` deadlines around every outbound provider `fetch`;
- bounded integer environment parsing with safe fallback;
- server-generated UUID correlation IDs returned as `X-Request-ID`.

No framework, persistence, telemetry backend, incoming request-ID trust, or new
public error taxonomy was added.

### Resource Limits

| Boundary | Limit |
| --- | --- |
| Invitation resolve request | 2 KiB |
| Invitation RSVP request | 32 KiB |
| Wedding delete request | 2 KiB |
| RSVP EventResponses | 20, reject rather than truncate |
| Auth response | 64 KiB |
| Storage list response | 512 KiB |
| DB/bridge response | 1 MiB |
| Signed-URL response | 64 KiB |

The existing RSVP optional-field bounds remain: guest message and note 1,000
characters, dietary information 500 characters, at most 20 companion names,
and at most 100 characters per companion name. The 43-character invitation
token and Wedding delete's minimal `wedding_id` request remain unchanged.

Touched numeric configuration now fails closed to its existing default:

- resolve rate limit: default 30, accepted range 1-300;
- RSVP rate limit: default 10, accepted range 1-100;
- signed cover TTL: default 1,800 seconds, accepted range 60-3,600 seconds.

Rate-limit dimensions and policy were not redesigned.

### Provider Deadlines and Failure Envelopes

- Supabase Auth `/auth/v1/user`: 5 seconds;
- PostgREST/`edge_api` calls: 8 seconds;
- Storage list/delete: 8 seconds per provider call;
- Storage signed-cover request: 5 seconds.

Invitation resolve retains `TEMPORARY_ERROR`, RSVP retains
`TEMPORARY_UNAVAILABLE`, and wedding deletion retains
`DELETE_RETRY_REQUIRED` after lifecycle begin/cleanup/finalization failures.
Explicit domain 4xx and rate-limit responses are unchanged. Every route now has
a final exception boundary; no abort type, URL, SQLSTATE, RPC name, stack, JWT,
invitation token, RSVP body, service key, or signed URL is echoed or logged.

Wedding deletion still authenticates the organizer, derives the actor from the
verified Auth user, begins through the service-only bridge, cleans the
authoritative prefix, verifies it empty, and finalizes through the service-only
bridge. List/delete/finalize failures leave the Wedding `DELETING`; no rollback
to `ACTIVE` or `ARCHIVED` was introduced.

### Verification Evidence

- Deno 2.9.5 full Edge suite: 4 files / 30 tests / 0 failures;
- body tests cover normal and oversized resolve/RSVP/delete requests without
  trusting `Content-Length`;
- RSVP tests accept 20 responses and reject 21;
- deterministic injected scheduling proves deadline abort and timer cleanup;
- Auth, DB, Storage list, Storage delete, and finalization failure paths return
  bounded envelopes without raw details;
- clean `npx supabase db reset`: PASS through Batch 17;
- full pgTAP: 15 files / 529 assertions / 0 failures;
- real local Edge/provider smoke: invitation resolve HTTP 200, RSVP HTTP 200,
  Wedding delete HTTP 200, fresh delete-prefix entries 0, deleted Wedding rows
  0, and preserved Auth users 1;
- Guest Web smoke: 2 test files / 9 tests / 0 failures.

Security review passed: body and provider-response processing is bounded; all
outbound calls have deadlines; service-role values remain inside Edge; Class-D
and OWNER authorization are unchanged; no route was added; cleanup targets
remain server-derived; errors remain small and no-store; and no changed code
logs secrets, tokens, PII, provider responses, or raw request bodies.

Defects fixed during verification were limited to implementation mechanics: the
Deno Windows timer-handle type was made runtime-neutral, bounded bridge JSON was
narrowed explicitly, and the disposable provider harness now removes RSVP event
responses before fixture teardown. No production database or Guest Web change
was required.

At M8.2A closure, AUTH_LOST/build-time Flutter configuration, Guest Web CSP,
CI/staging, NFR benchmarks, full security-matrix evidence, broad observability,
and unrelated rate-limit policy remained outside that slice.

## M8.2B Flutter Auth/Session Reliability

This slice closes `M8-P1-003` and the client-source portion of `M8-P2-008`.
It changes no database, RLS, Edge, Storage, Guest Web, or Wedding lifecycle
contract.

### AUTH_LOST and Wedding Access Recovery

The existing `SupabaseService` now owns one small
`SessionRecoveryController`. It observes Supabase auth-state changes and gives
the root navigator a single authenticated/auth-lost transition path. A missing,
signed-out, expired, refresh-failed, revoked, or backend-rejected organizer
session clears auth-dependent selected-Wedding state and returns the app to the
login surface without exposing provider details. Wedding-delete HTTP 401 uses
the same path; HTTP 403 remains an authorization result rather than an account
logout.

Selected Wedding access is revalidated using only selector/recovery metadata on
startup, token refresh, app resume, Wedding switch, and authoritative access
failure. A revoked membership or physically absent Wedding clears the stale
selection and returns to the selector/no-Wedding flow; another accessible
Wedding remains available there. This does not log out a still-valid account.

ARCHIVED Weddings remain selectable and readable. A DELETING Wedding remains
available only when RLS returns it to the active OWNER; the home load reads the
Wedding plus that actor's own membership and does not fetch tasks or the normal
business graph before rendering the recovery-only panel. A collaborator cannot
recover a DELETING Wedding because the metadata query returns no accessible row.

### Safe Errors and Draft Preservation

`AppErrorMapper` provides the bounded categories needed by current UX:
`AUTH_LOST`, access revoked, validation/conflict, `STALE_STATE`,
`STALE_IMPACT`, retry required, and generic failure. It inspects technical
details only for classification and never displays SQLSTATE, RPC/table names,
PostgREST payloads, provider URLs, Storage paths, or stack text. Existing stale
and delete-retry semantics remain distinct. Organizer screens that previously
interpolated exceptions now use this mapping.

The create-Wedding form keeps its non-sensitive name, budget text, cultural
context, and date choices in a process-memory-only draft. This allows a user to
reopen the form after login without writing the draft to device storage. The
draft is cleared after success. Passwords, JWTs, invitation tokens, credentials,
payment secrets, and the typed permanent-delete confirmation are not part of
the draft model; the existing delete confirmation remains dialog-local and is
discarded when closed.

### Public Build Configuration

Flutter now reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` exclusively through
`--dart-define`; the checked-in local URL and JWT-shaped anonymous key were
removed. Startup requires an HTTP(S) URL and plausible publishable/anonymous
client key, rejects a JWT whose role is `service_role`, and shows a bounded
deployment-configuration screen without echoing key material. There is no
Flutter service-role configuration path.

`organizer_app/README.md` documents local Android-emulator and desktop/web
defines. Google Sign-In remains dependent on platform OAuth client metadata,
redirect allowlists, signing fingerprints, and matching Supabase provider
configuration. No production Google identifier was invented or hard-coded;
M8 staging/release work must supply and verify those deployment values.

### Verification Evidence

- full Flutter suite: 11 test files / 54 tests / 0 failures;
- focused coverage proves config validation and service-role rejection,
  AUTH_LOST state transitions, token-refresh revalidation, wedding-delete 401,
  stale/revoked/deleted selection recovery, another/no-Wedding destinations,
  ARCHIVED and OWNER DELETING compatibility, in-memory draft behavior, and raw
  technical-error redaction;
- `flutter analyze`: 0 errors / 0 warnings / 212 info diagnostics (existing
  style/deprecation debt remains outside this slice);
- DB smoke: 15 pgTAP files / 529 assertions / 0 failures;
- wedding-delete Edge auth/contract smoke: 1 file / 12 tests / 0 failures;
- source audit: no organizer token logging, no service-role client setting, no
  hard-coded Supabase key, no persisted delete confirmation, and no backend
  surface change.

Verification fixes were limited to client implementation mechanics: imports for
the shared session error path were added to Finance forms, SQLSTATE `42501` was
classified as an access signal and then metadata-revalidated before selection
is cleared, and token refresh was made to notify even when authentication state
remains valid. No backend simplification or lifecycle redesign was required.

M8 remains IN PROGRESS. Guest Web CSP, CI/staging (including real Google OAuth
deployment values), NFR benchmarks, full security-matrix evidence, broad
observability, and unrelated P2/P3 findings remain outside this slice.

## M8.2C Guest Web Security and Reliability

This slice closes `M8-P1-010`, `M8-P2-010`, and the MVP requirement in
`M8-P2-011`. M8 overall remains **IN PROGRESS**; CI/staging, measured NFR gates,
the full release security matrix, and unrelated findings remain later slices.

### Cloudflare Pages Security Policy

`guest_web/public/_headers` is the committed Cloudflare Pages policy and Vite
copies it to `dist/_headers` during the production build. The app shell uses
`Cache-Control: no-store`; fingerprinted `/assets/*` files use a one-year
immutable cache policy. Browser protections include `nosniff`, `no-referrer`,
a deny-by-default Permissions Policy, and a CSP with:

- `default-src`, scripts, styles, fonts, forms, base URLs, and API connections
  restricted to same origin;
- no `unsafe-eval`, inline-script exception, generic source wildcard, frame,
  object, or worker authority;
- `frame-ancestors 'none'` for clickjacking protection;
- HTTPS Supabase subdomains allowed only for optional signed cover images.

The production Guest API contract remains same-origin. Deployment must route
`/v1/invitation/resolve` and `/v1/invitation/rsvp` accordingly rather than
weakening `connect-src`. Invitation tokens still enter through the URL fragment,
are scrubbed from browser history, live only in `sessionStorage`, and are never
written to `localStorage`, markup, user errors, or logs.

### Fetch Recovery and Optional Media

Guest resolve now has a 15-second browser deadline, allowing the Edge DB and
optional cover-signing stages to complete within their server deadlines. RSVP
has a 12-second browser deadline. Both use `AbortController`; timeout and network
details map to the existing bounded temporary-unavailable product states. Resolve
offers an explicit manual retry. RSVP never auto-replays a write: the entered
form state remains in memory and the guest may deliberately submit again.

Signed-cover load failure remains non-blocking: the failed image is hidden while
the invitation and RSVP stay usable, and its signed URL is never included in an
error. Proactive signed-cover refresh is not needed for the current MVP contract.

### Platform-Native Operational Events

All three Edge routes emit one platform-native JSON completion event using the
same server-generated `X-Request-ID`. The allowlisted event fields are:

`event`, `route`, `outcome`, `status_category`, `duration_ms`,
`correlation_id`, `retry_required`, and `rate_limited`.

The fixed outcome set distinguishes success, rejection, rate limiting,
retry-required provider/5xx outcomes, and unexpected exceptions. The logger has
no arbitrary metadata parameter, so bearer or invitation tokens, request bodies,
guest/Finance data, service credentials, signed URLs, Storage paths, provider
responses, and stack traces cannot enter this event shape. No external APM or
telemetry dependency was added.

### Verification Evidence

- Deno 2.9.5 full Edge suite: 5 files / 32 tests / 0 failures;
- Guest Web: 4 files / 15 tests / 0 failures; ESLint PASS;
- production build: PASS in 751 ms; JavaScript 203.23 kB / 64.36 kB gzip;
  `dist/_headers` present and byte-for-byte sourced from the committed public
  artifact;
- DB smoke: 15 pgTAP files / 529 assertions / 0 failures;
- real local Auth/Edge/PostgREST/Storage smoke: invitation resolve HTTP 200,
  RSVP HTTP 200, Wedding delete HTTP 200, fresh delete prefix entries 0,
  deleted Wedding rows 0, and preserved Auth users 1;
- deterministic Guest tests cover resolve timeout, RSVP timeout with no
  automatic replay, network failure redaction, manual resolve recovery,
  non-blocking cover failure, fragment/session-only token handling, and the
  committed CSP/header contract;
- Edge tests prove the structured allowlist, correlation ID, outcome flags, and
  absence of token, authorization, signed URL, service-role, body, and guest
  fields.

The only verification fix outside runtime code was making the existing
`m8_2a_edge_provider_smoke.ps1` tolerate the Supabase CLI's stderr warning for
intentionally disabled optional services while still checking its exit code and
every provider post-condition. The harness requires PowerShell 7 because it uses
`SkipHttpErrorCheck`; no fixture, credential, token, provider response, or build
output is retained.

## M8.3 Security Matrix and Provider Evidence

This slice closes `M8-P1-009`, materially resolves `M8-P2-001`, and closes
`M8-P2-006`. M8 overall remains **IN PROGRESS** for later CI/staging, NFR,
backup/recovery, and release-gate work only.

### Catalog and Callable-Surface Sweep

Batch 18 corrects the one catalog defect found by the live sweep: the four
legacy `SECURITY DEFINER` helpers `security.can_mutate_wedding`,
`security.can_owner_delete_wedding`, `security.can_owner_mutate_wedding`, and
`security.is_wedding_cover_path` were owned by `postgres`; they now use the
established `trusted_function_owner`. Their empty search paths, existing grants,
and behavior remain unchanged.

`database_verification_batch_18.test.sql` is an invariant-based drift check.
It asserts the expected 17 public business-table names, RLS on every one, no
anon direct business-table grant, schema usage boundaries, trusted owner plus
empty `search_path` on every scoped SECURITY DEFINER function, authenticated-only
`api_v1`, service-only `edge_api`, hidden `internal`, and no anon/service-role
direct execution of `security` helpers.

The reset catalog inventory contains 17 public business tables, 23 `api_v1`
functions, 4 service-only `edge_api` functions, 12 hidden `internal` functions,
and 7 `security` helpers. All 46 scoped functions have their approved grant
boundary. The intentional legacy internal overloads are hidden and do not create
client-callable drift; no new API or public route was added.

### Real HTTP and Class-D Evidence

The disposable real PostgREST fixtures authenticate OWNER, COLLABORATOR,
unrelated OWNER, and anonymous identities. They prove ACTIVE same-Wedding read,
ARCHIVED read-only access, DELETING OWNER recovery metadata only, DELETING graph
denial, DELETING collaborator denial, cross-Wedding zero-row filtering, and
anonymous HTTP 401. Representative planning, Guests, Finance, invitations,
targeting, map-link mutation, and public bridge cases all retain their approved
role/lifecycle behavior. Direct cross-Wedding update returns no changed rows;
anonymous update is denied.

The real Class-D fixture proves resolve and RSVP HTTP 200 with a valid credential;
an invalid credential carrying an arbitrary `wedding_id` field and a revoked
credential both return generic HTTP 404. The body field does not supply tenant
authority. No Class-D flow needs a direct anonymous database grant.

### Rate-Limit Provenance and Dimensions

`networkSignal` now uses only `CF-Connecting-IP` for an IP partition. It no
longer trusts `X-Forwarded-For` or `X-Real-IP`: local Supabase accepts those as
client-provided headers, so they cannot be authority. Without a provider-supplied
Cloudflare header it uses the fixed `unverified-network` partition.

Both Class-D routes now combine that route-scoped network partition with a
route-scoped SHA-256 token partition. The persisted limiter key stores only 32
hexadecimal characters from each digest, never the raw IP or credential, and is
well below the existing 128-character contract. This preserves shared-NAT
fairness while making distributed requests across arbitrary network partitions
harder to abuse. Unit tests prove CF precedence, forwarded-header rejection,
route separation, token separation, bounded format, and absence of raw values.
Existing environment count bounds remain 1-300 for resolve and 1-100 for RSVP;
the limiter window remains database-owned and has no unbounded Edge environment
control.

Production Cloudflare deployment must preserve provider ownership of
`CF-Connecting-IP`; local testing deliberately treats all non-CF forwarded
headers as untrusted. That deployment routing proof remains an M8 staging/release
evidence item, not a remaining application security defect.

### Real Storage and Secret Hygiene

The real local provider harness uploads 101 disposable objects beneath one
Wedding pagination prefix. Storage returned exactly 100 entries at offset 0 and
1 entry at offset 100. The canonical delete orchestration removed the entire
prefix, made a fresh list empty, physically deleted the Wedding, and preserved
its Auth user. This closes `M8-P2-006` with provider—not mock—pagination evidence.

The same real fixture re-proves ACTIVE organizer cover upload HTTP 200,
ARCHIVED/DELETING upload denial HTTP 400, DELETING read denial HTTP 400, and
no effective organizer DELETE authority: the provider returned HTTP 200 but the
object remained readable. Server cleanup continues to operate independently.

`m8_3_tracked_secret_scan.ps1` scans tracked files only and reports categories
and paths without echoing values. It checks tracked environment files, private
keys, `sb_secret_` values, bearer/JWT artifacts, and signed-URL captures. The
final run passed all five content categories with zero tracked environment files.

### Verification Evidence

- clean reset: PASS through `00000000000018_batch_18.sql`;
- full pgTAP: 16 files / 538 assertions / 0 failures; Batch 18 adds 9 catalog
  and callable-surface assertions;
- Deno 2.9.5: 5 files / 33 tests / 0 failures;
- real PostgREST lifecycle/storage matrix: PASS; ACTIVE and ARCHIVED approved
  reads HTTP 200, DELETING OWNER graph rows 0, DELETING COLLABORATOR rows 0,
  cross-Wedding rows 0, anon HTTP 401;
- real PostgREST invitation/map matrix: PASS; OWNER HTTPS update HTTP 204,
  unsafe schemes HTTP 400, collaborator existing policy HTTP 204, cross-Wedding
  rows changed 0, anon HTTP 401, public bridge HTTP 200;
- real Class-D/Storage provider matrix: resolve HTTP 200, RSVP HTTP 200,
  invalid and revoked credential HTTP 404, delete HTTP 200, provider pages
  100 plus 1, fresh target-prefix entries 0, deleted Wedding rows 0, and
  preserved Auth users 1;
- Flutter lifecycle/session smoke: 2 files / 17 tests / 0 failures;
- Guest Web: 4 files / 15 tests / 0 failures, ESLint PASS, production build
  PASS in 820 ms with 203.23 kB JavaScript / 64.36 kB gzip.

Verification-only fixes corrected Batch 18's PostgreSQL catalog comparison to
compare `name` values deterministically, made disposable provider fixtures
remove all generated paths on failure, and require PowerShell 7 for the
existing `SkipHttpErrorCheck` harness. No secrets, JWTs, fixtures, signed URLs,
logs, or generated output are retained.

## M8.4 NFR Benchmarks and Evidence-Based Tuning

This slice closes `M8-P1-008`. The approved NFR sources define only three
numeric targets: Android task/guest lists under two seconds, Guest Web first
useful invitation content under three seconds on a fixed 4G profile, and local
Excel preview parsing for 300 rows under five seconds. Finance, Edge, and
Storage have no approved numeric latency target, so their results are recorded
as diagnostics rather than an invented pass/fail gate.

The reproducible evidence lives in `docs/evidence/m8/m8_4-nfr-benchmark.md`.
The disposable database harness measures delivered query shapes over five
`EXPLAIN (ANALYZE, BUFFERS)` repetitions: 500-task list median 0.180 ms,
300-guest list median 0.190 ms, 100-payment list median 0.087 ms, 100-refund
list median 0.096 ms, Finance summary median 1.163 ms, and membership plus
credential-hash point lookups 0.046 ms and 0.047 ms. The small
Wedding-scoped fixtures use expected sequential scans and sorts; no target was
missed and no plan showed a material reason to add an index.

Flutter widget harness medians were 26 ms for 500-task initial render, 19 ms
for 300-guest initial render, and 43 ms for 300-row XLSX preview parsing. A
headless Chrome CDP fixed-4G production-bundle run (150 ms latency, 4 Mbps down,
3 Mbps up) rendered synthetic invitation content in a 622 ms median across three
cold-cache runs. Real local Edge/provider timing was 82 ms for resolve, 63 ms
for RSVP, and 176 ms for 101-object Storage cleanup plus finalization; the
provider showed actual pages of 100 and 1 entries and a fresh empty result.

No production tuning was performed because all approved local measurements
passed. Full regressions passed: clean DB reset through Batch 18 and pgTAP 16
files / 538 assertions / 0 failures; Deno 5 files / 33 tests / 0 failures;
Flutter 57 tests / 0 failures and analyzer 0 errors / 0 warnings / 212 existing
INFO diagnostics; Guest Web 4 files / 15 tests / 0 failures with lint PASS.

The local environment has no Android device/emulator, so M8.5/staging must
repeat the list fixture on the agreed reference device/network. The Guest Web
browser run measures production-bundle loading/rendering with a synthetic DTO;
its real resolve path is separately provider-tested and must be repeated against
staging 4G. A sandbox-owned ignored `guest_web/dist` directory cannot be
regenerated by the workspace identity, so the benchmark builds an identical
temporary production output and removes it afterward. These are staging/release
evidence limits, not unresolved M8.4 P1 target failures.

## M8.5 Release Automation, Staging Evidence & Recovery Gate

M8.5 implements the source-controlled portion of `M8-P1-006`: GitHub Actions
CI at `.github/workflows/ci.yml`, fixed Cloudflare Pages Functions for the
existing Guest Web `/v1/invitation/resolve` and `/v1/invitation/rsvp` routes,
and the non-secret operator runbook at `docs/release/mvp-release-runbook.md`.
The proxy uses a deployment-controlled HTTPS Supabase origin and publishable
anon key, forwards no client-supplied forwarding headers, and preserves only
Cloudflare's `CF-Connecting-IP` signal for the existing Edge limiter. It does
not create a generic proxy or expose any service credential.

The new proxy unit suite, full local Guest Web, clean database, Deno, Flutter,
tracked-secret, dependency, real PostgREST, and real Storage-provider gates
pass. Exact results and non-secret timings are recorded in
`docs/evidence/m8/m8_5-release-readiness.md`.

M8.5 local readiness is complete; M8 overall remains **IN PROGRESS** while the
remaining external release evidence is completed. Staging has now verified
Pages CSP/CORS/routing, credential-backed Guest E2E, and full-graph canonical
Wedding deletion. Outstanding gates are production-like `CF-Connecting-IP`
anti-spoof provenance, deployed Guest useful-content evidence, a reference
Android benchmark, Google Sign-In staging E2E, actual provider backup/PITR and
restore evidence, a staging rollback drill, RPO/RTO evidence, and final
release-readiness/CI evidence. M8 must not be marked complete until those gates
have real proof.

A real Cloudflare Pages staging deployment discovered and compiled the Pages
Functions, but rejected the original `../../../_shared/invitation_proxy`
imports. The two entrypoints are at `functions/v1/invitation/`, while the
helper is at `functions/_shared/invitation_proxy.ts`; both imports now use the
correct `../../_shared/invitation_proxy` path. Vite client build had already
passed. This fixes the source-controlled module-resolution defect only; proxy
routes, fixed upstream authority, header forwarding, and external staging gates
are unchanged. The subsequent redeploy completed the staging checks recorded
below.

The Pages redeploy then passed its Guest Web, CSP/header, approved-origin CORS,
invalid-origin fail-closed, and Cloudflare-to-Supabase routing checks. Real
Class-D POSTs were nevertheless rejected by the Supabase gateway with HTTP 401
`UNAUTHORIZED_NO_AUTH_HEADER` before WeddingOS code ran. The source-controlled
root cause was missing function JWT configuration. `supabase/config.toml` now
sets `verify_jwt = false` only for `invitation-resolve` and `invitation-rsvp`;
it explicitly retains `verify_jwt = true` for organizer-authenticated
`wedding-delete`. A Python standard-library TOML parser check guards the three
modes in CI. The Supabase CLI applies function configuration during
`functions deploy`; `--no-verify-jwt` is an explicit override and must be used
only for the two public functions if an operator chooses flags. The functions
were redeployed and the credential-backed Class-D staging E2E subsequently
passed.

The redeployed public Class-D routes now return their bounded 404
`INVITATION_UNAVAILABLE` envelope for `{}` through Cloudflare Pages, proving
that routing, gateway mode, handler entry, and CORS are active. This is not a
credential-backed Guest E2E result. `scripts/m8_5b_staging_guest_fixture.mjs`
uses only the approved organizer/Invitation lifecycle to create a disposable
synthetic Wedding fixture, hold the raw invitation credential in memory, run
deployed resolve/RSVP/reload/invalid/revoked checks, and optionally use the
canonical delete route for cleanup. Its two credential-free Node tests pass.

An operator subsequently supplied deployment-time access outside the repository
and completed the credential-backed synthetic Guest E2E. Resolve, RSVP,
current-state reload, invalid credential denial, regenerated credential denial,
and revoked credential denial passed without retaining a credential in source,
logs, or documentation. M8 remains **IN PROGRESS** for the remaining external
release gates.

### M8.5B Staging Guest INSERT Privilege Correction

An operator-run staging fixture subsequently proved the direct Class-B Guest
insert boundary was broken by table privilege, not RLS: creation reached Wedding,
Event, and InvitationParty before PostgREST returned HTTP 403 / `42501` for
`public.guests`. Batch 04's table-level grant was accidentally undone by its
unqualified normalization-column revoke. Batch 19 replaces that accidental
boundary with explicit authenticated `INSERT`/`UPDATE` columns matching
`GuestModel.toJson`: `wedding_id`, `invitation_party_id`, `primary_group_id`,
`name`, `phone`, `email`, `side`, and `guest_source`.

`normalized_phone`, `normalized_email`, `created_at`, and `updated_at` remain
database-controlled, and Guest `DELETE` remains unavailable to authenticated
clients. Existing ACTIVE-only RLS remains the lifecycle authority. The Flutter
serializer was corrected to omit `id`, including its empty create placeholder;
the existing update URL filter retains identity. Batch 19 pgTAP covers explicit
column grants, protected columns, normal insert/update plus trigger
normalization, outsider denial, ARCHIVED/DELETING denial, and no DELETE grant.
The fixture already uses a plain HTTPS `map_link`; no URL correction was needed.
Partial staging data is operator-owned and must be cleaned through canonical
Wedding delete. Batch 19 was deployed and the fixture completed successfully;
Guest E2E is **PASS**. M8 remains **IN PROGRESS** for the remaining external
release gates.

Verification is green: a clean local reset applied Batch 19 and the full pgTAP
suite passed 17 files / 552 assertions. The focused client regression expanded
the organizer suite to 59 passing tests; analyzer remained 0 errors / 0
warnings with 212 existing INFO diagnostics. Fixture Node tests passed 2, and
Guest Web passed 6 files / 19 tests, lint, and build. The real PostgREST
lifecycle/Storage matrix also passed: ACTIVE and ARCHIVED approved reads,
DELETING recovery-only denial, cross-Wedding and anonymous denial, lifecycle
Storage write/read controls, and ineffective organizer Storage DELETE. Its
local status parser now accepts optional stopped services only when API values
are still present, and it must run under PowerShell 7 because its existing
`SkipHttpErrorCheck` use is unsupported by Windows PowerShell 5.1.

### M8.5B Full-Graph Wedding Delete Recovery

The credential-backed synthetic Guest staging E2E is **PASS**: it exercised the
approved Wedding, Event, Party, Guest, Invitation, targeting, READY,
credential, resolve, RSVP, reload, invalid credential, regenerated credential,
and revoked credential paths without recording a credential. Its retained
recovery Wedding `8e619130-e0b1-4285-897b-2ccc69141faa` had reached `DELETING`,
had no Storage objects under its authoritative prefix, and had returned bounded
HTTP 503 `DELETE_RETRY_REQUIRED` on two canonical retries before the fix.

A clean local reproduction captured `event_responses_wedding_event_id_fkey`:
the `ON DELETE RESTRICT` EventResponse-to-WeddingEvent relationship prevents a
root Wedding cascade while RSVP response data remains. Batch 20 preserves those
ordinary integrity constraints and replaces the trusted two-argument finalizer
with one transactional, retry-safe dependency purge. It deletes RSVP/Event
response leaves, invitation credentials/targeting/invitations, Guests, Finance
payment/refund/installment/budget leaves, Tasks, Party/Group/Event nodes,
pending collaborator invitations, trusted receipts, memberships, then the
Wedding root. The service-only `edge_api` bridge, active-OWNER check, empty
Storage-before-finalize invariant, RLS, and bounded public response are
unchanged.

The finalizer locks the authorized DELETING Wedding row and rolls back as a
single function transaction on any failure. Batch 20 pgTAP covers the full
Guest/Invitation/RSVP graph plus Task/Event and Budget/Event RESTRICT paths,
wrong-actor and non-DELETING denial, unrelated-Wedding preservation, Auth-user
preservation, and absent-target retry behavior. Clean reset and pgTAP passed
through Batch 20: 18 files / 578 assertions / 0 failures. The full Edge suite
passed 5 files / 34 tests / 0 failures; the real PostgREST lifecycle/Storage
matrix remained PASS.

Operational delete diagnostics now emit a redacted structured failure stage for
`begin_bridge`, `storage_list`, `storage_cleanup`, or `finalize_bridge`, with a
correlation ID and HTTP status category where available. `callBridge` retains
only a bridge HTTP status for failed responses and never records raw provider
or PostgreSQL bodies. Public callers continue to receive only the existing
bounded `DELETE_RETRY_REQUIRED` response. Batch 20 and the updated
`wedding-delete` Edge Function were deployed to staging. After securely
refreshing the organizer session, the exact same canonical retry returned HTTP
200 `DELETED`, and an organizer PostgREST query returned zero rows for the
Wedding ID. No direct SQL cleanup or manual state repair was used. This proves
full Guest/Invitation/RSVP graph deletion and recovery retry semantics on real
staging data while preserving normal `ON DELETE RESTRICT` business semantics.
M8 stays **IN PROGRESS** for the remaining external release gates.

### M8.5C Google Sign-In Staging E2E

**GOOGLE SIGN-IN STAGING E2E = EXTERNALLY BLOCKED.** The manually configured
staging Google Android/Web OAuth clients, Supabase provider, and callback
exposed a source gap: native `google_sign_in` 7.2.0 must be initialized with a
public Web client ID when no `google-services.json` supplies it. Flutter now
uses `GOOGLE_WEB_CLIENT_ID` through `--dart-define`, fails closed before native
authentication when it is absent, and calls
`GoogleSignIn.instance.initialize(serverClientId: ...)` before `authenticate()`.
The native package exposes only an ID token for this flow, so it is exchanged
with Supabase `signInWithIdToken` without the optional access token. Flutter web
continues to use Supabase Google OAuth with PKCE. Android application ID is
`com.vibecode.weddingos.organizer_app`; the native path does not use a browser
callback/deep-link in the Android manifest.

Supabase is initialized only from build-time public URL/anon-key configuration.
`onAuthStateChange` drives session recovery; a missing, signed-out, or rejected
session clears the selected Wedding and enters bounded `AUTH_LOST` handling.
The security identity remains Supabase Auth `user.id`; Google profile data is
presentation-only and client code has no actor override or service-role path.
Google UI cancellation/provider failures are reduced to bounded Vietnamese
retry copy, without OAuth response or token disclosure.

The host has no Android SDK/device/emulator and no operator-owned Google account
session. Required staging proof is therefore unavailable: install a staging
build with `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and
`GOOGLE_WEB_CLIENT_ID=<google-web-client-id>` on a Google Play-services-capable
device, then verify sign-in, Supabase session, authenticated Wedding-selector
read, background/resume revalidation, and sign-out denial. No OAuth secret,
token, callback payload, or account identity is recorded.

`flutter test` passed 65 tests. `flutter analyze` reported 0 errors, 0
warnings, and 212 existing INFO diagnostics. New coverage verifies the native
client-ID failure-closed path, idempotent initialization, supported ID-token
handoff, and missing-token rejection. Existing coverage retains service-role
rejection from public config, safe error mapping, session recovery, and
`AUTH_LOST` for authenticated Edge failure. Native Google handoff remains a
real-device E2E requirement. M8 remains **IN PROGRESS**.
