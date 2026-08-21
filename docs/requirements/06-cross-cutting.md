# Đặc Tả Yêu Cầu Chi Tiết: REQ-06 — Cross-cutting Requirements

Tài liệu này đặc tả chi tiết các yêu cầu xuyên suốt (Cross-cutting) và yêu cầu phi chức năng (Non-functional Requirements - NFR) cho toàn bộ hệ thống WeddingOS ở mức sản phẩm và nghiệp vụ độc lập công nghệ.

---

## 1. Xác Thực & Danh Tính (Authentication & Identity)

*   **Xác thực không gian làm việc (Android Workspace):** Mọi thành viên ban tổ chức (`WeddingMember`) bắt buộc phải được xác thực danh tính thông tin tài khoản trước khi truy cập không gian đám cưới trên Android.
*   **Trải nghiệm khách mời (Guest-facing):** Khách mời truy cập trang thiệp cưới cá nhân hóa (**WEB-INV-01**) tuyệt đối không yêu cầu đăng ký tài khoản hay xác thực OTP.

### Yêu cầu chức năng & Quy tắc nghiệp vụ
*   **XCT-FR-001:** Người dùng hệ thống có thể tạo lập hoặc tham gia vào nhiều Đám cưới khác nhau (`Multi-wedding support`). Danh tính tài khoản của người dùng độc lập với vai trò thành viên cụ thể trong từng đám cưới. *(Surface: Android App)*
*   **XCT-BR-001:** Khi phiên làm việc (session) hoặc quyền truy cập của thành viên hết hiệu lực, hệ thống **PHẢI** tạm dừng thao tác ghi, hiển thị thông báo yêu cầu xác thực lại và **BẮT BUỘC** phải bảo toàn dữ liệu người dùng đang nhập dở trên giao diện để tránh mất mát dữ liệu sau khi đăng nhập lại thành công. *(Surface: Android App)*

---

## 2. Phân Quyền & Vai Trò (Authorization & Wedding Membership)

Hệ thống phân quyền nghiệp vụ của WeddingOS được thiết kế tối giản cho MVP nhằm đảm bảo an toàn thông tin nhạy cảm.

### Ma trận Phân quyền Nghiệp vụ (Authorization Matrix)

| Vai trò Nghiệp vụ (Business Role) | Xem thông tin Đám cưới | Quản lý Task & Guest | Xem/Sửa Tài chính nhạy cảm (Finance) | Cấu hình VietQR & Thiệp mời | Quản lý Thành viên (Members) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`Owner`** (Cặp đôi) | Có | Có | Có | Có | Có |
| **`Editor`** (Ban hỗ trợ) | Có | Có | Không | Có (Chỉ xem link/gửi) | Không |
| **`Guest`** (Khách vãng lai) | Chỉ xem sự kiện được mời | Không | Không | Chỉ xem VietQR tĩnh của mình | Không |

### Yêu cầu chức năng
*   **XCT-FR-002:** Hệ thống **PHẢI** chặn thành viên có vai trò `Editor` xem các thông tin tài chính nhạy cảm như: Tổng ngân sách mục tiêu, dự toán chi tiết, danh sách giao dịch thanh toán/hoàn tiền và thông tin tài khoản của người chi trả. *(Surface: Android App)*
*   **XCT-FR-003:** Khi quyền thành viên của một người dùng bị Owner thu hồi (`Member Removed`), hệ thống **PHẢI** lập tức chặn mọi thao tác đọc/ghi của người dùng đó đối với dữ liệu đám cưới tại lần tương tác tiếp theo. *(Surface: Android App)*

### 2.1. Quy Trình Mời & Nhận Quyền Thành Viên (Controlled Amendment AMEND-REQ-06-001)

*   **XCT-FR-008 (Mời Collaborator):** OWNER có thể tạo một lời mời thành viên đang chờ (`Pending Collaborator Invitation`) bằng cách nhập chính xác địa chỉ email Google mà Collaborator dự kiến dùng để đăng nhập WeddingOS. Vai trò mặc định được gán là `COLLABORATOR`.
*   **XCT-FR-009 (Thông báo thủ công):** Hệ thống không tích hợp tính năng tự động gửi email hoặc SMS thông báo lời mời. OWNER tự trao đổi thông tin và thông báo thủ công bên ngoài ứng dụng (Zalo, Messenger, SMS...) cho Collaborator.
*   **XCT-FR-010 (Đăng nhập & Chấp nhận):** Khi Collaborator đăng nhập vào ứng dụng bằng Google OAuth:
    *   Hệ thống tự động kiểm tra xem địa chỉ email Google của họ có lời mời đám cưới nào đang chờ hay không.
    *   Nếu có, ứng dụng hiển thị thông báo: *"Bạn có lời mời tham gia [Tên Đám cưới] với vai trò Thành viên hỗ trợ"*. Màn hình hiển thị này là **`AND-ONB-07` (Pending Invitations)**.
    *   Người dùng phải chủ động bấm chọn **Chấp nhận (Accept)** để kích hoạt quyền. Nếu chọn **Để sau (Not Now)**, lời mời vẫn ở trạng thái đang chờ để xử lý sau. Tuyệt đối không tự động join âm thầm.
