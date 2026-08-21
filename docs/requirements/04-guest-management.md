# Đặc Tả Yêu Cầu Chi Tiết: REQ-04 — Guest Management

Tài liệu này đặc tả chi tiết các yêu cầu nghiệp vụ phần mềm cho Phân hệ **REQ-04 — Guest Management (Quản lý Khách mời)** của hệ thống WeddingOS.

---

## 1. Mô Hình Tư Duy Khách Mời (Guest Mental Model)

*   **Không dùng Danh bạ Toàn cục (No Global Contacts):** MVP không hỗ trợ danh bạ dùng chung hay đồng bộ danh bạ từ điện thoại. Khách mời được lưu trực tiếp và độc lập trong phạm vi của từng Đám cưới (`Wedding`).
*   **Phân biệt rõ cá nhân (Guest) & nhóm mời (InvitationParty):**
    *   `Guest`: Cá nhân cụ thể có tên trong danh sách.
    *   `InvitationParty` (UI Term: *Nhóm mời*): Đơn vị nhận thiệp mời và phản hồi RSVP chung. Một nhóm mời có thể đại diện cho một cá nhân đơn lẻ, một cặp đôi, một gia đình hoặc một nhóm bạn thân.
    *   *Tính ràng buộc:* Một Guest có thể tồn tại độc lập mà chưa được gán vào bất kỳ Nhóm mời nào (`InvitationPartyId = NONE`). Tuy nhiên, Guest bắt buộc phải thuộc một Nhóm mời trước khi chuẩn bị hoặc gửi thiệp mời (Luồng thiệp mời thuộc REQ-05).
*   **Độc lập giữa Side và Source:**
    *   `Guest Side` (COMMON, BRIDE_SIDE, GROOM_SIDE) thể hiện khách thuộc phía nhà trai hay nhà gái.
    *   `Guest Source` (Khách của ai, ví dụ: *Bố chú rể, Mẹ cô dâu...*) thể hiện nguồn gốc người mời của khách đó. Không ràng buộc Side phải trùng khớp với Source.

---

## 2. Các Ma Trận Nghiệp Vụ Quyết Định (Decision Matrices)

### A. Ma Trận Quan Hệ Khách Mời & Nhóm Mời (Guest ↔ Invitation Party Membership Matrix)

Quy tắc liên kết giữa cá nhân (`Guest`) và Nhóm mời (`InvitationParty`):

*   **Tính chất:** Một `Guest` thuộc tối đa một `InvitationParty` (0..1). Một `InvitationParty` chứa từ 0 đến nhiều `Guest` (0..N).

| Hành động của Người dùng | Hành vi của Hệ thống (System Behavior) | Kết quả & Ảnh hưởng đến Số lượng người mời (`Invited Count`) |
| :--- | :--- | :--- |
| **Tạo khách lẻ không gán nhóm** | Khởi tạo thực thể `Guest` độc lập. Trường `InvitationPartyId = NONE`. | Guest hiển thị trong danh sách "Khách lẻ". Chưa có liên kết nhóm mời. |
| **Gán Khách lẻ vào Nhóm mời A** | Thiết lập liên kết `InvitationPartyId` của Guest sang nhóm A. | Guest chuyển sang danh sách Nhóm mời. Không tự động thay đổi `Invited Count` của nhóm A (giữ nguyên user intent). |
| **Di chuyển Guest từ Nhóm A sang Nhóm B** | Gỡ liên kết cũ, thiết lập `InvitationPartyId` của Guest sang nhóm B. | Nếu Nhóm A trở thành trống (0 named Guests), hệ thống xử lý theo Ma trận D. Không tự động điều chỉnh `Invited Count` của cả hai nhóm. |
| **Gỡ Guest ra khỏi Nhóm mời A** | Đặt trường `InvitationPartyId = NONE`. | Guest quay trở lại danh sách Khách lẻ. Nếu Nhóm A trống, xử lý theo Ma trận D. |

---

### B. Ma Trận Trùng Lặp & Gộp Khách (Duplicate Detection / Merge Matrix)

Quy tắc phát hiện trùng lặp và xử lý gộp hồ sơ khách mời:

*   **Tín hiệu trùng lặp:**
    *   *Tín hiệu mạnh (Strong Signal):* Trùng số điện thoại sau khi chuẩn hóa (bỏ khoảng trắng, mã vùng `+84` quy đổi về đầu số `0`).
    *   *Tín hiệu yếu (Weak Signal):* Trùng tên (so sánh case-insensitive, không dấu tiếng Việt).

