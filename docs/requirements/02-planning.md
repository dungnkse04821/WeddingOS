# Đặc Tả Yêu Cầu Chi Tiết: REQ-02 — Planning

Tài liệu này đặc tả chi tiết các yêu cầu nghiệp vụ phần mềm cho Phân hệ **REQ-02 — Planning (Lập Kế hoạch)** của hệ thống WeddingOS.

---

## 1. Mô Hình Tư Duy Lập Kế Hoạch (Planning Mental Model)

*   **Task phẳng (Checklist flatness):** Công việc (`Task`) là đơn vị lập kế hoạch độc lập và nhỏ nhất. Hệ thống không hỗ trợ công việc con (Subtask), danh sách kiểm tra phân cấp (Checklist hierarchy), hay biểu đồ phụ thuộc công việc (Dependency graph) trong MVP.
*   **AI chỉ Gợi ý (AI Recommendation-only):** AI chỉ gợi ý công việc trên giao diện. AI không được phép tự động tạo Task trong DB (trừ luồng onboarding đã chốt), không tự động đánh dấu hoàn thành, dời ngày, sửa đổi hay xóa bất kỳ công việc nào của người dùng.
*   **Phân chia Side & Assignee độc lập:** 
    *   `Side` đại diện cho phần việc thuộc trách nhiệm gia đình nào (`COMMON`, `BRIDE_SIDE`, `GROOM_SIDE`).
    *   `Assignee` đại diện cho thành viên cụ thể chịu trách nhiệm thực hiện. Side và Assignee hoàn toàn độc lập (Ví dụ: Một việc thuộc `GROOM_SIDE` vẫn có thể phân công cho cô dâu thực hiện).

---

## 2. Các Ma Trận Nghiệp Vụ Quyết Định (Decision Matrices)

### A. Ma Trận Chuyển Trạng Thái Công Việc (Task State Transition Matrix)

| Trạng thái Hiện tại (Current) | Hành động (Action) | Trạng thái Đích (Result) | Cho phép? (Allowed) | Ghi chú & Quy tắc nghiệp vụ |
| :--- | :--- | :--- | :--- | :--- |
| `TODO` | Bắt đầu thực hiện | `IN_PROGRESS` | Có | Chuyển trạng thái. |
| `TODO` | Hoàn thành trực tiếp | `COMPLETED` | Có | Ghi nhận hoàn thành và lưu dấu thời gian `CompletedAt`. |
| `TODO` | Hủy bỏ công việc | `CANCELLED` | Có | Chuyển sang trạng thái hủy. |
| `IN_PROGRESS` | Tạm dừng thực hiện | `TODO` | Có | Đưa về trạng thái cần làm. |
| `IN_PROGRESS` | Hoàn thành | `COMPLETED` | Có | Ghi nhận hoàn thành và lưu `CompletedAt`. |
| `IN_PROGRESS` | Hủy bỏ công việc | `CANCELLED` | Có | Chuyển sang trạng thái hủy. |
| `COMPLETED` | Mở lại công việc | `TODO` | Có | Hủy dấu thời gian hoàn thành. Áp dụng quy tắc tính hạn chót sau reopen (Xem phần B). |
| `CANCELLED` | Khôi phục công việc | `TODO` | Có | Khôi phục trạng thái làm việc, bảo toàn dữ liệu cũ của Task, không tạo mới Task. |

---

### B. Ma Trận Loại Hạn Chót & Quyền Cấu Hình (Deadline Type / Ownership Matrix)

| Loại Hạn Chót (Deadline Type) | Mô tả & Cách hiển thị khi ngày Sự kiện là `UNKNOWN` | Hành vi dời lịch khi đổi ngày Sự kiện | Quy tắc chuyển đổi (Override Rule) |
| :--- | :--- | :--- | :--- |
| **System-managed Relative** (Tương đối do Hệ thống quản lý) | Mốc ngày dạng tương đối (ví dụ: *"khoảng 30 ngày trước lễ cưới"*). Không hiển thị ngày lịch. | Tự động tính toán lại và dịch chuyển theo ngày cưới chính xác mới (`New Date + Default Offset`). | Trở thành `User-managed` ngay khi người dùng chỉnh sửa thủ công số ngày offset hoặc chọn ngày cố định. |
| **User-managed Relative** (Tương đối do Người dùng quản lý) | Mốc ngày dạng tương đối tùy chỉnh (ví dụ: *"khoảng 45 ngày trước lễ cưới"* do user sửa từ 30). | Tự động tính toán dịch chuyển theo ngày cưới chính xác mới và **bảo toàn số offset đã sửa** (`New Date + User Offset`). | Quay về `System-managed Relative` khi người dùng chọn hành động `"Theo lại lịch sự kiện"` trên giao diện sửa Task. |
| **User-managed Absolute** (Cố định do Người dùng quản lý) | Ngày dương lịch cụ thể (ví dụ: `12/10/2026`). | **Giữ nguyên hạn chót cố định**. Không tự dịch chuyển. Đưa vào màn hình Review để cảnh báo. | Xem quy tắc chuyển về mặc định tại luồng Action `"Theo lại lịch sự kiện"` (Mục 3). |
| **No Deadline** (Không có hạn chót) | Hiển thị trong khu vực *"Chưa có hạn chót"*. | Không dời lịch, không đưa vào review. | Chuyển sang một trong ba loại trên nếu người dùng cấu hình hạn chót. |

