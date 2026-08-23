# Implementation Log: 19 — M3 Invitation / Credential Foundation

## Status

M3 Invitation / Credential Foundation — **IN REVIEW**

M1, M2A.1, M2A.2, M2B.1, M2B.2, and M2B.3 remain approved. This checkpoint implements only the approved organizer-side Invitation and credential foundation scope. Class D public resolve, Guest Web, RSVP, VietQR, Finance, and Media were not started.

## A. Invitation Schema Implementation

Added Batch-07 migration with the approved physical tables:

* `public.invitations`
* `public.invitation_event_targetings`
* `public.invitation_credentials`

`invitations.status` uses only `DRAFT`, `READY`, and `MARKED_AS_SENT`. One `InvitationParty` can have at most one `Invitation` through `uq_invitation_party`.

## B. Targeting Implementation

`invitation_event_targetings` uses the approved flat M:N join with `wedding_id`, `invitation_id`, and `wedding_event_id`.

Same-Wedding integrity is enforced through composite foreign keys. A trigger rejects target Events unless they are `ACTIVE`; `REMOVED` Events cannot be newly targeted.

## C. Invitation Lifecycle

The database trigger `public.fn_invitation_lifecycle_guard` enforces:

* create as `DRAFT`;
* `DRAFT -> READY`;
* `READY -> MARKED_AS_SENT`;
* no backward transitions;
* no invented `REVOKED`, `DELETED`, `SENT_BY_SYSTEM`, `OPENED`, or inactive Invitation lifecycle state.

`DRAFT -> READY` revalidates the readiness rules server-side:

* valid Party exists;
* Party display name is non-blank;
* Party `invited_count > 0`;
* at least one active targeted Event exists.

Empty Parties with `invited_count > 0` are allowed.

## D. `marked_sent_at` Protection

Organizer clients receive no direct write grant for `marked_sent_at`, `first_viewed_at`, or `last_viewed_at`.

On explicit `READY -> MARKED_AS_SENT`, the DB sets `marked_sent_at` using server time. Copy/share actions in Flutter do not update Invitation status.

View tracking remains reserved for future Class D resolve.

## E. DEC-B-002 Credential Format

DEC-B-002 is closed for implementation:

* entropy: 32 cryptographically secure random bytes;
* encoding: base64url without padding;
* raw token length: 43 characters;
* token contents: opaque, no Wedding ID, Invitation ID, Guest ID, or sequence data;
* storage hash: SHA-256 over the raw token string;
* stored hash type: `bytea`;
* stored hash length: 32 bytes.

UUIDs are not used as invitation credentials.

## F. Credential Generation / Regeneration

Implemented `api_v1.regenerate_invitation_credential(uuid)` as the TOP-INV-001 trusted operation.

The function is `SECURITY DEFINER`, owned by `trusted_function_owner`, and validates:

* authenticated actor from `auth.uid()`;
* active Wedding membership;
* OWNER or COLLABORATOR role;
* Wedding lifecycle is `ACTIVE`;
* Invitation exists;
* Invitation status is `READY` or `MARKED_AS_SENT`.

The operation locks the Invitation, revokes the active credential if present, inserts one new active credential, and returns the raw token only in the RPC result.

## G. Token Hash / Raw-Token Handling

Raw tokens are never persisted in database tables, receipts, logs, or Flutter local preferences.

`invitation_credentials` stores only:

* `token_hash`;
* `is_active`;
* `created_at`;
* `revoked_at`;
* credential identity and Invitation link.

Flutter keeps the raw link only in screen memory after generation/regeneration. If the screen state is lost, the organizer must regenerate a new link.

## H. Active Credential Invariant

`uq_active_credential` enforces at most one active credential per Invitation.

Regeneration keeps old credential rows as historical inactive rows with `revoked_at` set, then creates a new active row. Final committed state contains exactly one active credential.

## I. Retry / Concurrency Behavior

TOP-INV-001 follows the approved retry-safe-new-result contract.

If a client retries after a lost response, the function may rotate again and return a newer token. It does not persist or replay raw tokens. After every successful call, exactly one credential is active.

The partial unique index is the DB-level final-state guard against two active credentials.