| Trường hợp Trùng lặp phát hiện | Trạng thái Nhóm mời của 2 Guest | Hành vi của Hệ thống khi gộp (Merge) | Luồng Người dùng & Quyết định (PO Decision - Option C) |
| :--- | :--- | :--- | :--- |
| **Hai Guest trùng SĐT** | Cùng thuộc 1 Nhóm mời | Gộp dữ liệu cá nhân. Giữ nguyên thông tin Nhóm mời. | Hệ thống tự động gộp phần thông tin text và số điện thoại nếu trùng khớp hoàn toàn, không cần review. |
| **Hai Guest trùng SĐT** | Thuộc 2 Nhóm mời khác nhau (Nhóm A và Nhóm B) | **Không tự động chọn nhóm mời đích**. | **Mở màn hình Review (Impact Review - AND-GUE-06)**. Yêu cầu user chọn: (1) Giữ Nhóm A, (2) Giữ Nhóm B, hoặc (3) Di chuyển Guest gộp sang Nhóm mới. |
| **Xung đột trường dữ liệu (conflicting fields)** | Bất kỳ | Hệ thống tự động điền các trường không xung đột (một bên trống, một bên có dữ liệu). | **Chỉ hiển thị các trường có xung đột** (Ví dụ: Khách A có Group "Đại học", Khách B có Group "Đồng nghiệp") lên màn hình review để user chốt giá trị thắng cuộc. Không hiển thị các trường giống nhau. |
| **Hai Guest trùng SĐT** | Một Guest đã có RSVP downstream (REQ-05) | Bảo toàn dữ liệu RSVP lịch sử của Guest cũ. | Khóa không cho phép ghi đè thông tin RSVP lịch sử. Cảnh báo hiển thị trên màn hình review. |

---

### C. Ma Trận Tác Động Xóa Khách Mời (Guest Removal Impact Matrix)

Quy tắc xử lý khi người dùng xóa một thực thể cá nhân (`Guest`) khỏi đám cưới:

| Liên kết Nhóm mời của Guest bị xóa | Lịch sử thiệp / RSVP (REQ-05) | Hành vi hệ thống đối với Nhóm mời | Kết quả & Ảnh hưởng đến Số lượng người mời (`Invited Count`) |
| :--- | :--- | :--- | :--- |
| **Không liên kết nhóm (unassigned)** | Không có | Xóa cứng thực thể `Guest` khỏi DB. | Không ảnh hưởng đến nhóm mời nào. |
| **Có liên kết Nhóm A** | Không có | Xóa Guest khỏi Nhóm A. Bảo toàn Nhóm A. | Số lượng người mời (`Invited Count`) của Nhóm A **không tự động giảm** (giữ nguyên ý định số lượng mời của nhóm). |
| **Có liên kết Nhóm A** | Là Guest duy nhất của Nhóm A | Xóa Guest khỏi Nhóm A. Nhóm A trở thành Nhóm trống (0 named Guests). | Nhóm A được giữ lại làm Nhóm trống. Hệ thống xử lý dọn dẹp theo Ma trận D. |
| **Guest có downstream history** | Đã phát sinh RSVP hoặc gửi thiệp | **Chặn xóa cứng** thông qua luồng thông thường để tránh phá vỡ lịch sử kế toán/RSVP (Chuyển sang REQ-05 xử lý). | Giao diện hiển thị cảnh báo lỗi dữ liệu lịch sử. |

---

## D. Ma Trận Dọn Dẹp Nhóm Trống (Invitation Party Empty/Cleanup Matrix)

Quy tắc xử lý đối với Nhóm mời không có cá nhân nào được khai báo tên cụ thể (Nhóm trống - 0 named Guests):

| Nhóm mời bị trống | Trạng thái gửi thiệp / RSVP (REQ-05) | Hành vi của Hệ thống (System Behavior) | Kết quả hiển thị & Xử lý |
| :--- | :--- | :--- | :--- |
| **Nhóm trống mới tạo hoặc trống sau khi dời Guest** | Chưa gửi thiệp / Chưa phát sinh RSVP | **Không tự động xóa**. Cho phép tồn tại nhóm trống trong danh sách quản lý. | Hệ thống cung cấp nút đề xuất dọn dẹp/xóa nhóm trống thủ công nếu người dùng muốn làm sạch danh sách. |
| **Nhóm trống sau khi dời Guest** | **Đã phát sinh RSVP hoặc đã gửi thiệp** | **Chặn tự động xóa cứng** và bảo toàn thực thể nhóm mời để lưu trữ token/lịch sử RSVP. | Giao diện hiển thị cảnh báo nhóm trống có lịch sử (chờ REQ-05 đặc tả hành vi bảo toàn chi tiết). |