---

### C. Ma Trận Tác Động Khi Thay Đổi Ngày Sự Kiện (Event Date Change Impact Matrix)

Khi ngày tổ chức của một `WeddingEvent` thay đổi (Ví dụ: dời từ ngày T1 sang ngày T2):

| Nhóm công việc (Task Group) | Trạng thái & Hạn chót | Hành vi hệ thống (System Behavior) | Luồng Người dùng (User Flow) |
| :--- | :--- | :--- | :--- |
| **Nhóm A** | Hoạt động (`TODO`, `IN_PROGRESS`) + Hạn tương đối hệ thống (`System-managed Relative`). | **Tự động dịch chuyển** hạn chót theo công thức của ngày sự kiện mới. | Không cần người dùng review. Hệ thống tự động dịch chuyển ngầm. |
| **Nhóm B** | Hoạt động (`TODO`, `IN_PROGRESS`) + Hạn tương đối sửa đổi (`User-managed Relative`). | **Tự động tính toán dịch chuyển** theo ngày cưới mới + số offset đã tùy biến của người dùng. | Không bắt buộc review từng việc. Các việc này hiển thị trong bảng Tổng hợp dịch chuyển tự động để người dùng biết. |
| **Nhóm C** | Hoạt động (`TODO`, `IN_PROGRESS`) + Hạn cố định (`User-managed Absolute`). | **Giữ nguyên ngày cố định cũ**. | **Đưa vào màn hình Review (Impact Review)** yêu cầu người dùng xác nhận giữ nguyên hay chọn dịch chuyển tịnh tiến. |
| **Nhóm D** | Đã hoàn thành (`COMPLETED`) - Bất kể loại hạn chót. | **Giữ nguyên tuyệt đối hạn chót lịch sử**. | Bỏ qua hoàn toàn, không dịch chuyển và không đưa vào màn hình Review. |

---

### D. Ma Trận Thay Đổi Ngày Từ Ngày Chính Xác sang Tháng Dự Kiến (Exact Date $\rightarrow$ Expected Month)

Khi ngày tổ chức của một `WeddingEvent` thay đổi từ một Ngày cụ thể (Exact Date) ngược trở lại chỉ biết Tháng dự kiến (Expected Month / Date Unknown):

| Nhóm công việc (Task Group) | Trạng thái & Hạn chót ban đầu | Hành vi hệ thống (System Behavior) | Hiển thị giao diện & Luồng xử lý |
| :--- | :--- | :--- | :--- |
| **Nhóm A** | Hoạt động + Hạn tương đối hệ thống (`System-managed Relative`). | **Hủy mốc ngày dương lịch đã tính**. Trở về hiển thị chuỗi tương đối theo quy tắc mặc định (T-offset). | Quay về cách hiển thị tương đối (Ví dụ: *"khoảng 30 ngày trước lễ cưới"*). Không hiển thị ngày lịch cụ thể và không tự đặt ngày giả. |
| **Nhóm B** | Hoạt động + Hạn tương đối sửa đổi (`User-managed Relative`). | **Hủy mốc ngày dương lịch đã tính**. Quay về hiển thị tương đối dựa trên custom offset đã sửa của user. | Bảo toàn số offset đã sửa của user (Ví dụ: *"khoảng 45 ngày trước lễ cưới"*). |
| **Nhóm C** | Hoạt động + Hạn cố định (`User-managed Absolute`). | **Giữ nguyên hạn chót dương lịch cố định**. Không tự xóa hạn chót, không tự quy đổi ngược sang offset tương đối. | Giữ nguyên ngày lịch cụ thể (Ví dụ: `10/11/2026`). Đưa vào màn hình Review/Warning để cảnh báo trùng lập hoặc quá hạn nếu ngày sự kiện đã chuyển sang tháng dự kiến khác. |
| **Nhóm D** | Đã hoàn thành (`COMPLETED`) - Bất kể loại hạn chót. | **Bảo toàn nguyên vẹn ngày hoàn thành lịch sử và trạng thái**. Không tính toán lại. | Giữ nguyên lịch sử đã lưu. |

