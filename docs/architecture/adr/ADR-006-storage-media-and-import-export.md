# Quyết Định Kiến Trúc: ADR-006 — Storage, Media & Import/Export

*   **Mã quyết định (ADR ID):** ADR-006
*   **Trạng thái (Status):** Approved (Đã Phê duyệt)
*   **Người thực hiện:** Antigravity (AI Architect)
*   **Ngày cập nhật:** 20/08/2026

---

## 1. Ngữ Cảnh (Context)

Hệ thống WeddingOS yêu cầu các giải pháp lưu trữ hình ảnh và xử lý tệp tin nhập/xuất nghiệp vụ cốt lõi sau:
*   **Hình ảnh Đám cưới / Thiệp mời:** Hình ảnh đại diện cho trang thiệp online (tùy chọn, dung lượng tải lên tối đa là 5MB từ thiết bị Android của ban tổ chức).
*   **Nhập danh sách khách mời từ Excel:** OWNER nạp danh sách khách mời khoảng 300 dòng từ tệp Excel, thực hiện rà soát thông số (Mapping/Preview) và xác nhận trước khi lưu vào DB.
*   **Xuất bản rà soát cho bố mẹ:** Xuất danh sách khách mời định dạng Excel/PDF ẩn thông tin nhạy cảm để bố mẹ kiểm tra chéo (Parent Review Export).
*   **Ràng buộc hạ tầng:** Vận hành tối ưu trên hạ tầng miễn phí (`Free-tier-first`).

Quyết định này thiết lập kiến trúc lưu trữ đối tượng (Object Storage), quy trình tối ưu hóa hình ảnh, cơ chế phân tích dữ liệu nhập và tạo tệp tin xuất bản nghiệp vụ.

---

## 2. Phạm Vi Quyết Định (Scope)

### Quyết định trong tài liệu này:
*   Lựa chọn dịch vụ lưu trữ đối tượng (BaaS Storage Provider) cho phiên bản MVP.
*   Mô hình phân quyền truy cập hình ảnh (Public vs Private Media).
*   Quy trình tải lên hình ảnh từ thiết bị Android (Organizer Upload).
*   Nguyên tắc tối ưu hóa dung lượng truyền tải thiệp mời (Guest-facing Media Delivery).
*   Mã loại hình ảnh được phép tải lên hệ thống (Media Type Scope).
*   Kiến trúc phân tích và nhập liệu danh sách khách mời từ tệp Excel.
*   Lưu trữ tệp Excel gốc sau khi nhập (Original XLSX Persistence).
*   Kiến trúc sinh tệp xuất bản Excel/PDF cho bố mẹ.
*   Các điểm kích hoạt và điều kiện xem xét chuyển đổi sang Cloudflare R2.

### Các quyết định hoãn lại (Deferred / Out of Scope):
*   Tên bucket lưu trữ vật lý hoặc cấu trúc thư mục lưu trữ đối tượng chi tiết.
*   Thời gian hiệu lực cụ thể của mã ký truy cập ảnh (Signed URL lifetime).
*   Mã định dạng nén (Codec), chất lượng nén, và kích thước pixel hiển thị chuẩn.
*   Lựa chọn thư viện nén ảnh trên Flutter.
*   Lựa chọn thư viện phân tích Excel (`XLSX parser`) hay tạo PDF trên Client/Server.
*   SQL thiết lập quyền RLS đối với Storage.
*   Cơ chế cụ thể dọn dẹp các tệp tin mồ côi (orphaned files).

---

## 3. Các Phương Án Lưu Trữ Đối Tượng Cân Nhắc (Storage Options)

### Phương án A: Chỉ sử dụng Supabase Storage làm lưu trữ duy nhất cho MVP (SELECTED)
*   *Đánh giá:* Supabase cung cấp dịch vụ lưu trữ đối tượng tích hợp PostgreSQL quản lý RLS rất mạnh mẽ. Việc sử dụng Supabase Storage giúp giảm tối đa số lượng nhà cung cấp hạ tầng ban đầu (Provider count = 1), giảm chi phí tích hợp và cấu hình bảo mật.
*   *Phù hợp MVP:* Hoàn toàn đáp ứng được quy mô kiểm thử nội bộ và lưu giữ hình ảnh thiệp của MVP.

