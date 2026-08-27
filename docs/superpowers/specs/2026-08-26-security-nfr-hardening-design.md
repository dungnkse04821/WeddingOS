# WeddingOS M8 Security and NFR Hardening Design

Status: DESIGN COMPLETE - AWAITING PO DECISIONS

Date: 2026-08-26

Milestone: Practical M8 - Security & NFR Hardening

Previous milestone: M7 Wedding Lifecycle & Cleanup - COMPLETE

This document is an audit and implementation design. It does not authorize or
contain production changes.

## A. Milestone Identity

The practical milestone after M7 is **M8 - Security & NFR Hardening**. It maps
primarily to original implementation-plan **M7**, while original plan M8 is the
later release-candidate smoke-testing phase. The numbering drift is retained for
traceability and does not merge the milestones.

Planning scope comes from EPIC-13 in `docs/planning/10-mvp-backlog.md` and the
security, NFR, and release-readiness phase in
`docs/planning/11-implementation-plan.md`:

| Story | Requirement | Priority | Intent |
| --- | --- | --- | --- |
| STORY-13-01 Security Audit | REQ-06-001 | P0 | Verify RLS and tenant isolation for every business table, including cross-tenant PostgREST evidence. |
| STORY-13-02 NFR Benchmarks | REQ-06-NFR | P1 | Prove the approved task, guest, Guest Web, and Excel-preview performance targets at representative MVP fixture sizes. |
| STORY-13-03 Release Readiness | REQ-06-001 | P1 | Establish technical release gates, CI/CD evidence, and staging end-to-end proof. |

Dependencies are all delivered MVP business milestones through M7, the local
Supabase provider stack, organizer Flutter, Guest Web, and the deployment/auth
providers used by release.

## B. Scope and Out of Scope

M8 scope is limited to hardening the delivered MVP:

- close verified P1 security, correctness, reliability, and release gaps;
- add complete RLS/grant/cross-tenant verification;
- make public and organizer Edge boundaries bounded and failure-safe;
- prove numeric, idempotency, lifecycle, and provider behavior;
- measure NFR targets and add only evidence-backed indexes or optimizations;
- establish repeatable release, secrets, deployment, and recovery gates.

Explicitly out of scope:

- EPIC-12 Attention Center unless separately approved;
- unarchive or any new Wedding lifecycle feature;
- gallery, video, media-library, or R2 work;
- new Finance product behavior rather than correction of existing contracts;
- unrelated organizer or Guest Web features;
- release-candidate product smoke execution assigned to the later original M8
  phase, except creation of the M8 release gate and staging automation needed by
  STORY-13-03;
- M9 or later work.

## C. Current Callable-Surface Inventory

The inventory was checked against source and the reset local database catalog.
No accidental client-callable schema drift was found.

### C.1 Database Objects

- 17 public business base tables have RLS enabled.
- `public.member_directory` and `public.finance_summaries` are
  `security_invoker = true` views.
- Anonymous has no direct table `SELECT` and no database function execution.
- Authenticated direct table reads are tenant-filtered through security helpers.
- Authenticated direct CUD is limited to the approved Class-B tables and columns.
- Payments and refunds are read-only through tables and mutate through Class-C
  RPCs.
- Invitation credentials and pending collaborator invitations have no direct
  authenticated table grants.

### C.2 Organizer `api_v1` RPCs

All current `api_v1` functions are executable by `authenticated`, not `anon`,
and not `service_role`. They derive organizer identity from `auth.uid()`:

1. `archive_wedding`
2. `commit_event_date_change`
3. `commit_event_removal`
4. `commit_guest_merge`
5. `commit_guest_party_move`
6. `commit_installment_compound`
7. `commit_primary_group_delete`
8. `confirm_guest_import`
9. `create_payment`
10. `create_refund`
11. `create_wedding`
12. `edit_payment`
13. `edit_refund`
14. `generate_initial_plan`
15. `preview_event_date_change`
16. `preview_event_removal`
17. `preview_guest_merge`
18. `preview_guest_party_move`
19. `preview_installment_compound`
20. `preview_primary_group_delete`
21. `regenerate_invitation_credential`
22. `void_payment`
23. `void_refund`

### C.3 Edge Routes

Organizer:

- `POST /functions/v1/wedding-delete`, the deployed-function form of the
  canonical `POST /v1/organizer/weddings/delete` operation.

Guest/Class-D:

- invitation resolve, conceptual `POST /v1/invitation/resolve`;
- invitation RSVP, conceptual `POST /v1/invitation/rsvp`.

No generic admin or Storage cleanup route exists.

### C.4 Service-Only and Hidden Functions

`edge_api` is service-only:

- `resolve_public_invitation`
- `submit_public_rsvp`
- `begin_wedding_delete`
- `finalize_wedding_delete`

`internal` is hidden from `anon` and `authenticated`:

- Wedding begin/finalize delete overloads;
- invitation resolve base/current-state functions;
- RSVP submit/base/current-state functions;
- VietQR current-state function;
- installment status recomputation.

Security helpers:

