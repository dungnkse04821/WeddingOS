# Quyết Định Kiến Trúc: ADR-005 — Guest Web & Public Invitation API

*   **Mã quyết định (ADR ID):** ADR-005
*   **Trạng thái (Status):** Approved (Đã Phê duyệt)
*   **Người thực hiện:** Antigravity (AI Architect)
*   **Ngày cập nhật:** 20/08/2026

---

## 1. Ngữ Cảnh (Context)

Theo yêu cầu `REQ-05` và `REQ-06`, khách mời tham dự đám cưới bắt buộc phải truy cập được thông tin thiệp cưới online và phản hồi RSVP một cách mượt mà và trực quan nhất.
*   **Không cài đặt app, không tài khoản:** Khách mời không được yêu cầu cài đặt ứng dụng Android WeddingOS hoặc đăng ký tài khoản xác thực (như Google hay OTP) để xem thiệp hay gửi RSVP.
*   **Mô hình Guest Web:** Đã chốt phương án host giao diện khách mời dưới dạng React + Vite Single Page Application (SPA) triển khai tĩnh trên **Cloudflare Pages**.
*   **Hạ tầng Backend:** Sử dụng **Supabase BaaS** (PostgreSQL + Auth + Storage + Edge Functions).

### Thử thách an ninh và bảo mật:
Giao diện Guest Web hoạt động trên trình duyệt của khách mời là môi trường hoàn toàn không đáng tin cậy (`untrusted client`). Để ngăn chặn rò rỉ dữ liệu chéo, phá hoại danh sách hoặc spam RSVP bừa bãi, trình duyệt Guest Web **tuyệt đối không được truy cập trực tiếp** hoặc truy vấn thẳng vào các bảng dữ liệu nội bộ của hệ thống (như bảng `Guest`, `InvitationParty`, `Invitation`, `WeddingMember`, `Finance`, hay `Planning`). 

Quyết định này thiết lập ranh giới tin cậy công khai (`Public Trusted Boundary`) bảo vệ cơ sở dữ liệu nội bộ thông qua việc sử dụng khả năng xử lý máy chủ tin cậy của Supabase (**Supabase Edge Functions**), đóng vai trò làm cổng API bảo mật dành riêng cho các thao tác thiệp mời và RSVP công khai.

---

## 2. Phạm Vi Quyết Định (Scope)

### Quyết định trong tài liệu này:
*   Mô hình runtime và cách phân tách dữ liệu của Guest Web tĩnh.
*   Xác lập ranh giới tin cậy máy chủ công khai (Public Trusted API Boundary).
*   Nguyên tắc giải quyết thông tin thiệp cưới từ mã truy cập (Invitation Resolution).
*   Mô hình hoạt động của mã thiệp mời (Invitation Credential).
*   Bộ dữ liệu thiệp mời công khai đã được làm sạch (Sanitized Public Data).
*   Quy trình và kiểm chứng nghiệp vụ cho thao tác gửi RSVP (RSVP Mutation Path).
*   Nguyên tắc bảo vệ quyền riêng tư, chống lập chỉ mục (Search Indexing) và chống rò rỉ mã thiệp (Referrer/Credential Leakage).
*   Phương án so sánh và hệ quả kiến trúc liên quan.

### Các quyết định hoãn lại (Deferred / Out of Scope):
*   Tên endpoint API cụ thể hoặc cấu trúc JSON DTO schema chi tiết.
*   Thiết kế bảng vật lý lưu trữ mã thiệp (`Invitation`) hay phản hồi (`EventResponse`).
*   Thuật toán mã hóa / băm mã thiệp trong database.
*   Cấu hình chi tiết CORS, Referrer-Policy, Content Security Policy (CSP).
*   Cách cài đặt Router trên React app hay chọn thư viện phân tích query string trên Web.
*   Cơ chế kiểm soát lưu cache trình duyệt/CDN và cấu hình HTTP headers.

---

## 3. Giao Diện Web Khách Mời & Runtime (Guest Web Runtime Model)

*   **Tĩnh hoàn toàn (Static Shell):** Cloudflare Pages chỉ lưu trữ và phân phối các tệp tĩnh (HTML, CSS, JS) của ứng dụng React/Vite.
*   **Truy xuất dữ liệu thời gian chạy (Runtime personalized data fetch):** Không áp dụng cơ chế SSG (Static Site Generation) tạo sẵn trang chứa thông tin cá nhân của khách tại build-time. Không nhúng bất kỳ thông tin đám cưới hoặc danh tính khách mời nào vào các gói build tĩnh được chia sẻ toàn cầu.
*   **Nạp dữ liệu động:** Khi khách mời truy cập link cá nhân hóa (ví dụ: `/invite/{credential}`), React ứng dụng sẽ phân tích mã truy cập từ URL và gửi yêu cầu API động tới ranh giới tin cậy của WeddingOS để nạp dữ liệu cá nhân tương ứng động tại thời điểm truy cập.

