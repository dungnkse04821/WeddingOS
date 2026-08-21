# Mô Hình Hóa Miền Nghiệp Vụ (Domain Model) - WeddingOS

Tài liệu này đặc tả Mô hình miền nghiệp vụ (Domain Model) của WeddingOS dựa trên các quyết định sản phẩm đã được phê duyệt ở giai đoạn Discovery và các phản hồi chốt thiết kế từ Product Owner. Mô hình này phục vụ thiết kế kiến trúc phần mềm, bảo toàn các quy tắc nghiệp vụ (Invariants) và ngôn ngữ nghiệp vụ thống nhất (Ubiquitous Language).

---

## 1. Thuật Ngữ Nghiệp Vụ (Ubiquitous Language Glossary)

Dưới đây là glossary chuẩn hóa cho toàn hệ thống:

| Tiếng Anh Nghiệp vụ (Domain Term) | Tiếng Việt Giao diện (UX Term) | Phân loại Khái niệm | Định nghĩa Nghiệp vụ & Phạm vi |
| :--- | :--- | :--- | :--- |
| **Wedding** | Đám cưới | Domain Concept | Thực thể gốc đại diện cho không gian cưới (Workspace). Chứa cấu hình tổng thể của đám cưới. |
| **WeddingMember** | Thành viên | Domain Concept | Thực thể liên kết giữa tài khoản người dùng (`User`) và một Đám cưới (`Wedding`) kèm theo Vai trò (Role). |
| **WeddingEvent** | Sự kiện | Domain Concept | Một nghi lễ hoặc tiệc cụ thể (Ăn hỏi, Cưới...) thuộc Đám cưới. |
| **Cultural Context** | Phong tục tổ chức | Domain Concept | Cấu hình phong tục vùng miền (Bắc/Trung/Nam/Tùy chọn) quyết định các gợi ý sự kiện và công việc. |
| **Side** | Phía gia đình | Domain Concept | Thuộc tính phân loại bên nhà (`COMMON` - Chung, `BRIDE_SIDE` - Nhà gái, `GROOM_SIDE` - Nhà trai) áp dụng cho Task, Guest, Budget Item. |
| **Task** | Công việc | Domain Concept | Đơn vị kế hoạch nhỏ nhất (Task phẳng, không hỗ trợ Checklist/Subtask). |
| **Task Source** | Nguồn công việc | Domain Concept | Nguồn gốc tạo ra Task (`System` - Mẫu hệ thống, `AI` - AI gợi ý, `User` - Tự tạo). |
| **Assignee** | Người thực hiện | Domain Concept | Người chịu trách nhiệm hoàn thành Task. Tách biệt với thuộc tính `Side`. |
| **Relative Deadline Rule** | Hạn chót tương đối | Domain Concept | Quy tắc tính hạn chót công việc: `Event Date + Signed Offset` (ví dụ: `Ngày cưới - 30 ngày`, `Ngày cưới + 3 ngày`). |
| **Absolute Deadline** | Hạn chót cố định | Domain Concept | Ngày dương lịch cụ thể do người dùng chốt cứng cho Task. |
| **User Relative Override** | Hạn chót tương đối tùy chỉnh | Domain Concept | Người dùng đổi khoảng cách ngày relative mặc định của hệ thống nhưng vẫn muốn Task dịch chuyển theo sự kiện. |
| **Impact Review** | Rà soát tác động | UI/Domain Concept | Giao diện và luồng nghiệp vụ yêu cầu người dùng duyệt lại các Task/Dữ liệu bị ảnh hưởng khi dời ngày hoặc xóa Sự kiện. |
| **Budget** | Hạn mức ngân sách | UI Concept | Mục tiêu ngân sách tổng thể của đám cưới. Là đích tham khảo, không bắt buộc nhập. |
| **Budget Category** | Danh mục ngân sách | Domain Concept | Phân loại chi phí cưới (Tiệc cưới, Trang phục, Quay chụp...). |
| **Budget Item** | Khoản mục chi | Domain Concept | Một hạng mục chi tiêu cụ thể (ví dụ: "Thuê váy cưới"). |
| **Estimated Cost** | Dự toán | Domain Concept | Chi phí dự kiến ban đầu khi lên kế hoạch. |
| **Confirmed Cost** | Đã chốt | Domain Concept | Chi phí nghĩa vụ thực tế phải chi trả (không bắt buộc có hợp đồng). |
| **Payment Schedule** | Lịch thanh toán | Domain Concept | Kế hoạch chia đợt trả tiền cho nhà cung cấp của Khoản mục chi. |
| **Installment** | Đợt thanh toán | Domain Concept | Một đợt chi trả cụ thể trong lịch (Số tiền + Hạn chót + Trạng thái). |
| **Payment** | Giao dịch thanh toán | Domain Concept | Bản ghi ghi nhận dòng tiền ra thực tế (Số tiền, Ngày chuyển, Payer). |
| **Refund** | Giao dịch hoàn tiền | Domain Concept | Bản ghi ghi nhận dòng tiền nhận lại thực tế (luồng UI nhập dương, technical lưu âm). |
| **Payer** | Người thanh toán | Domain Concept | Người trực tiếp bỏ tiền chi trả cho từng giao dịch `Payment` (Cô dâu, Chú rể, Bố mẹ...). |
| **Outstanding** | Còn phải trả | Derived Concept | Số tiền còn nợ nhà cung cấp. Bằng `Đã chốt - Tổng đã thanh toán ròng`. Chỉ tính khi có giá trị *Đã chốt*. |
| **Responsible Person** | Người phụ trách chi | UI Concept | Người liên hệ và chịu trách nhiệm làm việc với nhà cung cấp cho khoản chi đó. |
| **Guest** | Khách mời | Domain Concept | Một cá nhân được thêm vào đám cưới để mời. Lưu thông tin liên lạc trực tiếp (không có global Contact). |
| **Guest Source** | Nguồn khách | Domain Concept | Nhãn phân loại nguồn danh sách khách (Bride, Groom, Bố mẹ hai bên, Khác). |
| **Primary Group** | Nhóm khách mời | Domain Concept | Nhóm quan hệ của khách mời (Bạn học, đồng nghiệp...). Liên kết Nhiều-Một. |
| **Invitation Party** | Nhóm lời mời | Domain Concept | Hộ gia đình/Nhóm người nhận chung 1 RSVP (Ví dụ: "Gia đình bác Tư"). |
| **Invited Count** | Số người được mời | Domain Concept | Hạn mức số lượng người mời tối đa hiển thị trên thiệp cưới của một nhóm mời. |
| **Invitation** | Lời mời | Domain Concept | Thực thể đại diện cho tấm thiệp online. Gắn liền với token truy cập ngẫu nhiên. |
| **Invitation Token** | Mã thiệp mời | Domain Concept | Token bảo mật tạo link `/invite/{token}`. Tái tạo token không làm thay đổi Lời mời hay RSVP cũ. |
| **RSVP** | Phản hồi | Domain Concept | Bản ghi câu trả lời tham dự của một Nhóm lời mời. |
| **Event Response** | Phản hồi sự kiện | Domain Concept | Trạng thái tham dự (`Attending/Not`) và số người đi kèm (`Attending Count`) riêng biệt cho từng Sự kiện được mời. |
| **RSVP Cutoff** | Hạn chót RSVP | Domain Concept | Ngày chốt chặn toàn đám cưới, sau ngày này khách không được tự sửa RSVP trực tuyến. |
| **Tracking Signal** | Tín hiệu theo dõi | Technical Concept | Các mốc thời gian phụ trợ theo dõi thiệp cưới (`SentAt`, `FirstViewedAt`, `LastViewedAt`). |