### Phương án B: Sử dụng Cloudflare R2 làm lưu trữ chính
*   *Đánh giá:* R2 cung cấp 10GB lưu trữ miễn phí và hoàn toàn không tính phí băng thông truyền tải dữ liệu đi (Egress = $0$). R2 là lựa chọn tốt để tối ưu hóa chi phí cho lưu trữ công khai quy mô lớn. Tuy nhiên, phương án này tăng độ phức tạp trong quản lý xác thực và phân quyền do tách rời khỏi Supabase, chưa cần thiết cho giai đoạn đầu của MVP.

### Phương án C: Mô hình Hybrid (Supabase Storage + Cloudflare R2)
*   *Đánh giá:* Supabase Storage lưu trữ các tài liệu nội bộ nhạy cảm và Cloudflare R2 lưu trữ ảnh cưới công khai của thiệp mời. Phương án này là tối ưu nhất về bảo mật và băng thông cho sản phẩm quy mô lớn, nhưng quá phức tạp đối với MVP.

---

## 4. Dữ Liệu Thực Tế Gói Dịch Vụ Nhà Cung Cấp (Provider Facts)
*(Khảo sát dữ liệu chính thức ngày 20/08/2026)*

*   **Supabase Storage Free Tier:**
    *   Dung lượng lưu trữ: **1 GB** miễn phí.
    *   Băng thông truyền tải đi (Egress): **5 GB / tháng** miễn phí.
    *   Tính năng: Hỗ trợ cả Bucket công khai (Public) và riêng tư (Private), hỗ trợ tạo Signed URL và cấu hình RLS. Tính năng tối ưu hóa ảnh động (Image Transformation) yêu cầu trả phí gói Pro.
*   **Cloudflare R2 Free Allowance:**
    *   Dung lượng lưu trữ: **10 GB / tháng** miễn phí.
    *   Class A Operations (Tạo/Sửa): **1 triệu** yêu cầu / tháng miễn phí.
    *   Class B Operations (Đọc): **10 triệu** yêu cầu / tháng miễn phí.
    *   Băng thông Egress: **Hoàn toàn miễn phí ($0)**. Storage và Operations vẫn tính phí vượt hạn mức theo bảng giá động của nhà cung cấp.

---

## 5. Phân Quyền Truy Cập Ảnh Cưới: Mô Hình Private Storage (Private Media Model)

WeddingOS quyết định sử dụng **mô hình truy cập ảnh cưới Riêng tư (PRIVATE Supabase Storage access model)** làm baseline bảo vệ hình ảnh đại diện thiệp mời, không sử dụng Public Bucket.
*   *Lý do:* Một URL Public Bucket trực tiếp có thể bị truy cập tự do từ internet mà không cần qua bất kỳ lớp xác thực nào của WeddingOS. Điều này vi phạm nguyên tắc bảo vệ quyền riêng tư hình ảnh cặp đôi, đặc biệt là khi đám cưới đã chuyển sang trạng thái lưu trữ (`Archived`).

### A. Phân quyền cho Khách mời (Guest Media Access)
*   Khách mời chỉ được phép truy cập hình ảnh thiệp sau khi mã thiệp (`Invitation credential`) được Edge Function xác thực hợp lệ, Đám cưới đang hoạt động, và Lời mời đang hoạt động.
*   Sau khi xác thực thành công, hệ thống cung cấp mã ký thời gian tạm thời (e.g. **signed media URL**) để Guest Web hiển thị ảnh.
*   *Hạn chế kiến trúc:* Mã ký truy cập ảnh đã cấp từ trước có thể không hỗ trợ thu hồi tức thời tuyệt đối dưới mọi điều kiện lưu cache trình duyệt hoặc CDN. Ranh giới kiến trúc cam kết: Khi đám cưới bị lưu trữ (`Archived`), hệ thống **chặn hoàn toàn việc ký cấp mới** (no NEW Guest media access is granted) cho khách mời.

### B. Phân quyền cho Ban tổ chức (Organizer Media Access)
*   Thao tác truy cập ảnh cưới của ban tổ chức được xử lý thông qua luồng xác thực tài khoản thông thường độc lập với luồng khách mời.
*   Khi đám cưới bị chuyển lưu trữ (`Archived Wedding`):
    *   Đám cưới và dữ liệu chuyển sang trạng thái chỉ xem (View-only).
    *   **Ảnh cưới lịch sử vẫn được bảo toàn nguyên vẹn**, không bị hệ thống tự động xóa đi.
    *   Các thành viên ban tổ chức đã xác thực và có quyền vẫn tiếp tục xem được ảnh này trong ứng dụng Android. Giao diện khách mời (Guest flow) bị chặn không cấp mã ký mới.