---

## E. Ma Trận Kết Quả Từng Dòng Excel (Import Row Result Matrix)

Quy tắc phân loại kết quả kiểm tra tính hợp lệ dữ liệu của tệp Excel tải lên trong màn hình Preview (**AND-GUE-07**):

| Tình trạng Dòng (Excel Row State) | Tính hợp lệ dữ liệu | Hành vi xử lý/review bắt buộc | Ý nghĩa hiển thị trên giao diện Android |
| :--- | :--- | :--- | :--- |
| **`VALID`** | Đầy đủ tên khách, Side hợp lệ, Invited Count hợp lệ, Party Key hợp lệ. | Không trùng số điện thoại, không cần mapping. | 🟢 **Sẵn sàng nhập**. Cho phép nạp thẳng vào DB khi Confirm Import. |
| **`WARNING`** | Có tên khách, dữ liệu cấu trúc hợp lệ. | Phát hiện trùng SĐT (Duplicate Candidate) hoặc dòng chứa Nhóm quan hệ mới sẽ được khởi tạo. | 🟡 **Cảnh báo**. Không chặn import nhưng hiển thị nhãn cảnh báo (Ví dụ: *"Trùng SĐT"*, *"Nhóm mới 'Bạn đá bóng' sẽ được tạo"*). |
| **`MAPPING_REQUIRED`** | Khai báo Nguồn mời (`Guest Source`) chưa có trong hệ thống mẫu (Ví dụ: ghi *"Bố CR"*). | **Bắt buộc user phải ánh xạ (map)** giá trị này sang một controlled Source mẫu trước khi nạp. | 🟡 **Chờ ánh xạ**. Dòng này bị chặn không cho Confirm Import cho tới khi hoàn tất ánh xạ trên màn hình preview. |
| **`ERROR`** | Thiếu tên khách, hoặc sai Side, hoặc sai Invited Count, hoặc cùng Party Key nhưng khác Display Name/Invited Count. | Bất kỳ | 🔴 **Lỗi**. Dòng dữ liệu không hợp lệ cấu trúc. Bị chặn tuyệt đối, không cho phép nhập vào DB. |

---

## 3. Flow REQ-04.1 — Add / Edit Guest & Proxy Setup

### Goal
Cho phép người dùng thêm mới hoặc chỉnh sửa thông tin của từng cá nhân khách mời trong đám cưới, hỗ trợ khai báo khách thay cho bố mẹ (Proxy) mà không cần tạo tài khoản riêng cho họ.

### Actors
*   Cặp đôi (Cô dâu/Chú rể).

### Preconditions
*   Người dùng đã truy cập vào đám cưới hiện tại.

### Trigger
*   Người dùng bấm nút "Thêm khách mời" (+) trên giao diện Khách lẻ của màn hình Directory (**AND-GUE-01**).

### Main Flow
1.  Hệ thống hiển thị màn hình Tạo/Sửa Khách mời (**AND-GUE-03**).
2.  Người dùng nhập các trường thông tin:
    *   Họ và tên (Bắt buộc).
    *   Số điện thoại (Tùy chọn).
    *   Email (Tùy chọn).
    *   Chọn Phía gia đình (`Side`: `COMMON`, `BRIDE_SIDE`, `GROOM_SIDE` - Bắt buộc).
    *   Chọn Nguồn mời (`Guest Source`: `Bride`, `Groom`, `Bride's Father`, `Bride's Mother`, `Groom's Father`, `Groom's Mother`, `Other` - Bắt buộc).
    *   Chọn Nhóm quan hệ chính (`Primary Group` - Bắt buộc).
3.  Người dùng bấm "Lưu".
4.  Hệ thống kiểm tra trùng lặp số điện thoại (nếu có nhập):
    *   *Nếu trùng:* Chuyển hướng sang Flow Phát hiện & Gộp trùng lặp (REQ-04.3).
    *   *Nếu không trùng:* Tạo thực thể `Guest` mới trong cơ sở dữ liệu và đưa về danh sách.

