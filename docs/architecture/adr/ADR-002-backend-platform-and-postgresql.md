# Quyết Định Kiến Trúc: ADR-002 — Backend Platform & PostgreSQL

*   **Mã quyết định (ADR ID):** ADR-002
*   **Trạng thái (Status):** Approved (Đã Phê duyệt)
*   **Người thực hiện:** Antigravity (AI Architect)
*   **Ngày cập nhật:** 20/08/2026

---

## 1. Ngữ Cảnh (Context)
Hệ thống WeddingOS đòi hỏi một nền tảng backend và cơ sở dữ liệu để hỗ trợ:
*   Môi trường làm việc đám cưới đa người dùng xác thực (`authenticated organizer workspace`).
*   Mô hình không gian làm việc đám cưới cô lập chéo (`multiple isolated Wedding workspaces`).
*   Mô hình dữ liệu miền quan hệ phức tạp (`relational domain data` như Wedding ↔ Events ↔ Members, Tasks, Budget Items ↔ Payments ↔ Refunds).
*   Đảm bảo tính toàn vẹn tài chính, công nợ chi tiêu (`Finance integrity`).
*   Quản lý danh sách và nhóm mời khách mời (`Guest Management`).
*   Phát hành thiệp và thu nhận phản hồi tham dự của khách (`Invitation / RSVP`).
*   Lưu trữ hình ảnh thiệp cưới (`file/media storage`).
*   Cung cấp các cổng nghiệp vụ công khai cho khách mời (`public guest operations`) không cần tài khoản.
*   Kiểm soát phân quyền chặt chẽ (`authorization`) và thực thi các thao tác nghiệp vụ tin cậy (`trusted business operations`).

Bản phân tích các phương án kiến trúc vòng 1 đã đề xuất lựa chọn Supabase làm nền tảng Backend-as-a-Service (BaaS) chính cho MVP và PostgreSQL làm cơ sở dữ liệu quan hệ chính. ADR này chính thức đặc tả quyết định nền tảng backend và lưu trữ dữ liệu này.

---

## 2. Động Lực Kiến Trúc (Architecture Drivers)
Các động lực kiến trúc chính ảnh hưởng đến quyết định này (tham chiếu từ REQ-01 đến REQ-06):
*   **Android-first & Guest Web:** Cần cung cấp cả cơ chế đồng bộ dữ liệu nhanh cho app Android và cổng API nhẹ xác thực bằng mã bảo mật cho Guest Web.
*   **Free-tier-first:** Khả năng triển khai và chạy thử nghiệm sản phẩm với chi phí hạ tầng tối thiểu hoặc bằng $0$ trong giai đoạn đầu (validation). Tuy nhiên, không hy sinh tính toàn vẹn dữ liệu (Data Integrity) và bảo mật để đạt chi phí $0$ đ.
*   **Relational Domain Complexity:** Miền dữ liệu có cấu trúc quan hệ sâu và chặt chẽ, đòi hỏi các ràng buộc toàn vẹn ở tầng dữ liệu.
*   **Finance Integrity:** Chặn tuyệt đối việc tạo thanh toán trùng lặp khi retry mạng, bảo vệ tính đúng đắn của dòng tiền thực tế.
*   **Wedding Isolation:** Chặn đứng rò rỉ dữ liệu chéo giữa các đám cưới.
*   **Low Operational Overhead & Solo Maintainability:** Giảm thiểu tối đa việc viết code và cấu hình hệ thống backend thủ công để solo developer tập trung phát triển UI Android và Web.
*   **Migration Path:** Dễ dàng di chuyển dữ liệu khi dự án phát triển quy mô thương mại lớn.

---

## 3. Các Phương Án Được Cân Nhắc (Options Considered)

### Phương án A: Supabase Platform + PostgreSQL (BaaS-centric) - **SELECTED**
*   *Mô tả:* Sử dụng trực tiếp dịch vụ Supabase để quản lý cơ sở dữ liệu PostgreSQL, cơ chế xác thực Auth, lưu trữ Storage và chạy các hàm nghiệp vụ tin cậy qua Edge Functions.
*   *Đánh giá:* Rất tốt cho mục tiêu giảm thiểu khối lượng code backend tự dựng và tối ưu chi phí hạ tầng free-tier trong validation phase. Bảo mật dữ liệu được kiểm soát chặt chẽ ở mức cơ sở dữ liệu thông qua cơ chế Row Level Security (RLS) của Postgres.

