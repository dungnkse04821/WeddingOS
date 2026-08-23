# M2A.2 — Event Date/Precision Change + Event Removal Impact Review

**Status:** COMPLETE / APPROVED  
**Milestone:** M2A.2  
**Depends on:** M2A.1 (Planning Foundation — APPROVED)  
**Date completed:** 2026-08-22

---

## Overview

M2A.2 implements the two event-level trusted operations:

- **TOP-EVT-002:** Preview + Commit Event Date/Precision Change
- **TOP-EVT-003:** Preview + Commit Event Removal (with cascading task/budget/invitation impact)

All final closure issues from two review rounds have been resolved.

---

## Resolution Log

### IMPL-CONFLICT-004: USER_ABSOLUTE Tasks Fixed (Resolved)

**Issue:** `commit_event_date_change` had a `p_batch_action_c = 'SHIFT'` path that allowed
CLIENT-controlled shifting of `USER_ABSOLUTE` tasks. Flutter UI showed radio buttons for this.

**Resolution:**
- Removed `p_batch_action_c` parameter from `commit_event_date_change` entirely.
- New signature: `(uuid, date, integer, integer, text)`.
- Step 6 (SHIFT block) deleted from the function body.
- `USER_ABSOLUTE` tasks excluded from the EVT-002 impact fingerprint scope.
- `preview_event_date_change` now returns `absolute_tasks_unchanged_count` (integer, informational)
  instead of `review_tasks` (client-actionable list).
- Flutter `event_date_change_preview_screen.dart`: removed `_batchActionC`, removed radio buttons,
  added read-only `_buildAbsoluteTasksInfo()` informational card.

### IMPL-CONFLICT-005: Server-Authoritative Event Removal (Resolved)

**Issue:** `commit_event_removal` accepted `p_explicit_choices jsonb` allowing the client to
override which tasks were deleted vs preserved. Flutter showed per-task checkboxes.

**Resolution:**
- Removed `p_explicit_choices` parameter from `commit_event_removal` entirely.
- New signature: `(uuid, text)`.
- Server now unconditionally deletes ALL untouched active `SYSTEM_TEMPLATE`/`RECOMMENDATION` tasks.
- All other tasks (user-created, user-modified, completed) are unconditionally preserved + detached.
- Removed cross-wedding task reference validation (no longer needed without client choices).
- Flutter `event_removal_preview_screen.dart`: removed `_tasksToDelete`/`_tasksToPreserve` sets,
  replaced `CheckboxListTile` items with read-only icon list.

### IMPL-GAP-003: BudgetItem + Invitation Targeting Behavior (Resolved)

**Budget Items:**
- `commit_event_removal` already correctly unlinks BudgetItems (`UPDATE ... SET wedding_event_id = NULL`).
- pgTAP test section 7 verifies: record preserved (count=1), `wedding_event_id = NULL` after removal.

**Invitation Targeting:**
- Previous implementation did a hard `DELETE FROM invitation_event_targetings` (incorrect).
- Fixed to: `UPDATE invitation_event_targetings SET is_active = false` (soft-deactivate).
- This preserves historical RSVP data for reference while hiding the targeting from public Class D API.
- pgTAP test section 8 verifies: record preserved (count=1), `is_active = false` after removal.

### Post-Commit Retry Idempotency (Resolved)

**EVT-002:** Retry guard: if `current_state == target_state`, returns `replayed = true` immediately.
- pgTAP section 4 tests verify: replayed=true on second commit, relative task not double-shifted.

**EVT-003:** Retry guard: if event `lifecycle_status = 'REMOVED'`, returns `replayed = true` immediately.
- pgTAP section 10 tests verify: replayed=true on retry, task count stable (no extra deletions).

---

## Approved Architecture Invariants Enforced

| Transition | USER_ABSOLUTE | SYSTEM/USER_RELATIVE | NO_DEADLINE | COMPLETED |
|---|---|---|---|---|
| Exact → Exact | Unchanged (calendar-fixed) | Recalculated | Unchanged | Preserved (history) |
| Exact → Month | Unchanged (calendar-fixed) | resolved_deadline_at = NULL | Unchanged | Preserved (history) |
| Month → Exact | Unchanged (calendar-fixed) | Recalculated | Unchanged | Preserved (history) |
| Month → Month | Unchanged (calendar-fixed) | remains NULL | Unchanged | Preserved (history) |