*Chú ý phân biệt:*
*   `Side` (Phía gia đình của công việc/khách mời) $\neq$ `Payer` (Người bỏ tiền thanh toán thực tế cho từng giao dịch).
*   `Guest` (Cá nhân cụ thể) $\neq$ `Invitation Party` (Thực thể đại diện hộ gia đình nhận thiệp).
*   `Invited Count` (Số người được mời trên thiệp) $\neq$ `Attending Count` (Số người xác nhận đi thực tế qua RSVP).

---

## 2. Phân Vùng Nghiệp Vụ (Domain Areas)

Hệ thống được chia làm 5 phân vùng nghiệp vụ chính:
1.  **Wedding Core (Lõi Đám cưới):** Quản lý cấu hình đám cưới, thành viên đám cưới và các sự kiện con.
2.  **Planning (Lập Kế hoạch):** Quản lý công việc, ngày hạn chót và luồng dời lịch.
3.  **Finance (Tài chính):** Quản lý ngân sách, khoản mục chi, đợt thanh toán, và các giao dịch thực tế.
4.  **Guest Management (Quản lý Khách mời):** Quản lý hồ sơ khách mời riêng biệt, nhóm khách mời và cấu trúc hộ gia đình nhận thiệp.
5.  **Invitation & RSVP (Lời mời & Phản hồi):** Quản lý thiệp mời điện tử, bảo mật link và tiếp nhận thông tin phản hồi từ khách.

