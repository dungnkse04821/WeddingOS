# Khám Phá Sản Phẩm & Luồng Người Dùng: WeddingOS

Tài liệu này ghi nhận kết quả Khám phá sản phẩm cấp cao (High-level Discovery) và Luồng người dùng chi tiết cho các phân hệ của WeddingOS.

---

## PHẦN I: THIẾT KẾ CHI TIẾT CLUSTER 1 — WEDDING FOUNDATION (ĐÃ PHÊ DUYỆT)

*   **Progressive Onboarding:** Chỉ bắt buộc nhập Tên cặp đôi, Ngày cưới dự kiến và Phong tục tổ chức. Mọi trường khác có thể skip.
*   **Authentication trước:** Bắt buộc đăng ký/đăng nhập nhanh trước khi bắt đầu Onboarding. Không có Guest Mode.
*   **Không giả lập dữ liệu:** Khi skip bước Ngân sách/Khách mời, hệ thống lưu trạng thái `Chưa thiết lập/Chưa ước tính` và hiện nút CTA nhập liệu trên Dashboard. Không dùng con số 200M/200 khách mặc định để giả lập.
*   **Tiến độ thực tế:** Tiến độ lập kế hoạch bắt đầu từ 0% công việc hoàn thành. Onboarding không được tính là Task.
*   **Xử lý ngày cưới chưa rõ:** Nếu chưa chốt ngày chính xác, hệ thống chỉ hiển thị `"Dự kiến: Tháng X/Năm Y"` và hiển thị hạn chót task dạng tương đối (ví dụ: *"khoảng 1 tháng trước lễ cưới"*). Không hiển thị ngày 15 giữa tháng giả lập.
*   **Tách biệt Phong tục & Địa lý:** Khảo sát Onboarding hỏi về Phong tục tổ chức chủ đạo (Miền Bắc, Miền Trung, Miền Nam, Chưa rõ / Tùy chỉnh sau) thay vì đồng nhất với Địa điểm tổ chức cưới.
*   **First Value & Activation:** First Value là `Initial Wedding Plan Generated`. Activation là `First Meaningful Planning Action`.

---

## PHẦN II: THIẾT KẾ CHI TIẾT CLUSTER 2A — PLANNING (ĐÃ PHÊ DUYỆT)

*   **Đơn vị nhỏ nhất:** `Task` là đơn vị lập kế hoạch nhỏ nhất của hệ thống. Hệ thống không hỗ trợ công việc con (Checklist) hay subtask.
*   **Dịch chuyển ngày cưới (Model C):** Tự động dịch chuyển Task hệ thống (Nhóm A); giữ nguyên và đưa vào Review đối với Task người dùng đã chỉnh (Nhóm B & C); giữ nguyên đối với Task hoàn thành (Nhóm D).
*   **Hủy sự kiện không xóa sạch việc (Event Removal):** Khi xóa sự kiện, cho phép người dùng chọn giữ lại các công việc tự tạo/đã sửa và chuyển thành công việc chung.
*   **Tách biệt Side & Assignee:** Decouple thuộc tính Side của Task (`BRIDE_SIDE`, `GROOM_SIDE`, `COMMON`) khỏi gán người chịu trách nhiệm (`Assignee`).
*   **Task không thuộc Event:** Cho phép các công việc chung cấp Đám cưới tồn tại độc lập không gắn với sự kiện nào.
*   **Hạn chót tương đối âm/dương:** Hỗ trợ relative rule cho cả trước cưới (offset âm, e.g. `-30 ngày`) và sau cưới (offset dương, e.g. `+7 ngày`).
*   **Mở lại Task đã hoàn thành:** Reopen đối với Task nhóm A sẽ tự động cập nhật hạn chót mới theo Event Date. Đối với Task nhóm B & C (user-managed), giữ nguyên hạn chót cũ.
*   **Chốt ngày từ dự kiến sang chính xác:** Bảo toàn intent của người dùng (Preserve User Intent). Task Nhóm A tự tính theo ngày cưới; Task Nhóm B tự tính theo offset tùy chỉnh cũ của họ; Task Nhóm C (ngày tuyệt đối) giữ nguyên ngày tuyệt đối và đưa vào Review.

