# Implementation Log: 20 — M4 Public Guest Invitation Resolve

## Status

M4 Public Guest Invitation Resolve — **IN REVIEW**

M1, M2A.1, M2A.2, M2B.1, M2B.2, M2B.3, and M3 are approved. This checkpoint implements only D-INV-001 public invitation resolve and the Guest Web shell. RSVP mutation, VietQR, Finance, Media upload, push/email/SMS, and organizer Invitation changes were not started.

## A. D-INV-001 Endpoint

Added the Supabase Edge Function `invitation-resolve` as the public endpoint implementation for the approved `POST /v1/invitation/resolve` contract.

The Edge Function:

* accepts only `POST` plus CORS `OPTIONS`;
* accepts only a raw invitation token supplied from the Guest Web URL fragment;
* validates token shape before calling the database;
* never logs the token;
* returns generic public errors;
* sets `Cache-Control: no-store`, `Referrer-Policy: no-referrer`, and `X-Content-Type-Options: nosniff`;
* uses an explicit origin allowlist from `GUEST_WEB_ALLOWED_ORIGINS`.

Local Supabase routing exposes the function as `/functions/v1/invitation-resolve`.

The canonical product/API contract remains `POST /v1/invitation/resolve`. Production canonical-route proxy mapping to that path has not been deployed or verified in this local checkpoint.

## B. Token Handling

The Guest Web shell only supports the approved fragment shape:

```text
#/invite/<raw_token>
```

The browser extracts the token before rendering invitation content, stores it only in `sessionStorage` for same-tab refresh, and scrubs the fragment using `history.replaceState`. It does not place the token in query strings, normal path segments, local storage, logs, analytics, or persisted app state.

The raw token remains the M3 format:

* 32 random bytes;
* base64url without padding;
* 43 characters;
* opaque, with no embedded resource identity;
* SHA-256 lookup against `invitation_credentials.token_hash`.

## C. Resolve Lookup

Added `internal.resolve_public_invitation(text, varchar, integer)` as the hidden server-only database resolve primitive. The function is `SECURITY DEFINER`, owned by `trusted_function_owner`, and is not directly executable by `PUBLIC`, `anon`, `authenticated`, or `service_role`.

This resolves `IMPL-CONFLICT-012`: the Class-D DB helper is not an Organizer Class-C client API and is no longer placed in `api_v1`.

This also resolves `IMPL-CONFLICT-013`: `internal` is no longer included in local `[api].schemas` and remains hidden from ordinary PostgREST/Data API schema profiles. Because the Supabase Edge runtime uses PostgREST RPC for this local implementation, Batch-08 adds a narrow service-only bridge: `edge_api.resolve_public_invitation(text, varchar, integer)`. The bridge is provider plumbing only, calls `internal.resolve_public_invitation`, grants EXECUTE only to `service_role`, and does not expand Organizer Class-C or public Class-D inventories.

Resolve uses:

* `extensions.digest(raw_token, 'sha256')`;
* active credential rows only;
* `revoked_at IS NULL`;
* Invitation status `READY` or `MARKED_AS_SENT`;
* Wedding status `ACTIVE`.

`DRAFT`, revoked, malformed, unknown, ARCHIVED, and DELETING links all return the same public unavailable error.

Note: Architecture 07 previously described archived Wedding links as read-only. The M4 checkpoint explicitly requires ARCHIVED and DELETING guest links to be unavailable, so this implementation follows the newer checkpoint authority.

## D. Sanitized DTO

The public DTO contains only Guest-safe content:

* Wedding display name;
* Wedding timezone;
* RSVP cutoff date;
* public contact phone/email;
* Party display name;
* Party invited count;
* Invitation status;
* `can_submit_rsvp = false`;
* active targeted Event display facts.

The DTO does not expose:

* `wedding_id`;
* `invitation_id`;
* `invitation_party_id`;
* `credential_id`;
* `token_hash`;
* raw token;
* membership or organizer data;
* Guest table rows;
* private planning or finance data.

## E. Event Targeting / Readiness

Public resolve includes only Events explicitly targeted by the Invitation and currently `ACTIVE`.

Event readiness is represented without enabling RSVP:

* Exact Date Events are marked `rsvp_ready = true`;
* Expected Month Events are marked `rsvp_ready = false`;
* REMOVED Events are excluded.

The Guest Web shell labels Exact Date Events as future RSVP-ready and Expected Month Events as Save-the-Date / information only. It does not invent dates and does not submit RSVP.

## F. View Tracking

Resolve updates `first_viewed_at` on first successful resolve and `last_viewed_at` on every successful resolve. Tracking is best-effort and never blocks content resolution.

Batch-08 changes `fn_invitation_lifecycle_guard` to `SECURITY INVOKER` so the existing trusted-authority check sees the actual mutating execution role. Ordinary clients still cannot write view-tracking columns because those columns are not granted to `authenticated`; Class-D view tracking is performed only through the trusted database function.

