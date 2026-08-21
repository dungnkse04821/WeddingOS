# Đặc Tả Yêu Cầu Chi Tiết: REQ-03 — Finance

Tài liệu này đặc tả chi tiết các yêu cầu nghiệp vụ phần mềm cho Phân hệ **REQ-03 — Finance (Quản lý Tài chính)** của hệ thống WeddingOS.

---

## 1. Mô Hình Tư Duy Tài Chính (Finance Mental Model)

*   **Không phải phần mềm Kế toán:** Hệ thống được thiết kế tối giản, tập trung vào việc quản lý ngân sách và dòng tiền của cặp đôi thay vì xây dựng hệ thống kế toán kép (double-entry ledger).
*   **Phân định các khái niệm chi phí cốt lõi:**
    *   `Target Budget` (Ngân sách mục tiêu): Hạn mức tài chính mong muốn của đám cưới. Là tùy chọn (optional).
    *   `Estimated Cost` (Dự toán): Số tiền dự kiến chi ban đầu cho khoản mục.
    *   `Confirmed Cost` (Đã chốt): Số tiền cam kết thực tế sẽ phải thanh toán (từ báo giá, hợp đồng, bill chốt).
    *   `Net Paid` (Đã thanh toán): Tổng tiền thực tế đã chi ra sau khi trừ đi các khoản hoàn tiền.
    *   `Outstanding` (Còn phải trả): Nghĩa vụ tài chính còn lại cần thanh toán.
*   **Tách biệt Phía chi (Cost Side) & Người trả tiền thực tế (Payer):**
    *   `Cost Side` thuộc về khoản mục chi tiêu (`Budget Item`), biểu thị chi phí thuộc về phía nào (`COMMON`, `BRIDE_SIDE`, `GROOM_SIDE`).
    *   `Payer` thuộc về giao dịch thanh toán cụ thể (`Payment`), ghi nhận ai thực tế là người đã chi tiền. Không ràng buộc Payer phải cùng phía với Cost Side.
*   **Không phân bổ quỹ trước:** Ghi nhận trên thực tế chi tiêu, không quản lý planned percentage split (chia tỷ lệ dự kiến) hay funding allocation (phân quỹ).

---

## 2. Các Ma Trận Nghiệp Vụ Quyết Định (Decision Matrices)

### A. Ma Trận Trạng Thái Chi Phí Của Khoản Mục (Budget Item Cost State Matrix)

| Trạng thái của Khoản mục (Cost State) | Dự toán (Estimated) | Đã chốt (Confirmed) | Đã thanh toán (Net Paid) | Ý nghĩa nghiệp vụ |
| :--- | :--- | :--- | :--- | :--- |
| `ESTIMATED_ONLY` | $\ge 0$ | `UNKNOWN` | $\ge 0$ | Mới chỉ lên dự toán, chưa chốt giá chính thức. |
| `CONFIRMED_UNPAID` | Có/Không | $\ge 0$ | $= 0$ | Đã chốt chi phí nhưng chưa thực hiện thanh toán. |
| `CONFIRMED_PARTIALLY_PAID` | Có/Không | $\ge 0$ | $> 0$ và $< \text{Confirmed}$ | Đã chốt chi phí và đã thanh toán một phần. |
| `CONFIRMED_FULLY_PAID` | Có/Không | $\ge 0$ | $\ge \text{Confirmed}$ | Đã chốt chi phí và đã thanh toán đủ (hoặc thừa). |
| `NO_COST` | `UNKNOWN` | `UNKNOWN` | $= 0$ | Khoản chi mới khởi tạo chưa có thông tin tiền. |

---

### B. Ma Trận Trạng Thái Đợt Thanh Toán (Installment Payment State Matrix)

Trạng thái của một đợt thanh toán dự kiến (`Installment`) được suy diễn động (derived state) từ ngày hạn chót (`Due Date`) và số tiền thực tế đã liên kết (`Linked Payments`):

