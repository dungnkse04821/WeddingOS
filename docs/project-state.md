# Trạng thái Dự án WeddingOS

## Giai đoạn Hiện tại

Implementation -> M7: Wedding Lifecycle & Cleanup — **COMPLETE** (archive/read-only lifecycle, trusted permanent deletion, Storage prefix cleanup, and organizer recovery UX delivered.)

## Tình trạng Dự án

Kho lưu trữ dự án mới. Chưa có mã nguồn ứng dụng nào được triển khai.
Toàn bộ các giai đoạn **Khám phá sản phẩm cấp cao (High-level Discovery)**, **Thiết kế luồng trải nghiệm người dùng (User Flows)**, **Mô hình hóa miền nghiệp vụ (Domain Model)** và **Kiến trúc Thông tin (Information Architecture)** đã được phê duyệt chính thức.
Giai đoạn đặc tả Yêu cầu chi tiết đã hoàn tất đối với toàn bộ các phân hệ: **REQ-01 — Wedding Foundation**, **REQ-02 — Planning**, **REQ-03 — Finance**, **REQ-04 — Guest Management**, **REQ-05 — Invitation & RSVP**, và **REQ-06 — Cross-cutting** đều đã được **phê duyệt chính thức (Approved)** bởi Product Owner.
Hiện tại, dự án đã hoàn thành giai đoạn **Thiết kế Kiến trúc Kỹ thuật (Technical Architecture)**:
*   **Vòng 1: Phân tích động lực & Phương án (Architecture Drivers & Option Analysis)** đã được **Phê duyệt chính thức (Approved)**.
*   **ADR-001** tới **ADR-007** đã được **Phê duyệt chính thức (Approved)**.
*   **Logical & Data Architecture** đã được **Phê duyệt chính thức (Approved)**.
*   **Thiết kế Vật lý PostgreSQL (PostgreSQL Physical Design)** đã được **Phê duyệt chính thức (Approved)**.
*   **Thiết kế Phân quyền RLS & Xác thực (RLS & Authorization Design)** đã được **Phê duyệt chính thức (Approved)**.
*   **Thiết kế Nghiệp vụ Tin cậy (Trusted Operations Design)** đã được **Phê duyệt chính thức (Approved)**.
*   **Thiết kế API Khách mời Công khai (Class D Public Guest API Design)** đã được **Phê duyệt chính thức (Approved)**.
*   **Thiết kế API Ban tổ chức (Class C Organizer API Design)** đã được **Phê duyệt chính thức (Approved)**.
*   **Đánh giá Kiến trúc Kỹ thuật Cuối cùng (Technical Architecture Final Review)** đã được **Phê duyệt chính thức (Approved)**.

## Ràng buộc Sản phẩm (Product Constraints)

1.  **Android-first:** MVP ưu tiên phát triển ứng dụng di động gốc dành cho cặp đôi và ban hỗ trợ trên hệ điều hành Android.
2.  **Hạ tầng miễn phí làm đầu (Free-tier-first):** Thiết kế hệ thống tối giản để có thể triển khai và vận hành trên các gói dịch vụ miễn phí (Free-tier) càng lâu càng tốt trong giai đoạn validation.
3.  **Responsive Web cho khách (Guest-facing Responsive Web Exception):** Khách mời truy cập thiệp online và gửi phản hồi RSVP thông qua giao diện Web di động gọn nhẹ, không được yêu cầu khách cài đặt ứng dụng Android hay đăng ký tài khoản.

## Hiểu biết về Sản phẩm

Tài liệu thiết kế luồng người dùng chi tiết cho tất cả các phân hệ đã hoàn thành được lưu trữ tại [discovery.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/discovery.md). Tài liệu mô hình hóa miền nghiệp vụ lưu trữ tại [domain-model.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/domain-model.md). Tài liệu kiến trúc thông tin lưu trữ tại [information-architecture.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/information-architecture.md). Chỉ mục yêu cầu chi tiết lưu trữ tại [README.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/requirements/README.md). Báo cáo kiến trúc kỹ thuật vòng đầu tiên được lưu trữ tại [01-architecture-drivers-and-options.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/01-architecture-drivers-and-options.md).