### Phương án B: Custom Backend + Managed PostgreSQL (Traditional Backend)
*   *Mô tả:* Thiết lập API gateway/runtime riêng biệt và kết nối tới dịch vụ PostgreSQL được quản lý độc lập (managed database), tự tích hợp các dịch vụ xác thực/lưu trữ độc lập của bên thứ ba.
*   *Đánh giá:* Một giải pháp thay thế truyền thống khả thi với khả năng tùy biến logic nghiệp vụ và kiểm soát hạ tầng cao nhất. Tuy nhiên, phương án này tăng khối lượng mã nguồn backend cần tự viết và bảo trì ngay từ giai đoạn đầu, không tối ưu cho mục tiêu kiểm thử nhanh của MVP.

---

## 4. Quyết Định Kiến Trúc (Decision)
Hệ thống chính thức phê duyệt lựa chọn **Phương án A: Supabase làm nền tảng backend chính cho MVP của WeddingOS** và **PostgreSQL làm mô hình lưu trữ dữ liệu quan hệ chính**.
*   *Phạm vi giới hạn:* Supabase cung cấp Data API, Row Level Security (RLS), cơ sở dữ liệu PostgreSQL, dịch vụ Auth, dịch vụ Storage và môi trường Edge Functions (Deno). Việc phân loại chi tiết thao tác nào sử dụng Data API trực tiếp và thao tác nào bắt buộc đi qua Edge Functions/Serverless API được hoãn lại để giải quyết tại quyết định **ADR-003**.

---

## 5. Lý Do Lựa Chọn Cơ Sở Dữ Liệu Quan Hệ (PostgreSQL Rationale)
Lĩnh vực nghiệp vụ của WeddingOS mang các đặc tính quan hệ chặt chẽ và đòi hỏi tính toàn vẹn cao:
*   Mô hình Đám cưới (`Wedding`) liên kết trực tiếp với các Sự kiện cưới con (`Events`) và danh sách ban hỗ trợ (`Members`).
*   Mô hình công việc (`Tasks`) thuộc bối cảnh lịch trình đám cưới.
*   Mô hình chi tiêu ngân sách gồm các khoản chi (`Budget Items`) và lịch sử giao dịch dòng tiền thực tế (`Payments`, `Refunds`) đòi hỏi tính nhất quán giao dịch (ACID transactions) để tránh lỗi sai sót công nợ.
*   Khách mời cá nhân (`Guest`) thuộc bối cảnh nhóm mời thiệp chung (`InvitationParty`) có chỉ số số lượng người mời (`Invited Count`) hạn định.
*   Thiệp mời (`Invitation`) liên kết với các phản hồi RSVP của khách đối với từng sự kiện con (`Event-specific RSVP`).

Hệ cơ sở dữ liệu tài liệu (NoSQL/Document-first) không phù hợp vì việc duy trì tính toàn vẹn của các mối quan hệ phức tạp và các giao dịch tài chính liên đới trên tầng ứng dụng sẽ đòi hỏi viết code kiểm soát rất lớn và dễ gây bất đồng nhất dữ liệu. Cơ sở dữ liệu quan hệ PostgreSQL cung cấp các khóa ngoại (Foreign Keys), ràng buộc kiểm tra (Check Constraints) và giao dịch ACID ở mức DB, bảo vệ cấu trúc dữ liệu WeddingOS một cách tự nhiên và tin cậy nhất.

---

## 6. Phạm Vi Khai Thác Nền Tảng Supabase (Platform Capability Boundaries)

### A. PostgreSQL
Là cơ sở dữ liệu quan hệ tin cậy và tối cao của hệ thống. Mọi tính toán tài chính và lưu trữ thông tin thực thể đều nằm ở Postgres. Bản nháp cục bộ (local drafts) trên Android và dữ liệu trạng thái trên trình duyệt Guest Web chỉ phục vụ UX, không phải là lưu trữ nghiệp vụ tối cao (Not authoritative).

### B. Auth
Cung cấp năng lực danh tính ở backend (backend identity capability) cho các tài khoản ban tổ chức đám cưới. Cơ chế xác thực chi tiết được đặc tả tại ADR-004.

### C. Storage
Nơi lưu trữ hình ảnh đại diện thiệp cưới của cặp đôi. Việc tối ưu hóa hình ảnh, nén ảnh ở thiết bị di động, cơ chế cache, các biến thể media, và khả năng chuyển đổi sang Cloudflare R2 hoặc phân tích Excel import/export được hoãn lại để đặc tả chi tiết tại **ADR-006**. Giới hạn dung lượng tải lên tối đa 5MB được tham chiếu từ REQ-06.

### D. Edge Functions
Cung cấp môi trường chạy serverless để thực thi các hàm nghiệp vụ. Ranh giới tin cậy chi tiết và các API endpoints được đặc tả tại ADR-003 và ADR-005.

