# Chỉ Mục Yêu Cầu Chi Tiết (Requirements Index) - WeddingOS

Tài liệu này đóng vai trò là chỉ mục và hướng dẫn chung cho toàn bộ các yêu cầu phần mềm chi tiết (Detailed Requirements) của dự án WeddingOS.

---

## 1. Cấu Trúc Yêu Cầu (Requirement Structure)

Mỗi phân hệ yêu cầu được tổ chức chi tiết theo cấu trúc:
1.  **Feature / Flow:** Tên và luồng nghiệp vụ.
2.  **Goal & Actors:** Mục tiêu kinh doanh/người dùng và tác nhân tham gia.
3.  **Preconditions & Trigger:** Điều kiện trước khi bắt đầu và tác nhân kích hoạt luồng.
4.  **Main Flow & Alternate Flows:** Kịch bản luồng chính từng bước và các luồng rẽ nhánh quan trọng.
5.  **Functional Requirements (WED-FR-xxx / PLN-FR-xxx / FIN-FR-xxx / GUE-FR-xxx / INV-FR-xxx / XCT-FR-xxx):** Yêu cầu chức năng có thể kiểm thử độc lập, tham chiếu trực tiếp đến Screen ID và Domain Concept.
6.  **Business Rules (WED-BR-xxx / PLN-BR-xxx / FIN-BR-xxx / GUE-BR-xxx / INV-BR-xxx / XCT-BR-xxx):** Các quy tắc nghiệp vụ cố định phải tuân thủ.
7.  **Acceptance Criteria (WED-AC-xxx / PLN-AC-xxx / FIN-AC-xxx / GUE-AC-xxx / INV-AC-xxx / XCT-AC-xxx):** Tiêu chí nghiệm thu kiểm thử (Gồm các kịch bản kiểm thử hành vi Given/When/Then).
8.  **Validation Rules (WED-VAL-xxx / PLN-VAL-xxx / FIN-VAL-xxx / GUE-VAL-xxx / INV-VAL-xxx / XCT-VAL-xxx):** Quy tắc kiểm tra tính hợp lệ dữ liệu đầu vào.
9.  **Edge Cases & Error/Recovery Behavior (WED-ERR-xxx / PLN-ERR-xxx / FIN-ERR-xxx / GUE-ERR-xxx / INV-ERR-xxx / XCT-ERR-xxx):** Các trường hợp biên và kịch bản xử lý/khôi phục khi gặp lỗi.
10. **Traceability Matrix:** Bảng truy xuất nguồn gốc liên kết ID yêu cầu với Screen ID, Domain Concept và Quyết định Discovery.

---

## 2. Quy Ước Đặt Mã Định Danh (ID Convention)

Hệ thống mã định danh yêu cầu được quy ước thống nhất để tránh trùng lặp xuyên suốt dự án:
*   `WED-FR-xxx`, `PLN-FR-xxx`, `FIN-FR-xxx`, `GUE-FR-xxx`, `INV-FR-xxx`, `XCT-FR-xxx`: Yêu cầu Chức năng (Functional Requirement) - bắt đầu từ `001` tăng dần theo từng phân hệ.
*   `WED-BR-xxx`, `PLN-BR-xxx`, `FIN-BR-xxx`, `GUE-BR-xxx`, `INV-BR-xxx`, `XCT-BR-xxx`: Quy tắc Nghiệp vụ (Business Rule) - bắt đầu từ `001` tăng dần.
*   `WED-AC-xxx`, `PLN-AC-xxx`, `FIN-AC-xxx`, `GUE-AC-xxx`, `INV-AC-xxx`, `XCT-AC-xxx`: Tiêu chí Nghiệm thu (Acceptance Criterion) - bắt đầu từ `001` tăng dần.
*   `WED-VAL-xxx`, `PLN-VAL-xxx`, `FIN-VAL-xxx`, `GUE-VAL-xxx`, `INV-VAL-xxx`, `XCT-VAL-xxx`: Quy tắc Hợp lệ dữ liệu (Validation Rule) - bắt đầu từ `001` tăng dần.
*   `WED-ERR-xxx`, `PLN-ERR-xxx`, `FIN-ERR-xxx`, `GUE-ERR-xxx`, `INV-ERR-xxx`, `XCT-ERR-xxx`: Xử lý Lỗi và Khôi phục (Error/Recovery Behavior) - bắt đầu từ `001` tăng dần.

*Chú ý:* Không reset chỉ số ID về `001` giữa các màn hình/tài liệu khác nhau trong cùng một phân hệ để bảo đảm tính duy nhất.

---

## 3. Trạng Thái Trực Quan Của Phân Hệ Yêu Cầu (Requirements Status Index)

| Phân hệ Yêu cầu | Tài liệu | Trạng thái Hiện tại | Ghi chú / Trạng thái Phê duyệt |
| :--- | :--- | :--- | :--- |
| **REQ-01: Wedding Foundation** | [01-wedding-foundation.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/requirements/01-wedding-foundation.md) | 🟢 **Đã Phê duyệt (Approved)** | Phê duyệt chính thức bởi Product Owner |
| **REQ-02: Planning** | [02-planning.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/requirements/02-planning.md) | 🟢 **Đã Phê duyệt (Approved)** | Phê duyệt chính thức bởi Product Owner |
| **REQ-03: Finance** | [03-finance.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/requirements/03-finance.md) | 🟢 **Đã Phê duyệt (Approved)** | Phê duyệt chính thức bởi Product Owner |
| **REQ-04: Guest Management** | [04-guest-management.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/requirements/04-guest-management.md) | 🟢 **Đã Phê duyệt (Approved)** | Phê duyệt chính thức bởi Product Owner |
| **REQ-05: Invitation & RSVP** | [05-invitation-rsvp.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/requirements/05-invitation-rsvp.md) | 🟢 **Đã Phê duyệt (Approved)** | Phê duyệt chính thức bởi Product Owner |
| **REQ-06: Cross-cutting** | [06-cross-cutting.md](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/requirements/06-cross-cutting.md) | 🟢 **Đã Phê duyệt (Approved)** | Phê duyệt chính thức bởi PO (Hiệu chỉnh bổ sung AMEND-REQ-06-001 — Đã Phê duyệt) |
