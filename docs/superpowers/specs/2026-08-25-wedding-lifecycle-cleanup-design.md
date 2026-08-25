# M7 Wedding Lifecycle & Cleanup Design

## Identity and Traceability

Practical milestone: M7 Wedding Lifecycle & Cleanup. It implements `STORY-11-01` / `TOP-WED-003` Archive Wedding and `STORY-11-02` / `TOP-WED-004` Permanent Delete & Storage Cleanup. The older implementation plan calls this lifecycle/delete milestone M6; that numbering drift is traceability-only. M7 does not include later hardening/NFR work.

Sources: MVP Backlog Epic 11, implementation plan, trusted-operations design section J, Class-C API design, RLS design, Class-D design, physical design, and the M6 checkpoint.

## Lifecycle

| Current | Requested | Result |
| --- | --- | --- |
| ACTIVE | ARCHIVED | Allowed through TOP-WED-003 for active OWNER |
| ACTIVE | DELETING | Allowed through TOP-WED-004 for active OWNER |
| ARCHIVED | DELETING | Allowed through TOP-WED-004 for active OWNER |
| ARCHIVED | ACTIVE | Not allowed; MVP has no unarchive |
| DELETING | ACTIVE / ARCHIVED | Not allowed |
| DELETING | physical delete | Allowed only after verified Storage cleanup |

`DELETING` is terminal except delete recovery. Physical deletion removes Wedding-scoped DB data but never `auth.users`.

## TOP-WED-003 Archive

Class C RPC: `api_v1.archive_wedding`, called by authenticated Flutter. The DB validates `auth.uid()`, active OWNER membership, and `ACTIVE -> ARCHIVED`. It stores no receipt; retry returns stable ARCHIVED current-state success. Archive deletes no data. Organizer reads, including existing private cover reads, remain available; ordinary mutations and Storage writes are denied. Guest invitation resolve and RSVP are unavailable, and no new Guest media URL is signed. The Wedding remains selectable in a clearly read-only Flutter state. There is no unarchive surface.

## TOP-WED-004 Delete

Class C Edge/Hybrid surface: `POST /v1/organizer/weddings/delete`. It is Edge/Hybrid specifically for Storage coordination, not a rule for Class C generally. It is not receipt-backed and does not add `request_id`; the durable retry authority is Wedding lifecycle `DELETING`.

### Authority and Call Chain

`Flutter -> organizer delete Edge -> DB trusted begin-delete -> Storage cleanup -> DB trusted finalize-delete`.

The Edge validates its organizer session and orchestrates bounded Storage calls. DB trusted capabilities own actor validation, active OWNER validation, transition from ACTIVE/ARCHIVED to DELETING, final lifecycle validation, and physical DB deletion. The Edge derives fixed bucket `wedding_media` and prefix `weddings/{authoritative_wedding_id}/`; clients cannot choose a bucket, prefix, object list, or SQL operation. Service-role is confined to Edge Storage access and cannot be used for arbitrary direct lifecycle updates/deletes.

### Retry and Failure

First request marks the Wedding DELETING. Retry while DELETING lists the prefix again and resumes cleanup. Empty Storage permits final DB deletion. Storage failure leaves DELETING intact and never final-deletes DB. If Storage cleanup succeeds but final DB deletion fails, retry finalizes DB. If the Wedding is physically absent, an authenticated caller receives generic terminal success that does not reveal whether it previously existed.

### Storage Algorithm

List recursively beneath the fixed Wedding prefix, honoring provider pagination. Delete returned objects in bounded internal batches, repeat until a fresh list confirms empty, then finalize DB. Batch/page size remains an internal provider configuration, not a public contract. Prefix deletion is not assumed atomic. M7 provider integration tests must cover pagination, batch deletion, empty prefix, partial deletion, retry, and transient failure.

## DELETING Behavior and Concurrency

DELETING blocks all ordinary organizer mutations: members, events, tasks, guests, finance, invitations, credentials, and RSVP. It blocks organizer Storage mutation, Guest resolve, new signed media URLs, and collaborator lifecycle actions. Only active OWNER delete recovery is allowed. UI presents a blocking delete/retry state and removes selected Wedding/caches after success.

Lifecycle transitions serialize in DB. Archive versus delete is current-state authorization: if archive commits first, ARCHIVED may proceed to DELETING; if delete commits first, archive fails. Once DELETING commits, collaborator mutations, guest RSVP, Storage upload, and member administration fail closed.

## Delete UX

Archive uses a standard destructive confirmation and explains read-only retention, unavailable public invitation/RSVP, and no unarchive. Permanent delete requires typed Wedding-name confirmation: trim surrounding whitespace, Unicode-normalize consistently, compare case-insensitively while preserving Vietnamese diacritic distinction. The typed value is never persisted and is UX safety only; server authorization remains authoritative. Delete UI warns irreversibility, blocks submit until matched, offers retry-safe generic failure copy, and never exposes batches, credentials, SQLSTATE, or internal capability names.

## Cascade Audit

Audit final deletion of Wedding-scoped rows: wedding_members, pending_collaborator_invitations, wedding_events, tasks, budget_items, installments, payments, refunds, primary_groups, guests, invitation_parties, invitations, invitation_event_targetings, invitation_credentials, rsvps, event_responses, and `private.trusted_operation_receipts`. Existing FKs include both direct/indirect cascades and RESTRICT composite references; implementation must prove the exact final-delete order or cascade behavior before relying on `DELETE FROM weddings`. `private.class_d_rate_limits` is not Wedding-scoped and is not deleted. Auth identities remain intact.

## Security and Tests

OWNER-only DB authorization, exact authoritative prefix binding, private bucket access, service-role containment, no generic admin endpoint, bounded public errors, and no secret/token logging are invariants. Tests cover OWNER/collaborator/outsider behavior, ACTIVE/ARCHIVED transitions, DELETING recovery, DB cascades, auth-user preservation, Class-D unavailability, ordinary-mutation denial, storage pagination/batches/failure/retry, cross-Wedding safety, and Flutter selector recovery.

## Out of Scope

No M7 implementation in this design step. No gallery, video, R2, media library, unarchive, M8 hardening/NFR work, or changes to M6 Storage policy.

## Amendments and Decisions

No architecture amendment is required: the approved Edge/Hybrid delete surface already exists. Provider batch size is an implementation configuration to be documented during implementation. All PO decisions required by the prior design review are now resolved.
