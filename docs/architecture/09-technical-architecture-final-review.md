# Đặc Tả Kiến Trúc: 09 — Technical Architecture Final Review (Đánh Giá Kiến Trúc Kỹ Thuật Cuối Cùng)

*   **Trạng thái (Status):** APPROVED (Đã Phê duyệt)
*   **Người thực hiện:** Antigravity (AI Architect)
*   **Ngày cập nhật:** 21/08/2026

---

> [!IMPORTANT]
> **NON-EXECUTABLE ARCHITECTURE AUDIT DOCUMENT**
> Tài liệu này đại diện cho cuộc Đánh giá và Đối soát Kiến trúc Kỹ thuật toàn diện (Final Technical Architecture Review) nhằm xác minh tính sẵn sàng thực thi (IMPLEMENTATION READINESS) của hệ thống WeddingOS. Tài liệu này đánh giá thiết kế kiến trúc, không phải là mã nguồn thực thi hay tệp migration SQL đã triển khai trên môi trường runtime.

---

## A. Báo Cáo Tóm Tắt Trạng Thái Kiến Trúc (Executive Architecture Status)

Kiến trúc kỹ thuật của dự án WeddingOS đã trải qua quá trình thiết kế và hiệu chỉnh chặt chẽ qua 8 chặng:
1.  **Logical & Data Architecture:** 🟢 **APPROVED**
2.  **PostgreSQL Physical Design:** 🟢 **APPROVED** (Đã giải quyết `ERRATA-PHY-001` đến `009`)
3.  **RLS & Authorization Design:** 🟢 **APPROVED** (Đã giải quyết `ERRATA-RLS-001`)
4.  **Trusted Operations Design:** 🟢 **APPROVED** (Đã giải quyết `ERRATA-TOP-001` đến `004`)
5.  **Class D Public Guest API Design:** 🟢 **APPROVED** (Đã giải quyết `ERRATA-D-001` đến `004`)
6.  **Class C Organizer API Design:** 🟢 **APPROVED** (Đã giải quyết `ERRATA-CAPI-001` đến `004`)

**Kết luận đánh giá tổng thể:** Toàn bộ thiết kế kiến trúc hệ thống đạt trạng thái **Sẵn sàng Thực thi (READY FOR IMPLEMENTATION)**, không phát hiện bất kỳ mâu thuẫn yêu cầu hay khoảng trống bảo mật/cô lập tenant nào chưa được xử lý.

---

## B. Danh Mục Tài Liệu Nguồn Đáng Tin Cậy (Source-of-Truth Inventory)

Cuộc đối soát được thực thi dựa trên bộ tài liệu gốc đã được phê duyệt dưới đây:
1.  **Miền nghiệp vụ & Luồng người dùng:**
    *   [`docs/discovery.md`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/discovery.md)
    *   [`docs/domain-model.md`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/domain-model.md)
    *   [`docs/information-architecture.md`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/information-architecture.md)
2.  **Đặc tả Yêu cầu (Requirements):**
    *   [`docs/requirements/README.md`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/requirements/README.md)
    *   [`docs/requirements/01-wedding-foundation.md`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/requirements/01-wedding-foundation.md)
    *   [`docs/requirements/02-planning.md`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/requirements/02-planning.md)
    *   [`docs/requirements/03-finance.md`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/requirements/03-finance.md)
    *   [`docs/requirements/04-guest-management.md`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/requirements/04-guest-management.md)
    *   [`docs/requirements/05-invitation-rsvp.md`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/requirements/05-invitation-rsvp.md)
    *   [`docs/requirements/06-cross-cutting.md`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/requirements/06-cross-cutting.md)
3.  **Tài liệu Thiết kế Kiến trúc:**
    *   [`docs/architecture/01-architecture-drivers-and-options.md`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/01-architecture-drivers-and-options.md)
    *   [`docs/architecture/adr/`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/adr/) (ADR-001 đến ADR-007)
    *   [`docs/architecture/02-logical-architecture.md`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/02-logical-architecture.md)
    *   [`docs/architecture/03-data-architecture.md`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/03-data-architecture.md)
    *   [`docs/architecture/04-postgresql-physical-design.md`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/04-postgresql-physical-design.md)
    *   [`docs/architecture/05-rls-and-authorization-design.md`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/05-rls-and-authorization-design.md)
    *   [`docs/architecture/06-trusted-operations-design.md`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/06-trusted-operations-design.md)
    *   [`docs/architecture/07-class-d-public-guest-api-design.md`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/07-class-d-public-guest-api-design.md)
    *   [`docs/architecture/08-class-c-organizer-api-design.md`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/08-class-c-organizer-api-design.md)

---

## C. Ma Trận Truy Vết Nghiệp Vụ Cuối Cùng (Requirement Traceability Matrix)

Hệ thống đối soát lại các hàng thuộc diện rà soát bổ sung của PO:

| Yêu cầu / Quy tắc ID | Ý nghĩa nghiệp vụ | Thực thể Miền | Trường dữ liệu vật lý | Phân lớp Phân quyền | RLS/Grant DB | Đường dẫn Ghi dữ liệu | Nghiệp vụ Tin cậy (TOP) | API Contract | Kiểm thử an ninh | Trạng thái đối soát |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :---: |
| **`REQ-03-001`** | Ghi nhận chi tiêu | Payment | `payments` | OWNER | Chặn ghi Class B, gán Class C | Class C RPC | `TOP-FIN-001` | `api_v1.create_payment` | Test receipt chi đúp | **COVERED** |
| **`REQ-03-AUTH`** | Phân quyền tài chính | Budget, Payment, Refund | `budget_items`, `payments`, `refunds` | OWNER (SELECT/CUD) vs COLLAB (Blocked) | RLS + Grants: budget_items/installments cho phép Class B OWNER mutate. Payments/refunds khóa Class B. | Class B (Budget/Installment) / Class C (Payment/Refund) | TOP-FIN-001 -> 007 | `api_v1.*` | Test Collab đọc/ghi budget và payments | **COVERED** |
| **`REQ-03-PAYER`**| Định danh người chi trả thực tế | Payment | `payments.payer_display_name`, `payments.payer_wedding_member_id` | OWNER | references `wedding_members (id) ON DELETE SET NULL` | Class C RPC | `TOP-FIN-001` | `api_v1.create_payment` | Test gán member REVOKED / non-member | **COVERED** |
| **`REQ-05-SEC`** | Bảo mật mã thiệp trên URL | Credential | `invitation_credentials.token_hash` | Guest Web | Edge Function Class D verify SHA-256 hash | Class D Edge | `D-INV-001` | `POST .../invitation/resolve`| Test browser replaceState & XSS defense | **COVERED** |
| **`REQ-06-NFR`** | Tốc độ load thiệp & hiệu năng | Guest Web | - | Guest Web | Caching policy | Class D Edge | - | `Cache-Control: no-store` | Sẵn sàng đo kiểm hiệu năng (READY FOR BENCHMARK) | **COVERED** |
| **`REQ-06-FREE`** | Hạ tầng tối giản gói miễn phí | - | - | System | Edge / RPC tối giản | Class C / D | - | - | Không bắt buộc Realtime/AI/Cron | **COVERED** |
| **`DEC-A-001`** | Kiểu số thực tài chính | - | - | System | Bất biến ở mức DB: kiểu `NUMERIC` | RPC / Edge | - | Decimal string | Decimal parsing | **COVERED** |

---

## D. Đánh Giá Sự Tuân Thủ Các Bản Ghi ADR (ADR Conformance Matrix)

Hệ thống đối soát toàn bộ 7 quyết định kiến trúc cốt lõi đã phê duyệt:

*   **`ADR-001` (Flutter Client) $\rightarrow$ PASS.** Flutter Android chạy ở biên phân hệ ban tổ chức, xác thực thông qua JWT session. Thiết kế đa nền tảng sẵn sàng cho iOS chặng sau (Android-first, not Android-only).
*   **`ADR-002` (Supabase/Postgres backend) $\rightarrow$ PASS.** Hạ tầng tối giản hóa sử dụng gói miễn phí Supabase, tối ưu hóa các RPC chạy lưu trữ SQL để giảm thiểu số lượng Edge Function đồng thời. Định hướng thiết kế là tối giản hóa chi phí khởi chạy (Free-tier-first), không cấu thành một cam kết miễn phí vĩnh viễn (forever-free guarantee) khi quy mô lưu trữ/băng thông thực tế vượt ngưỡng.
*   **`ADR-003` (Boundaries & RLS) $\rightarrow$ PASS.** Phân định rõ 4 ranh giới Class A/B/C/D. RLS đóng vai trò chốt chặn cơ sở dữ liệu cho Class B. Phân chia rõ ràng: `budget_items` và `installments` hỗ trợ Class B mutation trực tiếp của OWNER. `payments` và `refunds` khóa cứng Class B, chỉ cho phép đột biến qua Class C RPC.
*   **`ADR-004` (Organizer Auth & Member) $\rightarrow$ PASS.** Supabase Auth quản lý tài khoản. Tách biệt `auth.users` khỏi thành viên `wedding_members`. Chấp nhận lời mời collaborator so khớp email Google Auth chính xác trước khi reactivate member.
*   **`ADR-005` (Guest Web & Class D) $\rightarrow$ PASS.** React SPA host trên Cloudflare Pages. Fragment `#` trên URL bảo vệ Token. Edge Function Class D băm SHA-256 đối soát an toàn. Cấm vai trò `anon` đọc trực tiếp Postgres.
*   **`ADR-006` (Private Storage & Import) $\rightarrow$ PASS.** Storage lưu file ảnh cưới cấu hình private, sinh Signed URL ngắn hạn chặng Class D. XLSX được client parse và đẩy dạng JSON payload lên Edge để xác nhận import, cấm lưu trữ file Excel thô trên đám mây.
*   **`ADR-007` (Attention Center & Notifications) $\rightarrow$ PASS.** Trung tâm chú ý (Attention Center) hoạt động dựa trên các truy vấn view động (derived views) để cảnh báo đứt gãy dữ liệu (Task quá hạn, Payment lệch đợt, Task gán cho thành viên bị REVOKED). Khước từ hạ tầng đẩy tin (Push Notification/SMS/Email) và AI RAG trong chặng MVP để giữ hệ thống free-tier-first.

---

## E. Đối Soát Kho Dữ Liệu Vật Lý & Errata (Physical Data/Errata Audit)

