# Kiến Trúc Thông Tin & Danh Mục Màn Hình (IA & Screen Inventory) - WeddingOS

Tài liệu này đặc tả Kiến trúc thông tin (Information Architecture - IA) và Danh mục màn hình (Screen Inventory) của WeddingOS. Thiết kế này tập trung vào trải nghiệm di động gốc cho cặp đôi (Android-first) và giao diện Web di động gọn nhẹ cho khách mời (Guest-facing Responsive Web).

---

## 1. Nguyên Tắc Thiết Kế Trải Nghiệm (IA & UX Principles)

1.  **Android-first Ergonomics (Tối ưu công năng di động):** Thiết kế giao diện tập trung vào khu vực tương tác bằng ngón tay cái, ưu tiên các nút hành động chính (Contextual CTAs/FAB) ở nửa dưới màn hình.
2.  **Progressive Disclosure (Hiển thị tăng dần):** Không nhồi nhét tất cả thông tin lên một màn hình. Sử dụng màn hình Overview/Dashboard để hiện tóm tắt và dẫn dắt sâu hơn qua các danh sách/chi tiết.
3.  **Search-first cho danh sách lớn:** Với quy mô 150-300 khách mời và 50-100 công việc, tính năng tìm kiếm (Search) và lọc (Filter) luôn được đưa lên đầu màn hình danh sách.
4.  **Preserve Input (Bảo toàn dữ liệu nhập liệu):** Các form nhập liệu (đặc biệt là import Excel, nhập tay khách mời, ghi nhận thanh toán) phải tự lưu nháp hoặc bảo toàn nội dung khi bị gián đoạn (offline, thoát ứng dụng tạm thời).
5.  **Attention Center tập trung:** Dashboard hoạt động như một trung tâm điều phối, cảnh báo ngay các rủi ro (việc trễ hạn, đợt thanh toán cận kề, RSVP vượt hạn mức) để cặp đôi xử lý nhanh bằng một lượt chạm.
6.  **Lightweight Guest Web:** Giao diện khách mời tối giản, tải nhanh dưới vài giây trên mạng di động 4G, không đòi hỏi tải app hay đăng ký.

---

## 2. Cấu Trúc Điều Hướng Ứng Dụng Android (Top-level Navigation)

Ứng dụng di động gốc Android sử dụng mô hình điều hướng **Hybrid Bottom Navigation** gồm 4 Tab chính:
1.  **Tổng quan (Home / Dashboard):** Nơi xem countdown, cảnh báo dòng tiền, tiến độ kế hoạch và các phím tắt thêm nhanh.
2.  **Kế hoạch (Planning):** Quản lý công việc (Task), danh sách sự kiện con và hạn chót.
3.  **Tài chính (Finance):** Quản lý các khoản chi tiêu, lịch thanh toán đợt và các giao dịch tiền mặt.
4.  **Khách mời (Guests):** Quản lý danh sách khách mời, tạo thiệp online và theo dõi RSVP.
*   *Profile / Settings:* Lối vào khu vực cấu hình đám cưới và thành viên được đưa lên góc phải thanh Top Bar của tab Tổng quan (Home).

---

## 3. Chuyển Đổi Không Gian Cưới (Wedding Switcher UX)
*   **Vị trí thiết kế:** Nằm trên thanh Top Bar của màn hình **Tổng quan (Home)**.
*   **Cách thức hoạt động:** Người dùng bấm vào Tên cặp đôi ở thanh tiêu đề $\rightarrow$ Một Bottom Sheet mở ra hiển thị danh sách các Đám cưới họ tham gia để chuyển đổi nhanh hoặc tạo không gian cưới mới.

---

## 4. Đặc Tả Tab Khách Mời (Guest Tab IA)

Tab **Khách mời (Guests)** được phân tách thành hai chế độ xem trực tiếp không bị ẩn sâu:

### A. Chế độ xem mặc định: Nhóm mời (Invitation Party View - Mặc định)
Đây là màn hình chính thức đầu tiên khi người dùng bấm vào Tab Khách mời, vì nó liên quan trực tiếp đến số người mời, RSVP, link mời, trạng thái gửi thiệp và phục vụ quản lý phát thiệp tối ưu nhất.
*   *UI Terminology:* Sử dụng nhãn giao diện là **"Nhóm mời"** thay vì "Hộ gia đình". (Ví dụ: *Nhóm mời: Anh Nguyễn Văn A*, *Nhóm mời: Anh Nam & chị Vy*, *Nhóm mời: Gia đình bác Tư*). English domain class vẫn giữ nguyên là `InvitationParty`.
*   **Thông tin hiển thị ưu tiên:**
    *   Tên hiển thị nhóm mời (Display Name).
    *   Số người được mời (Invited Count).
    *   Trạng thái lời mời (Invitation Status).
    *   Tóm tắt phản hồi RSVP.
    *   Tóm tắt số khách xác nhận đi chi tiết theo từng sự kiện con được mời.
    *   Cảnh báo nếu số người xác nhận đi vượt quá số người được mời (`Attending Count > Invited Count`).
*   **Hành động chính (CTAs):**
    *   Mở chi tiết Nhóm mời.
    *   Chuẩn bị/Chia sẻ thiệp mời online.
    *   Xem phản hồi RSVP.
    *   Thêm mới Nhóm mời.

### B. Chế độ xem phụ: Khách lẻ (Guest View - Phụ)
*   **Thông tin hiển thị ưu tiên:**
    *   Họ tên khách mời (Guest Name).
    *   Số điện thoại / Thông tin liên hệ.
    *   Bên nhà (`Side`).
    *   Nhóm mối quan hệ chính (`Primary Group`).
    *   Nguồn danh sách khách (`Guest Source`).
    *   Nhóm mời đang trực thuộc (Invitation Party membership).
    *   Nhãn cảnh báo trùng lặp (Duplicate warning).
*   **Hành động chính (CTAs):**
    *   Thêm Khách mời mới.
    *   Sửa thông tin Khách mời.
    *   Tìm kiếm / Lọc danh sách.
    *   Xử lý gộp khách trùng lặp.
    *   Di chuyển khách giữa các Nhóm mời.

---

## 5. Danh Mục Màn Hình Đầy Đủ (Complete MVP Screen Inventory)

### Surface A: WeddingOS Android App (Dành cho Cặp đôi & Thành viên)