---

## 4. Ranh Giới Tin Cậy Công Khai (Public Trust Boundary)

*   **Supabase Edge Functions làm API Biên:** Chọn Supabase Edge Functions (Deno runtime) làm môi trường thực thi máy chủ công khai của MVP.
*   **Không tin cậy client:** Trình duyệt Guest Web không giao tiếp trực tiếp với database qua PostgreSQL API của Supabase và không sử dụng RLS bảng trực tiếp làm chốt chặn bảo mật chính cho khách mời.
*   **Truy cập đặc quyền có điều kiện:** Edge Function sử dụng thông tin xác thực máy chủ có đặc quyền (privileged server-side credential / privileged database access) khi thật sự cần thiết.
*   **Ủy quyền máy chủ tối cao:** API Edge Function không mặc nhiên coi yêu cầu là hợp lệ chỉ vì nó chạy trên server. Nếu sử dụng truy cập đặc quyền để bypass RLS thông thường, Edge Function bắt buộc phải kiểm tra và xác thực tường minh (explicit validation) các yếu tố sau:
    *   Tính hợp lệ của mã truy cập thiệp (`Invitation Credential`).
    *   Trạng thái hoạt động của đám cưới (`Wedding state`).
    *   Trạng thái hoạt động của lời mời (`Invitation state`).
    *   Các quy tắc nghiệp vụ đám cưới và quy tắc RSVP.
*   **Nguyên tắc Đặc quyền Tối thiểu (Least Privilege):** Hệ thống áp dụng quyền truy cập dữ liệu tin cậy ở mức tối thiểu nhất có thể (least-privileged trusted data access) để thực hiện chính xác thao tác, tránh lạm dụng quyền đặc quyền tối cao cho mọi câu lệnh đọc/ghi.

---

## 5. Mô Hình Mã Truy Cập Thiệp (Invitation Credential Model)

*   **Thuộc tính:** Mã truy cập thiệp mời phải là một chuỗi ngẫu nhiên có độ hỗn loạn thông tin cao (`high entropy`), không thể đoán trước (`unguessable`), có thể thu hồi (`revocable`) và tái tạo mới (`regeneratable`).
*   **Giới hạn quyền:** Mã truy cập chỉ đại diện cho quyền truy cập vào **duy nhất một bối cảnh thiệp mời cụ thể** (`Invitation context`). Nó không thiết lập danh tính ban tổ chức và tuyệt đối không cấp quyền truy cập đám cưới tổng thể.

---

## 6. Giải Quyết Thiệp Mời Công Khai (Invitation Resolution)

Khi trình duyệt gửi mã thiệp lên Edge Function để phân tích, API máy chủ sẽ kiểm tra tối thiểu:
*   Mã truy cập hợp lệ và tồn tại trong DB.
*   Mã truy cập chưa bị thu hồi (Active / Not Revoked).
*   Đám cưới chủ quản đang hoạt động (Active / Not Archived).
*   Lời mời đang ở trạng thái hiển thị (Invitation is active/visible).
*   Sự kiện cưới con được nhắm mục tiêu mời phải hợp lệ.

Nếu kiểm tra thành công, API chỉ trả về một cấu trúc dữ liệu tối giản được làm sạch tuyệt đối. Các mã định danh nội bộ (DB Primary Keys) và thông tin không cần thiết sẽ bị loại bỏ để tránh nguy cơ khai thác thông tin.

---

## 7. Ranh Giới Dữ Liệu Được Làm Sạch (Sanitized Guest Data)

### Dữ liệu công khai hợp lệ được phép trả về Guest Web:
*   Tên hiển thị của Cô dâu & Chú rể.
*   Tên hiển thị của Nhóm mời (Greeting Display Name).
*   Danh sách các Sự kiện cưới con mà nhóm được mời tham gia.
*   Thông tin thời gian sự kiện: Đúng độ chính xác (Expected Month hoặc Exact Date khi đã chốt).
*   Giờ tổ chức cụ thể và địa điểm/địa chỉ (khi đã cấu hình).
*   Link chỉ đường bản đồ (nếu có).
*   Trạng thái RSVP-ready (đã có Exact Date).
*   Dữ liệu phản hồi RSVP hiện tại của chính Nhóm mời này.
*   Thông tin tài khoản VietQR / Ngân hàng mừng cưới (chỉ hiển thị sau khi hoàn tất RSVP theo đúng quy định `REQ-05`).