- `is_active_wedding_member`
- `is_wedding_owner`
- `can_mutate_wedding`
- `can_owner_mutate_wedding`
- `can_owner_delete_wedding`
- `is_wedding_cover_path`

### C.5 Direct Class-B Access

Authenticated organizer reads cover Weddings, members, events, tasks, primary
groups, invitation parties, guests, invitations, targetings, RSVPs, event
responses, and owner-only Finance data. Approved direct mutations cover Wedding
updates and the mutable planning/guest tables; owner-only direct Finance writes
are limited to budget items and installments.

## D. Authorization and RLS Findings

### D.1 Strengths

- Every current business table has RLS enabled.
- Tenant policies bind rows to active Wedding membership.
- Ordinary mutation helpers require both active membership and an `ACTIVE`
  Wedding.
- Owner-only helpers separately enforce active owner membership.
- Cross-Wedding access is covered by many pgTAP scenarios.
- Anonymous direct table access is absent.
- ARCHIVED organizer reads remain available while ordinary writes fail closed.
- Storage write policies also require an ACTIVE Wedding.

### D.2 Findings

**M8-P1-004 - DELETING reads are broader than the approved recovery-only UX.**

`security.is_active_wedding_member` intentionally does not inspect Wedding
lifecycle so it can preserve ARCHIVED reads. The same helper is used by SELECT
policies, which means an active member can continue direct PostgREST reads of the
normal Wedding graph while the Wedding is DELETING. M7 Flutter hides the normal
workspace, but the database does not enforce a minimized recovery-only read
surface. M8 needs an explicit DB read matrix for DELETING and corresponding RLS
tests. This requires a PO decision on whether OWNER recovery may read only the
Wedding/member identity needed for retry, or whether all authenticated members
retain reads until physical deletion.

**M8-P1-009 - Security evidence is scenario-rich but not exhaustive.**

The 438 pgTAP assertions cover delivered stories well, but there is no generated
catalog sweep proving RLS/grants for every business table and no real PostgREST
HTTP matrix covering same-Wedding, cross-Wedding, anonymous, OWNER,
COLLABORATOR, ARCHIVED, and DELETING combinations. STORY-13-01 explicitly
requires that release evidence.

**M8-P2-004 - A few function grants rely on schema hiding rather than explicit
least privilege.** See section E.

## E. Function-Security Findings

The live catalog contains 47 relevant `SECURITY DEFINER` functions. The intended
trusted functions are owned by `trusted_function_owner`, use an empty search
path, use fully qualified object references, and have narrow EXECUTE grants.
`trusted_function_owner` is `NOLOGIN` with the required `BYPASSRLS`; client roles
do not have bypass.

The M7 verified-actor exception remains narrowly contained:

- Edge verifies a JWT and derives `user.id`;
- only service-role can call the `edge_api` bridge;
- the DB revalidates active OWNER membership;
- clients cannot choose the actor;
- no custom GUC is business authority.

Findings:

**M8-P2-004 - Trigger/internal grant hygiene.**

- `public.fn_invitation_targeting_guard` and
  `public.fn_normalize_guest_contacts` are `SECURITY DEFINER`, owned by
  `postgres`, with empty search paths, but retain default broad function EXECUTE
  privileges. Direct invocation is not a useful business operation, yet their
  ownership and grants should match the trusted-function convention.
- `internal.recompute_installment_status` is not security-definer and uses fully
  qualified references, but it retains default EXECUTE. Client schema USAGE
  currently prevents client access. Explicit revocation and a declared empty
  search path would make the boundary self-documenting.

No function was found that uses a custom actor GUC, exposes a generic
execute-as-user capability, or grants the M7 bridge to authenticated/anonymous.

## F. Edge-Security Findings

### F.1 Invitation Resolve

- POST/OPTIONS only with allowlisted CORS.
- Strict 43-character token contract.
- Service-only DB bridge.
- Network-hash rate limiting, default 30 requests per 60 seconds.
- Signed cover path is validated and signed for 1,800 seconds by default.
- Safe response headers include no-store, referrer protection, and nosniff.

### F.2 RSVP

- POST/OPTIONS only with allowlisted CORS.
- Strict token, UUID, and response-shape validation.
- Service-only DB bridge.
- Network-hash rate limiting, default 10 requests per 60 seconds.
- Bounded public errors for handled DB/provider failures.

### F.3 Wedding Delete

- POST only.
- Bearer token is verified through Supabase Auth `/auth/v1/user`; it is not only
  decoded.
- Actor is derived from verified `user.id`.
- Bucket and Wedding prefix are server-derived.
- Recursive Storage cleanup uses list/delete batches and verifies a fresh empty
  prefix before DB finalization.
- Public result does not expose object names or DB internals.

### F.4 Findings

**M8-P1-005 - Public Edge resource and timeout envelopes are incomplete.**

- Request bodies are parsed without an explicit content-length/body-size limit.
- RSVP validates fields but does not cap the number of event responses before
  parsing and DB submission.