| ID Màn hình | Domain | Tên Màn hình | Loại Màn hình | Mục tiêu chính của Màn hình | CTA chính | CTA phụ |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **AND-ONB-01** | Wedding Core | Welcome & Auth | Full-screen flow | Chào mừng và Đăng nhập nhanh Google/Email | Đăng nhập Google | Đăng nhập bằng Email |
| **AND-ONB-02** | Wedding Core | Onboarding - Basics | Full-screen flow | Nhập tên cô dâu/chú rể và chọn Vai trò | Tiếp tục | Quay lại |
| **AND-ONB-03** | Wedding Core | Onboarding - Context | Full-screen flow | Chọn Phong tục vùng miền & Ngày dự kiến | Tiếp tục | Quay lại |
| **AND-ONB-04** | Wedding Core | Onboarding - Events | Full-screen flow | Tích chọn các sự kiện nghi lễ tổ chức | Tiếp tục | Quay lại |
| **AND-ONB-05** | Wedding Core | Onboarding - Estimates | Full-screen flow | Nhập dự toán ngân sách & Số khách ước tính | Tạo kế hoạch | **Bỏ qua (Skip)** |
| **AND-ONB-06** | Wedding Core | Plan Generation | Loading screen | Hiển thị tiến trình AI/Hệ thống sinh Task mẫu | Xem Dashboard | Không |
| **AND-ONB-07** | Wedding Core | Pending Invitations | Full-screen sheet | Xem và Chấp nhận/Để sau các lời mời đám cưới đang chờ (Hỗ trợ cả người dùng mới 0 đám cưới và thành viên hiện tại qua Wedding Selector) | Chấp nhận (Accept) | Để sau (Not Now) |
| **AND-HOM-01** | Wedding Core | Home Dashboard | Top-level dest | Xem tổng quan countdown, tiến độ, cảnh báo | Thêm nhanh (FAB) | Chuyển Wedding |
| **AND-PLA-01** | Planning | Task List / Timeline | Top-level dest | Danh sách Task phẳng lọc theo Phase/Sự kiện | Thêm Task mới | Bộ lọc / Tìm kiếm |
| **AND-PLA-02** | Planning | Task Detail | Detail screen | Xem chi tiết, phân công, hạn chót Task | Lưu thay đổi | Đánh dấu Hoàn thành |
| **AND-PLA-03** | Planning | Create/Edit Task | Form screen | Tạo mới hoặc sửa thông tin Task | Lưu | Hủy |
| **AND-PLA-04** | Planning | Event Detail | Detail screen | Xem thông tin sự kiện con, ngày giờ, địa điểm | Dời ngày sự kiện | Danh sách Task sự kiện |
| **AND-PLA-05** | Planning | Event Date Change | Form screen | Nhập ngày giờ mới cho Sự kiện | Tiếp tục | Hủy |
| **AND-PLA-06** | Planning | Date Change Impact Review | Review flow | Duyệt các Task bị dời hạn chót do đổi ngày | Xác nhận dời lịch | Điều chỉnh từng Task |
| **AND-PLA-07** | Planning | Event Removal Review | Review flow | Duyệt Task và Khoản chi bị ảnh hưởng khi xóa Event | Xác nhận xóa | Chuyển thành việc chung |
| **AND-FIN-01** | Finance | Finance Overview | Top-level dest | Thống kê Sức khỏe ngân sách & Dòng tiền 7/30 ngày | Ghi nhận chi tiêu | Xem mục lục khoản chi |
| **AND-FIN-02** | Finance | Budget Item Detail | Detail screen | Xem dự toán, thực chi, lịch thanh toán đợt | Ghi nhận thanh toán | Sửa khoản chi |
| **AND-FIN-03** | Finance | Create/Edit Budget Item | Form screen | Tạo mới hoặc sửa thông tin khoản chi tiêu | Lưu | Hủy |
| **AND-FIN-04** | Finance | Record Payment Form | Form screen | Nhập số tiền chi thực tế, ngày chuyển, Payer | Xác nhận | Hủy |
| **AND-FIN-05** | Finance | Record Refund Form | Form screen | Nhập số tiền hoàn nhận lại | Xác nhận | Hủy |
| **AND-FIN-06** | Finance | Add/Edit Installment | Form sheet | Thiết lập đợt thanh toán (số tiền, hạn chót) | Lưu | Hủy |
| **AND-GUE-01** | Guest | Guest Directory | Top-level dest | Quản lý Nhóm mời (Mặc định) và Khách lẻ | Thêm mới (+) | Import Excel |
| **AND-GUE-02** | Guest | Guest Detail | Detail screen | Xem thông tin liên lạc, nhóm quan hệ, nguồn | Sửa thông tin | Di chuyển nhóm mời |
| **AND-GUE-03** | Guest | Create/Edit Guest | Form screen | Tạo mới hoặc sửa thông tin cá nhân khách | Lưu | Hủy |
| **AND-GUE-04** | Guest | Invitation Party Detail | Detail screen | Quản lý nhóm mời, cấu hình sự kiện mời, link | Copy & Mark as Sent | Tái tạo link (Regenerate) |
| **AND-GUE-05** | Guest | Create/Edit Party | Form screen | Tạo nhóm mời, đặt tên và Invited Count | Lưu | Hủy |
| **AND-GUE-06** | Guest | Duplicate Merge Review | Review sheet | Xem so sánh thông tin và xử lý tác động thiệp | Xác nhận gộp | Giữ riêng biệt |
| **AND-GUE-07** | Guest | Bulk Excel Import Preview | Review flow | Upload file Excel, kiểm lỗi validate dữ liệu | Xác nhận nhập | Tải lại file |
| **AND-GUE-08** | Guest | Parent List Export Settings | Form sheet | Lọc khách theo Bố mẹ để xuất bản kiểm tra | Xuất Excel/PDF | Hủy |
| **AND-SET-01** | Wedding Core | Wedding Settings | Detail screen | Cài đặt chung, RSVP Cutoff, VietQR, Thành viên | Lưu | Quay lại |

---

### Surface B: Guest-facing responsive Web (Dành cho Khách mời)

