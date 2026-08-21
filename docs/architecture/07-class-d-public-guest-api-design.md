# Đặc Tả Kiến Trúc: 07 — Class D Public Guest API Design (Thiết Kế API Khách Mời Công Khai)

*   **Trạng thái (Status):** APPROVED (Đã Phê duyệt)
*   **Người thực hiện:** Antigravity (AI Architect)
*   **Ngày cập nhật:** 21/08/2026

---

> [!IMPORTANT]
> **NON-EXECUTABLE SPECIFICATION**
> Tài liệu này chứa đặc tả thiết kế giao diện API công khai Class D dành cho khách mời vãng lai (Guest Web). Đây KHÔNG phải là tệp mã nguồn Supabase Edge Functions hay React/Vite. Toàn bộ mã nguồn thực thi được hoãn lại cho phase sau.

---

## A. Mô Hình Tin Cậy Công Khai (Public Trust Model)

Hệ thống phân chia ranh giới tin cậy nghiêm ngặt đối với phân hệ Guest Web công khai:
1.  **Guest Browser (Không tin cậy):** Trình duyệt của khách là môi trường không an sau. Khách mời không cần đăng ký tài khoản WeddingOS.
2.  **Mã truy cập thiệp (Credential):** Opaque Token đi kèm đường dẫn thiệp mời là phương tiện duy nhất để định danh và phân quyền. Token này **không phải** là một Postgres Role, không phải là một JWT Member và không có quyền truy cập trực tiếp vào bất kỳ bảng cơ sở dữ liệu nào của hệ thống.
3.  **Supabase Edge Functions (Biên tin cậy Class D):** Đóng vai trò là chốt chặn bảo mật trung gian. Edge Function nhận Token, tính toán hàm băm SHA-256 nhị phân để đối soát với cơ sở dữ liệu, thực hiện kiểm tra các điều kiện nghiệp vụ đám cưới và chỉ trả về cấu trúc DTO đã được làm sạch (sanitized).
4.  **Cấm truy cập SQL trực tiếp:** RLS của vai trò `anon` khóa toàn bộ các bảng nghiệp vụ. Guest Web cấm truy cập trực tiếp cơ sở dữ liệu qua PostgREST/Supabase client SDK.

---

## B. Danh Mục Nghiệp Vụ Công Khai (Public Operation Inventory)

Để tối giản hóa hệ thống và tăng hiệu năng, Guest Web chỉ sử dụng 2 nghiệp vụ API công khai:

1.  **`D-INV-001` (Resolve Invitation):** Giải mã Token thiệp mời để lấy thông tin chi tiết đám cưới, danh sách sự kiện được mời và trạng thái RSVP hiện tại.
    *   *Side Effect (Ghi nhận lượt xem):* Tự động cập nhật `first_viewed_at` (nếu là lượt mở đầu tiên) và `last_viewed_at` sử dụng thời gian của máy chủ cơ sở dữ liệu.
    *   *Gán quyền media:* Sinh kèm các đường dẫn ảnh cưới đã được ký nhận đặc quyền ngắn hạn (Signed URLs).
2.  **`D-RSV-001` (Create/Update Guest RSVP current state):** Khách gửi phản hồi tham dự hoặc cập nhật trạng thái RSVP hiện tại cho các lễ cưới con được target sử dụng patch/upsert theo từng sự kiện.

---

## C. Danh Mục API Routes (Route Inventory)

Mọi API công khai được định hình phiên bản rõ ràng qua tiền tố `/v1`:

*   **POST `/v1/invitation/resolve`**
    *   *Mô tả:* Giải mã thông tin thiệp cưới từ token.
    *   *Input:* `raw_token` (truyền trong JSON body).
*   **POST `/v1/invitation/rsvp`**
    *   *Mô tả:* Gửi phản hồi RSVP hoặc cập nhật.
    *   *Input:* `raw_token` + Cấu trúc mảng phản hồi tham dự của các sự kiện con và các tùy chọn đi kèm.

---

## D. Thiết Kế Truyền Mã Link Thiệp Mời (Credential Transport Design)

