# Đặc Tả Kiến Trúc: 02 — Logical Architecture (Kiến Trúc Logic)

*   **Trạng thái (Status):** Approved (Đã Phê duyệt)
*   **Người thực hiện:** Antigravity (AI Architect)
*   **Ngày cập nhật:** 20/08/2026

---

## 1. Thành Phần Logic Hệ Thống (Logical Components)

Hệ thống WeddingOS được chia làm 3 phân vùng thực thi logic chính trên môi trường chạy:

### A. Ứng Dụng Di Động Android (Flutter Organizer Application)
Chạy trên thiết bị di động của ban tổ chức (OWNER và COLLABORATOR). Đây là môi trường không tin cậy (untrusted client). Gồm các mô-đun logic nghiệp vụ sau:
*   **Xác thực / Nhập cuộc (Authentication / Onboarding):** Quản lý trạng thái đăng nhập qua Google OAuth, khởi tạo đám cưới mới và tích hợp màn hình `AND-ONB-07` để chấp nhận lời mời tham gia làm thành viên đám cưới.
*   **Quản trị Đám cưới (Wedding Foundation):** Cấu hình cơ bản của Đám cưới, thiết lập Expected Month hoặc Exact Date.
*   **Quản lý Kế hoạch (Planning):** Quản lý danh sách sự kiện con (`WeddingEvent`) và công việc phẳng (`Task`), tính toán hạn chót tương đối dựa trên ngày sự kiện.
*   **Quản lý Tài chính (Finance):** Theo dõi hạn mức ngân sách tổng thể, cấu hình khoản chi (`BudgetItem`), lịch thanh toán đợt (`Installment`) và ghi nhận giao dịch (`Payment` / `Refund`). Chặn quyền truy cập đối với vai trò `COLLABORATOR`.
*   **Quản lý Khách mời (Guest Management):** Quản lý hồ sơ khách lẻ (`Guest`), nhóm hộ gia đình nhận thiệp (`InvitationParty`), nhóm quan hệ người dùng tự định nghĩa (`PrimaryGroup`) và phân tổ chức Side/Group.
*   **Quản lý Thiệp mời (Invitation Management):** Chuẩn bị link thiệp mời cá nhân hóa cho từng nhóm mời, quản lý trạng thái gửi thiệp và kích hoạt tái tạo token.
*   **Trung tâm Cảnh báo (Attention Center):** Tính toán và kết xuất trực quan các cảnh báo quá hạn, dòng tiền cận kề, cảnh báo trùng khách, cảnh báo RSVP vượt định mức khi người dùng mở ứng dụng.
*   **Cài đặt & Thành viên (Settings / Members):** Quản lý thiết lập chung (VietQR, RSVP Cutoff) và gửi/thu hồi lời mời thành viên ban tổ chức.
*   **Nhập / Xuất dữ liệu (Import / Export):** Phân tích tệp Excel khách mời thô cục bộ trên thiết bị (Preview/Mapping) trước khi xác nhận gửi lệnh nhập, và xuất tệp Excel/PDF cục bộ cho bố mẹ rà soát chéo.

### B. Ứng Dụng Web Khách Mời (Guest Web)
Chạy trên trình duyệt di động của khách mời nhận thiệp. Đây là môi trường hoàn toàn không tin cậy (untrusted client). Gồm các phần logic sau:
*   **Khung ứng dụng tĩnh (Static App Shell):** Phân phối mã nguồn React/Vite tĩnh qua Cloudflare Pages, không chứa thông tin cá nhân.
*   **Giải quyết Lời mời (Invitation Resolution):** Phân tích mã truy cập thiệp từ URL để gửi yêu cầu lấy dữ liệu cá nhân cá nhân hóa.
*   **Giao diện RSVP (RSVP UI):** Hiển thị thiệp, tiếp nhận thông tin phản hồi số người tham dự riêng biệt cho từng sự kiện và gửi phản hồi.
*   **Truy xuất tài nguyên (Media Access):** Tải hình ảnh đám cưới thông qua đường dẫn được ký cấp quyền thời gian.

