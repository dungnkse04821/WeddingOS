# M7 Wedding Lifecycle & Cleanup Checkpoint

## Milestone

- Status: **COMPLETE / READY FOR PO APPROVAL**.
- Practical milestone: M7 Wedding Lifecycle & Cleanup.
- Traceability: practical M7 implements original implementation-plan M6 (Wedding Lifecycle Delete & Storage Cleanup). The next practical milestone is M8 Security & NFR Hardening, corresponding to original-plan M7.
- Implemented: STORY-11-01 / TOP-WED-003 Archive Wedding and STORY-11-02 / TOP-WED-004 Permanent Delete & Storage Cleanup, including DB lifecycle authority, trusted Edge orchestration, provider cleanup, Flutter UX, and regression evidence.
- Explicitly not implemented: unarchive, gallery/video/media library, R2, later hardening/NFR work, Finance changes, and unrelated M8 work.

## Database

- Latest migration: `00000000000015_batch_15.sql`; 16 migration files exist from Batch 00 through Batch 15.
- Batch 13: `api_v1.archive_wedding`, hidden begin/finalize delete capabilities, lifecycle gates, and cascade proof.
- Batch 14: controlled `M7-AUTH-BRIDGE-001` service-only verified-actor bridges.
- Batch 15: generic absent-Wedding terminal result through the existing service-only begin bridge.
- Allowed transitions: ACTIVE -> ARCHIVED, ACTIVE -> DELETING, ARCHIVED -> DELETING, and DELETING -> physical deletion after verified Storage cleanup.
- Disallowed transitions: ARCHIVED -> ACTIVE, DELETING -> ACTIVE, and DELETING -> ARCHIVED. No unarchive surface exists.
- TOP-WED-003 surface: authenticated `api_v1.archive_wedding(uuid)`, bound to `auth.uid()`, requiring ACTIVE OWNER membership. ACTIVE archives; ARCHIVED retry converges; no receipt or request ID exists.
- TOP-WED-004 surface: authenticated `POST /functions/v1/wedding-delete`. Hidden `internal` begin/finalize functions are not executable by clients.
- Bridge functions: `edge_api.begin_wedding_delete(uuid, uuid)` and `edge_api.finalize_wedding_delete(uuid, uuid)` are executable by `service_role` only; `anon` and `authenticated` are revoked.
- DB independently checks the Edge-verified actor has ACTIVE OWNER membership for the target Wedding. Membership is retained during DELETING for retry and rechecked before finalization.
- Finalization explicitly removes Wedding-scoped trusted-operation receipts, then uses the verified FK cascade graph. Memberships, pending collaborator invitations, events, tasks, finance rows, groups, guests, invitation parties, invitations, targetings, credentials, RSVPs, and event responses are removed.
- `auth.users`, unrelated Weddings and child rows, and non-Wedding-scoped `private.class_d_rate_limits` remain.

## Edge And Storage

- JWT trust chain: Flutter bearer token -> Supabase Auth `/auth/v1/user` verification -> verified `user.id` -> service-only bridge -> independent DB OWNER authorization.
- Client body contains only `wedding_id`. Actor, role, bucket, prefix, and object paths cannot provide authority. No custom GUC or `request.jwt.claims` runtime impersonation is used.
- Fixed bucket: private `wedding_media`.
- Authoritative prefix: `weddings/{wedding_id}/`, derived server-side from the DB-authoritative Wedding ID.
- Cleanup recursively lists provider directories, paginates with `limit=100` and offset, deletes at most 100 object paths per request, relists, and finalizes only after a fresh authoritative empty listing.
- Storage list/delete or DB finalization failure returns bounded `DELETE_RETRY_REQUIRED`; Wedding remains DELETING. Partial cleanup, empty prefix, and finalization retries converge without a receipt or request ID.
- An authenticated retry for a physically absent target returns minimal generic `DELETED`, without revealing prior existence.
- Real provider evidence: service uploads/list/root and nested list/delete returned HTTP 200; root and nested lists were freshly empty after cleanup; empty retry was empty; another Wedding's object remained; disposable fixtures were removed.
- Organizer no-DELETE evidence: ACTIVE OWNER direct DELETE returned HTTP 200 but the object remained readable. HTTP status is not used as authorization proof; persistence and the absent organizer DELETE policy prove no effective organizer deletion authority. Trusted server cleanup succeeds separately.
- Real pagination was not forced with the small provider fixture. Deterministic Edge tests cover 101 listed entries, pagination offsets, and 100/1 delete batching.

