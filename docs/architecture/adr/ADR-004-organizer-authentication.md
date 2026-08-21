# Quyết Định Kiến Trúc: ADR-004 — Organizer Authentication

*   **Mã quyết định (ADR ID):** ADR-004
*   **Trạng thái (Status):** In Review (Đang Đánh giá)
*   **Người thực hiện:** Antigravity (AI Architect)
*   **Ngày cập nhật:** 20/08/2026

---

## 1. Ngữ Cảnh (Context)
Yêu cầu `REQ-06` quy định ban tổ chức đám cưới (Cô dâu, Chú rể, Thành viên hỗ trợ) phải được xác thực tài khoản trước khi truy cập không gian làm việc WeddingOS trên thiết bị Android. Ngược lại, trang Web thiệp cưới dành cho khách mời truy cập công khai (`Guest-facing Web`) tuyệt đối không yêu cầu tạo tài khoản hay xác thực Google/OTP.

Bản phân tích các phương án kiến trúc vòng 1 đã chốt định hướng sử dụng **Supabase Auth** làm nền tảng quản lý danh tính và **Google Sign-In** làm phương thức xác thực chính. ADR này chính thức đặc tả quyết định thiết kế xác thực cho ban tổ chức đám cưới và cơ chế liên kết tài khoản thành viên.

---

## 2. Phạm Vi Quyết Định (Scope)

### Quyết định trong tài liệu này:
*   Phương thức xác thực tài khoản ban tổ chức.
*   Lựa chọn nhà cung cấp dịch vụ danh tính (Identity Provider).
*   Vai trò của Supabase Auth đối với danh tính người dùng.
*   Phân biệt rõ ràng giữa Tài khoản người dùng (`User account`) và Tư cách thành viên Đám cưới (`WeddingMember`).
*   Mô hình lời mời và liên kết tài khoản Collaborator mới (`Pending Collaborator Invitation`).
*   Nguyên tắc duy trì phiên đăng nhập và đăng xuất.
*   Hành vi hệ thống khi thành viên bị xóa quyền truy cập đám cưới.
*   Hệ quả và rủi ro khôi phục tài khoản liên quan.

### Các quyết định hoãn lại (Deferred / Out of Scope):
*   Cấu trúc bảng cơ sở dữ liệu chi tiết của bảng `WeddingMember` và bảng `Invitation`.
*   Cách cài đặt thư viện auth trên Flutter app.
*   Lựa chọn gói package lưu trữ token cục bộ trên Android.
*   API routes và schemas chi tiết cho các hàm Edge Functions xác thực.

---

## 3. Mô Hình Danh Tính Hệ Thống (Identity Mental Model)
Kiến trúc WeddingOS phân biệt rõ hai khái niệm cốt lõi:
*   **Xác thực (Authentication):** Trả lời câu hỏi *"Người dùng này là ai?"* (`Who is this User?`).
*   **Phân quyền (Authorization):** Trả lời câu hỏi *"Người dùng này được phép làm gì trong Đám cưới này?"* (`What may this User do in this Wedding?`).

Tài khoản người dùng đã xác thực (`auth.users`) **hoàn toàn độc lập** với Tư cách thành viên đám cưới (`WeddingMember`). 
*   Một tài khoản người dùng có thể liên kết với **0, 1, hoặc nhiều** đám cưới khác nhau.
*   Khi bị xóa tư cách thành viên khỏi Đám cưới A, người dùng vẫn duy trì trạng thái đăng nhập của tài khoản người dùng (không bị logout tài khoản) và có thể truy cập Đám cưới B bình thường nếu có.

---

## 4. Các Phương Án Được Cân Nhắc (Options Considered)