### Dữ liệu tuyệt đối CẤM để lộ trên API công khai:
*   Danh sách hoặc tên của các Khách mời thuộc các Nhóm mời khác.
*   Thông tin phản hồi RSVP hoặc lời chúc của các nhóm khác.
*   Nguồn danh sách khách (`Guest Source`) và Nhóm quan hệ nội bộ (`Primary Group`).
*   Email, số điện thoại của ban tổ chức (trừ khi cấu hình công khai làm hotline hỗ trợ).
*   Ghi chú nội bộ của ban tổ chức về khách mời.
*   Toàn bộ phân hệ Kế hoạch (`Planning`) và Tài chính (`Finance`) nội bộ của đám cưới (bao gồm cả danh sách Payer và Budget).
*   Mã ID nội bộ và các chuỗi khóa bí mật/credential.

---

## 8. Gửi Phản Hồi RSVP & Trạng Thái Hiện Tại (RSVP Mutation & Current State)

### A. Gửi phản hồi RSVP
Thao tác gửi phản hồi RSVP từ trình duyệt của khách mời được xử lý an toàn qua Edge Function:
1.  **Kiểm tra tính hợp lệ trước khi ghi:**
    *   Xác thực mã thiệp mời còn hiệu lực.
    *   Đám cưới đang hoạt động.
    *   Sự kiện được RSVP nằm trong danh sách sự kiện được mời của nhóm.
    *   Sự kiện đã ở trạng thái RSVP-ready (có Exact Date).
    *   Thời gian hiện tại chưa vượt quá hạn chót của đám cưới (`RSVP Cutoff Date`, kiểm tra bằng múi giờ đám cưới dựa trên thời gian máy chủ tin cậy).
2.  **Ràng buộc số lượng tham gia:** Kiểm tra số lượng xác nhận tham gia (`Attending Count`) không vượt quá số người được mời của nhóm (`Invited Count`), trừ khi có chính sách cho phép vượt mức cấu hình riêng biệt.
3.  **Quy tắc cập nhật cuối (Latest-update wins):** WeddingOS duy trì duy nhất **một trạng thái RSVP hiện tại có thẩm quyền** (one authoritative CURRENT RSVP state) cho bối cảnh thiệp mời đó. Lượt cập nhật hợp lệ cuối cùng sẽ chiến thắng. Cơ chế lưu trữ lịch sử hoặc phiên bản dữ liệu chi tiết được hoãn lại cho thiết kế cơ sở dữ liệu sau này.
4.  **Sau hạn Cutoff:** Chặn mọi thay đổi RSVP từ phía khách. Giao diện chuyển sang View-only. Mọi thay đổi sau đó chỉ có thể thực hiện bởi Owner phía ứng dụng Android.

### B. Truy xuất trạng thái RSVP hiện tại
*   Guest Web chỉ được phép nạp trạng thái RSVP hiện thời của chính Nhóm mời sở hữu mã thiệp đó. Tuyệt đối không được xem hay chỉnh sửa RSVP của bất kỳ nhóm mời nào khác.

---

## 9. Tái Tạo Mã Truy Cập (Token Regeneration)

Khi OWNER yêu cầu tái tạo mã truy cập thiệp cho một nhóm mời trên app Android:
*   Hệ thống sinh một mã truy cập ngẫu nhiên mới và cập nhật trạng thái hoạt động.
*   Mã truy cập cũ lập tức bị đánh dấu hết hạn/vô hiệu hóa.
*   Tất cả thông tin định danh nhóm mời, lịch sử gửi thiệp và dữ liệu RSVP đã có được bảo toàn nguyên vẹn.
*   Mọi lượt truy cập sử dụng mã cũ từ trình duyệt sẽ lập tức nhận lỗi không hợp lệ (generic invalid error).

---

## 10. Xử Lý Khi Đám Cưới Bị Lưu Trữ (Archived Wedding)

*   Theo yêu cầu `REQ-06`, khi đám cưới chuyển sang lưu trữ (`Archived`), toàn bộ các link thiệp mời của khách phải ngừng hoạt động.
*   Khi có yêu cầu nạp dữ liệu bằng mã thiệp thuộc Đám cưới bị lưu trữ, Edge Function lập tức trả về lỗi không khả dụng chung (generic unavailable error) tương tự như link lỗi, không để lộ thông tin của đám cưới.