Để đảm bảo an toàn, tránh rò rỉ mã Token của khách ra môi trường mạng:
*   **Phương án lựa chọn:** **Browser-only URL Fragment Identifier** (`#/invitation/<raw_token>`).
    *   *Lý do lựa chọn:* Nội dung sau ký tự `#` (fragment) không bao giờ được trình duyệt gửi lên máy chủ trong tiêu đề yêu cầu HTTP. Điều này triệt tiêu nguy cơ rò rỉ mã Token vào CDN logs, `Referer` trình duyệt sang link ngoài, hoặc hệ thống telemetry bên thứ ba.
*   **Quy trình xử lý tại Client (Guest Bootstrap Flow):**
    1.  Khách click link: `https://wedding.weddingos.com/#/invite/token_goc_entropy_cao`.
    2.  React SPA khởi động cục bộ trên trình duyệt.
    3.  Trước khi bất kỳ công cụ phân tích bên thứ ba hay telemetry nào khởi động, JS SPA đọc `token_goc` từ `window.location.hash`.
    4.  JS SPA thực hiện lệnh `window.history.replaceState` để xóa sạch Token khỏi URL hiển thị và lịch sử trình duyệt, bảo vệ link khi khách copy chia sẻ lại cho người khác.
    5.  JS SPA lưu Token ngắn hạn vào bộ nhớ tạm `sessionStorage` (phục vụ refresh tab cùng tab). Cấm lưu trữ vĩnh viễn ở `localStorage`.
    6.  SPA gửi Token trong JSON body của yêu cầu POST tới Edge Function Class D để lấy dữ liệu hiển thị.

---

## E. Quản Lý Bộ Nhớ Tạm Khách (Session Storage & Lifecycles - Đã ghi nhận `ERRATA-D-002`)

*   Bộ nhớ tạm `sessionStorage` chỉ được sử dụng cho kịch bản khôi phục phiên khi F5 refresh lại tab hiện tại. Đây **không phải** là tài khoản Guest, không phải là nguồn xác thực dài hạn hay cơ chế ủy quyền thứ hai. Mọi yêu cầu API gửi lên biên đều phải đi kèm mã credential gốc và được Edge Function xác thực trực tiếp với cơ sở dữ liệu.
*   **Xóa bỏ token lưu tạm:** Trình duyệt khách phải tự động xóa bỏ credential lưu tạm khi:
    *   Nhận mã lỗi báo Token không còn hoạt động hoặc bị vô hiệu hóa (`INVITATION_UNAVAILABLE`).
    *   Khách chủ động chọn thoát hoặc đóng ngữ cảnh thiệp mời hiện tại.
    *   Một link thiệp mời/credential mới được tải đè lên tab cũ thay thế ngữ cảnh hiện tại.
    *   Việc đóng tab hoặc hủy phiên duyệt trình tự động xóa sạch `sessionStorage`. Tuyệt đối cấm sử dụng `localStorage`.

---

## F. Xem Trước Trên Mạng Xã Hội (Social Preview / Bot Prefetch - Đã ghi nhận `CLASS-D-API-GAP-001`)

*   **Ràng buộc kỹ thuật:** Vì raw credential nằm trong URL Fragment, trình duyệt không bao giờ gửi fragment này lên server khi bot crawler (như Facebook Crawler, Zalo Bot) quét link. Do đó, việc phát hiện User-Agent để render xem trước cá nhân hóa là không khả thi.
*   **Giải pháp MVP:** 
    *   Trang hiển thị thông tin xem trước mạng xã hội (OpenGraph/Social Preview) dạng chung không cá nhân hóa (generic/non-personalized).
    *   Thông tin thiệp mời cá nhân chỉ được giải mã và tải trên trình duyệt khách sau khi SPA bootstrap và gửi POST request.
    *   Việc theo dõi lượt xem (View tracking) chỉ được kích hoạt khi có yêu cầu API `D-INV-001` thành công từ SPA trình duyệt thực tế.

---

## G. Đặc Tả Endpoint Giải Mã Thiệp `D-INV-001` (Resolve Invitation Contract - Đã ghi nhận `ERRATA-D-001` & `ERRATA-PHY-008`)