### Phương án A: Google Sign-In qua Supabase Auth (SELECTED)
*   *Đánh giá:* Phương án tối ưu cho trải nghiệm Android (đăng nhập 1 chạm). Gói dịch vụ miễn phí hiện tại của Supabase cung cấp đủ hạn mức xác thực (Auth allowance) cho quy mô validation của MVP, tuy nhiên điều này là giả định vận hành và có thể thay đổi tùy thuộc vào chính sách giá/hạn mức của nhà cung cấp trong tương lai.

### Phương án B: Email / Mật khẩu truyền thống
*   *Đánh giá:* Một giải pháp thay thế khả thi. Tuy nhiên phương án này không được lựa chọn vì WeddingOS MVP hiện tại không cần thiết phải tự xây dựng và quản trị vòng đời mật khẩu, giao diện khôi phục mật khẩu (password recovery UX), và hạ tầng gửi mail khôi phục (email recovery infrastructure), khi danh tính Google đã đáp ứng đầy đủ yêu cầu hiện tại của ban tổ chức.

### Phương án C: Email Magic Link (DEFERRED)
*   *Đánh giá:* Bị trì hoãn cho các chặng sau vì Magic Link tạo ra sự lệ thuộc bắt buộc vào hạ tầng chuyển phát email thực tế (production email-delivery dependency). Tránh nhầm lẫn hạn mức MAU miễn phí của Supabase Auth với năng lực chuyển phát thư tín thực tế của máy chủ SMTP mặc định (SMTP mặc định của Supabase bị giới hạn ngặt nghèo ở mức **2 email/giờ**).

### Phương án D: Phone / SMS OTP (DEFERRED)
*   *Đánh giá:* Bị trì hoãn do yêu cầu tích hợp bên cung cấp SMS, quản lý chặn tin rác/giới hạn tần suất gửi (abuse/rate-limit), và chi phí gửi tin nhắn biến động (variable messaging cost) không cần thiết cho giai đoạn validation của MVP.

---

## 5. Quyết Định Kiến Trúc & Quy Trình Mời Thành Viên (Decision & Collaborator Onboarding Flow)

Hệ thống chính thức phê duyệt lựa chọn **Google Sign-In thông qua Supabase Auth** làm phương thức xác thực danh tính ban tổ chức đám cưới duy nhất cho phiên bản MVP.

Để giải quyết khoảng cách trải nghiệm (UX Gap) và loại bỏ hoàn toàn việc can thiệp thủ công vào cơ sở dữ liệu khi phân quyền, WeddingOS áp dụng quy trình mời thành viên hỗ trợ (Collaborator Onboarding) khép kín như sau:

### A. Luồng của OWNER (Mời thành viên)
1.  Tại giao diện quản trị thành viên của đám cưới (`AND-SET-01`), OWNER chọn Thêm Collaborator và nhập chính xác địa chỉ email Google dự kiến mà Collaborator sẽ dùng để đăng nhập WeddingOS.
2.  Hệ thống tạo một bản ghi **Lời mời đang chờ (Pending Collaborator Invitation)** liên kết với email này và vai trò `COLLABORATOR` (MVP không hỗ trợ tự định nghĩa vai trò mới).
3.  **Không gửi email/SMS tự động:** Hệ thống không tự động gửi bất kỳ email hay tin nhắn nào. OWNER chủ động liên hệ và nhắn qua Zalo, Messenger hoặc điện thoại: *"Hãy tải app WeddingOS và đăng nhập bằng tài khoản Google này nhé"*.
4.  **Thu hồi lời mời:** Trước khi Collaborator chấp nhận, OWNER có toàn quyền thu hồi (Revoke) lời mời này. Lời mời đã thu hồi sẽ bị hủy và không thể chấp nhận được nữa.