## Công nghệ sử dụng

Đã chốt định hướng: **Flutter (Android client)** + **Supabase (BaaS)** + **React SPA on Cloudflare Pages (Guest Web)**. (Đang đặc tả chi tiết các ADR).

## Kiến trúc hệ thống

Giai đoạn 3: Thiết kế Kiến trúc Logic & Dữ liệu (Logical & Data Architecture Phase) - Đã Phê duyệt (Approved)

## Phạm vi MVP Scope

Tập trung vào các mảng cốt lõi:
1. **Thiết lập không gian cưới:** Hỗ trợ cấu hình riêng biệt (Xem ngày âm/dương, chọn vùng miền).
2. **Kế hoạch thông minh:** Danh sách công việc phân chia theo bên gia đình (`COMMON`, `BRIDE_SIDE`, `GROOM_SIDE`) có sự hỗ trợ của AI.
3. **Quản lý ngân sách:** Tách biệt rõ ràng Khoản chi và Giao dịch thanh toán thực tế, hỗ trợ phân chia người chi trả.
4. **Quản lý khách mời:** Hỗ trợ nhập danh sách hộ bố mẹ (Proxy), theo dõi tiến độ RSVP và phát hiện trùng lặp.
5. **Trang RSVP đẹp mắt:** Cung cấp trang thiệp online tích hợp bản đồ, ảnh và VietQR thay vì một form đơn giản.

## Các quyết định đã chốt từ Product Owner (Tổng hợp toàn bộ)

*(Giữ nguyên lịch sử các quyết định đã được phê duyệt ở các Cluster 1, 2A, 2B, 3A, 3B, Mô hình miền, Kiến trúc thông tin, các Requirements chi tiết, và Architecture Option Analysis. Chi tiết xem tại các tài liệu tương ứng trong thư mục docs/)*

## Tình trạng các Phân hệ Yêu cầu (Requirements Status)

*   **REQ-01: Wedding Foundation:** 🟢 **Đã Phê duyệt (Approved)**
*   **REQ-02: Planning:** 🟢 **Đã Phê duyệt (Approved)**
*   **REQ-03: Finance:** 🟢 **Đã Phê duyệt (Approved)**
*   **REQ-04: Guest Management:** 🟢 **Đã Phê duyệt (Approved)**
*   **REQ-05: Invitation & RSVP:** 🟢 **Đã Phê duyệt (Approved)**
*   **REQ-06: Cross-cutting:** 🟢 **Đã Phê duyệt (Approved - Có Hiệu chỉnh AMEND-REQ-06-001)**

## Tình trạng các Tài liệu Thiết kế Kiến trúc (Architecture Status)

*   **Vòng 1: Drivers & Options:** 🟢 **Đã Phê duyệt (Approved)** - Chi tiết tại [01-architecture-drivers-and-options.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/01-architecture-drivers-and-options.md)
*   **ADR Index (README):** 🟢 **Đã Phê duyệt (Approved)** - Chi tiết tại [README.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/adr/README.md)
*   **ADR-001 Client Platform & Flutter:** 🟢 **Đã Phê duyệt (Approved)** - Chi tiết tại [ADR-001-client-platform-and-flutter.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/adr/ADR-001-client-platform-and-flutter.md)
*   **ADR-002 Backend Platform & PostgreSQL:** 🟢 **Đã Phê duyệt (Approved)** - Chi tiết tại [ADR-002-backend-platform-and-postgresql.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/adr/ADR-002-backend-platform-and-postgresql.md)
*   **ADR-003 Trust Boundary, Authorization & RLS:** 🟢 **Đã Phê duyệt (Approved)** - Chi tiết tại [ADR-003-trust-boundary-authorization-and-rls.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/adr/ADR-003-trust-boundary-authorization-and-rls.md)
*   **ADR-004 Organizer Authentication:** 🟢 **Đã Phê duyệt (Approved)** - Chi tiết tại [ADR-004-organizer-authentication.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/adr/ADR-004-organizer-authentication.md)
*   **ADR-005 Guest Web & Public Invitation API:** 🟢 **Đã Phê duyệt (Approved)** - Chi tiết tại [ADR-005-guest-web-and-public-invitation-api.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/adr/ADR-005-guest-web-and-public-invitation-api.md)
*   **ADR-006 Storage, Media & Import/Export:** 🟢 **Đã Phê duyệt (Approved)** - Chi tiết tại [ADR-006-storage-media-and-import-export.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/adr/ADR-006-storage-media-and-import-export.md)
*   **ADR-007 Notifications, AI & Deferred Capabilities:** 🟢 **Đã Phê duyệt (Approved)** - Chi tiết tại [ADR-007-notifications-ai-and-deferred-capabilities.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/adr/ADR-007-notifications-ai-and-deferred-capabilities.md)

