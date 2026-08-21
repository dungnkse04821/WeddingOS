# Kế Hoạch Lập Bản: 10 — Danh Mục Backlog MVP (MVP Backlog)

*   **Trạng thái (Status):** APPROVED (Đã Phê duyệt)
*   **Người thực hiện:** Antigravity (AI Architect)
*   **Ngày cập nhật:** 21/08/2026

---

> [!IMPORTANT]
> **NON-EXECUTABLE BACKLOG SPECIFICATION**
> Tài liệu này đại diện cho danh mục công việc bàn giao MVP (MVP Backlog) được phân nhỏ từ các yêu cầu và đặc tả kiến trúc đã phê duyệt. Tài liệu này phục vụ cho việc quản lý tiến độ và kiểm tra chất lượng thực thi, không chứa mã nguồn thực thi hay kịch bản kiểm thử chạy trực tiếp.

---

## A. Phạm Vi Phiên Bản Tối Thiểu (MVP Scope)

Danh mục Backlog này bao gồm toàn bộ các tính năng cốt lõi được Product Owner phê duyệt trong phạm vi MVP nhằm tối giản hóa chi phí vận hành (Free-tier-first) và tập trung vào trải nghiệm người dùng ban tổ chức (Android) kết hợp phản hồi khách mời (Guest Mobile Web):

*   **NẰM TRONG MVP (IN MVP):**
    1.  Tạo và quản lý không gian đám cưới (Wedding Workspace) với 3 trạng thái: `ACTIVE`, `ARCHIVED`, `DELETING`.
    2.  Hệ thống lập kế hoạch: Task tương đối theo ngày lễ cưới con, tính tương đối của deadline phụ thuộc vào `deadline_intent` và ngày lễ con.
    3.  Tài chính: OWNER quản lý budget và installments trực tiếp qua Class B API (phân quyền RLS). Giao dịch chi tiêu Payments và Refunds được bảo vệ hoàn toàn qua Class C RPC chống lặp (Receipt-backed), so khớp người thanh toán (ACTIVE member hoặc non-member qua display name).
    4.  Khách mời: CRUD khách mời, quản lý Party/Group, gộp khách trùng lặp (TOP-GUE-003) và nhập lô Excel parse local (TOP-GUE-004).
    5.  Thiệp khách mời Class D: React SPA tĩnh trên Cloudflare Pages đọc fragment URL (`#`), đối soát SHA-256 qua Class D Edge, thực hiện patch-by-event RSVP và hiển thị thông tin VietQR khi hoàn tất RSVP.
    6.  Storage: Lưu ảnh cưới private, Signed URL ngắn hạn cho khách xem, cơ chế OWNER dọn dẹp Storage khi xóa cưới.
    7.  Attention Center: Views động cảnh báo Task quá hạn, member bị Revoked, Payment lệch lịch biểu.

*   **NẰM NGOÀI MVP (OUT / POST-MVP):**
    *   Hạ tầng đẩy thông báo tự động (Push Notifications, SMS tự động, Email tự động).
    *   Cơ sở dữ liệu Vector DB, LLM gợi ý AI hoặc RAG running tasks.
    *   Đồng bộ offline nâng cao cho app di động (offline sync engine).
    *   Supabase Realtime subscriptions (client Flutter dùng pull-to-refresh).

---

## B. Danh Mục Epic MVP (Epic Inventory)

Bản backlog được phân rã thành **14 Epics** độc lập, bảo toàn mối quan hệ phụ thuộc ngược từ hạ tầng nền móng đến các nghiệp vụ phức tạp:

*   **`EPIC-00`:** Engineering & Environment Foundation (Thiết lập môi trường & hạ tầng kỹ thuật).
*   **`EPIC-01`:** Organizer Authentication & Wedding Workspace (Xác thực ban tổ chức & Không gian làm việc).
*   **`EPIC-02`:** Wedding Foundation / Onboarding / Initial Plan (Khởi tạo đám cưới & Sinh kế hoạch mẫu).
*   **`EPIC-03`:** Planning / Tasks / Events (Quản lý sự kiện & đầu việc).
*   **`EPIC-04`:** Collaborators & Member Management (Cộng tác viên & thành viên đám cưới).
*   **`EPIC-05`:** Guest Management / Parties / Groups (Quản lý khách mời, Nhóm & Party).
*   **`EPIC-06`:** Invitation & Guest Web Bootstrap (Khởi tạo credential thiệp & Guest Web tĩnh).
*   **`EPIC-07`:** RSVP / Cutoff / Guest Gift / VietQR (Khách RSVP, Hạn chốt & Mừng cưới VietQR).
*   **`EPIC-08`:** Finance / Budget / Installments / Payments / Refunds (Quản lý tài chính).
*   **`EPIC-09`:** Excel Guest Import (Nhập lô khách mời qua Excel).
*   **`EPIC-10`:** Media / Storage (Lưu trữ hình ảnh private & Signed URLs).
*   **`EPIC-11`:** Wedding Lifecycle / Archive / Permanent Delete (Vòng đời đám cưới).
*   **`EPIC-12`:** Cross-cutting UX / Attention / Wedding Switcher (Giao diện tổng quan & Cảnh báo).
*   **`EPIC-13`:** Security / Reliability / Performance / Release Readiness (Kiểm thử bảo mật & Hiệu năng).

---

## C. Quy Ước Đặt Tên & Thuộc Tính Backlog (Backlog Conventions)

*   **Mã Story:** `STORY-[EPIC_NUM]-[STORY_SEQ]` (Ví dụ: `STORY-01-01`).
*   **Mã Công việc Kỹ thuật:** `TECH-[EPIC_NUM]-[TASK_SEQ]` (Công việc backend, DB, RLS).
*   **Mã Công việc Kiểm thử:** `TEST-[EPIC_NUM]-[TEST_SEQ]` (Bảo đảm chất lượng & bảo mật).
*   **Trạng thái mặc định:** `PLANNED` (Đang lập kế hoạch).
*   **Độ phức tạp tương đối:** Phân chia theo kích cỡ áo thun (`XS`, `S`, `M`, `L`, `XL`), đánh giá độ khó và rủi ro kỹ thuật, hoàn toàn không đại diện cho thời gian ngày/giờ.
*   **Độ ưu tiên:** 
    *   `P0`: Công việc bắt buộc của MVP, mang tính sống còn đối với sự phụ thuộc hạ tầng hoặc nằm trên luồng phát hành cốt lõi.
    *   `P1`: Công việc bắt buộc của MVP, có thể triển khai sau P0 nhưng vẫn bắt buộc phải hoàn thành trước khi phát hành MVP (trừ khi có descopes rõ ràng từ PO).
    *   `P2`: Công việc MVP có độ ưu tiên thấp hơn (nếu có, không áp dụng cho chặng MVP hiện tại).

---

## D. Danh Sách Chi Tiết Story Backlog (Full Story Backlog)

### EPIC-00: Engineering & Environment Foundation
#### `STORY-00-01`: Thiết lập dự án và Cấu trúc thư mục DB/Edge/Client
*   **Epic:** `EPIC-00`
*   **Kết quả Nghiệp vụ:** Tạo lập môi trường mã nguồn đồng bộ cho Flutter, React SPA, Supabase Edge Functions và PostgreSQL migrations.
*   **Mã Yêu cầu nguồn:** `REQ-06-NFR`
*   **Tham chiếu Kiến trúc:** [`02-logical-architecture`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/02-logical-architecture.md), [`ADR-001`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/adr/ADR-001-client-platform-and-flutter.md), [`ADR-002`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/adr/ADR-002-backend-platform-and-postgresql.md)
*   **Vai trò (Actor):** Developer / Infrastructure
*   **Phân lớp Bảo mật:** `Infrastructure`
*   **Client:** `None/backend`
*   **Bề mặt Backend:** `None`
*   **Phụ thuộc (Dependencies):** Không có
*   **Độ ưu tiên:** `P0`
*   **Độ phức tạp:** `S`
*   **Tiêu chí Chấp nhận:**
    *   Khởi tạo dự án Flutter chạy tốt trên Android simulator.
    *   Khởi tạo dự án React/Vite build tĩnh thành công.
    *   Cài đặt Supabase CLI và kiểm tra kết nối local container.
*   **Nghĩa vụ Bảo mật/Idempotency:** N/A
*   **Nhiệm vụ kiểm thử (Test Obligations):** Xác minh biên dịch (compile check).
*   **Quyết định hoãn chặn (Blocking Dec):** `DEC-A-001`, `DEC-A-002`, `DEC-A-003` (Chốt trước migration DB đầu tiên).
*   **Nhiệm vụ kỹ thuật:**
    *   `TECH-00-01`: Khởi tạo monorepo workspace.
    *   `TECH-00-02`: Thiết lập khung dự án Flutter Android.
    *   `TECH-00-03`: Thiết lập khung dự án Guest Web React/Vite.
    *   `TEST-00-01`: Chạy thành công build pipeline trên môi trường CI/CD giả lập.

---