| ID Màn hình | Domain | Tên Màn hình | Loại Màn hình | Mục tiêu chính của Màn hình | CTA chính | CTA phụ |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **WEB-INV-01** | Invitation/RSVP | Invitation Landing | Public Web | Hiển thị thiệp, thông tin ngày giờ, địa điểm các sự kiện được mời | Xác nhận tham dự (RSVP) | Xem bản đồ dẫn đường |
| **WEB-RSV-01** | Invitation/RSVP | RSVP Form | Public Web | Điền thông tin tham dự riêng từng sự kiện, số lượng người, ghi chú | Gửi phản hồi | Quay lại thiệp |
| **WEB-RSV-02** | Invitation/RSVP | RSVP Success & Gift | Public Web | Xác nhận gửi RSVP thành công, hiển thị VietQR mừng cưới (nếu bật) | Xong / Đóng | Sửa phản hồi |
| **WEB-ERR-01** | Invitation/RSVP | Link Error / Revoked | Public Web | Hiển thị khi link hết hạn/bị thu hồi. An toàn thông tin | Quay lại trang chủ | Liên hệ cô dâu/chú rể |

---

## 6. Bản Đồ Điều Hướng (Navigation Map)

### Android App Navigation Map
```
App (Đăng nhập thành công)
├── AND-HOM-01: Tổng quan (Home Dashboard)
│   ├── Nút Profile ──> AND-SET-01: Cài đặt & Thành viên
│   └── Top Bar Switcher ──> Bottom Sheet: Chuyển đám cưới / Xem lời mời đang chờ (AND-ONB-07) / Tạo đám cưới mới (AND-ONB-02)
├── AND-PLA-01: Kế hoạch (Task List/Timeline)
│   ├── Bấm Task ──> AND-PLA-02: Chi tiết Task ──> AND-PLA-03: Sửa Task
│   ├── Nút Events ──> Danh mục Sự kiện con ──> AND-PLA-04: Chi tiết Sự kiện
│   │   ├── Bấm Dời ngày ──> AND-PLA-05: Form đổi ngày ──> AND-PLA-06: Review tác động Task
│   │   └── Bấm Xóa Sự kiện ──> AND-PLA-07: Review tác động khi xóa Event
│   └── Nút Thêm Task ──> AND-PLA-03: Tạo Task
├── AND-FIN-01: Tài chính (Overview & Dòng tiền)
│   ├── Bấm Khoản chi ──> AND-FIN-02: Chi tiết Khoản chi ──> AND-FIN-03: Sửa Khoản chi
│   │   ├── Bấm Thêm đợt thanh toán ──> AND-FIN-06: Thêm đợt trả tiền
│   │   ├── Bấm Ghi thanh toán ──> AND-FIN-04: Form ghi trả tiền
│   │   └── Bấm Ghi hoàn tiền ──> AND-FIN-05: Form ghi hoàn tiền
│   └── Nút Thêm Khoản chi ──> AND-FIN-03: Tạo Khoản chi
└── AND-GUE-01: Khách mời (Danh sách Directory)
    ├── Switcher: Tab Nhóm mời (Mặc định) / Tab Khách lẻ (Dễ truy cập trực tiếp)
    ├── Tab Nhóm mời (Mặc định)
    │   ├── Bấm Nhóm mời ──> AND-GUE-04: Chi tiết Nhóm mời ──> AND-GUE-05: Sửa Nhóm mời
    │   └── Nút Thêm Nhóm mời ──> AND-GUE-05: Tạo Nhóm mời
    ├── Tab Khách lẻ (Phụ)
    │   ├── Bấm Khách lẻ ──> AND-GUE-02: Chi tiết Khách ──> AND-GUE-03: Sửa Khách
    │   ├── Cảnh báo trùng SĐT ──> AND-GUE-06: Review gộp khách trùng
    │   └── Nút Thêm Khách lẻ ──> AND-GUE-03: Tạo Khách lẻ
    ├── Nút Nhập hàng loạt ──> AND-GUE-07: Preview Import Excel
    └── Nút Xuất danh sách ──> AND-GUE-08: Lọc xuất bản kiểm tra cho bố mẹ
```

### Guest Web Navigation Map
```
Link truy cập (/invite/{token})
├── Hợp lệ ──> WEB-INV-01: Trang đích thiệp cưới
│   └── Bấm RSVP ──> WEB-RSV-01: Form điền thông tin RSVP
│       └── Bấm Gửi ──> WEB-RSV-02: Success (Hiện VietQR mừng cưới nếu bật)
│           └── Trước Cutoff ──> Click Sửa RSVP ──> WEB-RSV-01
│           └── Sau Cutoff ──> Ẩn nút Sửa / Hiện View-only & Hotline
└── Hết hạn/Revoked ──> WEB-ERR-01: Báo lỗi link không hợp lệ (Ẩn thông tin cá nhân)
```