*   **XCT-FR-011 (Thu hồi lời mời):** OWNER có quyền xem danh sách và thu hồi (Revoke) các lời mời đang chờ chưa được chấp nhận. Lời mời sau khi bị thu hồi sẽ mất hoàn toàn hiệu lực và không thể claim.
*   **XCT-BR-007 (Ràng buộc danh tính):** Khi Collaborator chấp nhận lời mời, tư cách thành viên (`WeddingMember`) sẽ được liên kết trực tiếp với mã ID tài khoản xác thực ổn định của người dùng (`auth.users.id`). Địa chỉ email chỉ dùng để khớp nối ban đầu, tuyệt đối không dùng chuỗi email động làm khóa phân quyền.
*   **XCT-BR-008 (Chặn so khớp sai):** Nếu tài khoản Google đăng nhập không trùng khớp hoàn toàn với địa chỉ email trong lời mời đang chờ, hệ thống chặn truy cập, không cho phép hiển thị thông tin đám cưới hoặc chấp nhận lời mời.
*   **XCT-BR-009 (Chống trùng lặp thành viên):** Nếu người dùng đã là thành viên của Đám cưới đó, việc chấp nhận lời mời bổ sung cho cùng đám cưới sẽ không tạo ra bản ghi thành viên trùng lặp trong database.
*   **XCT-BR-010 (Phân quyền mời):** Chỉ tài khoản có vai trò `OWNER` mới có quyền tạo mới hoặc thu hồi lời mời đang chờ. Tài khoản `COLLABORATOR` bị chặn hoàn toàn thao tác này từ biên máy chủ.

---

## 3. Cô Lập Bối Cảnh Đám Cưới (Wedding Context Isolation)

Dữ liệu giữa các Đám cưới khác nhau phải được cô lập tuyệt đối để tránh rò rỉ thông tin chéo.

### Ma trận Xử lý Chuyển đổi Bối cảnh (Context Switching Matrix)

| Tình huống tương tác | Trạng thái ứng dụng hiện tại | Hành vi xử lý của Hệ thống (System Behavior) |
| :--- | :--- | :--- |
| **Người dùng đổi đám cưới đang xem** | Đang mở form nhập liệu dở dang | Hệ thống hiển thị cảnh báo: *"Dữ liệu chưa lưu sẽ bị mất khi đổi đám cưới. Bạn có muốn tiếp tục?"* trước khi thực hiện chuyển đổi. |
| **Truy cập qua Deep link của Đám cưới B** | Đang đăng nhập và hoạt động tại Đám cưới A | Kiểm tra quyền truy cập của User đối với Đám cưới B. Nếu hợp lệ $\rightarrow$ Switch context sang B. Nếu không hợp lệ $\rightarrow$ Chặn và báo lỗi phân quyền an toàn. |
| **Bị thu hồi quyền khi app đang mở** | Đang xem danh sách Đám cưới A | Đóng màn hình hiện tại, hiển thị thông báo mất quyền và tự động chuyển hướng người dùng về màn hình chọn Đám cưới khả dụng khác. |

### Quy tắc nghiệp vụ
*   **XCT-BR-002:** Tuyệt đối không để xảy ra hiện tượng rò rỉ dữ liệu chéo (Cross-leakage). Mọi thao tác truy vấn dữ liệu từ thiết bị phải được giới hạn chặt chẽ trong phạm vi ID của Đám cưới đang hoạt động (`active Wedding context`).

---

## 4. Quyền Riêng Tư & Bảo Vệ Dữ Liệu Nhạy Cảm (Privacy & Sensitive Data)

Hệ thống bảo vệ nghiêm ngặt thông tin định danh cá nhân (PII) và dữ liệu tài chính của đám cưới.

### Yêu cầu chức năng
*   **XCT-FR-004:** Giao diện Web khách mời (**Surface B - Guest Web**) tuyệt đối không được phép rò rỉ dữ liệu nội bộ bao gồm: Danh sách khách mời khác, số điện thoại/email của khách khác, các ghi chú nội bộ của cặp đôi, dữ liệu tài chính chi tiêu đám cưới và thông tin các thành viên ban tổ chức. *(Surface: Guest Web)*
*   **XCT-FR-005:** Khi liên kết thiệp mời bị hỏng hoặc thu hồi (`REVOKED`), trang thông báo lỗi **WEB-ERR-01** phải ẩn hoàn toàn tên cô dâu/chú rể, thời gian, địa điểm, bản đồ dẫn đường và VietQR mừng cưới để đảm bảo an toàn thông tin tối đa. *(Screen: WEB-ERR-01)*