### B. Luồng của COLLABORATOR (Đăng nhập & Nhận quyền)
1.  Collaborator đăng nhập vào ứng dụng WeddingOS bằng Google OAuth.
2.  Hệ thống kiểm tra xem email tài khoản Google của họ có lời mời đám cưới nào đang chờ hoạt động hay không.
3.  Nếu khớp, ứng dụng Android hiển thị thông báo mời tham gia đám cưới tại màn hình `AND-ONB-07` và nút bấm **Chấp nhận (Accept)** / **Bỏ qua (Ignore)**. Người dùng phải chủ động bấm chọn Chấp nhận để tham gia đám cưới, không tự động join ngầm.
4.  **Chấp nhận lời mời (Class C Operation):** Thao tác chấp nhận lời mời là một thay đổi phân quyền nhạy cảm, bắt buộc xử lý qua ranh giới máy chủ tin cậy (Edge Function/Trusted Boundary) để kiểm soát các invariant sau:
    *   Xác thực danh tính tài khoản đăng nhập Google.
    *   Email tài khoản Google trùng khớp hoàn toàn với email trong lời mời đang chờ.
    *   Đám cưới hoạt động bình thường (không bị lưu trữ).
    *   Lời mời đang chờ hoạt động (chưa bị thu hồi).
    *   Không tạo bản ghi trùng lặp nếu người dùng đã là thành viên.
5.  **Binds to Stable ID:** Khi chấp nhận thành công, tư cách thành viên đám cưới (`WeddingMember`) sẽ được liên kết trực tiếp với ID người dùng xác thực ổn định của họ (`auth.users.id`). Địa chỉ email chỉ dùng để so khớp ban đầu, tuyệt đối không dùng chuỗi email động làm khóa phân quyền dài hạn.

### C. Cơ chế xử lý Sai lệch email (Mismatch)
*   Nếu tài khoản Google đăng nhập không trùng khớp với email trong bản ghi lời mời đang chờ, hệ thống chặn truy cập, không cho phép claim và không để lộ bất kỳ thông tin đám cưới nào.

---

## 6. Nguyên Tắc Phiên Làm Việc (Session Principles)
*   Người dùng duy trì trạng thái đăng nhập trên thiết bị Android qua các lần tắt/mở ứng dụng thông qua JWT refresh token.
*   *Xử lý khi session hết hạn:* 
    *   Mọi tương tác ghi mạng (mutation) sẽ thất bại một cách an toàn.
    *   Ứng dụng Android hiển thị yêu cầu người dùng xác thực lại danh tính.
    *   **Bảo toàn dữ liệu nháp:** Form nhập liệu dở dang trên giao diện Android phải được giữ nguyên để lưu lại sau khi đăng nhập lại thành công.

---

## 7. Hành Vi Đăng Xuất (Sign Out)
*   Thao tác đăng xuất trên thiết bị chỉ xóa token phiên làm việc cục bộ để chấm dứt quyền truy cập trên điện thoại đó. 
*   Đăng xuất **tuyệt đối không xóa** tư cách thành viên (`WeddingMember`) và không tác động đến dữ liệu đám cưới hiện hữu trong database.

---

## 8. Hành Vi Thu Hồi Quyền Truy Cập (Membership Revocation)
*   Khi Owner xóa quyền truy cập đám cưới của một Collaborator, tài khoản người dùng của Collaborator đó vẫn duy trì đăng nhập (không bị logout tài khoản).
*   Tại lần tương tác gửi yêu cầu xác thực tiếp theo từ thiết bị của Collaborator này, hệ thống sẽ trả về lỗi phân quyền truy cập đám cưới.
    *   Nếu Collaborator còn đám cưới khác: chuyển hướng về màn hình chọn đám cưới (`Wedding Selector`).
    *   Nếu không còn đám cưới nào khác: đưa về trạng thái đã đăng nhập nhưng chưa có đám cưới.

---