---

## 3. Ranh Giới Aggregate Định Hình Theo Tính Nhất Quán Giao Dịch (Aggregate Boundaries)

Nhằm tối ưu hóa hiệu năng, giảm thiểu tranh chấp khóa (lock) dữ liệu trên môi trường di động và đáp ứng nghiệp vụ đặc thù (như gộp/tách khách), WeddingOS chia nhỏ ranh giới Aggregate như sau:

```
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    WEDDING CORE BOUNDARY                                     │
│  [Wedding] (Root)              [WeddingEvent] (Root)              [WeddingMember] (Root)     │
└──────────────────────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────┐      ┌────────────────────────┐      ┌──────────────────────────────┐
│    PLANNING BOUNDARY   │      │    FINANCE BOUNDARY    │      │    GUEST LIST BOUNDARY       │
│  [Task] (Root)         │      │  [Budget Item] (Root)  │      │  [Guest] (Root)              │
│                        │      │   ├── [Installment]    │      │                              │
│                        │      │   ├── [Payment]        │      │  [Invitation Party] (Root)   │
│                        │      │   └── [Refund]         │      │   └── GuestId[] (Ref)        │
└────────────────────────┘      └────────────────────────┘      └──────────────┬───────────────┘
                                                                               │
                                                                               ▼
                                                                ┌──────────────────────────────┐
                                                                │  INVITATION & RSVP BOUNDARY  │
                                                                │  [Invitation] (Root)         │
                                                                │   └── [RSVP]                 │
                                                                │        └── [EventResponse]   │
                                                                └──────────────────────────────┘
```

### A. Wedding Core: Chia nhỏ Wedding, Event và Member
*   **Wedding Aggregate (Root: `Wedding`):** Quản lý thông tin chung (Tên, Target Budget, Expected Month, Exact Date, Phong tục tổ chức, RSVP Cutoff Date).
*   **Wedding Event Aggregate (Root: `WeddingEvent`):** Tách ra làm Aggregate Root riêng biệt tham chiếu tới `WeddingId`. Giúp việc CRUD các sự kiện không cần khóa toàn bộ cấu hình chung của đám cưới.
*   **Membership Aggregate (Root: `WeddingMember`):** Tách biệt làm Aggregate Root độc lập liên kết `UserId` và `WeddingId`. Tránh tranh chấp khi thêm/xóa thành viên phụ trách hoặc chỉnh sửa quyền của họ.