### C. Nền Tảng Cơ Sở Supabase (Supabase Platform)
Thành phần máy chủ đóng vai trò cung cấp hạ tầng nghiệp vụ tin cậy (trusted server). Gồm:
*   **Auth (Supabase Auth):** Xác thực tài khoản Google và quản lý token phiên làm việc của ban tổ chức.
*   **Data Access (PostgreSQL API):** API mặc định để truy xuất trực tiếp các bảng dữ liệu qua phân quyền RLS.
*   **PostgreSQL Database:** Lưu trữ dữ liệu quan hệ, thực thi kiểm soát phân quyền ở cấp độ dòng (Row Level Security - RLS).
*   **Storage:** Lưu trữ hình ảnh đám cưới cá nhân hóa dưới mô hình Private Bucket.
*   **Giao dịch Nghiệp vụ Tin cậy (Trusted Operations):** Các tác vụ xử lý máy chủ đặc quyền của ban tổ chức (bypassing RLS) để thực thi nghiệp vụ phức tạp (như mời thành viên, nhập Excel khách mời, xóa đám cưới).
*   **Giao dịch Công khai Tin cậy (Public Trusted Operations):** Các tác vụ xử lý máy chủ phục vụ luồng khách mời Web không tài khoản (như phân tích mã thiệp mời, tiếp nhận phản hồi RSVP trước hạn cutoff, ký cấp link ảnh tạm thời).

---

## 2. Ranh Giới Tin Cậy Hệ Thống (Trust Boundaries)

Hệ thống phân định rõ ranh giới an ninh dựa trên ADR-003 và ADR-005 như sau:

```
[ GUEST WEB (Untrusted) ]        ──(Public Token)──> [ Public Trusted Operations (Supabase Edge) ]
                                                                      │ (Bypasses RLS with Checks)
[ FLUTTER CLIENT (Untrusted) ]   ──(Google JWT)────> [ Authenticated Data API (Supabase RLS) ]  
                                 ──(Google JWT)────> [ Trusted Operations (Supabase Edge) ]
                                                                      │
                                                                      ▼
                                                         [ AUTHORITATIVE POSTGRESQL ]
                                                         [ PRIVATE STORAGE BUCKET ]
```

*   **Không tin cậy Client (Untrusted Client Boundary):** Cả ứng dụng Android và Guest Web đều chạy trên thiết bị người dùng. Mọi kiểm tra định dạng dữ liệu (validation) tại client chỉ phục vụ nâng cao trải nghiệm người dùng (UX), không được coi là chốt chặn an ninh.
*   **Ranh giới Data API xác thực (Authenticated Data API):** Bảo vệ các câu lệnh CRUD trực tiếp từ client Android của ban tổ chức bằng cơ chế RLS của PostgreSQL dựa trên định danh người dùng đã đăng nhập (`auth.uid()`).
*   **Ranh giới Giao dịch máy chủ tin cậy (Trusted/Privileged Operations):** Các xử lý nghiệp vụ phức tạp đòi hỏi kiểm tra nhiều bảng hoặc bỏ qua RLS để thực thi quyền cao (như OWNER xử lý thành viên, nạp danh sách import). Biên máy chủ bắt buộc phải tự xác thực lại ID ban tổ chức, vai trò và tính toàn vẹn nghiệp vụ.
*   **Ranh giới Giao dịch công khai tin cậy (Public Trusted Operations):** Ranh giới an ninh tối quan trọng cô lập cơ sở dữ liệu nội bộ với Guest Web. Khách mời truy cập web không đăng nhập tài khoản. Edge Function (được chọn làm biên máy chủ công khai của MVP theo ADR-005) chịu trách nhiệm phân tích mã thiệp mời thô để trả về dữ liệu đã làm sạch (Sanitized), hoặc tiếp nhận phản hồi RSVP và lưu trữ an toàn, tuyệt đối không cho phép Guest Web đọc/ghi trực tiếp vào database.
*   **Cơ sở dữ liệu có thẩm quyền (Authoritative PostgreSQL):** Nguồn sự thật duy nhất của hệ thống, thực thi toàn bộ các ràng buộc khóa và quy tắc nghiệp vụ ở tầng lưu trữ.
*   **Lưu trữ hình ảnh riêng tư (Private Storage):** Không cho phép tải ảnh cưới công khai trực tiếp. Mọi truy cập ảnh cưới của khách mời phải thông qua signed URL ngắn hạn được cấp sau khi giải quyết mã thiệp mời hợp lệ.