*   **Yêu cầu đầu vào:** JSON body chứa `raw_token` (độ dài và ký tự chuẩn hóa).
*   **Quy tắc xác thực tại Edge Function:**
    *   Tính toán băm SHA-256: `digest = sha256(raw_token)`.
    *   Truy vấn bảng `invitation_credentials` với `token_hash = digest AND is_active = true`.
    *   Xác minh Đám cưới chủ quản đang ở trạng thái `ACTIVE` hoặc `ARCHIVED` (Nếu `ARCHIVED`, cho phép đọc cấu hình cũ nhưng đánh dấu `can_edit_rsvp = false`).
    *   **Trạng thái DELETING (`ERRATA-PHY-008`):** Nếu Đám cưới chủ quản có `status = 'DELETING'`, Edge Function từ chối truy cập ngay lập tức và trả về mã lỗi `404 Not Found` (`INVITATION_UNAVAILABLE`).
    *   Xác minh trạng thái thiệp mời ở dạng `READY` hoặc `MARKED_AS_SENT`. Trạng thái `DRAFT` bị chặn truy cập công khai và trả về lỗi không tồn tại.
*   **Ghi nhận lượt xem (View Tracking Failure Semantics):**
    *   Ghi nhận lượt xem là tác vụ phụ (secondary side-effect). Nếu việc ghi nhận mốc thời gian xem gặp lỗi tạm thời nhưng thiệp mời xác thực thành công, hệ thống **không được phép làm gián đoạn** việc hiển thị thiệp mời của khách.
    *   `first_viewed_at`: Cập nhật tại lượt resolve thành công đầu tiên.
    *   `last_viewed_at`: Cập nhật tại các lượt resolve thành công kế tiếp.
    *   *Không thay đổi vòng đời:* Việc ghi nhận view tuyệt đối không làm thay đổi trạng thái lifecycle `status` của thiệp.
*   **Mã truy cập ảnh cưới (Signed Media URLs - Đã ghi nhận `ERRATA-D-003`):**
    *   Sinh kèm danh sách ảnh cưới đã ký nhận đặc quyền ngắn hạn. Thời hạn ký nhận được cấu hình động trên máy chủ (ví dụ: cấu hình khởi chạy ban đầu đề xuất là 30 phút). Thời gian này không đại diện cho giao ước tương thích phiên bản API v1 và máy chủ có quyền điều chỉnh thời gian hết hạn mà không làm ảnh hưởng đến cấu trúc DTO công khai.
    *   Nếu hết hạn, việc resolve lại hợp lệ sẽ trả về link ký mới.
*   **Bảo vệ chống quét Enumeration:** Nếu Token không khớp, bị thu hồi hoặc đám cưới bị khóa/xóa/đang xóa, API trả về chung một mã lỗi **`404 Not Found`** với lỗi `INVITATION_UNAVAILABLE`. Tuyệt đối không trả về các lỗi chi tiết để tránh lộ thông tin nội bộ.
*   **Thuật ngữ:** Endpoint được thiết kế ở chế độ **`retry-safe`** (gọi lại an toàn), không gọi là strict idempotent vì nó có cập nhật `last_viewed_at` và sinh mã ảnh cưới mới.

---

## H. Cấu Trúc Dữ Liệu Thiệp Mời Công Khai (Public Invitation DTO)

Edge Function lọc sạch toàn bộ dữ liệu hệ thống trước khi gửi về client:

### 1. Dữ liệu được phép trả về (Sanitized Fields):
*   Tên hiển thị cô dâu/chú rể, cấu hình chung đám cưới (timezone).
*   Tên hiển thị của Nhóm thiệp mời (`invitation_parties.display_name`).
*   Danh sách các Sự kiện con được target (`invitation_event_targetings`).
*   Cấu hình liên hệ công khai (`public_contact_phone`, `public_contact_email`).
*   Thông tin đính kèm tài khoản VietQR (chỉ khi đủ điều kiện tại Mục P).
*   Mảng trạng thái RSVP hiện tại của từng sự kiện để prefill form.
*   Cấu hình hạn chốt phản hồi (`rsvp_cutoff_date`) dạng ngày dương lịch, và cờ boolean `can_edit_rsvp`.
*   Danh sách ảnh cưới Signed URLs.