- Outbound Auth, PostgREST, and Storage fetches do not use explicit deadlines.
- Wedding-delete auth and bridge network exceptions are not all caught by a
  route-level bounded-error envelope, so a provider/network exception can fall
  through to an unstructured runtime 500.

M8 must add small request limits, response-shape limits, abort deadlines, and a
top-level bounded error envelope without logging tokens or secrets.

**M8-P1-007 - Public event map links lack a server-side scheme allowlist.**

`wedding_events.map_link` is arbitrary text, is exposed in the public invitation
DTO, and becomes a Guest Web external link. The server must allow only approved
URL schemes, with `https` and optionally `http` as the minimal safe baseline.
Framework rendering behavior must not be the security boundary.

**M8-P2-009 - Edge abuse controls do not cover organizer delete.**

Wedding delete has strong owner authorization and is naturally bounded by
lifecycle, but it has no explicit endpoint rate limit. This is lower severity
than public Class-D abuse because only an active OWNER can reach cleanup. The PO
must decide whether organizer destructive operations require a separate policy.

## G. Rate-Limit Findings

Current Class-D limits:

| Route | Default limit | Key |
| --- | --- | --- |
| Invitation resolve | 30 / 60 seconds | Route-specific SHA-256 network hash |
| RSVP | 10 / 60 seconds | Route-specific SHA-256 network hash |

State is stored in `private.class_d_rate_limits` using limiter key, window start,
request count, and update timestamp. Raw IP addresses are not stored. Each call
deletes at most 100 stale rows older than ten times the effective window.

**M8-P2-001 - Current dimensions have predictable abuse and fairness gaps.**

- Distributed clients can avoid a network-only limit.
- Shared NAT users share a quota.
- Invitation token is not a second dimension.
- Forwarded-IP trust has not been provider-tested end to end.
- Cleanup is incremental and may lag under heavy key churn.
- Environment-provided thresholds are not bounded.

These are not current authorization bypasses. M8 should test provider header
provenance and propose token/network composite limits only after PO policy
approval.

## H. Receipt and Idempotency Findings

Receipt-backed operations are:

- TOP-WED-001 create Wedding;
- TOP-GUE-004 guest import confirmation;
- TOP-FIN-001 payment creation;
- TOP-FIN-004 refund creation.

Receipts bind operation, actor, request ID, semantic SHA-256 request hash,
Wedding, and result. Request ID is excluded from semantic content. Replays check
the semantic hash and return authoritative live state for Wedding, payment, and
refund operations; guest import replays its stored summary. Receipts are private,
have no client grants, and are removed with the Wedding. No time-based retention
policy exists.

Intentionally non-receipt-backed operations:

- M7 permanent delete uses durable `DELETING` lifecycle state;
- FIN-007 preview/commit operations use impact fingerprints and current-state
  preconditions;
- credential regeneration intentionally creates a new credential.

**M8-P1-002 - TOP-WED-001 can create duplicate Weddings under a concurrent
same-request race.**

The function reads the receipt, creates the Wedding/member, and then inserts the
receipt with `ON CONFLICT DO NOTHING`. Two transactions can both miss the
receipt and create separate Weddings; the ignored receipt conflict does not
converge the second transaction. M8 must serialize by the receipt identity or use
an equivalent atomic reservation and add a real concurrency test.

**M8-P2-002 - Concurrent receipt replay convergence is uneven.**

Other receipt-backed writes are protected from duplicate committed business rows
by transaction rollback and receipt uniqueness, but the losing concurrent call
can return a transient uniqueness error rather than the approved converged
result. This should be hardened after the Wedding-create blocker.

**M8-P2-003 - Receipt retention is undefined.**

Receipts currently survive for the Wedding lifetime. The PO must approve whether
MVP replay guarantees require lifetime retention or a bounded retention period.

## I. Finance Numeric Findings

Database Finance uses `numeric(15,2)`, positive/range constraints, numeric views,
and decimal-string API outputs. Outstanding and overpaid values are separated,
and unknown-total semantics remain nullable. Semantic hashes canonicalize money
with decimal formatting.

**M8-P1-001 - Flutter Finance write contracts are inconsistent with the approved
database API and decimal-string invariant.**

- `editPayment` sends `p_new_*` parameter names, while the installed DB RPC
  expects `p_amount`, `p_payment_date`, payer fields, notes, and
  `p_expected_updated_at`.
- `editRefund` has the same naming mismatch and omits required
  `p_expected_updated_at`.
- Several create/edit, installment, budget, and Wedding-budget paths convert
  values through Dart `double` rather than sending canonical decimal strings.

The read models retain money as strings, which is correct. M8 must fix the write
contract without changing Finance behavior and add exact-decimal and stale-write
tests.

## J. Data-Integrity Findings

Strengths include Wedding-scoped FKs, uniqueness for invitation token hashes and
receipt identity, lifecycle checks, positive Finance constraints, cascade proof
for permanent Wedding deletion, and trusted-operation same-Wedding validation.

**M8-P2-005 - Several invariants remain helper- or client-enforced.**