## 9. Rủi Ro Một Nhà Cung Cấp & Phục Hồi Tài Khoản (Single-provider Risk)
*   **Mã rủi ro:** `SINGLE_AUTH_PROVIDER_DEPENDENCY`
*   *Bản chất:* Việc chỉ hỗ trợ Google Sign-In tạo ra sự lệ thuộc hoàn toàn vào dịch vụ của Google. Nếu người dùng bị khóa tài khoản Google, WeddingOS MVP không có phương thức tự phục vụ (self-service) thứ hai để người dùng đăng nhập lại.
*   *Biện pháp giảm thiểu dài hạn (Deferred):* Sẽ xem xét tích hợp phương thức email Magic Link kết hợp dịch vụ SMTP chuyên dụng ngoài, hoặc thêm các nhà cung cấp OAuth thứ hai (như Apple Sign-In cho iOS sau này).

---

## 10. Bảo Mật & Ranh Giới Khách Mời
*   **An toàn OAuth:** Sử dụng luồng PKCE hoặc OAuth an toàn do Supabase Auth hỗ trợ, tuyệt đối không tự viết thủ công giao thức OAuth. Khóa bí mật (service credentials) tuyệt đối không được nhúng vào Flutter Client.
*   **Ranh giới khách mời:** Trình duyệt Guest Web tuyệt đối không sử dụng lại cơ chế Google Auth của ban tổ chức. Khách chỉ truy cập thiệp mời bằng token thiệp gửi qua Edge Functions công khai.

---

## 11. Bảng Tiêu Chí Nghiệm Thu Điển Hình (Acceptance Criteria)

*   **ADR-AC-001 (First Login Zero Weddings):**
    *   *Given:* Người dùng mới lần đầu đăng nhập ứng dụng bằng Google OAuth.
    *   *When:* Phiên xác thực hoàn tất và tài khoản người dùng được khởi tạo.
    *   *Then:* Người dùng tồn tại ở trạng thái đã đăng nhập nhưng có 0 đám cưới. Hệ thống hiển thị giao diện Onboarding tạo mới hoặc nhập đám cưới (`AND-ONB-02`), không tự sinh đám cưới giả.
*   **ADR-AC-002 (Owner Adds Pending Collaborator):**
    *   *Given:* Người dùng A (vai trò Owner) đang mở giao diện Cài đặt thành viên (`AND-SET-01`).
    *   *When:* Người dùng A nhập email `collaborator@example.com` và bấm "Gửi lời mời".
    *   *Then:* Hệ thống khởi tạo bản ghi lời mời ở trạng thái đang chờ (`Pending Collaborator Invitation`) liên kết với email này và vai trò `COLLABORATOR`.
*   **ADR-AC-003 (No Automated Messaging Sent):**
    *   *Given:* Người dùng A (Owner) bấm tạo lời mời thành công cho email `collaborator@example.com`.
    *   *When:* Bản ghi lời mời lưu trữ thành công vào Database.
    *   *Then:* Hệ thống không kích hoạt hay gửi bất kỳ tin nhắn SMS hoặc Email tự động nào tới địa chỉ email của Collaborator.
*   **ADR-AC-004 (Matching Google Account Sees Invitation):**
    *   *Given:* Tài khoản Google có email `collaborator@example.com` đăng nhập vào app WeddingOS.
    *   *When:* Ứng dụng nạp dữ liệu ở màn hình chính/onboarding.
    *   *Then:* Hệ thống quét và nhận diện có lời mời đang chờ trùng khớp email. Hiển thị hộp thoại thông báo mời tham gia đám cưới tại màn hình `AND-ONB-07` và nút bấm "Chấp nhận" / "Bỏ qua".
*   **ADR-AC-005 (User Accepts Invitation Binds to ID):**
    *   *Given:* Người dùng đăng nhập có email khớp đang mở popup thông báo lời mời.
    *   *When:* Người dùng bấm nút "Chấp nhận".
    *   *Then:* Lời mời chuyển sang trạng thái đã nhận, hệ thống tạo bản ghi thành viên đám cưới (`WeddingMember`) liên kết trực tiếp với ID người dùng (`auth.users.id`) ổn định của họ. Người dùng chính thức có vai trò `COLLABORATOR` trong đám cưới đó.