---

## 5. Kết Nối Di Động & Khôi Phục Sự Cố (Mobile Connectivity & Interruption Recovery)

MVP không yêu cầu thiết kế hệ thống full offline-first nhưng bắt buộc phải đảm bảo an toàn dữ liệu khi kết nối mạng bị gián đoạn đột ngột (Interruption-safe & Interruption Recovery).

### Ma trận Cấp độ Hoạt động Offline (Offline Operations Matrix)

| Phân hệ Nghiệp vụ | Cấp độ Hoạt động hỗ trợ | Hành vi xử lý khi mất kết nối (Offline Behavior) |
| :--- | :--- | :--- |
| **Welcome / Onboarding** | Yêu cầu Online | Chặn không cho thiết lập nếu không có mạng. |
| **Planning (Task)** | Read-only (Đọc offline) | Cho phép xem danh sách task đã tải lưu đệm trước đó. Chặn tạo/sửa. |
| **Finance (Chi tiêu/Giao dịch)** | Read-only (Đọc offline) | Cho phép xem báo cáo đã tải lưu đệm. Chặn tạo giao dịch mới để tránh sai lệch dòng tiền thực tế. |
| **Guest Management (Import)** | Yêu cầu Online | Chặn không cho upload và confirm import file Excel mới nếu không có mạng. |
| **Guest-facing RSVP Web** | Yêu cầu Online | Chặn không cho gửi RSVP. Khôi phục dữ liệu đang điền theo quy tắc REQ-05. |

### Yêu cầu chức năng & Quy tắc nghiệp vụ
*   **XCT-FR-006:** Khi kết nối mạng bị mất trong lúc người dùng đang chỉnh sửa form Task, Chi tiêu hoặc Khách mời trên Android, hệ thống **PHẢI** giữ nguyên nội dung đã nhập trên giao diện và hiển thị trạng thái *"Không có kết nối mạng"*, không được phép tự ý reset form hoặc làm mất dữ liệu của người dùng. *(Surface: Android App)*
*   **XCT-BR-003:** Hệ thống **KHÔNG ĐƯỢC PHÉP** hiển thị dữ liệu lên màn hình tổng hợp như thể dữ liệu đã được lưu thành công vào máy chủ nếu thực tế giao dịch lưu mạng chưa hoàn tất xác nhận từ server.

---

## 6. Chặn Gửi Trùng Lặp & Quy Tắc Gửi Lại (Duplicate Submission & Retry Semantics)

Chính sách ngăn chặn việc tạo trùng lặp dữ liệu do thao tác bấm nhiều lần hoặc do lỗi thử lại mạng (Retry).

### Yêu cầu chức năng
*   **XCT-FR-007:** Khi người dùng bấm các nút lưu giao dịch nhạy cảm (Lưu thanh toán, Lưu hoàn tiền, Xác nhận gộp khách, Xác nhận nhập Excel, Gửi RSVP), hệ thống **PHẢI** tạm thời khóa nút (Disable CTA) ngay lập tức cho đến khi giao dịch gửi hoàn tất phản hồi, ngăn chặn tình trạng bấm đúp (Double-tap) sinh dữ liệu trùng. *(Surface: Android App & Guest Web)*
*   **XCT-BR-004:** Quy trình thử lại (Retry) khi gặp sự cố timeout mạng **BẮT BUỘC** phải đảm bảo tính duy nhất (Idempotent). Việc gửi lại một yêu cầu ghi nhận thanh toán/hoàn tiền tài chính hoặc import khách mời cũ không được phép tạo thêm bản ghi giao dịch mới hoặc bản ghi khách mời trùng lặp trong hệ thống.

---

## 7. Ngày, Giờ & Múi Giờ (Date, Time & Timezone)

Quy chuẩn xử lý múi giờ và hiển thị thời gian đồng bộ trên hệ thống đám cưới.

### Quy tắc nghiệp vụ
*   **XCT-BR-005:** Mọi tính toán thời gian liên quan đến hạn chót RSVP (`Cutoff Date`), hạn hoàn thành công việc (`Task deadline`), hạn thanh toán đợt ngân sách (`Payment due date`), và đếm ngược thời gian (Countdown) **PHẢI** được tính toán đồng bộ theo múi giờ đám cưới (`Wedding timezone`) được cấu hình, không phụ thuộc vào múi giờ của thiết bị di động hiện tại của khách truy cập.
*   **XCT-BR-006:** Tránh quy đổi tháng dự kiến (`Expected Month`) thành ngày cưới chính xác giả (như ngày 01 của tháng) trong DB để tránh hiển thị sai lệch ý định của cặp đôi trên các màn hình thống kê.

