# M2A.1 — Planning Foundation & Initial Wedding Plan

**Status**: IN REVIEW (Closure Report Stage)
**Phase Gate**: M2A.1 Implementation Close

This document records the closure decisions, technical details, conflict resolutions, and verification reports for the first part of the Planning phase.

---

## 1. Conflict Resolutions

### A. RESOLVED: IMPL-CONFLICT-001 (Template DB Table Removal)
- **Problem**: Persistent table `internal.plan_template_tasks` was introduced, which violates the approved Physical Design table list.
- **Resolution**: Removed `internal.plan_template_tasks` table and dropped `internal` schema references. Embedded the static configuration templates directly as a version-controlled, trusted-side local JSONB structure inside the `api_v1.generate_initial_plan` PL/pgSQL function. Checked with pgTAP tests that no database template table remains.

### B. RESOLVED: IMPL-CONFLICT-002 (Task Provenance Creation/Update)
- **Problem**: Direct Class-B updates to tasks were resetting `task_source` or failing to preserve original `SYSTEM_TEMPLATE` / `RECOMMENDATION` sources.
- **Resolution**: Fixed the provenance trigger `fn_tasks_provenance_protection` to:
  - Direct Class-B inserts: Omitted fields default `task_source` to `USER` and `is_user_modified` to `false`. Direct writes to these fields are denied at SQL compile time by Column-level Grants.
  - Direct updates: `task_source` preserves the original source. If any core fields (name, offset, side, assignee, linked event) are edited, `is_user_modified` flips to `true` and cannot be reset back to `false` by the client.

### C. RESOLVED: IMPL-CONFLICT-003 (Event Date Cascade Restriction)
- **Problem**: Direct Class-B Event UPDATE mutations on `exact_date` could bypass future M2A.2 `TOP-EVT-002` Preview/Commit boundaries while triggering recalculation cascades.
- **Resolution**: Disabled direct update path for `exact_date`, `expected_year`, and `expected_month` on `public.wedding_events` by omitting them from the client `GRANT UPDATE` columns list. The database trigger still correctly handles low-level cascade recalculations when updated via future trusted server paths.

---

## 2. Verification Results

### A. Database layer pgTAP Tests
- Overwrote the test suite in `database_verification_batch_02.test.sql` to verify 38 separate assertions.
- **Assertion Coverage**:
  - Uniqueness and XOR date constraints (4 tests).
  - Assignee same-wedding active checks (3 tests).
  - Removal of database template table (1 test).
  - Client column grant blocks and provenance defaults (8 tests).
  - Date cascade logic and completed task snap freeze (5 tests).
  - Initial plan generation, concurrency safety, suggested events insertion, and replayed current-state replay semantics (10 tests).
  - RLS tenant isolation (3 tests).
  - Class-B mutation access blocks (4 tests).
- **Execution Output**:
  ```
  Connecting to local database...
  All tests successful.
  Files=2, Tests=69, Result: PASS
  ```

### B. Frontend static analysis (Flutter)
- Ran `flutter analyze` ensuring zero compiler errors exist in `task_model.dart`, `planning_screen.dart`, `task_detail_screen.dart`, or `home_screen.dart`.
- Fixed the Expected Month deadline rendering UI to print the relative offset and expected month details without displaying fake placeholder dates.

---

## 3. Reference Implementation Commit
- **Staged Files**: Models, screens, services, migration file, pgTAP test suite, and decision docs.
- **Commit ID**: `4197179` (Pushed to branch `main`).