### Alternate Flows (Gán Nhóm mời sau)
1.  Người dùng tạo khách mời mới và bỏ trống mục gán Nhóm mời.
2.  Hệ thống lưu khách với trường `InvitationPartyId = NONE`. Khách hiển thị trong danh sách "Khách lẻ".
3.  Sau đó, tại màn hình chi tiết khách (**AND-GUE-02**), người dùng bấm nút `"Gán vào Nhóm mời"`.
4.  Hệ thống mở Bottom Sheet hiển thị danh sách các Nhóm mời sẵn có hoặc nút tạo Nhóm mới.
5.  Người dùng chọn nhóm mời $\rightarrow$ Hệ thống cập nhật liên kết `InvitationPartyId` mà không thay đổi `Invited Count` của nhóm đó.

### Functional Requirements
*   **GUE-FR-001:** Hệ thống **PHẢI** hỗ trợ trường Nguồn mời (`Guest Source`) cho phép phân loại danh sách khách của bố mẹ (ví dụ: *Khách của Bố chú rể, Khách của Mẹ cô dâu*) để phục vụ công tác lọc và kiểm tra danh sách chéo. *(Screen: AND-GUE-03)*
*   **GUE-FR-002:** Thiết kế form nhập liệu tạo mới/chỉnh sửa khách mời **PHẢI** tự động khôi phục nội dung đang nhập (nháp) trên Android nếu phiên làm việc bị gián đoạn đột ngột. *(Screen: AND-GUE-03)*

### Business Rules
*   **GUE-BR-001:** Số điện thoại của khách mời không được coi là định danh tuyệt đối (Identity Proof) của khách trong hệ thống. Hệ thống không bắt buộc trường Số điện thoại phải luôn có giá trị (cho phép để trống).

### Validation Rules
*   **GUE-VAL-001:** Họ và tên khách mời không được để trống và có độ dài tối đa là 50 ký tự. Số điện thoại (nếu có nhập) phải tuân thủ định dạng số điện thoại Việt Nam hợp lệ.

### Acceptance Criteria
*   **GUE-AC-001 (Unassigned Guest Creation):**
    *   *Given:* Người dùng mở form tạo khách mời mới (**AND-GUE-03**).
    *   *When:* Người dùng nhập tên "Nguyễn Văn A" và chọn lưu mà không gán nhóm mời.
    *   *Then:* Khách mời được lưu thành công trong cơ sở dữ liệu ở trạng thái `InvitationPartyId = NONE` và xuất hiện trong tab "Khách lẻ".
*   **GUE-AC-002 (Assign Party Later):**
    *   *Given:* Khách mời "Nguyễn Văn A" đang ở trạng thái `InvitationPartyId = NONE`. Nhóm mời "Gia đình bác Tư" đang có `Invited Count = 4`.
    *   *When:* Người dùng thực hiện gán khách "Nguyễn Văn A" vào nhóm "Gia đình bác Tư".
    *   *Then:* Hệ thống cập nhật liên kết nhóm thành công. Số lượng người mời `Invited Count` của nhóm "Gia đình bác Tư" vẫn giữ nguyên tuyệt đối là `4`.

---

## 4. Flow REQ-04.2 — Invitation Party Management (Nhóm Mời)

### Goal
Tạo lập và cấu hình các nhóm nhận thiệp mời chung (InvitationParty) để quản lý số lượng người mời phát thiệp chính xác.

### Actors
*   Cặp đôi.

### Preconditions
*   Người dùng đang ở danh sách Nhóm mời của màn hình Directory (**AND-GUE-01**).

### Trigger
*   Người dùng bấm nút "Thêm nhóm mời" hoặc bấm chọn một nhóm mời có sẵn.

### Main Flow
1.  Hệ thống hiển thị màn hình Tạo/Sửa Nhóm mời (**AND-GUE-05**).
2.  Người dùng nhập các trường thông tin:
    *   Tên hiển thị thiệp (Ví dụ: *"Gia đình bác Tư"*, *"Anh Nam & bạn"* - Bắt buộc).
    *   Số lượng người mời (`Invited Count` - Bắt buộc).
3.  Người dùng lựa chọn thêm các `Guest` cá nhân có sẵn vào nhóm hoặc để trống (named guests = 0).
4.  Người dùng bấm "Lưu".
5.  Hệ thống lưu cấu hình thực thể `InvitationParty`.
6.  Cập nhật thông tin hiển thị lên danh sách.

### Functional Requirements
*   **GUE-FR-003:** Hệ thống **PHẢI** cho phép số lượng người mời (`Invited Count`) lớn hơn số lượng cá nhân có khai báo tên cụ thể (Named Guests) trong Nhóm mời. *(Screen: AND-GUE-05)*
*   **GUE-FR-004:** Khi di chuyển một cá nhân ra khỏi Nhóm mời làm nhóm đó trở nên trống (0 named Guests), hệ thống **KHÔNG ĐƯỢC PHÉP** tự động xóa Nhóm mời này nếu nhóm đã được tạo thiệp mời hoặc phát sinh RSVP ở các phân hệ sau. *(Domain Concept: InvitationParty)*