---

## 8. Bản Địa Hóa Tiếng Việt (Vietnamese Localization)

*   **Ngôn ngữ mặc định:** Tiếng Việt là ngôn ngữ duy nhất của giao diện cặp đôi và khách mời trong MVP.
*   **Định dạng hiển thị chuẩn:**
    *   *Tiền tệ:* Hiển thị đơn vị VND (Ví dụ: `15.000.000 đ` hoặc `15.000.000 VND`).
    *   *Định dạng số:* Dùng dấu chấm `.` để phân tách phần nghìn và dấu phẩy `,` để phân tách phần thập phân (nếu có).
    *   *Định dạng ngày:* Sử dụng chuẩn hiển thị `DD/MM/YYYY` (Ví dụ: `18/12/2026`).

---

## 9. Lịch Âm Tham Chiếu (Lunar Calendar Reference)

*   **Phạm vi áp dụng:** Lịch âm chỉ đóng vai trò là nhãn thông tin hiển thị tham chiếu bổ sung (Reference tag) tại các sự kiện cưới con (`WeddingEvent`) được cặp đôi thiết lập hiển thị (Ví dụ: hiển thị thêm *"Ngày 10/11 Bính Ngọ"* bên dưới ngày dương lịch).
*   **Ràng buộc nghiệp vụ:** Tuyệt đối không sử dụng ngày âm lịch làm mốc tính toán tự động cho các hạn chót đóng tiền (Finance Installment due date) hoặc hạn chót hoàn thành công việc (Task due date) để tránh phức tạp hóa logic hệ thống trong MVP.

---

## 10. Phân Loại Lỗi & Trải Nghiệm Khôi Phục (Error Handling UX)

Phân loại các nhóm lỗi nghiệp vụ và yêu cầu hiển thị tương ứng đối với người dùng:

| Nhóm lỗi phát sinh | Mô tả lỗi | Trải nghiệm thông báo yêu cầu (UX Rule) |
| :--- | :--- | :--- |
| **`VALIDATION_ERROR`** | Sai định dạng đầu vào (ví dụ: số điện thoại sai). | Hiển thị thông báo lỗi inline ngay bên dưới ô nhập liệu bị sai. |
| **`NETWORK_UNAVAILABLE`** | Thiết bị mất hoàn toàn kết nối mạng. | Hiển thị Banner cảnh báo lỗi kết nối, giữ nguyên dữ liệu trên form và cung cấp nút thử lại. |
| **`TIMEOUT`** | Gửi yêu cầu mạng quá thời gian phản hồi. | Hiển thị thông báo: *"Yêu cầu kết nối quá hạn. Vui lòng kiểm tra lại đường truyền và thử lại."* |
| **`AUTH_LOST`** | Mất quyền truy cập/hết hạn session. | Hiển thị Popup yêu cầu xác thực lại, bảo toàn form dữ liệu đang nhập dở. |
| **`RESOURCE_CHANGED`** | Dữ liệu đã bị xóa/sửa bởi thành viên khác trước đó. | Hiển thị thông báo dữ liệu đã thay đổi, tự động tải lại dữ liệu mới nhất (Refresh) để đồng bộ. |
| **`SYSTEM_ERROR`** | Lỗi phát sinh hệ thống từ phía máy chủ. | Hiển thị thông báo lỗi thân thiện: *"Có lỗi xảy ra từ hệ thống. Ban quản trị đang xử lý, vui lòng thử lại sau."*. **Tuyệt đối không rò rỉ mã lỗi kỹ thuật hoặc log debug (stack trace) ra ngoài giao diện.** |

---

## 11. Vòng Đời Dữ Liệu Nghiệp Vụ (Data Lifecycle)

Hệ thống quản lý vòng đời dữ liệu dựa trên các nguyên tắc chốt chặn an toàn tài chính và lịch sử:

*   **Task (Lịch trình):** Cho phép xóa cứng nếu chưa hoàn thành hoặc khôi phục trạng thái đối với các task bị hủy (`CANCELLED` $\rightarrow$ `TODO`).
*   **Finance (Chi tiêu):** Chặn tuyệt đối hành động xóa cứng khoản chi tiêu (`BudgetItem`) nếu đã phát sinh bất kỳ giao dịch thanh toán hoặc hoàn tiền nào liên quan. Chỉ cho phép chuyển sang lưu trữ (`Cancel/Archive BudgetItem`) để bảo toàn lịch sử sổ sách kế toán.
*   **Guest (Khách mời):** Cho phép xóa khách chưa có dữ liệu RSVP gửi đi. Khách đã gửi thiệp hoặc phản hồi RSVP chỉ được phép ngắt liên kết nhóm hoặc chuyển lưu trữ lịch sử, không cho xóa cứng.
*   **Wedding Archive:** Khi một đám cưới bị cặp đôi chuyển sang trạng thái lưu trữ (`Archive Wedding`), toàn bộ dữ liệu của đám cưới đó trên app Android chuyển sang chế độ chỉ xem (View-only) đối với mọi thành viên. Các liên kết Guest Web vẫn duy trì hoạt động đọc bình thường cho khách mời nếu chưa quá hạn chót.