---

## 11. Chống Dò Quét & Bảo Vệ Quyền Riêng Tư (Privacy & Security Model)

### A. Chống dò quét mã (Invalid Credential Privacy)
Yêu cầu lỗi đối với mã truy cập sai, hết hạn hoặc bị thu hồi phải trả về mã lỗi và cấu trúc thông điệp giống hệt nhau (`generic error responses`). Tuyệt đối không trả về thông tin chi tiết xác nhận sự tồn tại của Đám cưới hay nhóm khách để ngăn chặn kỹ thuật tấn công dò quét thu thập thông tin (enumeration attacks).

### B. Chặn lập chỉ mục tìm kiếm (Search Indexing)
*   Trang thiệp mời không phải nội dung SEO công khai. Hệ thống yêu cầu chặn lập chỉ mục tìm kiếm một cách chủ động.
*   Tuyệt đối không đưa link thiệp mời cá nhân hóa của khách vào bất kỳ sitemap công khai nào.
*   Thiết kế kỹ thuật chi tiết của robots/meta/header được hoãn lại ở phase phát triển.

### C. Ngăn ngừa rò rỉ qua Referrer (Referrer Leakage)
*   Do URL chứa mã truy cập cá nhân hóa nhạy cảm, khi khách click vào các liên kết ngoài trên thiệp (như link bản đồ Google Maps), mã truy cập này có nguy cơ bị gửi tới bên thứ ba thông qua header `Referer`.
*   *Nguyên tắc bảo vệ:* Mã thiệp mời thô (`raw credential`) tuyệt đối không được gửi tới các bên thứ ba như hệ thống theo dõi lỗi (Sentry), phân tích hành vi (Google Analytics) hay các liên kết ngoài. Thiết kế cụ thể Referrer-Policy được hoãn lại.
*   *Câu hỏi thiết kế bảo mật tương lai:* Có nên xóa/ẩn mã thiệp mời khỏi thanh địa chỉ của trình duyệt (browser address bar) sau khi đã giải quyết và nạp dữ liệu thành công hay không? (Chưa quyết định ở ADR này).

### D. Logging & Caching an toàn
*   *Logging:* Không ghi lại chuỗi mã truy cập thô (`raw credential string`) vào log hệ thống thông thường để tránh rò rỉ qua log storage. Chỉ ghi nhận ID log tương quan phục vụ debug.
*   *Caching:* 
    *   *Static assets:* Các tệp tĩnh React/Vite được CDN cache tối đa.
    *   *Personalized data:* Phản hồi thông tin cá nhân từ Edge Function tuyệt đối không được cache dùng chung (shared cache) trên CDN hay Proxy để tránh rò rỉ dữ liệu chéo giữa các thiệp mời. Cấu hình HTTP cache headers chi tiết được hoãn lại.

---

## 12. Lưu Trữ Bộ Nhớ Trình Duyệt (Browser Persistence Constraints)

*   **Hạn chế lưu giữ lâu dài:** Tránh lưu giữ lâu dài mã thiệp mời thô hoặc thông tin RSVP nhạy cảm vào bộ lưu trữ cục bộ của trình duyệt (local storage / cookies).
*   **Bảo toàn form nhập liệu:** Cho phép lưu giữ ngắn hạn hoặc lưu theo phạm vi phiên làm việc (session-scoped) để phục vụ khôi phục dữ liệu đang điền dở khi gặp sự cố mạng hoặc tải lại trang đột ngột, không tạo xung đột với hành vi khôi phục RSVP của `REQ-05`.
*   Cơ chế lưu trữ cụ thể trên trình duyệt được hoãn lại.

---

## 13. VietQR, Save the Date & Sự Kiện Xóa (RSVP & Events Invariants)

*   **VietQR mừng cưới:** Chỉ hiển thị sau khi hoàn tất RSVP hợp lệ (áp dụng cho cả trường hợp báo đi hoặc không đi nếu được cấu hình). Không được phép để lộ thông tin ngân hàng trước khi RSVP xong. Không để lộ dữ liệu tài chính của ban tổ chức.
*   **Save the Date:** Giữ nguyên quy tắc phân biệt `Expected Month` và `Exact Date`. Sự kiện chỉ có tháng dự kiến sẽ hiện dạng Save the Date và không yêu cầu khách RSVP.
*   **Xóa sự kiện:** Khi một sự kiện cưới bị xóa bởi ban tổ chức, nó phải lập tức biến mất khỏi trang Guest Web và Edge Function chặn không nhận RSVP cho sự kiện đó nữa. Các bản ghi RSVP lịch sử của sự kiện bị xóa được lưu trữ an toàn phía ban tổ chức.