| Trạng thái Đợt thanh toán (State) | Số tiền đã trả đợt này (Paid) | Hạn thanh toán (Due Date) | Ý nghĩa nghiệp vụ & Cách hiển thị |
| :--- | :--- | :--- | :--- |
| `PAID` | $\ge \text{Planned Amount}$ | Bất kỳ | Đã hoàn thành đóng tiền của đợt này (trả đủ hoặc thừa). |
| `UPCOMING` | $= 0$ | Tương lai hoặc `UNKNOWN` | Đợt thanh toán chưa tới hạn và chưa trả đồng nào. |
| `PARTIALLY_PAID` | $> 0$ và $< \text{Planned}$ | Tương lai hoặc `UNKNOWN` | Đã trả một phần đợt thanh toán trong tương lai. |
| `OVERDUE` | $< \text{Planned}$ | Quá khứ | Đợt thanh toán đã quá hạn và chưa hoàn thành đóng tiền. Hiển thị cảnh báo đỏ hoặc `"Quá hạn — còn X"` (nếu đã trả một phần). |

---

### C. Ma Trận Tính Toán Còn Phải Trả & Trả Thừa (Outstanding & Overpaid Calculation Matrix)

Quy tắc tính toán số tiền `Outstanding` (Còn phải trả) và `Overpaid` (Trả thừa) ở cấp độ Khoản chi (`Budget Item`):

*   **Công thức thực tế đã chi ra (`Net Paid`):**
    $$\text{Net Paid} = \text{Tổng Payments} - \text{Tổng Refunds}$$
*   **Ma trận tính toán công nợ:**

| Giá trị Đã chốt (Confirmed Cost) | Thực tế đã trả (Net Paid) | Số tiền Còn phải trả (Outstanding) | Số tiền Trả thừa (Overpaid) | Ý nghĩa hiển thị trên UX |
| :--- | :--- | :--- | :--- | :--- |
| `UNKNOWN` | Bất kỳ | `UNKNOWN` | `UNKNOWN` | Không tự tính Outstanding/Overpaid dựa trên Dự toán. Giao diện hiển thị: *"Chưa có"*. |
| Có giá trị $C$ | $NP \le C$ | $C - NP$ | $0$ | Hiển thị Còn phải trả bình thường. Trả thừa bằng 0. |
| Có giá trị $C$ | $NP > C$ | $0$ | $NP - C$ | Outstanding hiển thị `0` (không hiển thị số âm). Đồng thời hiển thị nhãn phụ: *"Trả thừa [Overpaid]"*. |

---

### D. Ma Trận Xóa Khoản Chi Tiêu (Budget Item Deletion/Archive Matrix)

Quy tắc xử lý khi người dùng yêu cầu xóa hoặc loại bỏ một Khoản chi (`Budget Item`):

| Lịch sử giao dịch thực tế | Hành vi hệ thống (System Behavior) | Luồng Người dùng (User Flow) |
| :--- | :--- | :--- |
| **Không có giao dịch nào** (Payments & Refunds trống) | Cho phép xóa cứng (Hard-delete) khoản chi khỏi cơ sở dữ liệu. | Khoản chi bị xóa sạch. Hệ thống tự động xóa các đợt thanh toán (`Installments`) tương ứng. |
| **Đã phát sinh giao dịch** (Có ít nhất 1 Payment hoặc Refund) | **Chặn hard-delete**. Chuyển sang trạng thái Hủy/Lưu trữ (`Cancel/Archive BudgetItem`) để bảo toàn thông tin kế toán. | Hệ thống lưu trữ lại toàn bộ bản ghi Payments, Refunds, Payers, ngày giao dịch và giá trị thanh toán lịch sử phục vụ báo cáo. |

---

### E. Ma Trận Tác Động Xóa Sự Kiện Đối Với Khoản Chi (Finance Event Removal Impact Matrix)

Khi một sự kiện cưới (`WeddingEvent`) bị người dùng xóa khỏi đám cưới:

| Khoản chi linked với Event bị xóa | Hành vi hệ thống (System Behavior) | Luồng Người dùng (User Flow) |
| :--- | :--- | :--- |
| **Budget Item bất kỳ** | **Bảo toàn dữ liệu tuyệt đối**. Không tự động xóa Budget Item, không tự xóa Payments/Refunds lịch sử. | Hệ thống gỡ liên kết sự kiện cũ, chuyển đổi Budget Item thành khoản chi chung cấp Đám cưới (`WeddingEvent = NONE`). Thay đổi này bắt buộc hiển thị rõ trên màn hình Rà soát tác động xóa sự kiện (**AND-PLA-07**) trước khi xác nhận. |

