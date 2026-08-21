# Quyết Định Kiến Trúc: ADR-007 — Notifications, AI & Deferred Capabilities

*   **Mã quyết định (ADR ID):** ADR-007
*   **Trạng thái (Status):** Approved (Đã Phê duyệt)
*   **Người thực hiện:** Antigravity (AI Architect)
*   **Ngày cập nhật:** 20/08/2026

---

## 1. Ngữ Cảnh (Context)

Hệ thống WeddingOS MVP được thiết kế theo định hướng ứng dụng di động Android cho ban tổ chức (Android-first) và giao diện Web di động tối giản cho khách mời (Guest-facing Web).
*   **Yêu cầu gợi ý kế hoạch:** Ban đầu đề cập đến các tính năng trợ lý gợi ý kế hoạch đám cưới và hệ thống thông báo cập nhật tiến trình cho cặp đôi.
*   **Đặc tả yêu cầu chi tiết đã duyệt:** Toàn bộ các phân hệ từ `REQ-01` tới `REQ-06` đều không bắt buộc phải sử dụng Mô hình ngôn ngữ lớn (LLM/AI) cho hoạt động cốt lõi của MVP.
*   **Ràng buộc vận hành:** MVP ưu tiên các giải pháp tối giản để tối ưu hóa hạ tầng và giảm thiểu độ phức tạp tích hợp ban đầu.

Quyết định kiến trúc này nhằm xác lập ranh giới phân định rõ ràng giữa các tính năng hiện thực hóa trong MVP và các năng lực kỹ thuật được trì hoãn (Deferred Capabilities), đảm bảo không phát sinh mở rộng phạm vi thiết kế (scope creep).

---

## 2. Phạm Vi Quyết Định (Scope)

### Quyết định trong tài liệu này:
*   Mô hình kiến trúc thông báo trong ứng dụng (In-app Attention Center).
*   Đánh giá sự cần thiết của hạ tầng thông báo đẩy (Push Notifications) trong MVP.
*   Thiết lập mô hình khuyến nghị/gợi ý dựa trên luật tĩnh và bộ mẫu nội dung (Deterministic templates/rules).
*   Xác định ranh giới tích hợp LLM / Trợ lý trí tuệ nhân tạo.
*   Nguyên tắc sở hữu và phân cấp dữ liệu biểu mẫu mẫu (Template Authority).
*   Yêu cầu về đồng bộ thời gian thực (Realtime) và tiến trình chạy ngầm (Background jobs).
*   Danh mục hạ tầng kỹ thuật chính thức bị trì hoãn (Deferred Infrastructure).

### Các quyết định hoãn lại (Deferred / Out of Scope):
*   Thiết kế cấu trúc bảng lưu trữ thông báo (`Notification`) hoặc bảng cấu hình gợi ý (`Template`).
*   Lập trình chi tiết bộ luật gợi ý hoặc các câu lệnh prompt AI.
*   Cấu hình chi tiết Firebase Cloud Messaging (FCM) topics.
*   Lựa chọn nhà cung cấp mô hình LLM hoặc cấu hình Vector database/RAG.
*   Lịch trình chạy cron job cụ thể của hệ thống.

---

## 3. Các Phương Án Cấu Trúc Thông Báo Cân Nhắc (Notification Options)

### Phương án A: Chỉ sử dụng Trung tâm Cảnh báo trong ứng dụng (In-app Attention Center) (SELECTED)
*   *Đánh giá:* Các cảnh báo nghiệp vụ được tạo lập động hoặc nạp thời gian chạy khi người dùng mở hoặc làm mới ứng dụng. Phương án này hoàn toàn không yêu cầu hạ tầng server gửi tin nhắn, không cần FCM và không tốn năng lượng chạy ngầm của thiết bị di động.
*   *Phù hợp MVP:* Phù hợp nhất cho phạm vi MVP, giúp giảm thiểu độ phức tạp và tập trung vào hoạt động cốt lõi của cặp đôi.

### Phương án B: In-app Attention Center + Thông báo đẩy Android (Android Push via FCM)
*   *Đánh giá:* Hỗ trợ đẩy thông báo chủ động tới thiết bị di động của cặp đôi kể cả khi tắt ứng dụng. Tuy nhiên, phương án này yêu cầu tích hợp Firebase SDK, thiết lập hệ thống phát thông điệp chạy ngầm và cấu hình quyền trên Android, làm tăng độ phức tạp kỹ thuật không cần thiết cho validation MVP.