### Validation Rules
*   **GUE-VAL-002:** Tên hiển thị nhóm mời không được để trống và có độ dài tối đa là 100 ký tự. Số lượng người mời (`Invited Count`) bắt buộc phải là số nguyên dương $> 0$.

### Acceptance Criteria
*   **GUE-AC-003 (Empty Party Preservation):**
    *   *Given:* Nhóm mời "Gia đình bác Tư" có `Invited Count = 4` và chứa 1 named Guest duy nhất là "Bác Tư".
    *   *When:* Người dùng gỡ Guest "Bác Tư" ra khỏi nhóm.
    *   *Then:* Guest "Bác Tư" chuyển sang danh sách Khách lẻ. Nhóm "Gia đình bác Tư" chuyển sang trạng thái nhóm trống (0 named Guests) nhưng vẫn tiếp tục tồn tại trong danh sách Nhóm mời với `Invited Count = 4` (không bị tự động xóa).

---

## 5. Flow REQ-04.3 — Duplicate Merge & Impact Review

### Goal
Phát hiện các bản ghi trùng lặp và cung cấp luồng rà soát gộp dữ liệu khách mời an toàn, đảm bảo không phá vỡ ý định gửi thiệp của người dùng.

### Actors
*   Cặp đôi.

### Preconditions
*   Hệ thống phát hiện số điện thoại vừa nhập hoặc tải lên bị trùng với số điện thoại của khách mời đã tồn tại trong đám cưới.

### Trigger
*   Hệ thống mở màn hình Rà soát Gộp trùng lặp (**AND-GUE-06**).

### Main Flow
1.  Hệ thống hiển thị hai bản ghi khách mời bị trùng lặp để so sánh thông tin:
    *   Bản ghi A (Đang có sẵn trong DB).
    *   Bản ghi B (Mới nhập hoặc mới import).
2.  Hệ thống thực hiện so sánh các trường dữ liệu:
    *   *Nếu các trường giống nhau hoàn toàn:* Tự động gộp dữ liệu.
    *   *Nếu chỉ một bên có dữ liệu, bên kia trống:* Tự động chọn trường có dữ liệu làm giá trị chốt.
    *   *Nếu xảy ra xung đột dữ liệu (conflicting fields):* Hệ thống chỉ hiển thị các trường bị xung đột lên giao diện review để người dùng tích chọn giá trị thắng cuộc.
3.  Người dùng chốt phương án gộp thông tin cá nhân.
4.  *Rà soát Nhóm mời:* Nếu hai khách thuộc 2 nhóm mời khác nhau (Nhóm A và Nhóm B), hệ thống hiển thị tùy chọn cho phép người dùng chọn Nhóm mời đích (Giữ nhóm A, Giữ nhóm B, hoặc di chuyển sang nhóm khác). Hệ thống không được tự ý quyết định nhóm đích.
5.  Người dùng xác nhận phương án gộp. Hệ thống thực hiện cập nhật cơ sở dữ liệu và dọn dẹp theo Ma trận D.

### Functional Requirements
*   **GUE-FR-005:** Khi thực hiện gộp hai khách trùng lặp thuộc 2 nhóm mời khác nhau, hệ thống **KHÔNG ĐƯỢC PHÉP** tự động quyết định nhóm mời đích. Hệ thống **PHẢI** yêu cầu người dùng phê duyệt phương án nhóm mời đích trên giao diện review. *(Screen: AND-GUE-06)*
*   **GUE-FR-006:** Khi xảy ra xung đột dữ liệu phi cấu trúc (conflicting fields), hệ thống **PHẢI** hiển thị trường xung đột trên giao diện review để người dùng chủ động chọn giá trị thắng cuộc thay vì tự ý ghi đè ngầm. *(Screen: AND-GUE-06)*

### Acceptance Criteria
*   **GUE-AC-004 (Duplicate Phone No Auto-Merge):**
    *   *Given:* Khách A (SĐT: `0912345678`, nhóm quan hệ: "Đại học") đã có sẵn trong đám cưới. Người dùng thêm mới Khách B (SĐT: `0912345678`, nhóm quan hệ: "Đồng nghiệp").
    *   *When:* Người dùng bấm lưu khách mời B.
    *   *Then:* Hệ thống không tự động gộp đè dữ liệu. Giao diện mở màn hình Review trùng lặp (**AND-GUE-06**), hiển thị trường Nhóm quan hệ bị xung đột ("Đại học" vs "Đồng nghiệp") để người dùng chọn trường thắng cuộc.

