# M4.2 Public RSVP Submit

## Status

Complete. M4 Public Guest Invitation Resolve was confirmed approved by the Product Owner before this checkpoint began.

## Delivered Design

`public.rsvps` holds one current RSVP per Invitation. `public.event_responses` holds one current response per RSVP/Event pair. The data belongs to the InvitationParty through Invitation; no Guest ownership, Guest account, fake Guest, or RSVP history version is introduced.

`D-RSV-001` uses the Class-D chain:

Guest Web -> `POST /v1/invitation/rsvp` (local `/functions/v1/invitation-rsvp`) -> service-role PostgREST profile `edge_api` -> `edge_api.submit_public_rsvp` -> hidden `internal.submit_public_rsvp`.

The bridge is provider plumbing only. `PUBLIC`, `anon`, and `authenticated` have no execute privilege; only `service_role` may execute the single bridge. `internal`, `security`, and `private` remain hidden from the Data API.

## Current RSVP Semantics

* A valid repeated submit updates the same RSVP and upserts only submitted EventResponses.
* Omitted EventResponses remain unchanged; omitted RSVP optional fields remain unchanged.
* Explicit `null` clears an approved RSVP-level optional field; `[]` clears companion names.
* `ATTENDING` requires a count of at least one. `NOT_ATTENDING` requires zero. `MAYBE` is rejected.
* Exact-date ACTIVE targeted Events are accepted. Expected-Month, REMOVED, non-targeted, and cross-Wedding Events are rejected as `EVENT_NOT_AVAILABLE`.
* The Wedding-local cutoff accepts submissions through the cutoff calendar date and returns `RSVP_CLOSED` after it. A null cutoff remains editable.
* Over-capacity is accepted and returned as the non-blocking `RSVP_OVERCOUNT` warning; Party `invited_count` is never rewritten.
* Each request validates before the RSVP/EventResponse mutation, so an invalid patch cannot partially commit. Latest valid committed update wins; no receipt or optimistic-lock version is introduced.

## Public DTO And Privacy

Resolve now returns Event IDs required for event-scoped patches, current RSVP state, derived `PENDING`/`PARTIAL`/`RESPONDED` summary, warnings, and `can_submit_rsvp`. It returns no credential hash, credential ID, Wedding ID, Guest data, membership data, limiter key, raw network signal, or SQL detail.

## Abuse Control

The existing `private.class_d_rate_limits` implementation is reused with the operation-specific `D-RSV-001:ip:<sha256-network-signal>` key. The default RSVP threshold is 10 requests per 60-second fixed window, server-configured with `CLASS_D_RSVP_RATE_LIMIT`; it is intentionally separate from the Resolve namespace and not client-configurable. Raw tokens are not stored. The existing bounded expired-window cleanup and fail-closed limiter behavior apply.

## Guest Web

The form displays only RSVP-ready Exact Events, pre-fills current state, submits only changed Event patches, and keeps draft state in memory if submission fails. Expected-Month Events remain informational, cutoff makes the form read-only, and public errors are mapped to safe Vietnamese copy. No raw token is persisted outside the existing fragment-to-`sessionStorage` flow.

## Verification

`npx supabase db reset` rebuilt all migrations through Batch 09, followed by `npx supabase test db` passing 343 assertions across nine files. Guest Web tests pass (7 tests), lint is clean, and the canonical `npm run build` passes in 816 ms, emitting `guest_web/dist`.

The original `EPERM` was not a live Vite/Node lock: the stale ignored `dist` files were owned by `CodexSandboxOffline`, while the canonical build runs as the workspace owner `nguye`, which had write but not delete permission. Windows Restart Manager reported no locking process. The sandbox owner safely removed only the ignored generated `guest_web/dist` tree; the canonical build then regenerated it under the workspace owner.

Local Supabase Edge smoke used `npx supabase functions serve invitation-rsvp --no-verify-jwt` with synthetic local fixtures that were removed afterward. A malformed token returned `404 INVITATION_UNAVAILABLE` with `Cache-Control: no-store`, `Referrer-Policy: no-referrer`, and no internal detail. A valid synthetic invitation returned `200` with the authoritative current RSVP DTO. A local stack restart was required to reload the existing `edge_api` PostgREST schema exposure after a stale `406` profile response. No credential file or repository secret was created. Direct Edge unit tests are not runnable because `deno` is not installed, which is not a delivery blocker.

Flutter regression passes (14 tests); analyzer reports 0 errors, 0 warnings, and 191 existing info diagnostics. The reviewed implementation was committed as `5a4a1f2` (`m4.2: implement public rsvp submit`) and pushed to `origin/main` before this final delivery record.

## Scope Boundary

This checkpoint does not implement VietQR, Finance, Media, push/email/SMS, Guest accounts, or `TOP-INV-002` organizer manual RSVP mutation. The conceptual production route mapping for `/v1/invitation/rsvp` remains unverified until deployment.
