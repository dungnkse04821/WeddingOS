# Đặc Tả Yêu Cầu Chi Tiết: REQ-05 — Invitation & RSVP

Tài liệu này đặc tả chi tiết các yêu cầu nghiệp vụ phần mềm cho Phân hệ **REQ-05 — Invitation & RSVP (Thiệp mời & RSVP)** của hệ thống WeddingOS.

---

## 1. Mô Hình Tư Duy Cốt Lõi (Core Mental Model)

*   **Tách biệt các khái niệm miền:**
    *   `InvitationParty` (Nhóm mời): Đại diện cho nhóm nhận chung một lời mời. REQ-04 đã chốt nhóm mời có thể chứa 0 named guests (nhóm trống).
    *   `Invitation` (Thiệp mời): Đối tượng quản lý trạng thái thiệp, mã truy cập (token) và liên kết sự kiện. Một nhóm mời có tối đa một active Invitation trong MVP.
    *   `RSVP` (Phản hồi): Tập hợp các phản hồi tham dự của nhóm mời.
    *   `EventResponse` (Phản hồi sự kiện): Phản hồi chi tiết cho từng Sự kiện con (`WeddingEvent`) được gán mời.
*   **Phản hồi RSVP riêng biệt theo sự kiện (Event-specific RSVP):** Không sử dụng một trạng thái tham dự chung cho toàn bộ đám cưới nếu thiệp mời nhắm mục tiêu nhiều sự kiện con. Khách mời phản hồi độc lập cho từng sự kiện được mời (ví dụ: tham dự Ăn hỏi nhưng không tham dự Tiệc cưới).
*   **Thống nhất chỉ số:**
    *   `Invited Count` (Số người mời): Cấu hình cố định thuộc Nhóm mời.
    *   `Attending Count` (Số người tham dự thực tế): Khai báo động thuộc về từng phản hồi sự kiện (`EventResponse`).

---

## 2. Các Ma Trận Nghiệp Vụ Quyết Định (Decision Matrices)

### A. Ma Trận Vòng Đời Thiệp Mời (Invitation Lifecycle Matrix)

Vòng đời nghiệp vụ của Thiệp mời (`Invitation`) được quản lý độc lập với các tín hiệu theo dõi (tracking signals) và tổng hợp phản hồi:

| Trạng thái Thiệp (Lifecycle State) | Tác vụ cho phép (Allowed Actions) | Tín hiệu theo dõi (Tracking Signals) | Trạng thái phản hồi (RSVP Summary) |
| :--- | :--- | :--- | :--- |
| **`DRAFT`** (Bản nháp / Chuẩn bị) | Chỉnh sửa sự kiện mời, tạo/sửa thông tin nhóm. Chưa thể chia sẻ chính thức. | Không | `PENDING` (Chờ phản hồi). |
| **`READY`** (Sẵn sàng) | Cho phép copy link, chia sẻ link. Chưa đánh dấu đã gửi. | Không | `PENDING`. |
| **`MARKED_AS_SENT`** (Đã đánh dấu gửi) | Copy link, chia sẻ link, thu hồi/tái tạo link (Regenerate). | `MarkedSentAt` (Lưu mốc thời gian đánh dấu gửi thiệp). | `PENDING`, `PARTIAL` (Đã phản hồi một phần), hoặc `RESPONDED` (Đã phản hồi xong). |

*Lưu ý:*
*   Trạng thái `MARKED_AS_SENT` thể hiện hành động chủ động của người dùng (cặp đôi) xác nhận đã gửi thiệp đi, hệ thống không tự động xác thực việc thiệp đã được giao thành công tới thiết bị của khách (No verified delivery confirmation).
*   Các trường `FirstViewedAt` và `LastViewedAt` là các tín hiệu theo dõi (tracking signals) được cập nhật động khi khách mở link, không làm thay đổi trạng thái vòng đời chính của Thiệp mời.

---

### B. Ma Trận Độ Sẵn Sàng Của Thiệp Mời (Invitation Readiness Matrix)

Điều kiện để chuyển trạng thái Thiệp mời từ `DRAFT` sang `READY`:

| Điều kiện xác thực (Readiness Rule) | Yêu cầu nghiệp vụ chi tiết | Kết quả nếu thiếu |
| :--- | :--- | :--- |
| **Nhóm mời tồn tại** | `InvitationParty` được khởi tạo hợp lệ. | Báo lỗi cấu trúc. |
| **Tên hiển thị nhóm mời** | `Party Display Name` không được để trống (Cho phép gán nhóm trống có 0 named guests). | Báo lỗi, chặn chuyển READY. |
| **Số người được mời** | `Invited Count` phải $> 0$. | Báo lỗi, chặn chuyển READY. |
| **Ít nhất một Sự kiện được chọn** | Thiệp mời phải nhắm mục tiêu (`target`) ít nhất một sự kiện con (`WeddingEvent`) đang hoạt động. | Báo lỗi: *"Cần chọn ít nhất một sự kiện mời để sẵn sàng phát thiệp."* |