---

## 6. Flow REQ-04.4 — Bulk Excel Import & Preview

### Goal
Cho phép người dùng tải lên tệp Excel danh sách khách mời lớn, ánh xạ các giá trị ngoài luồng dữ liệu chuẩn và tự động sinh các nhóm mời theo Khóa nhóm trước khi lưu vào hệ thống.

### Actors
*   Cặp đôi.

### Preconditions
*   Người dùng đã chuẩn bị sẵn tệp danh sách định dạng `.xlsx` theo template mẫu của hệ thống.

### Trigger
*   Người dùng bấm nút "Nhập hàng loạt" trên màn hình Directory (**AND-GUE-01**).

### Main Flow
1.  Hệ thống mở bộ chọn tệp trên thiết bị Android để người dùng tải lên tệp Excel.
2.  Hệ thống thực hiện phân tích cú pháp tệp chạy ngầm và chuyển hướng người dùng sang màn hình Preview Import Excel (**AND-GUE-07**).
3.  Hệ thống phân nhóm dựa trên cột **Mã Khóa Nhóm (Party Key)**. Hai dòng có cùng Party Key sẽ được xếp chung một nhóm mời. Nếu Party Key trống, khách đó là khách lẻ độc lập.
4.  Hệ thống kiểm tra các trường đặc thù:
    *   *Nhóm quan hệ chính (Primary Group) mới:* Hệ thống đề xuất tạo mới nhóm đó (Ví dụ: *"Đồng nghiệp cũ"*).
    *   *Nguồn mời (Guest Source) chưa có:* Hệ thống chặn dòng đó ở trạng thái `MAPPING_REQUIRED` và yêu cầu user ánh xạ.
5.  Giao diện hiển thị bảng ánh xạ hàng loạt (Batch Mapping UX). Người dùng chọn ánh xạ một nhãn không hiểu (Ví dụ: map *"Bố CR"* sang *"Groom's Father"*), hệ thống tự động áp dụng ánh xạ cho toàn bộ 35 dòng cùng chứa nhãn này.
6.  Người dùng bấm nút "Xác nhận nhập danh sách".
7.  Hệ thống nạp dữ liệu vào DB, tự động khởi tạo nhóm quan hệ mới và liên kết nhóm mời theo Party Key. Các dòng bị lỗi (Error) hoặc chưa mapping bị bỏ qua.

### Functional Requirements
*   **GUE-FR-007:** Hệ thống **KHÔNG ĐƯỢC PHÉP** khởi tạo bất kỳ bản ghi khách mời hay nhóm mời nào vào cơ sở dữ liệu trước khi người dùng bấm nút "Xác nhận nhập danh sách" trên giao diện preview. *(Screen: AND-GUE-07)*
*   **GUE-FR-008:** Tệp biểu mẫu Excel nhập liệu **PHẢI** sử dụng định dạng dòng phẳng (Flat Row Model): Mỗi dòng đại diện cho một cá nhân (`Guest`), đi kèm cột `"Mã Khóa Nhóm" (Party Key)` để hệ thống tự động gom nhóm khi phân tích cú pháp. Nếu cột Party Key bỏ trống, hệ thống **PHẢI** ghi nhận khách đó là khách lẻ độc lập (unassigned). *(Domain Concept: Excel Import)*

### Business Rules
*   **GUE-BR-002 (No Silent Data Loss):** Quá trình nhập dữ liệu khách mời bằng Excel tuyệt đối không được phép tự ý bỏ qua hoặc âm thầm thay thế các giá trị mà người dùng cung cấp (như Nguồn mời, Nhóm quan hệ, Số lượng người mời) nếu chưa có sự xác nhận ánh xạ của người dùng.

### Acceptance Criteria
*   **GUE-AC-005 (Import Row Grouping & Validation):**
    *   *Given:* Người dùng upload file Excel chứa 2 dòng có cùng mã khóa nhóm `P001` nhưng có thông tin số lượng người mời khác nhau (Dòng 1 ghi Invited Count = 2, Dòng 2 ghi Invited Count = 3).
    *   *When:* Hệ thống phân tích cú pháp file Excel.
    *   *Then:* Hệ thống phát hiện lỗi xung đột nhóm, đánh dấu dòng này ở trạng thái `Error` (lỗi dữ liệu nhóm) trên màn hình Preview (**AND-GUE-07**) và chặn không cho import dòng này vào DB.