---

### E. Ma Trận Tác Động Khi Xóa Sự Kiện (Event Removal Impact Matrix)

Khi một `WeddingEvent` bị người dùng xóa khỏi đám cưới:

| Loại công việc liên kết với Event | Hành vi hệ thống (System Behavior) | Luồng Người dùng (User Flow) |
| :--- | :--- | :--- |
| **Suggested Task chưa chỉnh sửa** | **Gợi ý xóa (Default Delete)** khỏi cơ sở dữ liệu. | Không yêu cầu review từng việc, chỉ hiển thị số lượng sẽ bị xóa trong thông báo xác nhận (Ví dụ: *"12 việc gợi ý liên quan sẽ bị xóa"*). |
| **Suggested Task đã sửa đổi** (Đã chỉnh tiêu đề, hạn chót, side, assign) | **Bảo toàn dữ liệu**. Tự động gỡ liên kết sự kiện con và chuyển thành Công việc chung cấp Đám cưới (Wedding-level Task). | **Đưa vào màn hình Review** để người dùng quyết định: giữ lại làm việc chung, chuyển sang sự kiện khác hoặc bấm xóa. |
| **Task do người dùng tự tạo** | **Bảo toàn dữ liệu**. Chuyển thành Công việc chung cấp Đám cưới. | **Đưa vào màn hình Review** để người dùng quyết định hành động tương tự như trên. |
| **Task đã hoàn thành (`COMPLETED`)** | **Bảo toàn dữ liệu**. Chuyển thành Công việc chung cấp Đám cưới. | Tự động giữ lại làm hồ sơ lịch sử đám cưới, không xóa và không yêu cầu review. |

---

## 3. Flow REQ-02.1 — Task CRUD & Assignment

### Goal
Cho phép người dùng tạo, sửa, xóa các công việc và thực hiện phân công thành viên phụ trách trên giao diện di động Android.

### Actors
*   Cô dâu, Chú rể hoặc thành viên có quyền hạn.

### Preconditions
*   Đám cưới đã được khởi tạo thành công.

### Trigger
*   Người dùng bấm nút thêm công việc mới (+) hoặc sửa một công việc sẵn có trên màn hình Kế hoạch (**AND-PLA-01**).

### Main Flow
1.  Tại màn hình Danh sách Công việc (**AND-PLA-01**), người dùng bấm nút thêm công việc mới (+).
2.  Hệ thống chuyển sang màn hình Tạo/Sửa Task (**AND-PLA-03**).
3.  Người dùng nhập Tiêu đề công việc, chọn Phía gia đình (`Side`), chọn Ngày hạn chót (tương đối hoặc cố định), và chọn Thành viên phụ trách (`Assignee`).
4.  Người dùng bấm nút "Lưu".
5.  Hệ thống khởi tạo thực thể `Task` trong cơ sở dữ liệu của đám cưới.
6.  Đưa người dùng quay lại danh sách công việc.

### Alternate Flows (Khôi phục hạn chót mặc định hệ thống - "Theo lại lịch sự kiện")
1.  Tại màn hình chỉnh sửa công việc (**AND-PLA-03**), đối với Task đang có hạn chót do người dùng quản lý (`User-managed`):
2.  Người dùng chủ động chọn hành động `"Theo lại lịch sự kiện"`.
3.  Hệ thống kiểm tra nguồn gốc của công việc:
    *   *Trường hợp A (Task gợi ý hệ thống hoặc Task từng có quy tắc tương đối):* Hệ thống khôi phục quy tắc tương đối mặc định của template (hoặc quy tắc đã cấu hình trước đó), tính toán lại theo ngày sự kiện và chuyển hạn chót về loại `System-managed Relative`.
    *   *Trường hợp B (Task do người dùng tự tạo cố định ban đầu - User-created Absolute):* Hệ thống **KHÔNG ĐƯỢC PHÉP** tự động suy diễn hay tính delta ngày offset từ ngày sự kiện cũ. Hệ thống yêu cầu người dùng phải chủ động nhập khoảng cách ngày offset tương đối mong muốn (ví dụ: nhập số ngày trước cưới) trước khi chuyển trạng thái.

