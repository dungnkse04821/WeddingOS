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

Local Supabase routing exposes the function as `/functions/v1/invitation-resolve`; production routing should map this function to the approved `/v1/invitation/resolve` public API shape.

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

Added `api_v1.resolve_public_invitation(text, varchar, integer)` as the internal database resolve primitive. The function is `SECURITY DEFINER`, owned by `trusted_function_owner`, and executable only by `service_role`.

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

The limiter does not persist raw invitation tokens or raw IP/network signals. It is intentionally simple and free-tier friendly. It is not a bot-proof WAF and does not implement long temporary bans.

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

* anon cannot select credential rows;
* anon cannot select Invitation rows;
* anon cannot select InvitationParty rows;
* anon cannot select Guest rows;
* anon cannot select WeddingEvent rows;
* anon cannot select WeddingMember rows;
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
* assertions: 270.

Guest Web:

* `npm test` — PASS;
* `npm run lint` — PASS;
* `npm run build` — PASS;
* measured build time: 2582.61 ms.

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
* aligned ARCHIVED guest-link behavior to the M4 checkpoint brief;
* kept malformed and unknown token failures generic.

## O. IMPL Gaps / Conflicts

No new IMPL conflict was recorded.

DEC-B-004 is resolved by the fixed-window Class-D rate limiter documented above.

## P. Remaining Blockers

No known implementation blocker remains for the M4 scope after final regression, commit, and push gates pass.

Future work remains outside this checkpoint:

* D-RSV-001 RSVP mutation;
* Guest Web RSVP form;
* VietQR / Finance;
* Media upload/rendering;
* push/email/SMS sending.