## G. DEC-B-004 Abuse Control

DEC-B-004 is closed for MVP with a DB-backed fixed-window rate limiter:

* limiter table: `private.class_d_rate_limits`;
* key: non-reversible Edge-derived network key;
* Edge input: `D-INV-001:ip:<sha256(D-INV-001:<network-signal>)>`;
* window: 60 seconds;
* default threshold: 30 requests per window;
* configurable threshold: `CLASS_D_RESOLVE_RATE_LIMIT`;
* public failure: `RATE_LIMITED`;
* response header: `Retry-After`.

Network signal authority:

* preferred runtime header: `cf-connecting-ip`, treated as trustworthy only when supplied/overwritten by the hosting proxy;
* fallback runtime header: first entry in `x-forwarded-for`, treated as trustworthy only within the Supabase/Kong/proxy model where the proxy controls that header chain;
* local or unknown runtime fallback: `unknown-network`.

The implementation does not claim a reliable client IP when provider metadata is absent or when a direct local request can spoof headers. In that case, the deterministic fallback safely groups requests rather than inventing confidence.

The limiter does not persist raw invitation tokens, raw credential hashes, auth secrets, or raw IP/network signals. It is intentionally simple and free-tier friendly. It is not a bot-proof WAF and does not implement long temporary bans.

The limiter fails closed at the public boundary: if the internal RPC or limiter infrastructure fails, the Edge Function returns a generic temporary error rather than bypassing throttling and resolving Invitation content.

Retention:

* each trusted limiter execution opportunistically deletes up to 100 expired rows;
* expiration threshold is ten fixed windows, currently about 10 minutes for the 60-second window;
* no cron, scheduler, or distributed background job is introduced for MVP.

`IMPL-GAP-006` is resolved by the documented authority model, persistence inventory, grant matrix, retention model, and direct negative tests.

Data API exposure:

* pre-fix local `[api].schemas`: `public`, `api_v1`, `internal`;
* final local `[api].schemas`: `public`, `api_v1`, `edge_api`;
* repository staging config: no staging Supabase exposure config exists in this repository, so staging exposed schemas are not verifiable from repo evidence;
* hidden WeddingOS schemas: `internal`, `security`, `private`;
* provider bridge schema: `edge_api`, service-only, documented under `IMPL-AMEND-002`.

## H. Guest Web Shell

Added a static React/Vite Guest Web app in `guest_web/`.

The shell supports:

* token fragment bootstrap;
* URL scrubbing;
* resolve request;
* loading, invalid, rate-limited, temporary-error, and valid states;
* public invitation rendering;
* Event readiness messaging;
* disabled RSVP placeholder;
* safe contact display;
* mobile-first responsive layout.

No Guest account, RSVP mutation, RSVP form submission, payment/VietQR, or media rendering was implemented.

## I. CORS / Headers

The Edge Function uses explicit allowed origins. Defaults are local development origins:

* `http://localhost:5173`;
* `http://127.0.0.1:5173`.

Production must provide the deployed Guest Web origin through `GUEST_WEB_ALLOWED_ORIGINS`. No wildcard origin is emitted.

## J. Security / RLS Result

Database tests verify:

* `api_v1.resolve_public_invitation` does not exist;
* `internal`, `security`, and `private` have no anon/authenticated/service_role schema usage;
* `service_role` cannot directly execute `internal.resolve_public_invitation`;
* only `service_role` can execute `edge_api.resolve_public_invitation`;
* anon cannot directly invoke the Class-D DB helper;
* authenticated organizer cannot directly invoke the Class-D DB helper;
* authenticated outsider cannot directly invoke the Class-D DB helper;
* anon cannot select credential rows;
* anon cannot select Invitation rows;
* anon cannot select InvitationParty rows;
* anon cannot select Guest rows;
* anon cannot select WeddingEvent rows;
* anon cannot select WeddingMember rows;
* anon/authenticated cannot access or reset limiter persistence;
* resolve returns only the sanitized DTO;
* unavailable token cases are enumeration-resistant at the public contract level.

`invitation_credentials` remains inaccessible to ordinary clients. Public resolve uses the service-role Edge boundary plus the trusted database function.

## K. Guest-Link Expiration Behavior

M4 implements only lifecycle/status invalidation already approved by the current data model:

* revoked or inactive credential: unavailable;
* DRAFT Invitation: unavailable;
* ARCHIVED Wedding: unavailable;
* DELETING Wedding: unavailable.

No new time-based invitation expiration field or lifecycle state was invented.

## L. Tests / Verification

Database:

* `npx supabase db reset` — PASS during implementation;
* `npx supabase test db` — PASS;
* files: 8;
* assertions: 306.

Guest Web:

* `npm test` — PASS;
* `npm run lint` — PASS;
* `npm run build` — PASS;
* measured build time: 2582.61 ms.