---

### C. Ma Trận Khả Năng RSVP Của Sự Kiện (RSVP Readiness Matrix)

Phân biệt giữa sự kiện hiển thị trên thiệp (`Invitation-visible`) và sự kiện đã sẵn sàng để phản hồi RSVP (`RSVP-ready`):

*   **Điều kiện Invitation-visible:** Sự kiện cưới xuất hiện trên thiệp khi có thông tin cơ bản đủ để cặp đôi muốn công bố. Chỉ cần thông tin Tháng dự kiến (`Expected Month`) là đủ điều kiện hiển thị dưới dạng Save the Date.
*   **Điều kiện RSVP-ready:** Một sự kiện con (`WeddingEvent`) chỉ mở tính năng tích chọn tham dự RSVP cho khách khi có ngày cưới chính xác (`Exact Date`). Các trường Giờ tổ chức (`Time`) và Địa điểm (`Venue`) **không bắt buộc** để mở RSVP trong MVP:
    *   Nếu thiếu `Time`: Guest Web hiển thị: *"Thời gian cụ thể sẽ được cập nhật."*
    *   Nếu thiếu `Venue`: Guest Web hiển thị: *"Địa điểm sẽ được cập nhật."* và không hiển thị bản đồ dẫn đường (không tạo dữ liệu hay bản đồ giả).
*   **Save the Date:** Nếu sự kiện mới chỉ có Tháng dự kiến (`Expected Month`) và chưa chốt ngày chính xác, sự kiện đó hiển thị dưới dạng thông tin tham khảo (Save the Date), không hiển thị form câu hỏi phản hồi tham dự và không tạo bản ghi phản hồi chờ giả cho sự kiện này.

| Phân loại Sự kiện trên Thiệp | Điều kiện Dữ liệu (Prerequisites) | Khả năng phản hồi RSVP (RSVP Action) | Trải nghiệm Guest Web |
| :--- | :--- | :--- | :--- |
| **Được mời + RSVP-ready** | Có ngày chính xác (`Exact Date`). | Được điền/chỉnh sửa RSVP trước hạn chót. | Hiển thị thông tin + Form chọn tham dự và nhập số lượng. |
| **Được mời + Chưa RSVP-ready** | Chỉ có Tháng dự kiến (`Expected Month`). | **Chỉ xem thông tin (Save the Date)**. Không yêu cầu phản hồi tham dự. | Hiển thị thông tin dạng: *"Dự kiến Tháng X/YYYY"*. Không hiện form câu hỏi RSVP cho sự kiện này. |
| **Sự kiện đã bị xóa** | Bị xóa khỏi hệ thống bởi cặp đôi. | Bị khóa. | Ẩn hoàn toàn khỏi thiệp cưới đang hoạt động. **Bản ghi phản hồi lịch sử (Historical EventResponse) phải được bảo toàn thành dữ liệu lịch sử và tiếp tục được hiển thị cho các thành viên ban tổ chức được ủy quyền (`authorized WeddingMembers`) đối chiếu khi phù hợp**. |
| **Không được gán mời** | Bất kỳ. | Bị khóa. | Ẩn hoàn toàn. |

---

### D. Ma Trận Đánh Giá Hoàn Tất Phản Hồi (RSVP Completion Matrix)

Quy tắc tính toán trạng thái phản hồi RSVP tổng thể (`RSVP summary`) của thiệp mời:

*   **Định nghĩa:** RSVP completion chỉ được đánh giá dựa trên tập hợp các sự kiện được gán mời hiện đang ở trạng thái **RSVP-ready** (có ngày cưới chính xác). Các sự kiện chỉ hiển thị dạng Save the Date (chưa RSVP-ready) không làm thay đổi trạng thái hoàn tất của phản hồi.
*   **Mở lại phản hồi:** Khi một sự kiện từ Save the Date được cập nhật thông tin ngày cưới chính xác (`Exact Date`) $\rightarrow$ sự kiện đó chuyển thành `RSVP-ready`. Trạng thái phản hồi RSVP tổng hợp của nhóm mời lúc này sẽ chuyển về trạng thái Chưa hoàn tất / Phản hồi một phần (`Partial`) cho tới khi khách thực hiện phản hồi cho sự kiện mới mở này.