---

## 12. Chỉ Tiêu Hiệu Năng Trải Nghiệm (Performance Targets)

Các chỉ tiêu hiệu năng trải nghiệm người dùng tối thiểu được thiết lập cho MVP hoạt động trên môi trường mạng thông thường:

*   **XCT-NFR-001 (Android Load Time):** Thời gian tải danh sách công việc (dưới 100 tasks) hoặc danh sách khách mời (dưới 300 khách) không được vượt quá `2,0 giây` trong điều kiện mạng di động 3G/4G thông thường. *(Surface: Android App)*
*   **XCT-NFR-002 (Guest Web First Load):** Thời gian tải trang đích thiệp cưới dành cho khách mời (**WEB-INV-01**) trên thiết bị di động sử dụng mạng 4G thông thường không được quá `3,0 giây` để hiển thị nội dung lời chào chính. *(Surface: Guest Web)*
*   **XCT-NFR-003 (Excel Import Processing):** Phân tích cú pháp tệp Excel nhập khách mời quy mô 300 dòng không được vượt quá `5,0 giây` để hiển thị màn hình Preview dữ liệu. *(Surface: Android App)*

---

## 13. Khả Năng Tương Thích & Tiếp Cận Web Khách (Guest Web Accessibility)

*   **XCT-NFR-004 (Mobile-first Web Compatibility):** Trang Web khách mời bắt buộc phải hiển thị responsive mượt mà trên các trình duyệt di động phổ biến (Chrome, Safari, Android System WebView) của các dòng điện thoại Android và iOS thông dụng.
*   **XCT-NFR-005 (Accessibility Baseline):** Kích thước của các nút bấm và vùng tương tác (Touch targets) trên Guest Web phải đạt tối thiểu `44x44 dp` để khách lớn tuổi dễ dàng thao tác bấm nút RSVP. Typography phải rõ ràng, tương phản tốt.

---

## 14. Giới Hạn Băng Thông & Đa Phương Tiện (Media & Bandwidth Constraints)

*   **XCT-NFR-006 (Media Optimization):** Hệ thống phải tự động tối ưu hóa dung lượng ảnh cưới do cặp đôi đăng tải làm ảnh đại diện thiệp cưới (giới hạn dung lượng tải lên tối đa là `5MB` mỗi ảnh và tự động nén dung lượng khi truyền tải về Guest Web).
*   **Ràng buộc hoạt động:** Thiệp mời Guest Web bắt buộc phải hoạt động bình thường kể cả khi cặp đôi không cấu hình bất kỳ ảnh cưới nào (không block tính năng RSVP).

---

## 15. Ràng Buộc Hạ Tầng Miễn Phí (Free-tier-first Product Constraints)

*   **XCT-NFR-007:** Để vận hành tối ưu trên hạ tầng miễn phí (Free-tier), WeddingOS **KHÔNG THỰC HIỆN** các tính năng gửi tin nhắn SMS có tính phí, không nhúng các dịch vụ bản đồ hiển thị động có phí (Google Maps API dynamic), và không duy trì kết nối thời gian thực (Real-time socket connection) liên tục khi người dùng không tương tác.
*   *Lưu ý:* Mọi liên kết bản đồ chỉ đường đều sử dụng liên kết URL thường dẫn sang Google Maps hoặc Apple Maps để thiết bị tự mở ứng dụng ngoài.

---

## 16. Sự Kiện Quan Sát Nghiệp Vụ (Observability Business Events)

Danh sách các sự kiện nghiệp vụ cốt lõi cần ghi nhận log nghiệp vụ (Business Log) để phân tích hành vi người dùng, không bao gồm các dữ liệu nhạy cảm PII:

1.  `Wedding Created` (Tạo đám cưới mới thành công).
2.  `Progressive Onboarding Completed` (Hoàn thành onboarding).
3.  `Task Completed` (Hoàn thành công việc).
4.  `BudgetItem Created` (Tạo khoản chi tiêu mới).
5.  `Payment Transaction Recorded` (Ghi nhận giao dịch thanh toán thành công).
6.  `Excel Guest List Imported` (Hoàn tất nhập Excel khách mời).
7.  `Invitation Marked As Sent` (Đánh dấu đã gửi thiệp).
8.  `Invitation Link Opened` (Khách mở link thiệp lần đầu).
9.  `RSVP Response Submitted` (Khách gửi phản hồi RSVP thành công).