### Phương án C: In-app Attention Center + Gửi Email/SMS tự động
*   *Đánh giá:* Tự động gửi thông tin cập nhật hoặc thông báo mời Collaborator qua Email/SMS. Phương án này bị từ chối do phát sinh chi phí SMS gateway và yêu cầu thiết lập máy chủ SMTP ngoài vượt giới hạn miễn phí của Supabase.

---

## 4. Quyết Định Kiến Trúc Về Thông Báo & Cập Nhật Thời Gian Thực (MVP Notification & Realtime Decision)

### A. Hạ tầng thông báo MVP
*   WeddingOS MVP thống nhất **chỉ sử dụng mô hình Trung tâm Cảnh báo trong ứng dụng (In-app Attention Center)**.
*   Hệ thống **không sử dụng** Firebase Cloud Messaging (FCM) hoặc đẩy thông báo chủ động, không tự động gửi Email, và không tích hợp SMS gateway cho hoạt động thông báo.
*   Mọi thông điệp chú ý (Attention items) chỉ hiển thị trực quan khi người tổ chức chủ động mở ứng dụng Android hoặc thực hiện thao tác làm mới (Refresh/Pull-to-refresh). Không hỗ trợ đẩy chủ động (proactive device delivery) khi app đang đóng.

### B. Định nghĩa Trạng thái Chú ý (Attention vs Notification)
*   Hệ thống phân biệt rõ *Trạng thái chú ý nghiệp vụ (Business attention state)* và *Kênh truyền thông (Delivery channel)*.
*   Các cảnh báo chú ý nghiệp vụ bao gồm: Công việc trễ hạn (overdue Task), hạn cọc tiền cận kề, RSVP vượt số lượng mời, cảnh báo trùng lặp khách mời.
*   **Nguyên tắc hiển thị động (Derived-on-read):** Các cảnh báo chú ý này nên được tính toán động từ trạng thái dữ liệu miền nghiệp vụ (WeddingOS domain state) hiện hữu khi người dùng mở app bất cứ khi nào khả thi. MVP không bắt buộc xây dựng một hệ thống con thông báo đẩy chủ động riêng biệt.
*   **Trì hoãn lưu trữ trạng thái UI:** Việc lưu trữ các trạng thái tương tác UI của thông báo như: *Đã xem (seen)*, *Đã ẩn (dismissed)*, hay *Đã xác nhận (acknowledged)* có cần lưu trữ lâu dài vào cơ sở dữ liệu hay không sẽ được hoãn lại cho tầng Thiết kế Dữ liệu (Data Architecture) quyết định. Không tự ý thiết kế bảng Notification ở ADR này.

### C. Giao tiếp Thời gian thực (Realtime & Websockets)
*   Hệ thống **không sử dụng** kết nối WebSocket thời gian thực (Supabase Realtime) để đồng bộ thay đổi tức thời giữa các thành viên đang cùng mở app. 
*   Mô hình giao tiếp kéo dữ liệu thông thường (normal fetch/refetch) mỗi khi chuyển trang hoặc mở lại ứng dụng được coi là đủ đáp ứng trải nghiệm cộng tác của ban tổ chức trong MVP.
*   *Lưu ý:* Cần phân định rõ ràng giữa (1) Khả năng cập nhật nhanh trạng thái giữa các client (Realtime propagation) và (2) Cơ chế xử lý xung đột ghi đè đồng thời (Concurrent-write/Data integrity). Xung đột đồng thời vẫn phải được xử lý ở thiết kế Database/API bất kể hệ thống có dùng Realtime hay không.

---

## 5. Các Phương Án Tích Hợp Trí Tuệ Nhân Tạo (AI Options)