---

## 3. Flow REQ-03.1 — Budget Target & BudgetItem CRUD

### Goal
Cho phép cặp đôi thiết lập ngân sách mục tiêu, tạo lập và sửa đổi các khoản chi tiêu cùng phía gia đình phụ trách.

### Actors
*   Cô dâu, Chú rể.

### Preconditions
*   Đám cưới đã được tạo thành công.

### Trigger
*   Người dùng thiết lập ngân sách tại Dashboard (**AND-HOM-01**) hoặc thêm khoản chi tại Overview (**AND-FIN-01**).

### Main Flow (CRUD Khoản chi)
1.  Tại màn hình Tổng quan Tài chính (**AND-FIN-01**), người dùng bấm nút Thêm khoản chi (+).
2.  Hệ thống hiển thị màn hình Tạo/Sửa Khoản chi (**AND-FIN-03**).
3.  Người dùng nhập Tên khoản chi, danh mục, số tiền Dự toán (`Estimated Cost`), và phía chịu phí (`Cost Side` gồm `COMMON`, `BRIDE_SIDE`, `GROOM_SIDE`).
4.  Người dùng bấm "Lưu". Hệ thống khởi tạo thực thể `BudgetItem` trong DB.
5.  *Nhập chi phí đã chốt:* Khi có giá chốt cụ thể, người dùng mở màn hình chỉnh sửa (**AND-FIN-03**) và điền số tiền vào trường "Đã chốt" (`Confirmed Cost`). Hệ thống tự động tính lại Outstanding.

### Alternate Flows (Lưu trữ thay vì Xóa)
1.  Tại màn hình Chi tiết Khoản chi (**AND-FIN-02**), người dùng yêu cầu xóa một khoản chi đã phát sinh thanh toán thực tế.
2.  Hệ thống ngăn chặn xóa cứng, hiển thị tùy chọn: `"Hủy/Lưu trữ khoản chi"`.
3.  Người dùng xác nhận $\rightarrow$ Khoản chi chuyển sang trạng thái lưu trữ (`Archived`), ẩn khỏi danh sách hoạt động nhưng vẫn cộng dồn các khoản đã trả lịch sử vào báo cáo tổng Dashboard.

### Functional Requirements
*   **FIN-FR-001:** Hệ thống **PHẢI** hỗ trợ vận hành đầy đủ mọi chức năng ghi nhận chi tiêu và thanh toán ngay cả khi Ngân sách mục tiêu ở trạng thái chưa thiết lập (`UNKNOWN`). *(Screen: AND-FIN-01)*
*   **FIN-FR-002:** Hệ thống **KHÔNG ĐƯỢC PHÉP** tự động gán bất kỳ con số ngân sách mặc định nào để giả lập dữ liệu nếu người dùng chưa thiết lập. *(Domain Concept: Budget)*
*   **FIN-FR-003:** Hệ thống **PHẢI** hỗ trợ tạo khoản chi chung cấp Đám cưới (`WeddingEvent = NONE`) không gắn với sự kiện con nào. *(Screen: AND-FIN-03)*
*   **FIN-FR-004:** MVP **PHẢI** hỗ trợ lưu trữ (Archive/Cancel) khoản chi cùng toàn bộ Payments/Refunds lịch sử thay vì xóa cứng khi đã phát sinh dòng tiền thực tế. *(Screen: AND-FIN-02)*

### Validation Rules
*   **FIN-VAL-001:** Hạn mức ngân sách mục tiêu (nếu cấu hình) phải lớn hơn 0.
*   **FIN-VAL-002:** Số tiền Dự toán (`Estimated Cost`) và Đã chốt (`Confirmed Cost`) khi nhập phải lớn hơn hoặc bằng 0.