All 4 transitions verified by pgTAP tests 7, 12, 15, and 18.

---

## API Surface

### `api_v1.preview_event_date_change(uuid, date, integer, integer)`

Returns:
- `impact_fingerprint` — MD5 over event state + relative tasks only
- `recalculated_tasks` — active relative tasks with new resolved dates (Exact target)
- `preserved_tasks` — completed tasks (informational, untouched)
- `unresolved_tasks` — active relative tasks losing resolved dates (Month target)
- `absolute_tasks_unchanged_count` — integer count of USER_ABSOLUTE tasks (informational)
- `current_precision`, `target_precision`

### `api_v1.commit_event_date_change(uuid, date, integer, integer, text)`

- Fingerprint check → STALE_IMPACT (40001) if stale
- Retry guard: returns `replayed=true` if target state already applied
- Cascades to SYSTEM_RELATIVE + USER_RELATIVE tasks only
- USER_ABSOLUTE and NO_DEADLINE: never touched

### `api_v1.preview_event_removal(uuid)`

Returns:
- `impact_fingerprint`
- `deletion_candidates` — server-classified (SYSTEM_TEMPLATE/RECOMMENDATION, untouched, active)
- `preservation_tasks` — server-classified (user/modified/completed)
- `budget_items_count`, `invitations_count` — informational
- `blocking_invariants` — e.g. `FINAL_MAIN_EVENT_INVARIANT`

### `api_v1.commit_event_removal(uuid, text)`

- Main Event invariant enforced
- Fingerprint check → STALE_IMPACT (40001) if stale
- Retry guard: `REMOVED` event → `replayed=true` immediately, no cascades
- Deletes deletion candidates unconditionally (server-authoritative)
- Detaches + converts preserved tasks per §06-trusted-ops §D rules
- BudgetItems: `wedding_event_id = NULL` (preserved)
- Invitation targetings: `is_active = false` (soft-deactivated, RSVP history preserved)

---

## Test Coverage

**File:** `supabase/tests/database_verification_batch_03.test.sql`  
**Assertions:** 40 (plan(40))

| Section | Tests |
|---|---|
| 1. Direct client mutation blocked | 1 |
| 2. EVT-002 transition matrix (Exact↔Month) | 14 |
| 2B. Month→Month USER_ABSOLUTE invariant | 3 |
| 3. Reopen completed task | 1 |
| 4. EVT-002 post-commit retry idempotency | 3 |
| 5. Stale fingerprint detection | 1 |
| 6. EVT-003 removal + invariants | 8 |
| 7. BudgetItem preserved | 2 |
| 8. Invitation soft-deactivated | 2 |
| 9. Month-precision NO_DEADLINE | 1 |
| 10. EVT-003 post-commit retry | 2 |
| 11. RLS tenant isolation | 2 |

**Total across all 3 files:** 114 assertions. All pass.

---

## Flutter Changes

- `event_date_change_preview_screen.dart`: No radio buttons. Shows informational absolute task count badge.
- `event_removal_preview_screen.dart`: No checkboxes. Read-only deletion candidate list (delete icons).
- `supabase_service.dart`: Updated RPC signatures to match new function signatures.
- `flutter analyze`: 0 errors, 137 pre-existing info warnings (withOpacity deprecations).

---

## Files Modified

| File | Change |
|---|---|
| `supabase/migrations/00000000000003_batch_03.sql` | Full rewrite of all 4 RPCs |
| `supabase/tests/database_verification_batch_03.test.sql` | plan(40), 40 assertions |
| `organizer_app/lib/services/supabase_service.dart` | Removed batchActionC, deleteTasks, preserveTasks |
| `organizer_app/lib/screens/event_date_change_preview_screen.dart` | Removed _batchActionC, radio buttons |
| `organizer_app/lib/screens/event_removal_preview_screen.dart` | Removed checkboxes |
