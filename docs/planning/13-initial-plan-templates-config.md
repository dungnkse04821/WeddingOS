# Decision Gate Closure — DEC-B-001: Initial Plan Templates Configuration

**Decision Status**: CLOSED & APPROVED.

---

## 1. Context and Architectural Choice

Under `DEC-B-001`, the persistent database table `internal.plan_template_tasks` is removed. To comply with the architecture guideline of a trusted-side, server-accessible, and version-controlled configuration, templates are embedded directly inside the PL/pgSQL RPC function `api_v1.generate_initial_plan`.

### Design Rationale:
1. **No Client Mutability**: The config resides entirely within the source code of the database migration. Clients have no insert/update/delete grants on functions, only execution context.
2. **Version Control**: Configuration changes are managed sequentially through standard Git migration scripts (such as `00000000000002_batch_02.sql`), ensuring strict schema versioning.
3. **Zero DB Storage Cost**: Eliminates the overhead of maintaining configuration tables in the database.
4. **Fast Generation**: Eliminates table joins and disk IO when fetching templates. Processing is done purely in memory using PostgreSQL native JSONB indexing.

---

## 2. Configuration Schema and Format

Statically defined as a `jsonb` variable containing a dictionary of cultural contexts:

```json
{
  "CULTURAL_CONTEXT_KEY": {
    "events": [
      {
        "name": "Suggested Event Name",
        "date_offset": -14
      }
    ],
    "tasks": [
      {
        "name": "Suggested Task Name",
        "date_offset": -30,
        "deadline_intent": "SYSTEM_RELATIVE",
        "side": "COMMON",
        "link_event": "MAIN_EVENT"
      }
    ]
  }
}
```

### Fields and Properties:
- **`version`**: Tracked via Git migration history.
- **`cultural_context`**: Matches target wedding workspace cultural context (`VIETNAMESE`, `WESTERN`, `TUY_CHON`).
- **`events` list**: Specifies suggested events to construct relative to the main event.
  - `name`: Unique identifier within the wedding workspace.
  - `date_offset`: Relative offset in days (calculated as `main_event.exact_date + date_offset`).
- **`tasks` list**: Specifies sugered tasks to construct.
  - `name`: Display name of the step.
  - `date_offset`: Relative offset in days.
  - `deadline_intent`: Always `SYSTEM_RELATIVE` for templates.
  - `side`: Common/shared or side-specific (`COMMON`, `BRIDE_SIDE`, `GROOM_SIDE`).
  - `link_event`: Either `'MAIN_EVENT'` or the name of a suggested event defined in the same template.

---

## 3. Server-Side Execution Mechanics

During execution of `api_v1.generate_initial_plan`:
1. **Concurrency Lock**: Locks the wedding workspace row (`FOR UPDATE`) to serialize concurrent execution attempts.
2. **Main Event Validation**: Asserts that an active Main Event exists. If not, raises `MAIN_EVENT_REQUIRED` (SQLSTATE `45000`).
3. **Suggested Events Insertion**: Loops through the config `events` list, inserting events dynamically relative to the main event (copying the date precision or applying the exact date offset). Event names are mapped to newly generated UUIDs in a session-isolated temporary table.
4. **Suggested Tasks Insertion**: Loops through the config `tasks` list, looking up `link_event` in the local mapping to obtain the UUID, inserting tasks with `task_source = 'SYSTEM_TEMPLATE'`.
5. **Durable Marker**: Updates `initial_plan_generated_at` to the current timestamp.
6. **Replay Semantics**: If the marker is already non-null, returns the current authoritative planning tasks state from the database without reconstructing or duplicating templates.

---

## 4. Test Strategy

Verified using pgTAP integration tests:
1. Prove no table `internal.plan_template_tasks` exists.
2. Verify that generating the plan for the `VIETNAMESE` context creates exactly 7 tasks and 2 suggested events, correctly linking relative tasks.
3. Verify that replaying the generation yields identical tasks without duplicating rows.
4. Verify that client-side direct update of event dates is blocked.