1.  **Kiểm soát số lượng bảng:** Thiết kế kiến trúc phê duyệt đúng **17 bảng nghiệp vụ** trong schema `public` + **1 bảng kỹ thuật nội bộ** `private.trusted_operation_receipts` nằm trong schema `private`. RLS/Grants vẫn là ranh giới kiểm soát truy cập, việc nằm trong schema `public` không đồng nghĩa với việc cho phép truy cập vãng lai/vô danh.
2.  **Đối soát các Errata vật lý đã tích hợp vào đặc tả:**
    *   `ERRATA-PHY-001` (Composite FK SET NULL): Thiết kế cấu hình chi tiết `ON DELETE SET NULL (columns)` chỉ định để bảo toàn `wedding_id`.
    *   `ERRATA-PHY-003` (Tenant Referential Integrity): Các bảng thực thể con sử dụng khóa ngoại hỗn hợp (composite FK) chứa kèm `wedding_id` để ngăn chặn triệt để kịch bản liên kết dữ liệu chéo đám cưới (cross-wedding linking).
    *   `ERRATA-PHY-004` (Delete Integrity): Khóa ngoại Payment $\rightarrow$ Installment đổi thành `ON DELETE RESTRICT` để bảo toàn lịch sử.
    *   `ERRATA-PHY-007` (Plan Generated Marker): Thay thế boolean bằng `initial_plan_generated_at timestamptz`.
    *   `ERRATA-PHY-008` (DELETING status): Bảng weddings bổ sung trạng thái `DELETING` và check constraint.
    *   `ERRATA-PHY-009` (Trusted Operation Receipts): Bảng `private.trusted_operation_receipts` được khai báo đầy đủ cấu trúc và chỉ số độc lập.

---

## F. Đánh Giá Trạng Thái Vòng Đời Đám Cưới (Lifecycle State Audit)

Vòng đời đám cưới gồm 3 trạng thái: `ACTIVE`, `ARCHIVED`, `DELETING`. Quy tắc kiểm duyệt hành vi chi tiết trong thiết kế kiến trúc:

| Trạng thái Wedding | Đột biến Class B trực tiếp | Nghiệp vụ tin cậy Class C | RSVP Khách Class D | OWNER Delete Recovery |
| :--- | :---: | :---: | :---: | :---: |
| **`ACTIVE`** | 🟢 Cho phép | 🟢 Cho phép | 🟢 Cho phép | - |
| **`ARCHIVED`** | 🔴 Bị chặn (RLS can_mutate) | 🔴 Bị chặn | 🔴 Bị chặn (404 INVITATION) | - |
| **`DELETING`** | 🔴 Bị chặn (RLS can_mutate) | 🔴 Bị chặn thông thường | 🔴 Bị chặn (404 INVITATION) | 🟢 Chỉ cho phép OWNER tiếp tục dọn Storage |

---

## G. Đối Soát Quy Tắc Mốc Ngày & Hạn Chốt (Date/Deadline Audit)

1.  **Độ chính xác ngày cưới:** Đám cưới và Lễ con hỗ trợ song song hai hình thức lưu: Exact Date (`exact_date`) hoặc Expected Month (`expected_year` + `expected_month`). Ràng buộc DB Check constraint thực thi cấu trúc XOR loại trừ lẫn nhau. Cấm sử dụng ngày giả lập (Ví dụ: cấm đặt mặc định ngày 15 khi ở Expected Month).
2.  **Tính tương đối của Task Deadline:** Ngày chốt đầu việc dương lịch (`resolved_deadline_at`) được tính toán tự động dựa trên `deadline_intent` (`SYSTEM_RELATIVE` hoặc `USER_RELATIVE`) phụ thuộc vào ngày sự kiện cưới con.
3.  **Bảo toàn User Intent:** Nếu sự kiện đổi ngày, Task có status = `COMPLETED` sẽ bảo lưu nguyên vẹn ngày chốt lịch sử, cấm ghi đè. Khi hủy sự kiện con (`TOP-EVT-003`), các task tương đối của sự kiện bị hủy được dời lên Wedding-level và tự chuyển sang ngày tuyệt đối hoặc `NO_DEADLINE` tương ứng.

---

## H. Tính Nhất Quán Khóa Ngoại Tenant (Tenant Referential Integrity Audit)

Để bảo vệ cô lập dữ liệu đám cưới tuyệt đối kể cả khi người dùng thuộc nhiều phòng cưới khác nhau:
*   Mọi khóa ngoại liên kết thực thể con đều bắt buộc sử dụng **khóa ngoại phức hợp chứa kèm `wedding_id`** liên kết trực tiếp tới khóa duy nhất tương ứng trên bảng cha (Ví dụ: `FOREIGN KEY (wedding_id, installment_id) REFERENCES installments (wedding_id, id)`).
*   RLS của Supabase chỉ đóng vai trò phân quyền tầng dòng (row security), còn Relational Integrity mức DB (FK Constraints) chịu trách nhiệm tối cao ngăn chặn liên kết rác chéo Wedding.

---

## I. Phân Phối Quyền Hạn Database (Authorization/RLS/Grants Audit - Đã giải quyết `FINAL-ARCH-CONFLICT-001` & `ERRATA-FINAL-001`)

*   **Ranh giới tài chính:** Tránh tình trạng gom toàn bộ Finance thành Class C:
    *   `budget_items`: OWNER được quyền SELECT trực tiếp qua Class B. OWNER cũng được thực hiện các INSERT/UPDATE Class B an toàn đã phê duyệt. Việc xóa cứng (hard-delete) chỉ được phép khi các quy tắc xóa phê duyệt cho phép và không có giao dịch/lịch sử hoặc bất biến hạ lưu nào ngăn chặn. Các hành vi phức hợp, hủy hoại hoặc nhạy cảm lịch sử sẽ chuyển sang kênh Class C.
    *   `installments`: OWNER được quyền SELECT trực tiếp qua Class B. Cho phép OWNER thực hiện create/edit Class B an toàn khi không liên kết với Payment/lịch sử tạo ra tác động phức hợp. Mọi thay đổi hủy hoại hoặc phức hợp liên kết Payment bắt buộc chuyển sang Class C (`TOP-FIN-007`).
    *   `payments` và `refunds`: Khóa cứng toàn bộ các đột biến Class B CUD trực tiếp của client. Bắt buộc sửa đổi/tạo/hủy qua Class C.
    *   *COLLABORATOR:* Bị chặn hoàn toàn quyền đọc/ghi trên toàn bộ các thực thể tài chính nhạy cảm nêu trên.