---

## PHẦN III: THIẾT KẾ CHI TIẾT CLUSTER 2B — FINANCE (ĐÃ PHÊ DUYỆT)

*   **Payer Model:** Người thanh toán được ghi nhận trên từng Giao dịch thực tế (`Payment`). Không làm planned percentage split trong MVP.
*   **Dashboard:** Hiển thị song song cả Sức khỏe ngân sách (Budget Health) và Dòng tiền sắp tới (Cash Flow/Upcoming Payments).
*   **Thuật ngữ UI:** Sử dụng chính xác: *Dự toán*, *Đã chốt*, *Đã thanh toán*, *Còn phải trả*. Không dùng từ "Thực chi" cho mục Committed Cost.
*   **Giá trị Đã chốt tùy biến:** Cho phép sửa đổi giá trị Đã chốt khi chi phí cuối thay đổi. Không lưu lịch sử phiên bản.
*   **Thanh toán từng phần:** Một đợt thanh toán (Installment) có thể thanh toán bằng nhiều Payment (hỗ trợ Partial Payment).
*   **Độc lập Payment:** Một Payment thuộc duy nhất 1 Budget Item, không phân bổ cho nhiều Item.
*   **Hoàn tiền riêng biệt (Refund):** Tách biệt luồng giao dịch Hoàn tiền (Refund) trên giao diện, tự động xử lý số tiền âm dưới hệ thống mà không bắt người dùng nhập dấu trừ `-` thủ công.
*   **Nợ trên giá trị chốt:** `Còn phải trả = Đã chốt - Đã thanh toán`. Không tự động suy ra công nợ từ *Dự toán* nếu chưa có giá trị *Đã chốt*.
*   **Event Linkage:** Khoản chi thuộc tối đa 1 Sự kiện hoặc cấp Đám cưới.
*   **Ngân sách tối giản:** Dashboard tài chính vẫn hoạt động bình thường nếu Hạn mức ngân sách để trống (`Chưa thiết lập`).

---

## PHẦN IV: THIẾT KẾ CHI TIẾT CLUSTER 3A — GUEST MODEL (ĐÃ PHÊ DUYỆT)

*   **Khách mời tích hợp (Unified Guest Model):** MVP không dùng Danh bạ toàn cục (`Global Contact`). Mọi thông tin liên hệ lưu trực tiếp trên thực thể `Guest` trong đám cưới.
*   **Nhóm Lời mời Lai (Hybrid Invitation Party Model):** `InvitationParty` đại diện cho một thiệp phát ra, chứa Display Name, danh sách Guest đã biết tên, và chỉ số `Invited Count`. Cho phép headcount lớn hơn số Guest đã biết tên (ví dụ: chỉ cần tạo 1 Guest "Bác Tư" nhưng chốt mời 4 người).
*   **Nguồn Khách mời (Guest Source):** Định rõ nguồn khách (Bride, Groom, Bố mẹ hai bên, Khác) để phục vụ nhập thay và bộ lọc.
*   **Gộp trùng lặp có duyệt tác động (Merge):** Khi gộp trùng SĐT chuẩn hóa ở 2 Party khác nhau, hệ thống yêu cầu Review tác động (chọn giữ Party A/B, di chuyển sang Party khác hoặc tạo Party mới) trước khi chốt, không tự động gộp. Không tự động xóa các Party trống có dữ liệu lịch sử/RSVP cũ.
*   **Import Excel mẫu:** Excel template (`.xlsx`) là hình thức bulk import chính. Hệ thống kiểm tra tính hợp lệ nghiệp vụ của dữ liệu và cảnh báo trùng trước khi cho phép xác nhận import thực tế.
*   **Chỉ số Headcount:** Phân biệt rõ ràng *Số người được mời (Invited Count)* và *Số khách xác nhận (RSVP Attending)*.
*   **Nhóm mối quan hệ Nhiều-Một:** Mỗi khách chỉ thuộc tối đa 1 nhóm mối quan hệ chính (`Primary Group`). Không xây tag hay nhóm phân cấp.
*   **Proxy Management & Export:** Con cái nhập hộ bố mẹ. Xuất danh sách kiểm tra ra PDF/Excel rút gọn (ẩn SĐT, ghi chú bảo mật) gửi Zalo cho bố mẹ duyệt thủ công. Không làm tài khoản hay cổng xác thực OTP riêng cho bố mẹ trong MVP.