---

## 3. Các Lớp Tương Tác Nghiệp Vụ (Interaction Classes)

Hệ thống phân loại toàn bộ tương tác giữa các thành phần logic thành 4 lớp (Classes A/B/C/D):

### Class A: Người tổ chức Đọc dữ liệu đơn giản (Organizer Simple Read)
*   *Mô tả:* Ban tổ chức mở app xem danh sách công việc, danh sách khách mời, báo cáo chi tiêu tài chính.
*   *Luồng xử lý:* Flutter Client $\rightarrow$ Gửi yêu cầu qua Supabase PostgreSQL API $\rightarrow$ Database đối chiếu phân quyền RLS của người dùng đăng nhập $\rightarrow$ Trả về kết quả trực tiếp.

### Class B: Người tổ chức Ghi dữ liệu đơn giản (Organizer Simple Mutation)
*   *Mô tả:* Ban tổ chức chỉnh sửa tên công việc, cập nhật số điện thoại một khách mời lẻ, sửa ghi chú chi tiêu.
*   *Luồng xử lý:* Flutter Client $\rightarrow$ Gửi yêu cầu ghi qua Supabase PostgreSQL API $\rightarrow$ Database đối chiếu phân quyền RLS của người dùng đăng nhập $\rightarrow$ Thực thi câu lệnh ghi và phản hồi thành công.

### Class C: Giao dịch nghiệp vụ tin cậy của Ban tổ chức (Compound Trusted Business Operation)
*   *Mô tả:* OWNER mời thêm Collaborator mới (`XCT-FR-008`), OWNER thu hồi lời mời thành viên (`XCT-FR-011`), OWNER thực hiện lệnh gộp khách hàng trùng (`Guest Merge`), OWNER xác nhận nhập danh sách khách từ Excel (`Confirm Import`), OWNER xóa/dời ngày sự kiện (`Event Removal/Date Change`).
*   *Luồng xử lý:* Flutter Client $\rightarrow$ Gọi lệnh xử lý nghiệp vụ tin cậy $\rightarrow$ Máy chủ xác thực ID tài khoản và kiểm tra vai trò người gọi $\rightarrow$ Chạy logic nghiệp vụ đặc quyền (bypassing RLS nếu cần) $\rightarrow$ Lưu dữ liệu an toàn vào DB $\rightarrow$ Phản hồi kết quả.
*   *Lưu ý:* Việc lựa chọn công nghệ cụ thể cho biên xử lý tin cậy Class C (như Edge Function, PostgreSQL functions/triggers, hoặc kết hợp cả hai) được hoãn lại cho tầng API và Physical Design tiếp theo quyết định. Cơ sở dữ liệu trigger không mặc định là tương đương hoàn toàn với điểm gọi Class C. Biên Class C phải tự thực thi xác thực quyền truy cập và các quy tắc nghiệp vụ theo đúng ADR-003.

### Class D: Khách mời tương tác thiệp công khai (Guest Public Operation)
*   *Mô tả:* Khách click vào link thiệp mời cá nhân hóa (`/invite/{token}`) để nạp dữ liệu thiệp mời và gửi phản hồi RSVP.
*   *Luồng xử lý:* Guest Web $\rightarrow$ Gửi mã thiệp mời lên Public Trusted Edge Function $\rightarrow$ Máy chủ xác thực tính hợp lệ của mã thiệp và trạng thái đám cưới $\rightarrow$ Máy chủ trả về thông tin đã làm sạch (Sanitized Data) hoặc tiếp nhận dữ liệu RSVP ghi vào Database $\rightarrow$ Phản hồi kết quả.
*   *Lưu ý:* Biên máy chủ công khai cho Class D đã được chốt sử dụng Supabase Edge Function theo ADR-005.

---

## 4. Quy Tắc Phụ Thuộc Logic (Logical Dependency Rules)