---

## 17. Bảng Tiêu Chí Nghiệm Thu Điển Hình (Acceptance Criteria)

*   **XCT-AC-001 (Member Revoked while App Open):**
    *   *Given:* Người dùng A (vai trò Editor) đang mở danh sách công việc của đám cưới. Người dùng A bị Owner xóa quyền truy cập đám cưới trên app.
    *   *When:* Người dùng A bấm cập nhật trạng thái của một Task.
    *   *Then:* Hệ thống chặn tương tác mạng, hiển thị lỗi phân quyền và tự động chuyển hướng người dùng khỏi không gian đám cưới này.
*   **XCT-AC-002 (Revoked Member with Another Wedding):**
    *   *Given:* Người dùng A bị xóa quyền tại Đám cưới X, nhưng người dùng A đang tham gia một Đám cưới Y khác trong hệ thống.
    *   *When:* Phiên làm việc của Đám cưới X bị thu hồi.
    *   *Then:* Hệ thống tự động chuyển hướng người dùng A về màn hình danh sách Đám cưới (`Wedding Selector`) để người dùng chọn Đám cưới Y hoặc tạo mới.
*   **XCT-AC-003 (Wedding Context Isolation during Switch):**
    *   *Given:* Người dùng đang mở Đám cưới A. Người dùng chọn chuyển sang xem Đám cưới B.
    *   *When:* Màn hình Đám cưới B tải xong.
    *   *Then:* Toàn bộ danh sách công việc, chi tiêu, khách mời và tổng quan thống kê hiển thị trên màn hình đều thuộc về Đám cưới B. Tuyệt đối không xuất hiện dữ liệu cũ của Đám cưới A trên bất kỳ widget hay cache nào.
*   **XCT-AC-004 (Wedding Timezone Differs from Device):**
    *   *Given:* Đám cưới thiết lập múi giờ là `Asia/Ho_Chi_Minh`. Thiết bị điện thoại của khách mời truy cập đang ở múi giờ Nhật Bản (UTC+9).
    *   *When:* Khách xem đồng hồ đếm ngược ngày cưới hoặc thời gian hết hạn RSVP.
    *   *Then:* Hệ thống tính toán thời gian đếm ngược dựa trên mốc ngày dương lịch quy đổi theo múi giờ `Asia/Ho_Chi_Minh`, không đổi theo giờ địa phương của điện thoại khách.
*   **XCT-AC-005 (RSVP Cutoff Date Semantics):**
    *   *Given:* Đám cưới cấu hình hạn chót RSVP Cutoff là ngày `15/10/2026` theo múi giờ `Asia/Ho_Chi_Minh`.
    *   *When:* Khách truy cập lúc 23:00 ngày `15/10/2026` giờ Việt Nam.
    *   *Then:* Giao diện web vẫn cho phép khách tự điền và sửa phản hồi RSVP (Chỉ khóa tính năng sửa bắt đầu từ 00:00 ngày `16/10/2026` theo múi giờ đám cưới).
*   **XCT-AC-006 (Archived Wedding is View-only):**
    *   *Given:* Đám cưới X đã được Owner chuyển sang trạng thái lưu trữ (`Archived`).
    *   *When:* Một thành viên ban tổ chức mở Đám cưới X trên app Android.
    *   *Then:* Người dùng xem được toàn bộ thông tin Planning, Finance, Guests và RSVP, nhưng các nút thêm mới, chỉnh sửa thông tin hoặc xóa dữ liệu đều bị ẩn hoặc vô hiệu hóa hoàn toàn.
*   **XCT-AC-007 (Archived Wedding Guest Link Access):**
    *   *Given:* Đám cưới X đã bị chuyển sang lưu trữ. Khách mời cố gắng truy cập link thiệp cưới cũ của họ.
    *   *When:* Trang web thiệp cưới tải.
    *   *Then:* Hệ thống chặn truy cập, tự động chuyển hướng khách sang trang báo lỗi an toàn **WEB-ERR-01** (không rò rỉ bất kỳ thông tin đám cưới nào).
*   **XCT-AC-008 (Network Retry Does Not Duplicate Payment):**
    *   *Given:* Người dùng bấm lưu giao dịch thanh toán khoản chi, kết nối mạng bị gián đoạn giữa chừng khiến app gửi lại yêu cầu lưu (Retry).
    *   *When:* Thao tác ghi mạng hoàn tất.
    *   *Then:* Hệ thống chỉ khởi tạo duy nhất một bản ghi giao dịch thanh toán tài chính trong cơ sở dữ liệu, không nhân bản thành hai giao dịch.
