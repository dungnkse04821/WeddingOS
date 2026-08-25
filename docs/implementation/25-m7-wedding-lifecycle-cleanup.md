# M7 Wedding Lifecycle & Cleanup

Status: M7 overall IN PROGRESS. M7.1 DB Lifecycle Foundation is COMPLETE.

Batch 13 adds owner-only `api_v1.archive_wedding`, plus hidden `internal.begin_wedding_delete` and `internal.finalize_wedding_delete` capabilities. The latter remain non-executable by `authenticated`; pgTAP invokes them as `trusted_function_owner` while preserving `request.jwt.claims`, proving that `auth.uid()` remains the business actor for OWNER/collaborator authorization.

Archive converges at ARCHIVED without a receipt or child deletion. Begin-delete transitions ACTIVE or ARCHIVED to DELETING and preserves membership for recovery. Finalize requires DELETING, deletes trusted-operation receipts explicitly, and relies on the existing Wedding FK cascade graph for child records. Tests prove representative event/group cascade, auth user preservation, unrelated Wedding preservation, hidden capability denial, and lifecycle read-only gating.

Verification: clean reset applied Batch 13; full pgTAP suite PASS, 13 files / 438 assertions. M7.2 Storage Edge orchestration and M7.3 Flutter lifecycle UX remain out of this slice.

M7.2A Trusted Actor Bridge is COMPLETE after Batch 14 verification: service-only `edge_api` begin/finalize bridges accept only the Edge-derived verified actor and DB revalidates active OWNER membership. No client role can execute the bridge or hidden overloads.

M7.2B1 Edge Route Foundation is COMPLETE: `POST /functions/v1/wedding-delete` verifies the bearer with Supabase Auth, derives the actor from `/auth/v1/user`, calls only the service-only begin bridge, and returns guarded `202 DELETING`. Storage cleanup and finalization are explicitly deferred to M7.2B2. The repository-standard Deno test path was restored with official Deno 2.9.5; `supabase/functions/wedding-delete/index_test.ts` passed 3/3 tests. Final DB regression reset applied Batch 14 and pgTAP passed 13 files / 438 assertions / 0 failures.
