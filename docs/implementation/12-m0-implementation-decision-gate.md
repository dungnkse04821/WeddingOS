# Kế Hoạch Triển Khai: 12 — M0 Implementation Decision Gate (Cửa Quyết Định Triển Khai M0)

*   **Trạng thái (Status):** In Review (Đang Đánh giá)
*   **Người thực hiện:** Antigravity (AI Architect)
*   **Ngày cập nhật:** 21/08/2026

---

## 1. Mục Tiêu (Purpose)

Tài liệu này giải quyết các quyết định thiết kế chi tiết ở mức triển khai (M0 Decision Gate) để chuẩn bị các điều kiện chạy các đợt di trú cơ sở dữ liệu `BATCH-00`, `BATCH-01` và lập trình lát cắt dọc đầu tiên (First Vertical Slice). Tài liệu tuân thủ nghiêm ngặt kiến trúc đã được phê duyệt, không thiết kế lại hoặc thay đổi các quyết định nghiệp vụ/kiến trúc cốt lõi.

---

## 2. Tài Liệu Nguồn Tham Chiếu (Authoritative Inputs)

Quá trình lập quyết định dựa trên các tài liệu đã được phê duyệt chính thức:
*   Đánh giá Kiến trúc Kỹ thuật: [`09-technical-architecture-final-review.md`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/architecture/09-technical-architecture-final-review.md)
*   Danh mục Backlog MVP: [`10-mvp-backlog.md`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/planning/10-mvp-backlog.md)
*   Kế hoạch Triển khai Thực thi: [`11-implementation-plan.md`](file:///D:/Dung/Project/VibeCode/WeddingOS/docs/planning/11-implementation-plan.md)

---

## 3. Phân Loại Quyết Định Hoãn Lại (Decision Classification)

Phân loại toàn bộ các quyết định hoãn lại từ Register của tài liệu `09`:

| Mã Quyết Định | Nội Dung Quyết Định Hoãn Lại | Phân Loại Cụ Thể | Ghi Chú / Điều Kiện Kích Hoạt |
| :--- | :--- | :---: | :--- |
| **`DEC-A-001`** | Kiểu dữ liệu vật lý chính xác của cột tiền tệ | **CLOSE NOW** | Cần thiết để khởi tạo bảng tài chính ở Batch 05 |
| **`DEC-A-002`** | Phân vùng bảng cơ sở dữ liệu | **CLOSE NOW** | Cần thiết trước khi chạy BATCH-00/BATCH-01 |
| **`DEC-A-003`** | Schema/Function ownership và role thực thi | **CLOSE NOW** | Cần thiết để cấu hình DB Batch 00 |
| **`DEC-B-001`** | Cấu trúc file cấu hình template công việc | **CLOSE BEFORE FEATURE** | Cần chốt trước Story `STORY-02-01` (TOP-WED-002) |
| **`DEC-B-002`** | Entropy và định dạng Token thiệp mời | **CLOSE BEFORE FEATURE** | Cần chốt trước Story `STORY-06-01` (M3) |
| **`DEC-B-003`** | Cấu trúc thư mục private Storage | **CLOSE BEFORE FEATURE** | Cần chốt trước Story `STORY-10-01` (M5) |
| **`DEC-B-004`** | Cơ chế rate limit Class D | **CLOSE BEFORE FEATURE** | Cần chốt trước cả `D-INV-001` và `D-RSV-001` (M4) |
| **`DEC-C-001`** | Thư viện parse Excel local trên Flutter | **DETAIL ONLY** | Chi tiết code (Story `STORY-09-01`) |
| **`DEC-C-002`** | Thuật toán serialize băm request_hash | **DETAIL ONLY** | Chi tiết code (Mốc `M1` / Lát cắt 1) |
| **`DEC-C-003`** | Naming convention tệp Edge / RPC | **DETAIL ONLY** | Chi tiết code |
| **`DEC-C-004`** | Quy trình CI/CD | **DETAIL ONLY** | Chi tiết vận hành |
| **`DEC-C-005`** | pgTAP / Database test framework | **DETAIL ONLY** | Chi tiết code (Story `STORY-13-01`) |
| **`DEC-D-001`** | Push/Email/SMS automation | **POST-MVP** | Loại bỏ hoàn toàn khỏi MVP |
| **`DEC-D-002`** | AI/RAG tasks suggestions | **POST-MVP** | Loại bỏ hoàn toàn khỏi MVP |
| **`DEC-D-003`** | Offline sync di động | **POST-MVP** | Loại bỏ hoàn toàn khỏi MVP |

---

## 4. Đặc Tả & Giải Quyết Các Quyết Định Nhóm A (DEC-A Audit)

### 4.1. Giải quyết quyết định `DEC-A-001` (Numeric Precision/Scale) — CLOSED
*   **Câu hỏi:** Độ chính xác vật lý của trường tiền tệ (authoritative monetary values)?
*   **Ràng buộc kiến trúc:** Bắt buộc dùng `NUMERIC` mức DB và Decimal String mức API. Cấm dùng float/double.
*   **Lý do lựa chọn:** Tiền tệ VND không có các đơn vị cent nhỏ lẻ (đồng xu VND nhỏ nhất là 200đ đã dừng lưu hành). Giao dịch ngân sách tiệc cưới tại Việt Nam thông thường dưới 10 tỷ VND, hoàn toàn nằm trong giới hạn tối đa 9.999.999.999.999,99đ (~10 nghìn tỷ VND) của **`numeric(15, 2)`**. Định dạng này đảm bảo tính toán nguyên tử không làm tròn sai số, có đủ dung lượng cộng dồn ngân sách tổng chặng MVP (aggregation headroom), và tương thích hoàn hảo với Decimal String chặng truyền nhận API. Không phát triển đa tiền tệ (multi-currency) chặng MVP.
*   **Lựa chọn chốt:** **`PostgreSQL numeric(15,2)`**.

### 4.2. Giải quyết quyết định `DEC-A-002` (Partitioning & Indexing) — CLOSED
*   **Câu hỏi:** Có cần phân vùng (partitioning) dữ liệu vật lý theo `wedding_id` chặng MVP?
*   **Khuyến nghị & Lựa chọn:** **Không phân vùng cho MVP**. Quy mô đám cưới MVP tối đa 150-300 khách, tổng số công việc/giao dịch ít, dữ liệu đám cưới độc lập được cô lập tốt qua RLS. Sử dụng chỉ mục index cơ bản (B-Tree trên các cột khóa ngoại) để đáp ứng hiệu năng truy vấn.
*   *Lưu ý:* B-Tree là chỉ mục mặc định được lựa chọn cơ bản. Hệ thống không cấm sử dụng các loại chỉ mục index đặc thù khác (như GiST hay GIN) chặng sau nếu phát sinh nhu cầu truy vấn thực tế.

### 4.3. Giải quyết quyết định `DEC-A-003` (Schema & Function Ownership) — CLOSED
*   **Câu hỏi:** Phân chia ranh giới và phân quyền quyền sở hữu thực thi di trú, RPC và actor?
*   **Lựa chọn chốt:**
    *   **Thực thi Di trú (Migration Executor):** Sử dụng quyền hạn quản trị dự án Supabase (Local/Staging dùng role `postgres`). Role này thực hiện tạo cấu trúc bảng vật lý (DDL).
    *   **Quyền sở hữu Trusted Function (Trusted Function Owner):**
        *   Tạo một role không đăng nhập (`trusted_function_owner`) được cấu hình **`NOLOGIN`** và **`BYPASSRLS`** với các đặc quyền tối thiểu cần thiết để sửa đổi dữ liệu (ví dụ: ghi biên nhận, cập nhật budget/installments/payments). Role này không bao giờ được lộ credentials cho Flutter/Guest Web hay lưu trữ dưới dạng client secret.
        *   Các hàm `SECURITY DEFINER` tin cậy chạy dưới quyền `trusted_function_owner` bắt buộc phải cấu hình `search_path = ''` và sử dụng fully-qualified object references để ngăn chặn lỗ hổng hijacking.
        *   Chỉ sử dụng `SECURITY DEFINER` cho các tác vụ thực sự đòi hỏi vượt qua chính sách RLS (như ghi nhận giao dịch tài chính hoặc biên nhận); các hàm khác ưu tiên sử dụng `SECURITY INVOKER`. Không tự động khai báo toàn bộ RPC trong `api_v1` là `SECURITY DEFINER`.
    *   **Business Actor:** Được xác định độc lập và tin cậy thông qua mã định danh người dùng JWT (`auth.uid()`) cung cấp bởi Supabase Auth Context. Quyền hạn của user thông thường (`authenticated`) chỉ được `EXECUTE` trên các RPC công khai chỉ định trong schema `api_v1`, tuyệt đối không được kế thừa quyền quản trị hay quyền của `trusted_function_owner`.

---

## 5. Quy Trình Xác Thực Google $\rightarrow$ Supabase (Auth Flow) — CLOSED

*   **Giải quyết `M0-CONFLICT-001`:** Khắc phục lỗi đồng nhất thông tin xác thực Google JWT trực tiếp thành Bearer token của database. Quy trình xác thực của ứng dụng di động Flutter Ban tổ chức chốt như sau:
    1.  Ứng dụng Flutter sử dụng thư viện **Native Google Sign-In** để yêu cầu người dùng đăng nhập.
    2.  Nhận về thông tin định danh Google bao gồm cả **Google ID Token** và **Google Access Token** (cả hai tham số đều bắt buộc để Supabase Auth thực thi xác thực).
    3.  Ứng dụng Flutter gửi cả hai token này qua hàm của Supabase SDK: **`signInWithIdToken`** (Google provider credentials).
    4.  Supabase Auth server xác thực thông tin định danh với Google API, sinh ra phiên làm việc **Supabase Session** hợp lệ và trả về cho thiết bị.
    5.  Thiết bị lưu trữ Session, Supabase client tự động đính kèm mã **Supabase Access Token JWT** này vào header của mọi request gọi Data API hoặc RPC.
    *   *Bảo mật:* Tuyệt đối không lưu trữ service key hay server credentials bên trong Flutter client.

---

## 6. Phơi Bày PostgREST Schema api_v1 & Hạn Chế Phân Quyền (Data API Exposure) — CLOSED

*   **Giải quyết `M0-CONFLICT-002` & `M0-GAP-004`:** Cấu hình phơi bày schema API của dự án:
    *   **Cấu hình local (`supabase/config.toml`):** Sử dụng khóa cấu hình API chuẩn của Supabase CLI:
        ```toml
        [api]
        schemas = ["public", "api_v1"]
        ```
    *   **Cấu hình Staging:** Đồng bộ cấu hình API schemas tương tự trên trang quản trị dự án Supabase Cloud.
    *   **An toàn Schema nghiệp vụ:** Tuyệt đối không phơi bày các schema nội bộ `security`, `internal`, và `private` ra PostgREST API.
    *   **Hạn chế quyền tối thiểu (Least Privilege):**
        *   Chỉ thực hiện `GRANT USAGE ON SCHEMA api_v1 TO authenticated`. Tuyệt đối **không cấp quyền USAGE schema `api_v1` cho vai trò `anon`**. Quyền truy cập ẩn danh chỉ dành cho các API Class D của khách mời thông qua Edge Functions.
        *   Rút quyền thực thi mặc định của public trên toàn bộ hàm nghiệp vụ (`ALTER DEFAULT PRIVILEGES IN SCHEMA api_v1 REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC`).
        *   Cấp quyền `EXECUTE` cụ thể trên từng RPC của `api_v1` cho vai trò `authenticated`.

---

## 7. Phân Loại Các Trường Băm Biên Nhận create_wedding (Semantic Hash Field Audit) — CLOSED

*   **Giải quyết `M0-GAP-001`:** Phân loại toàn bộ các trường đầu vào của DTO tạo đám cưới `api_v1.create_wedding` phục vụ băm request_hash:

| Tên Trường Request | Kiểu Dữ Liệu | Phân Loại Thuộc Tính | Ghi Chú |
| :--- | :--- | :--- | :--- |
| **`name`** | `varchar(255)` | **SEMANTICS_AFFECTING_AND_HASHED** | Tên đám cưới (Display identity) |
| **`cultural_context`** | `varchar(50)` | **SEMANTICS_AFFECTING_AND_HASHED** | Quyết định template công việc ban đầu |
| **`exact_date`** | `date` | **SEMANTICS_AFFECTING_AND_HASHED** | Ngày cưới cụ thể (Nếu chọn ngày chính xác) |
| **`expected_year`** | `integer` | **SEMANTICS_AFFECTING_AND_HASHED** | Năm dự kiến (Nếu chọn ngày tương đối) |
| **`expected_month`** | `integer` | **SEMANTICS_AFFECTING_AND_HASHED** | Tháng dự kiến (Nếu chọn ngày tương đối) |
| **`timezone`** | `varchar(50)` | **SEMANTICS_AFFECTING_AND_HASHED** | Múi giờ mặc định |
| **`target_budget`** | `numeric(15,2)` | **SEMANTICS_AFFECTING_AND_HASHED** | Ngân sách dự kiến ban đầu (Nếu có) |
| **`request_id`** | `uuid` | **TRANSPORT_METADATA_EXCLUDED** | Tránh trùng lặp, không đưa vào hash |
| **`correlation_metadata`**| `json` | **TRANSPORT_METADATA_EXCLUDED** | Siêu dữ liệu theo dõi |
| **`ui_metadata`** | `json` | **TRANSPORT_METADATA_EXCLUDED** | Siêu dữ liệu UI hiển thị |

*   *Cơ chế:* Mọi biến động của các trường thuộc nhóm `SEMANTICS_AFFECTING_AND_HASHED` khi gửi cùng một `request_id` bắt buộc phải kích hoạt lỗi `REQUEST_ID_REUSED` (409) do sai lệch request_hash trên bản ghi receipt.
*   *Xác thực Actor:* RPC tự lấy ID người dùng từ Auth context (`auth.uid()`), gán làm thành viên `OWNER` đầu tiên cho đám cưới. Flutter client không được truyền `actor_user_id` hay `wedding_member_id` trực tiếp lên.
*   *Thông tin thành viên:* Các thông tin định danh thành viên ban đầu (email, display name) được trích xuất trực tiếp từ JWT context đáng tin cậy của Google Auth session, không lấy từ thuộc tính metadata do người dùng tự chỉnh sửa ở phía client (user-editable auth metadata).

---

## 8. Cấu Hình Môi Trường & Kiểm Thử (Environment & Test Status) — CLOSED

*   **Quy chế thuật ngữ:** M0 là cửa ngõ quyết định lý thuyết (decision gate), không tuyên bố các tác vụ runtime đã hoàn thành:
    *   *Môi trường Local:* Đã thống nhất mô hình Supabase Local Docker.
    *   *Môi trường Staging:* Đã thống nhất mô hình host Supabase Cloud & CF Pages.
    *   *Test Tooling:* Chốt sử dụng framework **`pgTAP`** để kiểm thử an ninh RLS, Grants và DB constraints.
    *   *Release criteria:* 100% các bài test bảo mật/integrity bắt buộc phải pass. Dự án không sử dụng chỉ số code coverage phần trăm của client làm điều kiện phóng thích.
    *   *Test Fixtures:* Đã định hình mô hình User A (owner), User B (outsider).

---

## 9. Phân Chia Đợt Khởi Tạo Di Trú (Batch Readiness)

*   **`BATCH-00` Readiness:** 🟢 **READY (Sẵn sàng)**
    *   *Quy mô cho phép:* Khởi tạo schema `private`, `security`, `api_v1`, `internal`, các extensions yêu cầu, role đặc quyền `trusted_function_owner` (không có login), và thiết lập rút quyền thực thi mặc định của PUBLIC.
    *   *Chặn:* Không chứa bất kỳ bảng nghiệp vụ nào và không chứa triggers/policies phụ thuộc bảng.
*   **`BATCH-01` Readiness:** 🟢 **READY (Sẵn sàng)**
    *   *Quy mô cho phép:* Khởi tạo `weddings`, `wedding_members`, `pending_collaborator_invitations`. 
    *   *Tạo bảng Receipt:* Tạo bảng `private.trusted_operation_receipts` ngay sau `weddings` để bảo toàn khóa ngoại vật lý, sau đó mới nạp các helper functions và RPC `api_v1.create_wedding`.
    *   *Kiểm thử:* Quy trình kiểm thử bắt buộc phải assert role `trusted_function_owner` có đủ thẩm quyền ghi dữ liệu mà không cần chia sẻ quyền hạn này cho vai trò `authenticated`/`anon`.

---

## 10. Phụ Thuộc Quyết Định Nhóm B (DEC-B Register Mapping) — CLOSED

Các quyết định nhóm B được ánh xạ phụ thuộc vào tiến độ tính năng nghiệp vụ:
*   `DEC-B-001` (Template format) $\rightarrow$ Cần chốt trước Story **`STORY-02-01`** (Sinh kế hoạch cưới ban đầu).
*   `DEC-B-002` (Token entropy/encoding) $\rightarrow$ Cần chốt trước Story **`STORY-06-01`** (Sinh mã định danh thiệp).
*   `DEC-B-003` (Storage path bucket) $\rightarrow$ Cần chốt trước Story **`STORY-10-01`** (Lưu trữ ảnh cưới).
*   `DEC-B-004` (Class D abuse limiter mechanism) $\rightarrow$ Cần chốt trước cả 2 hàm **`D-INV-001`** và **`D-RSV-001`** (Resolve và RSVP Class D). Cơ chế chặn IP 15 phút bị loại bỏ khỏi MVP.

---

## 11. Nhật Ký Lỗi & Mâu Thuẫn M0 (M0 Gap/Conflict Register)

*   **`M0-CONFLICT-001` (Google provider credential vs Supabase application session authority) $\rightarrow$ RESOLVED.** Khắc phục quy trình đổi Token native Google (ID Token + Access Token) qua hàm `signInWithIdToken` để nhận Supabase Session hợp lệ.
*   **`M0-CONFLICT-002` (Incorrect local PostgREST schema configuration key) $\rightarrow$ RESOLVED.** Sử dụng định dạng cấu hình chuẩn CLI `[api] schemas = [...]` thay vì `db_schemas`.
*   **`M0-GAP-001` (Create-Wedding semantic hash field coverage) $\rightarrow$ RESOLVED.** Phân loại chi tiết toàn bộ các trường đầu vào của DTO tạo đám cưới phục vụ băm request_hash.
*   **`M0-GAP-002` (api_v1 Data API exposure/configuration) $\rightarrow$ RESOLVED.** Xác lập phơi bày schema `api_v1` mức PostgREST config và thu hồi EXECUTE mặc định của public.
*   **`M0-GAP-003` (Migration executor vs trusted function ownership) $\rightarrow$ RESOLVED.** Phân rã Executor di trú, Trusted function owner và Business Actor.
*   **`M0-GAP-004` (api_v1 unnecessary anon schema permission) $\rightarrow$ RESOLVED.** Thu hồi hoàn toàn quyền USAGE schema `api_v1` đối với vai trò `anon`.
*   **`M0-GAP-005` (Trusted function RLS execution authority for first slice) $\rightarrow$ RESOLVED.** Xác lập cấu hình `trusted_function_owner` đóng vai trò thực thi Bypass RLS, revalidate business authorization tin cậy trên context người dùng.

---

## 12. Điều Kiện Thông Qua Lát Cắt 1 (First Slice GO / NO-GO Checklist)

Cửa quyết định M0 đạt trạng thái **GO** khi và chỉ khi:
*   [x] 1. Quyết định tiền tệ `DEC-A-001` chốt và đóng (`numeric(15,2)`).
*   [x] 2. Quyết định sơ đồ chỉ mục `DEC-A-002` chốt và đóng (no partitioning).
*   [x] 3. Quyết định phân quyền `DEC-A-003` chốt và đóng (tách biệt Migration executor, trusted function owner role và business actor).
*   [x] 4. Quy trình xác thực đổi token Google Sign-in sang Supabase Session được chốt.
*   [x] 5. Schema `api_v1` được cấu hình phơi bày cho PostgREST API và thu hồi quyền `anon`.
*   [x] 6. Phân loại trường băm request_hash của `create_wedding` được chốt.
*   [x] 7. Khung monorepo và mô hình môi phát triển/kiểm thử pgTAP local được phê duyệt.

**KẾT LUẬN:** 🟢 **GO TO IMPLEMENTATION** (Đồng ý chuyển giao dự án sang thực thi mã nguồn di trú `BATCH-00` và code lát cắt 1).