### 2. Dữ liệu tuyệt đối cấm trả về (Withheld Fields):
*   Khóa ngoại `wedding_id`, `user_id` của ban tổ chức.
*   Thông tin chi tiết tài chính, ngân sách cưới (`budget_items`).
*   Ghi chú nội bộ của ban tổ chức về khách mời.
*   Mã băm SHA-256 `token_hash` của thiệp.
*   Các mốc thời gian lưu vết kỹ thuật debug hệ thống.

---

## I. Định Dạng DTO Sự Kiện & Độ Chính Xác Ngày (Event DTO & Date Precision)

Cấu trúc DTO sự kiện gửi về Guest Web phản ánh chính xác ngày cưới không giả lập:
*   **Trường hợp Exact Date:** 
    *   `date_precision` = `EXACT`
    *   `exact_date` = `YYYY-MM-DD`
    *   Sự kiện hiển thị ở trạng thái **RSVP-ready** (sẵn sàng phản hồi).
*   **Trường hợp Expected Month:** 
    *   `date_precision` = `EXPECTED_MONTH`
    *   `expected_year` = `YYYY`
    *   `expected_month` = `MM`
    *   Sự kiện hiển thị dạng **Save-the-Date** (chỉ xem thông tin lịch trình dự kiến, cấm hiển thị nút RSVP hoặc gửi dữ liệu phản hồi tham dự).

---

## J. Đặc Tả Endpoint RSVP `D-RSV-001` (RSVP Mutation Contract)

*   **Yêu cầu đầu vào:** 
    *   `raw_token`: Để xác thực quyền gửi.
    *   `responses`: Mảng chứa các phản hồi theo từng sự kiện (`event_id`, `response_status` [ATTENDING/NOT_ATTENDING], `attending_count`).
    *   `optional_fields`: `companion_names` (mảng tên khách đi kèm), `dietary_info` (lưu ý dị ứng), `guest_message` (lời chúc).
*   **Quy tắc kiểm duyệt tại máy chủ:**
    *   Xác minh thời hạn phản hồi cưới `rsvp_cutoff_date` trong múi giờ của đám cưới chưa bị quá hạn (Chi tiết tại Mục L).
    *   Tất cả các `event_id` trong danh sách gửi lên bắt buộc phải thuộc danh mục sự kiện được target trong thiệp mời (`invitation_event_targetings`) và đang ở chế độ **RSVP-ready** (có Exact Date).
    *   Ràng buộc logic phản hồi:
        *   Nếu `response_status = ATTENDING` $\rightarrow$ `attending_count` bắt buộc phải $\ge 1$.
        *   Nếu `response_status = NOT_ATTENDING` $\rightarrow$ `attending_count` bắt buộc phải $= 0$.
    *   *Overcount:* Nếu tổng `attending_count` của các khách tham dự lớn hơn hạn mức mời `invited_count` của Party $\rightarrow$ Ghi nhận phản hồi thành công và trả về mã Warning `RSVP_OVERCOUNT` cho client, không từ chối giao dịch.

---

## K. Cơ Chế Cập Nhật RSVP Bán Phần (RSVP Patch/Upsert Semantics)

*   **Patch-by-Event Semantics:** Khước từ phương pháp ghi đè toàn bộ (Full Replace) cũ. Hệ thống áp dụng cơ chế cập nhật từng phần dựa trên ID sự kiện:
    *   *Sự kiện cưới con có mặt trong request:* Hệ thống cập nhật/thêm mới bản ghi `EventResponse` tương ứng.
    *   *Sự kiện cưới con vắng mặt trong request:* Bản ghi `EventResponse` hiện tại trong DB được giữ nguyên vẹn (không bị xóa, không bị cập nhật thành chưa phản hồi).
*   **Các trường thông tin tùy chọn cấp RSVP:**
    *   *Trường bị bỏ qua (omitted):* Giữ nguyên giá trị cũ trong DB.
    *   *Trường có giá trị explicit `null`:* Xóa bỏ dữ liệu cũ (gán NULL cho trường tương ứng trên DB).
    *   *Trường có giá trị mới:* Thay thế giá trị cũ bằng giá trị mới.
    *   *Đối với `companion_names`:* Giá trị truyền lên là `[]` đại diện cho yêu cầu xóa sạch danh sách người đi kèm cũ. Cấm tự động sinh đối tượng khách mời `Guest` trên DB từ tên người đi kèm.

