# WeddingOS M8 Security and NFR Hardening

Status:

- M8 overall: **IN PROGRESS**
- M8.1A Finance Contract Correctness: **COMPLETE**
- M8.1B Wedding Concurrency + DELETING Read Matrix: **COMPLETE**
- M8.1C Map Validation + Function Hygiene: **COMPLETE**

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

- Edge request/timeout/error hardening;
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