| Trạng thái của các Sự kiện RSVP-ready được mời | Phản hồi của Khách mời | Trạng thái RSVP tổng hợp (RSVP Summary) | Hiển thị VietQR (nếu được bật) |
| :--- | :--- | :--- | :--- |
| **Chỉ có sự kiện Save the Date** (Không có sự kiện RSVP-ready nào) | Bất kỳ. | `PENDING` (Chưa mở form RSVP). | **KHÔNG HIỂN THỊ** (Không cho phép dùng Save the Date để hiện VietQR mừng cưới trước khi RSVP). |
| **Có $\ge 1$ sự kiện RSVP-ready** | Chưa phản hồi sự kiện nào. | `PENDING`. | Không hiển thị. |
| **Có nhiều sự kiện RSVP-ready** | Mới phản hồi một phần số sự kiện. | `PARTIAL`. | Không hiển thị. |
| **Có $\ge 1$ sự kiện RSVP-ready** | Đã phản hồi đầy đủ toàn bộ các sự kiện RSVP-ready. | `RESPONDED` (Đã hoàn tất). | **HIỂN THỊ** (Sẵn sàng nhận mừng cưới). |

---

### E. Ma Trận Phản Hồi Sự Kiện RSVP (RSVP EventResponse Matrix)

Cơ chế phản hồi chi tiết cho từng sự kiện được mở RSVP trong thiệp:

| Phản hồi tham dự (Attendance) | Số lượng tham gia (Attending Count) | Tên người đi kèm (Companion Names) | Yêu cầu ăn kiêng / Ghi chú (Dietary / Note) | Ý nghĩa hiển thị trên Guest Web |
| :--- | :--- | :--- | :--- | :--- |
| **`ATTENDING`** (Tham dự) | Bắt buộc nhập (số nguyên dương $\ge 1$). | Tùy chọn (nhập tự do ngăn cách). | Tùy chọn. | Ghi nhận tham dự đợt này. |
| **`NOT_ATTENDING`** (Không tham dự) | Mặc định bằng 0. Khóa ô nhập liệu. | Ẩn/Khóa. | Tùy chọn (người dùng vẫn có thể gửi lời chúc). | Ghi nhận không tham dự đợt này. |

---

### F. Ma Trận Hạn Chót RSVP (RSVP Cutoff Matrix)

Hành vi của hệ thống trước và sau mốc hạn chót khóa phản hồi RSVP tổng thể (`Wedding-level RSVP Cutoff`):

*   **Định nghĩa hạn chót:** Khách mời được phép tự chỉnh sửa phản hồi (self-edit) đến hết ngày RSVP Cutoff theo múi giờ đám cưới (`Wedding timezone`) được cấu hình. Nếu cặp đôi không cấu hình, khách mời được phép chỉnh sửa tự do.

| Thời điểm so với Cutoff | Giao diện Khách mời (Guest Web) | Giao diện Cặp đôi (Android App) | Ghi chú nghiệp vụ |
| :--- | :--- | :--- | :--- |
| **Trước hạn chót** (`Before Cutoff`) | Cho phép mở link, điền RSVP, sửa đổi phản hồi và gửi lại bình thường. | Cho phép cập nhật thủ công RSVP của khách nếu cần. | Cho phép cập nhật không giới hạn. |
| **Sau hạn chót** (`After Cutoff`) | **Khóa chế độ chỉnh sửa (View-only)**. Hiển thị thông tin đã phản hồi trước đó. | **Vẫn cho phép cập nhật thủ công** RSVP của khách (để xử lý trường hợp gọi điện báo trễ). | Khách không thể tự sửa trên Web. |

---

### G. Ma Trận Vượt Số Lượng Mời (Invited Count / Over-capacity Matrix)

Hành vi khi khách mời khai báo số người tham dự thực tế vượt quá hạn mức thiệp mời (`Attending Count > Invited Count`):

| Giá trị Attending Count | Trải nghiệm phía Khách (Guest UI) | Trải nghiệm phía Cặp đôi (Android UI) | Ý nghĩa nghiệp vụ |
| :--- | :--- | :--- | :--- |
| $AC \le IC$ | Cho phép gửi bình thường, chuyển sang trang xác nhận thành công. | Ghi nhận phản hồi hợp lệ. | Đóng gói phản hồi. |
| $AC > IC$ | **Không chặn gửi (Soft Warning)**. Hiển thị thông báo lịch sự: *"Thiệp hiện được chuẩn bị cho [IC] khách. Nếu bạn cần đăng ký thêm người, vui lòng để lại ghi chú để cô dâu/chú rể xác nhận."* | **Đánh dấu Cảnh báo Vượt hạn mức** (Over-capacity Warning Flag) trên danh sách review của cặp đôi kèm số lượng vượt. | Cặp đôi tự quyết định giữ nguyên hay điều chỉnh lại số lượng mà không tự động tăng Invited Count của nhóm. |

---

### H. Ma Trận Trạng Thái Khóa Truy Cập Link (Link Token State Matrix)

Quy tắc hiển thị thông tin nhằm giảm thiểu rủi ro chia sẻ link ngoài luồng (`Forwarding Risk Mitigation`) và bảo vệ quyền riêng tư cá nhân (`Privacy Protection`):