### E. Row Level Security (RLS)
Cơ chế bảo vệ dữ liệu mặc định ở mức DB để cô lập không gian giữa các đám cưới. Thiết kế chính sách chi tiết được đặc tả tại ADR-003.

---

## 7. Rủi Ro Tính Sẵn Sàng Khi Chạy Miễn Phí (Supabase Pause Risk & Stage Model)

*   **Mã rủi ro:** `FREE_PROJECT_PAUSE / GUEST_LINK_AVAILABILITY`
*   **Bản chất:** Gói dịch vụ miễn phí Supabase Free sẽ tự động tạm dừng hoạt động cơ sở dữ liệu nếu dự án không phát sinh bất kỳ hoạt động đọc/ghi nào trong 7 ngày liên tiếp. Khi dự án bị tạm dừng, toàn bộ liên kết Web của khách mời sẽ bị lỗi kết nối, ảnh hưởng nghiêm trọng đến khả năng phản hồi RSVP thực tế của đám cưới.
*   **Chính sách theo giai đoạn sản phẩm (Stage-based Production Readiness Policy):**
    *   *Giai đoạn phát triển / Thử nghiệm nội bộ (Development/Internal Validation):* Sử dụng gói miễn phí Supabase Free để tiết kiệm chi phí. Chấp nhận rủi ro dự án tự ngủ. Tuyệt đối không sử dụng các công cụ giữ thức giả tạo (database warmer/keep-alive tricks) để tránh vi phạm chính sách nhà cung cấp.
    *   *Giai đoạn Khởi chạy thực tế (Production Readiness Check):* Trước khi một Đám cưới thực tế gửi các liên kết thiệp mời tới khách mời, dự án bắt buộc phải trải qua bước kiểm tra sẵn sàng (`Production Readiness Check`). Bước này đánh giá hành vi tự ngủ, yêu cầu về tính sẵn sàng, hạn mức dữ liệu (quota headroom), sao lưu (backups), hỗ trợ kỹ thuật, giám sát vận hành và lưu lượng dự kiến.
    *   *Giải pháp nâng cấp:* Nếu rủi ro tạm dừng DB miễn phí là không thể chấp nhận đối với đám cưới thực tế, dự án bắt buộc phải nâng cấp lên gói **Supabase Pro** (Hiện tại là **$25/tháng**, kiểm tra vào ngày 20/08/2026 theo tài liệu chính thức của Supabase). Gói Pro tắt tính năng tự ngủ DB, cung cấp dung lượng lớn hơn và các tính năng hướng production. Việc nâng cấp Pro không cam kết một hợp đồng SLA $99.9\%$ chính thức (Cam kết SLA $99.9\%$ của Supabase chỉ áp dụng cho phân khúc khách hàng Enterprise).

---

## 8. Khả Năng Di Chuyển & Khóa Công Nghệ (Data Portability & Lock-in Analysis)

Đánh giá mức độ phụ thuộc công nghệ vào hệ sinh thái Supabase ở mức độ chi tiết:
*   **Dữ liệu PostgreSQL:** Mức độ lock-in **THẤP**. Cấu trúc schema và các bảng dữ liệu là SQL tiêu chuẩn, dễ dàng xuất (dump SQL) và import sang bất kỳ máy chủ Postgres nào khác.
*   **Ràng buộc logic & chỉ mục Postgres:** Mức độ lock-in **THẤP**. Các ràng buộc CHECK, INDEX trong Postgres được xuất và nhập bình thường qua các hệ thống SQL chuẩn.
*   **Các chính sách RLS:** Mức độ lock-in **THẤP - TRUNG BÌNH**. RLS là tính năng chuẩn của Postgres, nhưng các biểu thức policy viết trong RLS của Supabase có thể sử dụng các hàm helper đặc thù của platform hoặc phụ thuộc vào metadata JWT của Supabase Auth.
*   **Supabase Auth:** Mức độ lock-in **TRUNG BÌNH**. Việc di chuyển danh tính sang Auth0 hoặc Firebase Auth đòi hỏi xuất bảng `auth.users` và cấu hình lại JWT.
*   **Supabase Storage:** Mức độ lock-in **TRUNG BÌNH**. Các liên kết ảnh lưu dưới dạng URL tĩnh cần được export và cập nhật lại khi chuyển sang AWS S3/Cloudflare R2.
*   **Edge Functions:** Mức độ lock-in **TRUNG BÌNH**. Code viết bằng Deno/TypeScript, có thể đóng gói lại thành các controller API Node.js chuẩn khi di chuyển.
*   **Supabase Client SDK:** Mức độ lock-in **TRUNG BÌNH**. Động cơ Flutter giao tiếp trực tiếp qua Supabase Client SDK sẽ cần viết lại lớp dữ liệu nếu chuyển sang backend tự dựng.