---

## L. Quy Tắc Hạn Chốt Cutoff Date

*   **Thời gian cutoff:** Khách mời được phép gửi/sửa RSVP cho tới hết ngày ghi trong `rsvp_cutoff_date` tính theo múi giờ Đám cưới.
*   **Logic máy chủ:** Trạng thái gửi RSVP hợp lệ khi thời gian hiện tại của máy chủ **trước thời điểm bắt đầu của ngày kế tiếp** ngày hạn chốt (start of the calendar day AFTER cutoff) áp theo timezone cưới.
*   **Sau hạn chốt:** Mọi yêu cầu gửi RSVP từ client Class D sẽ bị từ chối ngay với mã lỗi `403 Forbidden` (`RSVP_CLOSED`). Khách chỉ được xem thông tin cũ ở dạng Read-only.
*   **Không khóa phiên bản client (No Client Optimistic Lock):** Loại bỏ hoàn toàn yêu cầu so khớp trường `updated_at` hay token phiên bản từ client trước khi cập nhật. Sử dụng nguyên tắc: **Bản ghi hợp lệ cập nhật cuối cùng sẽ chiến thắng (Latest valid update wins)**.

---

## M. Giới Hạn Kích Thước Dữ Liệu Nhập (Public Text Limits)

Để đảm bảo hiệu năng và phòng tránh tấn công từ chối dịch vụ (DoS), Edge Function thiết lập các giới hạn kiểm duyệt cứng trên dữ liệu đầu vào:
*   `guest_message`: Tối đa 1000 ký tự Unicode.
*   `dietary_info`: Tối đa 500 ký tự Unicode.
*   Mỗi tên người đi kèm trong `companion_names`: Tối đa 100 ký tự Unicode.
*   Mảng `companion_names`: Tối đa 20 phần tử.

Nếu bất kỳ trường nào vượt quá giới hạn, Edge Function từ chối giao dịch ngay lập tức bằng mã lỗi `400 Bad Request` (`INVALID_RESPONSE`) kèm thông tin chi tiết lỗi của trường bị vi phạm. Không tự ý cắt ngắn (truncate) dữ liệu khách nhập.

---

## N. Mã Cảnh Báo Phản Hồi RSVP (Warning Contract)

Cảnh báo là các thông tin phản hồi bổ sung giúp UX của client xử lý, không làm thất bại giao dịch:
*   **`RSVP_OVERCOUNT`:** Tổng số người đăng ký tham dự vượt quá hạn mức `invited_count` quy định cho hộ gia đình/nhóm mời. Hệ thống vẫn lưu dữ liệu thành công nhưng trả về warning để SPA hiển thị lời nhắc khéo léo cho khách.

---

## O. Mã Lỗi API Khách Mời (Error Contract - Đã ghi nhận `ERRATA-D-004`)

Hệ thống bảo vệ thông tin an ninh bằng cách trả về mã lỗi HTTP chuẩn hóa kết hợp Error Code an toàn:

| HTTP Status | Mã Lỗi (Error Code) | Ý nghĩa an toàn nghiệp vụ |
| :--- | :--- | :--- |
| **`404 Not Found`** | `INVITATION_UNAVAILABLE` | Token không khớp, bị thu hồi, đám cưới bị khóa/xóa/đang xóa (`DELETING`), hoặc thiệp đang ở dạng nháp. |
| **`403 Forbidden`** | `RSVP_CLOSED` | Quá hạn phản hồi cưới (`rsvp_cutoff_date`). |
| **`400 Bad Request`** | `INVALID_RESPONSE` | Lỗi logic gửi RSVP (ví dụ: truyền đi tham dự với số người bằng 0 hoặc quá giới hạn ký tự). |
| **`400 Bad Request`** | `EVENT_NOT_AVAILABLE` | Cố tình gửi RSVP cho lễ cưới con đã bị xóa, không được target, hoặc chưa chốt ngày (Expected Month). |
| **`429 Too Many Requests`** | `RATE_LIMITED` | Vi phạm tần suất gửi yêu cầu tối đa cho phép. |
| **`503 Service Unavailable`**| `TEMPORARY_UNAVAILABLE` | Lỗi kết nối database tạm thời của máy chủ hoặc hạ tầng biên gặp sự cố kỹ thuật. Chặn rò rỉ vết lỗi SQL hay hệ thống lưu trữ bên dưới. |

