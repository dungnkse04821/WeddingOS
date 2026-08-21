# Đặc Tả Kiến Trúc: 08 — Class C Organizer API Design (Thiết Kế API Ban Tổ Chức)

*   **Trạng thái (Status):** APPROVED (Đã Phê duyệt)
*   **Người thực hiện:** Antigravity (AI Architect)
*   **Ngày cập nhật:** 21/08/2026

---

> [!IMPORTANT]
> **NON-EXECUTABLE SPECIFICATION**
> Tài liệu này chứa đặc tả thiết kế giao diện API dành riêng cho Ban tổ chức (Organizer client-callable surfaces). Đây KHÔNG phải là tệp mã nguồn Supabase Edge Functions hay Flutter. Toàn bộ mã nguồn thực thi được hoãn lại cho phase sau.

---

## A. Mô Hình Tin Cậy Ban Tổ Chức (Organizer Trust Model)

Hệ thống phân chia ranh giới tin cậy nghiêm ngặt đối với phân hệ Ban tổ chức (App di động di động):
1.  **Xác thực Authoritative:** Mọi cuộc gọi API Class C bắt buộc phải đi kèm JWT session được chứng thực bởi Supabase Auth.
2.  **Bảo toàn Actor Context:** Quyền thực thi đặc quyền (Edge Function với các đặc quyền/năng lực của máy chủ hoặc PostgreSQL SECURITY DEFINER) **không bao giờ** được tự ý thay thế định danh người dùng. Mọi lệnh kiểm duyệt hoặc trigger đều phải giải mã định danh gốc của người dùng (`auth.uid()`) từ JWT để kiểm soát an ninh, chặn đứng kịch bản client Flutter truyền ID giả mạo.
3.  **Cô lập tenant tối đa:** Việc xác định Wedding ID của caller phải dựa trên truy vấn quyền hạn bảng `wedding_members` đối với actor đó, cấm hoàn toàn việc tin tưởng tham số `wedding_id` do client tự gửi lên.

---

## B. Phân Chia Phân Hệ Lớp Schema Bảo Mật (Trust Surface Schemas)

Hệ thống phân tách ranh giới SQL stored procedures làm 3 lớp sơ đồ bảo mật:

1.  **Lớp sơ đồ trợ giúp (`security`):**
    *   *Phạm vi:* Chứa các hàm kiểm soát quyền hạn nội bộ (Ví dụ: `security.can_mutate_wedding`, `security.can_owner_delete_wedding`).
    *   *Bảo mật:* Không cho phép client gọi trực tiếp. Chạy dưới đặc quyền `SECURITY DEFINER` và set `search_path = ''`.
2.  **Lớp sơ đồ API Client (`api_v1`):**
    *   *Phạm vi:* Chứa các hàm RPC được phân quyền thực thi (`GRANT EXECUTE`) cho vai trò `authenticated` (Flutter client).
    *   *Quy tắc:* Mỗi hàm chỉ đại diện cho duy nhất **một nghiệp vụ nghiệp vụ tin cậy hẹp**, cấm các hàm cập nhật động tự do (generic updates). Hàm tự động lấy Actor ID qua `auth.uid()` của JWT session.
3.  **Lớp sơ đồ máy chủ nội bộ (`internal`):**
    *   *Phạm vi:* Chỉ dành cho Edge Functions tin cậy gọi qua năng lực xác thực đặc quyền của máy chủ (privileged server credential/capability).
    *   *Bảo mật:* Tuyệt đối **thu hồi quyền EXECUTE** đối với tất cả các vai trò client công khai (`authenticated`, `anon`). Chứa các logic nhạy cảm có khả năng thiết lập trường được bảo vệ (như `SYSTEM_TEMPLATE` hay cờ `DELETING`).

---

## C. Xác Thực Lan Truyền Định Danh Máy Chủ Nội Bộ (Edge / Internal Actor Propagation)