### Functional Requirements
*   **PLN-FR-001:** Hệ thống **PHẢI** cho phép tạo công việc chung ở cấp độ Đám cưới (`Wedding-level Task`) không liên kết với bất kỳ Sự kiện cưới con nào. *(Screen: AND-PLA-03)*
*   **PLN-FR-002:** Giao diện nhập liệu tạo/sửa công việc **PHẢI** lưu trạng thái nháp tự động trên Android. Hệ thống **PHẢI** khôi phục lại nội dung đang nhập nếu luồng bị ngắt quãng do cuộc gọi, tắt app tạm thời hoặc mất kết nối mạng. *(Screen: AND-PLA-03)*

### Validation Rules
*   **PLN-VAL-001:** Tiêu đề công việc khi tạo mới hoặc chỉnh sửa không được để trống và có độ dài tối đa là 100 ký tự.

---

## 4. Flow REQ-02.2 — Task Lifecycle (Complete, Reopen, Cancel & Restore)

### Goal
Quản lý trạng thái tiến trình của từng công việc bao gồm hoàn thành, mở lại, hủy bỏ và khôi phục công việc đã hủy.

### Actors
*   Cô dâu, Chú rể hoặc thành viên có quyền.

### Preconditions
*   Công việc cần thay đổi trạng thái tồn tại trong đám cưới.

### Trigger
*   Người dùng thay đổi trạng thái công việc trên màn hình danh sách (**AND-PLA-01**) hoặc chi tiết (**AND-PLA-02**).

### Main Flow (Hoàn thành & Mở lại)
1.  Tại màn hình Chi tiết Task (**AND-PLA-02**), người dùng bấm nút "Đánh dấu Hoàn thành".
2.  Hệ thống chuyển trạng thái Task sang `COMPLETED`, tự động điền mốc thời gian hoàn thành thực tế (`CompletedAt`).
3.  *Luồng mở lại:* Khi công việc đang là `COMPLETED` và người dùng bấm nút "Mở lại", hệ thống chuyển trạng thái về `TODO` và xóa mốc thời gian hoàn thành.

### Alternate Flows (Hủy & Khôi phục)
1.  Người dùng chọn hủy một công việc hoạt động $\rightarrow$ Hệ thống chuyển trạng thái sang `CANCELLED`.
2.  *Luồng khôi phục:* Khi công việc đang là `CANCELLED`, giao diện cung cấp hành động "Khôi phục". Người dùng xác nhận khôi phục $\rightarrow$ Hệ thống chuyển trạng thái về `TODO`, bảo toàn toàn bộ thông tin tiêu đề, phân công và hạn chót cũ.

### Functional Requirements
*   **PLN-FR-003:** Khi người dùng mở lại (`Reopen`) một công việc gợi ý hệ thống (`System-managed Relative`) đã hoàn thành trước đó:
    *   *Quy tắc:* Hệ thống **PHẢI** tự động tính toán lại hạn chót của công việc dựa trên ngày hiện tại của Sự kiện liên kết.
    *   *Trường hợp ngoại lệ:* Nếu công việc đó là loại người dùng tự quản lý hạn chót (`User-managed` gồm cả Relative và Absolute), hệ thống **BẮT BUỘC** phải giữ nguyên ngày hạn chót tùy chỉnh cũ của người dùng. *(Domain Concept: Task)*
*   **PLN-FR-004:** Hệ thống **PHẢI** cho phép khôi phục công việc đang ở trạng thái hủy `CANCELLED` về lại trạng thái hoạt động `TODO` và bảo toàn nguyên vẹn dữ liệu gốc của công việc. *(Screen: AND-PLA-02)*

### Acceptance Criteria
*   **PLN-AC-001 (Reopen Completed System Task):**
    *   *Given:* Một task gợi ý hệ thống (hạn chót T-30) đã hoàn thành (`COMPLETED`) ở ngày cưới cũ `02/11/2026` (hạn chót lịch sử là `03/10/2026`). Ngày cưới sau đó dời sang `16/11/2026` (task completed không bị dời, giữ nguyên `03/10`).
    *   *When:* Người dùng bấm nút mở lại công việc (Reopen).
    *   *Then:* Trạng thái công việc chuyển sang `TODO` và hạn chót tự động tính lại theo ngày cưới mới: ngày cưới mới `16/11` - 30 ngày = `17/10/2026`.