### Acceptance Criteria
*   **FIN-AC-001 (Budget Target Unconfigured):**
    *   *Given:* Đám cưới vừa tạo chưa thiết lập ngân sách mục tiêu.
    *   *When:* Người dùng mở Dashboard (**AND-HOM-01**).
    *   *Then:* Widget Ngân sách hiển thị: *"Ngân sách mục tiêu: Chưa thiết lập"* kèm nút *"Thiết lập"*. Không tự điền số 200M giả lập.
*   **FIN-AC-002 (Outstanding Calculation with Unknown Confirmed):**
    *   *Given:* Khoản chi "Thuê áo cưới" có Dự toán = `10.000.000` VNĐ, Đã chốt = `UNKNOWN`. Người dùng đã ghi nhận thanh toán `3.000.000` VNĐ.
    *   *When:* Người dùng xem chi tiết khoản chi (**AND-FIN-02**).
    *   *Then:* Hệ thống hiển thị: Đã thanh toán = `3.000.000` VNĐ, Đã chốt = `Chưa có`. Chỉ số Còn phải trả hiển thị là `Chưa có` và không tự động trừ tiền từ dự toán.
*   **FIN-AC-007 (Archive BudgetItem with Payments):**
    *   *Given:* Khoản chi hoa cưới đã trả `2.000.000` VNĐ.
    *   *When:* Người dùng thực hiện thao tác xóa khoản chi này.
    *   *Then:* Hệ thống chặn xóa cứng, hiển thị cảnh báo yêu cầu lưu trữ. Sau khi lưu trữ, khoản chi biến mất khỏi danh sách đang hoạt động nhưng số tiền `2.000.000` VNĐ vẫn được tính vào tổng tiền đã trả của đám cưới.

---

## 4. Flow REQ-03.2 — Payment Schedule & Installments

### Goal
Xây dựng lịch trình các đợt thanh toán đóng tiền cho nhà cung cấp sử dụng ngày lịch dương cố định.

### Actors
*   Cặp đôi.

### Preconditions
*   Khoản chi tiêu đã được tạo sẵn.

### Trigger
*   Người dùng bấm "Thêm đợt thanh toán" trên màn hình Chi tiết Khoản chi (**AND-FIN-02**).

### Main Flow
1.  Hệ thống hiển thị Bottom Sheet Thêm đợt thanh toán (**AND-FIN-06**).
2.  Người dùng nhập tên đợt (Ví dụ: `Đặt cọc 20%`), số tiền dự kiến đợt (`Planned Amount`), và chọn ngày đóng tiền cố định (`Due Date` - chọn từ calendar).
3.  Người dùng bấm "Lưu".
4.  Hệ thống tạo thực thể `Installment` liên kết với khoản chi.
5.  Cập nhật danh sách trên màn hình chi tiết.

### Functional Requirements
*   **FIN-FR-005:** Mốc hạn chót thanh toán đợt (`Installment Due Date`) **PHẢI** sử dụng ngày dương lịch cố định (Absolute Date) để đảm bảo an toàn dòng tiền. Hệ thống **KHÔNG ĐƯỢC PHÉP** tự động dời ngày hạn thanh toán khi dời ngày tổ chức sự kiện. *(Screen: AND-FIN-06)*

### Validation Rules
*   **FIN-VAL-003:** Số tiền dự kiến của đợt thanh toán (`Planned Amount`) phải là số nguyên dương lớn hơn 0.