*   **Logical Architecture:** 🟢 **Đã Phê duyệt (Approved)** - Chi tiết tại [02-logical-architecture.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/02-logical-architecture.md)
*   **Data Architecture:** 🟢 **Đã Phê duyệt (Approved)** - Chi tiết tại [03-data-architecture.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/03-data-architecture.md)
*   **PostgreSQL Physical Design:** 🟢 **Đã Phê duyệt (Approved)** - Chi tiết tại [04-postgresql-physical-design.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/04-postgresql-physical-design.md)
*   **RLS & Authorization Design:** 🟢 **Đã Phê duyệt (Approved)** - Chi tiết tại [05-rls-and-authorization-design.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/05-rls-and-authorization-design.md)
*   **Trusted Operations Design:** 🟢 **Đã Phê duyệt (Approved)** - Chi tiết tại [06-trusted-operations-design.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/06-trusted-operations-design.md)
*   **Class D Public Guest API Design:** 🟢 **Đã Phê duyệt (Approved)** - Chi tiết tại [07-class-d-public-guest-api-design.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/07-class-d-public-guest-api-design.md)
*   **Class C Organizer API Design:** 🟢 **Đã Phê duyệt (Approved)** - Chi tiết tại [08-class-c-organizer-api-design.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/08-class-c-organizer-api-design.md)
*   **Technical Architecture Final Review:** 🟢 **Đã Phê duyệt (Approved)** - Chi tiết tại [09-technical-architecture-final-review.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/09-technical-architecture-final-review.md)
*   **MVP Backlog:** 🟢 **Đã Phê duyệt (Approved)** - Chi tiết tại [10-mvp-backlog.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/planning/10-mvp-backlog.md)
*   **Implementation Plan:** 🟢 **Đã Phê duyệt (Approved)** - Chi tiết tại [11-implementation-plan.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/planning/11-implementation-plan.md)
*   **M0 Implementation Decision Gate:** 🟢 **Đã Phê duyệt (Approved)** - Chi tiết tại [12-m0-implementation-decision-gate.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/implementation/12-m0-implementation-decision-gate.md)
*   **M2A.1 Planning Foundation:** 🟢 **Đã hoàn thành (Complete)** - Chi tiết tại [14-m2a1-planning-foundation.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/implementation/14-m2a1-planning-foundation.md)
*   **M2A.2 Date Change & Removal Previews:** 🟢 **Đã hoàn thành (Complete / Approved)** — IMPL-CONFLICT-006 resolved, 116 tests pass — Chi tiết tại [15-m2a2-event-impact-review.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/implementation/15-m2a2-event-impact-review.md)
*   **M2B.1 Guest Core Foundation:** 🟢 **Đã phê duyệt (Approved)** — 139 tests pass, transition constraints verified, Flutter tests pass — Chi tiết tại [16-m2b1-guest-foundation.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/implementation/16-m2b1-guest-foundation.md)
*   **M2B.2 Guest Impact Operations:** 🟢 **Đã phê duyệt (Approved)** — IMPL-CONFLICT-010 and IMPL-CONFLICT-011 resolved; DB 166/166 pass; Flutter tests pass; Flutter analyze has 0 errors / 0 warnings and info-level diagnostics tracked as analyzer debt — Chi tiết tại [17-m2b2-guest-impact-operations.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/implementation/17-m2b2-guest-impact-operations.md)
*   **M2B.3 Excel Guest Import:** 🟢 **Đã phê duyệt (Approved)** — TOP-GUE-004 local XLSX parsing, Preview, trusted Confirm Import, durable receipt retry, server revalidation, and tests implemented; DB 193/193 pass; Flutter tests pass; analyzer 0 errors / 0 warnings / 192 info — Chi tiết tại [18-m2b3-excel-import.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/implementation/18-m2b3-excel-import.md)
*   **M3 Invitation / Credential Foundation:** 🟢 **Đã phê duyệt (Approved)** — Invitation schema, Event targeting, lifecycle triggers, DEC-B-002 credential format, TOP-INV-001 credential regeneration, active credential invariant, organizer UI, and tests implemented; DB 232/232 pass; Flutter tests pass; analyzer 0 errors / 0 warnings / 191 info — Chi tiết tại [19-m3-invitation-credential-foundation.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/implementation/19-m3-invitation-credential-foundation.md)
*   **M4 Public Guest Invitation Resolve:** 🟢 **Đã phê duyệt (Approved)** — D-INV-001 public resolve, Guest Web shell, URL fragment token extraction/scrubbing, sanitized DTO, view tracking, Edge Function, hidden internal DB implementation, service-only `edge_api` PostgREST bridge, and DEC-B-004 Class-D rate limiting implemented; IMPL-CONFLICT-012, IMPL-CONFLICT-013, IMPL-GAP-006, IMPL-AMEND-001, and IMPL-AMEND-002 resolved/recorded; DB 306/306 pass; Guest Web tests/lint/build pass; Flutter tests pass; analyzer 0 errors / 0 warnings / 191 info — Chi tiết tại [20-m4-public-invitation-resolve.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/implementation/20-m4-public-invitation-resolve.md)
*   **M4.2 Public RSVP Submit:** 🟢 **Hoàn thành (Complete)** — D-RSV-001 current RSVP/EventResponse schema, trusted Class-D Edge/`edge_api` bridge, Wedding-timezone cutoff, partial patch-by-event, RSVP limiter integration, and Guest Web form delivered; DB 343/343, canonical Guest Web tests/lint/build, local Edge smoke, Flutter regression, commit, and push pass — Chi tiết tại [21-m4-2-public-rsvp-submit.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/implementation/21-m4-2-public-rsvp-submit.md)
*   **M4.3 VietQR Gating:** 🟢 **Hoàn thành (Complete)** — Wedding-level static configuration, authoritative qualified-RSVP Class-D DTO gate, Guest Web conditional display, and organizer configuration delivered; clean DB reset and 362 DB assertions pass, Guest Web tests/lint/build pass, and Flutter test/analyzer pass — Chi tiết tại [22-m4-3-vietqr-gating.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/implementation/22-m4-3-vietqr-gating.md)
*   **M5 Finance Core:** 🟡 **Chưa Hoàn Thành (Incomplete / Needs Fixes)** — 8 Class-C API surfaces (FIN-001 -> FIN-007), strict delete guards, VIEW-based finance aggregates delivered and DB verified. IMPL-CONFLICT-014 and IMPL-CONFLICT-016 resolved. Tuy nhiên Flutter UX implementation hiện tại chỉ là visual scaffolding, chưa được wire với service backend. Cần phải wire toàn bộ và verify service contract trước khi Complete. — Chi tiết tại [23-m5-finance-core.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/implementation/23-m5-finance-core.md)
*   **M6 Storage & Media Foundation:** 🟢 **Hoàn thành (Complete)** — Batch 12 private `wedding_media` bucket, exact WebP cover slot, Storage RLS, no organizer DELETE grant, Flutter upload/replace, D-INV-001 signed cover field, and Guest Web fallback delivered. DB 417 assertions, Flutter 21 tests/analyzer 0 errors and warnings, Guest Web tests/lint/build, and real authenticated Storage HTTP verification pass — Chi tiết tại [24-m6-storage-media-foundation.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/implementation/24-m6-storage-media-foundation.md)
*   **M7 Wedding Lifecycle & Cleanup:** 🟢 **Hoàn thành (Complete)** — Practical M7 implements original-plan M6 lifecycle scope: OWNER archive, ARCHIVED read-only behavior, service-only verified-actor deletion orchestration, recursive private Storage prefix cleanup, cascade-safe physical deletion, Flutter confirmation/recovery UX, and full regression. Batch 15 is latest; DB 438 assertions, Edge 13 tests, Flutter 31 tests/analyzer 0 errors and warnings, Guest Web 9 tests/lint/build, and real Storage HTTP post-condition verification pass — Chi tiết tại [25-m7-wedding-lifecycle-cleanup.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/implementation/25-m7-wedding-lifecycle-cleanup.md)