*   **PLN-AC-005 (Reopen Completed User Task):**
    *   *Given:* Một task có hạn chót cố định do user chốt (`User-managed Absolute` ngày `10/10/2026`) đã hoàn thành (`COMPLETED`). Ngày cưới sau đó dời sang `16/11/2026`.
    *   *When:* Người dùng bấm nút mở lại công việc (Reopen).
    *   *Then:* Trạng thái công việc chuyển sang `TODO` và ngày hạn chót được bảo toàn nguyên vẹn là ngày `10/10/2026`.

---

## 5. Flow REQ-02.3 — Event Date Change & Impact Review

### Goal
Đám bảo tính chính xác và an toàn của kế hoạch khi ngày tổ chức sự kiện bị thay đổi hoặc rút từ ngày chính xác về tháng dự kiến, tự động dời lịch các việc tương đối và yêu cầu rà soát các việc cố định.

### Actors
*   Cặp đôi (Cô dâu/Chú rể).

### Preconditions
*   Người dùng đang ở màn hình Chi tiết Sự kiện (**AND-PLA-04**).

### Trigger
*   Người dùng thay đổi cấu hình ngày tổ chức của một `WeddingEvent` và bấm xác nhận.

### Main Flow
1.  Hệ thống nhận cấu hình ngày cưới mới và thực hiện phân loại các công việc liên kết với sự kiện đó.
2.  *Nếu dời sang ngày chính xác mới:* Áp dụng Ma trận dời ngày (Mục 2.C). Hệ thống dịch chuyển tự động cho Nhóm A & B, hiển thị Nhóm C trên màn hình Review (**AND-PLA-06**).
3.  *Nếu chuyển từ Ngày chính xác về Tháng dự kiến:* Áp dụng Ma trận quy đổi ngược (Mục 2.D). Hệ thống tự động chuyển đổi hiển thị của Nhóm A & B sang dạng tương đối, giữ nguyên ngày cố định của Nhóm C và đưa lên Review/Warning context.
4.  Người dùng rà soát tác động, thực hiện chọn hành động mong muốn và xác nhận áp dụng.
5.  Hệ thống lưu dữ liệu cập nhật và đưa người dùng về Dashboard.

### Functional Requirements
*   **PLN-FR-005:** Hệ thống **PHẢI** tự động dịch chuyển hạn chót đối với các công việc có hạn chót tương đối tùy chỉnh (`User-managed Relative`) theo ngày sự kiện mới mà không bắt buộc người dùng duyệt thủ công từng dòng trên màn hình review. Các công việc này chỉ hiển thị trong phần thống kê kết quả dịch chuyển tự động. *(Screen: AND-PLA-06)*
*   **PLN-FR-006:** Màn hình Review **PHẢI** cho phép chọn xử lý hàng loạt (Batch Action) đối với các công việc có hạn cố định (Nhóm C) để dịch chuyển tịnh tiến nhanh, cấm áp dụng ghi đè lên các việc đã hoàn thành. *(Screen: AND-PLA-06)*

### Business Rules
*   **PLN-BR-003:** Mọi quy trình tính toán dời lịch của hệ thống tuyệt đối không được phép sử dụng bất kỳ ngày neo giả lập nào (ví dụ: ngày 15 giữa tháng) để làm cơ sở tính delta dời ngày.

### Acceptance Criteria
*   **PLN-AC-002 (Event Date Change):**
    *   *Given:* Sự kiện cưới dời từ ngày `02/11/2026` sang ngày `16/11/2026` (Dời lịch 14 ngày).
    *   *When:* Người dùng tiến hành dời ngày sự kiện.
    *   *Then:*
        *   Các công việc Nhóm A (hạn tương đối hệ thống T-30) tự động dịch chuyển hạn chót sang ngày `17/10/2026`.
        *   Các công việc Nhóm B (hạn tương đối tùy chỉnh T-45) tự động dịch chuyển sang ngày `02/10/2026`.
        *   Các công việc Nhóm C (hạn cố định) được hiển thị trên giao diện Rà soát để người dùng chốt.
        *   Các công việc Nhóm D (Completed) giữ nguyên hạn chót cũ.