*   **GUE-AC-008 (Auto-create Primary Group):**
    *   *Given:* File Excel chứa dòng khách có Nhóm quan hệ chính là `"Bạn đá bóng"` (chưa có trong DB).
    *   *When:* Người dùng xem màn hình preview (**AND-GUE-07**).
    *   *Then:* Hệ thống hiển thị dòng này ở trạng thái `Warning/Notice` với nhãn cảnh báo: *"Nhóm mới sẽ được tạo: 'Bạn đá bóng'"*. Sau khi Confirm Import, nhóm mới được tạo và gán thành công cho khách.
*   **GUE-AC-009 (Guest Source Mapping - Batch Resolution):**
    *   *Given:* File Excel có 10 dòng chứa Nguồn mời ghi là `"Bố CR"` (chưa có trong mẫu chuẩn).
    *   *When:* Người dùng tải file lên.
    *   *Then:* 10 dòng này bị đánh trạng thái `MAPPING_REQUIRED`. Trên bảng ánh xạ, người dùng chọn map `"Bố CR"` sang `"Groom's Father"` một lần. Hệ thống tự động áp dụng ánh xạ cho cả 10 dòng và chuyển trạng thái của chúng sang `VALID`.
*   **GUE-AC-010 (Unmapped Source Blocked):**
    *   *Given:* Dòng khách có nguồn mời `"Bố CR"` chưa được mapping.
    *   *When:* Người dùng bấm nút "Xác nhận nhập danh sách".
    *   *Then:* Hệ thống từ chối nạp dữ liệu của dòng đó, chỉ nạp các dòng ở trạng thái `VALID` hoặc `WARNING` đã được xác nhận.
*   **GUE-AC-011 (Cancel Import - No Persistence):**
    *   *Given:* Người dùng tải file Excel chứa Nhóm quan hệ mới `"Bạn đá bóng"` và tiến hành ánh xạ nguồn mời mới, sau đó bấm nút "Hủy bỏ/Quay lại".
    *   *When:* Người dùng vào cài đặt quan hệ hoặc danh sách khách.
    *   *Then:* Không có nhóm quan hệ mới `"Bạn đá bóng"` nào được tạo lập trong DB và các ánh xạ cũ bị hủy bỏ hoàn toàn.

---

## 7. Flow REQ-04.5 — Parent Review Export & Privacy Control

### Goal
Cho phép xuất danh sách khách mời tối giản theo từng Nguồn mời để bố mẹ rà soát mà không vi phạm quyền riêng tư dữ liệu cá nhân của khách.

### Actors
*   Cặp đôi.

### Preconditions
*   Đám cưới đã có dữ liệu khách mời được nhập.

### Trigger
*   Người dùng bấm nút "Xuất danh sách" tại màn hình Directory (**AND-GUE-01**).

### Main Flow
1.  Hệ thống hiển thị màn hình Cài đặt xuất danh sách (**AND-GUE-08**).
2.  Người dùng chọn bộ lọc Nguồn mời (Ví dụ: chỉ tích chọn `Groom's Father` - Khách của Bố chú rể).
3.  Người dùng lựa chọn định dạng xuất tệp (Excel hoặc PDF).
4.  Người dùng bấm nút "Xuất bản kiểm tra".
5.  Hệ thống tự động sinh tệp báo cáo tương ứng:
    *   *Chính sách riêng tư (Privacy):* Tệp xuất bản kiểm tra mặc định ẩn các cột thông tin Số điện thoại, Email và Ghi chú nội bộ. Hệ thống chỉ xuất các cột này khi người dùng chủ động tích chọn bổ sung trên form.
6.  Hệ thống kích hoạt chia sẻ tệp mặc định để gửi tệp.

### Alternate Flows (Xóa Nhóm quan hệ chính - Primary Group)
1.  Khi người dùng thực hiện xóa một Nhóm quan hệ chính (Ví dụ: Xóa nhóm "Bạn cấp 3") trong cài đặt.
2.  Hệ thống tính toán số lượng khách mời đang thuộc nhóm này.
3.  Hệ thống hiển thị thông báo xác nhận: *"Xóa nhóm quan hệ này sẽ chuyển [X] khách mời về trạng thái 'Không có nhóm'. Bạn có chắc chắn muốn xóa?"*.
4.  Người dùng bấm xác nhận $\rightarrow$ Hệ thống cập nhật tất cả các khách mời thuộc nhóm đó thành `Primary Group = NONE` ("Không có nhóm"), không xóa các bản ghi khách mời.