### B. Planning: Task Aggregate (Root: `Task`)
*   **Đặc tả:** Mỗi `Task` là một Aggregate Root riêng biệt. Tham chiếu đến `WeddingId`, `WeddingEventId`, và `AssigneeId` thông qua định danh dạng ID.
*   **Quy tắc:** Mọi thay đổi về tiến độ, phân công, hạn chót tương đối/tuyệt đối chỉ diễn ra gói gọn trong 1 bản ghi Task duy nhất.

### C. Finance: Budget Item Aggregate (Root: `BudgetItem`)
*   **Đặc tả:** `BudgetItem` làm Aggregate Root. Chứa thực thể nội bộ `Installment` (Đợt thanh toán), `Payment` (Giao dịch ra), và `Refund` (Giao dịch hoàn tiền vào). Tham chiếu đến `WeddingId` và `WeddingEventId`.
*   **Lý do ranh giới:** Cần sự nhất quán đồng thì (Atomic Consistency) để tổng tiền thanh toán ròng (`Net Paid = Payments - Refunds`) và công nợ còn lại (`Outstanding = Confirmed - Net Paid`) luôn được tính toán chính xác tuyệt đối mỗi khi có bất kỳ giao dịch nào được ghi nhận.

### D. Guest List: Chia tách Guest và Invitation Party
*   **Guest Aggregate (Root: `Guest`):** Mỗi khách mời là một Aggregate Root độc lập chứa thông tin liên lạc (Họ tên, SĐT), Bên nhà (`Side`), Nhóm chính (`Primary Group`), và Nguồn khách (`Guest Source`). Tham chiếu đến `WeddingId` và `InvitationPartyId`.
*   **Invitation Party Aggregate (Root: `InvitationParty`):** Thực thể đại diện hộ gia đình/nhóm mời. Làm Aggregate Root quản lý danh sách tham chiếu `GuestId[]`, Tên hiển thị nhóm mời, và Hạn mức số lượng người mời (`Invited Count`).
    *   *Lý do tách biệt:* Giúp luồng Gộp (Merge) hoặc Tách (Split) khách mời diễn ra dễ dàng bằng cách cập nhật ID tham chiếu mà không phải viết lại cấu trúc dữ liệu của toàn bộ hộ gia đình. Tăng tính concurrency khi cặp đôi chỉnh sửa thông tin một khách mời độc lập khi khách đó đang RSVP.

### E. Invitation & RSVP: Active Web Boundary (Root: `Invitation`)
*   **Đặc tả:** `Invitation` làm Aggregate Root. Chứa thực thể nội bộ `RSVP` và mảng giá trị `EventResponse` (Phản hồi chi tiết theo từng sự kiện). Tham chiếu đến `InvitationPartyId` và các sự kiện nhắm mục tiêu `WeddingEventId[]`.
*   **Lý do ranh giới:** Đây là ranh giới tiếp nhận giao dịch từ Web của khách mời (Guest-facing active interface). Tách riêng giúp các thao tác cập nhật RSVP từ bên ngoài không đụng chạm tới cấu trúc quản lý khách mời (Guest/Party) phía cặp đôi, tránh xung đột ghi dữ liệu.

---

## 4. Bản Đồ Liên Kết Nghiệp Vụ (Relationship Map)

Bản đồ này mô tả mối liên kết logic cấp nghiệp vụ (không đồng nghĩa với kho khóa ngoại Database Foreign Key):
*   `Wedding` $\rightarrow$ `WeddingEvent` *(Tham chiếu qua WeddingId)*
*   `Wedding` $\rightarrow$ `WeddingMember` *(Tham chiếu qua WeddingId)*
*   `Task` $\rightarrow$ `WeddingEvent` *(Tham chiếu qua WeddingEventId - Tùy chọn)*
*   `BudgetItem` $\rightarrow$ `WeddingEvent` *(Tham chiếu qua WeddingEventId - Tùy chọn)*
*   `InvitationParty` $\rightarrow$ `Guest` *(Tham chiếu qua danh sách GuestId[])*
*   `Invitation` $\rightarrow$ `InvitationParty` *(Tham chiếu qua InvitationPartyId)*
*   `Invitation` $\rightarrow$ `WeddingEvent` *(Tham chiếu qua danh sách WeddingEventId[])*
*   `Task` $\rightarrow$ `WeddingMember` *(Tham chiếu người phụ trách AssigneeId - Tùy chọn)*

