# Đặc Tả Kiến Trúc: 06 — Trusted Operations Design (Thiết Kế Nghiệp Vụ Tin Cậy)

*   **Trạng thái (Status):** APPROVED (Đã Phê duyệt)
*   **Người thực hiện:** Antigravity (AI Architect)
*   **Ngày cập nhật:** 21/08/2026

---

> [!IMPORTANT]
> **NON-EXECUTABLE SPECIFICATION**
> Tài liệu này chứa đặc tả thiết kế nghiệp vụ tin cậy Class C. Đây KHÔNG phải là đặc tả endpoint API (HTTP Method, URL) hay thiết kế DTO (JSON Request/Response). Toàn bộ các định dạng hợp đồng API chi tiết được hoãn lại cho phase sau.

---

## A. Nguyên Tắc Nghiệp Vụ Tin Cậy (Trusted Operation Principles)

Nghiệp vụ tin cậy Class C đại diện cho các hành vi nghiệp vụ phức tạp, nhạy cảm hoặc có tác động liên hoàn (compound impact). Các quy tắc an toàn cốt lõi bao gồm:
1.  **Đường dẫn thực thi đặc quyền (Least Privilege Trusted Path):** Các nghiệp vụ này chạy trên môi trường máy chủ tin cậy (như Supabase Edge Functions đặc quyền hoặc PostgreSQL Transactions). Không cấp quyền ghi (INSERT/UPDATE/DELETE) trực tiếp qua API Class B cho client thông thường trên các bảng này.
2.  **Xác thực Authoritative tại biên:** Mỗi nghiệp vụ tin cậy bắt buộc phải tự thực thi kiểm tra an ninh đầu vào dựa trên thông tin định danh đáng tin cậy:
    *   Xác định định danh người dùng qua `auth.uid()`.
    *   Kiểm tra tính hoạt động của đám cưới (`weddings.status = 'ACTIVE'`).
    *   Kiểm tra tư cách thành viên hoạt động (`wedding_members.status = 'ACTIVE'`).
    *   Kiểm tra vai trò tương ứng (`OWNER` hoặc `COLLABORATOR`).
3.  **Đảm bảo tính giao dịch (Atomicity):** Mọi sửa đổi trên nhiều bảng liên quan phải nằm trong một PostgreSQL Transaction duy nhất. Nếu bất kỳ bước nào thất bại, toàn bộ giao dịch phải được Rollback.
4.  **Chống trùng lặp (Safe Retry/Idempotency):** Thiết kế tập trung vào kiểm soát **kết quả lặp lại an toàn về mặt nghiệp vụ (semantic retry outcomes)** thay vì ràng buộc cứng một công nghệ/cơ chế kỹ thuật cụ thể (như Idempotency Key, Client Mutation Token hay Import Session ID). Các phương án thực thi công nghệ cụ thể được hoãn lại (Deferred) cho phase sau.
5.  **Sử dụng thời gian máy chủ (Authoritative Time):** Các mốc thời gian ghi nhận lịch sử bắt buộc lấy từ đồng hồ máy chủ cơ sở dữ liệu (`now()`), cấm sử dụng thời gian do client truyền lên.

---

## B. Danh Mục Nghiệp Vụ Tin Cậy Chi Tiết (Operation Inventory)