### Functional Requirements
*   **GUE-FR-009:** Tệp xuất bản kiểm tra cho bố mẹ **BẮT BUỘC** phải ẩn các cột thông tin Số điện thoại, Email và Ghi chú nội bộ theo mặc định để bảo vệ quyền riêng tư cá nhân (PII), trừ khi người dùng chủ động tích chọn bổ sung trên giao diện cài đặt xuất. *(Screen: AND-GUE-08)*
*   **GUE-FR-010:** Khi người dùng xóa một Nhóm quan hệ chính (`Primary Group`), hệ thống **KHÔNG ĐƯỢC PHÉP** xóa các bản ghi khách mời thuộc nhóm đó. Hệ thống **PHẢI** chuyển chúng về trạng thái không có nhóm (`Primary Group = NONE`) và hiển thị thông báo tổng số khách bị ảnh hưởng trước khi xác nhận. *(Domain Concept: Primary Group)*

### Acceptance Criteria
*   **GUE-AC-006 (Delete Primary Group):**
    *   *Given:* Đám cưới đang có 15 khách mời thuộc nhóm quan hệ "Đồng nghiệp". Người dùng thực hiện thao tác xóa nhóm "Đồng nghiệp".
    *   *When:* Người dùng bấm xác nhận xóa nhóm quan hệ.
    *   *Then:* Nhóm quan hệ bị xóa. 15 khách mời được bảo toàn dữ liệu hoàn toàn và trường Nhóm quan hệ của họ chuyển sang `"Không có nhóm"` (`Primary Group = NONE`).
*   **GUE-AC-007 (Parent Export Privacy):**
    *   *Given:* Danh sách khách có đầy đủ số điện thoại và ghi chú nội bộ. Người dùng chọn xuất tệp bản kiểm tra cho bố mẹ mà không tích chọn mục bổ sung thông tin nhạy cảm.
    *   *When:* Người dùng mở tệp Excel/PDF xuất ra.
    *   *Then:* Tệp xuất ra chỉ chứa các cột: Số thứ tự, Tên hiển thị nhóm mời, Nhóm quan hệ, Số lượng người mời. Cột số điện thoại và ghi chú hoàn toàn bị ẩn mặc định.

---

## 8. Bảng Truy Xuất Nguồn Gốc (Traceability Matrix)

| Mã Yêu Cầu (Requirement ID) | Phân hệ / Luồng (Flow) | Mã Màn Hình (Screen ID) | Khái Niệm Miền (Domain Concept) | Quyết Định Thiết Kế (Discovery Decision) | Mã Tiêu Chí Nghiệm Thu (Acceptance Criteria) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **GUE-FR-001** | REQ-04.1 | AND-GUE-03 | `Guest` | Hỗ trợ nguồn mời phân loại theo bố mẹ | GUE-AC-001 |
| **GUE-FR-002** | REQ-04.1 | AND-GUE-03 | - | Khôi phục bản nháp đang nhập dở trên app | - |
| **GUE-FR-003** | REQ-04.2 | AND-GUE-05 | `InvitationParty` | Số lượng mời lớn hơn số cá nhân named | GUE-AC-002 |
| **GUE-FR-004** | REQ-04.2 | AND-GUE-05 | `InvitationParty` | Chặn tự động xóa nhóm mời trống đã gửi thiệp | GUE-AC-003 |
| **GUE-FR-005** | REQ-04.3 | AND-GUE-06 | `InvitationParty` | Không tự ý quyết định nhóm mời đích khi gộp | GUE-AC-004 |
| **GUE-FR-006** | REQ-04.3 | AND-GUE-06 | `Guest` | Hiển thị review xung đột dữ liệu | GUE-AC-004 |
| **GUE-FR-007** | REQ-04.4 | AND-GUE-07 | `Guest` | Không tự tạo record trước khi bấm confirm import | GUE-AC-005, GUE-AC-010 |
| **GUE-FR-008** | REQ-04.4 | - | `Excel Import` | Định dạng dòng phẳng flat row dễ phân tích | GUE-AC-005 |
| **GUE-FR-009** | REQ-04.5 | AND-GUE-08 | `Parent Review` | Ẩn số điện thoại, ghi chú để bảo vệ privacy | GUE-AC-007 |
| **GUE-FR-010** | REQ-04.5 | - | `Primary Group` | Xóa nhóm quan hệ chuyển khách về không có nhóm | GUE-AC-006 |
