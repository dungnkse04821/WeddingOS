# Trạng thái Dự án WeddingOS

## Giai đoạn Hiện tại

Implementation -> M2A.1: Planning Foundation + Initial Wedding Plan — In Review

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
*   **M2A.1 Planning Foundation:** 🟡 **Đang chờ duyệt (In Review)** - Chi tiết tại [14-m2a1-planning-foundation.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/implementation/14-m2a1-planning-foundation.md)

## Các câu hỏi mở cần Product Owner làm rõ về Kiến trúc

*   **`OPEN-DATA-001` (Financial Transaction Correction Semantics):** 🟢 **Đã Giải quyết (Resolved)** - MVP sử dụng cơ chế Controlled Edit + Void. Chi tiết tại đặc tả Physical Design.

## Ràng buộc hành vi

- Không viết mã nguồn ứng dụng trong giai đoạn Khởi động (Bootstrap), Khám phá (Discovery), thiết kế Luồng người dùng (User Flows), viết Yêu cầu chi tiết (Detailed Requirements) và thiết kế Kiến trúc chi tiết (Technical Architecture).
- Không chọn công nghệ trước khi hoàn tất Khám phá và đánh giá kiến trúc kỹ thuật.
- Bảo lưu lịch sử Git và các quy tắc dự án.

## Giai đoạn Tiếp theo

MVP Backlog & Kế hoạch Triển khai Thực thi (MVP Backlog & Implementation Planning).

## Hành động Khuyên dùng tiếp theo

Bắt đầu xây dựng danh mục Backlog MVP và lập kế hoạch triển khai thực thi chi tiết.