- `pending_collaborator_invitations.role` lacks a direct database role CHECK.
- Wedding cultural-context and timezone values are not fully table-constrained;
  cultural context is directly updateable through Class B.
- Some Finance names/notes do not have server-side length caps.
- Payment payer member linkage is validated as same-Wedding by trusted RPC rather
  than a composite FK.
- Event-response event linkage is validated by the public trusted function, but
  lacks a composite same-Wedding constraint for defense in depth.

M8 should add constraints only where existing data and contracts prove a safe
migration path.

## K. Storage Findings

Current controls:

- private `wedding_media` bucket;
- 5 MiB object limit;
- `image/webp` only;
- exact organizer path `weddings/{wedding_id}/cover.webp`;
- active same-Wedding organizer read/write policy;
- ARCHIVED authenticated member read remains available;
- no organizer Storage DELETE policy;
- signed URL default TTL 1,800 seconds;
- M7 server cleanup is prefix-capable and recursive, uses list page size 100 and
  delete batch size 100, relists, and requires a fresh empty result before DB
  finalization;
- cross-Wedding provider fixtures remain untouched.

Provider behavior can return HTTP success for organizer DELETE while leaving the
object in place. Authorization evidence therefore uses the post-condition, not
status alone.

**M8-P2-006 - Real provider pagination was not forced.**

M7 used real HTTP list/delete/nested/retry checks and deterministic automated
pagination logic with 101 objects, but the local provider fixture did not force a
real second provider page. M8 should add a reproducible provider pagination
fixture if practical. This is not release-blocking if deterministic logic plus
real provider list/delete remains green and the PO explicitly accepts the debt.

**M8-P2-007 - Signed URL TTL configuration lacks bounds.**

The secure default is correct, but an environment value can change it without a
minimum/maximum validation envelope. M8 should bound it and test the configured
contract.

## L. Auth and Session Findings

Flutter uses Supabase Flutter session persistence and PKCE defaults. It stores
only selected Wedding ID/name in SharedPreferences. It does not store service
credentials or organizer tokens itself.

**M8-P1-003 - AUTH_LOST and stale authorization handling are fragmented.**

- App initialization reads the current session synchronously without a central
  auth-state transition handler.
- Expired/refresh-failed sessions and revoked membership often surface as generic
  or raw exceptions.
- The approved requirement to return to login while preserving an in-progress
  form is not consistently implemented.
- A removed/physically deleted Wedding is handled by lifecycle flows, but other
  stale membership changes remain ad hoc.

M8 must centralize the bounded auth-lost response and revalidate selected Wedding
access without introducing a new state-management architecture.

**M8-P2-008 - Environment-specific public Auth config is embedded in source.**

The checked-in Supabase anonymous key is a publishable client key, not a secret,
but it is JWT-shaped and local-environment-specific. Production URL/key and
Google Sign-In configuration are not represented. M8 should use build-time
public configuration and document rotation/deployment without ever committing
service-role values.

## M. Input-Validation Findings

Database RPCs generally validate UUID-bound rows, lifecycle, expected timestamps,
positive money values, nonempty arrays, and semantic request reuse. Edge validates
Class-D tokens, UUIDs, enums, and bounded optional string fields. Storage paths
are server-derived or exact-policy validated.

Release gaps are:

- Edge body byte limits and RSVP response-count limits (M8-P1-005);
- public map URL scheme validation (M8-P1-007);
- direct-table enum/text invariants listed in M8-P2-005;
- Flutter Finance double conversion and RPC mismatch (M8-P1-001).

No mass-assignment endpoint or client-controlled Storage cleanup path was found.

## N. Error-Contract Findings

Edge routes usually map failures to small status/code/message contracts and do
not return SQLSTATE, bridge names, provider details, or stack traces. Guest Web
maps those codes to product-level states.

Flutter is inconsistent: multiple screens render `$e`, `e.toString()`, or raw
PostgREST messages. Finance mapping can preserve raw database text. Together
with uncovered wedding-delete fetch exceptions, this is part of M8-P1-003 and
M8-P1-005.

M8 should reuse a minimal existing error set:

- authorization/authentication lost;
- validation/conflict;
- retry required or network unavailable;
- generic system failure.

No broad new public error taxonomy is required.

## O. Secrets and Configuration Findings

The tracked-tree scan found no committed service-role value, private key, real
organizer JWT, signed URL capture, real media, or tracked environment file. Test
credentials are disposable/fake and provider evidence does not persist tokens.

Findings:

- the public local anonymous key/config should move to build-time configuration
  (M8-P2-008);
- no CI secret-validation workflow exists (M8-P1-006);
- release must scan tracked content and generated artifacts without printing
  matched values.

## P. Logging and Observability Findings

Edge and Guest Web contain no meaningful structured production logs. Flutter has
many development `print` calls and raw-error UI paths. There is no release
evidence for alerts or searchable events for provider failures, delete retries,
rate limiting, RSVP failures, or unexpected 5xx responses.

**M8-P2-010 - Minimal redacted operational evidence is absent.**