## J. RLS / Grant Matrix

`invitations`:

* `authenticated`: SELECT, INSERT limited to `wedding_id` and `invitation_party_id`, UPDATE limited to `status`;
* RLS: active member can read; active member of an `ACTIVE` Wedding can mutate.

`invitation_event_targetings`:

* `authenticated`: SELECT, INSERT, DELETE;
* RLS: active member can read; active member of an `ACTIVE` Wedding can mutate.

`invitation_credentials`:

* no `authenticated` or `anon` table access;
* no direct client CUD;
* TOP-INV-001 is the only implemented credential mutation surface.

OWNER and COLLABORATOR follow the approved Invitation Management matrix. Credential regeneration also allows OWNER and COLLABORATOR, as specified by Architecture 08.

## K. Archived / Deleting Behavior

ARCHIVED and DELETING Weddings reject Invitation mutation and credential generation for ordinary organizer paths. Existing read behavior follows the active-member RLS pattern already used by the project.

## L. Flutter Invitation UX

Added organizer Invitation management entry from the Directory screen.

The screen supports:

* viewing Parties and associated Invitation status;
* creating a DRAFT Invitation for an existing Party;
* selecting targeted Events;
* showing Event readiness:
  * Exact Date = RSVP-ready for future RSVP;
  * Expected Month = save-the-date / information only;
  * REMOVED = disabled and not selectable;
* saving targets;
* moving `DRAFT -> READY`;
* explicit `MARKED_AS_SENT`.

No RSVP summary or Guest Web resolve was implemented.

## M. Flutter Credential UX

Organizer can generate/regenerate a link for `READY` or `MARKED_AS_SENT` Invitations.

The warning explains that old links stop working and Invitation identity/history remains. Copying the link does not mark the Invitation as sent. Link format uses `#/invite/<raw_token>`.

## N. DB Suite / Assertion Count

Current database suite result during implementation:

* `npx supabase test db` — PASS
* Files: 7
* Assertions: 232

Batch-07 contributes 39 assertions.

## O. Credential Security Tests

Added tests for:

* raw token URL-safe structure and length;
* no resource IDs embedded in token;
* token hash length = 32 bytes;
* hash lookup foundation using SHA-256(raw token);
* wrong token no active match;
* revoked old token no active match;
* exactly one active credential after first generation, regeneration, and retry;
* anon denied;
* outsider denied;
* ARCHIVED denied;
* authenticated direct credential SELECT/INSERT/UPDATE denied;
* no TOP-INV-001 receipt payload.

## P. Clean Reset

`npx supabase db reset` passed after Batch-07 migration was added. Final checkpoint verification repeats clean reset before commit.

## Q. Flutter Tests

`flutter test` passed with 14 tests during implementation.

Added invitation model tests for:

* Expected Month save-the-date only;
* Exact Date RSVP-ready;
* REMOVED Event not active/selectable;
* lifecycle helper semantics;
* fragment link shape.

## R. Analyzer

`flutter analyze` currently reports:

* ERROR: 0
* WARNING: 0
* INFO: 191

The remaining info diagnostics are existing project analyzer debt classes. No new error or warning was introduced.

## S. Regression Result

Database regression suites M1, M2A, M2B.1, M2B.2, and M2B.3 pass with the new Batch-07 suite.

Flutter tests pass with the new M3 model coverage.

## T. Defects / Fixes

Implementation-time fixes:

* Updated the historical Batch-03 test so it seeds the real Batch-07 `invitation_event_targetings` schema instead of creating a test-only table with the same name.
* Corrected the Batch-07 pgTAP plan count to 39.
* Ensured credential internals are inspected only under test owner context while authenticated clients remain denied.
* Removed new analyzer info diagnostics introduced by the M3 Flutter additions.

## U. IMPL Gaps / Conflicts

No new IMPL conflict was recorded.

`DEC-B-002` is resolved by the 32-byte base64url token format documented above.

## V. Remaining Blockers

No implementation blocker is known for M3 scope.

Remaining future work is outside this checkpoint:

* Class D invitation resolve;
* Guest Web;
* RSVP;
* VietQR / Finance;
* Media.