1.  **Phân hệ Kế hoạch không sở hữu Tài chính (Planning $\rightarrow$ Finance Block):** Mô-đun công việc (`Planning/Task`) có thể tham chiếu tới một sự kiện cưới (`WeddingEvent`) nhưng tuyệt đối không được phép trực tiếp tạo lập, thay đổi hay tham chiếu trực tiếp đến các thực thể giao dịch hoặc khoản chi tài chính (`BudgetItem`/`Payment`).
2.  **Tài chính chỉ tham chiếu tĩnh (Finance $\rightarrow$ Planning Isolation):** Các khoản chi tiêu tài chính (`BudgetItem`) có thể liên kết tĩnh tới mã sự kiện (`WeddingEventId`) để phân bổ ngân sách theo buổi lễ, nhưng tuyệt đối không được phụ trách việc thay đổi trạng thái hoàn thành hay hạn chót của công việc (`Task`).
3.  **Khách mời tách biệt hoàn toàn với RSVP (Guest List $\rightarrow$ Invitation/RSVP Isolation):**
    *   Hồ sơ khách mời cá nhân (`Guest`) độc lập hoàn toàn với thực thể thiệp mời (`Invitation`) và phản hồi (`RSVP`).
    *   Sự thay đổi trạng thái phản hồi RSVP từ Web của khách chỉ tác động trực tiếp tới thực thể con `EventResponse` bên trong `Invitation` Aggregate. Hệ thống không tự động ghi đè hay thay đổi thông tin liên lạc hay thuộc tính nội bộ của `Guest` phía sau.
4.  **Danh tính tài khoản tách biệt với Tư cách thành viên (User Identity $\neq$ WeddingMember):** Danh tính xác thực của người dùng (tài khoản Google OAuth trong `auth.users`) độc lập với tư cách thành viên đám cưới (`WeddingMember`). Một tài khoản người dùng có thể là Owner của Đám cưới A đồng thời là Collaborator của Đám cưới B, dữ liệu bối cảnh của hai đám cưới phải được cô lập hoàn toàn.
5.  **Dữ liệu phái sinh phụ thuộc vào dữ liệu nguồn:** Mọi giá trị thống kê phái sinh (như công nợ `Outstanding`, tổng tiền thanh toán ròng `Net Paid`, chỉ số trễ hạn `Overdue`) bắt buộc phải được tính toán từ các dữ liệu nguồn lịch sử có thẩm quyền (Confirmed Cost, Payments, Refunds, Deadlines), tuyệt đối không cho phép client thay đổi trực tiếp các chỉ số phái sinh này.

---

## 5. Luồng Chạy Điển Hình Hệ Thống (Major Runtime Flows)

### A. Luồng Mời và Chấp Nhận quyền Collaborator (Onboarding & Member Invitation)

```
[ Owner App ]                    [ Edge Function (Class C) ]            [ Database ]
      │                                       │                              │
      ├─ 1. Gửi email mời ───────────────────>│                              │
      │  collaborator@example.com             ├─ 2. Tạo lời mời PENDING ────>│
      │                                       │  (chưa liên kết User ID)     │
                                                                             │
[ Collaborator App ]                                                         │
      │                                                                      │
      ├─ 3. Đăng nhập bằng Google ───────────> [ Supabase Auth ]             │
      │  (email: collaborator@example.com)                                   │
      │                                                                      │
      ├─ 4. Mở màn hình chính ───────────────>│                              │
      │  (Yêu cầu quét lời mời đang chờ)      ├─ 5. Quét tìm email trùng ───>│
      │                                       │<─ 6. Trả về thông tin mời ───┤
      │<─ 7. Hiện popup mời (AND-ONB-07) ─────┤                              │
      │                                       │                              │
      ├─ 8. Người dùng chọn ACCEPT ──────────>│                              │
      │                                       ├─ 9. Liên kết WeddingMember ──>│
      │                                       │  với auth.users.id           │
      │                                       ├─ 10. Chuyển Lời mời ────────>│
      │                                       │  sang trạng thái ACCEPTED    │
```

---

### B. Luồng Giải Quyết Thiệp Mời và RSVP của Khách (Guest Invitation & RSVP Flow)