| Trạng thái Token (Token State) | Quyền hiển thị thông tin đám cưới (Wedding Details) | Quyền phản hồi RSVP | Giao diện hiển thị |
| :--- | :--- | :--- | :--- |
| **`VALID`** (Hợp lệ) | Hiển thị đầy đủ thông tin sự kiện được mời, tên cặp đôi, lời chào cá nhân. | Có quyền điền và gửi RSVP. | Mở màn hình thiệp cưới **WEB-INV-01**. |
| **`REVOKED`** (Bị thu hồi do tái tạo link mới) | **Ẩn toàn bộ thông tin**. Không hiển thị lời chào, tên cặp đôi, venue, ngày cưới, bản đồ hay VietQR. | Bị khóa. | Chuyển hướng sang màn hình lỗi an toàn chung **WEB-ERR-01**. Không hiển thị hotline của đám cưới để bảo mật. |
| **`INVALID`** (Không tồn tại / sai token) | **Ẩn toàn bộ thông tin**. | Bị khóa. | Chuyển hướng sang màn hình lỗi an toàn chung **WEB-ERR-01**. Không hiển thị hotline của đám cưới. |

---

## 3. Surface A — Các Yêu Cầu Trên Ứng Dụng Android Của Cặp Đôi (Android App)

### Goal
Cho phép cặp đôi chuẩn bị thiệp mời, phân phối liên kết cá nhân hóa, theo dõi trạng thái phản hồi RSVP và cập nhật thủ công khi cần thiết.

### Core User Flows
1.  **Chuẩn bị Thiệp & Sự kiện mời:** Tại màn hình Chi tiết Nhóm mời (**AND-GUE-04**), cặp đôi chọn cấu hình các Sự kiện cưới con sẽ mời nhóm này. Hệ thống kiểm tra điều kiện READY (Mục 2.B).
2.  **Chia sẻ thiệp & Đánh dấu đã gửi:** Cặp đôi bấm nút `"Sao chép liên kết"` hoặc `"Chia sẻ thiệp"`. Hệ thống sinh link cá nhân hóa chứa token bảo mật. Cặp đôi bấm nút `"Đánh dấu đã gửi"`, hệ thống chuyển trạng thái Thiệp sang `MARKED_AS_SENT` và ghi nhận thời gian `MarkedSentAt`.
3.  **Cập nhật RSVP thủ công:** Cặp đôi mở chi tiết nhóm mời (**AND-GUE-04**), bấm nút chỉnh sửa RSVP thủ công để điền thông tin tham dự thay cho khách.
4.  **Tái tạo liên kết (Regenerate Link):** Cặp đôi bấm `"Tái tạo liên kết"`. Hệ thống thu hồi token cũ (chuyển sang trạng thái `REVOKED`) và sinh token mới, bảo toàn nguyên vẹn mọi dữ liệu RSVP đã gửi trước đó.

### Functional Requirements
*   **INV-FR-001:** Hệ thống **PHẢI** hỗ trợ cơ chế nhắm mục tiêu sự kiện riêng biệt cho từng Nhóm mời. Chỉ hiển thị các sự kiện được mời lên giao diện Guest Web của nhóm đó. *(Screen: AND-GUE-04)*
*   **INV-FR-002:** Hành động Sao chép liên kết hoặc Chia sẻ liên kết **KHÔNG ĐƯỢC TỰ ĐỘNG** chuyển trạng thái thiệp sang `MARKED_AS_SENT`. Trạng thái `MARKED_AS_SENT` chỉ được ghi nhận khi người dùng chủ động chọn hành động `"Đánh dấu đã gửi"` (Mark as Sent) để tránh ghi nhận sai lệch tín hiệu gửi thiệp thực tế. *(Screen: AND-GUE-04)*
*   **INV-FR-003:** Khi người dùng thực hiện hành động Tái tạo liên kết (Regenerate Link), hệ thống **PHẢI** vô hiệu hóa token cũ ngay lập tức nhưng **BẮT BUỘC** phải bảo toàn thực thể thiệp mời (`Invitation`) và mọi dữ liệu lịch sử RSVP cũ liên quan đến nhóm đó. *(Domain Concept: Invitation)*
*   **INV-FR-004:** Cặp đôi **PHẢI** có quyền cập nhật thủ công phản hồi RSVP của khách mời bất kể thời điểm (kể cả sau khi đã quá hạn chót RSVP Cutoff). *(Screen: AND-GUE-04)*

---

## 4. Surface B — Các Yêu Cầu Trên Giao Diện Web Dành Cho Khách Mời (Guest Web)

### Goal
Cung cấp trang Web di động gọn nhẹ giúp khách mời xem thông tin thiệp cưới cá nhân hóa, thực hiện phản hồi RSVP dễ dàng và xem thông tin VietQR mừng cưới sau khi hoàn tất.