*   **XCT-AC-009 (Network Retry Does Not Duplicate RSVP):**
    *   *Given:* Khách bấm gửi RSVP và gặp sự cố mạng chập chờn kích hoạt gửi lại gói tin.
    *   *When:* Giao dịch mạng kết thúc.
    *   *Then:* Dữ liệu phản hồi RSVP của khách được cập nhật đè thành công lên một bản ghi duy nhất, không tạo ra hai bản ghi phản hồi trùng lặp của cùng một nhóm mời.
*   **XCT-AC-010 (Draft Form Survives Interruption):**
    *   *Given:* Người dùng đang nhập dở thông tin giao dịch thanh toán (nhập số tiền, chọn người trả). Ứng dụng Android bị đẩy xuống chạy ngầm (Background) hoặc thiết bị mất mạng.
    *   *When:* Người dùng mở lại ứng dụng Android hoặc khôi phục kết nối.
    *   *Then:* Form nhập liệu vẫn giữ nguyên các thông số số tiền và người chi trả đã điền, không bị reset form về trạng thái trống.
*   **XCT-AC-011 (No False Saved State):**
    *   *Given:* Người dùng bấm lưu một khoản chi tiêu mới khi thiết bị đang ở trạng thái mất kết nối mạng.
    *   *When:* Giao dịch mạng lỗi.
    *   *Then:* Ứng dụng hiển thị thông báo lỗi mạng. Hệ thống không cập nhật hiển thị khoản chi tiêu này vào danh sách tổng hợp như thể đã lưu thành công.
*   **XCT-AC-012 (Lunar Date Reference Tag):**
    *   *Given:* Sự kiện cưới có cấu hình hiển thị lịch âm. Ngày cưới dương lịch là `18/12/2026`.
    *   *When:* Giao diện thiệp cưới Guest Web tải.
    *   *Then:* Hiển thị thông tin ngày cưới dương lịch kèm theo nhãn phụ ghi chú ngày âm tương ứng dưới dạng text tĩnh tham khảo (không ảnh hưởng tới overdue hay countdown ngày).
*   **XCT-AC-013 (Android Touch Target Baseline):**
    *   *Given:* Người dùng mở danh sách công việc hoặc cài đặt thành viên.
    *   *When:* Hệ thống hiển thị các nút tương tác (nút tick hoàn thành task, nút xóa thành viên).
    *   *Then:* Diện tích cảm ứng thực tế của các nút bấm và ô chọn tương tác đạt tối thiểu `48dp × 48dp` để dễ dàng thao tác bấm chạm.
*   **XCT-AC-014 (Invalid Authorization leaks No Wedding Data):**
    *   *Given:* Người dùng cố gắng truy cập trái phép vào bối cảnh đám cưới của người khác bằng cách thay đổi ID đám cưới trên deep link.
    *   *When:* Hệ thống kiểm tra quyền.
    *   *Then:* Yêu cầu bị chặn đứng ngay lập tức, chuyển người dùng về trang thông báo lỗi phân quyền chung và không tải bất kỳ thông tin nào của đám cưới bị hack.
*   **XCT-AC-015 (First Login Zero Weddings):**
    *   *Given:* Người dùng mới lần đầu đăng nhập ứng dụng bằng Google OAuth.
    *   *When:* Phiên xác thực hoàn tất và tài khoản người dùng được khởi tạo.
    *   *Then:* Người dùng tồn tại ở trạng thái đã đăng nhập nhưng có 0 đám cưới. Hệ thống hiển thị giao diện Onboarding tạo mới hoặc nhập đám cưới (`AND-ONB-02`), không tự sinh đám cưới giả.
*   **XCT-AC-016 (Owner Adds Pending Collaborator):**
    *   *Given:* Người dùng A (vai trò Owner) đang mở giao diện Cài đặt thành viên (`AND-SET-01`).
    *   *When:* Người dùng A nhập email `collaborator@example.com` và bấm "Gửi lời mời".
    *   *Then:* Hệ thống khởi tạo bản ghi lời mời ở trạng thái đang chờ (`Pending Collaborator Invitation`) liên kết với email này và vai trò `COLLABORATOR`.
*   **XCT-AC-017 (No Automated Messaging Sent):**
    *   *Given:* Người dùng A (Owner) bấm tạo lời mời thành công cho email `collaborator@example.com`.
    *   *When:* Bản ghi lời mời lưu trữ thành công vào Database.
    *   *Then:* Hệ thống không kích hoạt hay gửi bất kỳ tin nhắn SMS hoặc Email tự động nào tới địa chỉ email của Collaborator.