---

## 5. Quy Tắc Nghiệp Vụ Cố Định Cuối Cùng (Final Domain Invariants)

| Mã Quy tắc | Quy tắc nghiệp vụ | Phân vùng Aggregate chịu trách nhiệm |
| :--- | :--- | :--- |
| **INV-PLAN-01** | Ngày cưới dời đổi (Event Date Change) bắt buộc phải bỏ qua các Task đã hoàn thành (`COMPLETED`). Hạn chót lịch sử và thông tin hoàn thành được bảo toàn tuyệt đối. | `Task Aggregate` |
| **INV-PLAN-02** | Công việc đã sửa tay (User-managed Task) không được tự ý dịch chuyển hạn chót khi Sự kiện đổi ngày. | `Task Aggregate` |
| **INV-PLAN-03** | Khi xóa một Sự kiện con, hệ thống không được tự động xóa các công việc do người dùng tự tạo hoặc đã chỉnh sửa nếu chưa qua rà soát tác động (Impact Review). | `Task Aggregate` (phối hợp qua Workflow) |
| **INV-FIN-01** | Số tiền còn nợ (`Outstanding`) tuyệt đối không được tự tính toán từ số tiền *Dự toán (Estimate)* nếu chưa chốt giá trị thực tế (*Confirmed Cost*). | `BudgetItem Aggregate` |
| **INV-FIN-02** | Một giao dịch thanh toán (`Payment`) chỉ thuộc về duy nhất một Khoản chi (`BudgetItem`), không phân bổ cho nhiều khoản chi trong MVP. | `BudgetItem Aggregate` |
| **INV-FIN-03** | Phân tách Cost Side (`COMMON`/`BRIDE_SIDE`/`GROOM_SIDE`) ở cấp Khoản chi và Người thanh toán (`Payer`) ở cấp Giao dịch thanh toán. | `BudgetItem Aggregate` |
| **INV-GUEST-01**| Gộp khách trùng SĐT chuẩn hóa bắt buộc phải qua luồng Impact Review để người dùng tự chốt thiệp mời đích, không tự động gộp dữ liệu. | `Guest & Party Aggregate` (qua Workflow) |
| **INV-GUEST-02**| Số người được mời (`Invited Count`) là ràng buộc mềm, không khóa cứng số lượng điền trên form RSVP của khách. | `Invitation Aggregate` (đối chiếu Invited Count) |
| **INV-GUEST-03**| Việc tái tạo Token truy cập thiệp mới không được làm mất lịch sử gửi thiệp hay nội dung phản hồi RSVP cũ của tấm thiệp đó. | `Invitation Aggregate` |
| **INV-GUEST-04**| Phản hồi RSVP và số lượng đi kèm (`Attending Count`) phải được phân tách độc lập theo từng Sự kiện con được mời. | `Invitation Aggregate` |
| **INV-GUEST-05**| Link thiệp mời của khách không bao giờ được hiển thị danh sách khách mời khác, số điện thoại của khách khác hoặc dữ liệu kế hoạch/tài chính nội bộ. | `Invitation Aggregate` |
| **INV-GUEST-06**| Một chi phí chung phục vụ nhiều sự kiện con (ví dụ: quay chụp trọn gói) được lưu ở dạng Khoản chi cấp Đám cưới (Wedding-level BudgetItem với WeddingEvent = NONE) để tránh ép người dùng chia nhỏ hợp đồng. | `BudgetItem Aggregate` |

---