---

## J. Quyền Hạn Ghi Nguồn Task (Protected Field Authority Audit)

*   Thuộc tính nguồn gốc `task_source` và cờ chỉnh sửa `is_user_modified` là các trường được bảo vệ.
*   **Quy tắc trigger DB:**
    *   Khi client gọi lệnh Class B tạo Task trực tiếp $\rightarrow$ trigger `before_insert_tasks` cưỡng chế gán `task_source = 'USER'` và `is_user_modified = false`.
    *   Khi client gọi lệnh Class B sửa Task $\rightarrow$ trigger `before_update_tasks` tự động gán `is_user_modified = true`.
    *   Chỉ các RPC đặc quyền hệ thống trong schema `internal` mới có năng lực ghi đè các trường này theo template máy chủ tin cậy.

---

## K. Phân Định Ranh Giới Class A/B/C/D (Class A/B/C/D Boundary Audit)

*   **Class A (System-level):** RLS, Postgres Grants, Triggers kiểm soát cứng invariants.
*   **Class B (Direct Data API):** Client đọc/ghi trực tiếp qua Supabase PostgREST trên các bảng được phép (Tasks, Guests, Groups, Budgets/Installments) dựa vào các helper functions: `security.can_mutate_wedding`.
*   **Class C (Organizer API):** Giao thức Edge Functions hoặc RPC api_v1 chịu trách nhiệm thực thi.
*   **Class D (Public Guest Web):** Chốt chặn Edge Function Class D nhận credential fragment, giải mã và đối soát. Cấm vai trò `anon` đọc trực tiếp DB.

---

## L. Đảm Bảo Tính Giao Dịch Nghiệp Vụ (Trusted Operations Audit)

Toàn bộ 24 TOP operations đều tuân thủ chặt chẽ nguyên tắc **Atomicity**. Các thay đổi trên nhiều bảng (ví dụ: gộp khách và gỡ nhóm, tạo thanh toán và cập nhật installment đợt chi) đều được đóng gói trong một transaction duy nhất. Edge Function điều phối Storage cũng tuân thủ thứ tự tuần tự để tránh mồ côi tài nguyên ngoài DB.

---

## M. Kiến Trúc API Khách Mời Class D (Class D API Audit)

*   **An toàn truyền dẫn:** Fragment `#` trên URL không được gửi lên CDN/static host trong tiêu đề HTTP request thông thường. Điều này giúp giảm thiểu nguy cơ rò rỉ mã Token vào CDN logs, CDN cache, hoặc URL/referrer leakage sang trang bên ngoài.
*   **Defense-in-depth:** Fragment đơn lẻ không bảo vệ chống XSS, browser extensions độc hại hoặc client-side telemetry sai. Do đó hệ thống áp dụng các tầng phòng thủ bổ sung: JS đọc fragment trước analytics, replaceState xóa URL thô tức thời, cấm lưu trữ vĩnh viễn ở localStorage (chỉ dùng sessionStorage ngắn hạn cho tab recovery), và Edge Function bắt buộc revalidate token trên từng request của Class D.

---

## N. Kiến Trúc API Ban Tổ Chức Class C (Class C API Audit - Đã giải quyết `ERRATA-CAPI-003`)

*   Thiết kế kiến trúc xác định chính xác cấu hình **31 organizer client-callable surfaces** bao gồm 15 single RPCs, 12 Preview/Commit RPCs và 4 Edge HTTP routes.
*   Thuật ngữ **"organizer client-callable surfaces"** hoặc **"authenticated organizer API/RPC surfaces"** được sử dụng nhất quán để phân biệt rõ ràng với bề mặt gọi vãng lai của khách mời Class D.

---

## O. Cơ Chế Chống Trùng Lặp Yêu Cấu (Retry/Idempotency Audit)

*   **Receipt-backed operations:** TOP-WED-001, TOP-GUE-004, TOP-FIN-001, TOP-FIN-004 sử dụng `request_id` lưu vết receipt trong cùng transaction DB.
*   **Concurrency Guard (Sinh kế hoạch concurrent - `ERRATA-CAPI-001` & `CLASS-C-API-GAP-006`):** Sinh kế hoạch cưới áp dụng invariant concurrency control mức DB. Chỉ cho phép duy nhất 1 transaction chuyển đổi trạng thái `initial_plan_generated_at = NULL` sang timestamp thành công. Yêu cầu concurrent đến sau được giải phóng sẽ trực tiếp đọc dữ liệu kế hoạch vừa sinh, cấm tạo nhân bản.
*   **Lặp lại an toàn (Safe retry):** Lặp lại tạo payment trả về thông tin Payment đã cập nhật mới nhất từ DB (không trả response cache cũ).

---

## P. Đánh Giá Trực Quan Tác Động (Impact Review Audit)

Mẫu thiết kế Preview & Commit chia tách thành 2 API surfaces cho 6 nghiệp vụ nhạy cảm. Dấu vân tay vật lý `impact_fingerprint` hoạt động độc quyền cho mục đích phát hiện stale-state, không dùng làm khóa phân quyền hay idempotency/retry key.