### Core User Flows
1.  **Truy cập thiệp:** Khách mời bấm vào link cá nhân hóa. Hệ thống xác thực token. Nếu hợp lệ, hiển thị màn hình **WEB-INV-01** chứa lời chào cá nhân hóa (sử dụng `Party Display Name` làm từ chào, ví dụ: *"Trân trọng kính mời Gia đình bác Tư"*), tên cặp đôi, thời gian và địa điểm các sự kiện được mời.
2.  **Xem chỉ đường:** Khách mời bấm nút xem chỉ đường tại từng sự kiện, hệ thống mở link bản đồ dẫn đường tương ứng (nếu có địa điểm).
3.  **Phản hồi RSVP:** Khách mời bấm `"Xác nhận tham dự"` $\rightarrow$ Chuyển sang màn hình **WEB-RSV-01**. Khách chọn trạng thái tham dự riêng cho từng sự kiện RSVP-ready, nhập số lượng đi kèm, ghi chú ăn kiêng/lời chúc và bấm "Gửi phản hồi".
4.  **Xác nhận thành công & Mừng cưới:** Hệ thống lưu phản hồi, chuyển sang màn hình **WEB-RSV-02** báo thành công. Nếu cặp đôi có bật tính năng mừng cưới, hiển thị phân đoạn thông tin chuyển khoản VietQR tĩnh để khách tiện mừng cưới.

### Functional Requirements
*   **INV-FR-005:** Trang Web dành cho khách mời **PHẢI** tương thích hoàn toàn với trình duyệt di động (Responsive mobile web) và **KHÔNG ĐƯỢC YÊU CẦU** khách mời phải cài đặt ứng dụng WeddingOS hoặc đăng ký tài khoản để phản hồi. *(Screen: WEB-INV-01)*
*   **INV-FR-006:** Hệ thống **BẮT BUỘC** phải ẩn hoàn toàn các thông tin nhạy cảm (như danh sách khách mời khác, số điện thoại của khách khác, ghi chú nội bộ của cặp đôi) trên giao diện Web của khách mời để bảo vệ quyền riêng tư. *(Screen: WEB-INV-01)*
*   **INV-FR-007:** Khi mở một liên kết bị thu hồi (`REVOKED`) hoặc không hợp lệ (`INVALID`), trang Web **KHÔNG ĐƯỢC PHÉP** rò rỉ bất kỳ thông tin riêng tư nào của cô dâu/chú rể hay sự kiện cưới. Hệ thống **PHẢI** hiển thị trang thông báo lỗi an toàn chung **WEB-ERR-01**. *(Screen: WEB-ERR-01)*
*   **INV-FR-008:** Phân đoạn thông tin mừng cưới VietQR **CHỈ ĐƯỢC HIỂN THỊ** sau khi khách mời đã bấm hoàn tất gửi phản hồi RSVP thành công trên màn hình **WEB-RSV-02** (Và thiệp mời phải có ít nhất một sự kiện RSVP-ready được phản hồi). Hệ thống **KHÔNG ĐƯỢC PHÉP** hiển thị VietQR trước khi khách phản hồi hoặc làm nút bấm mừng cưới nổi bật hơn nút RSVP chính. *(Screen: WEB-RSV-02)*
*   **INV-FR-009:** MVP chỉ hỗ trợ hiển thị ảnh QR chuyển khoản tĩnh hoặc thông tin tài khoản ngân hàng tĩnh do cặp đôi tải lên sẵn. Hệ thống **KHÔNG THỰC HIỆN** các tác vụ đối soát giao dịch tự động, tự quét tài khoản hay cập nhật trạng thái đã nhận tiền trên app. *(Screen: WEB-RSV-02)*
*   **INV-FR-010:** Giao diện điền RSVP (**WEB-RSV-01**) **PHẢI** lưu trữ tạm thời nội dung đang điền của khách mời. Nếu giao dịch gửi gặp sự cố mạng hoặc lỗi hệ thống, hệ thống hiển thị thông báo lỗi và nút thử lại mà không được xóa sạch các câu trả lời khách vừa nhập. *(Screen: WEB-RSV-01)*

