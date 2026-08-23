# Implementation Log: 17 - M2B.2 Guest Impact Operations Security & Retry Closure

*   **Status:** IN REVIEW
*   **Executor:** Codex
*   **Updated:** 2026-08-24

---

## A. Scope

This closure resolves only final M2B.2 security and retry review issues for:

*   `TOP-GUE-001` - Primary Group Delete.
*   `TOP-GUE-002` - Guest Party Move / Remove.
*   `TOP-GUE-003` - Guest Duplicate Merge.

No Excel Import, Invitation Credential, Guest Web, RSVP, Finance, or Media work was started.

## B. IMPL-CONFLICT-010 - Custom GUC Trusted Authority

**Issue:** `weddingos.trusted_operation = 'true'` was used as trusted-operation authority for bypassing the Guest Party transition trigger.

**Resolution:** Removed all trigger authority based on `current_setting('weddingos.trusted_operation', ...)` and removed all trusted RPC calls to `set_config('weddingos.trusted_operation', ...)`.

Trusted mutation authority now derives from PostgreSQL execution authority:

*   Approved RPCs run as `SECURITY DEFINER` functions owned by `trusted_function_owner`.
*   `trusted_function_owner` is `NOLOGIN`, `BYPASSRLS`, and narrowly granted access to the affected Guest tables.
*   The party transition trigger is `SECURITY INVOKER` and allows privileged transitions only when `current_user = 'trusted_function_owner'`.
*   Ordinary authenticated client mutation cannot self-assert this execution role.

**Status:** RESOLVED.

## C. Business Actor vs Execution Authority

Execution authority remains separate from business actor identity:

*   `current_user` identifies the privileged execution role.
*   `auth.uid()` identifies the organizer business actor.

All M2B.2 preview/commit functions that operate on existing resources validate:

*   `auth.uid()` is an active Wedding member.
*   Wedding status is `ACTIVE`.
*   same-Wedding target resources are enforced.
*   operation-specific impact fingerprints and candidate invariants are checked.

## D. Party Transition Boundary

M2B.1 direct mutation protection is retained:

*   `NULL -> Party` remains allowed through ordinary Class-B update.
*   `Party -> NULL` remains denied through ordinary Class-B update.
*   `Party A -> Party B` remains denied through ordinary Class-B update.

`TOP-GUE-002` commit can still perform approved `Party -> NULL` or `Party A -> Party B` transitions because it executes under `trusted_function_owner` after Preview/Commit validation.

## E. Negative GUC Security Test

Added explicit adversarial coverage in `database_verification_batch_05.test.sql`:

*   authenticated client sets `weddingos.trusted_operation = 'true'`;
*   direct `Party -> NULL` update is denied;
*   direct `Party A -> Party B` update is denied.

This proves the formerly used bypass value no longer carries authority.

## F. TOP-GUE-002 Positive Trusted Test

The same suite proves:

*   direct Class-B party transition is denied;
*   `api_v1.commit_guest_party_move` succeeds after valid preview/fingerprint;
*   source and target `invited_count` values remain unchanged;
*   authorized retry returns terminal success only when the current guest state already equals the requested target Party.

## G. GUC / Bypass Audit

Audit query covered:

`set_config`, `current_setting`, `weddingos.*`, `trusted_operation`, `bypass`, `skip_trigger`, `trusted=true`.

Findings:

*   Removed security-sensitive M2B.2 custom GUC authority from `supabase/migrations/00000000000005_batch_05.sql`.
*   Remaining `weddingos.trusted_operation` occurrence is only the mandatory adversarial pgTAP test.
*   Remaining `set_config` usage in database tests is limited to Supabase JWT test setup through `request.jwt.claims`.
*   Existing documentation references to "bypass RLS" describe approved architecture, not a client-assertable bypass switch.
*   Existing M2A.2 MD5 stale-impact fingerprints remain outside this M2B.2 closure scope and are not treated as authorization, credentials, idempotency, or authenticity proof.

Follow-up analyzer closure confirmed no additional security-sensitive custom configuration bypasses were introduced.

## H. IMPL-CONFLICT-011 - Ambiguous Guest Merge Replay

**Issue:** `TOP-GUE-003` inferred successful replay when the secondary Guest was absent and the survivor fields matched requested values.

**Resolution:** Removed replay inference from secondary absence. Because no approved durable proof exists for `TOP-GUE-003`, an absent secondary Guest now returns `CONFLICT` instead of `replayed=true`, even if survivor fields match.

**Status:** RESOLVED.

## I. Merge Retry Tests

Added/updated tests:

*   Preview Merge A+B.
*   Commit succeeds and physically removes B.
*   Retrying the same merge returns `CONFLICT`, not `replayed=true`.
*   Constructed ambiguous state with absent unrelated secondary and matching survivor values also returns `CONFLICT`.

## J. Retry Audit

`TOP-GUE-001`:

*   Current terminal success when a target PrimaryGroup no longer exists is retained.
*   This is unambiguous under the approved taxonomy because the only final state for the operation is "group absent and guests no longer reference it"; the operation has no duplicate side-effect risk after the group row is gone.

`TOP-GUE-002`:

*   Terminal success is retained only when an authorized actor calls the operation and the current Guest row already has the requested `invitation_party_id`.
*   `invited_count` is not recalculated by the operation, so repeating it has no hidden double-counting side effect.

`TOP-GUE-003`:

*   Terminal success from absent secondary is removed.
*   Without durable proof, absence is ambiguous and fails closed with `CONFLICT`.

## K. Fingerprint Algorithm

M2B.2 `impact_fingerprint` values now use SHA-256 over deterministic, material state strings.

The fingerprint is only a stale-impact change detector. It is not a credential, authorization token, idempotency token, replay proof, or cryptographic authenticity proof.

## L. Verification

Verification commands executed:

*   `npx supabase db reset` -> PASS. All migrations `batch_00` through `batch_05` applied cleanly.
*   `npx supabase test db` -> PASS. All 5 suites passed: M1, M2A.1, M2A.2, M2B.1, M2B.2.
*   Total database assertions: 166.
*   `flutter test` -> PASS. 3 widget/smoke tests passed.
*   `flutter analyze` -> NON-ZERO because Flutter reports info-level diagnostics as issues in CLI output. Structured analyzer summary: 0 errors, 0 warnings, 188 info diagnostics.

Additional closure checks:

*   M2B.2 user-facing error paths now map backend/security failures to safe Vietnamese app messages.
*   Full GUC/bypass audit rerun after patch; no security-sensitive custom-GUC authority remains.
*   `trusted_function_owner` regression coverage added: role is `NOLOGIN`, and `authenticated`/`anon` have no role-membership path to inherit or `SET ROLE` into it.
*   No analyzer finding indicates exposure of `trusted_function_owner`, custom GUC state, trigger internals, or SQLSTATE internals from the M2B.2 user-facing screens after the safe error copy patch.

## L.1 Flutter Analyzer Closure

Analyzer environment:

*   Working directory: `D:\Dung\Project\VibeCode\WeddingOS\organizer_app`.
*   Flutter: 3.47.1 stable (`6655482ec0`, 2026-08-19).
*   Dart: 3.13.1.
*   DevTools: 2.60.0.

Analyzer configuration:

*   `organizer_app/analysis_options.yaml` still includes `package:flutter_lints/flutter.yaml`.
*   Excluded generated/platform/vendor paths remain: `build/**`, `android/**`, `ios/**`, `web/**`, `windows/**`, `macos/**`, `linux/**`.
*   No lint rule was disabled or weakened for this closure.

Analyzer discrepancy finding:

*   The earlier "clean" analyzer reports most likely meant no compiler/fatal analyzer errors, not zero Flutter analyzer issues.
*   Current Flutter/Dart SDK reports many API deprecations as info-level diagnostics, especially `withOpacity`, `DropdownButtonFormField.value`, `Radio.groupValue`, `Radio.onChanged`, and Supabase `anonKey`.
*   Before this analyzer closure, structured analysis found 0 errors, 3 warnings, and 189 info diagnostics.
*   After removing unused imports and fixing the M2B.2 correctness-related async context issue in Guest create/edit, structured analysis found 0 errors, 0 warnings, and 188 info diagnostics.

M2B.2 touched-file state:

*   M2B.2 target files have 0 errors and 0 warnings.
*   M2B.2 target files have 51 remaining info diagnostics: 48 `deprecated_member_use`, 2 `unnecessary_underscores`, and 1 `prefer_interpolation_to_compose_strings`.
*   No remaining M2B.2 target-file diagnostic is correctness-related after the `BuildContext` async-gap finding was fixed in Guest create/edit.

Remaining analyzer debt is tracked as debt, not as an M2B.2 security/retry blocker:

*   Legacy and SDK-deprecation cleanup remains outside this closure.
*   Some info diagnostics are in M2B.2 UI files, but they are not errors, warnings, or security/retry correctness findings.

## M. Gap Register

*   **`IMPL-CONFLICT-010` (Custom GUC trusted-operation authority) -> RESOLVED.**
*   **`IMPL-CONFLICT-011` (Ambiguous Guest Merge replay inference) -> RESOLVED.**
*   **`TECH-DEBT-001` (Legacy M2A.2 MD5 stale-impact fingerprints) -> OPEN / NON-BLOCKING.** Existing M2A.2 MD5 fingerprints are stale-impact change detectors only. They must not be described as secure and are not credentials, authorization tokens, idempotency tokens, replay proof, or authenticity proof.

## N. Recommendation

M2B.2 security/retry and Flutter analyzer closure are implementation-complete. Recommendation: **M2B.2 - COMPLETE**, pending Product Owner review.