---

## PHẦN V: THIẾT KẾ CHI TIẾT CLUSTER 3B — INVITATION & RSVP (ĐÃ PHÊ DUYỆT)

## 1. Mô hình Tư duy Lời mời & RSVP (Invitation & RSVP Mental Model)

Hệ thống điều hành Lời mời và Phản hồi của WeddingOS được chốt với các đặc tả hành vi sản phẩm như sau để tối ưu hóa trải nghiệm khách mời và đảm bảo quyền riêng tư.

### A. Nhắm mục tiêu Sự kiện trong Lời mời (Event-specific Targeting)
*   Một lời mời (`Invitation`) có thể nhắm mục tiêu (target) một tập hợp các sự kiện cưới cụ thể (`WeddingEvent[]`). Khách mời chỉ nhìn thấy thông tin thời gian, địa điểm, bản đồ của các sự kiện mà họ được mời.

### B. RSVP riêng biệt từng Sự kiện (Event-specific RSVP)
*   Nếu một lời mời chứa nhiều sự kiện (ví dụ: Ăn hỏi + Tiệc cưới), giao diện RSVP cho phép khách phản hồi tham dự và số lượng đi kèm **độc lập cho từng sự kiện** (ví dụ: Ăn hỏi chọn *Không tham gia*; Tiệc cưới chọn *Tham gia*).
*   **Số lượng đi kèm theo sự kiện:** Chỉ số `Attending Count` được quản lý độc lập theo từng Sự kiện trong RSVP của nhóm mời (ví dụ: Ăn hỏi đi 2 người; Tiệc cưới đi 4 người) do nhu cầu cỗ bàn và quy mô các buổi lễ là khác nhau.

### C. Khống chế mềm Số người được mời (Invited Count - Soft Constraint)
*   Hệ thống không khóa cứng (hard-block) giao diện nếu khách muốn đăng ký số lượng `Attending Count` vượt quá số lượng mời `Invited Count`.
*   **UX Tế nhị:** Nếu chọn vượt, giao diện hiển thị wording lịch sự: *"Thiệp hiện được chuẩn bị cho [N] khách. Nếu bạn cần đăng ký thêm người, vui lòng để lại ghi chú để cô dâu/chú rể xác nhận."*
*   **Quản lý phía Cặp đôi:** Hệ thống cho phép submit và gắn cờ cảnh báo trên trang quản trị để cặp đôi duyệt. Hệ thống không tự động tăng `Invited Count` nếu chưa được cặp đôi duyệt thủ công.

### D. Tối giản thông tin RSVP
*   MVP không bắt buộc nhập tên tất cả người đi cùng để tối đa hóa tốc độ hoàn thành RSVP.
    *   *Required:* Trạng thái tham dự theo sự kiện, Số lượng đi kèm (nếu đi).
    *   *Optional:* Họ tên những người đi cùng, tùy chọn ăn uống (chay/dị ứng), ghi chú/lời chúc gửi cặp đôi.

---

## 2. Vòng đời Lời mời (Invitation Lifecycle) và Quản lý Token