*   Flutter Client cung cấp mã xác thực JWT trong HTTP Header. Edge Function kiểm tra và xác định định danh người dùng thực tế (verified organizer User identity).
*   Khi Edge Function gọi các hàm DB nội bộ trong schema `internal` để thực hiện thay đổi đặc quyền thông qua **năng lực xác thực đặc quyền của máy chủ (privileged server credential/capability)** (lưu ý: năng lực này đại diện cho quyền thực thi hạ tầng, KHÔNG phải là Actor nghiệp vụ), Edge Function phải truyền định danh người dùng thực tế đã xác minh qua tham số `verified_actor_user_id`.
*   **Bảo vệ authorization độc lập:** Bản thân hàm SQL nội bộ trong `internal` **vẫn bắt buộc phải tự thực thi các kiểm tra phân quyền độc lập** (không được tin cậy mù quáng cuộc gọi từ Edge):
    *   Đối soát `verified_actor_user_id` với tư cách thành viên đám cưới (`wedding_members`) để đảm bảo người dùng có quyền tương ứng với đám cưới mục tiêu.
    *   Kiểm tra vai trò (`role = OWNER`) và trạng thái thành viên (`status = 'ACTIVE'`).
    *   Kiểm tra trạng thái đám cưới (`status = 'ACTIVE'`).
*   Client Flutter hoàn toàn không có quyền thực thi bất kỳ hàm nào thuộc schema `internal`.

---

## D. Phiên Bản Giao Diện RPC (RPC Versioning)

*   Lớp API công khai của client được thiết lập phiên bản trực tiếp qua schema `api_v1`.
*   **Quy tắc tiến hóa:**
    *   Các thay đổi tương thích ngược (như thêm trường tùy chọn đầu vào, thêm trường trả về) được phép thực hiện trực tiếp trên `api_v1`.
    *   Các thay đổi phá vỡ tương thích (breaking changes) về tham số yêu cầu, cấu trúc trả về hoặc luồng nghiệp vụ bắt buộc phải tiến hóa sang một schema mới (ví dụ: `api_v2`). Không thiết lập các tiêu đề HTTP thương lượng phiên bản quá phức tạp cho các hàm gọi RPC thuần.

---

## E. Giao Ước Thiết Lập Mã Yêu Cầu `request_id` (Request ID Contract)

*   Client sử dụng duy nhất trường **`request_id`** (định dạng String/UUID trong DTO hoặc đối số RPC) làm khóa định danh trùng lặp duy nhất cho mỗi nỗ lực gửi yêu cầu.
*   Cấm sử dụng luân phiên các thuật ngữ khác như `Idempotency-Key` trong body để đảm bảo tính nhất quán giữa giao thức gọi RPC và Edge HTTP.
*   Client Flutter chịu trách nhiệm sinh mã `request_id` ngẫu nhiên cho mỗi giao dịch gửi mới, và giữ nguyên mã đó khi thực hiện gọi lại (retry) do mất kết nối.
*   Mã `request_id` chỉ bắt buộc đối với các nghiệp vụ sử dụng bảng biên nhận để kiểm soát chống trùng lặp: `TOP-WED-001`, `TOP-GUE-004`, `TOP-FIN-001`, `TOP-FIN-004`.

---

## F. Thiết Kế Hăm Bảo Mật Trùng Lặp Chuẩn Hóa Nghiệp Vụ (Canonical Request-Hash Decision - Đã giải quyết `CLASS-C-API-CONFLICT-001` & `ERRATA-CAPI-004`)

*   **Không băm payload thô:** Hệ thống tuyệt đối không thực hiện băm trực tiếp chuỗi bytes HTTP request nhận được từ client để làm khóa đối soát. Điều này nhằm tránh các lỗi lệch hash do thay đổi thứ tự thuộc tính JSON hoặc khoảng trắng vô hại.
*   **Cơ chế chuẩn hóa ngữ nghĩa cố định (Semantic Canonicalization):**
    1.  Edge/RPC tiếp nhận yêu cầu, parse và validate dữ liệu thô.
    2.  Tiến hành chuẩn hóa định dạng các trường ảnh hưởng đến logic nghiệp vụ (semantics-affecting fields):
        *   Các giá trị được validate và normalize một cách nhất quán (ví dụ: Decimal values được chuẩn hóa về định dạng chuỗi thập phân chuẩn như `"1500000.00"`).
        *   Xử lý nhất quán sự khác biệt giữa các trường bị khuyết thiếu (omitted) và các trường truyền giá trị `null` chủ động theo đúng hợp đồng nghiệp vụ.
        *   **Loại bỏ hoàn toàn trường `request_id`** và các tham số siêu dữ liệu chỉ phục vụ truyền dẫn mạng hoặc hiển thị giao diện không làm thay đổi kết quả nghiệp vụ khỏi payload trước khi băm.
        *   Đảm bảo thứ tự các key trong JSON object không ảnh hưởng đến mã băm cuối (ví dụ: có thể áp dụng kỹ thuật sort các key của object theo bảng chữ cái).
        *   Mảng dữ liệu chỉ được chuẩn hóa thứ tự nếu nghiệp vụ xác định mảng đó là không nhạy cảm với thứ tự (order-insensitive); đối với các mảng có ý nghĩa về thứ tự (order-sensitive), bắt buộc bảo toàn nguyên vẹn.
    3.  Thực hiện mã hóa SHA-256 chuỗi cấu trúc chuẩn hóa để sinh ra mã `request_hash` an toàn lưu trữ trên DB. (Thuật toán serialize cụ thể được hoãn lại dưới dạng chi tiết thực thi).