---

## Q. Bảo Toàn Tính Nhất Quán Tài Chính & Người Thanh Toán (Finance Integrity Audit - Đã giải quyết `FINAL-ARCH-CONFLICT-002` & `ERRATA-FINAL-002`)

1.  **Quy tắc Người thanh toán (Payer Semantics):** Payer (Người chi trả thực tế) khác biệt hoàn toàn với Cost Side và Responsible. Người chi trả thực tế **không bắt buộc phải là một WeddingMember**. 
    *   Hệ thống cho phép lưu thông tin hiển thị của người thanh toán ngoài đời thực qua `payer_display_name`.
    *   Trường liên kết thành viên `payer_wedding_member_id` là tùy chọn (nullable). Khi tạo mới hoặc thay đổi gán liên kết, member đích bắt buộc thuộc cùng Wedding và đang ở trạng thái `ACTIVE` tại thời điểm gán.
    *   Nếu thành viên đó chuyển sang `REVOKED` sau này, tham chiếu liên kết lịch sử trong Payment cũ **vẫn được giữ nguyên vẹn**, tuyệt đối không tự động đặt NULL hay từ chối Payment lịch sử vì việc thu hồi này.
    *   Việc xóa vĩnh viễn Wedding gốc vẫn tiếp tục tuân thủ theo các quy tắc xóa gốc đã duyệt.
2.  **Công thức phái sinh (derived views):**
    *   `Net Paid = Active Payments - Active Refunds`.
    *   Nếu Confirmed Cost có giá trị $\rightarrow$ `Outstanding = max(Confirmed Cost - Net Paid, 0)`. Nếu Confirmed Cost chưa chốt (NULL) $\rightarrow$ `Outstanding = UNKNOWN` (Cấm tự tính toán Outstanding dựa trên Estimated Cost).

---

## R. Kiểm Duyệt Nghiệp Vụ Khách Mời & RSVP (Guest/Invitation/RSVP Audit - Đã giải quyết `ERRATA-CAPI-002`)

1.  **Duplicate Signals:** revalidate trùng lặp qua SĐT/Email chỉ sinh cảnh báo warning, không dùng làm định danh duy nhất.
2.  **Party Invited Count:** Hạn mức số người mời thuộc về Party, không tự động tăng/giảm khi di chuyển hay gộp khách.
3.  **RSVP Update Semantics:** Cả Class D và Class C manual RSVP đều dùng cơ chế patch-by-event. RSVP Summary là trường phái sinh tự động tính toán, client cấm tự ghi.
4.  **Guest Merge Retry (`ERRATA-CAPI-002`):** TOP-GUE-003 retry cấm suy luận thành công từ việc biến mất của khách phụ. Hệ thống phải đối soát trạng thái không mơ hồ của khách chính; nếu mơ hồ bắt buộc trả lỗi `STALE_STATE` / `CONFLICT` và chặn thực thi.

---

## S. Kiến Trúc Bộ Nhớ Đệm Ảnh Cưới (Storage/Media Audit)

*   Toàn bộ ảnh cưới lưu trữ private. Guest Web chỉ nhận Signed URL có thời hạn hết hạn ngắn hạn (cấu hình động trên server biên).
*   Quy trình xóa đám cưới `TOP-WED-004` dọn Storage ảnh cưới trước rồi mới cascade xóa DB để tránh mồ côi tài nguyên ngoài DB.

---

## T. Đồng Bộ Danh Mục Mã Lỗi (Error/Warning Audit)

Hệ thống thiết lập danh mục lỗi nghiệp vụ thống nhất cho Class C và Class D, che giấu hoàn toàn SQL detail. Warning được trả về dưới dạng metadata đi kèm success response (Ví dụ: `RSVP_OVERCOUNT` hoặc `schedule_review_warning`), cấm biến warning thành lỗi HTTP làm thất bại giao dịch.

---

## U. Đánh Giá Khả Năng Đáp Ứng Phi Chức Năng (NFR Audit)

Thiết kế kiến trúc của WeddingOS được đánh giá là đã sẵn sàng cho mục tiêu đo kiểm hiệu năng (SUPPORTED / READY FOR BENCHMARK). Các chỉ số phi chức năng đề ra trong REQ-06:
*   *Tốc độ tải danh sách Android:* Target <2 giây.
*   *Tốc độ load thiệp Guest Web:* Target <3 giây trên kết nối 4G.
*   *Nhập Excel:* Target xử lý 300 khách mời <5 giây.

Các con số trên là mục tiêu kỹ thuật đối soát, việc tuân thủ thực tế đòi hỏi chạy benchmark thực tế trên code thực thi ở giai đoạn sau.

---

## V. Tối Ưu Hóa Gói Miễn Phí (Free-Tier-First Audit)

Thiết kế hệ thống tuân thủ chặt chẽ nguyên lý **Free-tier-first** để giảm thiểu tối đa sự phụ thuộc vào các hạ tầng trả phí bắt buộc chặng khởi chạy.
*   Hệ thống không bắt buộc sử dụng hạ tầng Realtime, cron ngầm, Vector DB, LLM hoặc các tổng đài gửi tin nhắn SMS/Email tự động.
*   *Lưu ý vận hành:* Nguyên lý này giảm thiểu rào cản chi phí ban đầu, không cấu thành một cam kết miễn phí vĩnh viễn (forever-free guarantee). Khi lưu lượng sử dụng thực tế (băng thông ảnh cưới, Edge Function runtime, dung lượng lưu trữ DB) vượt quá hạn mức miễn phí của nhà cung cấp dịch vụ đám mây, việc nâng cấp tài khoản trả phí là hoàn toàn bình thường và cần thiết.

