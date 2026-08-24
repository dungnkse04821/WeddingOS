# M5 Finance Core Checkpoint

1. **Current milestone + exact status**:
   M5 Finance Core - COMPLETE / READY FOR PO APPROVAL.

2. **Implemented scope**:
   - DB Finance Core schema (budget_items, installments, payments, refunds).
   - `public.finance_summaries` VIEW with `security_invoker = true` and `WHERE security.is_wedding_owner(w.id)` to block collaborator reads.
   - exactly 8 `api_v1` Trusted Operations (FIN-001 through FIN-007).
   - Direct Class-B Supabase table operations (create, update, delete on `budget_items` and `installments`) protected by RLS and triggers, not using `api_v1` RPCs.
   - Strict `delete guards` blocking deletions if history exists.
   - Idempotency + Durable Receipts for FIN-001/004.
   - Fully wired Flutter UI integration with backend services.

3. **Explicitly NOT implemented scope**:
   - Vendor, Media, Day-of modules.
   - TOP-INV-002.
   - Bank sync.
   - Dynamic VietQR reconciliation.

4. **Latest migration + files/modules changed**:
   - Migration: `00000000000011_batch_11.sql`.
   - Flutter screens: `organizer_app/lib/screens/...`.
   - DB Tests: `database_verification_batch_11.test.sql`.

5. **Final Finance schema**:
   - `budget_items`: numeric(15,2) for `estimated_cost`, `confirmed_cost`.
   - `installments`: numeric(15,2) for `amount`.
   - `payments` / `refunds`: numeric(15,2) for `amount`, immutable after insert/void.

6. **Exact 8 api_v1 Finance surfaces**:
   - `api_v1.create_payment` (FIN-001)
   - `api_v1.edit_payment` (FIN-002)
   - `api_v1.void_payment` (FIN-003)
   - `api_v1.create_refund` (FIN-004)
   - `api_v1.edit_refund` (FIN-005)
   - `api_v1.void_refund` (FIN-006)
   - `api_v1.preview_installment_compound` (FIN-007 Preview)
   - `api_v1.commit_installment_compound` (FIN-007 Commit)

7. **Class-B direct operations**:
   - `createBudgetItem`, `updateBudgetItem`, `deleteBudgetItem`, `createInstallment`, `updateInstallment`, `deleteInstallment` are implemented as direct Supabase table queries, not extra RPCs.

8. **finance_summaries security**:
   - `CREATE VIEW public.finance_summaries WITH (security_invoker = true) ... WHERE security.is_wedding_owner(w.id)`.
   - OWNER sees their own wedding summaries.
   - COLLABORATOR sees 0 rows.
   - outsider sees 0 rows.
   - anon gets permission denied / 42501 as design.

9. **receipt semantics**:
   - Client generates a UUIDv4 `request_id` once in the form screen lifecycle (`initState`) and retains it across logical retries of the same transaction. New form screens generate new request IDs.

10. **FIN-007 semantics**:
    - Preview calls `api_v1.preview_installment_compound` and computes an `impact_fingerprint`. Commit calls `api_v1.commit_installment_compound` with the fingerprint. If the fingerprint is stale, the commit fails.

11. **delete guards**:
    - Triggers block BudgetItem deletes if installments, payments, or refunds exist. Triggers block Installment deletes if payments exist.

12. **decimal handling**:
    - All authoritative finance calculations remain server-side.
    - Flutter UI/Service layers map all monetary figures to `String` representations to prevent precision loss.

13. **DB evidence**:
    - `npx supabase test db`: 11 files, 393 assertions. 100% PASS.

14. **Flutter evidence**:
    - `flutter test`: 15 tests, 100% PASS.
    - `flutter analyze`: 0 ERROR, 0 WARNING, 200 INFO.

15. **Guest Web evidence**:
    - `npm test`: 2 files, 8 tests, 100% PASS.
    - `npm run lint`: 100% PASS.
    - `npm run build`: 100% PASS.

16. **Git**:
    - Branch: `main`.
    - implementation commit: `519600b` (Implementation).
    - closure commit: `5ec7f54` (Closure).
    - messages: `chore(finance): deliver M5 Finance Core Flutter UX`
    - push result: Pushed to origin/main.

17. **working tree**:
    - Clean (or final changes will be committed).

18. **next task**:
    - Proceed to M6 after PO approval.

19. **STOP boundary**:
    - STOP. Do NOT start M6.