*   **XCT-AC-018 (Matching Google Account Sees Invitation):**
    *   *Given:* Tài khoản Google có email `collaborator@example.com` đăng nhập vào app WeddingOS.
    *   *When:* Ứng dụng nạp dữ liệu ở màn hình chính/onboarding.
    *   *Then:* Hệ thống quét và nhận diện có lời mời đang chờ trùng khớp email. Hiển thị hộp thoại thông báo mời tham gia đám cưới tại màn hình `AND-ONB-07` và nút bấm "Chấp nhận" / "Để sau".
*   **XCT-AC-019 (User Accepts Invitation Binds to ID):**
    *   *Given:* Người dùng đăng nhập có email khớp đang mở popup thông báo lời mời.
    *   *When:* Người dùng bấm nút "Chấp nhận".
    *   *Then:* Lời mời chuyển sang trạng thái đã nhận, hệ thống tạo bản ghi thành viên đám cưới (`WeddingMember`) liên kết trực tiếp với ID người dùng (`auth.users.id`) ổn định của họ. Người dùng chính thức có vai trò `COLLABORATOR` trong đám cưới đó.
*   **XCT-AC-020 (Wrong Google Account Blocked):**
    *   *Given:* OWNER tạo lời mời cho email `collaborator@example.com`. Người dùng B đăng nhập bằng Google với email `other_user@example.com`.
    *   *When:* Người dùng B cố gắng tìm cách chấp nhận lời mời của email kia thông qua API hoặc URL.
    *   *Then:* Hệ thống so khớp email thất bại, chặn đứng yêu cầu ghi nhận quyền, không hiển thị bất kỳ dữ liệu nhạy cảm nào của đám cưới.
*   **XCT-AC-021 (Owner Revokes Invitation Before Acceptance):**
    *   *Given:* OWNER tạo lời mời cho email `collaborator@example.com`.
    *   *When:* Lời mời vẫn ở trạng thái đang chờ, OWNER bấm "Thu hồi lời mời" trên giao diện quản trị thành viên.
    *   *Then:* Lời mời chuyển sang trạng thái bị thu hồi (`REVOKED`). Khi người dùng sở hữu email `collaborator@example.com` đăng nhập vào app, hệ thống không hiển thị thông báo mời và chặn hoàn toàn thao tác bấm chấp nhận.
*   **XCT-AC-022 (No Duplicate Wedding Member Created):**
    *   *Given:* Người dùng A đã là thành viên của Đám cưới X.
    *   *When:* Người dùng A nhận được một lời mời khác của cùng Đám cưới X và bấm chấp nhận lời mời.
    *   *Then:* Hệ thống phát hiện đã tồn tại tư cách thành viên, ghi nhận chấp nhận thành công nhưng không nhân đôi bản ghi thành viên trong database.
*   **XCT-AC-023 (Collaborator Cannot Invite/Revoke Members):**
    *   *Given:* Người dùng B có vai trò `COLLABORATOR` trong Đám cưới X.
    *   *When:* Người dùng B gửi yêu cầu tạo lời mời thành viên mới hoặc yêu cầu thu hồi lời mời qua API/Edge Function.
    *   *Then:* Biên hệ thống máy chủ tin cậy đối chiếu vai trò trong DB, chặn đứng thao tác và trả về lỗi phân quyền truy cập.
*   **XCT-AC-024 (User Removed from Wedding Stays Authenticated):**
    *   *Given:* Người dùng A đang đăng nhập app WeddingOS và tham gia Đám cưới X.
    *   *When:* OWNER của Đám cưới X xóa tư cách thành viên của Người dùng A khỏi đám cưới.
    *   *Then:* Tại lần tương tác tiếp theo, Người dùng A bị chặn quyền truy cập Đám cưới X, nhưng tài khoản Google xác thực tổng thể của họ vẫn hoạt động và không bị buộc đăng xuất khỏi hệ thống.

---

## 18. Lịch Sử Hiệu Chỉnh Yêu Cầu (Controlled Amendment Audit Log)

*   **Mã hiệu chỉnh:** `AMEND-REQ-06-001` (Controlled Amendment following ADR-004 gap discovery).
*   **Mô tả sửa đổi:** Bổ dung yêu cầu chức năng từ `XCT-FR-008` đến `XCT-FR-011`, quy tắc nghiệp vụ từ `XCT-BR-007` đến `XCT-BR-010` và bộ tiêu chí nghiệm thu từ `XCT-AC-015` đến `XCT-AC-024` đặc tả quy trình mời Collaborator bằng email Google và cơ chế chấp nhận lời mời để giải quyết lỗ hổng liên kết tài khoản thủ công trong MVP.
*   **Ngày cập nhật:** 20/08/2026.