---

## G. Quyền Riêng Tư Biên Nhận & Mô Hình Replay (Receipt Privacy & Replay Model)

Bảng biên nhận `private.trusted_operation_receipts` được thiết kế tối giản nhằm tuân thủ bảo mật dữ liệu:
1.  **Cấm lưu trữ PII:** Không lưu trữ thông tin cá nhân khách mời (họ tên, SĐT, email), lời nhắn tự do, thông tin ngân hàng hay mã token credential chưa băm vào bảng receipt.
2.  **Dữ liệu lưu vết tối thiểu:** Bảng chỉ lưu `result_resource_id` (ID của thực thể được tạo như `wedding_id` hoặc `payment_id`) và tóm tắt trạng thái kỹ thuật tối giản cần thiết để khôi phục kết quả.
3.  **Cơ chế Replay:** Khi phát hiện gọi lại (retry) hợp lệ trùng khớp receipt:
    *   Hệ thống **không cache toàn bộ response body** để trả về.
    *   Thay vào đó, hệ thống thực hiện **truy vấn lại cơ sở dữ liệu thời gian thực** dựa trên `result_resource_id` để lấy trạng thái mới nhất của thực thể nghiệp vụ và trả về cho client.
    *   *Ví dụ:* Nếu một Payment được tạo thành công bởi `TOP-FIN-001`, sau đó ban tổ chức sửa đổi thông tin thanh toán này bằng `TOP-FIN-002`. Khi client retry lại lệnh tạo `TOP-FIN-001` cũ do mất gói tin, hệ thống sẽ trả về thông tin cập nhật mới nhất của Payment đó từ DB, cấm ghi đè lại dữ liệu cũ hay sinh thêm Payment thứ hai.

---

## H. Cơ Chế Chặn Đột Biến Trong Trạng Thế `DELETING` (DELETING Authorization)

Khi Đám cưới chuyển trạng thái sang `DELETING` để chuẩn bị xóa vĩnh viễn:
*   **Khóa toàn bộ:** Hệ thống chặn tất cả các hoạt động đột biến dữ liệu nghiệp vụ thông thường (cả Class B trực tiếp lẫn Class C nghiệp vụ tin cậy).
*   **Danh mục cấm cụ thể:** Cấm sinh kế hoạch (`TOP-WED-002`), Archive (`TOP-WED-003`), mời/chấp nhận/thu hồi thành viên (`TOP-MEM-001` tới `004`), các tác vụ sự kiện (`TOP-EVT-001` tới `003`), khách mời (`TOP-GUE-001` tới `004`), tài chính (`TOP-FIN-001` tới `007`), tái sinh credential (`TOP-INV-001`), manual RSVP (`TOP-INV-002`). Khách vãng lai bị chặn truy cập hoàn toàn qua Class D.
*   **Đường dẫn được phép:** Chỉ cho phép duy nhất nghiệp vụ xóa/phục hồi dọn dẹp Storage `TOP-WED-004` được tiếp tục thực thi bởi OWNER của đám cưới.

---

## I. Giao Thức Đánh Giá Tác Động Nghiệp Vụ (Preview / Commit Fingerprint)

Để tránh trường hợp người dùng phê duyệt dữ liệu dựa trên thông tin xem trước đã bị lạc hậu, hệ thống bắt buộc chia tách 2 bước gọi qua 2 hàm API/RPC riêng biệt. Mã vân tay `impact_fingerprint` là cơ chế kiểm soát stale-state, không dùng làm khóa phân quyền hay idempotency/retry key.