### EPIC-01: Organizer Authentication & Wedding Workspace
#### `STORY-01-01`: Đăng nhập Ban tổ chức và So khớp định danh thành viên
*   **Epic:** `EPIC-01`
*   **Kết quả Nghiệp vụ:** Người dùng đăng nhập qua Google Auth, tự động lấy thông tin email để so khớp danh sách lời mời đám cưới đang chờ (`PENDING`).
*   **Mã Yêu cầu nguồn:** `REQ-01-001`, `REQ-04-002`
*   **Tham chiếu Kiến trúc:** [`ADR-004`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/adr/ADR-004-organizer-authentication.md), [`05-rls-and-authorization-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/05-rls-and-authorization-design.md)
*   **Vai trò (Actor):** Người dùng ban tổ chức (Google Auth user)
*   **Phân lớp Bảo mật:** `Class B` (Đọc danh sách member) + `Class C` (Accept pending)
*   **Client:** `Flutter`
*   **Bề mặt Backend:** `api_v1 RPC` (accept invitation), `Data API` (select members)
*   **Phụ thuộc (Dependencies):** `STORY-00-01`
*   **Độ ưu tiên:** `P0`
*   **Độ phức tạp:** `M`
*   **Tiêu chí Chấp nhận:**
    *   Đăng nhập Google Auth trả về JWT chứa email chính xác.
    *   So khớp email này với bảng `pending_collaborator_invitations` để hiển thị danh sách lời mời.
*   **Nghĩa vụ Bảo mật & Idempotency:** Giải mã email từ JWT hệ thống, cấm nhận email tùy ý từ client gửi lên để gán quyền. `accept_pending_invitation` là idempotent hoặc unique state activation.
*   **Nhiệm vụ kiểm thử (Test Obligations):**
    *   `TEST-01-01`: Kiểm thử RLS ngăn chặn người dùng chưa đăng nhập SELECT thành viên.
    *   `TEST-01-02`: Kiểm thử gọi accept trên token sai định dạng/hết hạn.
*   **Quyết định hoãn chặn (Blocking Dec):** N/A
*   **Nhiệm vụ kỹ thuật:**
    *   `TECH-01-01`: Tạo bảng `wedding_members` và `pending_collaborator_invitations` cùng RLS tương ứng.
    *   `TECH-01-02`: Tạo RPC `api_v1.list_my_pending_invitations` (`TRD-MEM-001`) trả danh sách.
    *   `TECH-01-03`: Tạo RPC `api_v1.accept_pending_invitation` (`TOP-MEM-003`).

---

### EPIC-02: Wedding Workspace Foundation & Initial Plan
#### `STORY-02-01`: Khởi tạo đám cưới mới và Sinh kế hoạch cưới mẫu (First Vertical Slice)
*   **Epic:** `EPIC-02`
*   **Kết quả Nghiệp vụ:** Cặp đôi tạo đám cưới mới, chỉ định ngày cưới hoặc khoảng tháng dự kiến, và kích hoạt sinh kế hoạch cưới mẫu đồng thời không bị đúp đầu việc.
*   **Mã Yêu cầu nguồn:** `REQ-01-001`, `REQ-02-001`
*   **Tham chiếu Kiến trúc:** [`04-postgresql-physical-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/04-postgresql-physical-design.md), [`08-class-c-organizer-api-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/08-class-c-organizer-api-design.md)
*   **Vai trò (Actor):** Cặp đôi (Khách vãng lai đã login $\rightarrow$ OWNER)
*   **Phân lớp Bảo mật:** `Class C` (Tạo cưới qua receipt & Sinh kế hoạch qua Edge đặc quyền)
*   **Client:** `Flutter`
*   **Bề mặt Backend:** `api_v1.create_wedding` (RPC), `/v1/organizer/weddings/plan` (Edge Function)
*   **Phụ thuộc (Dependencies):** `STORY-01-01`
*   **Độ ưu tiên:** `P0`
*   **Độ phức tạp:** `L`
*   **Tiêu chí Chấp nhận:**
    *   Tạo thành công bản ghi Wedding kèm bản ghi thành viên role = OWNER trong cùng một transaction nguyên tử.
    *   Yêu cầu sinh kế hoạch mẫu (`TOP-WED-002`) chỉ thực thi đúng 1 lần bằng cơ chế kiểm soát đồng thời mức DB (DB-level concurrency control), ghi nhận `initial_plan_generated_at`. Luồng gửi đồng thời thứ hai trả về kế hoạch hiện tại, cấm sinh đúp Task.
*   **Nghĩa vụ Bảo mật & Concurrency:** Sử dụng `request_id` lưu vết biên nhận trong `private.trusted_operation_receipts` trong cùng giao dịch tạo Wedding để ngăn chi/tạo đúp. Áp dụng DB lock cho dòng `weddings` để ngăn race condition.
*   **Nhiệm vụ kiểm thử (Test Obligations):**
    *   `TEST-02-01`: Giả lập 2 request sinh kế hoạch cùng lúc để kiểm tra concurrency guard.
    *   `TEST-02-02`: Gọi lại tạo Wedding trùng `request_id` -> replay kết quả, cấm tạo đúp.
    *   `TEST-02-03`: Gọi lại tạo với payload khác nhưng trùng `request_id` -> lỗi `REQUEST_ID_REUSED`.
*   **Quyết định hoãn chặn (Blocking Dec):** `DEC-B-001` (Cấu trúc file template).
*   **Nhiệm vụ kỹ thuật:**
    *   `TECH-02-01`: Tạo bảng `weddings` và trigger gán quyền OWNER tự động cho người tạo.
    *   `TECH-02-02`: Viết RPC `api_v1.create_wedding` tích hợp kiểm tra receipt chống trùng lặp.
    *   `TECH-02-03`: Viết Edge Function sinh kế hoạch cưới, gọi DB internal để chốt trạng thái `initial_plan_generated_at`.

---

### EPIC-03: Planning / Tasks / Events
#### `STORY-03-01`: Quản lý Công việc thông thường và Tính toán hạn chốt tương đối
*   **Epic:** `EPIC-03`
*   **Kết quả Nghiệp vụ:** Thành viên OWNER/COLLABORATOR quản lý danh mục công việc (Tasks), hệ thống tự động gán nguồn gốc `task_source` và tính toán hạn dương lịch tương đối theo ngày lễ cưới con.
*   **Mã Yêu cầu nguồn:** `REQ-02-001`, `REQ-06-001`
*   **Tham chiếu Kiến trúc:** [`04-postgresql-physical-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/04-postgresql-physical-design.md), [`06-trusted-operations-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/06-trusted-operations-design.md)
*   **Vai trò (Actor):** OWNER / COLLABORATOR
*   **Phân lớp Bảo mật:** `Class B` (CUD công việc trực tiếp bảo vệ bởi RLS)
*   **Client:** `Flutter`
*   **Bề mặt Backend:** `Data API` (PostgREST direct insert/update)
*   **Phụ thuộc (Dependencies):** `STORY-02-01`
*   **Độ ưu tiên:** `P0`
*   **Độ phức tạp:** `M`
*   **Tiêu chí Chấp nhận:**
    *   Khi INSERT Task qua Class B, trigger DB gán `task_source = 'USER'` và `is_user_modified = false`.
    *   Khi UPDATE bất kỳ trường nào của Task qua Class B, trigger DB tự động gán `is_user_modified = true`.
    *   Task Deadline được tính dựa trên offset dương lịch tương đối so với sự kiện con liên kết khi `deadline_intent = 'SYSTEM_RELATIVE'` hoặc `'USER_RELATIVE'`.
*   **Nghĩa vụ Bảo mật & Integrity:** RLS chặn ghi Tasks nếu user không là thành viên đám cưới đó. Composite FK (`wedding_id`, `wedding_event_id`) ngăn gán Task vào Event của đám cưới khác.
*   **Nhiệm vụ kiểm thử (Test Obligations):**
    *   `TEST-03-01`: Kiểm thử sửa đổi Task qua PostgREST đảm bảo `is_user_modified` chuyển sang `true`.
    *   `TEST-03-02`: Kiểm thử chéo tenant: chèn task có `wedding_event_id` của đám cưới B vào đám cưới A -> DB báo lỗi.
*   **Quyết định hoãn chặn (Blocking Dec):** N/A
*   **Nhiệm vụ kỹ thuật:**
    *   `TECH-03-01`: Tạo bảng `tasks` kèm composite FK và các check constraints của deadline.
    *   `TECH-03-02`: Viết DB Triggers `before_insert_tasks` và `before_update_tasks` kiểm soát provenance.
    *   `TECH-03-03`: Viết hàm SQL tự động phân giải `resolved_deadline_at` khi ngày của `wedding_events` thay đổi.

#### `STORY-03-02`: Chuyển đổi ngày sự kiện và Hủy sự kiện con (Preview & Commit)
*   **Epic:** `EPIC-03`
*   **Kết quả Nghiệp vụ:** Khi ban tổ chức dời ngày cưới hoặc hủy lễ cưới con, hệ thống cung cấp màn hình Preview các công việc bị ảnh hưởng kèm dấu vân tay `impact_fingerprint` trước khi xác nhận Commit.
*   **Mã Yêu cầu nguồn:** `REQ-02-002`, `REQ-02-003`
*   **Tham chiếu Kiến trúc:** [`06-trusted-operations-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/06-trusted-operations-design.md), [`08-class-c-organizer-api-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/08-class-c-organizer-api-design.md)
*   **Vai trò (Actor):** OWNER / COLLABORATOR
*   **Phân lớp Bảo mật:** `Class C` (Preview/Commit RPCs)
*   **Client:** `Flutter`
*   **Bề mặt Backend:** `api_v1.preview_event_date_change`, `api_v1.commit_event_date_change`
*   **Phụ thuộc (Dependencies):** `STORY-03-01`
*   **Độ ưu tiên:** `P1`
*   **Độ phức tạp:** `L`
*   **Tiêu chí Chấp nhận:**
    *   Commit thay đổi chỉ được thực thi nếu `impact_fingerprint` gửi lên khớp với tính toán thực tế tại thời điểm ghi nhận (ngăn chặn stale-state).
    *   Khi đổi ngày cưới, Task có status = `COMPLETED` sẽ bảo lưu lịch sử hạn cũ, không bị ghi đè.
    *   Khi hủy lễ con, dời các Task tự tạo (USER) lên cấp Wedding và bảo lưu trạng thái nguyên vẹn.
*   **Nghĩa vụ Bảo mật & Concurrency:** Tính toán dấu vân tay `impact_fingerprint` ở server-side và đối soát tại bước Commit. Chặn đè stale-state.
*   **Nhiệm vụ kiểm thử (Test Obligations):**
    *   `TEST-03-03`: Test gọi commit dời ngày với vân tay đã cũ (do có OWNER khác vừa sửa Task) $\rightarrow$ Đảm bảo trả lỗi `STALE_STATE` (409).
    *   `TEST-03-04`: Test dời ngày cưới xác nhận `COMPLETED` tasks không bị sửa deadline.
*   **Quyết định hoãn chặn (Blocking Dec):** N/A
*   **Nhiệm vụ kỹ thuật:**
    *   `TECH-03-04`: Viết RPC preview và tính băm `impact_fingerprint`.
    *   `TECH-03-05`: Viết RPC commit dời ngày sự kiện (`TOP-EVT-002`) và commit hủy sự kiện (`TOP-EVT-003`).

---

### EPIC-04: Collaborators & Member Management
#### `STORY-04-01`: OWNER tạo và thu hồi lời mời cộng tác viên
*   **Epic:** `EPIC-04`
*   **Kết quả Nghiệp vụ:** OWNER gửi lời mời cộng tác viên qua email (`pending_collaborator_invitations`) và có quyền thu hồi khi lời mời chưa được chấp nhận.
*   **Mã Yêu cầu nguồn:** `REQ-04-002`
*   **Tham chiếu Kiến trúc:** [`05-rls-and-authorization-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/05-rls-and-authorization-design.md), [`08-class-c-organizer-api-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/08-class-c-organizer-api-design.md)
*   **Vai trò (Actor):** OWNER
*   **Phân lớp Bảo mật:** `Class C` (Tạo/Hủy lời mời qua RPCs)
*   **Client:** `Flutter`
*   **Bề mặt Backend:** `api_v1` RPCs (`create_pending_invitation`, `revoke_pending_invitation`)
*   **Phụ thuộc (Dependencies):** `STORY-01-01`
*   **Độ ưu tiên:** `P1`
*   **Độ phức tạp:** `S`
*   **Tiêu chí Chấp nhận:**
    *   Chỉ OWNER được quyền tạo và thu hồi dòng trong `pending_collaborator_invitations`.
    *   Ngăn chặn gửi trùng lời mời khi email đích đã có trạng thái `PENDING` hoạt động.
*   **Nghĩa vụ Bảo mật & Idempotency:** RLS chặn trực tiếp PostgREST CUD trên bảng pending invitations. RPC gạt bỏ các email sai định dạng.
*   **Nhiệm vụ kiểm thử (Test Obligations):**
    *   `TEST-04-01`: Đảm bảo Collaborator cố tạo/thu hồi lời mời bị từ chối.
    *   `TEST-04-02`: Test thu hồi lời mời thành công chuyển trạng thái dòng thành `REVOKED`.
*   **Quyết định hoãn chặn (Blocking Dec):** N/A
*   **Nhiệm vụ kỹ thuật:**
    *   `TECH-04-01`: Tạo bảng `pending_collaborator_invitations` và thiết lập chính sách RLS.
    *   `TECH-04-02`: Viết RPC `api_v1.create_pending_invitation` (`TOP-MEM-001`) và `api_v1.revoke_pending_invitation` (`TOP-MEM-002`).

#### `STORY-04-02`: Đọc danh sách lời mời và Chấp nhận cộng tác viên
*   **Epic:** `EPIC-04`
*   **Kết quả Nghiệp vụ:** Người dùng chưa onboard đọc danh sách các lời mời khớp email và chấp nhận tham gia để trở thành COLLABORATOR.
*   **Mã Yêu cầu nguồn:** `REQ-04-002`
*   **Tham chiếu Kiến trúc:** [`05-rls-and-authorization-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/05-rls-and-authorization-design.md), [`08-class-c-organizer-api-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/08-class-c-organizer-api-design.md)
*   **Vai trò (Actor):** Google Auth user (Chưa onboard)
*   **Phân lớp Bảo mật:** `Class C` (RPC chấp nhận đặc quyền)
*   **Client:** `Flutter`
*   **Bề mặt Backend:** `api_v1.list_my_pending_invitations` (`TRD-MEM-001`), `api_v1.accept_pending_invitation` (`TOP-MEM-003`)
*   **Phụ thuộc (Dependencies):** `STORY-04-01`
*   **Độ ưu tiên:** `P1`
*   **Độ phức tạp:** `S`
*   **Tiêu chí Chấp nhận:**
    *   Người dùng đăng nhập lấy email từ JWT hệ thống để so khớp danh sách invitation.
    *   Chấp nhận tạo bản ghi thành viên `wedding_members` với quyền `COLLABORATOR` và chuyển lời mời sang trạng thái `ACCEPTED`.
*   **Nghĩa vụ Bảo mật & Idempotency:** Cấm nhận email tham số từ client. `accept` kích hoạt lại member cũ nếu trùng email lịch sử để tái sử dụng.
*   **Nhiệm vụ kiểm thử (Test Obligations):**
    *   `TEST-04-03`: Thử chấp nhận lời mời của email khác email Google Auth -> Báo lỗi chặn.
*   **Quyết định hoãn chặn (Blocking Dec):** N/A
*   **Nhiệm vụ kỹ thuật:**
    *   `TECH-04-03`: Viết RPC `api_v1.list_my_pending_invitations` và `api_v1.accept_pending_invitation`.

#### `STORY-04-03`: OWNER thu hồi thành viên và Bảo vệ OWNER cuối cùng
*   **Epic:** `EPIC-04`
*   **Kết quả Nghiệp vụ:** OWNER thu hồi quyền của thành viên (Collaborator hoặc OWNER khác), hệ thống chặn xóa nếu đó là OWNER cuối cùng.
*   **Mã Yêu cầu nguồn:** `REQ-01-001`
*   **Tham chiếu Kiến trúc:** [`05-rls-and-authorization-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/05-rls-and-authorization-design.md), [`08-class-c-organizer-api-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/08-class-c-organizer-api-design.md)
*   **Vai trò (Actor):** OWNER
*   **Phân lớp Bảo mật:** `Class C` (RPC thu hồi)
*   **Client:** `Flutter`
*   **Bề mặt Backend:** `api_v1.revoke_wedding_member` (`TOP-MEM-004`)
*   **Phụ thuộc (Dependencies):** `STORY-04-02`
*   **Độ ưu tiên:** `P1`
*   **Độ phức tạp:** `S`
*   **Tiêu chí Chấp nhận:**
    *   Chuyển trạng thái thành viên sang `REVOKED`.
    *   Ngăn chặn thu hồi thành viên OWNER nếu đám cưới chỉ còn đúng 1 OWNER hoạt động.
*   **Nghĩa vụ Bảo mật & Concurrency:** Đếm số lượng OWNER hoạt động trực tiếp trong giao dịch DB để đảm bảo tính nguyên tử.
*   **Nhiệm vụ kiểm thử (Test Obligations):**
    *   `TEST-04-04`: Thử thu hồi OWNER duy nhất của phòng cưới -> Báo lỗi `FINAL_OWNER_INVARIANT`.
*   **Quyết định hoãn chặn (Blocking Dec):** N/A
*   **Nhiệm vụ kỹ thuật:**
    *   `TECH-04-04`: Viết RPC `api_v1.revoke_wedding_member` tích hợp logic đếm OWNER.

---

### EPIC-05: Guest Management / Parties / Groups
#### `STORY-05-01`: Quản lý Danh sách khách mời, Party và Nhóm liên kết
*   **Epic:** `EPIC-05`
*   **Kết quả Nghiệp vụ:** Ban tổ chức thực hiện CRUD khách mời qua PostgREST trực tiếp, nhóm khách mời vào các Party (hộ gia đình) và PrimaryGroup (nhóm quan hệ).
*   **Mã Yêu cầu nguồn:** `REQ-04-001`, `REQ-04-002`
*   **Tham chiếu Kiến trúc:** [`04-postgresql-physical-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/04-postgresql-physical-design.md), [`05-rls-and-authorization-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/05-rls-and-authorization-design.md)
*   **Vai trò (Actor):** OWNER / COLLABORATOR
*   **Phân lớp Bảo mật:** `Class B` (CUD trực tiếp bảo vệ bởi RLS check member)
*   **Client:** `Flutter`
*   **Bề mặt Backend:** `Data API` (PostgREST)
*   **Phụ thuộc (Dependencies):** `STORY-02-01`
*   **Độ ưu tiên:** `P0`
*   **Độ phức tạp:** `M`
*   **Tiêu chí Chấp nhận:**
    *   Tạo khách mời gán số điện thoại/email tự động chuẩn hóa định dạng.
    *   Sự thay đổi thành viên Party (di chuyển khách) không tự động tăng/giảm hạn mức số người được mời (`invited_count`) của Party.
*   **Nghĩa vụ Bảo mật & Integrity:** RLS chặn ghi Guests nếu user không là thành viên đám cưới đó. Composite FK (`wedding_id`, `invitation_party_id`) và (`wedding_id`, `primary_group_id`) ngăn gán chéo đám cưới.
*   **Nhiệm vụ kiểm thử (Test Obligations):**
    *   `TEST-05-01`: Kiểm thử gán khách mời vào Party của đám cưới khác $\rightarrow$ Báo lỗi khóa ngoại mức DB.
    *   `TEST-05-02`: Đảm bảo trigger chuẩn hóa hoạt động cho các số điện thoại/email thô.
*   **Quyết định hoãn chặn (Blocking Dec):** N/A
*   **Nhiệm vụ kỹ thuật:**
    *   `TECH-05-01`: Tạo bảng `primary_groups`, `invitation_parties` và `guests` kèm composite FK và RLS.
    *   `TECH-05-02`: Viết DB trigger tự động chuẩn hóa định dạng SĐT/Email khi lưu (`normalized_phone`, `normalized_email`).

#### `STORY-05-02`: Gộp khách trùng lặp (Preview & Commit)
*   **Epic:** `EPIC-05`
*   **Kết quả Nghiệp vụ:** Ban tổ chức gộp hai tài khoản khách mời trùng lặp (khách phụ gộp vào khách chính sống sót), hệ thống giải quyết tranh chấp thông tin và chuyển giao thiệp mời.
*   **Mã Yêu cầu nguồn:** `REQ-04-001`
*   **Tham chiếu Kiến trúc:** [`06-trusted-operations-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/06-trusted-operations-design.md), [`08-class-c-organizer-api-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/08-class-c-organizer-api-design.md)
*   **Vai trò (Actor):** OWNER / COLLABORATOR
*   **Phân lớp Bảo mật:** `Class C` (Preview/Commit RPC)
*   **Client:** `Flutter`
*   **Bề mặt Backend:** `api_v1.preview_guest_merge`, `api_v1.commit_guest_merge`
*   **Phụ thuộc (Dependencies):** `STORY-05-01`
*   **Độ ưu tiên:** `P1`
*   **Độ phức tạp:** `L`
*   **Tiêu chí Chấp nhận:**
    *   Khi gọi lại (retry), hệ thống cấm tự động suy luận gộp thành công từ việc biến mất của khách phụ. Bắt buộc đối soát trạng thái của khách chính để replay; nếu mơ hồ trả về lỗi `STALE_STATE` / `CONFLICT`.
    *   Không đưa các liên kết tài chính của khách mời vào dấu vân tay `impact_fingerprint` của quá trình gộp khách.
*   **Nghĩa vụ Bảo mật & Concurrency:** Đối soát dấu vân tay `impact_fingerprint` ở bước Commit. Ngăn chặn đè stale-state.
*   **Nhiệm vụ kiểm thử (Test Obligations):**
    *   `TEST-05-03`: Test trường hợp gọi lại lệnh gộp khi khách phụ đã biến mất do bị xóa thủ công trước đó $\rightarrow$ Đảm bảo trả về lỗi `CONFLICT` / `STALE_STATE`.
*   **Quyết định hoãn chặn (Blocking Dec):** N/A
*   **Nhiệm vụ kỹ thuật:**
    *   `TECH-05-03`: Viết RPC preview gộp khách và sinh vân tay tác động.
    *   `TECH-05-04`: Viết RPC commit gộp khách (`TOP-GUE-003`) thực hiện xóa khách phụ và gán thiệp sang khách chính.

---

### EPIC-06: Invitation & Guest Web Bootstrap
#### `STORY-06-01`: Sinh mã định danh thiệp và Tạo liên kết khách mời
*   **Epic:** `EPIC-06`
*   **Kết quả Nghiệp vụ:** OWNER/COLLABORATOR sinh mã định danh và liên kết thiệp (Invitation) độc bản cho từng khách mời để chia sẻ link thiệp.
*   **Mã Yêu cầu nguồn:** `REQ-05-001`
*   **Tham chiếu Kiến trúc:** [`04-postgresql-physical-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/04-postgresql-physical-design.md), [`07-class-d-public-guest-api-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/07-class-d-public-guest-api-design.md)
*   **Vai trò (Actor):** OWNER / COLLABORATOR
*   **Phân lớp Bảo mật:** `Class C` (Edge Function sinh mã định danh đặc quyền)
*   **Client:** `Flutter`
*   **Bề mặt Backend:** `/v1/organizer/credentials/regen` (Edge Function)
*   **Phụ thuộc (Dependencies):** `STORY-05-01`
*   **Độ ưu tiên:** `P0`
*   **Độ phức tạp:** `M`
*   **Tiêu chí Chấp nhận:**
    *   Hệ thống sinh mã Token ngẫu nhiên độ bảo mật cao, băm SHA-256 lưu trữ trong DB (`token_hash`), cấm lưu mã thô.
    *   Đảm bảo duy nhất 1 credential hoạt động tại 1 thời điểm cho mỗi thiệp (one active credential invariant). Khi tái sinh (regen), vô hiệu hóa mã cũ.
*   **Nghĩa vụ Bảo mật & Integrity:** Mã thô tuyệt đối không được ghi log hay telemetry. Mọi lookup dùng băm SHA-256 đối soát.
*   **Nhiệm vụ kiểm thử (Test Obligations):**
    *   `TEST-06-01`: Kiểm thử gọi giải mã thiệp bằng token cũ đã bị vô hiệu hóa $\rightarrow$ Trả về lỗi 404 INVITATION_UNAVAILABLE.
*   **Quyết định hoãn chặn (Blocking Dec):** `DEC-B-002` (Entropy và độ dài Token thiệp).
*   **Nhiệm vụ kỹ thuật:**
    *   `TECH-06-01`: Tạo bảng `invitations`, `invitation_event_targetings` và `invitation_credentials` kèm RLS.
    *   `TECH-06-02`: Viết Edge Function sinh và băm SHA-256 token mới (`TOP-INV-001`).

#### `STORY-06-02`: Khởi chạy trang Web Khách mời tĩnh và Giải mã thiệp
*   **Epic:** `EPIC-06`
*   **Kết quả Nghiệp vụ:** Khách mời mở URL chứa mã định danh ở fragment `#`, SPA giải mã thiệp an toàn và tải dữ liệu hiển thị không lộ định danh đám cưới gốc.
*   **Mã Yêu cầu nguồn:** `REQ-05-001`, `REQ-06-NFR`
*   **Tham chiếu Kiến trúc:** [`ADR-005`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/adr/ADR-005-guest-web-and-public-invitation-api.md), [`07-class-d-public-guest-api-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/07-class-d-public-guest-api-design.md)
*   **Vai trò (Actor):** Khách mời (Guest User)
*   **Phân lớp Bảo mật:** `Class D` (Public Guest APIs)
*   **Client:** `Guest Web`
*   **Bề mặt Backend:** `/v1/public/invitations/resolve` (Edge Function Class D)
*   **Phụ thuộc (Dependencies):** `STORY-06-01`
*   **Độ ưu tiên:** `P0`
*   **Độ phức tạp:** `L`
*   **Tiêu chí Chấp nhận:**
    *   React SPA lấy token từ URL fragment `#`, gọi API resolve gửi qua POST body.
    *   Chạy `window.history.replaceState` xóa sạch token khỏi thanh địa chỉ tức thời.
    *   Token thô chỉ được lưu trong `sessionStorage` ngắn hạn cho tab recovery, cấm dùng `localStorage`.
    *   DTO phản hồi được làm sạch (sanitized), lọc bỏ `wedding_id` gốc và các dữ liệu member nội bộ.
*   **Nghĩa vụ Bảo mật & Abuse Protection:** Áp dụng IP/network rate limiting có cấu hình trên Edge Class D. Trả lỗi HTTP 429 khi quá ngưỡng. Cấm dùng localStorage.
*   **Nhiệm vụ kiểm thử (Test Obligations):**
    *   `TEST-06-03`: Xác nhận token biến mất khỏi thanh địa chỉ trong vòng <100ms.
    *   `TEST-06-04`: Thử gọi trực tiếp vào database qua PostgREST vãng lai -> RLS chặn hoàn toàn.
*   **Quyết định hoãn chặn (Blocking Dec):** `DEC-B-004` (Cấu hình IP rate limit Class D).
*   **Nhiệm vụ kỹ thuật:**
    *   `TECH-06-03`: Phát triển UI React SPA load thiệp động.
    *   `TECH-06-04`: Thiết lập Edge Function resolve nhận token, băm SHA-256 đối soát DB và trả về DTO đã sanitize.

---

### EPIC-07: RSVP / Cutoff / Guest Gift / VietQR
#### `STORY-07-01`: Khách mời phản hồi RSVP và Áp dụng Hạn chốt
*   **Epic:** `EPIC-07`
*   **Kết quả Nghiệp vụ:** Khách mời gửi phản hồi RSVP cho từng lễ cưới con liên kết, hệ thống tự cập nhật trạng thái trước mốc hạn chốt (Cutoff Date).
*   **Mã Yêu cầu nguồn:** `REQ-05-002`
*   **Tham chiếu Kiến trúc:** [`07-class-d-public-guest-api-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/07-class-d-public-guest-api-design.md)
*   **Vai trò (Actor):** Khách mời (Guest User)
*   **Phân lớp Bảo mật:** `Class D` (Public RSVP API)
*   **Client:** `Guest Web`
*   **Bề mặt Backend:** `/v1/public/invitations/rsvp` (Edge Function Class D)
*   **Phụ thuộc (Dependencies):** `STORY-06-02`
*   **Độ ưu tiên:** `P0`
*   **Độ phức tạp:** `M`
*   **Tiêu chí Chấp nhận:**
    *   Hỗ trợ cơ chế cập nhật từng sự kiện (patch-by-event): sự kiện nào gửi lên thì tạo/sửa phản hồi, sự kiện khuyết thiếu giữ nguyên (không bị xóa hay đặt mặc định).
    *   Chặn mọi cập nhật RSVP từ phía khách mời nếu thời gian server vượt qua ngày hạn chốt `rsvp_cutoff_date` cấu hình trên Wedding.
*   **Nghĩa vụ Bảo mật & Integrity:** Revalidate token của khách mời trên từng request gửi lên Edge Function.
*   **Nhiệm vụ kiểm thử (Test Obligations):**
    *   `TEST-07-01`: Gửi request RSVP muộn hơn hạn chốt $\rightarrow$ Đảm bảo trả lỗi `RSVP_CLOSED` (403).
    *   `TEST-07-02`: RSVP một sự kiện con không thuộc đám cưới của thiệp đó -> DB báo lỗi chéo.
*   **Quyết định hoãn chặn (Blocking Dec):** N/A
*   **Nhiệm vụ kỹ thuật:**
    *   `TECH-07-01`: Tạo bảng `rsvps` và `event_responses` lưu vết RSVP.
    *   `TECH-07-02`: Viết Class D Edge Function tiếp nhận RSVP, kiểm duyệt mốc hạn chốt `rsvp_cutoff_date` trước khi ghi DB (`D-RSV-001`).

#### `STORY-07-02`: Hiển thị Mừng cưới và VietQR có điều kiện
*   **Epic:** `EPIC-07`
*   **Kết quả Nghiệp vụ:** Sau khi khách mời hoàn tất RSVP, trang Web hiển thị thông tin mừng cưới và mã VietQR có điều kiện để khách gửi quà.
*   **Mã Yêu cầu nguồn:** `REQ-05-003`
*   **Tham chiếu Kiến trúc:** [`07-class-d-public-guest-api-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/07-class-d-public-guest-api-design.md)
*   **Vai trò (Actor):** Khách mời (Guest User)
*   **Phân lớp Bảo mật:** `Class D` (DTO gating)
*   **Client:** `Guest Web`
*   **Bề mặt Backend:** `/v1/public/invitations/resolve` DTO update
*   **Phụ thuộc (Dependencies):** `STORY-07-01`
*   **Độ ưu tiên:** `P1`
*   **Độ phức tạp:** `S`
*   **Tiêu chí Chấp nhận:**
    *   Thông tin ngân hàng/VietQR của đám cưới chỉ được đính kèm vào DTO khi bản ghi RSVP của thiệp mời đó được xác nhận là đã hoàn thành đầy đủ.
*   **Nghĩa vụ Bảo mật & Integrity:** Gating logic thực thi authoritative ở server-side.
*   **Nhiệm vụ kiểm thử (Test Obligations):**
    *   `TEST-07-03`: Kiểm thử gọi resolve thiệp chưa RSVP $\rightarrow$ Xác nhận không tồn tại trường VietQR/Bank thông tin trong JSON trả về.
*   **Quyết định hoãn chặn (Blocking Dec):** N/A
*   **Nhiệm vụ kỹ thuật:**
    *   `TECH-07-03`: Tích hợp logic lọc VietQR DTO trên Edge Function resolve.
    *   `TECH-07-04`: Thiết kế giao diện chúc mừng và VietQR sinh từ ngân hàng của cặp đôi trên UI Guest Web.

---

### EPIC-08: Finance / Budget / Installments / Payments / Refunds
#### `STORY-08-01`: Quản lý Mục chi và Đợt thanh toán (Class B)
*   **Epic:** `EPIC-08`
*   **Kết quả Nghiệp vụ:** OWNER quản lý danh sách danh mục chi tiêu (Budget Items) và đợt trả tiền (Installments) trực tiếp qua PostgREST với các điều kiện ràng buộc.
*   **Mã Yêu cầu nguồn:** `REQ-03-001`, `REQ-03-002`
*   **Tham chiếu Kiến trúc:** [`05-rls-and-authorization-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/05-rls-and-authorization-design.md), [`09-technical-architecture-final-review`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/09-technical-architecture-final-review.md)
*   **Vai trò (Actor):** OWNER (CUD), Collaborator (Blocked)
*   **Phân lớp Bảo mật:** `Class B` (RLS cho OWNER)
*   **Client:** `Flutter`
*   **Bề mặt Backend:** `Data API` (PostgREST)
*   **Phụ thuộc (Dependencies):** `STORY-02-01`
*   **Độ ưu tiên:** `P0`
*   **Độ phức tạp:** `M`
*   **Tiêu chí Chấp nhận:**
    *   OWNER được INSERT/UPDATE trên `budget_items` và `installments`.
    *   Chỉ được phép xóa cứng `budget_items` khi không có giao dịch thanh toán hoặc đợt trả tiền liên kết.
    *   Collaborator bị RLS chặn hoàn toàn quyền đọc/ghi.
*   **Nghĩa vụ Bảo mật & Integrity:** RLS cô lập dữ liệu theo Wedding ID. Khóa ngoại phức hợp (`wedding_id`, `installment_id`) ngăn chặn gán chéo.
*   **Nhiệm vụ kiểm thử (Test Obligations):**
    *   `TEST-08-01`: Kiểm thử tài khoản Collaborator cố gắng SELECT `budget_items` $\rightarrow$ Xác nhận trả về 0 dòng.
*   **Quyết định hoãn chặn (Blocking Dec):** N/A
*   **Nhiệm vụ kỹ thuật:**
    *   `TECH-08-01`: Tạo bảng `budget_items` và `installments` kèm các check constraint tiền tệ dương.
    *   `TECH-08-02`: Thiết lập chính sách RLS cho OWNER trên hai bảng này, chặn Collaborator.

#### `STORY-08-02`: Giao dịch Thanh toán và Hoàn tiền chống trùng lặp (Class C)
*   **Epic:** `EPIC-08`
*   **Kết quả Nghiệp vụ:** OWNER ghi nhận giao dịch chi trả (Payments) và hoàn tiền (Refunds) an toàn, hệ thống tự động kiểm soát chống chi đúp qua biên nhận.
*   **Mã Yêu cầu nguồn:** `REQ-03-001`, `REQ-03-002`, `REQ-03-003`
*   **Tham chiếu Kiến trúc:** [`06-trusted-operations-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/06-trusted-operations-design.md), [`08-class-c-organizer-api-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/08-class-c-organizer-api-design.md)
*   **Vai trò (Actor):** OWNER
*   **Phân lớp Bảo mật:** `Class C` (RPCs đặc quyền gán receipt)
*   **Client:** `Flutter`
*   **Bề mặt Backend:** `api_v1` RPCs (`create_payment`, `create_refund`, `void_payment`)
*   **Phụ thuộc (Dependencies):** `STORY-08-01`
*   **Độ ưu tiên:** `P0`
*   **Độ phức tạp:** `L`
*   **Tiêu chí Chấp nhận:**
    *   Bảng `payments` và `refunds` chặn hoàn toàn đột biến Class B PostgREST.
    *   Tạo giao dịch yêu cầu cung cấp `request_id`, ghi nhận vào `private.trusted_operation_receipts` trong cùng transaction DB.
    *   Hỗ trợ gán `payer_display_name` cho người thanh toán không là thành viên. Trường hợp chọn `payer_wedding_member_id` thì member phải thuộc cùng Wedding và đang `ACTIVE` tại thời điểm gán. Nếu member bị `REVOKED` sau này, giữ nguyên vẹn Payment (không NULL hay từ chối).
*   **Nghĩa vụ Bảo mật & Concurrency:** Transaction DB bao bọc cả việc kiểm duyệt, ghi nhận receipt và chèn Payment. `payer_wedding_member_id` check ACTIVE khi tạo mới/hiệu chỉnh.
*   **Nhiệm vụ kiểm thử (Test Obligations):**
    *   `TEST-08-02`: Gọi lại lệnh tạo Payment trùng `request_id` $\rightarrow$ Xác nhận trả về kết quả cũ và không tạo Payment thứ hai.
    *   `TEST-08-03`: Thử gán payer là member thuộc đám cưới khác -> DB báo lỗi.
    *   `TEST-08-04`: Thử gán payer là member đã bị `REVOKED` -> RPC báo lỗi từ chối.
*   **Quyết định hoãn chặn (Blocking Dec):** N/A
*   **Nhiệm vụ kỹ thuật:**
    *   `TECH-08-03`: Tạo bảng `payments` và `refunds` kèm RLS chặn hoàn toàn CUD của client.
    *   `TECH-08-04`: Viết RPC `api_v1.create_payment` (`TOP-FIN-001`) và `api_v1.create_refund` (`TOP-FIN-004`) tích hợp băm chuẩn hóa payload và lưu receipt.

#### `STORY-08-03`: Views phái sinh tài chính và Biểu đồ dòng tiền
*   **Epic:** `EPIC-08`
*   **Kết quả Nghiệp vụ:** Ban tổ chức xem các thông số tổng quan tài chính (Net Paid, Outstanding, Projected Cost) và xem biểu đồ dòng tiền (Cash Flow) 7/30 ngày.
*   **Mã Yêu cầu nguồn:** `REQ-03-001`, `REQ-03-002`
*   **Tham chiếu Kiến trúc:** [`04-postgresql-physical-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/04-postgresql-physical-design.md), [`09-technical-architecture-final-review`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/09-technical-architecture-final-review.md)
*   **Vai trò (Actor):** OWNER
*   **Phân lớp Bảo mật:** `Class B` (Đọc views phái sinh)
*   **Client:** `Flutter`
*   **Bề mặt Backend:** `Data API` (PostgREST views)
*   **Phụ thuộc (Dependencies):** `STORY-08-02`
*   **Độ ưu tiên:** `P1`
*   **Độ phức tạp:** `M`
*   **Tiêu chí Chấp nhận:**
    *   `Net Paid = Active Payments - Active Refunds`.
    *   `Outstanding = max(Confirmed Cost - Net Paid, 0)` khi Confirmed Cost khác NULL. Nếu Confirmed Cost là NULL $\rightarrow$ `Outstanding = UNKNOWN` (cấm tự động dùng Estimated Cost).
*   **Nghĩa vụ Bảo mật & Integrity:** RLS lọc view động tự động theo `wedding_id` của actor.
*   **Nhiệm vụ kiểm thử (Test Obligations):**
    *   `TEST-08-05`: Thiết lập bộ dữ liệu test có Budget Item chưa chốt Confirmed Cost $\rightarrow$ Đảm bảo Outstanding hiển thị giá trị UNKNOWN (hoặc null mức DB).
*   **Quyết định hoãn chặn (Blocking Dec):** N/A
*   **Nhiệm vụ kỹ thuật:**
    *   `TECH-08-05`: Viết PostgreSQL View `v_wedding_finance_summary` thực thi công thức tính toán phái sinh.
    *   `TECH-08-06`: Viết PostgreSQL View `v_wedding_cash_flow_daily` gom nhóm tiền theo 7/30 ngày.

---

### EPIC-09: Excel Guest Import
#### `STORY-09-01`: Nhập lô Khách mời từ tệp Excel parse tại client
*   **Epic:** `EPIC-09`
*   **Kết quả Nghiệp vụ:** Ban tổ chức tải tệp mẫu Excel, parse cấu trúc cột tại client di động thành JSON và gửi lô dữ liệu lên Edge để xác nhận nhập khách hàng loạt.
*   **Mã Yêu cầu nguồn:** `REQ-04-002`
*   **Tham chiếu Kiến trúc:** [`ADR-006`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/adr/ADR-006-storage-media-and-import-export.md), [`08-class-c-organizer-api-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/08-class-c-organizer-api-design.md)
*   **Vai trò (Actor):** OWNER / COLLABORATOR
*   **Phân lớp Bảo mật:** `Class C` (Edge Function import lô chống trùng)
*   **Client:** `Flutter`
*   **Bề mặt Backend:** `/v1/organizer/excel/confirm` (Edge Function)
*   **Phụ thuộc (Dependencies):** `STORY-05-01`
*   **Độ ưu tiên:** `P1`
*   **Độ phức tạp:** `L`
*   **Tiêu chí Chấp nhận:**
    *   Tệp Excel được parse thành JSON cấu trúc tại client di động, cấm đẩy file `.xlsx` nhị phân thô lên máy chủ.
    *   Gộp nhóm khách vào Party dựa trên thuộc tính Party Key trong file.
    *   Edge Function sử dụng `request_id` biên nhận để ngăn chặn import đúp dữ liệu khi người dùng bấm xác nhận nhiều lần.
*   **Nghĩa vụ Bảo mật & Idempotency:** Dữ liệu Excel thô không được lưu trên cloud storage. Tích hợp receipt kiểm soát.
*   **Nhiệm vụ kiểm thử (Test Obligations):**
    *   `TEST-09-01`: Gọi lại lệnh import với cùng `request_id` $\rightarrow$ Xác nhận trả thành công tóm tắt số khách đã import cũ, không ghi đè đúp dòng Guests.
*   **Quyết định hoãn chặn (Blocking Dec):** `DEC-C-001` (Thư viện parse XLSX local).
*   **Nhiệm vụ kỹ thuật:**
    *   `TECH-09-01`: Tích hợp thư viện parse Excel trên client Flutter và xuất JSON chuẩn.
    *   `TECH-09-02`: Viết Edge Function import lô nhận JSON, kiểm tra trùng lặp qua receipt và thực thi INSERT hàng loạt.

---

### EPIC-10: Media / Storage
#### `STORY-10-01`: Lưu trữ ảnh cưới và Phân quyền link Signed URLs ngắn hạn
*   **Epic:** `EPIC-10`
*   **Kết quả Nghiệp vụ:** Cặp đôi tải ảnh cưới lên Storage (tối đa 5MB), hệ thống lưu trữ private và cấp link Signed URL ngắn hạn cho khách mời xem thiệp trực tuyến.
*   **Mã Yêu cầu nguồn:** `REQ-05-001`, `REQ-06-NFR`
*   **Tham chiếu Kiến trúc:** [`ADR-006`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/adr/ADR-006-storage-media-and-import-export.md), [`07-class-d-public-guest-api-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/07-class-d-public-guest-api-design.md)
*   **Vai trò (Actor):** OWNER (Upload), Khách mời (View)
*   **Phân lớp Bảo mật:** `Class C` (Signed URL generation) + `Class D` (Signed URL consumption)
*   **Client:** `Flutter` + `Guest Web`
*   **Bề mặt Backend:** `Storage` (Supabase Storage bucket private)
*   **Phụ thuộc (Dependencies):** `STORY-06-02`
*   **Độ ưu tiên:** `P1`
*   **Độ phức tạp:** `M`
*   **Tiêu chí Chấp nhận:**
    *   Bucket hình ảnh được cấu hình private, chặn truy cập ẩn danh trực tiếp.
    *   Khi khách mở thiệp Class D, Edge Function sinh Signed URL ngắn hạn (thời gian hết hạn dưới 15 phút) đính kèm vào DTO để hiển thị ảnh trên Web.
    *   Ảnh upload bị giới hạn dung lượng tối đa 5MB và được nén ảnh tối ưu tại Flutter client trước khi gửi lên.
*   **Nghĩa vụ Bảo mật & Integrity:** RLS của Storage Bucket kiểm duyệt chỉ thành viên của Wedding mới được tải lên/sửa.
*   **Nhiệm vụ kiểm thử (Test Obligations):**
    *   `TEST-10-01`: Thử dùng link ảnh trực tiếp (không ký) $\rightarrow$ Xác nhận lỗi `AccessDenied` từ CDN/Storage.
*   **Quyết định hoãn chặn (Blocking Dec):** `DEC-B-003` (Cấu trúc bucket Storage).
*   **Nhiệm vụ kỹ thuật:**
    *   `TECH-10-01`: Cấu hình private Storage bucket trên Supabase kèm chính sách OWNER access policy.
    *   `TECH-10-02`: Tích hợp thư viện nén ảnh tại client Flutter.
    *   `TECH-10-03`: Tích hợp logic sinh Signed URL động trên Edge Function resolve Class D.

---

### EPIC-11: Wedding Lifecycle / Archive / Permanent Delete
#### `STORY-11-01`: OWNER lưu trữ đám cưới (Archive) sang dạng chỉ đọc
*   **Epic:** `EPIC-11`
*   **Kết quả Nghiệp vụ:** OWNER lưu trữ phòng cưới (Archive) để chuyển dữ liệu sang chế độ đọc-ghi giới hạn (chỉ đọc cho collaborator, khóa đột biến mới).
*   **Mã Yêu cầu nguồn:** `REQ-01-001`
*   **Tham chiếu Kiến trúc:** [`05-rls-and-authorization-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/05-rls-and-authorization-design.md), [`08-class-c-organizer-api-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/08-class-c-organizer-api-design.md)
*   **Vai trò (Actor):** OWNER
*   **Phân lớp Bảo mật:** `Class C` (RPC lưu trữ)
*   **Client:** `Flutter`
*   **Bề mặt Backend:** `api_v1.archive_wedding` (`TOP-WED-003`)
*   **Phụ thuộc (Dependencies):** `STORY-02-01`
*   **Độ ưu tiên:** `P1`
*   **Độ phức tạp:** `S`
*   **Tiêu chí Chấp nhận:**
    *   Chuyển trạng thái đám cưới sang `ARCHIVED`.
    *   Sau khi lưu trữ, RLS chặn toàn bộ các hoạt động chèn/sửa dữ liệu thông thường.
*   **Nghĩa vụ Bảo mật & Integrity:** RLS check trạng thái ACTIVE của Wedding trước khi cho phép đột biến dữ liệu.
*   **Nhiệm vụ kiểm thử (Test Obligations):**
    *   `TEST-11-01`: Đảm bảo Wedding ở trạng thái `ARCHIVED` sẽ bị từ chối mọi hoạt động tạo Task mới.
*   **Quyết định hoãn chặn (Blocking Dec):** N/A
*   **Nhiệm vụ kỹ thuật:**
    *   `TECH-11-01`: Thiết lập kiểm tra cờ status của Wedding trong hàm RLS helper `security.can_mutate_wedding`.
    *   `TECH-11-02`: Viết RPC `api_v1.archive_wedding`.

#### `STORY-11-02`: Xóa vĩnh viễn và Dọn dẹp Storage (Permanent Delete)
*   **Epic:** `EPIC-11`
*   **Kết quả Nghiệp vụ:** OWNER kích hoạt quy trình xóa vĩnh viễn đám cưới, dọn sạch Storage ảnh cưới trước khi DB thực thi cascade xóa vĩnh viễn.
*   **Mã Yêu cầu nguồn:** `REQ-01-001`
*   **Tham chiếu Kiến trúc:** [`05-rls-and-authorization-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/05-rls-and-authorization-design.md), [`06-trusted-operations-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/06-trusted-operations-design.md)
*   **Vai trò (Actor):** OWNER
*   **Phân lớp Bảo mật:** `Class C` (Edge Function xóa cưới dọn dẹp Storage)
*   **Client:** `Flutter`
*   **Bề mặt Backend:** `/v1/organizer/weddings/delete` (Edge Function)
*   **Phụ thuộc (Dependencies):** `STORY-10-01`
*   **Độ ưu tiên:** `P1`
*   **Độ phức tạp:** `L`
*   **Tiêu chí Chấp nhận:**
    *   Khi xóa đám cưới, chuyển status sang `DELETING`. Trong trạng thái này, chặn toàn bộ đột biến nghiệp vụ thông thường, khách mời không thể resolve thiệp.
    *   Edge Function thực hiện xóa toàn bộ tài nguyên hình ảnh trên Storage bucket của đám cưới trước. Khi Storage dọn sạch thành công mới thực thi cascade delete các bảng DB để tránh mồ côi tài nguyên.
    *   Nếu dọn Storage lỗi giữa chừng, đám cưới vẫn ở trạng thái `DELETING` để OWNER có thể bấm gọi lại (retry) xóa lại.
*   **Nghĩa vụ Bảo mật & Integrity:** Chỉ OWNER mới được chạy lệnh xóa. RLS can_owner_delete_wedding được mở riêng cho OWNER chạy xóa Storage/DB chặng cuối khi ở DELETING.
*   **Nhiệm vụ kiểm thử (Test Obligations):**
    *   `TEST-11-02`: Giả lập xóa cưới lỗi Storage $\rightarrow$ Đảm bảo DB không bị xóa và đám cưới vẫn ở trạng thái `DELETING` cho phép gọi lại.
*   **Quyết định hoãn chặn (Blocking Dec):** N/A
*   **Nhiệm vụ kỹ thuật:**
    *   `TECH-11-03`: Viết SQL function cascade delete tất cả các bảng dữ liệu khớp `wedding_id`.
    *   `TECH-11-04`: Viết Edge Function xóa dọn dẹp Storage theo tuần tự và kích hoạt cascade DB delete (`TOP-WED-004`).

---

### EPIC-12: Cross-cutting UX / Attention Center / Wedding Switcher
#### `STORY-12-01`: Bộ chuyển đổi phòng cưới và Giao diện Attention Center cảnh báo
*   **Epic:** `EPIC-12`
*   **Kết quả Nghiệp vụ:** Thành viên xem danh sách các đám cưới tham gia để chuyển đổi không gian, hiển thị Attention Center chứa các thông báo cảnh báo đứt gãy dữ liệu (Task quá hạn, Payment lệch lịch biểu, member REVOKED).
*   **Mã Yêu cầu nguồn:** `REQ-06-001`
*   **Tham chiếu Kiến trúc:** [`ADR-007`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/adr/ADR-007-notifications-ai-and-deferred-capabilities.md), [`09-technical-architecture-final-review`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/09-technical-architecture-final-review.md)
*   **Vai trò (Actor):** OWNER / COLLABORATOR
*   **Phân lớp Bảo mật:** `Class B` (Truy vấn views động)
*   **Client:** `Flutter`
*   **Bề mặt Backend:** `Data API` (PostgREST views)
*   **Phụ thuộc (Dependencies):** `STORY-03-01`, `STORY-08-02`
*   **Độ ưu tiên:** `P1`
*   **Độ phức tạp:** `M`
*   **Tiêu chí Chấp nhận:**
    *   Attention Center hoạt động hoàn toàn bằng cách SELECT các view động (derived views) thời gian thực, tuyệt đối không dùng background cron-job chạy ngầm hay đẩy SMS/Email tốn phí.
    *   Hiển thị cảnh báo khi: Task quá hạn chưa hoàn thành; Task được gán cho một member đã bị `REVOKED`; hoặc Payment thực tế bị lệch mốc lịch biểu Installment tương ứng.
*   **Nhiệm vụ kiểm thử (Test Obligations):**
    *   `TEST-12-01`: Gán Task cho Collaborator X $\rightarrow$ Thu hồi Collaborator X $\rightarrow$ Xác nhận Attention Center xuất hiện cảnh báo đầu việc mồ côi assignee.
*   **Quyết định hoãn chặn (Blocking Dec):** N/A
*   **Nhiệm vụ kỹ thuật:**
    *   `TECH-12-01`: Xây dựng view SQL `v_wedding_attention_warnings` gom tất cả điều kiện cảnh báo động.
    *   `TECH-12-02`: Phát triển giao diện Attention Center trên app Flutter di động.

---

### EPIC-13: Security / Reliability / Performance / Release Readiness
#### `STORY-13-01`: Kiểm thử an ninh cô lập Tenant và Ma trận Bảo mật (Security Audit)
*   **Epic:** `EPIC-13`
*   **Kết quả Nghiệp vụ:** Chạy bộ test tích hợp tự động đối soát toàn bộ các chính sách RLS và khóa ngoại DB, đảm bảo người dùng đám cưới A không thể đọc/ghi dữ liệu của đám cưới B.
*   **Mã Yêu cầu nguồn:** `REQ-06-001`
*   **Tham chiếu Kiến trúc:** [`05-rls-and-authorization-design`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/05-rls-and-authorization-design.md), [`09-technical-architecture-final-review`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/09-technical-architecture-final-review.md)
*   **Vai trò (Actor):** Security Auditor / Developer
*   **Phân lớp Bảo mật:** `Class A` (Database level validation)
*   **Client:** `None/backend`
*   **Bề mặt Backend:** `Database`
*   **Phụ thuộc (Dependencies):** Tất cả các Epics
*   **Độ ưu tiên:** `P0`
*   **Độ phức tạp:** `M`
*   **Tiêu chí Chấp nhận:**
    *   100% các bảng dữ liệu có cờ RLS ENABLED.
    *   Giả lập chéo ID giữa các tenant và xác minh DB chặn đứng hoàn toàn.
*   **Nghĩa vụ Bảo mật & Integrity:** release gate an ninh cao nhất.
*   **Nhiệm vụ kiểm thử (Test Obligations):**
    *   `TEST-13-01`: Viết bộ test SQL chạy ngầm (sử dụng thư viện kiểm thử pgTAP hoặc công cụ kiểm thử database tương đương được quyết định ở bước triển khai) quét chính sách RLS tất cả các bảng.
    *   `TEST-13-02`: Viết test tích hợp gọi API PostgREST giả lập chéo `wedding_id` để xác thực mã lỗi trả về.
*   **Quyết định hoãn chặn (Blocking Dec):** `DEC-C-005` (Quyết định framework kiểm thử DB).

#### `STORY-13-02`: Đo kiểm Hiệu năng và NFR Benchmarks
*   **Epic:** `EPIC-13`
*   **Kết quả Nghiệp vụ:** Chạy bộ test đo hiệu năng và kiểm soát tốc độ phản hồi API/Edge/Client đạt target.
*   **Mã Yêu cầu nguồn:** `REQ-06-NFR`
*   **Tham chiếu Kiến trúc:** [`09-technical-architecture-final-review`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/09-technical-architecture-final-review.md)
*   **Vai trò (Actor):** Developer / QA
*   **Phân lớp Bảo mật:** `Infrastructure`
*   **Client:** `None/backend`
*   **Bề mặt Backend:** `Edge / RPC / Client`
*   **Phụ thuộc (Dependencies):** Tất cả các Epics
*   **Độ ưu tiên:** `P1`
*   **Độ phức tạp:** `M`
*   **Tiêu chí Chấp nhận:**
    *   Ghi nhận số liệu đo đạc thực tế đối soát với các target NFR: load list Android <2s, load Guest Web <3s, Excel 300 khách <5s.
*   **Nhiệm vụ kiểm thử (Test Obligations):**
    *   `TEST-13-03`: Tạo tập dữ liệu giả lập (300 khách, 500 tasks, 100 payment transactions) và chạy script đo thời gian phản hồi.
*   **Quyết định hoãn chặn (Blocking Dec):** N/A

#### `STORY-13-03`: Đánh giá sẵn sàng Release (Release Readiness Gate Validation)
*   **Epic:** `EPIC-13`
*   **Kết quả Nghiệp vụ:** Thực thi bộ kiểm thử tích hợp chót (smoke test suite) trên môi trường staging để nghiệm thu 100% cổng release.
*   **Mã Yêu cầu nguồn:** `REQ-06-001`
*   **Tham chiếu Kiến trúc:** [`09-technical-architecture-final-review`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/09-technical-architecture-final-review.md)
*   **Vai trò (Actor):** QA / Release Manager
*   **Phân lớp Bảo mật:** `Infrastructure`
*   **Client:** `Flutter` + `Guest Web`
*   **Bề mặt Backend:** `Database / Edge / Storage`
*   **Phụ thuộc (Dependencies):** Tất cả các Stories
*   **Độ ưu tiên:** `P1`
*   **Độ phức tạp:** `S`
*   **Tiêu chí Chấp nhận:**
    *   Hội tụ đầy đủ 8 cổng phát hành kỹ thuật (Release Gates) và không phát hiện bất kỳ blocker nào.
*   **Nhiệm vụ kiểm thử (Test Obligations):**
    *   `TEST-13-04`: Chạy E2E flow happy path từ Google login -> onboarding -> tạo task -> tạo khách -> share link -> RSVP -> VietQR bank info.
*   **Quyết định hoãn chặn (Blocking Dec):** `DEC-C-004` (Quy trình CI/CD).

---

## E. Ma Trận Bất Biến Nghiệp Vụ & Yêu Cầu (Requirement Traceability)

Mỗi Story trong backlog được truy vết trực tiếp tới các Yêu cầu:

| Mã Story | Epic tương ứng | Requirement ID | Actor / Persona | Phân lớp Bảo mật |
| :--- | :--- | :--- | :--- | :--- |
| **`STORY-00-01`** | `EPIC-00` | `REQ-06-NFR` | Infrastructure | Infrastructure |
| **`STORY-01-01`** | `EPIC-01` | `REQ-01-001`, `REQ-04-002` | Google User | Class B / C |
| **`STORY-02-01`** | `EPIC-02` | `REQ-01-001`, `REQ-02-001` | OWNER / COLLAB | Class C (RPC & Edge) |
| **`STORY-03-01`** | `EPIC-03` | `REQ-02-001`, `REQ-06-001` | OWNER / COLLAB | Class B (PostgREST) |
| **`STORY-03-02`** | `EPIC-03` | `REQ-02-002`, `REQ-02-003` | OWNER / COLLAB | Class C (Preview/Commit) |
| **`STORY-04-01`** | `EPIC-04` | `REQ-04-002` | OWNER | Class C (RPCs) |
| **`STORY-04-02`** | `EPIC-04` | `REQ-04-002` | Google User | Class C (RPCs) |
| **`STORY-04-03`** | `EPIC-04` | `REQ-01-001` | OWNER | Class C (RPCs) |
| **`STORY-05-01`** | `EPIC-05` | `REQ-04-001`, `REQ-04-002` | OWNER / COLLAB | Class B (PostgREST) |
| **`STORY-05-02`** | `EPIC-05` | `REQ-04-001` | OWNER / COLLAB | Class C (Preview/Commit) |
| **`STORY-06-01`** | `EPIC-06` | `REQ-05-001` | OWNER / COLLAB | Class C (Edge Credential) |
| **`STORY-06-02`** | `EPIC-06` | `REQ-05-001`, `REQ-06-NFR` | Guest User | Class D (React & Edge) |
| **`STORY-07-01`** | `EPIC-07` | `REQ-05-002` | Guest User | Class D (Edge RSVP) |
| **`STORY-07-02`** | `EPIC-07` | `REQ-05-003` | Guest User | Class D (DTO Gating) |
| **`STORY-08-01`** | `EPIC-08` | `REQ-03-001`, `REQ-03-002` | OWNER | Class B (Budget/Installment) |
| **`STORY-08-02`** | `EPIC-08` | `REQ-03-001` tới `REQ-03-003` | OWNER | Class C (Payment/Refund RPC) |
| **`STORY-08-03`** | `EPIC-08` | `REQ-03-001`, `REQ-03-002` | OWNER | Class B (Finance Views) |
| **`STORY-09-01`** | `EPIC-09` | `REQ-04-002` | OWNER / COLLAB | Class C (Excel Edge) |
| **`STORY-10-01`** | `EPIC-10` | `REQ-05-001`, `REQ-06-NFR` | OWNER / Guest | Class C / D |
| **`STORY-11-01`** | `EPIC-11` | `REQ-01-001` | OWNER | Class C (Archive RPC) |
| **`STORY-11-02`** | `EPIC-11` | `REQ-01-001` | OWNER | Class C (Delete Edge) |
| **`STORY-12-01`** | `EPIC-12` | `REQ-06-001` | OWNER / COLLAB | Class B (Attention Views) |
| **`STORY-13-01`** | `EPIC-13` | `REQ-06-001` | Security Auditor | Class A (DB Validation) |
| **`STORY-13-02`** | `EPIC-13` | `REQ-06-NFR` | QA / Developer | Infrastructure |
| **`STORY-13-03`** | `EPIC-13` | `REQ-06-001` | Release Manager | Infrastructure |

---

## F. Ma Trận Phân Nhóm Độ Ưu Tiên (Priority Matrix)

Hệ thống phân tách thứ tự thực thi theo 3 tầng ưu tiên để đảm bảo luồng nghiệp vụ xương sống luôn hoạt động trước tiên:

*   **Tầng P0 (Bắt buộc cốt lõi):** `STORY-00-01`, `STORY-01-01`, `STORY-02-01`, `STORY-03-01`, `STORY-05-01`, `STORY-06-01`, `STORY-06-02`, `STORY-07-01`, `STORY-08-01`, `STORY-08-02`, `STORY-13-01`. (11 Stories).
*   **Tầng P1 (Quan trọng trước release):** `STORY-03-02`, `STORY-04-01`, `STORY-04-02`, `STORY-04-03`, `STORY-05-02`, `STORY-07-02`, `STORY-08-03`, `STORY-09-01`, `STORY-10-01`, `STORY-11-01`, `STORY-11-02`, `STORY-12-01`, `STORY-13-02`, `STORY-13-03`. (14 Stories).
*   **Tầng P2 (Lower-priority MVP candidates):** Không có.

---

## G. Quy Trình Trách Nhiệm Bảo Mật & Kiểm Thử (Security/Test Obligations)

*   **Ràng buộc Story Definition of Done (DoD):** Mỗi Story chỉ được đánh dấu hoàn thành (`DONE`) khi đáp ứng đủ:
    1.  Mã nguồn đã viết xong và biên dịch thành công không có lỗi lint nghiêm trọng.
    2.  Bộ kiểm thử tương ứng (Unit/Integration) đạt độ phủ và pass 100% các bài test được định nghĩa.
    3.  Cơ chế kiểm soát an toàn tenant chéo đám cưới được đối soát bằng kiểm thử tự động trực tiếp trên Story đó (ví dụ: Story tạo task bắt buộc kèm test chèn chéo wedding_event_id bị chặn).
    4.  Logic kiểm duyệt tham số đầu vào (validation) được thực hiện ở server-side.
    5.  Các trường bảo mật (`task_source`, `is_user_modified`) được kiểm chứng là không cho phép client ghi đè tự do qua Class B.
    6.  Log hệ thống tuyệt đối không chứa thông tin cá nhân khách mời (PII) chưa mã hóa hoặc token thiệp mời thô.

*   **Ràng buộc Epic Definition of Done (DoD):** Epic chỉ được coi là hoàn tất khi:
    1.  Tất cả các Story độ ưu tiên `P0` và `P1` trực thuộc đã hoàn thành và đạt tiêu chuẩn Story DoD.
    2.  Luồng hạnh phúc (Happy path) của Epic chạy thông suốt end-to-end.
    3.  100% các kịch bản kiểm thử lạm dụng an ninh liên quan trong Ma trận Security/Abuse Matrix được xác minh thành công.
    4.  Đã chạy đo kiểm và ghi nhận kết quả hiệu năng sơ bộ đối với các NFR mục tiêu tương ứng của Epic (ví dụ: benchmark import Excel đối với `EPIC-09`).

---

## H. Danh Mục Rủi Ro Backlog (Backlog Risks)

Hệ thống nhận diện 4 rủi ro cốt lõi trong quá trình triển khai backlog và phương án giảm thiểu:

1.  **Rò rỉ dữ liệu chéo (Cross-tenant leak):**
    *   *Rủi ro:* Do lập trình viên quên gán hoặc cấu hình sai chính sách RLS.
    *   *Giảm thiểu:* Thiết lập kiểm thử tích hợp tự động pgTAP bắt buộc chạy trong CI/CD, tự động quét kiểm duyệt chính sách RLS đối với từng bảng dữ liệu mới được thêm vào.
2.  **Đứt gãy liên hoàn lịch biểu (Cascade deadline bugs):**
    *   *Rủi ro:* Khi dời ngày cưới, số lượng lớn Task tương đối chạy trigger cập nhật ngày dương lịch làm quá tải Edge Function hoặc DB transaction.
    *   *Giảm thiểu:* Phân tách quy trình Preview & Commit rõ ràng. Giới hạn số lượng sự kiện con và tối ưu hóa câu lệnh SQL update của database trigger để chạy trực tiếp nguyên tử trong PostgreSQL.
3.  **Lộ mã Token thiệp mời:**
    *   *Rùi ro:* Khách chia sẻ link thiệp dẫn đến lộ token cho người khác.
    *   *Giảm thiểu:* Mã token chỉ chứa thông tin đọc, không cho quyền đột biến phòng cưới. Edge Function resolve thực hiện băm SHA-256 đối soát. Hỗ trợ OWNER hủy và sinh mã mới bất kỳ lúc nào (`TOP-INV-001`).
4.  **Vượt ngưỡng tài nguyên miễn phí (Free-tier quota growth):**
    *   *Rủi ro:* Ảnh cưới dung lượng lớn làm cạn kiệt dung lượng miễn phí của Supabase Storage.
    *   *Giảm thiểu:* Client Flutter bắt buộc thực hiện resize, nén ảnh (JPEG tối ưu) và chặn file >5MB tại thiết bị trước khi upload.

---

## I. Câu Hỏi Mở Về Backlog (Open Planning Questions)

1.  **Vấn đề:** Các thư viện nén ảnh trên Flutter có cần đồng bộ thuật toán nén cụ thể để đảm bảo chất lượng hiển thị trên Guest Web không?
    *   *Đề xuất:* Sử dụng định dạng ảnh WebP nén để tối ưu dung lượng tải chặng 4G của khách mời.