---

## W. Ma Trận Đánh Giá Nguy Cơ An Ninh & Lạm Dụng (Security Threat/Abuse Matrix)

| Nguy cơ an ninh (Threat Vector) | Tình huống giả lập (Attack Vector) | Lớp bảo vệ kiến trúc (Protection Layer) | Kết quả an toàn mong đợi |
| :--- | :--- | :--- | :--- |
| **Outsider tấn công API Class C** | Kẻ gian gửi request trực tiếp vào các hàm `api_v1` | Supabase JWT session verification | Bị từ chối ngay lập tức (`419 Unauthorized`). |
| **Collaborator xem lén tài chính** | Thành viên COLLABORATOR SELECT bảng `payments` | RLS check role = OWNER trên bảng members | Bị chặn, cơ sở dữ liệu trả về 0 dòng kết quả. |
| **Collaborator sửa đổi tài chính**| Collaborator gọi trực tiếp RPC `api_v1.create_payment` | RPC internal check `security.can_owner_mutate_wedding`| Bị từ chối thực thi, trả lỗi `INSUFFICIENT_ROLE` (403). |
| **Người dùng phá hoại chéo** | OWNER đám cưới A gửi ID sự kiện đám cưới B vào RPC | DB Composite FK constraint chứa kèm `wedding_id` | Bị từ chối thực thi, DB trả lỗi `CONFLICT` / `FK_VIOLATION`. |
| **Gian lận nguồn gốc công việc**| Flutter truyền `task_source = SYSTEM_TEMPLATE` trực tiếp| DB Trigger `before_insert_tasks_provenance` | Cưỡng chế gán đè `task_source = 'USER'`, bảo vệ provenance. |
| **Giả mạo Actor Edge** | Kẻ gian POST request chứa `actor_user_id` giả lập lên Edge | Edge Function JWT parsing | Edge gạt bỏ trường client gửi, tự lấy ID từ token. |
| **Spoof Actor RPC nội bộ** | Kẻ gian gọi trực tiếp hàm SQL nội bộ trong `internal` | Lớp schema `internal` thu hồi EXECUTE của public roles | Bị chặn từ chối thực thi mức cơ sở dữ liệu. |
| **Dò quét lời mời** | Kẻ gian gọi Accept lời mời với email tùy ý | RPC `accept_pending_invitation` so khớp Google Auth email | Bị từ chối, trả về lỗi `INVITATION_NOT_CLAIMABLE`. |
| **Thu hồi OWNER cuối cùng** | OWNER duy nhất của phòng cưới tự gọi lệnh xóa mình | RPC check count(OWNER) của wedding | Bị từ chối thực thi, trả lỗi `FINAL_OWNER_INVARIANT` (400). |
| **Đột biến phòng cưới đang xóa**| OWNER gửi sửa Task khi đám cưới đang ở status `DELETING`| Hàm RLS `security.can_mutate_wedding` check status ACTIVE | Bị chặn từ chối thực thi do status không phải ACTIVE. |
| **Khách vãng lai đọc trộm DB** | Guest Web gửi query PostgREST trực tiếp vào bảng `guests` | RLS khóa toàn bộ quyền của vai trò `anon` | Bị từ chối mức cơ sở dữ liệu. |
| **Khách gửi RSVP sau hạn chốt** | Khách gọi `D-RSV-001` vượt quá ngày `rsvp_cutoff_date` | Edge check thời gian server trước start of next local day | Bị từ chối thực thi, trả lỗi `RSVP_CLOSED` (403). |
| **Lần mò token ngẫu nhiên** | Bot quét dò tìm credential ngẫu nhiên qua Class D | SHA-256 đối soát + Edge Rate Limiting (HTTP 429) | Trả về 404 INVITATION_UNAVAILABLE đồng nhất. |
| **Tái sử dụng request ID đúp tiền**| Gọi lại lệnh tạo Payment trùng `request_id` nhưng lệch payload | DB receipt check `request_hash` so khớp | Bị từ chối thực thi, trả lỗi `REQUEST_ID_REUSED` (409). |

---

## X. Danh Mục Quyết Định Hoãn Lại (Deferred Decision Register)

Các quyết định thiết kế chi tiết dưới đây được hoãn lại phục vụ triển khai chặng sau:

### Nhóm A: Bắt buộc quyết định trước khi chạy Migration DB đầu tiên
*   `DEC-A-001`: Độ chính xác và thang chia tỉ lệ vật lý của trường `NUMERIC` cơ sở dữ liệu (Authoritative Decimal precision/scale, ví dụ: `numeric(15,2)` hay `numeric(19,4)`). Việc sử dụng kiểu dữ liệu `NUMERIC` và Decimal string đã được duyệt cố định, cấm dùng kiểu float nhạy sai số.
*   `DEC-A-002`: Sơ đồ phân vùng bảng dữ liệu vật lý nếu có (Partitioning) chặng tải lớn.
*   `DEC-A-003`: Cấu trúc phân quyền quyền sở hữu schema PostgreSQL (Database Owner/Execution role).