## 6. Các Luồng Nghiệp Vụ Phối Hợp Liên Aggregate (Cross-domain Workflows)

### A. Quy trình Dời ngày Sự kiện (Event Date Change Workflow)
1.  Người dùng dời ngày sự kiện `WeddingEvent` từ ngày T1 sang ngày T2.
2.  Hệ thống kích hoạt quy trình dời ngày:
    *   Truy vấn các `Task` liên kết với `WeddingEventId` này.
    *   Tự động dịch chuyển hạn chót đối với Task nhóm A (Chưa sửa hạn chót tương đối).
    *   Bỏ qua toàn bộ Task ở trạng thái `COMPLETED` (Bảo lưu ngày cũ).
    *   Gắn nhãn cảnh báo tác động cho các Task nhóm B & C (Đã sửa hạn chót tương đối hoặc chốt ngày cố định) và đưa vào màn hình Review của người dùng.

### B. Quy trình Gộp Khách trùng lặp (Guest Merge Workflow)
1.  Hệ thống phát hiện trùng SĐT chuẩn hóa, người dùng bấm chọn Gộp (Merge).
2.  Hệ thống đối chiếu hai Nhóm lời mời (`InvitationParty`) tương ứng.
3.  Kích hoạt màn hình Review: Người dùng chọn giữ lại Party A hoặc Party B (hoặc tạo Party mới).
4.  Hợp nhất thông tin cá nhân của 2 `Guest`, cập nhật ID tham chiếu của Guest về Party được chọn, cập nhật lại tên hiển thị và hạn mức mời `Invited Count` của Party đích, sau đó vô hiệu hóa bản ghi Guest trùng.
5.  Nếu Party cũ trở thành trống nhưng đã có lịch sử RSVP/gửi thiệp, hệ thống giữ lại Party rỗng này (không tự động xóa sạch) và hiển thị gợi ý dọn dẹp thủ công.

---

## 7. Các Cân Nhắc Kỹ Thuật Được Hoãn Lại (Deferred Technical Architecture Concerns)

Để bảo đảm Domain Model hoàn toàn trung lập với công nghệ và hạ tầng, các quyết định sau đây được hoãn lại và chuyển giao cho giai đoạn Thiết kế Kiến trúc kỹ thuật:
*   *Phương thức dựng trang Web cho khách:* Chọn Rendering động (Dynamic SSR), ứng dụng trang đơn (SPA) hay trang tĩnh (Static SSG).
*   *Nhà cung cấp hạ tầng:* Lựa chọn nhà cung cấp Database, Serverless Hosting, CDN (Cloudflare hay khác), Object Storage để đáp ứng Free-tier-first.
*   *Tích hợp thông báo:* API dịch vụ gửi Email, SMS hoặc Zalo.
*   *Phương thức kết nối:* Thiết kế RESTful API hay GraphQL, cơ chế xác thực JWT hay Sessions.

---

## 8. Các Tác Nhân Thúc Đẩy Chi Phí Hạ Tầng (Future Architecture Cost Drivers)

Dù domain model trung lập, chúng tôi nhận diện các yếu tố nghiệp vụ có thể gây tốn kém tài nguyên hạ tầng sau này để đội ngũ kỹ thuật có giải pháp thiết kế phù hợp:
1.  **Dung lượng Lưu trữ Ảnh:** Người dùng tải ảnh cưới độ phân giải cao lên thiệp online (Ảnh hưởng Object Storage cost).
2.  **Băng thông Truy cập Thiệp:** Băng thông tải thiệp online của khách mời tăng đột biến sát ngày cưới (Ảnh hưởng Data Transfer/CDN cost).
3.  **Xác thực Tài khoản:** Phí dịch vụ gửi SMS OTP hoặc gửi email kích hoạt tài khoản.
4.  **Tích hợp Bản đồ & AI:** Tần suất gọi API Google Maps hoặc các mô hình AI gợi ý kế hoạch.