MVP needs small structured events for route name, outcome category, correlation
ID, duration, and provider stage. Logs must exclude bearer tokens, invitation
tokens, service keys, raw guest contacts/responses, payment details, signed URLs,
and object names where unnecessary. Heavyweight APM is not required.

## Q. Database Performance Findings

Current indexes strongly support primary/unique/FK lookup and invitation token,
membership, targeting, and receipt paths. The audit found likely list/sort paths
without matching composite indexes:

- tasks by Wedding and created/order field;
- guests by Wedding and name/created field;
- budget items by Wedding and created field;
- installments by budget item and due date;
- payments by budget item and payment date;
- refunds by budget item and refund date.

**M8-P1-008 - Required NFR evidence does not exist.**

There is no benchmark harness or representative EXPLAIN evidence for 500 tasks,
300 guests, or 100 payments. M8 must seed representative data, measure the actual
queries, and add only indexes justified by plans and target misses.

**M8-P3-001 - Invitation credential token hash has redundant-looking index
coverage.**

A separate hash index appears to overlap the unique token-hash index. Remove it
only if catalog/query evidence proves redundancy.

## R. Edge Performance Findings

- Resolve and RSVP are short service-bridge calls; resolve optionally signs one
  cover URL.
- Wedding delete intentionally performs sequential list/delete/relist work for
  retry safety and can span multiple provider calls.
- Storage page and batch size are 100, internal-only.
- No explicit provider deadlines exist.

Cold start, signed URL generation, and sequential cleanup should be measured but
not prematurely redesigned. Explicit deadlines and bounded retry behavior are
the release priority. Large-media cleanup remains limited by provider/runtime
duration and resumes safely from `DELETING`.

## S. Flutter Performance Findings

- Wedding-scoped state is invalidated on lifecycle transitions.
- Lists are currently fetched as MVP-sized collections rather than paginated UI
  streams.
- Image media processing is bounded to WebP and 5 MiB before upload.
- Wedding switching can trigger repeated domain fetches, and stale access is not
  centrally reconciled.

**M8-P3-002 - Full-list rendering is acceptable only within approved MVP
limits.**

No optimization is required if <100 task and <300 guest targets pass on the
reference Android device. The current broad max-row ceiling can become a silent
truncation risk beyond MVP and should be tracked for post-MVP pagination.

The current analyzer has 208 INFO diagnostics but zero errors/warnings. The INFO
debt is P3 unless it masks changed-code issues.

## T. Guest Web Findings

Current final build output is 202.68 kB JavaScript (64.16 kB gzip). The token is
read from the URL fragment, scrubbed from history, retained only in session
storage, and never put in local storage. React escapes rendered DTO values. The
public DTO is intentionally narrow.

**M8-P1-010 - Static deployment security controls are not represented.**

No committed Cloudflare Pages `_headers`/CSP configuration was found. Because a
guest token is a bearer capability available to page JavaScript during the
session, release must enforce and verify a restrictive CSP plus frame,
permissions, content-type, and referrer protections appropriate to the app.

**M8-P1-006 also applies:** Guest Web defaults to `/v1/invitation/...`, while the
repository does not contain production routing/proxy evidence connecting those
paths to Supabase functions.

**M8-P2-011 - Public fetch recovery is basic.**

No explicit fetch deadline or automatic signed-cover refresh exists. An expired
cover URL affects optional imagery rather than RSVP correctness, so this is not a
release blocker once bounded fetch errors are present.

The bundle size alone is not a defect; the required 4G first-content benchmark
decides whether optimization is needed.

## U. Reliability Findings

| Failure | Current behavior | Audit result |
| --- | --- | --- |
| Lost response to receipt-backed write | Replay by request ID and semantic hash | Sound except concurrency findings in section H. |
| Partial Finance mutation | One DB transaction | Fails atomically. |
| Storage cleanup interruption | Wedding remains DELETING; retry relists | Sound and provider-tested. |
| Finalize failure after empty Storage | Retry rechecks empty and finalizes | Sound. |
| Invitation/RSVP provider failure | Bounded handled errors | Needs explicit timeout envelope. |
| Expired invitation | Resolve/RSVP unavailable | Fails closed. |
| Expired signed URL | Optional cover fails until new resolve | Acceptable; refresh is P2. |
| Flutter stale session/membership | Ad hoc error/state recovery | P1 auth-lost hardening. |
| Local/provider outage | Core operation unavailable | Generally fails closed; user messaging varies. |

## V. Concurrency Findings

Strengths:

- Finance edits use expected-updated-at guards in the DB contract.
- FIN-007 preview/commit uses fingerprints and current-state validation.
- M7 archive/delete transitions are atomic and DELETING is terminal.
- RSVP upsert/validation occurs in a trusted transaction.
- Storage cleanup retries from authoritative provider state.

Findings:

- TOP-WED-001 concurrent receipt race is P1 (M8-P1-002).
- Flutter edit Payment/Refund does not currently send the DB stale-write
  parameter correctly (M8-P1-001).
- Concurrent receipt replays may return a transient conflict rather than stable
  convergence (M8-P2-002).