## Product Behavior

- ARCHIVED: organizer reads and Wedding switching remain; ordinary business mutations and Storage writes are denied; guest resolve, RSVP, and new signed cover URLs are unavailable; no unarchive exists.
- DELETING: ordinary organizer/member/task/guest/finance/Storage mutations and public guest capabilities fail closed. OWNER retry and Wedding switching are the only recovery actions.
- Concurrency authority is the locked DB lifecycle transition. If archive wins first, ARCHIVED may then enter DELETING; if delete wins, archive cannot overwrite DELETING. Repeated owner deletes converge.
- Flutter shows OWNER-only archive/delete controls. Archive has a data-retaining read-only warning. Permanent delete requires trimmed, NFC-normalized, case-insensitive Wedding-name matching while preserving Vietnamese diacritic distinctions.
- ARCHIVED remains readable with an explicit badge. DELETING replaces the editable workspace with bounded retry/switch UX. Terminal deletion clears persisted current-Wedding state, removes stale selection, invalidates Wedding-scoped context, and returns to selector/no-Wedding flow.
- Guest/Class-D behavior remains fail-closed for ARCHIVED and DELETING. No new guest route exists, and VietQR behavior is unchanged except lifecycle denial.

## Final Evidence

- Database: clean reset PASS through Batch 15; 13 pgTAP files / 438 assertions / 0 failures.
- Edge: Deno 2.9.5; 3 files / 13 tests / 0 failures across invitation resolve, RSVP, and Wedding delete.
- Provider: real local Storage HTTP list/delete/nested/empty retry/cross-Wedding post-conditions PASS; organizer effective DELETE denial PASS.
- Flutter: 31 tests / 0 failures; analyzer 0 errors / 0 warnings / 208 info diagnostics.
- Guest Web: 2 suites / 9 tests / 0 failures in 24.12 seconds; lint PASS; build PASS in 1.24 seconds; JavaScript bundle 202.68 kB (64.16 kB gzip).
- Security: OWNER-only lifecycle authority, collaborator/outsider denial, service-role containment, fixed cleanup authority, no organizer DELETE grant, no account deletion, bounded errors, and no token/secret logging all PASS.

## Defects And Debt

- Fixed during M7.3: pre-existing missing parenthesis and State-class closing brace in `cover_media_screen.dart`; M6 behavior was unchanged.
- Controlled amendment: `M7-AUTH-BRIDGE-001`; no open M7 implementation conflict remains.
- Non-blocking debt: provider pagination is deterministically tested but was not forced in real local fixtures; Flutter retains 208 info-level analyzer diagnostics; local Storage DELETE may return HTTP 200 for an RLS no-op, so verification must inspect object persistence.

## Git And Takeover

- Branch: `main`.
- Closure commit: `638e2b1` (`m7: finalize wedding lifecycle cleanup`).
- Push: PASS to `origin/main`; the authoritative checkpoint is included by the subsequent `docs: finalize m7 handoff checkpoint` commit.
- Working tree after final checkpoint delivery: clean, with local HEAD equal to `origin/main` (verified after push).
- Exact next task: Product Owner review of M7, then separately authorize practical M8 Security & NFR Hardening.
- STOP boundary: do not start M8 from this checkpoint.
- Next-harness execution mode: Continue until milestone closure. Do not return intermediate progress reports unless a non-resolvable technical blocker appears.