### 1. Phân giải Dấu vân tay vật lý (`impact_fingerprint`):
Mã vân tay là hàm băm chuẩn hóa các thông số nghiệp vụ thực tế tại thời điểm Preview:
*   **TOP-EVT-002 (Đổi ngày):** Ngày hiện tại và độ chính xác của sự kiện + danh sách ID các Task tương đối chịu tác động + trạng thái hạn chốt, intent, offset và lịch sử hoàn thành của chúng.
*   **TOP-EVT-003 (Hủy sự kiện):** Trạng thái hoạt động sự kiện + danh mục Task hệ thống/User liên kết + danh sách các BudgetItem liên quan + trạng thái thiệp nhắm tới lễ con đó.
*   **TOP-GUE-001 (Xóa Group):** Trạng thái hoạt động của Nhóm quan hệ + số lượng và danh sách ID các Guest đang liên kết.
*   **TOP-GUE-002 (Di chuyển khách):** ID khách mời + thông tin Party nguồn và đích + hạn mức Invited Count của các Party.
*   **TOP-GUE-003 (Gộp khách):** Trạng thái vật lý của cả 2 Guest + danh mục trường xung đột + Side + Guest Source + PrimaryGroup + tư cách thành viên Party hiện tại + downstream Invitation/RSVP context + các tham chiếu lịch sử chặn xóa. **Tuyệt đối không đưa liên kết tài chính/ngân sách ảo của khách vào dấu vân tay này.**
*   **TOP-FIN-007 (Đổi đợt trả tiền):** Số tiền và due_date của đợt + danh sách Payment đã thanh toán liên kết.

### 2. Luồng xử lý:
*   *Bước 1:* Client gọi API Preview tương ứng $\rightarrow$ Máy chủ tính toán tác động, sinh `impact_fingerprint` và trả về kèm dữ liệu xem trước.
*   *Bước 2:* Client gọi API Commit gửi kèm `impact_fingerprint`. Máy chủ tính lại dấu vân tay thực tế tại thời điểm Commit. Nếu lệch vân tay $\rightarrow$ Báo lỗi `STALE_STATE` / `STALE_IMPACT` và trả về Preview mới để người dùng duyệt lại từ đầu.

---

## J. Danh Mục Bề Mặt API Ban Tổ Chức (Authenticated Organizer API/RPC Surfaces - Đã giải quyết `CLASS-C-API-GAP-005` & `ERRATA-CAPI-003`)

Dưới đây là bảng đặc tả đầy đủ 24 nghiệp vụ tin cậy và 1 nghiệp vụ đọc đặc quyền, đảm bảo tính đơn nhiệm của từng hàm gọi. Bản đồ ánh xạ này khớp chính xác tuyệt đối với tổng số **31 organizer client-callable surfaces** (gồm **15 single-surface RPCs**, **12 Preview/Commit RPCs** thuộc 6 nghiệp vụ chia tách, và **4 Edge HTTP routes**):