---

## 9. Hệ Quả Kiến Trúc (Consequences)

### Điểm tích cực (Positive)
*   **Vận hành cực nhẹ:** Loại bỏ việc duy trì hạ tầng API server riêng cho giai đoạn MVP, tận dụng toàn bộ hạ tầng đám mây sẵn có của Supabase.
*   **Bảo mật dữ liệu tự nhiên:** Tận dụng Row Level Security (RLS) của Postgres để cô lập tenant đám cưới ở mức DB một cách an toàn và tin cậy nhất.
*   **Nhất quán dữ liệu:** Tận dụng khả năng giao dịch ACID của PostgreSQL bảo vệ toàn vẹn số liệu tài chính.
*   **Phát triển nhanh:** SDK Flutter tích hợp sâu giúp solo developer binding dữ liệu nhanh.

### Điểm hạn chế (Negative)
*   **Hạn chế của Free-tier:** Dự án tự động pause sau 7 ngày không hoạt động trên gói Free, đòi hỏi kích hoạt nâng cấp Pro khi có đám cưới thực tế.
*   **Ràng buộc công nghệ (BaaS Coupling):** Lớp giao tiếp client phụ thuộc vào Supabase SDK. Việc viết logic nghiệp vụ nhạy cảm phải tuân thủ chuẩn Deno của Supabase Edge Functions.
*   **Yêu cầu năng lực PostgreSQL/RLS:** Đội ngũ phát triển cần hiểu sâu về cơ chế phân quyền RLS ở mức cơ sở dữ liệu để tránh cấu hình sai sót làm lộ dữ liệu.

---

## 10. Các Phương Án Bị Từ Chối (Rejected Alternatives)
*   *Phương án API Server tự dựng kết nối Managed Postgres:* Phương án này vẫn hoàn toàn khả thi về mặt kỹ thuật. Tuy nhiên, nó bị từ chối cho giai đoạn MVP vì WeddingOS hiện tại ưu tiên:
    1. Tiết kiệm diện tích mã nguồn backend tự sở hữu.
    2. Giảm thiểu gánh nặng vận hành API Server độc lập.
    3. Tích hợp sâu các dịch vụ DB/Auth/Storage trong một nền tảng thống nhất để kiểm thử nhanh giả định sản phẩm.
*   *Điều kiện xem xét lại quyết định:* Sẽ xem xét lại phương án tự dựng backend nếu logic xử lý chạy ngầm (Background Tasks) vượt hạn mức timeout của Edge Functions, hoặc chi phí sử dụng/upgrade của Supabase tăng quá cao, hoặc yêu cầu kiểm soát an ninh đòi hỏi quyền kiểm soát máy chủ tuyệt đối.

---

## 11. Các Vấn Đề Trì Hoãn (Deferred Decisions)
Các quyết định chi tiết dưới đây hoàn toàn được hoãn lại:
*   Thiết kế cấu trúc bảng cơ sở dữ liệu (Database Schema / ERD).
*   Đặc tả chi tiết các cột dữ liệu và kiểu dữ liệu (Table design & Column types).
*   Chính sách đặt tên migration và công cụ quản lý DB migration.
*   Thiết kế chi tiết các chính sách Row Level Security (RLS policies) - *(ADR-003)*.
*   Phân loại chi tiết Data API vs Edge Functions - *(ADR-003)*.
*   API routes và danh sách các API endpoints của Edge Functions - *(ADR-003/005)*.
*   Cơ chế triển khai Stored Procedures / Triggers trong Postgres.
*   Chi tiết thiết lập môi trường Supabase local development và quy trình CI/CD cho Database.
*   Chi tiết thiết kế lưu trữ media và xuất Excel - *(ADR-006)*.

---

## 12. Khảo Sát Tính Nguồn Gốc (Traceability)
Quyết định này liên kết trực tiếp và đáp ứng trọn vẹn:
*   Ràng buộc Constraints: `Free-tier-first`.
*   Yêu cầu `REQ-03 Finance` (Toàn vẹn số liệu tài chính).
*   Yêu cầu `REQ-06 Cross-cutting` (Cô lập đám cưới, bảo mật dữ liệu nhạy cảm).
*   Mục tiêu `XCT-NFR-007` (Không sử dụng background process tốn tài nguyên trên free-tier).