---

## 7. Cấu Trúc Thông Tin Các Màn Hình Khóa (Key Screen Hierarchy)

### Màn hình AND-HOM-01: Tổng quan (Home Dashboard)
*   **Header Widget:** Tên Đám cưới & Switcher (Ví dụ: "Vy & Dung's Wedding 🔽") | Countdown ngày cưới hoặc Tháng dự kiến cưới.
*   **Attention Center (Thông báo quan trọng):** Thẻ cảnh báo động (*Có 3 việc trễ hạn*, *Đợt cọc nhà hàng 10M đến hạn*, *RSVP nhóm anh Nam vượt số người mời*).
*   **Planning Widget:** Biểu đồ tròn tiến trình % công việc | Nút CTA xem Timeline đầy đủ.
*   **Finance Widget:** Tiến trình hạn mức ngân sách (Tổng dự toán vs Đã chốt vs Đã thanh toán) | Nút CTA xem sổ chi tiêu.
*   **Guest Widget:** Tóm tắt thiệp (Số thiệp đã chuẩn bị | Đã gửi | Số người xác nhận đi thực tế).
*   **First-use / Empty State:** Nút CTA nổi bật nhập ngân sách hoặc khách mời nếu đã skip khi onboarding.

### Màn hình AND-GUE-01: Danh sách Khách mời (Guest Directory)
*   **Top Bar:** Tìm kiếm nhanh (tên/SĐT) | Lọc nhanh (Side, Source, RSVP).
*   **Segmented Switcher (Tab chính):**
    *   **Tab Nhóm mời (Mặc định):** Danh sách các nhóm nhận thiệp. Hiện: *Display Name*, *Invited Count*, *Invitation status*, *RSVP summary*, *Cảnh báo RSVP overcount*.
    *   **Tab Khách lẻ:** Hiện: *Guest Name*, *SĐT*, *Side*, *Primary Group*, *Nguồn*, *Nhóm mời trực thuộc*, *Duplicate warning*.
*   **FAB / Action Bar:** Nút Thêm mới (+) | Import Excel.

---

## 8. Thiết Kế Trạng Trái Trống & Lỗi (Empty / Error States)

1.  **Chưa chốt ngày cưới chính xác:** Dashboard và Kế hoạch hiện hạn chót dạng tương đối ("khoảng 1 tháng trước lễ cưới") | CTA: "Cập nhật ngày cưới chính xác".
2.  **Không có công việc nào (No Tasks):** CTA: "Tạo công việc" hoặc "Áp dụng bộ công việc mẫu vùng miền".
3.  **Lỗi nạp Excel hàng loạt:** Cảnh báo các dòng lỗi nghiệp vụ (sai định dạng, thiếu dữ liệu) và cho phép bấm tải lại (`Retry`) bảo toàn layout nạp cũ.
4.  **Thiệp hết hạn hoặc thu hồi (WEB-ERR-01):** Chỉ hiện thông báo chung, ẩn toàn bộ tên tuổi, bản đồ, VietQR của cặp đôi để bảo vệ quyền riêng tư.

---

## 9. Cơ Hội Tinh Giản Màn Hình (Screen Consolidation)

1.  Gom thao tác sửa, dời ngày và xóa sự kiện trực tiếp vào màn hình **AND-PLA-04: Chi tiết Sự kiện**.
2.  Sử dụng chung một layout form cho cả luồng Tạo mới và Chỉnh sửa đối với Task, Khoản chi và Khách mời (phân biệt qua tiêu đề header).

---

## 10. Các Quyết Định Kế Thừa Từ Giai Đoạn Trước

*   *Từ Cluster 3A:* Không tạo Global Contact. Bố mẹ rà soát qua bản Excel/PDF rút gọn bảo mật.
*   *Từ Cluster 3B:* VietQR chỉ hiển thị sau khi hoàn tất RSVP. Cutoff khóa quyền tự sửa ở cấp Wedding. RSVP và Attending Count được tách biệt và xử lý độc lập cho từng sự kiện được nhắm mục tiêu.