### A. Vòng đời nghiệp vụ Lời mời
Hệ thống phân biệt trạng thái nghiệp vụ và tín hiệu theo dõi (Tracking signals):
*   **Trạng thái nghiệp vụ (Lifecycle Status):** `DRAFT/PREPARED` (Dự thảo) $\rightarrow$ `READY` (Sẵn sàng) $\rightarrow$ `SENT / MARKED_AS_SENT` (Đã gửi) $\rightarrow$ `REVOKED` (Thu hồi - nếu có).
    *   *Quy tắc gửi thiệp:* Hệ thống không tự động coi việc bấm `Copy Link` là thiệp đã được gửi đi (tránh báo cáo sai lệch). Cặp đôi có thể chọn hành động kết hợp copy link và đánh dấu là đã gửi (`Copy & Mark as Sent`).
*   **Tín hiệu theo dõi (Tracking Signals):** Lưu trữ các mốc thời gian độc lập: `SentAt` (Ngày gửi), `FirstViewedAt` (Lần đầu khách xem), `LastViewedAt` (Lần cuối khách xem). Trạng thái `Viewed` chỉ là tín hiệu theo dõi hỗ trợ, không phải trạng thái nghiệp vụ chính.

### B. Bảo toàn dữ liệu khi Thay đổi Token (Regenerate Link)
*   Mỗi `InvitationParty` có duy nhất 1 active Invitation gắn với một token truy cập ngẫu nhiên.
*   Khi cặp đôi bấm tái tạo link (Regenerate Link) để thu hồi quyền truy cập cũ do gửi nhầm:
    *   Hệ thống chỉ thay thế Token truy cập (Access credential).
    *   **Không làm mất** dữ liệu lịch sử gửi, phản hồi RSVP hoặc các thay đổi trước đó của lời mời đó. Token cũ lập tức trở nên vô hiệu.

---

## 3. Cài đặt Hạn chót & Trải nghiệm sau Khóa RSVP (RSVP Cutoff)
*   **Khóa chung cấp Đám cưới (Wedding-level Cutoff):** Hệ thống áp dụng một ngày hạn chót khóa RSVP duy nhất cho toàn bộ đám cưới (Cài đặt tùy chọn).
*   **UX sau hạn chót:** Khách mời vẫn mở được link thiệp mời cá nhân để xem thông tin tiệc cưới và trạng thái RSVP cũ, nhưng không thể chỉnh sửa. Hệ thống hiển thị thông báo khóa và phương thức liên hệ do cặp đôi tự cấu hình (không tự động hiển thị số điện thoại cá nhân mặc định).

---

## 4. Vị trí hiển thị VietQR nhận mừng cưới
*   Mã VietQR tĩnh nhận mừng cưới của cặp đôi chỉ được hiển thị **sau khi khách mời đã hoàn tất xác nhận gửi RSVP** (áp dụng cho cả khách bấm chọn *Tham gia* hoặc *Không tham gia*). Không hiển thị VietQR ở phần đầu trang đích khi vừa mở thiệp để đảm bảo tính tinh tế trong văn hóa Việt Nam.

---

## PHẦN VI: TUYÊN BỐ KẾT THÚC GIAI ĐOẠN KHÁM PHÁ SẢN PHẨM & LUỒNG NGƯỜI DÙNG

> [!IMPORTANT]
> **Core Product Discovery & User Flow Design: Complete**
> Toàn bộ quá trình Khám phá sản phẩm cấp cao và Thiết kế luồng người dùng cốt lõi (cho cả 5 Phân hệ/Cluster) đã hoàn thành và được phê duyệt chính thức bởi Product Owner. Dự án đã sẵn sàng chuyển sang bước chuẩn bị tiếp theo.

---

## PHẦN VII: ĐỀ XUẤT BƯỚC TIẾP THEO

Chúng tôi đề xuất 3 bước tiếp theo có thể thực hiện, xếp hạng theo mức độ ưu tiên từ cao xuống thấp:

### 1. (ƯU TIÊN CAO NHẤT) Detailed Requirements / User Stories (Viết Yêu cầu & Tiêu chí nghiệm thu chi tiết)
*   *Nội dung:* Chuyển đổi các luồng người dùng và quy tắc nghiệp vụ đã chốt ở 5 Cluster thành các tài liệu đặc tả chức năng chi tiết, bao gồm: Viết User Stories, Quy tắc nghiệp vụ chi tiết (Business Rules), Tiêu chí nghiệm thu kiểm thử (Acceptance Criteria) và các Trường hợp biên (Edge Cases).
*   *Lý do chọn:* Đây là cầu nối trực tiếp tiếp theo để chuyển hóa các flow trải nghiệm thành tài liệu kỹ thuật có thể đo lường và kiểm thử được. Giúp kiến trúc sư kỹ thuật biết chính xác hệ thống cần phản ứng thế nào trong mọi trường hợp.

### 2. Domain Modeling (Mô hình hóa Miền nghiệp vụ kỹ thuật)
*   *Nội dung:* Xác định các Aggregate, Entities, Value Objects và Domain Events (ví dụ: sự kiện `WeddingDateChangedEvent` kích hoạt dịch chuyển task).
*   *Lý do:* Giúp cấu trúc mã nguồn (Codebase) sạch và đồng bộ với ngôn ngữ nghiệp vụ của sản phẩm (Ubiquitous Language) trước khi thiết kế Database.

### 3. Information Architecture & Screen Inventory Refinement (Tinh chỉnh cấu trúc màn hình)
*   *Nội dung:* Lập danh mục tất cả các màn hình, popup và trạng thái giao diện cần thiết cho MVP.
*   *Lý do:* Phù hợp khi cần dựng Wireframe giao diện, nhưng có thể song hành trong quá trình viết Requirements.

---

## PHẦN VIII: CÁC RỦI RO SẢN PHẨM & GIẢ ĐỊNH CẦN KIỂM CHỨNG (PRODUCT RISKS / OPEN ASSUMPTIONS)

Trước khi tiến hành xây dựng thực tế, 5 rủi ro và giả định xuyên suốt các cluster dưới đây cần được kiểm chứng (validation) bằng prototype hoặc phỏng vấn người dùng thực tế:

1.  **Tỷ lệ tương tác RSVP di động của Khách lớn tuổi:** Giả định rằng mọi đối tượng khách (bao gồm người lớn tuổi nhận thiệp từ bố mẹ) đều có thể dễ dàng thao tác bấm RSVP trên di động. Cần kiểm chứng bằng một bản Prototype RSVP giao diện tối giản để đo lường độ khó thao tác.
2.  **Mức độ chính xác của AI Timeline gợi ý:** Giả định AI/Template gợi ý timeline công việc có giá trị thực tiễn ngay lập tức. Nếu gợi ý quá nhiều việc không liên quan hoặc sai lệch văn hóa vùng miền đặc thù của gia đình, người dùng sẽ tắt tính năng kế hoạch. Cần kiểm chứng bộ quy tắc Task mặc định với 3-5 đám cưới thật.
3.  **Hành vi cập nhật dòng tiền (Cash Flow):** Giả định người dùng sẽ kiên nhẫn lập Lịch thanh toán (Payment Schedule) và ghi nhận từng Giao dịch (Payment) để kiểm soát tài chính. Nếu trải nghiệm nhập liệu quá phức tạp, họ sẽ quay lại dùng Excel.
4.  **Tác động đổi ngày cưới (Review Screen UX):** Khi ngày cưới dời đổi, giao diện duyệt lại hạn chót các Task tùy chỉnh (Nhóm B & C) có quá phức tạp khiến người dùng bối rối hay không?
5.  **An toàn thông tin của Bản in Proxy:** Việc xuất danh sách khách kiểm tra ẩn SĐT và ghi chú bảo mật cho bố mẹ có đáp ứng đủ nhu cầu duyệt khách của bố mẹ không (liệu bố mẹ có đòi hỏi phải xem SĐT để đối chiếu danh bạ hay không)?