The measured 2582.61 ms is the local npm production build duration, not a 4G page-load measurement. The Guest Web `<3s on 4G` performance requirement remains an NFR target and is not yet verified by staging or real-network measurement.

Edge Function:

* direct `deno test` could not run in this environment because the `deno` executable is not installed;
* `npx supabase functions serve invitation-resolve --no-verify-jwt` started successfully using `supabase-edge-runtime-1.74.3`;
* malformed-token smoke request returned `404` with `INVITATION_UNAVAILABLE`, `Cache-Control: no-store`, and `Referrer-Policy: no-referrer`.

The local Supabase proxy injected local CORS behavior around the smoke response. The function source itself emits only configured explicit origins and no wildcard.

Flutter regression:

* `flutter test` — PASS, 14 tests;
* `flutter analyze` — 0 errors, 0 warnings, 191 existing info-level diagnostics.

## M. Token Leak Audit

Audit findings:

* no production `console.*` logging in Guest Web or the Edge Function;
* no production `localStorage` token use;
* `sessionStorage` is used only for same-tab token continuity;
* test-only raw tokens are synthetic fixtures;
* no raw token is returned by the database resolve DTO;
* no raw token or IP address is persisted by the Class-D rate limiter.

## N. Defects / Fixes

Implementation-time fixes:

* changed the M3 lifecycle trigger from `SECURITY DEFINER` to `SECURITY INVOKER` so trusted view tracking can be distinguished from ordinary client writes by `current_user`;
* moved the Class-D implementation from `api_v1` to hidden `internal`;
* removed `internal` from local PostgREST exposed schemas;
* added narrow `edge_api.resolve_public_invitation` service-only provider bridge;
* added bounded opportunistic cleanup for expired rate-limit rows;
* aligned ARCHIVED guest-link behavior to the M4 checkpoint brief;
* kept malformed and unknown token failures generic.

## O. IMPL Gaps / Conflicts

`IMPL-CONFLICT-012` — Class-D server helper placed in organizer `api_v1` schema — **RESOLVED**.

Resolution: moved the implementation to hidden `internal.resolve_public_invitation`, kept client roles denied, and updated Edge to call the narrow `edge_api.resolve_public_invitation` service-only bridge through PostgREST profile headers. This does not expand the approved 31 Organizer Class-C client-callable surfaces.

`IMPL-CONFLICT-013` — Class-D helper required PostgREST access to hidden `internal` schema — **RESOLVED**.

Resolution: removed `internal` from local `[api].schemas`, removed direct service-role schema/function access to `internal`, and added the narrow `edge_api.resolve_public_invitation` bridge for the Edge Function's provider-compatible PostgREST RPC call. The hidden implementation remains in `internal`.

`IMPL-GAP-006` — DEC-B-004 limiter authority/persistence evidence — **RESOLVED**.

Evidence is recorded in Sections G and J and covered by Batch-08 tests.

DEC-B-004 is resolved by the fixed-window Class-D rate limiter documented above.

`IMPL-AMEND-001` — Class-D rate limiter technical persistence — **RESOLVED / RECORDED**.

Batch-08 introduces `private.class_d_rate_limits` as technical infrastructure only. It does not change the approved 17 business-table inventory and does not become a Wedding domain aggregate.

Persistence inventory:

* schema: `private`;
* table: `class_d_rate_limits`;
* columns: `limiter_key`, `window_start`, `request_count`, `updated_at`;
* primary key: `limiter_key`;
* index: `idx_class_d_rate_limits_window_start`;
* owner: `trusted_function_owner`;
* write authority: trusted limiter function under `trusted_function_owner`;
* read authority: trusted owner/test owner only, no direct client access;
* stored identifiers: non-reversible limiter keys such as `D-INV-001:ip:<sha256>`;
* retention: bounded opportunistic cleanup during limiter execution.

`IMPL-AMEND-002` — Class-D service-only PostgREST bridge — **RESOLVED / RECORDED**.

Bridge inventory:

* schema: `edge_api`;
* function: `edge_api.resolve_public_invitation(text, varchar, integer)`;
* reason: Supabase Edge local/provider runtime uses PostgREST RPC for database function invocation, while `internal` must remain hidden;
* implementation: `SECURITY DEFINER` wrapper owned by `trusted_function_owner`;
* behavior: calls only `internal.resolve_public_invitation`;
* execute authority: `service_role` only;
* denied: `PUBLIC`, `anon`, and `authenticated`;
* inventory impact: does not expand the approved 31 Organizer Class-C client-callable surfaces and is not a public Class-D route.

## P. Remaining Blockers

No known implementation blocker remains for the M4 scope after final regression, commit, and push gates pass.

Future work remains outside this checkpoint:

* D-RSV-001 RSVP mutation;
* Guest Web RSVP form;
* VietQR / Finance;
* Media upload/rendering;
* push/email/SMS sending.