### 1. Nhóm Nghiệp Vụ Đám Cưới (Wedding Workspace Operations)
*   **`TOP-WED-001` (Create Wedding Workspace):** Khởi tạo Đám cưới mới và gán quyền chủ sở hữu cho người tạo. Giao dịch bắt buộc bao gồm: tạo bản ghi `weddings` + tạo bản ghi `wedding_members` với vai trò `OWNER` và `status = 'ACTIVE'`. Không cho phép đám cưới mồ côi không có Owner.
*   **`TOP-WED-002` (Generate Initial Wedding Plan):** Đề xuất các đầu việc lập kế hoạch dựa trên nguồn mẫu nội dung tĩnh phía máy chủ. Đám cưới phải có sẵn ít nhất một sự kiện chính (Main Event) hoạt động (tái sử dụng sự kiện chính hiện có và tạo thêm các lễ con đề xuất khác theo mẫu; không tự động nhân bản). Hỗ trợ cả Exact Date và Expected Month (cấm gán ngày cưới giả lập). Tạo `wedding_events` mặc định và các `tasks` mẫu tương ứng với nguồn gốc `SYSTEM_TEMPLATE` hoặc `RECOMMENDATION` và cờ `is_user_modified = false`. Tuyệt đối không tạo `budget_items`.
*   **`TOP-WED-003` (Archive Wedding):** Chuyển đám cưới sang trạng thái lưu trữ đọc-ghi giới hạn (`weddings.status = 'ARCHIVED'`). Khách vãng lai Guest Web bị chặn RSVP. Toàn bộ ban tổ chức bị chặn ghi qua Class B Data API.
*   **`TOP-WED-004` (Delete Wedding):** Xóa vĩnh viễn dữ liệu đám cưới. Thực hiện xóa cascade toàn bộ các bảng con liên quan và dọn dẹp Storage media cưới (Mục G).

### 2. Nhóm Nghiệp Vụ Thành Viên (Membership Operations)
*   **`TOP-MEM-001` (Create Pending Collaborator Invitation):** OWNER mời một tài khoản khác tham gia ban tổ chức bằng cách tạo bản ghi lời mời ở trạng thái `PENDING`.
*   **`TOP-MEM-002` (Revoke Pending Invitation):** OWNER hủy bỏ lời mời thành viên chưa được chấp nhận, chuyển trạng thái sang `REVOKED`.
*   **`TOP-MEM-003` (Accept Pending Invitation):** Người nhận lời mời đồng ý tham gia đám cưới (Mục F).
*   **`TOP-MEM-004` (Revoke WeddingMember):** OWNER loại bỏ một thành viên khỏi ban tổ chức bằng cách chuyển trạng thái sang `REVOKED`. OWNER hoạt động tối thiểu phải >= 1 (Mục H).

### 3. Nhóm Nghiệp Vụ Sự Kiện & Lập Kế Hoạch (Event & Planning Operations)
*   **`TOP-EVT-001` (Select/Change Main Event):** Thiết lập một sự kiện cưới con làm sự kiện chính. Một đám cưới luôn phải có duy nhất một Main Event. Không cho phép hủy Main Event hiện tại trừ khi một lễ con khác được gán làm Main Event mới.
*   **`TOP-EVT-002` (Wedding Event Date/Precision Change):** Thay đổi ngày/tháng của sự kiện cưới con và cập nhật lại hạn chót của các Task phụ thuộc dựa trên thuộc tính `deadline_intent` (Chi tiết tại Mục C).
*   **`TOP-EVT-003` (Event Removal):** Hủy bỏ một sự kiện con và xử lý tác động liên hoàn (Chi tiết tại Mục D).

### 4. Nhóm Nghiệp Vụ Khách Mời (Guest Management Operations)
*   **`TOP-GUE-001` (Primary Group Delete):** Xóa nhóm quan hệ. Tính toán số lượng khách ảnh hưởng, gỡ liên kết `primary_group_id = NULL` trên khách thuộc nhóm và xóa bản ghi `primary_groups` (Khách lẻ không bị xóa).
*   **`TOP-GUE-002` (Guest Party Move/Remove):** Di chuyển khách sang Party khác. Hạn mức mời `invited_count` của Party cũ và Party mới không được tự động thay đổi âm thầm mà phải do ban tổ chức tự điều chỉnh thủ công.
*   **`TOP-GUE-003` (Guest Duplicate Merge):** Gộp thông tin khách trùng lặp (Chi tiết tại Mục E).
*   **`TOP-GUE-004` (Confirm Excel Import):** Xác nhận ghi nhận hàng loạt khách mời từ bảng nháp thiết bị. revalidate định dạng SĐT/Email, duplicate check, ghi hàng loạt dưới dạng lô (batch).