```
[ Guest Web ]                      [ Edge Function (Class D) ]          [ Database ]
      │                                         │                            │
      ├─ 1. URL chứa token ────────────────────>│                            │
      │  /invite/{token}                        ├─ 2. Xác thực token, ──────>│
      │                                         │  đám cưới active, cutoff   │
      │                                         │<─ 3. Trả về thông tin ─────┤
      │<─ 4. Hiển thị trang WEB-INV-01 ─────────┤  đã làm sạch (Sanitized)   │
      │                                         │                            │
      ├─ 5. Gửi RSVP (Attending Count) ────────>│                            │
      │  (WEB-RSV-01)                           ├─ 6. Kiểm tra hạn cutoff, ──>│
      │                                         │  Attending <= Invited      │
      │                                         ├─ 7. Ghi nhận RSVP vào DB ──>│
      │<─ 8. Hiển thị VietQR (WEB-RSV-02) ──────┤                            │
```

---

### C. Luồng Dời Ngày Sự Kiện và Tính lại Hạn chót Task (Event Date Change Workflow)

```
[ Organizer App ]                [ Edge Function / Database ]           [ Database ]
      │                                       │                              │
      ├─ 1. Gửi lệnh dời ngày sự kiện ───────>│                              │
      │  (Event T1 -> T2)                     ├─ 2. Cập nhật ngày sự kiện ──>│
      │                                       │                              │
      │                                       ├─ 3. Quét các Task liên kết ──>│
      │                                       │<─ 4. Trả về mảng Task ───────┤
      │                                       │                              │
      │                                       ├─ 5. Lọc bỏ các Task đã ──────┤
      │                                       │  ở trạng thái COMPLETED      │
      │                                       │                              │
      │                                       ├─ 6. Tính lại hạn chót cho ──>│
      │                                       │  Task nhóm relative tĩnh     │
      │                                       │                              │
      │                                       ├─ 7. Nhận diện các Task nhóm ─┤
      │                                       │  đã sửa tay / absolute       │
      │<─ 8. Trả về danh sách Task bị ────────┤                              │
      │  ảnh hưởng để Review (AND-PLA-06)     │                              │
```

---

## 6. Rủi Ro & Khoảng Trống Kiến Trúc (Architecture Risks & Gaps)

1.  **Rủi ro Trễ hạn đồng bộ thiết bị (Client-side Data Stale Risk):** Do hệ thống không sử dụng Supabase Realtime để tiết kiệm tài nguyên hạ tầng, khi hai thành viên (ví dụ: Cô dâu và Chú rể) cùng mở app tại một thời điểm, dữ liệu trên màn hình di động có thể bị lệch pha.
    *   *Biện pháp khắc phục:* Áp dụng chính sách kiểm tra dữ liệu phiên bản trước khi ghi (Optimistic Concurrency Control / Version checking) tại máy chủ tin cậy để ngăn chặn ghi đè dữ liệu cũ.
2.  **Khoảng trống Thu hồi quyền truy cập tức thời (Instant Access Revocation Gap):** Khi Owner xóa quyền thành viên của một Collaborator, do độ trễ của kiểm tra phiên làm việc JWT trên thiết bị di động, Collaborator có thể thực hiện một vài thao tác đọc tạm thời từ cache cục bộ trước khi lệnh chặn có hiệu lực.
    *   *Biện pháp khắc phục:* Thực hiện kiểm tra trạng thái hoạt động của thành viên (`WeddingMember.status == ACTIVE`) tại mỗi giao dịch ghi nhạy cảm trên máy chủ.
3.  **Rủi ro quá hạn mức băng thông ảnh (Media Egress Exhaustion):** Link ảnh cưới riêng tư (Signed URL) gửi cho 20.000 khách mời vẫn tiêu tốn lượng băng thông lớn của Supabase Storage nếu khách mời tải đi tải lại ảnh cưới gốc chưa nén.
    *   *Biện pháp khắc phục:* Bắt buộc ứng dụng Flutter Android của ban tổ chức phải thực hiện nén giảm kích thước ảnh cưới tối đa trước khi thực hiện tải lên máy chủ.
