# Quyết Định Kiến Trúc: ADR-001 — Client Platform & Flutter

*   **Mã quyết định (ADR ID):** ADR-001
*   **Trạng thái (Status):** Approved (Đã Phê duyệt)
*   **Người thực hiện:** Antigravity (AI Architect)
*   **Ngày cập nhật:** 20/08/2026

---

## 1. Ngữ Cảnh Nghiệp Vụ (Context)
Ứng dụng WeddingOS phục vụ ban tổ chức đám cưới (Cô dâu, Chú rể, Thành viên hỗ trợ) đòi hỏi giao diện phong phú, hỗ trợ nhiều bảng biểu nhập liệu chi tiết (form-heavy screens như kế hoạch công việc, chi tiêu ngân sách, giao dịch thanh toán) và danh sách hiển thị lớn (danh bạ khách mời từ 150 đến 300 dòng, có bộ lọc và tìm kiếm nhanh). Theo ràng buộc sản phẩm ban đầu, ứng dụng chính phải được thiết kế ưu tiên cho di động trên hệ điều hành Android (Android-first). Ngoài ra, tài nguyên phát triển của dự án trong giai đoạn đầu rất hạn chế (Solo/Small-team development) đòi hỏi tốc độ phát triển và kiểm thử cực nhanh.

---

## 2. Động Lực Kiến Trúc (Architecture Drivers)
Các yếu tố chính ảnh hưởng đến quyết định:
*   **Android-first UX:** Giao diện điều khiển mượt mà, phản hồi tốt trên nhiều dòng máy Android trung và yếu.
*   **Solo Developer Productivity:** Tối giản hóa boilerplate code, có khả năng reload nhanh khi sửa đổi UI, thư viện tích hợp BaaS (Supabase) hoàn thiện.
*   **Android Touch Target Requirements:** Ràng buộc phi chức năng tối thiểu của vùng cảm ứng tương tác đạt `48dp × 48dp` (REQ-06).
*   **Khả năng mở rộng dài hạn:** Mã nguồn có khả năng tái sử dụng để xây dựng phiên bản iOS trong tương lai khi dự án phát triển quy mô thương mại lớn, mà không phải viết lại logic nghiệp vụ từ đầu.

---

## 3. Các Phương Án Được Cân Nhắc (Options Considered)

### Phương án A: Native Android (Kotlin + Jetpack Compose)
*   *Đánh giá:* Một giải pháp thay thế khả thi với tính chuyên biệt hóa xuất sắc cho hệ điều hành Android, nhưng không được chọn vì WeddingOS hiện tại ưu tiên một codebase client có khả năng chạy đa nền tảng và duy trì khả năng tùy chọn iOS trong tương lai.

### Phương án B: Flutter Cross-platform (Dart) - **SELECTED**
*   *Đánh giá:* Giải pháp đa nền tảng tối ưu nhờ tốc độ phát triển giao diện nhanh thông qua Hot Reload và kho widget dồi dào. Hệ sinh thái thư viện Dart tích hợp Supabase SDK chính thức hoạt động ổn định.

### Phương án C: React Native (Typescript)
*   *Đánh giá:* Một giải pháp thay thế đa nền tảng khả thi khác, tuy nhiên không xác định được lợi thế kiến trúc chuyên biệt nào cho WeddingOS vượt trội hơn việc chọn Flutter cho sản phẩm hiện tại.

---

## 4. Quyết Định Kiến Trúc (Decision)
Hệ thống chính thức phê duyệt lựa chọn **Phương án B: Flutter** làm framework phát triển chính cho ứng dụng di động ban tổ chức của WeddingOS.
*   **Phạm vi phát hành MVP:** **Chỉ đóng gói và phát hành ứng dụng trên hệ điều hành Android (Android only)**.
*   **Khả năng iOS:** Không phân phối ứng dụng iOS trong giai đoạn MVP. Khả năng chạy trên iOS là một lợi thế thiết kế tương lai, không nằm trong phạm vi bắt buộc hiện tại.
*   **Không hỗ trợ Desktop/Web Organizer:** Loại bỏ hoàn toàn phiên bản Desktop hay Web dành cho ban tổ chức trong giai đoạn này.