### 5. Nhóm Nghiệp Vụ Tài Chính (Finance Operations)
*   **`TOP-FIN-001` (Payment Create):** OWNER ghi nhận giao dịch thanh toán cho khoản chi. Đợt thanh toán `installment_id` (nếu gán) bắt buộc phải thuộc cùng một khoản chi `budget_item_id`. Thanh toán lớn hơn số tiền installment cho phép (không tự động phân bổ). Thành viên thanh toán (`payer_wedding_member_id`) bắt buộc là thành viên `ACTIVE` tại thời điểm gán.
*   **`TOP-FIN-002` (Payment Controlled Edit):** OWNER hiệu chỉnh thông tin giao dịch ở trạng thái `ACTIVE`. Trường `budget_item_id` là bất biến (immutable). Nếu thay đổi `payer_wedding_member_id` mới, thành viên đó bắt buộc là `ACTIVE`. Nếu sai khoản chi, buộc phải gọi nghiệp vụ hủy (Void) và tạo lại.
*   **`TOP-FIN-003` (Payment Void):** OWNER hủy giao dịch chi tiêu, cập nhật `status = 'VOIDED'` cùng vết hủy `voided_at`, `voided_by_user_id`, và lý do. Bản ghi được bảo lưu nhưng loại trừ khỏi derived views tài chính.
*   **`TOP-FIN-004` (Refund Create):** OWNER ghi nhận giao dịch tiền mặt hoàn lại thực tế (`amount > 0`). Không được sử dụng làm công cụ sửa lỗi nhập sai của Payment.
*   **`TOP-FIN-005` (Refund Controlled Edit):** OWNER sửa thông tin giao dịch hoàn tiền đang hoạt động (cấm sửa `budget_item_id`).
*   **`TOP-FIN-006` (Refund Void):** OWNER hủy giao dịch hoàn tiền, chuyển sang `VOIDED` và ghi vết.
*   **`TOP-FIN-007` (Installment Compound Change):** Sửa đổi đợt thanh toán kế hoạch đã phát sinh lịch sử thanh toán hoặc có liên kết Payment (FK RESTRICT bảo vệ) được nâng cấp lên Class C để đánh giá lại dòng tiền.

### 6. Nhóm Nghiệp Vụ Thiệp Mời & RSVP (Invitation & RSVP Operations)
*   **`TOP-INV-001` (Credential Regeneration):** Thu hồi mã truy cập cũ và cấp phát mã mới (Chi tiết tại Mục G).
*   **`TOP-INV-002` (Organizer Manual RSVP Update):** Ban tổ chức tự cập nhật RSVP thủ công dựa trên các ràng buộc nghiệp vụ (Chi tiết tại Mục I).

---

## C. Ma Trận Thay Đổi Ngày/Độ Chính Xác Sự Kiện (`TOP-EVT-002`)

Bảng dưới đây mô tả chi tiết logic cập nhật lại hạn chót Task phụ thuộc đối với từng loại chuyển đổi:

| Trạng thái ban đầu | Trạng thái ghi mới | `deadline_intent` ảnh hưởng | Hành vi tính toán lại ngày chốt (`resolved_deadline_at`) |
| :--- | :--- | :--- | :--- |
| **Exact Date** | **Exact Date** | `SYSTEM_RELATIVE` | `Event.exact_date + system_offset` |
| | | `USER_RELATIVE` | `Event.exact_date + user_offset` |
| | | `USER_ABSOLUTE` / `NO_DEADLINE` | Giữ nguyên, không thay đổi ngày chốt. |
| **Expected Month** | **Exact Date** | `SYSTEM_RELATIVE` / `USER_RELATIVE`| Phân giải thành ngày chốt dương lịch chính xác sử dụng relative offset tương ứng. |
| **Exact Date** | **Expected Month** | `SYSTEM_RELATIVE` / `USER_RELATIVE`| Bảo lưu intent và offset. Cột hạn chót dương lịch chuyển thành `NULL` (unresolved). Cấm gán ngày cưới giả lập. |
| | | `USER_ABSOLUTE` | Giữ nguyên ngày dương lịch đã chốt. |
| **Expected Month** | **Expected Month** | `SYSTEM_RELATIVE` / `USER_RELATIVE`| Bảo lưu intent và offset. Hạn chót dương lịch giữ nguyên `NULL` (unresolved). |
| **Bất kỳ** | **Bất kỳ** | **Task có trạng thái `COMPLETED`** | Bảo lưu mốc ngày chốt lịch sử thực tế (`resolved_deadline_at`), cấm ghi đè cho toàn bộ quá trình dịch chuyển ngày/độ chính xác. |