*   **PLN-AC-012 (Month to Exact Date Conversion):**
    *   *Given:* Đám cưới đang ở trạng thái dự kiến `Tháng 12/2026` (Exact Date = UNKNOWN). Công việc T-30 đang hiển thị là *"Khoảng 1 tháng trước cưới"*. Người dùng sau đó chốt ngày cưới chính xác là `18/12/2026`.
    *   *When:* Hệ thống cập nhật ngày cưới chính xác.
    *   *Then:* Công việc T-30 tự động tính toán ra ngày hạn chót dương lịch cụ thể là ngày `18/11/2026` (không tính trung gian qua ngày 15/12).
*   **PLN-AC-015 (Exact Date to Expected Month - System Relative):**
    *   *Given:* Đám cưới có ngày cưới chính xác là `18/12/2026`. Công việc Nhóm A (T-30) hiển thị ngày hạn cụ thể là `18/11/2026`. Người dùng sau đó chuyển ngày cưới về dạng dự kiến `Tháng 12/2026` (Exact Date = UNKNOWN).
    *   *When:* Hệ thống cập nhật cấu hình ngày cưới mới.
    *   *Then:* Hạn chót của công việc Nhóm A lập tức quay về cách hiển thị tương đối là *"khoảng 30 ngày trước lễ cưới"*, không giữ ngày cố định `18/11/2026`.
*   **PLN-AC-016 (Exact Date to Expected Month - User Relative):**
    *   *Given:* Công việc Nhóm B có hạn tương đối tùy chỉnh là trước cưới 45 ngày, đang tính ra ngày hạn cụ thể là `03/11/2026` (ngày cưới `18/12`). Người dùng chuyển ngày cưới về dạng dự kiến `Tháng 12/2026`.
    *   *When:* Hệ thống cập nhật ngày cưới mới.
    *   *Then:* Hạn chót công việc Nhóm B quay về hiển thị dạng tương đối dựa trên custom offset là *"khoảng 45 ngày trước lễ cưới"*.
*   **PLN-AC-017 (Exact Date to Expected Month - User Absolute):**
    *   *Given:* Công việc Nhóm C có hạn cố định dương lịch do user tự chọn là `10/11/2026`. Người dùng chuyển ngày cưới về dạng dự kiến `Tháng 12/2026`.
    *   *When:* Hệ thống cập nhật ngày cưới mới.
    *   *Then:* Ngày hạn chót của công việc Nhóm C được giữ nguyên tuyệt đối là ngày `10/11/2026` và hiển thị cảnh báo warning liên quan trong danh sách review.
*   **PLN-AC-018 (Theo Lại Lịch Sự Kiện - Custom Absolute Task):**
    *   *Given:* Công việc do user tự tạo với hạn chót cố định ban đầu là ngày `15/11/2026` (không có quy tắc relative trước đó).
    *   *When:* Người dùng mở sửa và bấm chọn hành động `"Theo lại lịch sự kiện"`.
    *   *Then:* Hệ thống không tự động tính offset tương đối dựa trên hiệu số ngày, mà hiển thị thông báo yêu cầu người dùng tự chọn/nhập khoảng cách ngày offset tương đối theo ý muốn.
*   **PLN-AC-019 (Exact Date to Expected Month - Completed Task):**
    *   *Given:* Công việc Nhóm D đã hoàn thành (`COMPLETED`) có hạn chót lịch sử được ghi nhận. Người dùng chuyển ngày cưới về dạng dự kiến `Tháng 12/2026`.
    *   *When:* Hệ thống cập nhật ngày cưới mới.
    *   *Then:* Hạn chót lịch sử và trạng thái của công việc Nhóm D được giữ nguyên tuyệt đối.

---

## 6. Flow REQ-02.4 — Event Removal Impact Review

### Goal
Ngăn chặn mất dữ liệu công việc và tài chính do người dùng tự tạo hoặc chỉnh sửa khi tiến hành xóa sự kiện cưới con.

### Actors
*   Cặp đôi.

### Preconditions
*   Người dùng yêu cầu xóa một sự kiện con trong trang chi tiết sự kiện (**AND-PLA-04**).

### Trigger
*   Người dùng bấm nút "Xóa sự kiện" trên giao diện.

