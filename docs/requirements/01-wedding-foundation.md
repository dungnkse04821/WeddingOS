# Đặc Tả Yêu Cầu Chi Tiết: REQ-01 — Wedding Foundation

Tài liệu này đặc tả chi tiết các yêu cầu nghiệp vụ phần mềm cho Phân hệ **REQ-01 — Wedding Foundation (Thiết lập Đám cưới)** của hệ thống WeddingOS.

---

## 1. Flow REQ-01.1 — Welcome & Authentication Entry

### Goal
Giúp người dùng tiếp cận ứng dụng, hiểu sơ bộ giá trị và thực hiện Đăng nhập/Đăng ký nhanh trước khi bắt đầu tạo không gian cưới.

### Actors
*   Người dùng mới (Cô dâu, Chú rể hoặc thành viên hỗ trợ chưa có tài khoản).

### Preconditions
*   Người dùng đã cài đặt và mở ứng dụng di động gốc WeddingOS trên thiết bị Android.
*   Thiết bị có kết nối mạng internet.

### Trigger
*   Người dùng khởi động ứng dụng WeddingOS lần đầu tiên hoặc sau khi đã đăng xuất.

### Main Flow
1.  Hệ thống hiển thị màn hình Chào mừng (**AND-ONB-01**) với các slide giới thiệu giá trị cốt lõi của ứng dụng (Kế hoạch thông minh, Quản lý tài chính và Danh sách khách mời).
2.  Người dùng bấm nút "Bắt đầu lên kế hoạch" (Start Planning).
3.  Hệ thống hiển thị Panel Đăng nhập nhanh.
4.  Người dùng chọn hình thức đăng nhập (Đăng nhập thông qua các phương thức xác thực nhanh được hệ thống tích hợp).
5.  Người dùng hoàn tất xác thực thông qua nhà cung cấp dịch vụ được chọn.
6.  Hệ thống kiểm tra trạng thái tài khoản:
    *   *Trường hợp tài khoản mới:* Chuyển sang bước Thiết lập thông tin cơ bản (**AND-ONB-02**).
    *   *Trường hợp tài khoản đã có đám cưới trước đó:* Chuyển thẳng về màn hình **AND-HOM-01: Home Dashboard** của đám cưới gần nhất.

### Alternate Flows
*   *Luồng đăng nhập thất bại:* Hệ thống hiển thị thông báo lỗi và giữ người dùng ở lại màn hình **AND-ONB-01** để thử lại.

### Functional Requirements
*   **WED-FR-001:** Hệ thống **BẮT BUỘC** yêu cầu người dùng xác thực tài khoản (Authentication) thành công trước khi bắt đầu luồng Onboarding thiết lập không gian đám cưới. *(Screen: AND-ONB-01)*
*   **WED-FR-002:** Hệ thống **KHÔNG ĐƯỢC PHÉP** cung cấp Chế độ khách (Guest Mode - sử dụng không cần đăng nhập) cho cặp đôi/ban tổ chức trong MVP. *(Screen: AND-ONB-01)*
*   **WED-FR-003:** Giao diện đăng nhập trên Android **PHẢI** hỗ trợ các phương thức xác thực nhanh di động (ví dụ: xác thực bên thứ ba hoặc tài khoản email) tích hợp sẵn trên thiết bị. *(Screen: AND-ONB-01)*

### Business Rules
*   **WED-BR-001:** Mỗi tài khoản xác thực thành công là một định danh duy nhất (`UserId`) trong hệ thống và có thể sở hữu hoặc tham gia vào một hoặc nhiều Đám cưới (`Wedding`) khác nhau.

### Acceptance Criteria
*   **WED-AC-001:**
    *   *Given:* Người dùng chưa đăng nhập hệ thống và đang ở màn hình **AND-ONB-01**.
    *   *When:* Người dùng cố gắng bỏ qua hoặc bấm nút quay lại thiết bị để thoát màn hình đăng nhập.
    *   *Then:* Hệ thống không cho phép truy cập vào bất kỳ chức năng lập kế hoạch nào và giữ nguyên màn hình Đăng nhập.
*   **WED-AC-002:**
    *   *Given:* Người dùng đã xác thực thành công bằng tài khoản được liên kết.
    *   *When:* Đây là lần đầu tiên tài khoản này truy cập vào hệ thống.
    *   *Then:* Hệ thống tự động chuyển tiếp người dùng sang màn hình **AND-ONB-02 (Onboarding - Basics)**.

### Error / Recovery Behavior
*   **WED-ERR-001:** Nếu xác thực thất bại do lỗi mạng hoặc lỗi từ nhà cung cấp dịch vụ, hệ thống hiển thị thông báo lỗi mạng/xác thực chung cho người dùng. Người dùng có thể nhấn nút "Thử lại" ngay trên giao diện mà không bị mất trạng thái thông tin đã điền trước đó.