---

## 6. Cơ Chế Tải Lên & Tối Ưu Hóa Hình Ảnh (Organizer Upload & Optimization)

*   **Tối ưu hóa phía Client (Client-side compression):** Khi người dùng Android chọn một hình ảnh cưới (> 5MB):
    *   Ứng dụng Android (Flutter) thực hiện resize và nén ảnh trực tiếp trên thiết bị trước khi upload để tiết kiệm băng thông và không gian lưu trữ đối tượng. Định dạng nén cụ thể (WebP/JPEG), kích thước và chất lượng nén được hoãn lại để kiểm thử thực tế.
*   **Giới hạn 5MB:** Mức giới hạn `5MB` là ràng buộc đầu vào tải lên tối đa (upload input limit / product constraint) trên Android, hoàn toàn không phải là mục tiêu dung lượng truyền tải tải về Guest Web (delivered payload). Dung lượng ảnh tải về Web khách mời phải được nén nhỏ để đảm bảo các chỉ tiêu hiệu năng tải trang NFR.
*   **Xác thực phía Server (Authoritative Validation):** Ranh giới lưu trữ và máy chủ tin cậy bắt buộc phải tự thực thi kiểm tra an toàn độc lập, không tin tưởng hoàn toàn vào siêu dữ liệu (metadata) hay đuôi tệp tin do client gửi lên.
    *   Kiểm tra quyền hạn ghi của tài khoản (Wedding authorization).
    *   Kiểm tra dung lượng file thực tế dưới 5MB.
    *   Kiểm tra loại tệp tin (chỉ chấp nhận các loại ảnh raster thông dụng được yêu cầu, chặn tải lên các tài liệu tùy ý, video hay SVG để tránh rò rỉ bảo mật). Thiết kế chi tiết về magic bytes hay trình quét malware được hoãn lại.
*   **Tham chiếu lưu trữ (Storage Reference):** Hệ thống chỉ lưu trữ đường dẫn đối tượng logic (Object Path / Reference) trong DB thay vì URL tuyệt đối, giúp dễ dàng di chuyển dữ liệu sang nhà cung cấp khác nếu cần.

---

## 7. Đánh Giá Áp Lực Băng Thông Ảnh Cưới (Media Egress Scenarios)
Giả định đám cưới đạt quy mô tối đa validation MVP: **20.000 khách mời** truy cập thiệp mời, phát sinh **40.000 lượt tải trang** (tải ảnh cưới).

Hệ thống Supabase phân biệt rõ quota băng thông đi có cache (cached egress) và không cache (uncached egress). Bảng đánh giá dưới đây thể hiện mức độ áp lực truyền tải vật lý của hình ảnh (Traffic model):

*   **Ảnh cưới 100 KB:**
    *   1 lượt mở/khách $\approx$ **2 GB**
    *   2 lượt mở/khách $\approx$ **4 GB**
    *   *Đánh giá áp lực:* **Thấp (Low media-pressure).** Phù hợp tốt gói Free.
*   **Ảnh cưới 250 KB:**
    *   1 lượt mở/khách $\approx$ **5 GB**
    *   2 lượt mở/khách $\approx$ **10 GB**
    *   *Đánh giá áp lực:* **Trung bình (Medium media-pressure).** Có nguy cơ vượt quota nếu tỉ lệ hit cache thấp.
*   **Ảnh cưới 500 KB:**
    *   1 lượt mở/khách $\approx$ **10 GB**
    *   2 lượt mở/khách $\approx$ **20 GB**
    *   *Đánh giá áp lực:* **Cao (High media-pressure).** Nguy cơ vượt hạn mức miễn phí rất lớn.

---

## 8. Kiến Trúc Nhập Liệu Khách Mời Từ Excel (Excel Import Processing)