---

## 14. Phòng Chống Lạm Dụng & Giới Hạn Tần Suất (Abuse & Rate Limiting)

Do các endpoint API của Edge Functions dành cho khách mời hoạt động không có tài khoản xác thực, chúng là mục tiêu nhắm tới của việc brute-force dò mã hoặc spam RSVP.
*   Kiến trúc bắt buộc phải triển khai cơ chế giới hạn tần suất yêu cầu (`Rate Limiting`) dựa trên các tín hiệu đầu vào bao gồm: IP người gọi, mã thiệp mời (credential), tần suất/mẫu yêu cầu, và các chỉ số lạm dụng khác.
*   Không coi CORS là hàng rào bảo mật. API bảo mật phải tự phòng vệ an toàn kể cả khi bị gọi trực tiếp từ các công cụ dòng lệnh (như curl) thay vì trình duyệt.
*   Không giả định Supabase tự động cung cấp hoàn chỉnh chính sách chống lạm dụng ứng dụng. Thiết kế chi tiết cơ chế rate limit được hoãn lại.

---

## 15. So Sánh Các Phương Án Thiết Kế (Option Analysis)

### Phương án 1: React SPA trên Cloudflare Pages + Supabase Edge Functions (SELECTED)
*   *Ưu điểm:* Kiến trúc cực kỳ gọn nhẹ, phân tách hoàn chỉnh ứng dụng client và logic server. Chi phí vận hành tĩnh bằng $0$đ. Bảo mật tập trung tại Edge Function, dễ dàng kiểm soát dữ liệu trả về cho client.
*   *Phù hợp MVP:* Hoàn toàn khớp với mục tiêu phát triển nhanh của đội ngũ nhỏ và ràng buộc free-tier.

### Phương án 2: Server-Side Rendering (SSR) / Render thiệp ở Backend
*   *Đánh giá:* Cho phép tối ưu SEO và thời gian tải trang ban đầu (First Contentful Paint) tốt hơn. Tuy nhiên, nó tăng đáng kể độ phức tạp của server hosting, tăng tài nguyên tính toán của Edge Functions vượt hạn mức miễn phí của Supabase, và không cần thiết do thiệp cưới cá nhân không yêu cầu SEO công khai.

---

## 16. Hệ Quả & Rủi Ro Kiến Trúc (Consequences & Risks)

### Hệ quả Tích cực:
*   Tải trang tĩnh cực nhanh qua CDN toàn cầu của Cloudflare.
*   Cô lập hoàn toàn ứng dụng ban tổ chức (Android) và khách mời (Web SPA).
*   Khách tham gia RSVP mượt mà không gặp rào cản đăng nhập.
*   Bảo vệ an toàn cơ sở dữ liệu nội bộ.

### Hệ quả Tiêu cực / Rủi ro:
*   Trang web phụ thuộc hoàn toàn vào kết nối API thời gian chạy của Backend để hiển thị nội dung.
*   Mở ra bề mặt tấn công công khai thông qua các endpoint accountless (Yêu cầu phải thiết lập Rate Limiting).
*   Rủi ro rò rỉ mã thiệp mời qua chia sẻ link chéo (Cần giáo dục UX cho cặp đôi khi gửi thiệp).

---

## 17. Khía Cạnh Kiểm Thử Kỹ Thuật (Testing Implications)
Kiến trúc yêu cầu xây dựng bộ kiểm thử tự động cho các trường hợp:
*   Mã thiệp mời hợp lệ, không hợp lệ, bị thu hồi, bị tái tạo mới.
*   Đám cưới bị lưu trữ (Archived Wedding).
*   Truy cập nhầm sự kiện cưới không được mời.
*   Gửi RSVP trước và sau thời hạn Cutoff.
*   Đảm bảo cô lập dữ liệu tuyệt đối giữa các Nhóm mời (cross-party isolation).
*   Kiểm tra tính an toàn của dữ liệu trả về (Sanitized response).

---

## 18. Các Vấn Đề Trì Hoãn (Deferred Decisions)
*   Thuật toán băm và mã hóa token thiệp mời trong database.
*   Cấu hình cụ thể IP Rate Limiter trên Supabase Edge Functions.
*   Cài đặt HTTP Headers chi tiết (CORS, Referrer-Policy, CSP, Cache-Control, Vary, CDN rules).
*   Giải pháp lưu trữ tạm thời dữ liệu form nhập dở trên trình duyệt.