### Screen References
*   [AND-ONB-01](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/information-architecture.md#5-danh-mục-màn-hình-đầy-đủ-complete-mvp-screen-inventory)

### Domain References
*   `Wedding`
*   `WeddingMember`

### Traceability
*   *Kế thừa quyết định:* Cluster 1 - Authentication trước, chọn phương án A.

---

## 2. Flow REQ-01.2 — Create Wedding & Switcher

### Goal
Cho phép người dùng tạo một Đám cưới (`Wedding`) mới độc lập và hỗ trợ chuyển đổi linh hoạt giữa các đám cưới mà họ có quyền truy cập.

### Actors
*   Người dùng đã đăng nhập thành công.

### Preconditions
*   Người dùng đã được xác thực danh tính hệ thống.

### Trigger
*   Người dùng hoàn tất bước Đăng nhập lần đầu (tự động kích hoạt luồng Tạo đám cưới).
*   Hoặc người dùng bấm nút "Tạo đám cưới mới" trong Bottom Sheet chuyển đổi trên màn hình Dashboard (**AND-HOM-01**).

### Main Flow
1.  Hệ thống khởi chạy phiên làm việc (Session) tạo đám cưới mới.
2.  Người dùng thực hiện các bước Onboarding từ **AND-ONB-02** tới **AND-ONB-05**.
3.  Tại bước cuối, hệ thống sinh thực thể Đám cưới mới (`Wedding`) và tự động gán tài khoản hiện tại làm Thành viên quản trị (`WeddingMember` với role là `Owner`).
4.  Hệ thống lưu trữ cấu hình đám cưới và đặt đám cưới này làm Không gian làm việc hiện tại (`Current Wedding Context`).
5.  Chuyển người dùng về Dashboard chính (**AND-HOM-01**).

### Alternate Flows (Chuyển đổi đám cưới)
1.  Tại màn hình Dashboard (**AND-HOM-01**), người dùng bấm vào Tên cặp đôi ở thanh tiêu đề Top Bar.
2.  Hệ thống mở Bottom Sheet hiển thị danh sách các Đám cưới mà người dùng đang tham gia.
3.  Người dùng bấm chọn một Đám cưới khác.
4.  Hệ thống lập tức tải lại dữ liệu của Đám cưới được chọn và cập nhật giao diện Dashboard mới.

### Functional Requirements
*   **WED-FR-004:** Hệ thống **PHẢI** hỗ trợ một người dùng tham gia nhiều không gian cưới (`Wedding Workspace`) khác nhau bằng cùng một tài khoản. *(Screen: AND-HOM-01)*
*   **WED-FR-005:** Hành động tạo mới hoặc sửa đổi dữ liệu trong một Đám cưới **KHÔNG ĐƯỢC PHÉP** ảnh hưởng đến cấu hình hoặc dữ liệu của các đám cưới khác mà tài khoản đó đang tham gia. *(Domain Concept: Wedding)*
*   **WED-FR-006:** Hệ thống **PHẢI** cung cấp lối tắt chuyển đổi Đám cưới nhanh (Wedding Switcher) thông qua Bottom Sheet từ thanh tiêu đề Top Bar. *(Screen: AND-HOM-01)*

### Business Rules
*   **WED-BR-002:** Khi một Đám cưới mới được tạo ra, tài khoản thực hiện tạo sẽ tự động được hệ thống gán vai trò `Owner` (Chủ sở hữu) với toàn quyền cấu hình đám cưới.

### Acceptance Criteria
*   **WED-AC-003:**
    *   *Given:* Người dùng đã sở hữu Đám cưới A và vừa bấm chọn "Tạo đám cưới mới".
    *   *When:* Người dùng tiến hành thiết lập đám cưới B mới.
    *   *Then:* Toàn bộ danh sách công việc, ngân sách, khách mời của Đám cưới A được giữ nguyên hoàn toàn và không bị ghi đè.

### Error / Recovery Behavior
*   **WED-ERR-002:** Nếu luồng tạo đám cưới bị gián đoạn giữa chừng (ví dụ: tắt ứng dụng ở bước 3), hệ thống lưu trạng thái bản nháp của onboarding hiện tại. Khi người dùng mở lại app, hệ thống đề xuất người dùng tiếp tục thiết lập onboarding đang dang dở hoặc tạo mới từ đầu mà không tạo trùng lặp Wedding ID.

### Screen References
*   [AND-HOM-01](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/information-architecture.md#5-danh-mục-màn-hình-đầy-đủ-complete-mvp-screen-inventory)
*   [AND-ONB-02](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/information-architecture.md#5-danh-mục-màn-hình-đầy-đủ-complete-mvp-screen-inventory)

### Domain References
*   `Wedding`
*   `WeddingMember`

---

## 3. Flow REQ-01.3 — Wedding Basics

### Goal
Thu thập thông tin định danh cơ bản nhất cho đám cưới (Tên cô dâu và chú rể) để cá nhân hóa không gian làm việc.

### Actors
*   Người dùng đang trong luồng Onboarding.

### Preconditions
*   Người dùng đã đăng nhập thành công.

### Trigger
*   Người dùng chuyển tiếp từ màn hình Authentication hoặc chọn tạo đám cưới mới.

### Main Flow
1.  Hệ thống hiển thị màn hình **AND-ONB-02: Onboarding - Basics**.
2.  Người dùng nhập tên của Cô dâu (Bride Name) và tên của Chú rể (Groom Name).
3.  Người dùng chọn vai trò của mình trong đám cưới (Cô dâu, Chú rể hoặc người hỗ trợ).
4.  Người dùng bấm nút "Tiếp tục" (Next).
5.  Hệ thống lưu thông tin cơ bản vào bộ nhớ đệm và chuyển sang màn hình **AND-ONB-03**.

### Functional Requirements
*   **WED-FR-007:** Hệ thống **BẮT BUỘC** yêu cầu nhập Tên cô dâu và Tên chú rể tại bước này. Không được phép để trống. *(Screen: AND-ONB-02)*
*   **WED-FR-008:** Trường chọn Vai trò của người dùng hiện tại **BẮT BUỘC** phải có đầu vào để hệ thống ghi nhận cấu hình member ban đầu. *(Screen: AND-ONB-02)*

### Validation Rules
*   **WED-VAL-002:** Tên cô dâu và tên chú rể chỉ được phép chứa các ký tự chữ cái (không chứa số, ký tự đặc biệt) và có độ dài tối đa là 50 ký tự.

### Screen References
*   [AND-ONB-02](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/information-architecture.md#5-danh-mục-màn-hình-đầy-đủ-complete-mvp-screen-inventory)

### Domain References
*   `Wedding`
*   `WeddingMember`

---

## 4. Flow REQ-01.4 — Wedding Date & Expected Month

### Goal
Thu thập thời gian tổ chức đám cưới của cặp đôi. Hỗ trợ đầy đủ cả trường hợp đã chốt ngày cưới chính xác và trường hợp mới chỉ có tháng dự kiến.

### Actors
*   Người dùng đang ở bước Onboarding thiết lập thời gian.

### Preconditions
*   Người dùng đã hoàn thành bước Basics (**AND-ONB-02**).

### Trigger
*   Hệ thống chuyển người dùng sang màn hình **AND-ONB-03**.

### Main Flow
1.  Hệ thống hiển thị màn hình **AND-ONB-03: Onboarding - Context**.
2.  Hệ thống hiển thị câu hỏi về thời gian đám cưới kèm hai tùy chọn chuyển đổi (Switch):
    *   **Tùy chọn A: Đã chốt ngày chính xác** (Exact Date).
    *   **Tùy chọn B: Chỉ biết tháng dự kiến** (Expected Month).
3.  *Nếu chọn Tùy chọn A:* Người dùng chọn ngày dương lịch cụ thể thông qua bộ chọn ngày (Date Picker).
4.  *Nếu chọn Tùy chọn B:* Người dùng chọn tháng và năm dự kiến (ví dụ: `Tháng 12 Năm 2026`).
5.  Người dùng bấm nút "Tiếp tục".
6.  Hệ thống lưu thông tin thời gian tương ứng và chuyển tiếp sang màn hình chọn Phong tục (**AND-ONB-03**).

### Functional Requirements
*   **WED-FR-009:** Hệ thống **PHẢI** cho phép người dùng hoàn tất onboarding ngay cả khi chưa xác định ngày cưới chính xác bằng cách cung cấp tùy chọn nhập Tháng dự kiến (`Expected Wedding Month`). *(Screen: AND-ONB-03)*
*   **WED-FR-010:** Khi chỉ biết tháng dự kiến, hệ thống **BẮT BUỘC** phải đặt giá trị ngày cưới chính xác thành chưa rõ (`Exact Wedding Date = UNKNOWN`). **KHÔNG ĐƯỢC PHÉP** sử dụng bất kỳ ngày mặc định ẩn nào (ví dụ: ngày 15 giữa tháng) làm mốc neo giả lập. *(Domain Concept: Wedding)*
*   **WED-FR-011:** Khi ngày cưới chính xác ở trạng thái `UNKNOWN`, hệ thống **PHẢI** hiển thị toàn bộ hạn chót (due dates) của công việc trên giao diện dưới dạng tương đối (ví dụ: *"khoảng 1 tháng trước lễ cưới"*). *(Screen: AND-HOM-01, AND-PLA-01)*

### Business Rules
*   **WED-BR-003:** Trạng thái `UNKNOWN` của ngày cưới chính xác là một trạng thái hợp lệ của miền nghiệp vụ Wedding. Mọi tính toán hạn chót tương đối sẽ được chuyển hóa thành ngày tuyệt đối chỉ khi người dùng cập nhật ngày cưới chính xác sau này.

### Acceptance Criteria
*   **WED-AC-004:**
    *   *Given:* Người dùng chọn nhập thời gian dự kiến là `Tháng 12/2026` trong onboarding.
    *   *When:* Hệ thống tạo đám cưới và sinh các công việc gợi ý.
    *   *Then:* Task "Đặt nhà hàng (T-180)" hiển thị hạn chót là *"Khoảng 6 tháng trước lễ cưới"*. Hệ thống không được hiển thị ngày cụ thể là `15/06/2026` hoặc bất kỳ ngày nào khác.

### Validation Rules
*   **WED-VAL-003:** Ngày cưới chính xác được nhập phải là một ngày hợp lệ trên lịch (Valid calendar date). Tháng dự kiến phải là định dạng tháng/năm hợp lệ.

### Screen References
*   [AND-ONB-03](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/information-architecture.md#5-danh-mục-màn-hình-đầy-đủ-complete-mvp-screen-inventory)

### Domain References
*   `Wedding`
*   `Relative Deadline Rule`

### Traceability
*   *Kế thừa quyết định:* Cluster 2A - Khi từ tháng dự kiến chuyển sang ngày cưới chính xác, chọn phương án C.

---

## 5. Flow REQ-01.5 — Cultural Context (Vùng Miền)

### Goal
Xác định Phong tục tổ chức đám cưới của cặp đôi để làm cơ sở gợi ý các nghi lễ sự kiện và danh sách công việc phù hợp.

### Actors
*   Người dùng đang trong luồng Onboarding.

### Preconditions
*   Người dùng đang ở màn hình **AND-ONB-03**.

### Trigger
*   Hệ thống yêu cầu chọn phong tục tổ chức sau khi thiết lập thời gian.

### Main Flow
1.  Tại màn hình **AND-ONB-03**, hệ thống hiển thị danh sách phong tục tổ chức chính chủ đạo:
    *   Miền Bắc
    *   Miền Trung
    *   Miền Nam
    *   Chưa rõ / Tùy chỉnh sau
2.  Người dùng tích chọn 1 trong 4 phương án.
3.  Người dùng bấm nút "Tiếp tục".
4.  Hệ thống lưu cấu hình vùng miền (`Cultural Context`) và chuyển tiếp sang màn hình Lựa chọn Sự kiện (**AND-ONB-04**).

### Functional Requirements
*   **WED-FR-012:** Hệ thống **PHẢI** cho phép người dùng chọn phương án "Chưa rõ / Tùy chỉnh sau" cho Phong tục tổ chức để tiếp tục onboarding mà không bắt buộc chọn 3 miền chính. *(Screen: AND-ONB-03)*
*   **WED-FR-013:** Hệ thống **KHÔNG ĐƯỢC PHÉP** đồng nhất Phong tục tổ chức (Cultural Context) với địa điểm tổ chức đám cưới (Physical Location). *(Domain Concept: Cultural Context)*
*   **WED-FR-014:** Lựa chọn phong tục tổ chức **PHẢI** được sử dụng làm tham số đầu vào để hệ thống gợi ý các mẫu sự kiện và công việc tương ứng ở các bước sau. *(Domain Concept: Cultural Context)*

### Acceptance Criteria
*   **WED-AC-005:**
    *   *Given:* Người dùng chọn phong tục tổ chức là "Miền Bắc".
    *   *When:* Chuyển sang màn hình chọn sự kiện (**AND-ONB-04**).
    *   *Then:* Hệ thống hiển thị danh sách các nghi lễ gợi ý đặc thù miền Bắc (ví dụ: Lễ Dạm Ngõ, Lễ Ăn Hỏi...) được chọn sẵn mặc định.

### Screen References
*   [AND-ONB-03](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/information-architecture.md#5-danh-mục-màn-hình-đầy-đủ-complete-mvp-screen-inventory)

### Domain References
*   `Wedding`
*   `Cultural Context`

### Traceability
*   *Kế thừa quyết định:* Cluster 1 - Tách biệt phong tục & địa lý.

---

## 6. Flow REQ-01.6 — Wedding Event Selection

### Goal
Cho phép người dùng lựa chọn các sự kiện nghi lễ con (Ăn hỏi, Đón dâu, Tiệc cưới...) sẽ diễn ra trong đám cưới của mình để cấu hình timeline ban đầu, bảo đảm có ít nhất một sự kiện chính.

### Actors
*   Người dùng đang trong luồng Onboarding.

### Preconditions
*   Người dùng đã chọn phong tục vùng miền ở bước trước (**AND-ONB-03**).

### Trigger
*   Hệ thống chuyển người dùng sang màn hình **AND-ONB-04: Onboarding - Events**.

### Main Flow
1.  Hệ thống hiển thị danh sách các sự kiện gợi ý dựa trên Phong tục vùng miền đã chọn.
2.  Các sự kiện đề xuất mặc định được tích chọn sẵn.
3.  Người dùng có thể:
    *   Tích chọn thêm các sự kiện mong muốn (ví dụ: Lễ Dạm Ngõ, Lễ Hằng Thuận...).
    *   Bỏ tích chọn bất kỳ sự kiện gợi ý nào trong danh sách.
4.  Người dùng bấm nút "Tiếp tục".
5.  *Nếu không có sự kiện nào được chọn:* Hệ thống không cho qua, hiển thị hướng dẫn nghiệp vụ yêu cầu chọn hoặc tạo tối thiểu một sự kiện chính.
6.  Hệ thống lưu cấu hình sự kiện cưới được chọn và chuyển sang bước nhập Ngân sách (**AND-ONB-05**).

### Functional Requirements
*   **WED-FR-015:** Hệ thống **PHẢI** hiển thị danh sách các sự kiện đề xuất tương ứng với Phong tục cưới đã chọn để người dùng dễ chọn lựa. *(Screen: AND-ONB-04)*
*   **WED-FR-016:** Người dùng **PHẢI** chọn hoặc tự tạo ít nhất một sự kiện cưới làm sự kiện chính (Main Event/Planning Anchor) trước khi hoàn thành thiết lập. Không được phép bỏ chọn toàn bộ và không tự tạo Event giả trong background. *(Screen: AND-ONB-04)*
*   **WED-FR-017:** MVP **PHẢI** cho phép người dùng chỉnh sửa danh sách sự kiện (Thêm mới sự kiện tùy chỉnh, đổi ngày hoặc xóa sự kiện) bất cứ lúc nào trong trang chi tiết sau khi hoàn thành onboarding. *(Domain Concept: WeddingEvent)*

### Business Rules
*   **WED-BR-004:** Đám cưới bắt buộc phải có ít nhất một Sự kiện chính (Main Wedding Event) để hoàn tất Thiết lập Đám cưới ban đầu (Initial Wedding Setup). Sự kiện chính này không bắt buộc là một nghi lễ cụ thể mà có thể là Custom Event do người dùng tự tạo.

### Acceptance Criteria
*   **WED-AC-006:**
    *   *Given:* Người dùng đã tích chọn ít nhất một Sự kiện chính (ví dụ: Lễ cưới hoặc một Sự kiện tùy chỉnh).
    *   *When:* Người dùng bấm "Tiếp tục" tại màn hình **AND-ONB-04**.
    *   *Then:* Hệ thống lưu cấu hình và cho phép chuyển tiếp sang màn hình Sinh kế hoạch.
*   **WED-AC-010:**
    *   *Given:* Người dùng bỏ tích toàn bộ các sự kiện trên màn hình **AND-ONB-04**.
    *   *When:* Người dùng bấm nút "Tiếp tục" để hoàn tất thiết lập sự kiện.
    *   *Then:* Hệ thống chặn lại, không cho phép hoàn thành và hiển thị thông báo: *"Vui lòng chọn hoặc tạo ít nhất một sự kiện chính để WeddingOS xây dựng kế hoạch."*
*   **WED-AC-011:**
    *   *Given:* Sự kiện chính được chọn (Main Event) chỉ thiết lập Tháng dự kiến (Expected Month).
    *   *When:* Hệ thống khởi chạy luồng Sinh kế hoạch ban đầu (Plan Generation).
    *   *Then:* Hệ thống cho phép hoàn thành luồng và tuyệt đối không tạo ngày chốt cứng giả (Exact Wedding Date) trong DB.

### Screen References
*   [AND-ONB-04](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/information-architecture.md#5-danh-mục-màn-hình-đầy-đủ-complete-mvp-screen-inventory)

### Domain References
*   `WeddingEvent`

---

## 7. Flow REQ-01.7 — Budget & Guest Estimate (Optional Setup)

### Goal
Thu thập dự báo tài chính và số khách mời ban đầu của cặp đôi. Luồng này hoàn toàn là tùy chọn (Optional) để giảm thiểu friction khi onboarding.

### Actors
*   Người dùng đang trong luồng Onboarding.

### Preconditions
*   Người dùng đang ở màn hình **AND-ONB-05: Onboarding - Estimates**.

### Trigger
*   Hệ thống chuyển người dùng sang bước nhập ước tính.

### Main Flow
1.  Hệ thống hiển thị màn hình **AND-ONB-05** gồm hai ô nhập liệu:
    *   Hạn mức ngân sách dự kiến (đơn vị: VNĐ).
    *   Số lượng khách mời ước tính (đơn vị: Người).
2.  Người dùng có hai lựa chọn hành động:
    *   *Lựa chọn A (Nhập liệu):* Người dùng điền số tiền và số khách $\rightarrow$ Bấm nút "Tạo kế hoạch".
    *   *Lựa chọn B (Bỏ qua - Skip):* Người dùng không nhập gì $\rightarrow$ Bấm nút **"Bỏ qua" (Skip)**.
3.  Hệ thống tiếp nhận thông tin và chuyển sang màn hình Sinh kế hoạch mẫu (**AND-ONB-06**).

### Alternate Flows (Khi người dùng chọn Skip)
1.  Nếu người dùng bấm **Skip**, hệ thống ghi nhận trạng thái chưa thiết lập dữ liệu tài chính và khách mời:
    *   `Target Budget = Not Configured`
    *   `Guest Estimate = Unknown`
2.  Hệ thống tuyệt đối **KHÔNG ĐƯỢC PHÉP** tự động sinh bất kỳ số liệu giả lập nào (như 200M VNĐ hay 200 khách) để lấp chỗ trống.
3.  Khi chuyển về Dashboard chính (**AND-HOM-01**), các widget Ngân sách và Khách mời hiển thị thông báo trạng thái trống kèm nút CTA kêu gọi: `"Thiết lập hạn mức ngân sách ngay"` hoặc `"Nhập ước tính số khách mời đầu tiên"`.

### Functional Requirements
*   **WED-FR-018:** Hệ thống **PHẢI** cung cấp nút hành động "Bỏ qua" (Skip) nổi bật trên giao diện tại bước nhập ước tính này. *(Screen: AND-ONB-05)*
*   **WED-FR-019:** Nếu người dùng chọn bỏ qua, hệ thống **BẮT BUỘC** phải lưu trạng thái rỗng của Ngân sách/Khách mời. Nghiêm cấm sử dụng các con số mặc định (200M/200 khách) để giả lập dữ liệu. *(Domain Concept: Wedding)*
*   **WED-FR-020:** Hệ thống **PHẢI** hiển thị nút hành động kêu gọi thiết lập dữ liệu (CTA) phù hợp trên các Widget tương ứng của Dashboard chính sau khi onboarding nếu người dùng đã skip. *(Screen: AND-HOM-01)*

### Acceptance Criteria
*   **WED-AC-007:**
    *   *Given:* Người dùng bấm "Bỏ qua" ở màn hình **AND-ONB-05**.
    *   *When:* Onboarding hoàn thành và Dashboard chính (**AND-HOM-01**) được tải.
    *   *Then:* Widget Ngân sách hiển thị trạng thái chưa thiết lập kèm nút bấm kêu gọi nhập hạn mức. Hệ thống không hiển thị biểu đồ ngân sách 200 triệu đồng.

### Validation Rules
*   **WED-VAL-004:** Hạn mức ngân sách và Số lượng khách mời nếu nhập phải là số nguyên dương lớn hơn 0.

### Screen References
*   [AND-ONB-05](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/information-architecture.md#5-danh-mục-màn-hình-đầy-đủ-complete-mvp-screen-inventory)
*   [AND-HOM-01](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/information-architecture.md#5-danh-mục-màn-hình-đầy-đủ-complete-mvp-screen-inventory)

### Domain References
*   `Wedding`
*   `Budget`

### Traceability
*   *Kế thừa quyết định:* Cluster 1 - Không giả lập dữ liệu, Budget & Guest estimate khi Skip.

---

## 8. Flow REQ-01.8 — Generate Initial Plan (First Value Event)

### Goal
Tự động khởi tạo danh sách các công việc mẫu, thời hạn tương đối và các nghi lễ đề xuất phù hợp với phong tục cưới của người dùng. Đây là sự kiện đem lại Giá trị Đầu tiên (First Value Event) cho người dùng.

### Actors
*   Hệ thống WeddingOS (chạy tự động).

### Preconditions
*   Người dùng đã hoàn tất toàn bộ các bước nhập liệu cơ bản trong onboarding.

### Trigger
*   Người dùng bấm nút "Tạo kế hoạch" hoặc "Bỏ qua" tại màn hình **AND-ONB-05**.

### Main Flow
1.  Hệ thống hiển thị màn hình chờ tải **AND-ONB-06: Plan Generation** kèm thanh tiến trình sinh dữ liệu.
2.  Hệ thống đọc các tham số đầu vào đã thu thập:
    *   Expected Month hoặc Exact Date.
    *   Cultural Context (Bắc, Trung, Nam hoặc Chưa rõ).
    *   Danh sách WeddingEvents được lựa chọn.
3.  Hệ thống truy vấn cơ sở dữ liệu mẫu (Templates) để lấy:
    *   Danh sách các công việc (`Suggested Tasks`) mặc định cho phong tục và các sự kiện cưới được chọn, kèm quy tắc tính hạn chót tương đối (`Relative Deadline Rule`).
4.  Hệ thống khởi tạo các thực thể `Task` trong không gian cưới mới tạo.
5.  Hệ thống tính toán hạn chót tương đối cho từng Task (dưới dạng mốc ngày cụ thể nếu đã có Exact Date, hoặc dạng chuỗi văn bản tương đối nếu chỉ có Expected Month).
6.  Hệ thống **KHÔNG ĐƯỢC PHÉP** tự động khởi tạo bất kỳ bản ghi Khoản mục chi tiêu (`BudgetItem`) hay Giao dịch tài chính nào trong luồng sinh tự động này để tránh tạo dữ liệu giả.
7.  Khi hoàn thành, hệ thống tự động lưu trữ và ghi nhận sự kiện phân tích: **First Value Event - Initial Wedding Plan Generated**.
8.  Chuyển người dùng sang màn hình Dashboard chính (**AND-HOM-01**).

### Functional Requirements
*   **WED-FR-021:** Hệ thống **PHẢI** tự động sinh các công việc mẫu phù hợp ngay khi người dùng hoàn thành onboarding mà không bắt họ phải tự nhập tay từng dòng từ đầu. Hệ thống **KHÔNG ĐƯỢC PHÉP** tự động tạo bất kỳ thực thể `BudgetItem` nào trong cơ sở dữ liệu khi sinh kế hoạch ban đầu. *(Domain Concept: Task, BudgetItem)*
*   **WED-FR-022:** Toàn bộ các công việc do hệ thống khởi tạo **PHẢI** được phân loại rõ ràng là Nguồn hệ thống gợi ý (`Task Source = System`) để phân biệt với các công việc do người dùng tự tạo sau này. *(Domain Concept: Task)*

### Business Rules
*   **WED-BR-005:** Tiến độ thực tế ban đầu của đám cưới bắt buộc phải được đặt là 0% công việc hoàn thành. Bản thân quá trình thực hiện Onboarding thiết lập đám cưới không được tính là một công việc đã hoàn thành để đảm bảo tính thực tế của tiến độ kế hoạch.

### Acceptance Criteria
*   **WED-AC-008:**
    *   *Given:* Đám cưới được khởi tạo thành công ở trạng thái ngày cưới chính xác là `UNKNOWN`.
    *   *When:* Hệ thống sinh các Suggested Tasks.
    *   *Then:* Các Task hiển thị hạn chót tương đối dưới dạng chuỗi chữ (ví dụ: *"khoảng 30 ngày trước lễ cưới"*). Hệ thống không được hiển thị ngày dương lịch cụ thể và không có bản ghi Khoản chi tiêu (`BudgetItem`) nào được tạo ra trong DB.

### Screen References
*   [AND-ONB-06](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/information-architecture.md#5-danh-mục-màn-hình-đầy-đủ-complete-mvp-screen-inventory)
*   [AND-HOM-01](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/information-architecture.md#5-danh-mục-màn-hình-đầy-đủ-complete-mvp-screen-inventory)

### Domain References
*   `Wedding`
*   `Task`

### Traceability
*   *Kế thừa quyết định:* Cluster 1 - First Value, Tiến độ thực tế.

---

## 9. Flow REQ-01.9 — First Dashboard & Switching Context

### Goal
Cung cấp giao diện trung tâm trực quan để cặp đôi nắm bắt toàn bộ trạng thái đám cưới, xem tiến độ lập kế hoạch thực tế từ ban đầu và phát cảnh báo thiếu dữ liệu.

### Actors
*   Người dùng đã hoàn tất Onboarding.

### Preconditions
*   Hệ thống đã hoàn tất sự kiện **Initial Wedding Plan Generated**.

### Trigger
*   Người dùng truy cập ứng dụng hoặc hoàn tất Onboarding.

### Main Flow
1.  Hệ thống hiển thị màn hình **AND-HOM-01: Home Dashboard**.
2.  Hệ thống tính toán và hiển thị:
    *   Tên cặp đôi ở tiêu đề Top Bar (ví dụ: *"Vy & Dung's Wedding"*).
    *   Countdown ngày cưới còn lại (ví dụ: *"Còn 120 ngày"* hoặc *"Dự kiến: Tháng 12/2026"*).
    *   Widget Kế hoạch hiển thị tiến độ thực tế là **0%** công việc hoàn thành.
    *   Các Widget Tài chính, Khách mời hiển thị trạng thái tương ứng:
        *   *Nếu đã nhập:* Hiển thị chỉ số dự báo và hạn mức.
        *   *Nếu đã skip:* Hiển thị nhãn trống kèm nút CTA dẫn đến form nhập liệu tương ứng.
3.  Hệ thống hiển thị **Attention Center** chứa thông báo kêu gọi hoàn thiện thông tin:
    *   *"Bạn chưa cấu hình ngày cưới chính xác. Hãy chốt ngày để áp dụng lịch làm việc cụ thể."*
    *   *"Hạn mức ngân sách chưa được thiết lập."*
    *   *"Chưa có thông tin dự kiến số lượng khách mời."*
4.  Người dùng bấm vào một cảnh báo/CTA $\rightarrow$ Hệ thống điều hướng trực tiếp đến màn hình cài đặt tương ứng để cập nhật.

### Functional Requirements
*   **WED-FR-023:** Màn hình Dashboard chính **PHẢI** hiển thị đúng thông tin của Đám cưới hiện tại đang được chọn (Current Wedding Context). *(Screen: AND-HOM-01)*
*   **WED-FR-024:** Tiến độ kế hoạch ban đầu hiển thị trên giao diện **PHẢI** là `0%` và chỉ tăng lên khi người dùng thực hiện hành động lập kế hoạch có ý nghĩa đầu tiên (sự kiện kích hoạt **Activation Event**). *(Screen: AND-HOM-01)*
*   **WED-FR-025:** Màn hình Dashboard **KHÔNG ĐƯỢC PHÉP** hiển thị thông tin giả lập (fake progress) hay biểu đồ ảo nếu người dùng chưa nhập liệu thực tế. *(Screen: AND-HOM-01)*

### Business Rules
*   **WED-BR-006:** Hệ thống ghi nhận trạng thái **Activation Event** chỉ khi người dùng thực hiện hành động lập kế hoạch có ý nghĩa đầu tiên (First Meaningful Planning Action - ví dụ: thay đổi trạng thái task, chỉnh sửa task hoặc tạo task mới).

### Acceptance Criteria
*   **WED-AC-009:**
    *   *Given:* Đám cưới vừa được sinh ra và chưa có bất kỳ chỉnh sửa nào từ người dùng.
    *   *When:* Người dùng mở Dashboard (**AND-HOM-01**).
    *   *Then:* Chỉ số tiến độ lập kế hoạch hiển thị là `0%`.

### Screen References
*   [AND-HOM-01](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/information-architecture.md#5-danh-mục-màn-hình-đầy-đủ-complete-mvp-screen-inventory)

### Domain References
*   `Wedding`
*   `Task`

### Traceability
*   *Kế thừa quyết định:* Cluster 1 - First Value & Activation, Tiến độ thực tế.

---

## 10. Bảng Truy Xuất Nguồn Gốc (Traceability Matrix)

| Mã Yêu Cầu (Requirement ID) | Phân hệ / Luồng (Flow) | Mã Màn Hình (Screen ID) | Khái Niệm Miền (Domain Concept) | Quyết Định Thiết Kế (Discovery Decision) | Mã Tiêu Chí Nghiệm Thu (Acceptance Criteria) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **WED-FR-001** | REQ-01.1 | AND-ONB-01 | `WeddingMember` | Đăng nhập bắt buộc trước onboarding | WED-AC-001 |
| **WED-FR-002** | REQ-01.1 | AND-ONB-01 | `Wedding` | Không cung cấp Guest Mode cho cặp đôi | WED-AC-001 |
| **WED-FR-003** | REQ-01.1 | AND-ONB-01 | - | Tối giản hình thức đăng nhập di động | WED-AC-002 |
| **WED-FR-004** | REQ-01.2 | AND-HOM-01 | `Wedding` | Một user có thể tham gia nhiều đám cưới | WED-AC-003 |
| **WED-FR-005** | REQ-01.2 | - | `Wedding` | Không gian cưới độc lập không ghi đè | WED-AC-003 |
| **WED-FR-006** | REQ-01.2 | AND-HOM-01 | - | Chuyển đổi đám cưới nhanh bằng Switcher | - |
| **WED-FR-007** | REQ-01.3 | AND-ONB-02 | `Wedding` | Tên cô dâu và chú rể bắt buộc | - |
| **WED-FR-008** | REQ-01.3 | AND-ONB-02 | `WeddingMember` | Phải xác nhận vai trò trong đám cưới | - |
| **WED-FR-009** | REQ-01.4 | AND-ONB-03 | `Wedding` | Cho phép skip nếu chưa có ngày cưới | WED-AC-004 |
| **WED-FR-010** | REQ-01.4 | - | `Wedding` | Không materialize ngày 15 giả lập ẩn | WED-AC-004 |
| **WED-FR-011** | REQ-01.4 | AND-HOM-01 | `Relative Deadline Rule` | Hiển thị chữ hạn tương đối khi ngày UNKNOWN | WED-AC-004 |
| **WED-FR-012** | REQ-01.5 | AND-ONB-03 | `Cultural Context` | Cho phép chưa chốt phong tục tổ chức | - |
| **WED-FR-013** | REQ-01.5 | - | `Cultural Context` | Tách biệt phong tục và địa điểm địa lý | - |
| **WED-FR-014** | REQ-01.5 | - | `Cultural Context` | Phong tục dùng làm gợi ý mẫu kế hoạch | WED-AC-005 |
| **WED-FR-015** | REQ-01.6 | AND-ONB-04 | `WeddingEvent` | Hiển thị nghi lễ gợi ý theo phong tục | - |
| **WED-FR-016** | REQ-01.6 | AND-ONB-04 | `WeddingEvent` | Đám cưới có ít nhất một sự kiện chính | WED-AC-006, WED-AC-010 |
| **WED-FR-017** | REQ-01.6 | - | `WeddingEvent` | Sửa đổi được sự kiện sau onboarding | - |
| **WED-FR-018** | REQ-01.7 | AND-ONB-05 | `Wedding` | Ngân sách/Khách mời là tùy chọn | WED-AC-007 |
| **WED-FR-019** | REQ-01.7 | - | `Budget` | Skip không được tự điền 200M/200 khách | WED-AC-007 |
| **WED-FR-020** | REQ-01.7 | AND-HOM-01 | `Budget` | Widget hiện CTA hoàn thiện nếu skip | WED-AC-007 |
| **WED-FR-021** | REQ-01.8 | AND-ONB-06 | `Task`, `BudgetItem` | Tự động sinh công việc, cấm tạo BudgetItem | WED-AC-008, WED-AC-011 |
| **WED-FR-022** | REQ-01.8 | - | `Task` | Phân loại nguồn gợi ý của hệ thống | WED-AC-008 |
| **WED-FR-023** | REQ-01.9 | AND-HOM-01 | `Wedding` | Dashboard hiển thị đúng wedding context | - |
| **WED-FR-024** | REQ-01.9 | AND-HOM-01 | `Task` | Tiến độ khởi đầu kế hoạch bằng 0% | WED-AC-009 |
| **WED-FR-025** | REQ-01.9 | AND-HOM-01 | - | Không hiển thị số liệu ảo trên dashboard | WED-AC-009 |
