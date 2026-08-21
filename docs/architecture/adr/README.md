# Mục Lục Quyết Định Kiến Trúc (Architecture Decision Records Index)

Tài liệu này ghi nhận chỉ mục các Quyết định Kiến trúc (ADR) của hệ thống WeddingOS.

---

## 1. Chỉ Mục Quyết Định Kiến Trúc (ADR Index)

### [ADR-001] Client Platform & Flutter
*   **Trạng thái (Status):** 🟢 **Approved (Đã Phê duyệt)**
*   **Yêu cầu/Động lực ảnh hưởng (Requirements/Drivers affected):** DRV-01 (Android-first), Constraints (Android-first, no desktop/web organizer MVP).
*   **Câu hỏi quyết định chính (Key decision questions):** Lựa chọn công nghệ di động nào để xây dựng ứng dụng ban tổ chức WeddingOS tối ưu tiến độ phát triển của nhóm nhỏ và đảm bảo hiệu năng UI tốt trên hệ điều hành Android?

### [ADR-002] Backend Platform & PostgreSQL
*   **Trạng thái (Status):** 🟢 **Approved (Đã Phê duyệt)**
*   **Yêu cầu/Động lực ảnh hưởng (Requirements/Drivers affected):** DRV-03 (Free-tier-first), DRV-05 (Finance integrity), Database Category.
*   **Câu hỏi quyết định chính (Key decision questions):** Lựa chọn mô hình backend (BaaS vs Traditional Server) và hệ quản trị cơ sở dữ liệu nào để đáp ứng toàn vẹn giao dịch tài chính nhạy cảm và giảm thiểu chi phí cố định?

### [ADR-003] Trust Boundary, Authorization & RLS
*   **Trạng thái (Status):** 🟢 **Approved (Đã Phê duyệt)**
*   **Yêu cầu/Động lực ảnh hưởng (Requirements/Drivers affected):** DRV-04 (Isolation & Tenant Privacy), REQ-06 (Authorization Roles).
*   **Câu hỏi quyết định chính (Key decision questions):** Làm thế nào để cô lập tuyệt đối dữ liệu giữa các đám cưới ở tầng DB và xác thực quyền kiểm soát hành động ghi nhạy cảm trên máy chủ tin cậy thay vì chỉ ẩn nút ở client?

### [ADR-004] Organizer Authentication
*   **Trạng thái (Status):** 🟢 **Approved (Đã Phê duyệt)**
*   **Yêu cầu/Động lực ảnh hưởng (Requirements/Drivers affected):** REQ-06 (Authentication & Identity), DRV-03 (Free-tier-first).
*   **Câu hỏi quyết định chính (Key decision questions):** Phương thức xác thực danh tính nào cho ban tổ chức đáp ứng trải nghiệm mượt mà trên Android và hoàn toàn miễn phí lâu dài?

### [ADR-005] Guest Web & Public Invitation API
*   **Trạng thái (Status):** 🟡 **In Review (Đang Đánh giá)**
*   **Yêu cầu/Động lực ảnh hưởng (Requirements/Drivers affected):** DRV-02 (Guest-facing Web), REQ-05 (Invitation & RSVP).
*   **Câu hỏi quyết định chính (Key decision questions):** Cấu trúc dựng và host trang Web khách mời như thế nào để tối ưu tốc độ tải trang di động và bảo vệ dữ liệu RSVP/cá nhân hóa qua API?

### [ADR-006] Storage, Media & Import/Export
*   **Trạng thái (Status):** 🟡 **In Review (Đang Đánh giá)**
*   **Yêu cầu/Động lực ảnh hưởng (Requirements/Drivers affected):** DRV-06 (Excel Import/Export), REQ-06 (Media constraints).
*   **Câu hỏi quyết định chính (Key decision questions):** Xử lý lưu trữ hình ảnh tối ưu băng thông di động và phân tích cú pháp tệp Excel nhập khách mời ở client hay server để tránh quá tải tài nguyên miễn phí?

### [ADR-007] Notifications, AI & Deferred Capabilities
*   **Trạng thái (Status):** 🟢 **Approved (Đã Phê duyệt)**
*   **Yêu cầu/Động lực ảnh hưởng (Requirements/Drivers affected):** Constraints (No SMS, no paid maps API), REQ-02 (AI recommendations).
*   **Câu hỏi quyết định chính (Key decision questions):** Làm thế nào để triển khai hệ thống thông báo, chỉ đường bản đồ và gợi ý lịch trình đám cưới thông minh với chi phí $0$ đ?