---

## 5. Hệ Quả Kiến Trúc (Consequences)
*   **Tích hợp Supabase mượt mà:** Sử dụng thư viện Dart `supabase_flutter` để giao tiếp trực tiếp với DB và Auth, giảm tải việc tự viết HTTP REST API client.
*   **Quản lý giao diện đồng bộ:** Thiết kế giao diện pixel-perfect giống nhau trên mọi thiết bị Android.
*   **Hoãn lại các thư viện cụ thể:** Quyết định này **CHỈ** giải quyết nền tảng phát triển tổng thể. Các quyết định chi tiết khác dưới đây **hoàn toàn được hoãn lại** để quyết định ở các chặng thiết kế chi tiết tiếp theo:
    *   Thư viện quản lý trạng thái (State-management library như Bloc/Provider/Riverpod).
    *   Thư viện điều hướng (Navigation library).
    *   Thư viện lưu trữ cục bộ (Local persistence library).
    *   Cơ chế tiêm phụ thuộc (Dependency injection).
    *   Cấu trúc thư mục dự án (Application folder structure).
    *   Mô hình kiến trúc chi tiết của app (Detailed app architecture pattern).

---

## 6. Rủi Ro & Biện Phá Giảm Thiểu (Risks & Mitigations)
*   **Rủi ro hiệu năng máy yếu:** Hiệu năng trên các thiết bị Android phân khúc thấp/trung bình cần được xác thực chéo với các chỉ tiêu phi chức năng (NFR targets) của WeddingOS MVP.
    *   *Giảm thiểu:* 
        *   Thực hiện đo lường hiệu năng trên các bản build release (release/profile benchmarking).
        *   Kiểm thử trên các thiết bị Android thực tế thuộc phân khúc thấp/trung bình.
        *   Đo lường thời gian tải và độ mượt khi cuộn các danh sách dài (Khách mời, Công việc).
        *   Đo lường thời gian khởi động app và hiệu năng các màn hình nhập liệu phức tạp (form-heavy screens).
        *   Tối ưu hóa các điểm nghẽn (bottlenecks) được phát hiện trong quá trình đo lường thực tế.
*   **Dung lượng app cài đặt:** Runtime và các thư viện phụ thuộc của Flutter đóng góp vào dung lượng thực tế của ứng dụng.
    *   *Giảm thiểu:* Dung lượng tải xuống và cài đặt thực tế của người dùng sẽ được đo lường cụ thể từ các artifact release trong quá trình implementation/release engineering. Việc đóng gói phát hành và tối ưu hóa dung lượng ứng dụng sẽ được xử lý trong giai đoạn chuẩn bị release.

---

## 7. Các Phương Án Bị Từ Chối (Rejected Alternatives)
*   *Native Kotlin:* Bị từ chối do không đáp ứng mức độ ưu tiên hiện tại về codebase đa nền tảng và khả năng chạy iOS trong tương lai.
*   *React Native:* Bị từ chối do không có lợi thế kiến trúc chuyên biệt vượt trội so với Flutter cho sản phẩm ở thời điểm hiện tại.

---

## 8. Các Vấn Đề Trì Hoãn (Deferred Concerns)
*   Hoãn lại việc phát hành ứng dụng iOS.
*   Hoãn lại việc phát triển bản Web/Desktop cho ban tổ chức.
*   Hoãn lại việc lựa chọn chi tiết các thư viện bổ trợ trong dự án Flutter.

---

## 9. Khảo Sát Tính Nguồn Gốc (Traceability)
Quyết định này liên kết trực tiếp và đáp ứng trọn vẹn:
*   Ràng buộc Constraints: `Android-first`.
*   Yêu cầu `REQ-01 Welcome & Onboarding`.
*   Chỉ số hiệu năng di động `XCT-NFR-001` (Android load time dưới 2.0s).
*   Kích thước touch target `XCT-NFR-004` (Touch target tối thiểu 48dp).