| Mã Nghiệp Vụ | Tên Nghiệp Vụ Ban Tổ Chức | Quyền hạn yêu cầu | Giao thức triển khai | API Client-Callable Surface (Single or Commit) | API Preview Surface (if split) | Trình kiểm duyệt stale-review (Review Freshness Control) | Phân loại cơ chế Gọi lại (Retry Category) | Cơ quan thẩm quyền trả về (Response Authority) |
| :--- | :--- | :---: | :---: | :--- | :--- | :---: | :---: | :--- |
| **`TOP-WED-001`** | Tạo Đám cưới mới | Khách vãng lai đã login | RPC | `api_v1.create_wedding` | - | **NONE** | **DURABLE_RECEIPT** | Trả về DTO Wedding được tạo hoặc thông tin hiện tại từ receipt. |
| **`TOP-WED-002`** | Sinh kế hoạch cưới mẫu | OWNER / COLLABORATOR | Edge / Hybrid | `POST /v1/organizer/weddings/plan` | - | **NONE** | **DURABLE_STATE_MARKER_OR_LIFECYCLE**| Trả về DTO cấu trúc tóm tắt kế hoạch cưới hiện tại trên DB, cấm sinh trùng. |
| **`TOP-WED-003`** | Lưu trữ đám cưới | OWNER | RPC | `api_v1.archive_wedding` | - | **NONE** | **CURRENT_STATE_PRECONDITION**| Trả về trạng thái lưu trữ Wedding đọc-ghi giới hạn. |
| **`TOP-WED-004`** | Xóa đám cưới | OWNER | Edge / Hybrid | `POST /v1/organizer/weddings/delete` | - | **NONE** | **DURABLE_STATE_MARKER_OR_LIFECYCLE**| Trả về mã thành công chung ổn định kể cả khi DB đã bị xóa hoàn toàn. |
| **`TOP-MEM-001`** | Gửi lời mời Collaborator | OWNER | RPC | `api_v1.create_pending_invitation` | - | **NONE** | **NATURAL_TERMINAL_OR_UNIQUE_STATE** | Trả về thông tin lời mời đã tạo (chặn gửi trùng email pending). |
| **`TOP-MEM-002`** | Thu hồi lời mời | OWNER | RPC | `api_v1.revoke_pending_invitation`| - | **NONE** | **CURRENT_STATE_PRECONDITION**| Trả về thông tin lời mời ở trạng thái REVOKED. |
| **`TOP-MEM-003`** | Chấp nhận lời mời | Khách mời (khớp email) | RPC | `api_v1.accept_pending_invitation`| - | **NONE** | **NATURAL_TERMINAL_OR_UNIQUE_STATE** | Trả về DTO thành viên mới ACTIVE (kích hoạt lại dòng REVOKED cũ nếu trùng). |
| **`TOP-MEM-004`** | Xóa thành viên | OWNER | RPC | `api_v1.revoke_wedding_member` | - | **NONE** | **CURRENT_STATE_PRECONDITION**| Trả về thông tin thành viên bị REVOKED. Chặn xóa OWNER cuối cùng. |
| **`TOP-EVT-001`** | Thay đổi Sự kiện chính | OWNER / COLLABORATOR | RPC | `api_v1.change_main_event` | - | **NONE** | **NATURAL_TERMINAL_OR_UNIQUE_STATE** | Trả về DTO cập nhật cờ Lễ chính duy nhất. |
| **`TOP-EVT-002`** | Thay đổi ngày lễ cưới | OWNER / COLLABORATOR | RPC | `api_v1.commit_event_date_change` | `api_v1.preview_event_date_change` | **IMPACT_FINGERPRINT** | **CURRENT_STATE_PRECONDITION** | Trả về ngày cưới mới nếu thành công; trả về lỗi STALE_STATE nếu data nền đổi. |
| **`TOP-EVT-003`** | Hủy sự kiện cưới con | OWNER / COLLABORATOR | RPC | `api_v1.commit_event_removal` | `api_v1.preview_event_removal` | **IMPACT_FINGERPRINT** | **NATURAL_TERMINAL_OR_UNIQUE_STATE** | Trả về trạng thái REMOVED; gọi lại an toàn trên lễ đã REMOVED trả success. |
| **`TOP-GUE-001`** | Xóa nhóm quan hệ | OWNER / COLLABORATOR | RPC | `api_v1.commit_primary_group_delete`| `api_v1.preview_primary_group_delete`| **IMPACT_FINGERPRINT** | **NATURAL_TERMINAL_OR_UNIQUE_STATE** | Trả về xác nhận xóa Group; gọi lại khi Group đã mất trả success. |
| **`TOP-GUE-002`** | Di chuyển khách mời | OWNER / COLLABORATOR | RPC | `api_v1.commit_guest_party_move` | `api_v1.preview_guest_party_move` | **IMPACT_FINGERPRINT** | **CURRENT_STATE_PRECONDITION** | Trả về DTO khách mời sau di chuyển; chặn lặp lại ảnh hưởng hạn mức mời. |
| **`TOP-GUE-003`** | Gộp khách trùng lặp | OWNER / COLLABORATOR | RPC | `api_v1.commit_guest_merge` | `api_v1.preview_guest_merge` | **IMPACT_FINGERPRINT** | **NATURAL_TERMINAL_OR_UNIQUE_STATE** | Trả về khách chính sống sót sau gộp; cấm gộp đúp hay chạy đè trên khách đã bị xóa. |
| **`TOP-GUE-004`** | Xác nhận nhập lô Excel | OWNER / COLLABORATOR | Edge / Hybrid | `POST /v1/organizer/excel/confirm` | - | **NONE** | **DURABLE_RECEIPT** | Trả về DTO tóm tắt số lượng khách đã import thành công. |
| **`TOP-FIN-001`** | Ghi nhận chi tiêu | OWNER | RPC | `api_v1.create_payment` | - | **NONE** | **DURABLE_RECEIPT** | Trả về DTO giao dịch Payment được tạo hoặc thông tin từ receipt. |
| **`TOP-FIN-002`** | Hiệu chỉnh chi tiêu | OWNER | RPC | `api_v1.edit_payment` | - | **NONE** | **CURRENT_STATE_PRECONDITION**| Trả về DTO Payment đã cập nhật. Chặn đè stale-state bằng `expected_updated_at`. |
| **`TOP-FIN-003`** | Hủy giao dịch chi tiêu | OWNER | RPC | `api_v1.void_payment` | - | **NONE** | **CURRENT_STATE_PRECONDITION**| Trả về DTO Payment ở trạng thái VOIDED. |
| **`TOP-FIN-004`** | Ghi nhận hoàn tiền | OWNER | RPC | `api_v1.create_refund` | - | **NONE** | **DURABLE_RECEIPT** | Trả về DTO giao dịch Refund được tạo hoặc thông tin từ receipt. |
| **`TOP-FIN-005`** | Hiệu chỉnh hoàn tiền | OWNER | RPC | `api_v1.edit_refund` | - | **NONE** | **CURRENT_STATE_PRECONDITION**| Trả về DTO Refund đã cập nhật. Chặn đè stale-state bằng `expected_updated_at`. |
| **`TOP-FIN-006`** | Hủy giao dịch hoàn tiền | OWNER | RPC | `api_v1.void_refund` | - | **NONE** | **CURRENT_STATE_PRECONDITION**| Trả về DTO Refund ở trạng thái VOIDED. |
| **`TOP-FIN-007`** | Thay đổi đợt trả tiền | OWNER | RPC | `api_v1.commit_installment_compound`| `api_v1.preview_installment_compound`| **IMPACT_FINGERPRINT** | **CURRENT_STATE_PRECONDITION** | Trả về DTO đợt thanh toán cập nhật; ngăn chặn đè phá hủy lịch sử chi tiêu. |
| **`TOP-INV-001`** | Tái tạo link thiệp mới | OWNER / COLLABORATOR | Edge / Hybrid | `POST /v1/organizer/credentials/regen`| - | **NONE** | **RETRY_SAFE_NEW_RESULT_ALLOWED**| Trả về DTO Token thô mới sinh (Hủy mã cũ). |
| **`TOP-INV-002`** | Ban tổ chức manual RSVP | OWNER / COLLABORATOR | RPC | `api_v1.organizer_manual_rsvp` | - | **NONE** | **NATURAL_TERMINAL_OR_UNIQUE_STATE** | Trả về DTO RSVP hiện tại và derived RSVP Summary sau đột biến (Latest wins). |
| **`TRD-MEM-001`** | Xem danh sách lời mời | Người dùng chưa onboard | RPC | `api_v1.list_my_pending_invitations` | - | **NONE** | **READ_CURRENT_STATE** | Trả về danh sách DTO PENDING invitations khớp email Google Auth (Không mutation). |