---

## D. Quy Tắc Xử Lý Khi Hủy Sự Kiện (`TOP-EVT-003` - Đã ghi nhận `ERRATA-TOP-001`)

Khi một lễ cưới con bị hủy bỏ, hệ thống thực thi việc gỡ bỏ và dọn dẹp đầu việc mẫu theo nguyên tắc bảo toàn ý định người dùng (User Intent):

1.  **Untouched Active Tasks:** Đầu việc hệ thống mẫu chưa chỉnh sửa (`task_source` thuộc `SYSTEM_TEMPLATE` hoặc `RECOMMENDATION` và `is_user_modified = false` và chưa hoàn thành) $\rightarrow$ Đề xuất xóa trong Impact Review.
2.  **User-created hoặc User-modified Tasks (Được giữ lại):**
    *   Tách biệt và dời liên kết lên mức Wedding-level (`wedding_event_id = NULL`).
    *   *Điều chỉnh ngày chót:*
        *   Nếu là Task tương đối (`SYSTEM_RELATIVE` hoặc `USER_RELATIVE`) và **đã phân giải được Calendar Due Date** cụ thể trước khi hủy sự kiện $\rightarrow$ Chuyển `deadline_intent` sang `USER_ABSOLUTE` và gán cứng mốc Calendar Due Date đó.
        *   Nếu **chưa có Calendar Due Date** do sự kiện trước đó ở Expected Month mode $\rightarrow$ Chuyển `deadline_intent` thành `NO_DEADLINE` và tự động đánh dấu `Needs Review`.
        *   Task tuyệt đối `USER_ABSOLUTE` hoặc `NO_DEADLINE` $\rightarrow$ Giữ nguyên.
3.  **Completed Tasks (Được giữ lại - `ERRATA-TOP-001`):**
    *   Tách biệt lên mức Wedding-level (`wedding_event_id = NULL`).
    *   *Điều chỉnh ngày chót:*
        *   Nếu **đã phân giải được Calendar Due Date** cụ thể trước đó $\rightarrow$ Chuyển `deadline_intent` sang `USER_ABSOLUTE` dùng mốc ngày chốt dương lịch phân giải đó. Các mốc snapshot ngày chốt lịch sử (`completed_at`, `resolved_deadline_at`) giữ nguyên không đổi.
        *   Nếu **chưa từng phân giải được ngày chốt** (do nằm trong Expected Month) $\rightarrow$ Chuyển `deadline_intent` thành `NO_DEADLINE`. Trạng thái `COMPLETED` và lịch sử hoàn thành cũ được bảo toàn nguyên vẹn.

---

## E. Quy Tắc Gộp Khách Trùng Lặp (`TOP-GUE-003` - Đã ghi nhận `ERRATA-TOP-002`)

1.  **Định nghĩa Khách đích:** Người dùng bắt buộc phải tự tay lựa chọn khách hàng sống sót/đích (surviving/destination Guest) trong danh sách gộp. Cấm hệ thống tự ý chỉ định.
2.  **Giải quyết xung đột:** Các trường dữ liệu xung đột (`phone`, `email`, `side`, `guest_source`, `primary_group_id`) phải được hiển thị và xử lý thủ công qua giao diện gộp.
3.  **Xung đột Nhóm mời (Invitation Party Conflict):** Nếu 2 khách thuộc 2 Party khác nhau, hệ thống buộc người dùng chọn Party đích trong Impact Review (cấm tự chọn). 
4.  **Bảo toàn lịch sử:** Thiệp mời, RSVP và phản hồi sự kiện được giữ nguyên tại Party sở hữu. Không thực hiện việc chuyển đổi hay ghi lại quyền sở hữu RSVP từ Party này sang Party khác.
5.  **Xử lý khách phụ (`ERRATA-TOP-002`):** Khách phụ chỉ được phép xóa cứng (hard-delete) nếu đáp ứng đầy đủ điều kiện an toàn xóa khách (không còn liên kết downstream). Nếu bị chặn xóa do ràng buộc dữ liệu lịch sử quan trọng, hệ thống trả về lỗi `Conflict / Impact Resolution Required` để người dùng xử lý thủ công, cấm tự ý sinh ra trạng thái logic `inactive` hoặc ẩn đi ngầm.