### Screen References
*   [AND-FIN-02](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/information-architecture.md#5-danh-mục-màn-hình-đầy-đủ-complete-mvp-screen-inventory)
*   [AND-FIN-06](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/information-architecture.md#5-danh-mục-màn-hình-đầy-đủ-complete-mvp-screen-inventory)

---

## 5. Flow REQ-03.3 — Record Payment, Refunds & Overpayment

### Goal
Ghi nhận chính xác dòng tiền đi ra (thanh toán), dòng tiền nhận lại (hoàn tiền) và xử lý công nợ khi trả vượt định mức.

### Actors
*   Cặp đôi hoặc thành viên phụ trách tài chính.

### Preconditions
*   Khoản chi liên quan đã được khởi tạo.

### Trigger
*   Người dùng bấm "Ghi thanh toán" hoặc "Ghi hoàn tiền" tại màn hình Chi tiết Khoản chi (**AND-FIN-02**).

### Main Flow (Ghi nhận thanh toán)
1.  Hệ thống mở Form ghi nhận thanh toán (**AND-FIN-04**).
2.  Người dùng nhập số tiền (`Payment Amount`), ngày thực tế chi, Payer (Người chi tiền), và lựa chọn đợt thanh toán liên kết (`Installment` - nếu có).
3.  Người dùng bấm "Xác nhận".
4.  Hệ thống khóa tạm thời nút bấm gửi để tránh rủi ro bấm đúp tạo giao dịch trùng lặp.
5.  Hệ thống tạo thực thể `Payment` và tính toán lại `Net Paid` và `Outstanding` theo ma trận tại mục 2.C.

### Alternate Flows (Thanh toán vượt định mức đợt - Over-Installment Payment)
1.  Nếu đợt thanh toán yêu cầu `5.000.000` VNĐ nhưng người dùng thực tế chi trả `7.000.000` VNĐ liên kết với đợt này.
2.  Hệ thống chấp nhận giao dịch `7.000.000` VNĐ và tự động cập nhật đợt thanh toán đó sang trạng thái hoàn thành `PAID`.
3.  Hệ thống cộng toàn bộ `7.000.000` VNĐ vào số tiền đã trả (`Net Paid`) của khoản chi, giảm Outstanding tương ứng.
4.  Hệ thống **KHÔNG ĐƯỢC PHÉP** tự động phân bổ số tiền dư thừa `2.000.000` VNĐ vào các đợt thanh toán tiếp theo trong kế hoạch.
5.  Nếu tổng giá trị của các đợt thanh toán còn lại trong lịch trình không còn khớp với số tiền thực tế còn lại phải trả (`Outstanding`), hệ thống hiển thị nhãn cảnh báo: `"Lịch thanh toán cần rà soát"`.

### Alternate Flows (Ghi nhận hoàn tiền - Refund)
1.  Người dùng bấm "Ghi hoàn tiền" $\rightarrow$ Mở Form ghi hoàn tiền (**AND-FIN-05**).
2.  Người dùng nhập số tiền và ngày nhận lại tiền hoàn $\rightarrow$ Bấm xác nhận.
3.  Hệ thống ghi nhận thực thể `Refund`, tính giảm `Net Paid` của Khoản chi, tự động tăng tương ứng số tiền Còn phải trả (`Outstanding`).

### Functional Requirements
*   **FIN-FR-006:** Hệ thống **PHẢI** cho phép ghi nhận thanh toán trực tiếp cho một Khoản chi mà không bắt buộc phải lập lịch thanh toán đợt từ trước. *(Screen: AND-FIN-04)*
*   **FIN-FR-007:** Giao diện chi tiết đợt thanh toán **PHẢI** hiển thị đúng trạng thái trả một phần (`PARTIALLY_PAID`) và hiển thị rõ số tiền còn lại phải trả của đợt đó nếu số tiền đã liên kết nhỏ hơn số tiền dự kiến đợt. *(Screen: AND-FIN-02)*
*   **FIN-FR-008:** Hệ thống **BẮT BUỘC** phải chặn và báo lỗi nếu người dùng cố ý tạo giao dịch thanh toán hoặc hoàn tiền với số tiền bằng 0. *(Screen: AND-FIN-04, AND-FIN-05)*
*   **FIN-FR-009:** Trường Người trả tiền (`Payer`) trên Form thanh toán **PHẢI** hỗ trợ lựa chọn các đối tượng không cần có tài khoản trong hệ thống WeddingOS (ví dụ: Bố mẹ hai bên). *(Screen: AND-FIN-04)*

### Validation Rules
*   **FIN-VAL-004:** Số tiền thanh toán thực tế (`Payment Amount`) và số tiền hoàn lại (`Refund Amount`) khi nhập bắt buộc phải lớn hơn 0.

### Acceptance Criteria
*   **FIN-AC-003 (Multiple Payments & Partial State):**
    *   *Given:* Một đợt thanh toán dự kiến có số tiền planned là `20.000.000` VNĐ. Người dùng thực hiện ghi nhận thanh toán lần một `5.000.000` VNĐ liên kết đợt này.
    *   *When:* Hệ thống cập nhật trạng thái đợt thanh toán.
    *   *Then:* Trạng thái đợt thanh toán hiển thị là `PARTIALLY_PAID` (Đã trả một phần) kèm nhãn hiển thị: *"Đã trả: 5.000.000 VNĐ / Còn lại: 15.000.000 VNĐ"*.
*   **FIN-AC-004 (Refund reduces Net Paid):**
    *   *Given:* Khoản chi "Nhà rạp" có giá chốt `30.000.000` VNĐ, tổng tiền đã trả trước đó là `25.000.000` VNĐ. Người dùng ghi nhận hoàn tiền `5.000.000` VNĐ từ nhà cung cấp.
    *   *When:* Hệ thống lưu giao dịch hoàn tiền.
    *   *Then:* Giá trị Đã thanh toán của khoản chi giảm xuống còn `20.000.000` VNĐ và số tiền Còn phải trả (Outstanding) tăng lên tương ứng là `10.000.000` VNĐ.
*   **FIN-AC-005 (Overpayment Outstanding Zero):**
    *   *Given:* Khoản chi trang trí hoa cưới có giá chốt là `15.000.000` VNĐ. Người dùng ghi nhận giao dịch chuyển tiền cọc và thanh toán tổng cộng là `17.000.000` VNĐ.
    *   *When:* Hệ thống tính toán công nợ hiển thị.
    *   *Then:* Giá trị Đã thanh toán hiển thị là `17.000.000` VNĐ. Số tiền Còn phải trả (Outstanding) hiển thị là `0` VNĐ. Đồng thời giao diện hiển thị nhãn phụ: *"Trả thừa: 2.000.000 VNĐ"*.
*   **FIN-AC-008 (Payment Exceeds Installment Amount):**
    *   *Given:* Khoản chi tiệc cưới có đợt thanh toán cọc là `10.000.000` VNĐ và đợt 2 là `40.000.000` VNĐ. Người dùng ghi nhận một giao dịch thanh toán thực tế cọc là `12.000.000` VNĐ liên kết đợt cọc.
    *   *When:* Hệ thống lưu giao dịch và cập nhật lịch thanh toán.
    *   *Then:* Giao dịch `12M` được ghi nhận. Đợt cọc chuyển sang trạng thái hoàn thành `PAID`. Số tiền dư thừa `2.000.000` VNĐ không tự động chuyển sang trừ vào đợt 2. Đồng thời hệ thống hiển thị nhãn cảnh báo trên lịch trình: *"Lịch thanh toán cần rà soát"*.
*   **FIN-AC-010 (Overdue Installment with Partial Payment):**
    *   *Given:* Một đợt thanh toán dự kiến có số tiền là `10.000.000` VNĐ, hạn chót ngày `15/08/2026` (đã quá hạn so với hiện tại). Người dùng đã trả trước `3.000.000` VNĐ.
    *   *When:* Hệ thống hiển thị trạng thái của đợt thanh toán quá hạn này.
    *   *Then:* Trạng thái hiển thị là `"Quá hạn — còn 7.000.000 VNĐ"`.
*   **FIN-AC-011 (Zero Payment Attempt Rejected):**
    *   *Given:* Người dùng mở Form ghi thanh toán (**AND-FIN-04**).
    *   *When:* Người dùng nhập số tiền là `0` VNĐ và bấm xác nhận.
    *   *Then:* Hệ thống chặn lại, hiển thị thông báo lỗi yêu cầu số tiền phải lớn hơn 0 và không cho gửi form.

---

## 6. Flow REQ-03.4 — Finance Dashboard Metrics & Cash Flow

### Goal
Hiển thị tổng thể sức khỏe tài chính và dự báo dòng tiền chính xác trong 7/30 ngày của đám cưới.

### Actors
*   Cặp đôi.

### Preconditions
*   Người dùng truy cập vào tab Tài chính (**AND-FIN-01**).

### Trigger
*   Hệ thống tải dữ liệu tài chính của đám cưới.

### Main Flow
1.  Hệ thống thực hiện tính toán các chỉ số tài chính tổng hợp từ DB:
    *   `Total Estimated` = Tổng toàn bộ số tiền Dự toán của các khoản chi đang hoạt động.
    *   `Total Confirmed` = Tổng toàn bộ số tiền Đã chốt của các khoản chi đang hoạt động.
    *   `Projected Cost` (Tổng chi phí dự kiến) = Tính tổng bằng cách ưu tiên lấy giá trị Đã chốt (`Confirmed Cost`) của các khoản chi đã chốt, nếu chưa chốt thì cộng giá trị Dự toán (`Estimated Cost`) tương ứng.
    *   `Total Net Paid` = Tổng thực chi của tất cả các khoản chi hoạt động và lưu trữ.
    *   `Outstanding` = Tổng tiền còn phải trả hoạt động.
2.  Hệ thống tổng hợp dòng tiền cần chuẩn bị trong tương lai (`Cash Flow`):
    *   `Overdue Payments` = Tổng số tiền chưa trả của các đợt thanh toán có `Due Date` trong quá khứ và chưa `PAID`.
    *   `Due in 7 days` = Tổng số tiền còn lại của các đợt thanh toán có `Due Date` trong vòng 7 ngày tới.
    *   `Due in 30 days` = Tổng số tiền còn lại của các đợt thanh toán có `Due Date` trong vòng 30 ngày tới.
3.  Hệ thống hiển thị các chỉ số tổng hợp trên màn hình **AND-FIN-01**.

### Functional Requirements
*   **FIN-FR-010:** Hệ thống **PHẢI** tính toán chỉ số Dự báo Tổng chi phí (`Projected Cost`) bằng cách ưu tiên cộng dồn giá trị Đã chốt của các khoản chi đã có giá chốt và cộng giá Dự toán của các khoản chi chưa chốt. *(Screen: AND-FIN-01)*
*   **FIN-FR-011:** Chỉ số dự báo dòng tiền 7 ngày và 30 ngày **PHẢI** được tổng hợp duy nhất từ các đợt thanh toán đóng tiền chưa hoàn thành có cài đặt mốc ngày hạn đóng tiền (`Due Date`). Hệ thống **KHÔNG ĐƯỢC PHÉP** tự ý phân bổ hay neo ngày giả đối với các đợt không có hạn. *(Screen: AND-FIN-01)*

### Acceptance Criteria
*   **FIN-AC-006 (Projected Cost Calculation):**
    *   *Given:* Đám cưới có 3 khoản chi:
        *   Khoản 1: Dự toán = `10.000.000` VNĐ, Đã chốt = `UNKNOWN`.
        *   Khoản 2: Dự toán = `20.000.000` VNĐ, Đã chốt = `25.000.000` VNĐ.
        *   Khoản 3: Dự toán = `15.000.000` VNĐ, Đã chốt = `UNKNOWN`.
    *   *When:* Hệ thống tính chỉ số tổng Projected Cost hiển thị trên giao diện tài chính.
    *   *Then:* Chỉ số Projected Cost hiển thị là `50.000.000` VNĐ (Tính bằng: `10M` (Dự toán Khoản 1) + `25M` (Chốt Khoản 2) + `15M` (Dự toán Khoản 3)).

---

## 7. Flow REQ-03.5 — Finance Event Linkage

### Goal
Đảm bảo các khoản chi tiêu và thanh toán lịch sử không bị xóa mất ngoài ý muốn khi người dùng xóa sự kiện cưới con.

### Actors
*   Cặp đôi.

### Preconditions
*   Người dùng yêu cầu xóa một sự kiện con tại màn hình Chi tiết Sự kiện (**AND-PLA-04**).

### Trigger
*   Người dùng thực hiện xóa sự kiện.

### Main Flow
1.  Hệ thống kiểm tra danh sách các khoản chi tiêu (`Budget Item`) liên kết với sự kiện chuẩn bị xóa.
2.  Hệ thống hiển thị màn hình Rà soát tác động xóa sự kiện (**AND-PLA-07**).
3.  Hệ thống hiển thị thông tin rà soát tài chính rõ ràng để người dùng xác nhận (Ví dụ: *"2 khoản chi phí liên quan sẽ được chuyển thành khoản chi chung của đám cưới"*).
4.  Người dùng bấm xác nhận xóa sự kiện.
5.  Hệ thống xóa sự kiện con khỏi DB, tự động cập nhật tất cả các khoản chi tiêu liên kết với sự kiện đó thành khoản chi chung cấp Đám cưới (`WeddingEvent = NONE`).
6.  Hệ thống bảo toàn nguyên vẹn toàn bộ bản ghi lịch sử Payments và Refunds của các khoản chi này.

### Functional Requirements
*   **FIN-FR-011:** Khi xóa một sự kiện con, hệ thống **KHÔNG ĐƯỢC PHÉP** tự động xóa các khoản chi tiêu liên quan. Hệ thống **PHẢI** tự động chuyển chúng thành khoản chi chung cấp đám cưới và hiển thị thông tin chuyển đổi này trên giao diện review tác động trước khi xác nhận. *(Screen: AND-PLA-07)*

### Acceptance Criteria
*   **FIN-AC-009 (Event Removal Impact on Finance):**
    *   *Given:* Khoản chi thuê rạp hoa cưới đang liên kết với sự kiện Lễ Ăn Hỏi và đã phát sinh thanh toán cọc `5.000.000` VNĐ. Người dùng tiến hành xóa sự kiện Lễ Ăn Hỏi.
    *   *When:* Người dùng xác nhận đồng ý xóa trên màn hình review tác động (**AND-PLA-07**).
    *   *Then:* Sự kiện Lễ Ăn Hỏi bị xóa, khoản chi hoa cưới được chuyển thành khoản chi chung cấp Đám cưới, số tiền đã cọc `5.000.000` VNĐ và lịch sử thanh toán được bảo toàn hoàn toàn.

---

## 8. Bảng Truy Xuất Nguồn Gốc (Traceability Matrix)

| Mã Yêu Cầu (Requirement ID) | Phân hệ / Luồng (Flow) | Mã Màn Hình (Screen ID) | Khái Niệm Miền (Domain Concept) | Quyết Định Thiết Kế (Discovery Decision) | Mã Tiêu Chí Nghiệm Thu (Acceptance Criteria) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **FIN-FR-001** | REQ-03.1 | AND-FIN-01 | `Budget` | Vận hành đầy đủ khi ngân sách mục tiêu trống | FIN-AC-001 |
| **FIN-FR-002** | REQ-03.1 | - | `Budget` | Không tự điền số giả lập 200M | FIN-AC-001 |
| **FIN-FR-003** | REQ-03.1 | AND-FIN-03 | `BudgetItem` | Cho phép khoản chi chung cấp đám cưới | - |
| **FIN-FR-004** | REQ-03.1 | AND-FIN-02 | `BudgetItem` | Chặn hard-delete khoản chi đã có giao dịch | FIN-AC-007 |
| **FIN-FR-005** | REQ-03.2 | AND-FIN-06 | `Installment` | Hạn đợt thanh toán dùng ngày cố định | FIN-AC-003 |
| **FIN-FR-006** | REQ-03.3 | AND-FIN-04 | `Payment` | Cho phép ghi thanh toán trực tiếp không cần đợt | - |
| **FIN-FR-007** | REQ-03.3 | AND-FIN-02 | `Installment` | Đợt thanh toán hiển thị trạng thái trả một phần | FIN-AC-003, FIN-AC-010 |
| **FIN-FR-008** | REQ-03.3 | AND-FIN-04 | `Payment` | Chặn giao dịch thanh toán hoặc hoàn tiền bằng 0 | FIN-AC-011 |
| **FIN-FR-009** | REQ-03.3 | AND-FIN-04 | `Payer` | Payer có thể là người không có account app | - |
| **FIN-FR-010** | REQ-03.4 | AND-FIN-01 | `BudgetItem` | Tính Projected Cost ưu tiên cộng Confirmed Cost | FIN-AC-006 |
| **FIN-FR-011** | REQ-03.5 | AND-PLA-07 | `BudgetItem` | Chuyển BudgetItem thành việc chung khi xóa Event | FIN-AC-009 |