### Business Rules
*   **INV-BR-002 (RSVP Concurrency - Latest Update Wins):** Hệ thống chỉ duy trì duy nhất một trạng thái phản hồi RSVP hiện tại trong cơ sở dữ liệu. Bất kỳ cập nhật hợp lệ nào đến sau (từ thiết bị Guest Web của khách trước hạn cutoff, hoặc từ thao tác cập nhật thủ công của WeddingMember trên app Android) đều ghi đè lên giá trị cũ để đảm bảo tính nhất quán của dữ liệu tham dự. Nếu xảy ra cập nhật đồng thời, hệ thống phải kết thúc với một trạng thái hợp lệ và không tạo các bản ghi phản hồi bị trùng lặp.
*   **INV-BR-003 (Event Removal Impact):** Khi một sự kiện con (`WeddingEvent`) bị xóa khỏi hệ thống, sự kiện đó phải bị ẩn khỏi thiệp mời cưới đang hoạt động của khách mời và không nhận RSVP mới. Bản ghi phản hồi lịch sử (`Historical EventResponse`) đối với sự kiện đã xóa phải được bảo toàn thành dữ liệu lịch sử và tiếp tục hiển thị cho các thành viên ban tổ chức được ủy quyền (`authorized WeddingMembers`) đối chiếu khi phù hợp. Sự kiện bị xóa không làm ảnh hưởng đến tính toán trạng thái RSVP tổng hợp (`RSVP Summary`) của các sự kiện đang hoạt động.

---

## 5. Bảng Tiêu Chí Nghiệm Thu Điển Hình (Acceptance Criteria)

*   **INV-AC-001 (Expected Month Event as Save the Date):**
    *   *Given:* Sự kiện "Lễ cưới" chỉ mới cấu hình Tháng dự kiến là `12/2026` (Chưa chốt ngày chính xác).
    *   *When:* Khách mở link thiệp cưới (**WEB-INV-01**).
    *   *Then:* Sự kiện "Lễ cưới" hiển thị dưới dạng Save the Date với dòng chữ *"Dự kiến: Tháng 12/2026"*. Giao diện không hiện ô tích chọn tham dự RSVP cho sự kiện này và không xuất hiện trong form RSVP (**WEB-RSV-01**).
*   **INV-AC-002 (No Fake Exact Date):**
    *   *Given:* Sự kiện cưới chỉ cấu hình Expected Month.
    *   *When:* Khách mở thiệp xem thông tin.
    *   *Then:* Hệ thống hiển thị đúng dòng chữ tháng dự kiến cưới, tuyệt đối không tự sinh ngày cưới giả (như ngày 01) hoặc neo ngầm ngày để hiển thị lên UI của khách.
*   **INV-AC-003 (Event with Exact Date but no Time):**
    *   *Given:* Sự kiện cưới có Exact Date là `18/12/2026` nhưng chưa nhập Giờ tổ chức (`Time`).
    *   *When:* Khách mở thiệp cưới.
    *   *Then:* RSVP cho sự kiện này vẫn được mở bình thường. Giao diện Guest Web hiển thị thông tin thời gian là: *"Thời gian cụ thể sẽ được cập nhật."*.
*   **INV-AC-004 (Event with Exact Date but no Venue):**
    *   *Given:* Sự kiện cưới có Exact Date là `18/12/2026` nhưng chưa nhập Địa điểm (`Venue`).
    *   *When:* Khách mở thiệp cưới.
    *   *Then:* RSVP cho sự kiện này vẫn được mở bình thường. Giao diện Guest Web hiển thị thông tin địa điểm là: *"Địa điểm sẽ được cập nhật."* và không hiển thị bản đồ dẫn đường (không tạo link/bản đồ giả).
*   **INV-AC-005 (Empty Party Invitation Eligibility):**
    *   *Given:* Nhóm mời "Gia đình bác Tư" có `Invited Count = 4` nhưng không khai báo bất kỳ named Guest nào (0 named Guests). Thiệp đã cấu hình mời sự kiện "Tiệc cưới chính" và đáp ứng đủ các readiness rule.
    *   *When:* Cặp đôi mở chi tiết nhóm trên app Android.
    *   *Then:* Hệ thống cho phép thiệp chuyển sang trạng thái `READY` và cho phép copy link bình thường. Trình chào trên Web hiển thị đúng: *"Trân trọng kính mời Gia đình bác Tư"*.
*   **INV-AC-006 (Guest Update Overwrites Previous Response):**
    *   *Given:* Đám cưới đang ở thời điểm trước hạn chót RSVP Cutoff. Khách mời A đã gửi phản hồi tham dự là 2 người.
    *   *When:* Khách mời A mở lại link và chỉnh sửa số người tham dự thành 3 người rồi bấm gửi lại.
    *   *Then:* Hệ thống cập nhật đè số lượng tham dự hiện tại thành 3 người.
*   **INV-AC-007 (WeddingMember Update Overwrites Current Response):**
    *   *Given:* Khách mời A đã tự RSVP tham dự 2 người trên Web.
    *   *When:* Cô dâu nhận điện thoại báo thay đổi và chỉnh sửa thủ công số người đi của nhóm A trên app Android thành 4 người.
    *   *Then:* Hệ thống lưu thành công. Khách mở lại link web sau đó sẽ thấy thông tin hiển thị là đã đăng ký 4 người tham dự.