### Main Flow
1.  Hệ thống kiểm tra danh sách các công việc và khoản chi tiêu (`BudgetItem`) đang liên kết với sự kiện sắp xóa.
2.  Hệ thống hiển thị màn hình Rà soát tác động xóa sự kiện (**AND-PLA-07**).
3.  *Đối với các Suggested Task chưa chỉnh sửa:* Hệ thống gom nhóm và hiển thị thông báo đề xuất xóa hàng loạt (ví dụ: *"12 công việc gợi ý liên quan sẽ bị xóa"*).
4.  *Đối với các công việc tự tạo, đã chỉnh sửa hoặc đã hoàn thành:* Hệ thống hiển thị chi tiết danh sách và yêu cầu người dùng chọn hành động xử lý:
    *   `Chuyển thành công việc/khoản chi chung cấp Đám cưới` (gỡ liên kết sự kiện cũ).
    *   `Chuyển sang liên kết với sự kiện con khác`.
    *   `Xác nhận xóa vĩnh viễn`.
5.  Người dùng hoàn tất chọn lựa và bấm "Xác nhận xóa sự kiện".
6.  Hệ thống thực hiện cập nhật DB theo lựa chọn và đưa người dùng về Dashboard.

### Functional Requirements
*   **PLN-FR-007:** Hệ thống **KHÔNG ĐƯỢC PHÉP** tự động xóa các công việc đã hoàn thành hoặc công việc tự tạo của người dùng khi xóa sự kiện mà không thông qua luồng duyệt và xác nhận. *(Screen: AND-PLA-07)*
*   **PLN-FR-008:** Hệ thống **BẮT BUỘC** phải khóa nút xóa và chặn hành động xóa Sự kiện con nếu đó là Sự kiện chính (Main Event) duy nhất còn lại của đám cưới. Người dùng bắt buộc phải tạo hoặc chọn một sự kiện khác làm sự kiện chính trước khi xóa sự kiện hiện tại. *(Screen: AND-PLA-04)*

### Acceptance Criteria
*   **PLN-AC-003 (Event Removal):**
    *   *Given:* Người dùng đang ở màn hình **AND-PLA-07** để chuẩn bị xóa sự kiện Lễ Ăn Hỏi. Danh sách có 10 suggested tasks chưa chỉnh sửa và 1 task do user tự tạo.
    *   *When:* Người dùng bấm xác nhận xóa và chọn chuyển task tự tạo thành việc chung.
    *   *Then:* Sự kiện Lễ Ăn Hỏi bị xóa, 10 suggested tasks bị xóa, task tự tạo được bảo toàn và chuyển thành công việc chung cấp đám cưới (`WeddingEvent = NONE`).
*   **PLN-AC-013 (Block Last Main Event Deletion):**
    *   *Given:* Đám cưới chỉ có duy nhất 1 sự kiện chính là Lễ Cưới.
    *   *When:* Người dùng bấm nút "Xóa sự kiện" của Lễ Cưới tại màn hình **AND-PLA-04**.
    *   *Then:* Nút xóa bị khóa hoặc hệ thống hiển thị thông báo chặn: *"Không thể xóa sự kiện chính duy nhất còn lại. Vui lòng thiết lập sự kiện khác làm sự kiện chính trước khi thực hiện."*

---

## 7. Flow REQ-02.5 — Planning Progress & Activation Action

### Goal
Đo lường chính xác tiến độ lập kế hoạch đám cưới và ghi nhận hành vi kích hoạt ứng dụng của người dùng.

### Actors
*   Hệ thống WeddingOS (chạy tự động).

### Preconditions
*   Người dùng thực hiện một hành động trên ứng dụng.

### Trigger
*   Mỗi khi có sự thay đổi trạng thái của các thực thể `Task` trong không gian đám cưới.

### Main Flow
1.  Hệ thống đếm tổng số lượng công việc hoạt động đang lập kế hoạch trong đám cưới:
    *   `Active Planning Tasks = Tổng số Task ở trạng thái TODO + IN_PROGRESS + COMPLETED`.
    *   *Quy tắc:* Loại bỏ hoàn toàn các công việc ở trạng thái `CANCELLED`.
2.  Hệ thống đếm tổng số công việc đã hoàn thành:
    *   `Completed Planning Tasks = Tổng số Task ở trạng thái COMPLETED`.
3.  Hệ thống tính toán tiến độ lập kế hoạch theo công thức:
    *   *Nếu Active Planning Tasks = 0:* Đặt `Planning Progress (%) = 0%`.
    *   *Nếu Active Planning Tasks > 0:* `Planning Progress (%) = (Completed Planning Tasks) / (Active Planning Tasks) * 100%`.
4.  Hệ thống cập nhật chỉ số phần trăm này lên Widget Kế hoạch của Dashboard (**AND-HOM-01**) tức thì.