### A. Phân tích phía Client (Client-side Preview)
*   **Thao tác:** Ứng dụng Android (Flutter) nạp tệp Excel (quy mô khoảng 300 dòng) và thực hiện phân tích cú pháp (parsing) cục bộ trên thiết bị của cặp đôi.
*   **Mục tiêu:** Hiển thị màn hình xem trước dữ liệu nhập (`AND-GUE-07`), thực hiện ánh xạ cột (Mapping) và hiển thị cảnh báo lỗi dữ liệu ngay lập tức cho người dùng xử lý trước khi gửi xác nhận.
*   **Khôi phục phiên nhập (Import Session Recovery):** Trạng thái phiên import đang làm việc (dữ liệu thô đã đọc, trạng thái mapping cột) được lưu tạm thời vào cache cục bộ trên thiết bị của ban tổ chức để khôi phục nhanh nếu app bị gián đoạn, không đồng bộ dữ liệu phiên này lên máy chủ, không cần cloud persistence hay mutation queue.

### B. Xác nhận nhập liệu (Confirm Import)
*   Khi người dùng bấm chọn Xác nhận nhập dữ liệu trên giao diện:
    *   Ứng dụng gửi lệnh nhập chuẩn hóa (Normalized import command) lên **Giao dịch Nghiệp vụ Tin cậy (CLASS C Trusted Business Operation)** để thực thi.
    *   Môi trường máy chủ tin cậy tiến hành xác thực nghiệp vụ tối cao: quyền của tài khoản, kiểm tra trùng lặp khách mời dựa trên số điện thoại, đối soát số lượng được mời (`Invited Count`), đảm bảo tính nhất quán của Party Key, đối chiếu ánh xạ Guest Source và toàn bộ tính toàn vẹn nghiệp vụ.
*   **Không lưu trữ tệp Excel gốc (No XLSX Persistence):** WeddingOS **không lưu giữ** tệp XLSX thô của người dùng trên Supabase Storage. Điều này giúp loại bỏ rủi ro rò rỉ PII từ tệp thô, tiết kiệm không gian lưu trữ và tránh nhân bản dữ liệu nhạy cảm. File nguồn trên thiết bị người dùng là nguồn lưu trữ duy nhất của họ.

### C. Tải tệp mẫu (Template Distribution)
*   Tệp Excel biểu mẫu nhập liệu chuẩn được phục vụ dưới dạng tệp tĩnh phiên bản (static versioned asset) đính kèm sẵn trong bundle ứng dụng Android, không cần yêu cầu Edge Function sinh động tệp tin này khi tải xuống.

---

## 9. Kiến Trúc Xuất Bản Danh Sách Cho Bố Mẹ (Parent Review Export)

*   **Tạo tệp phía Client (Client-side Generation):** Thiết bị di động Android của ban tổ chức sẽ tự đảm nhiệm việc chuyển đổi dữ liệu danh sách khách mời hiện có thành định dạng Excel/PDF (bằng thư viện Flutter cục bộ).
    *   *Lý do:* Phù hợp hoàn hảo với quy mô dữ liệu nhỏ (300 dòng), tận dụng năng lực tính toán của thiết bị di động, tránh tiêu tốn tài nguyên tính toán (compute time) giới hạn của Supabase Edge Functions trên hạ tầng miễn phí.
*   **Ràng buộc phân quyền dữ liệu:** 
    *   Quá trình xuất tệp cục bộ tuyệt đối không được bypass cơ chế phân quyền (Không cho phép xuất dữ liệu tài chính nhạy cảm nếu tài khoản là `Editor`).
    *   Trình xuất bản mặc định ẩn toàn bộ Số điện thoại, Email và Ghi chú nội bộ của khách mời (chỉ hiện Tên hiển thị, Side, số lượng mời) để phục vụ bố mẹ rà soát chéo an toàn, trừ khi người dùng chủ động tích chọn hiển thị rõ ràng trên giao diện xuất bản (`AND-GUE-08`).
*   **Không lưu trữ tệp xuất bản (No Permanent Export Copies):** Tệp Excel/PDF sau khi được tạo ra trên thiết bị di động Android sẽ được mở hoặc chia sẻ trực tiếp thông qua hệ sinh thái Android Intent, không tải lên hay lưu giữ vĩnh viễn trên Supabase Storage.

---

## 10. Nguyên Tắc Quản Lý Vòng Đời Tệp Tin (File Lifecycle Principles)