### Phương án A: Chỉ sử dụng bộ mẫu nội dung và luật tĩnh (Deterministic templates & rules) (SELECTED)
*   *Đánh giá:* Hệ thống sinh sẵn danh sách công việc (Task) và khoản chi tiêu tiêu chuẩn dựa trên phong tục vùng miền (Bắc/Trung/Nam) chọn lúc onboarding bằng bộ dữ liệu tĩnh lưu trong ứng dụng hoặc database. 
*   *Phù hợp MVP:* 
    *   Sản sinh đầu ra hoàn toàn có thể dự đoán được (predictable output) đối với cùng một đầu vào đầu bộ.
    *   Dễ dàng thực hiện kiểm thử tự động (testable).
    *   Không phát sinh chi phí cuộc gọi API trên mỗi lượt suy luận (no per-inference LLM API usage).
    *   Vẫn đòi hỏi quy trình cập nhật nội dung sản phẩm và kiểm chứng nghiệp vụ tương ứng (chất lượng nội dung không được coi là tự động cam kết hoàn hảo).

### Phương án B: Biểu mẫu tĩnh + Tích hợp mô hình LLM tùy chọn
*   *Đánh giá:* Sử dụng LLM để cặp đôi chat hỏi đáp hoặc tối ưu hóa lịch trình đám cưới nâng cao. Phương án này làm tăng chi phí gọi API và yêu cầu thiết lập bảo mật dữ liệu nhạy cảm PII khi gửi sang bên thứ ba, không phù hợp cho MVP validation.

### Phương án C: Trợ lý AI lập kế hoạch dựa trên LLM bắt buộc
*   *Đánh giá:* Dùng LLM để tự động sinh toàn bộ Task và Ngân sách đám cưới từ câu lệnh chat ban đầu. Phương án này chịu rủi ro về ảo giác dữ liệu tài chính nhạy cảm và độ trễ phản hồi, không khả thi.

---

## 6. Quyết Định Tích Hợp AI & Ranh Giới LLM (MVP AI & LLM Boundary Decision)

### A. Công nghệ gợi ý kế hoạch MVP
*   **WeddingOS MVP hoàn toàn không phụ thuộc vào LLM (Large Language Model).**
*   Mọi đề xuất lịch trình công việc mẫu, danh mục ngân sách mẫu, phong tục vùng miền và cảnh báo tài chính đều sử dụng **bộ dữ liệu mẫu tĩnh (deterministic templates) và bộ luật nghiệp vụ định sẵn (rule-based recommendations)**. 
*   *Ràng buộc danh xưng:* Hệ thống không gọi các gợi ý tĩnh mang tính chất luật nghiệp vụ này là "trí tuệ nhân tạo tạo sinh" (generative AI) để tránh gây hiểu lầm.

### B. Quyền lực của bộ mẫu nội dung (Template Authority)
*   Bộ biểu mẫu và quy tắc gợi ý là tài sản nội dung của sản phẩm (application-owned content). Chúng phải có khả năng cập nhật phiên bản thông qua các bản phát hành ứng dụng hoặc cập nhật database tĩnh từ máy chủ.
*   **Tôn trọng lựa chọn của người dùng:** Khi người dùng đã chỉnh sửa hoặc tùy biến (Customized) một công việc hoặc khoản chi tiêu mẫu, hệ thống gợi ý **tuyệt đối không được phép tự ý ghi đè** (overwrite) hoặc thay đổi nội dung đó dựa trên luật gợi ý.

### C. Ranh giới LLM trong tương lai (Future LLM Boundary)
*   Nếu LLM được tích hợp ở các phiên bản sau, nó chỉ đóng vai trò đề xuất hoặc khuyến nghị (propose/recommend). 
*   **Tuyệt đối không cấp quyền cho LLM tự động thực thi các hành động ghi nhạy cảm** (ghi tiền Payment, hoàn tiền Refund, thay đổi RSVP, xóa thành viên Wedding membership, xóa sự kiện Event removal, thay đổi quyền hạn) mà không có sự xác nhận thủ công (explicit user action) từ người dùng và kiểm chứng từ máy chủ tin cậy (trusted business validation).

### D. Quyền riêng tư dữ liệu (AI Privacy)
*   Do không sử dụng LLM, WeddingOS MVP **không gửi bất kỳ thông tin cá nhân (PII)** hay dữ liệu tài chính nhạy cảm nào của cặp đôi và khách mời tới các nhà cung cấp mô hình trí tuệ nhân tạo bên thứ ba. Việc tích hợp AI ngoài ở các giai đoạn sau bắt buộc phải có một quyết định kiến trúc bảo mật độc lập.

