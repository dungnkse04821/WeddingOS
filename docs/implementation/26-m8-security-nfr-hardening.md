# WeddingOS M8 Security and NFR Hardening

Status:

- M8 overall: **IN PROGRESS**
- M8.1A Finance Contract Correctness: **COMPLETE**

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

## Remaining M8 Work

M8 remains IN PROGRESS. This slice does not close:

- TOP-WED-001 concurrency;
- DELETING read-policy clarification;
- Edge request/timeout/error hardening;
- public map-link validation;
- full security matrix/provider evidence;
- NFR benchmarks and evidence-based indexing;
- CI, staging, CSP, deployment, observability, or recovery gates;
- other P2/P3 findings in the approved M8 design.