*   **INV-AC-008 (Guest Can Update Again Before Cutoff after WeddingMember Update):**
    *   *Given:* Cô dâu đã chỉnh sửa thủ công số người tham dự của nhóm A thành 4 người. Hiện tại vẫn đang trước hạn chót RSVP Cutoff.
    *   *When:* Khách mời A tự mở lại link web và chọn sửa phản hồi thành 3 người rồi bấm gửi.
    *   *Then:* Hệ thống ghi nhận giá trị gửi sau cùng của khách, cập nhật đè phản hồi hiện tại thành 3 người tham dự.
*   **INV-AC-009 (Guest Blocked After Cutoff):**
    *   *Given:* Đám cưới cấu hình hạn chót RSVP Cutoff là ngày `15/10/2026`. Hôm nay là ngày `16/10/2026` (sau hạn chót).
    *   *When:* Khách mời mở link thiệp cưới.
    *   *Then:* Giao diện hiển thị thông tin phản hồi ở chế độ chỉ xem (View-only). Nút chỉnh sửa phản hồi bị ẩn hoặc vô hiệu hóa, khách không thể tự sửa đổi dữ liệu.
*   **INV-AC-010 (WeddingMember Can Update After Cutoff):**
    *   *Given:* Hôm nay là ngày `16/10/2026` (sau hạn chót).
    *   *When:* Chú rể mở chi tiết nhóm mời trên app Android và thực hiện chỉnh sửa thủ công số người tham dự của nhóm.
    *   *Then:* Hệ thống cho phép lưu thành công phản hồi mới.
*   **INV-AC-011 (Removed Event Disappears from Active Invitation):**
    *   *Given:* Sự kiện "Lễ Ăn Hỏi" bị xóa khỏi danh sách sự kiện trên app Android của cặp đôi.
    *   *When:* Khách mời mở link thiệp cưới.
    *   *Then:* Sự kiện "Lễ Ăn Hỏi" hoàn toàn biến mất khỏi thiệp cưới đang hoạt động của khách mời.
*   **INV-AC-012 (Historical EventResponse Survives Event Removal):**
    *   *Given:* Nhóm mời A đã phản hồi RSVP tham dự sự kiện "Lễ Ăn Hỏi" trước đó. Sau đó, cặp đôi thực hiện xóa sự kiện "Lễ Ăn Hỏi" khỏi hệ thống.
    *   *When:* Người dùng kiểm tra báo cáo lịch sử phản hồi trên app Android.
    *   *Then:* Thực thể phản hồi sự kiện `EventResponse` cũ của nhóm A đối với Lễ Ăn Hỏi được bảo toàn thành dữ liệu lịch sử và tiếp tục được hiển thị cho các thành viên ban tổ chức được ủy quyền (`authorized WeddingMembers`) đối chiếu khi phù hợp.
*   **INV-AC-013 (Copy Link Does Not Mark Sent):**
    *   *Given:* Thiệp mời đang ở trạng thái `READY`.
    *   *When:* Người dùng bấm nút Sao chép liên kết thiệp.
    *   *Then:* Liên kết được sao chép vào bộ nhớ đệm thiết bị. Trạng thái thiệp mời vẫn giữ nguyên là `READY` (chỉ chuyển sang `MARKED_AS_SENT` khi người dùng bấm nút xác nhận "Đánh dấu đã gửi").
*   **INV-AC-014 (Viewed Tracking Does Not Mean Delivered):**
    *   *Given:* Thiệp mời ở trạng thái `MARKED_AS_SENT`.
    *   *When:* Khách mời mở link thiệp (kích hoạt ghi nhận thời điểm viewed).
    *   *Then:* Hệ thống cập nhật trường `FirstViewedAt` và `LastViewedAt` trong DB. Trạng thái thiệp mời trên app vẫn hiển thị đúng là `MARKED_AS_SENT` kèm mốc thời gian đã xem, không tự động xác nhận thiệp đã được giao thành công tuyệt đối tới tay khách.
*   **INV-AC-015 (Regenerate Token Preserves RSVP):**
    *   *Given:* Nhóm mời A đã phản hồi RSVP tham dự 2 người. Cặp đôi thực hiện hành động "Tái tạo liên kết" cho nhóm này trên app.
    *   *When:* Hệ thống cập nhật link mới.
    *   *Then:* Dữ liệu phản hồi tham dự 2 người của nhóm A được giữ nguyên tuyệt đối, không bị reset về trạng thái chờ (`Pending`).
*   **INV-AC-016 (Revoked Token Exposes No Wedding Data):**
    *   *Given:* Cặp đôi đã thực hiện tái tạo liên kết cho nhóm A.
    *   *When:* Người dùng hoặc khách cố gắng truy cập bằng đường link chứa token cũ trước đó.
    *   *Then:* Hệ thống chặn truy cập, chuyển hướng sang trang lỗi **WEB-ERR-01** và không hiển thị bất kỳ thông tin đám cưới nào (như tên cặp đôi, venue, ngày cưới, bản đồ hay VietQR).