---

## F. Chấp Nhận Lời Mời Collaborator (`TOP-MEM-003`)

*   **Xác thực:** Yêu cầu tài khoản Google Auth đăng nhập trùng khớp với email lời mời và hành động bấm chấp nhận rõ ràng (Accept). Nếu người dùng chọn bỏ qua (Not Now), không có dữ liệu nào bị thay đổi và lời mời giữ trạng thái `PENDING`.
*   **Không cho phép đăng nhập sai tài khoản:** Tài khoản không trùng khớp địa chỉ email lời mời sẽ bị từ chối claim link lời mời.
*   **Xử lý thành viên cũ bị REVOKED:** Nếu người dùng này đã từng có bản ghi `wedding_members` ở trạng thái `REVOKED` trong đám cưới này, hệ thống sẽ thực hiện kích hoạt lại (reactivate) bản ghi cũ thành `status = 'ACTIVE'` và cập nhật `display_name`, `profile_email` mới của họ, thay vì insert thêm một dòng mới gây trùng lặp.
*   **Đồng bộ dữ liệu:** Chấp nhận thành công sẽ chuyển đổi lời mời sang `ACCEPTED` và kích hoạt thành viên `ACTIVE` trong cùng 1 transaction DB. Email lời mời chỉ dùng để bootstrap ban đầu, sau đó phân quyền hoàn toàn dùng User ID cố định.

---

## G. Cơ Chế Tái Tạo Mã Thiệp Mời (`TOP-INV-001`)

*   **Logic thực thi:** Khi ban tổ chức kích hoạt yêu cầu tái tạo mã:
    *   Bản ghi credential active hiện tại (nếu có) bị đánh dấu `is_active = false` và lưu vết thời gian `revoked_at`.
    *   Hệ thống sinh một bản ghi `invitation_credentials` mới và trả mã Token thô duy nhất về client. Chỉ lưu trữ băm SHA-256 nhị phân của token trên cơ sở dữ liệu.
*   **Khi gọi lại (Safe Retry):** Trong trường hợp lỗi mạng mất response, client gọi lại yêu cầu:
    *   Hệ thống tiếp tục thực hiện vô hiệu hóa credential đang hoạt động gần nhất đó, sinh credential hoàn toàn mới và trả về Token mới. Không yêu cầu replay lại mã Token cũ.
    *   Bảo đảm sau khi commit giao dịch, chỉ có duy nhất **1 active credential** tồn tại. Định danh thiệp mời và lịch sử RSVP giữ nguyên.

---

## H. Thu Hồi Thành Viên & Quyền OWNER Tối Thiểu (`TOP-MEM-004`)

*   Cấm thu hồi tư cách thành viên ban tổ chức nếu hành động này dẫn đến số lượng OWNER hoạt động của đám cưới bé hơn 1 (lỗi `FINAL_OWNER_INVARIANT`).
*   Lịch sử phân công cũ tại các Task, Budget, Payer của người bị thu hồi được giữ nguyên vẹn.
*   Khi có yêu cầu gọi lại (retry) một thao tác thu hồi đã hoàn thành trước đó, hệ thống trả về kết quả thành công và không tạo ra bất kỳ side-effect nào khác.

---

## I. Ban Tổ Chức Cập Nhật RSVP Thủ Công (`TOP-INV-002` - Đã ghi nhận `ERRATA-TOP-004`)