*   **Ảnh cưới bị thay thế:** Khi người dùng upload ảnh cưới mới, đối tượng ảnh cũ phải được dọn dẹp để tránh phát sinh tệp tin mồ côi (orphaned objects) chiếm dụng dung lượng lưu trữ vĩnh viễn. Thiết kế kỹ thuật dọn dẹp được hoãn lại.
*   **Đám cưới bị lưu trữ (Archived):** Ảnh cưới lịch sử được giữ lại cho ban tổ chức xem, chặn hoàn toàn việc ký cấp mới đường link ảnh cho Guest Web.
*   **Đám cưới bị xóa:** Tuân thủ theo chính sách xóa/lưu giữ dữ liệu chung của đám cưới (hoãn thiết kế chính sách xóa chi tiết).
*   **Nhập Excel thất bại/hủy:** Do không upload file XLSX gốc lên cloud nên không phát sinh rác cần dọn dẹp trên Storage.
*   **Xuất file cho bố mẹ:** Tệp tin chỉ lưu trữ tạm thời trên bộ nhớ thiết bị Android của người dùng, không tạo bản copy trên WeddingOS Storage.

---

## 11. Điều Kiện Xem Xét Chuyển Đổi Sang Cloudflare R2 (R2 Reconsideration Triggers)

Kiến trúc sẽ duy trì Supabase Storage cho MVP. Trận chiến chuyển sang Cloudflare R2 chỉ được kích hoạt dựa trên đo lường thực tế tại giai đoạn validation sản phẩm:
*   Mức băng thông truyền tải ảnh (media egress) hoặc dung lượng lưu trữ thực tế tiệm cận giới hạn gói miễn phí của Supabase, gây áp lực tăng chi phí vận hành.
*   Sự gia tăng quy mô ảnh thiệp cưới thực tế vượt tầm kiểm soát của Supabase Free-tier.
*   Độ phức tạp tích hợp thêm R2 được chứng minh là xứng đáng so với lợi ích chi phí mang lại.
*   *Lưu ý về R2:* R2 miễn phí băng thông truyền tải đi (Egress = $0$), tuy nhiên dung lượng lưu trữ và các lớp operation Class A/B vẫn tính phí khi vượt định mức miễn phí của Cloudflare.

---

## 12. Đánh Giá Rủi Ro An Ninh Lưu Trữ (Security & Privacy Risks)

*   `PRIVATE_MEDIA_LINK_LEAK`: Link ký ảnh (signed URL) bị lộ ra ngoài. Biện pháp: Thiết lập thời gian sống của signed URL ngắn, chỉ đủ để kết xuất trang thiệp.
*   `SIGNED_MEDIA_ACCESS_LIFETIME`: Thời gian sống của signed URL quá dài làm mất tính bảo mật khi archive. Biện pháp: Đưa signed URL lifetime vào danh mục cấu hình bảo mật biên.
*   `PII_EXCEL_SOURCE_RETENTION`: Rò rỉ thông tin cá nhân khách mời từ tệp Excel thô lưu đệm trên server. Biện pháp: Chặn tuyệt đối việc lưu trữ tệp XLSX nguồn vào máy chủ.
*   `EXPORT_PII_LEAK`: Rò rỉ thông tin cá nhân qua tệp xuất bản cho bố mẹ. Biện pháp: Mặc định ẩn SĐT/Email/Ghi chú và tạo file cục bộ trên thiết bị của ban tổ chức.
*   `MALICIOUS_OR_SPOOFED_IMAGE`: Tải lên tệp độc hại giả dạng ảnh. Biện pháp: Biên lưu trữ xác thực cấu trúc tệp ảnh và giới hạn dung lượng tải lên nghiêm ngặt.
*   `MEDIA_EGRESS_EXHAUSTION`: Tấn công spam tải ảnh cưới làm cạn kiệt hạn mức băng thông máy chủ. Biện pháp: Triển khai CDN caching kết hợp Rate Limiting ở API biên.
*   `ORPHANED_MEDIA`: Tệp tin cũ chiếm dụng không gian lưu trữ. Biện pháp: Thực thi cơ chế ghi đè tệp tin theo ID đám cưới cố định.

---

## 13. Đánh Giá Khả Năng Di Chuyển Hạ Tầng (Vendor Lock-in)

*   **Supabase Storage:** Có coupling ở mức SDK gọi API và cấu hình Storage RLS gắn với Postgres. Tuy nhiên, do hệ thống sử dụng tham chiếu đối tượng logic (Object Reference) thay vì lưu URL tuyệt đối, việc di chuyển cấu trúc tệp sang S3-compatible API như Cloudflare R2 rất dễ dàng bằng các công cụ sync đối tượng tiêu chuẩn mà không phải sửa đổi schema dữ liệu nội bộ.