- Wedding switching during a mutation relies on captured IDs and screen state;
  tests should prove a response cannot update the newly selected Wedding.

## W. Backup, Recovery, and Data-Loss Findings

Product semantics are clear:

- Archive retains data and has no MVP unarchive.
- Permanent Wedding delete is intentionally irreversible and deletes Storage
  before database finalization.
- Auth users and unrelated Weddings survive.
- The application does not promise user-facing undo or recycle-bin recovery.

**M8-P2-012 - Operational recovery targets and drills are not documented.**

No repository source defines database/storage RPO/RTO, provider backup tier,
restore procedure, Cloudflare rollback, or operator recovery drill. The PO must
set the minimum release expectation. At minimum, release documentation must state
what is backed up, what is not recoverable, and how a deployment rollback and
database restore are tested. It must not imply that permanent Wedding deletion
can be undone.

## X. Privacy Findings

- Guest names, phones, emails, RSVP details, and Finance data are organizer-only
  under RLS.
- Public invitation DTO excludes Wedding IDs, credential hashes, member lists,
  guest lists, and Finance data.
- Public DTO includes only invitation-party display information, approved public
  contacts, Wedding/event details, RSVP current state, optional signed cover, and
  conditional VietQR.
- Raw invitation tokens are transient in Edge requests and same-tab session
  storage; they are not logged or persisted in repository evidence.
- Signed URLs are temporary bearer capabilities and must remain out of logs.

Privacy hardening is primarily log redaction, receipt-retention policy, CSP, and
continued DTO minimization. No additional legal compliance regime is inferred by
this audit.

## Y. Availability and Dependency Risks

| Dependency | User-visible failure | Current recovery / degraded mode |
| --- | --- | --- |
| Supabase Auth | Organizer login/session verification unavailable | Fails closed; Flutter bounded AUTH_LOST handling is incomplete. |
| Postgres/PostgREST | Core reads and writes unavailable | Transactions protect integrity; retry messaging varies. |
| Supabase Storage | Cover upload/read may fail; deletion pauses | Cover is optional for guests; Wedding deletion remains retryable in DELETING. |
| Edge runtime | Guest resolve/RSVP and Wedding delete unavailable | No alternate public path; safe retry after recovery. |
| Cloudflare Pages | Guest Web unavailable | No in-repo degraded experience or rollback evidence. |
| Google Sign-In | Organizer login unavailable | No production fallback is approved; local mock email is not production auth. |

The MVP appropriately fails closed for authorization. Availability SLAs and
provider recovery commitments are not currently specified.

## Z. Test-Coverage Findings

Current final M7 evidence:

| Layer | Evidence | Domain strength | Material gap |
| --- | --- | --- | --- |
| Database | 13 pgTAP files, 438 assertions | RLS, trusted operations, lifecycle, cascades | No complete catalog sweep or real PostgREST tenant matrix; no receipt concurrency harness. |
| Edge | 3 Deno files, 13 tests | Validation, auth boundary, cleanup logic | Limited successful Class-D DB integration and provider failure/deadline evidence. |
| Flutter | 7 test files, 31 tests | Media and lifecycle UX/service contracts | Finance write contract, auth-lost flows, cross-screen stale response behavior. |
| Guest Web | 2 suites, 9 tests | Resolve/RSVP states and rendering | Deployment headers/routing and real browser/staging E2E. |

There is no code-coverage percentage artifact, and this design does not invent
one. There is no performance/load harness, CI workflow, staging E2E suite, or
automated real-provider release suite.

## AA. Proposed MVP Release Gate

Every item below must be reproducible from a clean checkout and must block release
unless explicitly identified as PO-accepted P2 debt.

### AA.1 Database

- clean `npx supabase db reset`;
- full `npx supabase test db`;
- automated catalog assertions for RLS, table grants, schema usage, definer
  ownership/search path, and function EXECUTE grants;
- real PostgREST cross-tenant/anonymous/role/lifecycle matrix;
- TOP-WED-001 concurrent idempotency test;
- exact Finance decimal and stale-update contract tests.

### AA.2 Edge and Provider

- all Deno tests;
- request-size, timeout, bounded-error, and rate-limit tests;
- authenticated organizer route test;
- real Class-D happy-path integration;
- real Storage upload/upsert/no-effective-organizer-delete and recursive cleanup;
- real pagination fixture if practical, otherwise deterministic pagination proof
  plus explicit PO acceptance of M8-P2-006.

### AA.3 Flutter

- all Flutter tests;
- `flutter analyze` with zero errors and warnings;
- Finance exact-decimal/RPC contract tests;
- auth lost, revoked access, stale Wedding, and lifecycle recovery tests;
- reference Android task/guest list benchmarks.

### AA.4 Guest Web

- tests, lint, and production build;
- deployed route mapping and security-header verification;
- browser E2E resolve -> RSVP -> VietQR behavior;
- 4G first-content benchmark.

### AA.5 Release Operations