*   **ADR-AC-006 (Wrong Google Account Blocked):**
    *   *Given:* OWNER tạo lời mời cho email `collaborator@example.com`. Người dùng B đăng nhập bằng Google với email `other_user@example.com`.
    *   *When:* Người dùng B cố gắng tìm cách chấp nhận lời mời của email kia thông qua API hoặc URL.
    *   *Then:* Hệ thống so khớp email thất bại, chặn đứng yêu cầu ghi nhận quyền, không hiển thị bất kỳ dữ liệu nhạy cảm nào của đám cưới.
*   **ADR-AC-007 (Owner Revokes Invitation Before Acceptance):**
    *   *Given:* OWNER tạo lời mời cho email `collaborator@example.com`.
    *   *When:* Lời mời vẫn ở trạng thái đang chờ, OWNER bấm "Thu hồi lời mời" trên giao diện quản trị thành viên.
    *   *Then:* Lời mời chuyển sang trạng thái bị thu hồi (`REVOKED`). Khi người dùng sở hữu email `collaborator@example.com` đăng nhập vào app, hệ thống không hiển thị thông báo mời và chặn hoàn toàn thao tác bấm chấp nhận.
*   **ADR-AC-008 (No Duplicate Wedding Member Created):**
    *   *Given:* Người dùng A đã là thành viên của Đám cưới X.
    *   *When:* Người dùng A nhận được một lời mời khác của cùng Đám cưới X và bấm chấp nhận lời mời.
    *   *Then:* Hệ thống phát hiện đã tồn tại tư cách thành viên, ghi nhận chấp nhận thành công nhưng không nhân đôi bản ghi thành viên trong database.
*   **ADR-AC-009 (Collaborator Cannot Invite/Revoke Members):**
    *   *Given:* Người dùng B có vai trò `COLLABORATOR` trong Đám cưới X.
    *   *When:* Người dùng B gửi yêu cầu tạo lời mời thành viên mới hoặc yêu cầu thu hồi lời mời qua API/Edge Function.
    *   *Then:* Biên hệ thống máy chủ tin cậy (Edge Function) đối chiếu vai trò trong DB, chặn đứng thao tác và trả về lỗi phân quyền truy cập.
*   **ADR-AC-010 (User Removed from Wedding Stays Authenticated):**
    *   *Given:* Người dùng A đang đăng nhập app WeddingOS và tham gia Đám cưới X.
    *   *When:* OWNER của Đám cưới X xóa tư cách thành viên của Người dùng A khỏi đám cưới.
    *   *Then:* Tại lần tương tác tiếp theo, Người dùng A bị chặn quyền truy cập Đám cưới X, nhưng tài khoản Google xác thực tổng thể của họ vẫn hoạt động và không bị buộc đăng xuất khỏi hệ thống.

---

## 12. Điều Kiện Xem Xét Lại Quyết Định (Reconsideration Triggers)
Quyết định chỉ dùng Google Auth sẽ được đánh giá lại nếu:
*   Phần lớn người dùng ban hỗ trợ thử nghiệm (Collaborators) phản hồi không muốn hoặc không thể sử dụng tài khoản Google.
*   Khi phát triển ứng dụng di động lên iOS, yêu cầu kiểm duyệt của Apple App Store bắt buộc phải tích hợp Sign in with Apple song song với Google Sign-In.

---

## 13. Các Vấn Đề Trì Hoãn (Deferred Decisions)
Các quyết định chi tiết dưới đây hoàn toàn được hoãn lại:
*   Cấu hình dịch vụ SMTP bên ngoài để kích hoạt email Magic Link.
*   Tích hợp SMS gateway cho Phone OTP.
*   Lựa chọn gói thư viện Flutter dùng để lưu trữ an toàn refresh token trên Android.
*   Quy trình CI/CD cấu hình Google Client ID trên môi trường Supabase Auth.