### Functional Requirements
*   **PLN-FR-009:** Chỉ số phần trăm tiến độ lập kế hoạch hiển thị trên giao diện **PHẢI** được tính toán động từ số công việc hoàn thành thực tế. Hệ thống **PHẢI** hiển thị `0%` nếu chưa có công việc hoạt động nào được tạo lập trong đám cưới (tránh lỗi chia cho 0). *(Screen: AND-HOM-01)*

### Business Rules
*   **PLN-BR-004:** Trạng thái **Activation Event** của đám cưới được kích hoạt khi người dùng thực hiện một hành động lập kế hoạch có ý nghĩa đầu tiên (First Meaningful Planning Action), bao gồm các hành động sau:
    *   Bắt đầu công việc (`TASK_STARTED` - chuyển sang `IN_PROGRESS`).
    *   Hoàn thành công việc (`TASK_COMPLETED` - chuyển sang `COMPLETED`).
    *   Tự tạo mới một công việc (`TASK_CREATED`).
    *   Chỉnh sửa thông tin cốt lõi của công việc gợi ý (`TASK_CUSTOMIZED`).
    *   Chủ động loại bỏ/xóa bỏ một công việc gợi ý không phù hợp (`SUGGESTION_REMOVED`).
    *   *Quy tắc:* Các hành động xem, tìm kiếm, lọc, sắp xếp danh sách hoặc chuyển đổi tab điều hướng không được tính là kích hoạt ứng dụng.

### Acceptance Criteria
*   **PLN-AC-004 (Planning Progress):**
    *   *Given:* Đám cưới mới tạo có 10 công việc hoạt động (tất cả là `TODO`). Tiến độ hiển thị là `0%`.
    *   *When:* Người dùng đánh dấu hoàn thành 1 công việc đầu tiên.
    *   *Then:* Tiến độ lập kế hoạch lập tức cập nhật thành `10%` (`1/10 * 100%`) và hệ thống ghi nhận tài khoản đã đạt trạng thái **Activation**.
*   **PLN-AC-014 (Denominator Zero Protection):**
    *   *Given:* Đám cưới chưa có bất kỳ công việc nào trong danh sách (Active Planning Tasks = 0).
    *   *When:* Hệ thống tính toán tiến độ kế hoạch hiển thị trên Dashboard.
    *   *Then:* Chỉ số tiến độ hiển thị là `0%` mà không gặp lỗi hiển thị `undefined` hoặc lỗi crash ứng dụng.

---

## 8. Bảng Truy Xuất Nguồn Gốc (Traceability Matrix)

| Mã Yêu Cầu (Requirement ID) | Phân hệ / Luồng (Flow) | Mã Màn Hình (Screen ID) | Khái Niệm Miền (Domain Concept) | Quyết Định Thiết Kế (Discovery Decision) | Mã Tiêu Chí Nghiệm Thu (Acceptance Criteria) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **PLN-FR-001** | REQ-02.1 | AND-PLA-03 | `Task` | Cho phép tạo công việc chung cấp đám cưới | - |
| **PLN-FR-002** | REQ-02.1 | AND-PLA-03 | - | Tránh mất dữ liệu nháp đang nhập trên app | - |
| **PLN-FR-003** | REQ-02.2 | AND-PLA-02 | `Task` | Reopen Task gợi ý tự động recalculate theo ngày cưới mới | PLN-AC-001, PLN-AC-005 |
| **PLN-FR-004** | REQ-02.2 | AND-PLA-02 | `Task` | Cho phép khôi phục công việc đã hủy về TODO | - |
| **PLN-FR-005** | REQ-02.3 | AND-PLA-06 | `Task` | Tự động dịch chuyển User-managed Relative mà không bắt duyệt thủ công | PLN-AC-002 |
| **PLN-FR-006** | REQ-02.3 | AND-PLA-06 | - | Hỗ trợ Batch action khi review dời lịch | - |
| **PLN-FR-007** | REQ-02.4 | AND-PLA-07 | `WeddingEvent` | Không tự xóa Task đã sửa/xong khi xóa Event | PLN-AC-003 |
| **PLN-FR-008** | REQ-02.4 | AND-PLA-04 | `WeddingEvent` | Khóa nút xóa nếu là sự kiện chính cuối cùng | PLN-AC-013 |
| **PLN-FR-009** | REQ-02.5 | AND-HOM-01 | `Task` | Tiến độ kế hoạch tính toán động từ DB | PLN-AC-004, PLN-AC-014 |