- CI runs all deterministic gates on protected delivery branches;
- dependency and tracked-secret scans pass without printing secret values;
- production public configuration and Google Auth setup are documented;
- staging end-to-end path passes;
- deployment rollback and agreed backup/restore drill pass;
- no P0 or P1 finding remains open;
- every shipped P2 has named owner, rationale, and PO acceptance;
- Git HEAD equals remote and the working tree is clean.

## AB. Prioritized Hardening Backlog

### AB.1 P0 - Critical

No P0 finding was identified. Current RLS, schema/grant boundaries, private
Storage, service-only actor bridge, and secret containment prevent an observed
critical unauthenticated or cross-tenant compromise.

### AB.2 P1 - Must Fix Before MVP Release

| ID | Finding |
| --- | --- |
| M8-P1-001 | Flutter Finance edit RPC names/stale parameters and decimal-double conversion violate the installed contract. |
| M8-P1-002 | TOP-WED-001 concurrent same-request race can create duplicate Weddings. |
| M8-P1-003 | Flutter AUTH_LOST/stale authorization handling and raw technical error exposure are inconsistent. |
| M8-P1-004 | DELETING direct database reads exceed the approved recovery-only product state; exact read policy needs PO confirmation. |
| M8-P1-005 | Edge routes lack complete body-size/count limits, outbound deadlines, and a universal bounded failure envelope. |
| M8-P1-006 | CI, staging E2E, production routing/config, and deployment evidence are absent. |
| M8-P1-007 | Public `map_link` lacks an approved server-side URL scheme allowlist. |
| M8-P1-008 | Approved NFR benchmarks and evidence-backed index decisions are absent. |
| M8-P1-009 | Full catalog/grant/RLS and real PostgREST cross-tenant release matrices are absent. |
| M8-P1-010 | Guest Web deployment security headers/CSP are not committed or verified. |

### AB.3 P2 - Track and Fix Soon or Accept Explicitly

| ID | Finding |
| --- | --- |
| M8-P2-001 | Class-D network-only rate-limit dimensions and forwarded-IP provenance gaps. |
| M8-P2-002 | Concurrent receipt replay may return transient conflict rather than convergence. |
| M8-P2-003 | Receipt retention period is undefined. |
| M8-P2-004 | Trigger/internal function owner, search-path, and EXECUTE grant hygiene. |
| M8-P2-005 | Role, cultural/timezone, text-length, and same-Wedding constraints need defense-in-depth review. |
| M8-P2-006 | Real Storage provider pagination was not forced. |
| M8-P2-007 | Signed URL TTL environment value is not bounded. |
| M8-P2-008 | Flutter public Supabase configuration is local and source-embedded. |
| M8-P2-009 | Organizer Wedding delete has no separate rate-limit policy. |
| M8-P2-010 | Minimal redacted structured observability is absent. |
| M8-P2-011 | Guest Web fetch timeout and signed-cover refresh behavior are basic. |
| M8-P2-012 | Backup/RPO/RTO, restore, and deployment rollback expectations are undocumented. |

### AB.4 P3 - Post-MVP or Measure First

| ID | Finding |
| --- | --- |
| M8-P3-001 | Potential redundant invitation credential hash index. |
| M8-P3-002 | Full-list Flutter rendering/pagination beyond approved MVP limits. |
| M8-P3-003 | Flutter analyzer has 208 INFO diagnostics. |
| M8-P3-004 | Edge cold-start/sequential provider-call optimization without a measured target miss. |
| M8-P3-005 | Guest Web bundle optimization absent a failed 4G benchmark. |
| M8-P3-006 | Incremental Class-D stale-key cleanup efficiency at non-MVP scale. |

## AC. Proposed M8 Implementation Slices

The slices deliberately keep each harness run bounded. Production work starts
only after the PO decisions in section AD.

### M8.1 - Correctness and Security Boundaries

- fix Finance RPC parameters, expected timestamps, and decimal-string writes;
- make TOP-WED-001 receipt acquisition concurrency-safe;
- implement the approved DELETING database read matrix;
- validate public event map URL schemes;
- harden trigger/internal owner and EXECUTE grants;
- add focused pgTAP/Flutter/concurrency tests.

### M8.2 - Edge, Session, and Error Reliability

- add Edge body/count limits, abort deadlines, and bounded top-level errors;
- bound public configuration values including signed URL TTL/rate limits;
- centralize Flutter AUTH_LOST, stale membership, and safe error mapping;
- move public Flutter environment settings to build-time configuration;
- add Guest Web CSP/security headers and fetch timeout behavior;
- add minimal redacted structured operational events.

### M8.3 - Security Matrix and Provider Evidence

- add catalog-wide RLS/grant/definer assertions;
- add real PostgREST tenant/role/lifecycle tests;
- add successful real Class-D integration checks;
- add reproducible real Storage pagination if practical;
- verify proxy/IP behavior and approved rate-limit dimensions;
- run tracked-secret and callable-surface drift checks.

### M8.4 - NFR Benchmarks and Evidence-Based Tuning

- create deterministic MVP-size fixtures;
- benchmark task/guest/Finance query plans and Android list behavior;
- benchmark Guest Web 4G first content and 300-row Excel preview;
- add only indexes or client optimizations supported by failed measurements;
- retain before/after plans and timings as non-secret evidence.