*   **INV-AC-017 (Static VietQR Only After RSVP Success):**
    *   *Given:* Đám cưới cấu hình hiển thị VietQR mừng cưới. Khách truy cập thiệp lần đầu và đang ở trang đích **WEB-INV-01**.
    *   *When:* Khách cuộn xem thông tin thiệp.
    *   *Then:* Phân đoạn thông tin chuyển khoản VietQR hoàn toàn không hiển thị trên trang đích. Thông tin này chỉ xuất hiện sau khi khách đã hoàn thành gửi form RSVP tại màn hình thành công **WEB-RSV-02**.
*   **INV-AC-018 (RSVP Completion with Mixed Ready and Save-the-Date Events):**
    *   *Given:* Thiệp mời mời sự kiện A (đã RSVP-ready có Exact Date) và sự kiện B (chỉ Save-the-Date mới có Expected Month).
    *   *When:* Khách điền phản hồi đầy đủ cho sự kiện A và bấm gửi.
    *   *Then:* Hệ thống đánh giá khách đã hoàn thành phản hồi hiện cần thiết, trạng thái RSVP tổng hợp hiển thị là Đã hoàn tất (`RESPONDED`), và VietQR tĩnh được hiển thị thành công trên màn hình WEB-RSV-02 (nếu bật).
*   **INV-AC-019 (Save-the-Date Event Promoted to RSVP-Ready):**
    *   *Given:* Khách đã hoàn thành RSVP sự kiện A (Trạng thái tổng hợp = `RESPONDED`). Sự kiện B trước đó chỉ là Save-the-Date.
    *   *When:* Cặp đôi cấu hình ngày cưới chính xác (`Exact Date`) cho sự kiện B trên app Android.
    *   *Then:* Sự kiện B tự động chuyển thành `RSVP-ready`. Trạng thái RSVP tổng hợp của nhóm mời chuyển về Chưa hoàn tất (`PARTIAL`) để báo hiệu còn sự kiện chưa phản hồi.
*   **INV-AC-020 (Only Save-the-Date Events No VietQR):**
    *   *Given:* Thiệp mời chỉ gán mời các sự kiện cưới ở trạng thái Save-the-Date (chưa RSVP-ready).
    *   *When:* Khách mở thiệp xem thông tin.
    *   *Then:* Khách không thể gửi phản hồi RSVP (vì không có form câu hỏi). Không phát sinh sự kiện RSVP completion, VietQR mừng cưới hoàn toàn không hiển thị trên giao diện của khách.

---

## 6. Bảng Truy Xuất Nguồn Gốc (Traceability Matrix)

| Mã Yêu Cầu (Requirement ID) | Phân hệ / Luồng (Flow) | Mã Màn Hình (Screen ID) | Khái Niệm Miền (Domain Concept) | Quyết Định Thiết Kế (Discovery Decision) | Mã Tiêu Chí Nghiệm Thu (Acceptance Criteria) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **INV-FR-001** | Surface A | AND-GUE-04 | `Invitation` | Nhắm mục tiêu sự kiện riêng biệt từng nhóm | INV-AC-001, INV-AC-016 |
| **INV-FR-002** | Surface A | AND-GUE-04 | `Invitation` | Copy link không tự chuyển trạng thái SENT | INV-AC-011 |
| **INV-FR-003** | Surface A | AND-GUE-04 | `Invitation` | Tái tạo link bảo toàn dữ liệu RSVP cũ | INV-AC-013 |
| **INV-FR-004** | Surface A | AND-GUE-04 | `RSVP` | Cho phép cập nhật thủ công bất kể thời điểm | INV-AC-008 |
| **INV-FR-005** | Surface B | WEB-INV-01 | `Invitation` | Responsive web di động không bắt cài app | - |
| **INV-FR-006** | Surface B | WEB-INV-01 | - | Bảo vệ privacy, ẩn danh sách khách khác | - |
| **INV-FR-007** | Surface B | WEB-ERR-01 | `Invitation` | Link hỏng/thu hồi chuyển hướng trang lỗi an toàn | INV-AC-014 |
| **INV-FR-008** | Surface B | WEB-RSV-02 | `VietQR` | Chỉ hiện VietQR sau khi gửi RSVP thành công | INV-AC-015, INV-AC-018, INV-AC-020 |
| **INV-FR-009** | Surface B | WEB-RSV-02 | `VietQR` | MVP chỉ hỗ trợ QR tĩnh, không tự đối soát | - |
| **INV-FR-010** | Surface B | WEB-RSV-01 | `RSVP` | Lỗi mạng không làm mất dữ liệu đang điền | - |