---

## P. Kiểm Soát Phơi Bày VietQR & Thông Tin Quà Tặng

Để bảo vệ quyền riêng tư tài khoản ngân hàng của ban tổ chức, thông tin VietQR/tài khoản ngân hàng chỉ được phơi bày trong DTO trả về của API resolve (`D-INV-001`) hoặc API RSVP (`D-RSV-001`) khi đáp ứng đủ đồng thời 3 điều kiện:
1.  Đám cưới cấu hình kích hoạt nhận quà tặng (VietQR enabled).
2.  Thiệp mời có tồn tại ít nhất một sự kiện con được target ở trạng thái RSVP-ready (có Exact Date).
3.  Trạng thái tổng hợp RSVP của thiệp mời hiện tại đạt mức **Đã hoàn thành phản hồi** (`RSVP Summary = RESPONDED`). Nếu đang ở trạng thái phản hồi một phần (`PARTIAL`) hoặc thiệp Save-the-Date-only, thông tin ngân hàng bắt buộc giữ ẩn.
*Lưu ý:* Việc khách chọn NOT_ATTENDING nhưng đã hoàn tất phản hồi đầy đủ vẫn được phép hiển thị VietQR nếu đám cưới cấu hình cho phép.

---

## Q. Thiết Kế An Ninh CDN, Caching & Logging (Đã ghi nhận `ERRATA-D-004`)

Để ngăn chặn rò rỉ dữ liệu thông qua hạ tầng truyền dẫn mạng:
1.  **shared CDN Caching Policy:** 
    *   API resolution và RSVP response trả về dữ liệu riêng tư của khách bắt buộc cấu hình tiêu đề phản hồi:
        `Cache-Control: no-store` hoặc các tiêu đề nghiêm ngặt chống lưu kho (strict no-storage semantics).
    *   Ngăn cản các CDN proxy trung gian lưu trữ đệm DTO của khách.
2.  **Chống rò rỉ qua Referrer:** SPA cấu hình tiêu đề:
    `<meta name="referrer" content="no-referrer">`
    Ngăn chặn trình duyệt gửi mã Token trên URL sang các liên kết bản đồ bên ngoài.
3.  **Redaction Logs (Lọc sạch Log):** Nhật ký Edge Function Class D bắt buộc loại bỏ trường `raw_token`, dị ứng khách mời, lời chúc thô và thông tin ngân hàng. Log chỉ ghi nhận mã ID thiệp mời nội bộ (UUID đã qua giải mã) và mã trạng thái HTTP.

---

## R. Rate Limiting & Phòng Chống Tấn Công Dò Quét

*   Áp dụng giới hạn tần suất yêu cầu (abuse controls) cấu hình động trên máy chủ.
*   Sử dụng IP/Network-level signal ở chặng pre-validation và băm định danh Invitation (fingerprint) ở chặng post-validation. 
*   Từ chối yêu cầu vượt ngưỡng bằng mã lỗi `HTTP 429 RATE_LIMITED`. Không lưu trữ token thô trong log rate limit.

---

## S. Ma Trận Kiểm Thử Bảo Mật API Công Khai (Public Security Test Matrix)

Các kịch bản kiểm thử bảo mật bắt buộc phải được viết test tự động ở chặng sau:

| Loại Kiểm Thử | Tình huống đầu vào (Input context) | Kết quả mong đợi (Expected Outcome) |
| :--- | :--- | :--- |
| **Xác thực mã hợp lệ** | Token active tồn tại, Đám cưới active, Thiệp ở dạng `READY` | Trả về DTO D-INV-001 thành công, ghi view tracking, sinh Signed URL. |
| **Xác thực mã nháp** | Token thuộc thiệp ở trạng thái `DRAFT` | Bị từ chối, trả về lỗi `404 INVITATION_UNAVAILABLE`. |
| **Xác thực mã thu hồi**| Token thuộc bản ghi credential có `is_active = false` | Bị từ chối, trả về lỗi `404 INVITATION_UNAVAILABLE`. |
| **Gửi RSVP bán phần** | Thiệp target Lễ A và Lễ B. Request chỉ chứa RSVP cho Lễ A | Lễ A cập nhật/thêm mới phản hồi. Lễ B giữ nguyên vẹn trạng thái cũ trên DB. |
| **Cập nhật trường tùy chọn**| Gửi request không chứa trường `guest_message` | Lời nhắn cũ trên DB được bảo toàn nguyên vẹn. |
| **Xóa trường tùy chọn** | Gửi request chứa `guest_message = null` | Lời nhắn cũ trên DB được xóa sạch (NULL). |
| **RSVP sau hạn chốt** | Ngày hiện tại vượt quá `rsvp_cutoff_date` trong timezone cưới | Bị từ chối, trả về lỗi `403 RSVP_CLOSED`. |
| **Tranh chấp ghi** | Ban tổ chức ghi đè, sau đó khách gửi update mới trước cutoff | RSVP của khách ghi thành công và trở thành trạng thái hiện tại (Latest wins). |
| **Bảo mật ảnh cưới** | Signed URL ảnh cưới hết hạn, gửi yêu cầu resolve mới hợp lệ | Nhận Signed URL mới hoạt động bình thường. |
| **Xem trước mạng xã hội**| Bot Facebook crawl link chứa Fragment | Trả về OG/Social Preview dạng chung không cá nhân hóa. |
| **Đám cưới đang xóa** | Đám cưới có trạng thái `DELETING`, gửi yêu cầu resolve | Bị từ chối, trả về lỗi `404 INVITATION_UNAVAILABLE`. |

---

## T. Nhật Ký Nhật Ký Xung Đột & Khoảng Trống API Class D (CLASS-D-API Gaps/Conflicts)

*   **`CLASS-D-API-GAP-001` (Bot/social preview vs fragment credential) $\rightarrow$ RESOLVED.** fragment không được gửi lên server nên crawler bot không thể xem trước cá nhân hóa. Giải quyết bằng cách phục vụ OG/Social Preview dạng chung (generic/non-personalized) cho MVP.
*   **`CLASS-D-API-CONFLICT-001` (Optimistic locking conflicted with latest-update rule) $\rightarrow$ RESOLVED.** Loại bỏ yêu cầu đối soát `updated_at` của client trước khi sửa RSVP, chuyển hoàn toàn sang cơ chế "Bản ghi hợp lệ cập nhật cuối cùng chiến thắng".
*   **`CLASS-D-API-CONFLICT-002` (Full-replace RSVP risked accidental loss of omitted responses) $\rightarrow$ RESOLVED.** Cơ chế ghi đè toàn bộ RSVP cũ làm mất phản hồi của các lễ cưới con không truyền lên. Chuyển sang cơ chế cập nhật từng phần dựa trên ID sự kiện (Patch-by-Event).
*   **`ERRATA-D-001` (Resolve Retry Terminology) $\rightarrow$ RESOLVED.** Định vị rõ D-INV-001 ở trạng thái retry-safe thay vì idempotent hoàn toàn do tác động đổi mới URL ký nhận ảnh và cập nhật last_viewed_at.
*   **`ERRATA-D-002` (Session Credential Lifetime) $\rightarrow$ RESOLVED.** Làm rõ giới hạn hoạt động và điều kiện tự động dọn sạch raw token trong sessionStorage trên trình duyệt.
*   **`ERRATA-D-003` (Media Expiry) $\rightarrow$ RESOLVED.** Ràng buộc thời gian sống Signed URL ảnh cưới là tham số cấu hình động, không phải là một cam kết API v1.
*   **`ERRATA-D-004` (Cache / Temporary Failure) $\rightarrow$ RESOLVED.** Áp dụng strict no-store thay vì "private" cho DTO động nhạy cảm, đồng thời chuẩn hóa mã lỗi hạ tầng/boundary 503 TEMPORARY_UNAVAILABLE.
*   **`ERRATA-PHY-008` (Wedding DELETING Lifecycle) $\rightarrow$ RESOLVED.** Edge Function resolve thiệp mời chặn truy cập và trả về mã 404 INVITATION_UNAVAILABLE khi Đám cưới có status = DELETING.