### M8.5 - Release Automation and Recovery Gate

- implement CI for DB, Edge, Flutter, Guest Web, security, and secret checks;
- verify production route mapping, public configuration, Google Sign-In, and
  Cloudflare headers in staging;
- automate the approved staging E2E path;
- document and exercise deployment rollback and approved backup/restore checks;
- produce the M8 release-readiness checkpoint without starting the later RC
  milestone.

## AD. Required PO Decisions

Only the following policy decisions cannot be settled by current engineering
evidence:

1. **Resolved - DELETING read matrix:** the PO approved minimum active OWNER
   recovery reads only. The OWNER may read the Wedding selector/recovery row and
   their own active OWNER membership. Normal business-graph and Storage reads are
   denied; collaborators receive no DELETING Wedding or graph reads. ACTIVE and
   ARCHIVED read behavior remains unchanged.
2. **P2 release acceptance:** approve which, if any, P2 findings may ship with an
   owner and target date. Recommendation: allow provider-pagination debt only if
   deterministic pagination plus real list/delete checks pass; do not silently
   accept the other P2 items.
3. **Rate-limit policy:** decide whether Class-D adds a token dimension and
   whether organizer Wedding delete gets a separate limit. Recommendation: retain
   network hash and add a non-reversible token hash dimension for Class-D after
   provider header verification; apply a generous authenticated owner limit to
   delete retries.
4. **Resolved - receipt retention:** receipts remain for the lifetime of the
   Wedding in MVP. No TTL, scheduled expiry, or retention cleanup is introduced.
5. **Backup/recovery target:** approve minimum DB backup/restore and deployment
   rollback expectations, including RPO/RTO if the provider tier supports them.
   This decision must explicitly state that permanent Wedding deletion remains
   irreversible to the user.
6. **Minimal observability destination:** approve platform-native logs only or a
   small external sink. Recommendation: platform-native structured redacted logs
   and basic error/rate-limit counters for MVP; no heavyweight APM.

Performance index selection, timeout values, request byte limits, CI commands,
and fixture construction are engineering details and do not require PO approval.

## AE. Consistency, Amendments, and Explicit Tech Debt

### AE.1 Consistency Result

The audit cross-checked planning, architecture, requirements, M5/M6/M7
checkpoints, implementation logs, project state, source, tests, and the reset
database catalog.

- M7 remains complete; no M7 contract was changed.
- M6 Storage and signed-cover controls remain intact.
- Receipt-backed and deliberately non-receipt-backed operations match approved
  architecture. Batch 16 resolves the TOP-WED-001 concurrency defect without
  changing replay semantics or receipt lifetime.
- M7-AUTH-BRIDGE-001 remains the only explicit verified-actor bridge exception.
- No new public or `api_v1` surface was introduced by this design.
- Approved architecture documents contain operations not yet present in the
  delivered callable inventory. They are unimplemented/out-of-scope surfaces,
  not accidental exposure.

### AE.2 Approved Architecture Clarification

`M8-ARCH-PROPOSED-001` is **RESOLVED / APPROVED**. DELETING is a recovery-only
database read state. An active OWNER may read the Wedding row needed by the
selector/retry UX and only their own active OWNER membership row. Normal child
graph, Finance, RSVP/invitation, and organizer Storage reads are denied. An
active COLLABORATOR has no DELETING Wedding, membership-directory, or business
graph read access. ACTIVE member reads and ARCHIVED member read-only access are
preserved. The service-only M7 delete bridge and Storage cleanup authority are
unchanged.

Batch 16 implements this distinction by making the existing normal-read helpers
lifecycle-aware for `ACTIVE` and `ARCHIVED`, while a dedicated OWNER recovery
helper is used only by the Wedding row and actor's own membership-row policies.
This is a row-level recovery surface, not a new general organizer API and not a
grant of normal DELETING workspace access.

### AE.3 Documentation Drift

`DOC-DRIFT-M8-001`: older M5 implementation/project-state text describes Flutter
Finance as scaffolded or incomplete, while the M5 checkpoint says complete and
the current app contains wired Finance services/screens. The current code also
contains the P1 RPC/decimal defects. M8.1 should reconcile the historical status
wording while documenting the actual fixes; it must not rewrite historical test
evidence.

### AE.4 Explicit Remaining Debt

- real provider pagination fixture (M8-P2-006);
- Class-D rate-limit dimensions/provider IP provenance (M8-P2-001);
- concurrent replay convergence for other receipt-backed operations
  (M8-P2-002); receipt lifetime is resolved as Wedding lifetime;
- minimal observability and operational recovery evidence
  (M8-P2-010/012);
- post-MVP list pagination, analyzer INFO cleanup, and unmeasured optimization
  items in P3.

## Design Gate Recommendation

**M8 DESIGN - READY FOR PO DECISIONS**

There is sufficient repository and provider evidence to begin implementation
after the six policy decisions in section AD are recorded. No additional broad
research phase is required.