## Gap Register

*   **`TECH-DEBT-001` (Legacy M2A.2 MD5 stale-impact fingerprints):** 🟡 **Open / Non-blocking** — M2A.2 MD5 fingerprints are stale-impact change detectors only; they are not credentials, authorization tokens, idempotency tokens, replay proof, or authenticity proof. Do not describe them as secure.
*   **`IMPL-CONFLICT-012` (Class-D DB helper boundary):** 🟢 **Resolved** — D-INV-001 implementation moved out of organizer `api_v1` to hidden `internal.resolve_public_invitation`; provider bridge is separate service-only plumbing.
*   **`IMPL-CONFLICT-013` (Hidden internal schema PostgREST exposure):** 🟢 **Resolved** — `internal` removed from local `[api].schemas`; Edge calls narrow `edge_api.resolve_public_invitation` bridge instead.
*   **`IMPL-GAP-006` (DEC-B-004 limiter authority/persistence evidence):** 🟢 **Resolved** — limiter authority, network signal assumptions, persistence object, grants, retention, and negative tests documented.
*   **`IMPL-AMEND-001` (Class-D rate limiter technical persistence):** 🟢 **Recorded** — `private.class_d_rate_limits` is technical infrastructure for DEC-B-004 only; it does not change the approved 17 business-table inventory and is not a domain aggregate.
*   **`IMPL-AMEND-002` (Class-D service-only PostgREST bridge):** 🟢 **Recorded** — `edge_api.resolve_public_invitation` is a narrow service-only bridge for D-INV-001 Edge runtime plumbing; it is not Organizer Class-C and not a public Class-D route.

## Các câu hỏi mở cần Product Owner làm rõ về Kiến trúc

*   **`OPEN-DATA-001` (Financial Transaction Correction Semantics):** 🟢 **Đã Giải quyết (Resolved)** - MVP sử dụng cơ chế Controlled Edit + Void. Chi tiết tại đặc tả Physical Design.

## Ràng buộc hành vi

- Không viết mã nguồn ứng dụng trong giai đoạn Khởi động (Bootstrap), Khám phá (Discovery), thiết kế Luồng người dùng (User Flows), viết Yêu cầu chi tiết (Detailed Requirements) và thiết kế Kiến trúc chi tiết (Technical Architecture).
- Không chọn công nghệ trước khi hoàn tất Khám phá và đánh giá kiến trúc kỹ thuật.
- Bảo lưu lịch sử Git và các quy tắc dự án.

## Giai đoạn Tiếp theo

Implementation -> M8: Security & NFR Hardening design/implementation gate. This is original implementation-plan M7; numbering shifted because practical M6 was Storage & Media and practical M7 was Wedding Lifecycle & Cleanup.

## Hành động Khuyên dùng tiếp theo

Product Owner review M7 delivery, then authorize practical M8 Security & NFR Hardening separately. Do not start M8 from this checkpoint.