---

## K. Thiết Kế Các Nghiệp Vụ & Kết Quả Gọi Lại Giao Diện preview/commit (Đã giải quyết `ERRATA-CAPI-002`)

### 1. Thay đổi ngày lễ cưới (`TOP-EVT-002` - Commit retry):
*   **Hành vi:** Khi client gọi lại lệnh Commit sau khi đã thành công (nhưng mất response):
    *   Hệ thống truy vấn trạng thái ngày và độ chính xác của sự kiện con hiện tại trên DB.
    *   Nếu ngày cưới thực tế trên DB đã khớp chính xác với ngày cưới yêu cầu trong payload $\rightarrow$ Trả về kết quả thành công hiện tại (stable/current result).
    *   Nếu ngày cưới trên DB khác biệt (ví dụ: đã bị một OWNER khác dời ngày tiếp theo) $\rightarrow$ Trả về lỗi `STALE_STATE` / `STALE_IMPACT` và yêu cầu tải lại Preview mới, cấm dời đè mù quáng.

### 2. Hủy sự kiện cưới con (`TOP-EVT-003` - Commit retry):
*   **Hành vi:** Khi client gọi lại lệnh Commit xóa lễ con đã hoàn tất thành công:
    *   Hệ thống kiểm tra trạng thái sự kiện con. Nếu sự kiện cưới con đó đã ở trạng thái `REMOVED` $\rightarrow$ Trả về terminal success ổn định ngay lập tức.
    *   Tuyệt đối không thực thi lại các lệnh xóa lan truyền (xóa thêm Task khác, dời nhầm Task User lên Wedding-level lần thứ hai).