*   **Xác thực đầy đủ:** Thao tác cập nhật RSVP thủ công của Ban tổ chức phải kiểm tra an toàn:
    *   Thiệp mời (`invitations`) thuộc Đám cưới đang thao tác.
    *   Sự kiện cưới con (`wedding_events`) được target trong thiệp mời đó đang hoạt động (không bị `REMOVED`).
    *   Sự kiện cưới con đã có ngày cưới chính xác (`Exact Date` exists) để đảm bảo trạng thái RSVP-ready.
    *   Trạng thái phản hồi và số lượng đi kèm hợp lệ:
        *   `ATTENDING`: Số khách tham dự `attending_count` phải lớn hơn hoặc bằng 1.
        *   `NOT_ATTENDING`: Số khách tham dự `attending_count` phải bằng 0.
*   **RSVP Overcount:** Cho phép số khách đăng ký vượt quá hạn mức mời (`Attending Count > Invited Count`), ghi nhận phản hồi và sinh cảnh báo warning, không chặn lỗi.
*   **Cutoff:** Hạn chốt cutoff date không được phép chặn thao tác ghi thủ công của ban tổ chức.
*   **Không có supremacy vĩnh viễn:** Trước cutoff date, nếu khách tự cập nhật lại thì bản cập nhật mới nhất của khách sẽ ghi đè trạng thái của ban tổ chức (Latest valid update wins).

---

## J. Điều Phối Hủy Đám Cưới & File Storage (`TOP-WED-004` - Đã ghi nhận `ERRATA-PHY-008`)

*   **Điều phối đa tài nguyên:** Hành vi xóa đám cưới bao gồm hai chặng: chuyển trạng thái sang `DELETING` và xóa cascade PostgreSQL sau khi đã xóa Storage thành công.
*   **Quy trình khôi phục an toàn (Delete Recovery Protocol):**
    1. OWNER xác thực quyền và yêu cầu xóa đám cưới.
    2. Đám cưới chuyển status sang `DELETING` (giữ nguyên member phục vụ authorization).
    3. Edge Function dọn dẹp Storage ảnh cưới.
    4. Chỉ sau khi Storage xóa thành công: thực thi DB cascade delete sạch bóng.
    5. Nếu Storage dọn dẹp lỗi dở dang: đám cưới giữ status `DELETING`, OWNER được quyền tiếp tục gọi lại (retry) để hoàn tất.
*   **Khi đã xóa DB thành công:** Nếu response phản hồi thành công bị mất, client gửi lại yêu cầu xóa $\rightarrow$ Hệ thống kiểm tra đám cưới không tồn tại sẽ trả về mã thành công trực tiếp (converged success).

---

## K. Đặc Tả Tính Giao Dịch (Atomicity Matrix)

Bảng dưới đây phân loại chi tiết phạm vi giao dịch đối với tất cả 24 nghiệp vụ tin cậy cụ thể:

| Mã Nghiệp Vụ | Tên Nghiệp Vụ Tin Cậy | Database Transaction? | Cross-Resource Orchestration? | Lý do Thiết kế |
| :--- | :--- | :---: | :---: | :--- |
| **`TOP-WED-001`** | Create Wedding Workspace | YES | NO | Đám cưới, Owner và receipt phải được tạo đồng thời trong 1 transaction DB. |
| **`TOP-WED-002`** | Generate Initial Plan | YES | NO | Tạo chuỗi sự kiện, task mẫu và set `initial_plan_generated_at` đồng thời. |
| **`TOP-WED-003`** | Archive Wedding | NO | NO | Thao tác ghi đơn dòng thay đổi status của weddings. |
| **`TOP-WED-004`** | Delete Wedding | YES (DB portion) | YES | DB status `DELETING` + Storage delete + DB cascade delete (Mục J). |
| **`TOP-MEM-001`** | Create Pending Invite | NO | NO | Tạo bản ghi đơn dòng trên pending_collaborator_invitations. |
| **`TOP-MEM-002`** | Revoke Pending Invite | NO | NO | Sửa bản ghi đơn dòng trạng thái lời mời. |
| **`TOP-MEM-003`** | Accept Invite | YES | NO | Cập nhật lời mời ACCEPTED và kích hoạt lại thành viên đồng thời. |
| **`TOP-MEM-004`** | Revoke Member | YES | NO | Thu hồi thành viên và kiểm tra số lượng OWNER hoạt động tối thiểu. |
| **`TOP-EVT-001`** | Main Event Change | YES | NO | Cập nhật trạng thái lễ chính cũ và lễ chính mới đồng thời. |
| **`TOP-EVT-002`** | Date/Precision Change | YES | NO | Đảm bảo đổi ngày lễ con và tính lại hạn chót các task liên quan đồng bộ. |
| **`TOP-EVT-003`** | Event Removal | YES | NO | Đảm bảo dọn dẹp task, gỡ targeting và đổi trạng thái sự kiện con đồng thời. |
| **`TOP-GUE-001`** | Primary Group Delete | YES | NO | Gỡ liên kết nhóm quan hệ trên khách trước khi xóa Group. |
| **`TOP-GUE-002`** | Party Move/Remove | NO | NO | Sửa bản ghi đơn dòng của khách lẻ. |
| **`TOP-GUE-003`** | Guest Merge | YES | NO | Thực hiện gộp hồ sơ khách mời và xóa khách phụ an toàn. |
| **`TOP-GUE-004`** | Confirm Import | YES | NO | Ghi nhận lô Excel và lưu receipt tin cậy trong cùng transaction DB. |
| **`TOP-FIN-001`** | Payment Create | YES | NO | Ghi nhận payment và lưu receipt tin cậy trong cùng transaction DB. |
| **`TOP-FIN-002`** | Payment Edit | NO | NO | Sửa bản ghi đơn dòng của payment. |
| **`TOP-FIN-003`** | Payment Void | YES | NO | Chuyển trạng thái payment sang VOIDED và cập nhật trạng thái đợt chi tiêu. |
| **`TOP-FIN-004`** | Refund Create | YES | NO | Ghi nhận refund và lưu receipt tin cậy trong cùng transaction DB. |
| **`TOP-FIN-005`** | Refund Edit | NO | NO | Sửa bản ghi đơn dòng của refunds. |
| **`TOP-FIN-006`** | Refund Void | YES | NO | Chuyển trạng thái refund sang VOIDED và cập nhật đợt chi tiêu liên quan. |
| **`TOP-FIN-007`** | Installment Compound Change | YES | NO | Sửa đổi đợt trả tiền và cân đối lại dòng tiền liên quan. |
| **`TOP-INV-001`** | Credential Regeneration | YES | NO | Đảm bảo thu hồi link cũ và cấp link mới diễn ra trong cùng 1 transaction. |
| **`TOP-INV-002`** | Manual RSVP Update | YES | NO | Cập nhật RSVP tổng và chi tiết tham dự các lễ con đồng thời. |

---

## L. Ma Trận Kết Quả Gọi Lại Nghiệp Vụ An Toàn (Safe Retry Matrix)

Bảng dưới đây quy định kết quả hội tụ nghiệp vụ mong đợi (semantic retry outcomes) cho tất cả 24 nghiệp vụ tin cậy cụ thể khi client thực hiện gọi lại do mất kết nối:

| Mã Nghiệp Vụ | Retry-safe Required? | Duplicate Side-effect Risk? | Kết quả hội tụ nghiệp vụ mong đợi (Desired Semantic Outcome) |
| :--- | :---: | :---: | :--- |
| **`TOP-WED-001`** | YES | YES | Chỉ tạo duy nhất 1 đám cưới, trả về thông tin đám cưới đã tạo qua receipt. |
| **`TOP-WED-002`** | YES | YES | Kiểm tra `initial_plan_generated_at IS NOT NULL` để trả về thành công trực tiếp, cấm sinh trùng lặp. |
| **`TOP-WED-003`** | YES | NO | Đám cưới giữ nguyên trạng thái `ARCHIVED`. |
| **`TOP-WED-004`** | YES | YES | OWNER tiếp tục dọn Storage nếu status = DELETING, trả về success nếu DB đã bị cascade delete thành công trước đó. |
| **`TOP-MEM-001`** | YES | YES | Chỉ tồn tại duy nhất 1 bản ghi mời pending cho email gửi đi. |
| **`TOP-MEM-002`** | YES | NO | Lời mời giữ nguyên trạng thái `REVOKED`. |
| **`TOP-MEM-003`** | YES | YES | Lời mời thành công ở trạng thái `ACCEPTED`, thành viên `ACTIVE`. |
| **`TOP-MEM-004`** | YES | NO | Thành viên giữ nguyên trạng thái `REVOKED`, không sinh lỗi. |
| **`TOP-EVT-001`** | YES | NO | Lễ con chỉ định giữ vai trò Main Event, các lễ khác là false. |
| **`TOP-EVT-002`** | YES | NO | Hạn chót Task cập nhật khớp chính xác theo ngày cưới con mới nhất. |
| **`TOP-EVT-003`** | YES | NO | Lễ con chuyển sang `REMOVED`, các task liên quan giữ trạng thái đã xử lý. |
| **`TOP-GUE-001`** | YES | NO | Nhóm quan hệ bị xóa, liên kết khách hàng giữ trạng thái NULL. |
| **`TOP-GUE-002`** | YES | NO | Khách mời chuyển sang nhóm mời chỉ định mới. |
| **`TOP-GUE-003`** | YES | YES | Khách phụ đã bị xóa, hồ sơ khách chính tích hợp thông tin gộp ổn định. |
| **`TOP-GUE-004`** | YES | YES | Kiểm tra receipt tin cậy chống import trùng lặp tệp dữ liệu. |
| **`TOP-FIN-001`** | YES | YES | Kiểm tra receipt tin cậy chống ghi đúp tiền payment. |
| **`TOP-FIN-002`** | YES | NO | Thông tin sửa đổi payment cập nhật khớp giá trị gọi cuối cùng. |
| **`TOP-FIN-003`** | YES | NO | Payment chuyển sang `VOIDED`, không sinh lỗi. |
| **`TOP-FIN-004`** | YES | YES | Kiểm tra receipt tin cậy chống ghi đúp tiền refund. |
| **`TOP-FIN-005`** | YES | NO | Thông tin sửa đổi refund cập nhật khớp giá trị gọi cuối cùng. |
| **`TOP-FIN-006`** | YES | NO | Refund chuyển sang `VOIDED`, không sinh lỗi. |
| **`TOP-FIN-007`** | YES | NO | Đợt chi tiêu cập nhật khớp giá trị gọi cuối cùng. |
| **`TOP-INV-001`** | YES | YES | Hủy link cũ, sinh link mới active. Chấp nhận sinh Token mới (không replay). |
| **`TOP-INV-002`** | YES | NO | RSVP tổng và lễ con cập nhật khớp giá trị gửi tham dự cuối cùng. |

---

## M. Sổ Nhật Ký Phát Hiện Xung Đột Trusted Operations (Trusted-Op Conflict/Gap Register)

*   **`TRUSTED-OP-CONFLICT-001` (Deadline recalculation intent) $\rightarrow$ RESOLVED.**
*   **`TRUSTED-OP-CONFLICT-002` (Guest/RSVP ownership) $\rightarrow$ RESOLVED.**
*   **`TRUSTED-OP-CONFLICT-003` (RSVP overcount validation) $\rightarrow$ RESOLVED.**
*   **`TRUSTED-OP-CONFLICT-004` (Safe-retry implementation prematurely locked) $\rightarrow$ RESOLVED.**
*   **`ERRATA-PHY-007` (Initial Plan Generation Marker) $\rightarrow$ RESOLVED.** Sử dụng `initial_plan_generated_at` làm mốc chỉ dấu.
*   **`ERRATA-PHY-008` (Wedding DELETING Lifecycle) $\rightarrow$ RESOLVED.** Cấp trạng thái `DELETING` cho vòng đời đám cưới.
*   **`ERRATA-PHY-009` (Durable Trusted Operation Receipts) $\rightarrow$ RESOLVED.** Bổ sung bảng kỹ thuật nội bộ `private.trusted_operation_receipts` chống trùng lặp.