### Nhóm B: Bắt buộc quyết định trước khi triển khai tính năng liên quan
*   `DEC-B-001`: Định dạng cấu trúc tóm tắt cấu hình template đầu việc (`SYSTEM_TEMPLATE` config format).
*   `DEC-B-002`: Cơ chế mã hóa và độ dài entropy thực tế của Token thiệp mời Class D.
*   `DEC-B-003`: Cấu trúc đường dẫn thư mục private Storage bucket cho đám cưới.
*   `DEC-B-004`: Các ngưỡng giới hạn Rate Limiting thực tế cho Edge Class D và Class C.

### Nhóm C: Chi tiết triển khai an toàn (Safe Implementation Details)
*   `DEC-C-001`: Thư viện parse tệp Excel `.xlsx` chạy trên client di động.
*   `DEC-C-002`: Thuật toán serialize chuẩn hóa dữ liệu thô phục vụ băm request_hash.
*   `DEC-C-003`: Quy chuẩn đặt tên tệp mã nguồn lưu trữ Edge Functions và RPC function names.
*   `DEC-C-004`: Cơ chế CI/CD deploy mã nguồn lên Supabase và Cloudflare Pages.
*   `DEC-C-005`: Tên ràng buộc khóa ngoại (constraint names) và chỉ mục index chi tiết.

### Nhóm D: Nghiệp vụ hoãn lại sau MVP (Post-MVP / Deferred Features)
*   `DEC-D-001`: Tích hợp hạ tầng đẩy thông báo (Push Notification/Zalo/Email).
*   `DEC-D-002`: Tích hợp AI gợi ý đầu việc hoặc phân tích chi phí thông minh.
*   `DEC-D-003`: Đồng bộ dữ liệu ngoại tuyến (Offline sync) mức nâng cao cho thiết bị di động.

---

## Y. Danh Mục Tổng Hợp Lỗi & Khoảng Trống Kiến Trúc (Consolidated Conflict/Gap Register)

Hệ thống ghi nhận và xác minh trạng thái giải quyết cho toàn bộ các Gap/Conflict lịch sử:

*   **`OPEN-DATA-001` (Finance Transaction Semantics) $\rightarrow$ RESOLVED** qua Controlled Edit + Void. (Đặc tả: 04 Physical Design).
*   **`PHYSICAL-DATA-GAP-008` (Task Assignee) $\rightarrow$ RESOLVED** qua cột `assignee_wedding_member_id` và check constraint cùng Wedding. (Đặc tả: 04 Physical Design).
*   **`PHYSICAL-DATA-GAP-009` (Finance Responsible) $\rightarrow$ RESOLVED** qua cột `responsible_wedding_member_id` trên `budget_items`. (Đặc tả: 04 Physical Design).
*   **`PHYSICAL-DATA-GAP-010` (RSVP optional fields) $\rightarrow$ RESOLVED** qua `companion_names`, `dietary_info`, và `guest_message` trên `rsvps`. (Đặc tả: 04 Physical Design).
*   **`PHYSICAL-DATA-GAP-011` (Invitation lifecycle tracking) $\rightarrow$ RESOLVED** qua tách biệt status thiệp và các mốc xem. (Đặc tả: 04 Physical Design).
*   **`PHYSICAL-DATA-GAP-012` (Guest normalized email) $\rightarrow$ RESOLVED** qua index không unique. (Đặc tả: 04 Physical Design).
*   **`PHYSICAL-DATA-GAP-013` (Membership revocation historical reference) $\rightarrow$ RESOLVED** qua bảo lưu quan hệ cũ. (Đặc tả: 04 Physical Design).
*   **`PHYSICAL-DATA-CONFLICT-001` (Invitation lifecycle status) $\rightarrow$ RESOLVED** qua loại bỏ trạng thái REVOKED trên thiệp. (Đặc tả: 04 Physical Design).
*   **`ERRATA-PHY-001` (Composite FK SET NULL protection) $\rightarrow$ RESOLVED** qua ràng buộc cột cụ thể. (Đặc tả: 04 Physical Design).
*   **`ERRATA-PHY-003` (Tenant Referential Integrity) $\rightarrow$ RESOLVED** qua composite FK mức DB. (Đặc tả: 04 Physical Design).
*   **`ERRATA-PHY-004` (Payment Delete RESTRICT) $\rightarrow$ RESOLVED** qua ON DELETE RESTRICT. (Đặc tả: 04 Physical Design).
*   **`ERRATA-PHY-007` (Initial Plan marker) $\rightarrow$ RESOLVED** qua `initial_plan_generated_at`. (Đặc tả: 04 Physical Design).
*   **`ERRATA-PHY-008` (DELETING status) $\rightarrow$ RESOLVED** qua status `DELETING`. (Đặc tả: 04 Physical Design).
*   **`ERRATA-PHY-009` (Durable receipts) $\rightarrow$ RESOLVED** qua `private.trusted_operation_receipts`. (Đặc tả: 04 Physical Design).
*   **`RLS-AUTH-GAP-001` (Finance write restriction) $\rightarrow$ RESOLVED** qua khóa Class B CUD tài chính. (Đặc tả: 05 RLS Design).
*   **`RLS-AUTH-GAP-002` (Guest direct DB SQL access) $\rightarrow$ RESOLVED** qua khóa vai trò anon. (Đặc tả: 05 RLS Design).
*   **`ERRATA-RLS-001` (Provenance triggers superuser privilege) $\rightarrow$ RESOLVED** qua DB trigger hẹp. (Đặc tả: 05 RLS Design).
*   **`TRUSTED-OP-CONFLICT-004` (Safe retry lock-in) $\rightarrow$ RESOLVED** qua chốt hội tụ nghiệp vụ thay vì công cụ. (Đặc tả: 06 Trusted Operations).
*   **`CLASS-D-API-GAP-001` (Social preview bot scan) $\rightarrow$ RESOLVED** qua phục vụ preview dạng chung. (Đặc tả: 07 Class D Design).
*   **`CLASS-C-API-GAP-005` (Surface count consistency) $\rightarrow$ RESOLVED** qua đặc tả **31 surfaces** thống nhất 1-1. (Đặc tả: 08 Class C Design).
*   **`CLASS-C-API-GAP-006` (Concurrent Initial Plan Generation) $\rightarrow$ RESOLVED** qua DB-level lock/concurrency control. (Đặc tả: 08 Class C Design).
*   **`CLASS-C-API-CONFLICT-001` (Raw payload vs semantic hash) $\rightarrow$ RESOLVED** qua chuẩn hóa ngữ nghĩa payload. (Đặc tả: 08 Class C Design).
*   **`FINAL-ARCH-CONFLICT-001` (Finance Class-B/C Boundary overgeneralization) $\rightarrow$ RESOLVED.** Xác định ngân sách/đợt trả có đột biến Class B OWNER, chỉ khóa payments/refunds bắt buộc Class C. (Tài liệu đối chiếu: [`05 RLS & Authorization`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/05-rls-and-authorization-design.md)).
*   **`FINAL-ARCH-CONFLICT-002` (Payer Constrained to WeddingMember) $\rightarrow$ RESOLVED.** Cho phép người thanh toán ngoài đời thực không là thành viên qua `payer_display_name`, gán member chỉ bắt buộc ACTIVE tại thời điểm chọn và bảo lưu lịch sử khi REVOKED. (Tài liệu đối chiếu: [`04 Physical Design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/04-postgresql-physical-design.md)).
*   **`ERRATA-FINAL-001` (Finance Class-B Mutation Wording) $\rightarrow$ RESOLVED.** Chuẩn hóa mô tả Class B/C boundary đối với budget_items và installments. (Tài liệu đối chiếu: [`09 Technical Architecture Final Review`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/09-technical-architecture-final-review.md)).
*   **`ERRATA-FINAL-002` (Historical Payer Member Reference) $\rightarrow$ RESOLVED.** Chuẩn hóa liên kết payer member khi bị REVOKED hoặc người thanh toán không thuộc member. (Tài liệu đối chiếu: [`09 Technical Architecture Final Review`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/09-technical-architecture-final-review.md)).

---

## Z. Đánh Giá Điều Kiện Sẵn Sàng Thực Thi (Implementation Readiness Gate)

Hệ thống đánh giá sự sẵn sàng dựa trên 10 tiêu chí an toàn bắt buộc:

1.  **Không có mâu thuẫn yêu cầu nghiệp vụ chưa giải quyết?** $\rightarrow$ **PASS** (Đã giải quyết `FINAL-ARCH-CONFLICT-001` và `002`).
2.  **Không có khoảng trống cô lập tenant chéo đám cưới?** $\rightarrow$ **PASS** (Đã giải quyết qua composite FKs).
3.  **Không có khoảng trống phân quyền ban tổ chức?** $\rightarrow$ **PASS** (Đã bảo vệ bằng RLS check member và RPC role checking).
4.  **Không có nguy cơ client tự sửa provenance hoặc cờ hệ thống?** $\rightarrow$ **PASS** (Bảo vệ qua trigger DB và schema internal).
5.  **Không có nguy cơ phá vỡ tính nhất quán tài chính?** $\rightarrow$ **PASS** (Các view Net Paid, Outstanding, Projected Cost được tính toán authoritative).
6.  **Không có nguy cơ client Flutter tự tạo Guest/Party sai ranh giới?** $\rightarrow$ **PASS**.
7.  **Không có nguy cơ lặp lại đúp tiền hoặc đúp phòng cưới?** $\rightarrow$ **PASS** (Kiểm soát qua bảng biên nhận `private.trusted_operation_receipts`).
8.  **Có cơ chế phục hồi khi dọn dẹp Storage lúc xóa cưới thất bại?** $\rightarrow$ **PASS** (Đám cưới giữ trạng thái `DELETING` cho OWNER retry dọn lại).
9.  **Ranh giới Class C và Class D bảo vệ an toàn DB chống truy cập SQL trực tiếp?** $\rightarrow$ **PASS** (anon bị khóa cứng, Edge/RPC làm trung gian).
10. **Tất cả các quyết định hoãn lại có phân loại và kiểm soát rõ ràng?** $\rightarrow$ **PASS** (Khai báo tại Mục X).

**ĐÁNH GIÁ CHUNG:** **PASS** (Hệ thống vượt qua toàn bộ 10/10 điều kiện sẵn sàng triển khai kiến trúc. Thiết kế kiến trúc sẵn sàng chuyển tiếp sang chặng xây dựng backlog).

---

## AA. Khuyến Nghị Giai Đoạn Kế Tiếp (Final Recommendation)

> [!IMPORTANT]
> **Technical Architecture Final Review $\rightarrow$ APPROVED (Đồng ý thông qua)**
> Kiến trúc kỹ thuật của hệ thống WeddingOS đã đạt độ trưởng thành cao, nhất quán, sẵn sàng thực thi và không còn khoảng trống bảo mật hay mâu thuẫn nghiệp vụ. 
> **Khuyến nghị giai đoạn tiếp theo:** Chuyển sang phase **Xây dựng Backlog MVP & Kế hoạch Triển khai Thực thi (MVP Backlog & Implementation Planning)** để định hình Sprint và bắt đầu triển khai code thực tế.