### 3. Xóa nhóm quan hệ (`TOP-GUE-001` - Commit retry):
*   **Hành vi:** Khi client gọi lại lệnh xóa Group đã hoàn thành:
    *   Hệ thống kiểm tra Group ID. Nếu Group ID mục tiêu đã hoàn toàn biến mất khỏi DB $\rightarrow$ Trả về terminal success ổn định, cấm báo lỗi 404 gây hiểu lầm cho Flutter client.

### 4. Di chuyển khách mời (`TOP-GUE-002` - Commit retry):
*   **Hành vi:** Kiểm tra trạng thái vị trí Party hiện tại của khách mời trên DB. Nếu khách đã nằm trong Party đích yêu cầu $\rightarrow$ Trả về success ổn định mà không thực hiện tăng/giảm hạn mức invited_count của Party nguồn/đích lần thứ hai.

### 5. Gộp khách trùng lặp (`TOP-GUE-003` - Commit retry - Đã giải quyết `ERRATA-CAPI-002`):
*   **Hành vi:** Khi client gọi lại lệnh gộp khách, hệ thống **tuyệt đối không được phép suy luận** rằng: "Khách phụ không tồn tại có nghĩa là lần gộp trước đã thành công" (vì khách phụ có thể đã bị xóa qua luồng xóa khách thông thường khác).
    *   *Luồng đối soát trạng thái:* 
        *   Nếu hệ thống có thể xác minh một cách không mơ hồ (unambiguously) từ trạng thái hiện tại của cơ sở dữ liệu rằng yêu cầu gộp này đã được áp dụng thành công trước đó (ví dụ: kiểm tra vết lịch sử hoặc cấu trúc Party đích chứa đúng khách chính sống sót với các thuộc tính đã giải quyết) $\rightarrow$ Trả về kết quả Guest sống sót hiện tại.
        *   Nếu trạng thái cơ sở dữ liệu hiện tại là mơ hồ (ambiguous) $\rightarrow$ Trả về lỗi `STALE_STATE` / `CONFLICT`. Hệ thống tuyệt đối không thực thi gộp lại, không xóa thêm bất kỳ khách nào và không thay thế thực thể khác.

### 6. Đổi đợt chi trả kế hoạch (`TOP-FIN-007` - Commit retry):
*   **Hành vi:** Hệ thống kiểm tra số tiền và due_date hiện tại của đợt thanh toán Installment trên DB. Nếu các thông số này đã khớp chính xác với yêu cầu $\rightarrow$ Trả về success ổn định, không ghi đè đúp phá hủy ngân sách.

---

## L. Xử Lý Độc Quyền Đồng Thời Khi Sinh Kế Hoạch Cưới (`TOP-WED-002` - Đã giải quyết `CLASS-C-API-GAP-006` & `ERRATA-CAPI-001`)

*   **Vấn đề tranh chấp concurrent:** Nếu hai yêu cầu sinh kế hoạch cưới được gửi lên gần như đồng thời từ hai thiết bị khi trường `initial_plan_generated_at` đang là `NULL`, hệ thống phải ngăn chặn kịch bản cả hai cùng đọc thấy NULL và chạy tạo nhân bản hai bộ Task/Event mẫu đúp.
*   **Cơ chế kiểm soát đồng thời mức DB (Authoritative DB-level concurrency control):**
    *   Hệ thống bắt buộc áp dụng một cơ chế khóa/kiểm soát trạng thái nguyên tử ở mức cơ sở dữ liệu (ví dụ như cơ chế khóa dòng `SELECT FOR UPDATE` trên PostgreSQL hoặc cơ chế atomic state guard tương đương). Việc lựa chọn kỹ thuật SQL cụ thể được hoãn lại cho phase mã nguồn thực thi.
    *   **Ràng buộc bất biến (Invariant):** Chỉ duy nhất một transaction thành công trong việc dịch chuyển trạng thái đám cưới từ `initial_plan_generated_at = NULL` sang `initial_plan_generated_at = trusted timestamp` và sinh các Event/Task mẫu.
    *   Yêu cầu đồng thời thứ hai sẽ bị chặn hoặc rollback. Khi transaction thứ nhất commit và hoàn tất, yêu cầu thứ hai đọc thấy mốc timestamp đã được ghi nhận $\rightarrow$ Trả về ngay lập tức dữ liệu kế hoạch hiện tại do transaction thắng cuộc sinh ra, cấm chạy lại thuật toán sinh trùng lặp.

