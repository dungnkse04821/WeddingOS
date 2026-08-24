# M5: Finance Core

**Status:** INCOMPLETE / NEEDS FIXES (August 24, 2026)
**Epic:** STORY-08-01 Finance Module Core

## Overview
This phase delivers the core infrastructure and initial UI for the Finance module, ensuring precision in financial transactions and strictly adhering to the agreed architecture.

## Deliverables
- `budget_items`, `installments`, `payments`, `refunds` tables with RLS and numeric(15,2) constraints.
- `public.finance_summaries` VIEW with `security_invoker=true` replacing the unauthorized RPC.
- 8 trusted operations (FIN-001 through FIN-007) with strict delete guards.
- Comprehensive Flutter UI for Finance Management (Overview, Budget Items, Installments, Payments, Refunds) - **Note: Currently visual scaffolding only. Requires backend wiring.**
- Database verification tests (389 assertions) covering CUD constraints, idempotent retries, and precision edge cases.

## Resolution of Open Conflicts
- **IMPL-CONFLICT-014**: Resolved. BudgetItem hard deletes are permitted ONLY when there are no associated payments, refunds, or installments. Checked securely via Postgres triggers.
- **IMPL-CONFLICT-016**: Resolved. Replaced unauthorized `api_v1.get_finance_summary` with RLS-compliant `public.finance_summaries` view.

## Verification
- Postgres `pgTAP` tests pass 100%.
- `flutter analyze` reports 0 errors.
- `flutter test` passes.
- Guest web regression (`npm test`, `npm run build`) passes.