---

## 7. Tiến Trình Chạy Ngầm Hệ Thống (Background Jobs)

*   **Không chạy ngầm liên tục:** Để duy trì hạ tầng tối giản, hệ thống **không triển khai các tác vụ chạy ngầm định kỳ** (scheduled background cron jobs) trên server để quét dữ liệu tạo cảnh báo trong MVP.
*   **Đọc thời gian chạy (Derived-on-read):** Các cảnh báo chú ý của Attention Center được tính toán động ngay khi ban tổ chức nạp/tải lại trang (read-time processing), không cần thiết kế hệ thống cron chạy nền liên tục.
*   Nếu ở giai đoạn phát triển phát sinh yêu cầu bắt buộc phải chạy background job thực tế (như kiểm tra khóa RSVP đúng 00:00 hàng ngày), trường hợp này sẽ được gắn nhãn `Needs Further Architecture Decision` để thiết kế một giải pháp chuyên biệt.

---

## 8. Danh Mục Hạ Tầng Bị Trì Hoãn (Deferred Infrastructure)

Để bảo vệ giới hạn hạ tầng và tiến độ phát triển, các hạ tầng kỹ thuật sau **chính thức bị trì hoãn** và không được thiết kế hay nhúng vào mã nguồn MVP:
1.  Hạ tầng thông báo đẩy Firebase Cloud Messaging (FCM) / Mobile Push Notifications.
2.  Nhà cung cấp dịch vụ gửi Email chuyên nghiệp (SMTP server ngoài).
3.  SMS Gateway chuyển phát tin nhắn xác thực/mời.
4.  Cấu hình realtime socket connection liên tục (Supabase Realtime).
5.  Hạ tầng scheduler / Cron jobs chạy ngầm trên máy chủ.
6.  Các thư viện và API kết nối LLM (OpenAI, Gemini API...).
7.  Vector Database, Embeddings model, và các khung đại lý AI (AI Agent frameworks).

---

## 9. Điểm Kích Hoạt Đánh Giá Lại (Reconsideration Triggers)

Kiến trúc sẽ xem xét lại quyết định trì hoãn khi:
*   *Đối với Push Notifications:* Khi khảo sát thực tế và phân tích hành vi (Product Analytics) chứng minh người dùng bỏ lỡ nghiêm trọng các hành động nhạy cảm thời gian do việc chỉ dùng thông báo trong app là không đủ.
*   *Đối với LLM:* Khi luật tĩnh không đáp ứng được nhu cầu lập lịch trình cho các đám cưới phức tạp đặc thù và khảo sát thực tế chứng minh người dùng cần trợ lý dạng hội thoại tự nhiên.
*   *Đối với Email/SMS:* Có yêu cầu bắt buộc từ sản phẩm phải gửi thiệp tự động qua tin nhắn di động trực tiếp.
*   *Đối với Realtime:* Khi trải nghiệm cộng tác nhiều thiết bị phát sinh độ lệch hiển thị dữ liệu (stale state) đáng kể mà cơ chế refetch thông thường không xử lý tốt.

---

## 10. Hệ Quả Kiến Trúc (Consequences)

### Hệ quả Tích cực:
*   Kiến trúc hệ thống cực kỳ tinh gọn, giảm tối đa các điểm lỗi (failure points).
*   Không tốn chi phí vận hành máy chủ SMTP, SMS hay LLM API $\rightarrow$ Đảm bảo duy trì gói miễn phí vô thời hạn trong giai đoạn validation.
*   Hệ thống gợi ý hoạt động độc lập, chính xác và dễ dàng kiểm thử.
*   Bảo vệ dữ liệu riêng tư tuyệt đối, tránh rò rỉ PII sang mô hình AI bên ngoài.

### Hệ quả Tiêu cực:
*   Ban tổ chức bắt buộc phải mở app di động lên mới xem được các cảnh báo quá hạn hay thay đổi RSVP.
*   Không có kênh nhắc nhở chủ động (như SMS hay Email) tới khách mời khi cận kề ngày cưới mà họ chưa RSVP.
*   Các gợi ý kế hoạch mang tính khuôn mẫu tĩnh, kém linh hoạt sinh động hơn so với hội thoại tự nhiên của LLM.