---

## M. Sổ Nhật Ký Gặp Phải & Khoảng Trống Thiết Kế Tầng API (CLASS-C-API Gaps/Conflicts)

*   **`CLASS-C-API/DATA-GAP-001` đến `004`:** Đã giải quyết.
*   **`CLASS-C-API-GAP-005` (Trusted callable surface coverage mismatch) $\rightarrow$ RESOLVED.** Thống nhất chính xác số lượng 31 client-callable surfaces tương ứng với 24 TOP và 1 TRD.
*   **`CLASS-C-API-GAP-006` (Concurrent Initial Plan Generation) $\rightarrow$ RESOLVED.** Giải quyết tranh chấp concurrent thông qua cơ chế khóa dòng/kiểm soát trạng thái nguyên tử mức DB trong transaction sinh kế hoạch cưới.
*   **`CLASS-C-API-CONFLICT-001` (Raw Request Hashing vs Semantic Canonical Hashing) $\rightarrow$ RESOLVED.** Đặc tả chi tiết cơ chế chuẩn hóa ngữ nghĩa JSON và tiền tệ trước khi thực hiện băm SHA-256 bảo mật.
*   **`ERRATA-CAPI-001` (Initial Plan Concurrency Primitive) $\rightarrow$ RESOLVED.** Hoãn lại SQL primitive cụ thể và chỉ giữ ràng buộc DB concurrency invariant cho TOP-WED-002.
*   **`ERRATA-CAPI-002` (Guest Merge Retry Ambiguity) $\rightarrow$ RESOLVED.** Chặn suy luận thành công mù quáng từ sự biến mất của khách phụ trong TOP-GUE-003 retry.
*   **`ERRATA-CAPI-003` (Organizer Surface Terminology) $\rightarrow$ RESOLVED.** Thống nhất thuật ngữ "organizer client-callable surfaces" hoặc "authenticated organizer API/RPC surfaces".
*   **`ERRATA-CAPI-004` (Canonical Hash Wording) $\rightarrow$ RESOLVED.** Thống nhất ngôn ngữ định hình chuẩn hóa ngữ nghĩa (semantic canonicalization), hoãn lại chi tiết kỹ thuật serialize.

---

## N. Thiết Kế Các Kịch Bản Kiểm Thử An Ninh Bắt Buộc (API Security Test Matrix)

Các kịch bản dưới đây bắt buộc phải được viết test tự động ở chặng sau:

### 1. Kiểm thử concurrent sinh kế hoạch:
*   Giả lập gửi đồng thời 2 HTTP request gọi sinh kế hoạch `TOP-WED-002` cho đám cưới A $\rightarrow$ Đảm bảo duy nhất 1 luồng transaction chạy sinh task, luồng còn lại trả về kết quả thành công chứa danh sách task đã được tạo bởi luồng thứ nhất (không báo lỗi và không sinh đúp).

### 2. Kiểm thử gộp khách hàng loạt (Guest Merge Commit Retry):
*   OWNER gửi Commit gộp khách X và Y vào khách Z thành công. Response bị mất.
*   OWNER gửi lại Commit gộp X và Y vào Z $\rightarrow$ Hệ thống phát hiện khách phụ X và Y đã bị xóa sạch $\rightarrow$ Đối soát cấu hình Z; nếu khớp và không mơ hồ $\rightarrow$ Trả về kết Z; nếu mơ hồ $\rightarrow$ Trả lỗi `STALE_STATE` / `CONFLICT`, cấm gộp đè.

### 3. Kiểm thử chuẩn hóa băm (Semantic Hash):
*   Hai payload gửi lên có thứ tự thuộc tính JSON lệch nhau và số tiền định dạng khác nhau nhưng cùng mang ý nghĩa thanh toán $\rightarrow$ Đảm bảo sinh ra duy nhất một mã băm semantic hash khớp nhau trên DB.
