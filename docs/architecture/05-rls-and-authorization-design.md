# Đặc Tả Kiến Trúc: 05 — RLS & Authorization Design (Thiết Kế Phân Quyền RLS & Xác Thực)

*   **Trạng thái (Status):** APPROVED (Đã Phê duyệt)
*   **Người thực hiện:** Antigravity (AI Architect)
*   **Ngày cập nhật:** 20/08/2026

---

> [!IMPORTANT]
> **NON-EXECUTABLE AUTHORIZATION SPECIFICATION**
> Tài liệu này chứa đặc tả thiết kế phân quyền, ma trận chính sách RLS, và Postgres Grants. Đây KHÔNG phải là tệp lệnh SQL thực thi trực tiếp trên Supabase. Mọi câu lệnh SQL thực tế được hoãn lại cho phase triển khai DDL/Migration tiếp theo.

---

## 1. Nguyên Tắc Phân Quyền (Authorization Principles)

Hệ thống phân quyền của WeddingOS tuân thủ các nguyên tắc cốt lõi sau:
1.  **Least Privilege (Đặc quyền tối thiểu):** Giới hạn tối đa quyền truy cập. Những gì không được cho phép rõ ràng thì mặc định bị cấm. Vai trò `anon` (khách vãng lai không đăng nhập) không được cấp bất kỳ quyền GRANT trực tiếp nào trên các bảng cơ sở dữ liệu.
2.  **Tenant Isolation (Cô lập Đám cưới):** Người dùng thuộc Đám cưới A không thể thực hiện bất kỳ thao tác Đọc/Ghi nào đối với dữ liệu thuộc Đám cưới B, kể cả khi tài khoản của họ được phân quyền ở cả hai đám cưới (quy tắc cô lập dữ liệu quan hệ).
3.  **Hybrid Trust Model (Mô hình tin cậy hỗn hợp):** Tách biệt rõ ràng giữa các thao tác CRUD trực tiếp (Class A/B) thông qua Data API bảo vệ bằng RLS và các nghiệp vụ phức tạp đòi hỏi kiểm soát an toàn cao (Class C/D) bắt buộc chạy qua biên máy chủ tin cậy (Trusted Boundary).
4.  **Chốt chặn Database là tối cao:** Không dựa vào Flutter Client để bảo vệ dữ liệu nhạy cảm (như thông tin tài chính hay phân quyền thành viên). Mọi kiểm soát phải được thực thi ở mức cấu hình Postgres Grants, RLS Policies, Database Triggers và Ràng buộc toàn vẹn cơ sở dữ liệu.
5.  **Cô lập Client Guest Web:** Khách mời vãng lai không được cấp quyền truy cập PostgreSQL trực tiếp qua API. Mọi tương tác của khách trên Guest Web phải thông qua các Edge Function Class D công khai.

---

## 2. Định Danh & Quyền Thành Viên (Identity & Membership Authority)

*   **Định danh authoritative:** Định danh duy nhất đáng tin cậy của tài khoản người dùng đăng nhập là giá trị hàm `auth.uid()` cung cấp bởi Supabase Auth.
*   **Quyền thành viên authoritative:** Quyền hạn thực hiện thao tác trên đám cưới (`wedding_id`) được quyết định bởi bản ghi liên kết active trong bảng `wedding_members`:
    *   Thành viên phải có trạng thái hoạt động: `status = 'ACTIVE'`.
    *   Tài khoản bị thu hồi quyền (`status = 'REVOKED'`) sẽ mất toàn bộ quyền truy cập lập tức từ lần yêu cầu database tiếp theo.
*   *Cảnh báo an ninh:* Quyền hạn và vai trò không được lưu hoặc đọc từ JWT metadata tự do của client, tránh nguy cơ client tự thay đổi quyền hạn.

---

## 3. Ma Trận Vai Trò & Năng Lực (Role Capability Matrix)

Hệ thống hỗ trợ 2 vai trò tổ chức chính trong đám cưới (tuân thủ chính xác REQ-06):

| Thực thể / Tính năng | OWNER | COLLABORATOR | Ranh giới thực thi |
| :--- | :---: | :---: | :--- |
| **Wedding Foundation (SELECT)** | 🟢 Cho phép | 🟢 Cho phép | RLS SELECT |
| **Wedding Foundation (UPDATE)** | 🟢 Cho phép | 🟢 Cho phép (chỉ các trường cấu hình không nhạy cảm) | Column Grants + RLS |
| **Wedding Events (SELECT)** | 🟢 Cho phép | 🟢 Cho phép | RLS SELECT |
| **Wedding Events (UPDATE)** | 🟢 Cho phép | 🟢 Cho phép (chỉ tên, địa điểm, giờ; cấm dời ngày) | Column Grants + RLS |
| **Planning & Tasks (SELECT/CUD)** | 🟢 Cho phép | 🟢 Cho phép | RLS SELECT/INSERT/UPDATE/DELETE |
| **Guest Management (SELECT/CUD)** | 🟢 Cho phép | 🟢 Cho phép | RLS SELECT/INSERT/UPDATE/DELETE |
| **Invitation Management (SELECT/UPDATE)**| 🟢 Cho phép | 🟢 Cho phép | RLS SELECT/UPDATE |
| **RSVP & Event Responses (SELECT)** | 🟢 Cho phép | 🟢 Cho phép | RLS SELECT |
| **Finance (budget_items, installments)**| 🟢 Cho phép | 🔴 BỊ CẤM | RLS SELECT/CUD (OWNER-only) |
| **Finance (payments, refunds)** | 🟢 Cho phép (SELECT)| 🔴 BỊ CẤM | RLS SELECT (OWNER) + Giao dịch Class C |
| **Mời/Xóa thành viên ban tổ chức** | 🟢 Cho phép | 🔴 BỊ CẤM | Giao dịch Class C |
| **Lưu trữ / Xóa Đám cưới** | 🟢 Cho phép | 🔴 BỊ CẤM | Giao dịch Class C |

---

## 4. Ma Trận Tiếp Cận Bảng Dữ Liệu (Table Exposure Matrix)

Phân loại mức độ phơi bày của các bảng vật lý ra ngoài môi trường Internet qua Data API:

| Tên Bảng vật lý | Phơi bày Data API? | SELECT | INSERT | UPDATE | DELETE | Phân loại |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| `weddings` | YES | 🟢 | 🔴 | 🟢 | 🔴 | Class A/B |
| `wedding_members` | YES | 🟢 | 🔴 | 🔴 | 🔴 | Class A (Read-only) |
| `pending_collaborator_invitations`| NO | 🔴 | 🔴 | 🔴 | 🔴 | Class C only |
| `wedding_events` | YES | 🟢 | 🟢 | 🟢 | 🔴 | Class A/B (Delete qua Class C) |
| `tasks` | YES | 🟢 | 🟢 | 🟢 | 🟢 | Class A/B |
| `budget_items` | YES | 🟢 | 🟢 | 🟢 | 🟢 | Class A/B (OWNER-only) |
| `installments` | YES | 🟢 | 🟢 | 🟢 | 🟢 | Class A/B (OWNER-only) |
| `payments` | YES | 🟢 (OWNER) | 🔴 | 🔴 | 🔴 | Class A (Read-only) |
| `refunds` | YES | 🟢 (OWNER) | 🔴 | 🔴 | 🔴 | Class A (Read-only) |
| `primary_groups` | YES | 🟢 | 🟢 | 🟢 | 🔴 | Class A/B (Delete qua Class C) |
| `guests` | YES | 🟢 | 🟢 | 🟢 | 🟢 | Class A/B |
| `invitation_parties` | YES | 🟢 | 🟢 | 🟢 | 🔴 | Class A/B (Delete qua Class C) |
| `invitations` | YES | 🟢 | 🟢 | 🟢 | 🔴 | Class A/B |
| `invitation_event_targetings` | YES | 🟢 | 🟢 | 🔴 | 🟢 | Class A/B |
| `invitation_credentials` | NO | 🔴 | 🔴 | 🔴 | 🔴 | Class C/D only |
| `rsvps` | YES | 🟢 | 🔴 | 🔴 | 🔴 | Class A (Read-only) |
| `event_responses` | YES | 🟢 | 🔴 | 🔴 | 🔴 | Class A (Read-only) |

---

## 5. Ma Trận Phân Quyền PostgreSQL (Postgres Grants Matrix)

Ràng buộc an ninh ở tầng GRANT đối với hai vai trò `authenticated` (tài khoản đăng nhập) và `anon` (vãng lai):

| Tên Bảng vật lý | Quyền cấp cho vai trò `anon` | Quyền cấp cho vai trò `authenticated` (Table-level) | Quyền cấp cột giới hạn (Column-level GRANTS) |
| :--- | :--- | :--- | :--- |
| `weddings` | NONE | SELECT, UPDATE | Chặn UPDATE trên cột: `status` |
| `wedding_members` | NONE | SELECT | |
| `pending_collaborator_invitations`| NONE | NONE | |
| `wedding_events` | NONE | SELECT, INSERT, UPDATE | Chặn UPDATE trên các cột: `is_main_event`, `lifecycle_status` |
| `tasks` | NONE | SELECT, INSERT, UPDATE, DELETE | Chặn INSERT/UPDATE trên các cột: `task_source`, `is_user_modified`, `resolved_deadline_at` |
| `budget_items` | NONE | SELECT, INSERT, UPDATE, DELETE | |
| `installments` | NONE | SELECT, INSERT, UPDATE, DELETE | |
| `payments` | NONE | SELECT | Chặn INSERT, UPDATE, DELETE |
| `refunds` | NONE | SELECT | Chặn INSERT, UPDATE, DELETE |
| `primary_groups` | NONE | SELECT, INSERT, UPDATE | |
| `guests` | NONE | SELECT, INSERT, UPDATE, DELETE | Chặn INSERT/UPDATE trên các cột: `normalized_phone`, `normalized_email` |
| `invitation_parties` | NONE | SELECT, INSERT, UPDATE | |
| `invitations` | NONE | SELECT, INSERT, UPDATE | Chặn INSERT/UPDATE trên các cột: `marked_sent_at`, `first_viewed_at`, `last_viewed_at` |
| `invitation_event_targetings` | NONE | SELECT, INSERT, DELETE | |
| `invitation_credentials` | NONE | NONE | |
| `rsvps` | NONE | SELECT | Chặn INSERT, UPDATE, DELETE |
| `event_responses` | NONE | SELECT | Chặn INSERT, UPDATE, DELETE |

*Ý nghĩa kỹ thuật:* Việc cấu hình GRANT giới hạn ở mức cột buộc Flutter Client khi thực hiện cập nhật chỉ được truyền danh sách các cột được phép sửa đổi. Lệnh truyền cả dòng (`SELECT *` sau đó gửi đè) sẽ bị database chặn đứng ngay lập tức do vi phạm quyền ghi cột.

---

## 6. Đặc Tả Chính Sách RLS (SELECT / INSERT / UPDATE / DELETE Matrices)

### A. Chính sách SELECT
Mã giả điều kiện `USING` của chính sách SELECT cho vai trò `authenticated`:

| Tên Bảng | Tên Chính sách SELECT | Biểu thức điều kiện logic (USING) |
| :--- | :--- | :--- |
| `weddings` | `select_wedding_if_member` | `security.is_active_wedding_member(id)` |
| `wedding_members` | `select_members_if_same_wedding` | `security.is_active_wedding_member(wedding_id)` |
| `wedding_events` | `select_events_if_member` | `security.is_active_wedding_member(wedding_id)` |
| `tasks` | `select_tasks_if_member` | `security.is_active_wedding_member(wedding_id)` |
| `budget_items` | `select_budget_items_if_owner` | `security.is_wedding_owner(wedding_id)` |
| `installments` | `select_installments_if_owner` | `budget_item_id IN (SELECT id FROM budget_items WHERE security.is_wedding_owner(wedding_id))` |
| `payments` | `select_payments_if_owner` | `budget_item_id IN (SELECT id FROM budget_items WHERE security.is_wedding_owner(wedding_id))` |
| `refunds` | `select_refunds_if_owner` | `budget_item_id IN (SELECT id FROM budget_items WHERE security.is_wedding_owner(wedding_id))` |
| `primary_groups` | `select_groups_if_member` | `security.is_active_wedding_member(wedding_id)` |
| `guests` | `select_guests_if_member` | `security.is_active_wedding_member(wedding_id)` |
| `invitation_parties`| `select_parties_if_member` | `security.is_active_wedding_member(wedding_id)` |
| `invitations` | `select_invitations_if_member` | `security.is_active_wedding_member(wedding_id)` |
| `invitation_event_targetings` | `select_targeting_if_member` | `security.is_active_wedding_member(wedding_id)` |
| `rsvps` | `select_rsvps_if_member` | `invitation_id IN (SELECT id FROM invitations WHERE security.is_active_wedding_member(wedding_id))` |
| `event_responses` | `select_responses_if_member` | `rsvp_id IN (SELECT r.id FROM rsvps r JOIN invitations i ON r.invitation_id = i.id WHERE security.is_active_wedding_member(i.wedding_id))` |

### B. Chính sách INSERT
Mã giả điều kiện `WITH CHECK` của chính sách INSERT:

| Tên Bảng | Tên Chính sách INSERT | Biểu thức điều kiện logic (WITH CHECK) |
| :--- | :--- | :--- |
| `wedding_events` | `insert_event_if_member` | `security.can_mutate_wedding(wedding_id)` |
| `tasks` | `insert_task_if_member` | `security.can_mutate_wedding(wedding_id)` |
| `budget_items` | `insert_budget_if_owner` | `security.can_owner_mutate_wedding(wedding_id)` |
| `installments` | `insert_installment_if_owner` | `budget_item_id IN (SELECT id FROM budget_items WHERE security.can_owner_mutate_wedding(wedding_id))` |
| `primary_groups` | `insert_group_if_member` | `security.can_mutate_wedding(wedding_id)` |
| `guests` | `insert_guest_if_member` | `security.can_mutate_wedding(wedding_id)` |
| `invitation_parties`| `insert_party_if_member` | `security.can_mutate_wedding(wedding_id)` |
| `invitations` | `insert_invitations_if_member` | `security.can_mutate_wedding(wedding_id)` |
| `invitation_event_targetings` | `insert_targeting_if_member` | `security.can_mutate_wedding(wedding_id)` |

### C. Chính sách UPDATE
Mã giả điều kiện `USING` (lọc dòng hiện tại) và `WITH CHECK` (lọc dòng sửa đổi):

| Tên Bảng | Tên Chính sách UPDATE | Biểu thức điều kiện (USING / WITH CHECK) |
| :--- | :--- | :--- |
| `weddings` | `update_wedding_if_member` | `security.can_mutate_wedding(id)` |
| `wedding_events` | `update_event_if_member` | `security.can_mutate_wedding(wedding_id)` |
| `tasks` | `update_tasks_if_member` | `security.can_mutate_wedding(wedding_id)` |
| `budget_items` | `update_budget_if_owner` | `security.can_owner_mutate_wedding(wedding_id)` |
| `installments` | `update_installment_if_owner` | `budget_item_id IN (SELECT id FROM budget_items WHERE security.can_owner_mutate_wedding(wedding_id))` |
| `primary_groups` | `update_group_if_member` | `security.can_mutate_wedding(wedding_id)` |
| `guests` | `update_guest_if_member` | `security.can_mutate_wedding(wedding_id)` |
| `invitation_parties`| `update_party_if_member` | `security.can_mutate_wedding(wedding_id)` |
| `invitations` | `update_invitations_if_member`| `security.can_mutate_wedding(wedding_id)` |

### D. Chính sách DELETE
Mã giả điều kiện `USING` của chính sách DELETE:

| Tên Bảng | Tên Chính sách DELETE | Biểu thức điều kiện logic (USING) |
| :--- | :--- | :--- |
| `tasks` | `delete_tasks_if_member` | `security.can_mutate_wedding(wedding_id)` |
| `budget_items` | `delete_budget_if_owner` | `security.can_owner_mutate_wedding(wedding_id)` |
| `installments` | `delete_installment_if_owner` | `budget_item_id IN (SELECT id FROM budget_items WHERE security.can_owner_mutate_wedding(wedding_id))` |
| `guests` | `delete_guests_if_member` | `security.can_mutate_wedding(wedding_id)` |
| `invitation_event_targetings`| `delete_targeting_if_member` | `invitation_id IN (SELECT id FROM invitations WHERE security.can_mutate_wedding(wedding_id))` |

---

## 7. Thiết Kế Hàm Trợ Giúp Phân Quyền (Helper Function Security Design)

Để tối ưu hóa hiệu năng, giảm trùng lặp mã và triệt tiêu đệ quy RLS, hệ thống thiết kế các hàm nội bộ thuộc schema bảo mật riêng biệt:

### 1. Ràng buộc an ninh hàm Security Definer:
*   Các hàm này chạy với quyền đặc quyền của chủ sở hữu hàm (`SECURITY DEFINER`).
*   Bắt buộc cấu hình cứng search path rỗng để tránh các lỗi phân giải và nguy cơ tấn công SQL Injection thông qua path:
    `SET search_path = ''`
*   Mọi thực thể bảng và hàm gọi bên trong bắt buộc phải chỉ định rõ tên schema đầy đủ (ví dụ: `public.wedding_members`).
*   Thu hồi quyền thực thi mặc định từ vai trò `PUBLIC` và chỉ `GRANT EXECUTE` giới hạn cho vai trò `authenticated`.

### 2. Thiết kế hàm `security.is_active_wedding_member(wedding_id_param uuid)`
```sql
CREATE FUNCTION security.is_active_wedding_member(wedding_id_param uuid)
RETURNS boolean SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.wedding_members
    WHERE wedding_id = wedding_id_param
      AND user_id = auth.uid()
      AND status = 'ACTIVE'
  );
END;
$$ LANGUAGE plpgsql;
```

### 3. Thiết kế hàm `security.is_wedding_owner(wedding_id_param uuid)`
```sql
CREATE FUNCTION security.is_wedding_owner(wedding_id_param uuid)
RETURNS boolean SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.wedding_members
    WHERE wedding_id = wedding_id_param
      AND user_id = auth.uid()
      AND role = 'OWNER'
      AND status = 'ACTIVE'
  );
END;
$$ LANGUAGE plpgsql;
```

### 4. Thiết kế hàm `security.can_mutate_wedding(wedding_id_param uuid)`
```sql
CREATE FUNCTION security.can_mutate_wedding(wedding_id_param uuid)
RETURNS boolean SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.wedding_members m
    JOIN public.weddings w ON m.wedding_id = w.id
    WHERE m.wedding_id = wedding_id_param
      AND m.user_id = auth.uid()
      AND m.status = 'ACTIVE'
      AND w.status = 'ACTIVE' -- Chặn hoàn toàn mọi sửa đổi Class B khi Wedding đã bị ARCHIVED hoặc ở trạng thái DELETING
  );
END;
$$ LANGUAGE plpgsql;
```

### 5. Thiết kế hàm `security.can_owner_mutate_wedding(wedding_id_param uuid)`
```sql
CREATE FUNCTION security.can_owner_mutate_wedding(wedding_id_param uuid)
RETURNS boolean SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.wedding_members m
    JOIN public.weddings w ON m.wedding_id = w.id
    WHERE m.wedding_id = wedding_id_param
      AND m.user_id = auth.uid()
      AND m.role = 'OWNER'
      AND m.status = 'ACTIVE'
      AND w.status = 'ACTIVE' -- Chặn các sửa đổi đặc quyền thông thường khi Đám cưới không ACTIVE
  );
END;
$$ LANGUAGE plpgsql;

### 6. Thiết kế hàm kiểm soát quyền Xóa/Phục hồi (`security.can_owner_delete_wedding`)
```sql
CREATE FUNCTION security.can_owner_delete_wedding(wedding_id_param uuid)
RETURNS boolean SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.wedding_members m
    JOIN public.weddings w ON m.wedding_id = w.id
    WHERE m.wedding_id = wedding_id_param
      AND m.user_id = auth.uid()
      AND m.role = 'OWNER'
      AND m.status = 'ACTIVE'
      AND w.status IN ('ACTIVE', 'DELETING') -- Cho phép OWNER tiếp tục chạy phục hồi dọn dẹp kể cả khi đang DELETING
  );
END;
$$ LANGUAGE plpgsql;
```
```

---

## 8. Bảo Vệ Thuộc Tính Nhạy Cảm & Dữ Liệu Nguồn (Provenance & Normalization)

### A. Kiểm soát nguồn Task (`RLS-AUTH-GAP-003` - Đã giải quyết):
Để đảm bảo client di động không giả mạo nguồn Task hoặc reset cờ chỉnh sửa, database kết hợp Column Grants và Trigger cấp cơ sở dữ liệu:
*   Trường `task_source` và `is_user_modified` bị cấm ghi trực tiếp bởi client qua Column-level Grants.
*   Database thiết lập trigger **`before_insert_update_tasks_provenance`**:
    *   **INSERT:** Nếu ghi được kích hoạt bởi client thông thường, trigger tự động gán đè `task_source = 'USER'` và `is_user_modified = false`.
    *   **UPDATE:** Nếu client thông thường chỉnh sửa các trường nghiệp vụ (`name`, `deadline_intent`, `date_offset`), trigger tự động cập nhật `is_user_modified = true`. Chặn đứng mọi hành vi chỉnh sửa của client cố tình chuyển ngược trạng thái từ `true` về `false`.
    *   **Trusted System Path:** Đường dẫn thực thi hệ thống tin cậy (Trusted system execution path) có đặc quyền được cấp hẹp (narrowly scoped authority) để ghi trực tiếp các trường nguồn gốc bảo vệ (`SYSTEM_TEMPLATE` hoặc `RECOMMENDATION`). Nguyên tắc đặc quyền tối thiểu (Least privilege) vẫn bắt buộc áp dụng. Vai trò thực thi hoặc phân quyền database chi tiết được hoãn lại (Deferred) cho phase thiết kế migration/triển khai thực tế kế tiếp.

### B. Tự động hóa chuẩn hóa thông tin khách (Guest Normalization):
*   Quyền cập nhật trực tiếp `normalized_phone` và `normalized_email` của vai trò `authenticated` bị thu hồi qua Column-level Grants.
*   Trigger cơ sở dữ liệu tự động chuẩn hóa định dạng phone (chỉ giữ ký số) và email (chuyển thường) từ trường thô `phone` và `email` khi lưu.

### C. Đảm bảo mốc thời gian thiệp cưới (Invitation Tracking):
*   Các trường tracking `first_viewed_at` và `last_viewed_at` chỉ được cập nhật qua Edge Function Class D.
*   Cờ `marked_sent_at` được tự động sinh trên DB khi trạng thái thiệp chuyển sang `MARKED_AS_SENT` lần đầu tiên.

---

## 9. Thiết Kế Tra Cứu Danh Bạ Thành Viên (`RLS-AUTH/DATA-GAP-004` - Đã giải quyết)

*   **Bổ sung dữ liệu hiển thị (`ERRATA-PHY-006`):** Bổ sung trường `display_name` và `profile_email` trực tiếp vào bảng `wedding_members` làm snapshot lưu thông tin tại thời điểm chấp nhận mời.
*   **Quy tắc hiển thị (Member Directory Exposure):**
    *   Cột `profile_email` bị chặn SELECT đối với vai trò COLLABORATOR (chỉ dành cho OWNER khi quản lý thành viên).
    *   Các thông tin `id`, `wedding_id`, `display_name`, `role`, và `status` được hiển thị công khai cho mọi thành viên active dòng SELECT thông qua một Security View bảo mật:
        `CREATE VIEW public.member_directory WITH (security_invoker = true) AS SELECT id, wedding_id, display_name, role, status FROM public.wedding_members;`

---

## 10. Phân Quyền Cho Các Bảng Con Gián Tiếp (Indirect Table RLS)

Đối với các bảng con không mang trực tiếp trường `wedding_id`, điều kiện RLS được bắc cầu qua liên kết khóa ngoại:

*   **`installments`**:
    `budget_item_id IN (SELECT id FROM budget_items WHERE security.is_wedding_owner(budget_item_id))`
*   **`payments` / `refunds`**:
    `budget_item_id IN (SELECT id FROM budget_items WHERE security.is_wedding_owner(budget_item_id))`
*   **`invitation_credentials`**:
    `invitation_id IN (SELECT id FROM invitations WHERE security.is_active_wedding_member(invitation_id))`
*   **`rsvps`**:
    `invitation_id IN (SELECT id FROM invitations WHERE security.is_active_wedding_member(invitation_id))`
*   **`event_responses`**:
    `rsvp_id IN (SELECT r.id FROM rsvps r JOIN invitations i ON r.invitation_id = i.id WHERE security.is_active_wedding_member(i.wedding_id))`

---

## 11. Phân Quyền Cột Weddings (Weddings Column Exposure Audit)

Bảng `weddings` chứa nhiều trường cấu hình với mức độ nhạy cảm khác nhau, được phân lớp truy cập như sau:

| Tên Cột | OWNER Readable | COLLABORATOR Readable | OWNER Writable | COLLABORATOR Writable | Trusted-only Writable |
| :--- | :---: | :---: | :---: | :---: | :---: |
| `id`, `name` | 🟢 | 🟢 | 🟢 | 🔴 | 🔴 |
| `expected_year`, `expected_month` | 🟢 | 🟢 | 🟢 | 🔴 | 🔴 |
| `exact_date` | 🟢 | 🟢 | 🟢 | 🔴 | 🔴 |
| `target_budget` (Finance) | 🟢 | 🔴 | 🟢 | 🔴 | 🔴 |
| `cultural_context`, `timezone` | 🟢 | 🟢 | 🟢 | 🔴 | 🔴 |
| `rsvp_cutoff_date`, `cover_photo_key` | 🟢 | 🟢 | 🟢 | 🟢 | 🔴 |
| `public_contact_phone`, `public_contact_email` | 🟢 | 🟢 | 🟢 | 🟢 | 🔴 |
| `vietqr_bank_id`, `vietqr_account_no` | 🟢 | 🟢 | 🟢 | 🔴 | 🔴 |
| `vietqr_account_name`, `vietqr_photo_key` | 🟢 | 🟢 | 🟢 | 🔴 | 🔴 |
| `vietqr_enabled` | 🟢 | 🟢 | 🟢 | 🔴 | 🔴 |
| `status` (lifecycle/archive) | 🟢 | 🟢 | 🔴 | 🔴 | 🟢 |

---

## 12. Ràng Buộc Phân Phối File Ảnh Private (Storage Ownership Binding)

*   **Ràng buộc logic:** Mọi tệp tải lên Storage cưới phải bao gồm phân đoạn đường dẫn chứa mã đám cưới `wedding_id` (ví dụ: `{wedding_id}/media_key`).
*   **Kiểm tra an ninh:** Storage RLS phân giải mã `wedding_id` từ đường dẫn và gọi hàm đặc quyền `security.is_active_wedding_member(wedding_id)` để cấp quyền đọc/ghi.
*   **Archived Wedding:** Quyền tải lên tệp mới (write) bị chặn khi đám cưới đã archive; quyền đọc (read) được bảo lưu.
*   **Guest Access:** Không truy cập trực tiếp Storage. Khách đọc ảnh qua Signed URLs thời hạn ngắn do Edge Function sinh.

---

## 13. Ràng Buộc Thành Viên Hoạt Động (`ERRATA-PHY-006` - Đã giải quyết)

Database thực thi ràng buộc kiểm tra trạng thái thành viên khi phân công nhiệm vụ mới:
*   **Kịch bản áp dụng:** Khi thực hiện câu lệnh `INSERT` hoặc `UPDATE` làm thay đổi các trường tham chiếu `assignee_wedding_member_id` trên `tasks` hoặc `responsible_wedding_member_id` trên `budget_items`.
*   **Ràng buộc:** Nếu cột tham chiếu có giá trị khác null và bị thay đổi, hệ thống bắt buộc kiểm tra thành viên được gán phải có `status = 'ACTIVE'`.
*   **Bảo toàn lịch sử:** Nếu cột tham chiếu không thay đổi (giữ nguyên gán cho thành viên cũ đã bị `REVOKED`), các chỉnh sửa thuộc tính khác (ví dụ: đổi tên task) vẫn được chấp nhận bình thường.

---

## 14. Quy Tắc Chuyển Đổi Vòng Đời Thiệp Mời

*   **Chuyển đổi hợp lệ:** Thiệp cưới chỉ được phép chuyển trạng thái theo đúng chu trình tuyến tính: `DRAFT` $\rightarrow$ `READY` $\rightarrow$ `MARKED_AS_SENT`.
*   Cấm tuyệt đối các chuyển đổi ngược (ví dụ: `MARKED_AS_SENT` quay lại `DRAFT`).
*   Khi chuyển đổi sang `MARKED_AS_SENT` thành công lần đầu tiên, trigger database tự động ghi nhận thời gian máy chủ vào cột `marked_sent_at`. Client cấm gửi đè trường này.

---

## 15. Ma Trận Kịch Bản Thử Nghiệm Phân Quyền (Authorization Test Matrix)

Hệ thống thiết lập bộ test kiểm thử bảo mật tự động bao quát các kịch bản quan trọng:

### 1. Kịch bản Cô lập Đám cưới Đa Tenant (Multi-Wedding Integrity)
*   *Tình huống:* User X là OWNER của cả Đám cưới A và Đám cưới B.
*   *Hành động:* Gửi yêu cầu cập nhật liên kết Task cưới thuộc Đám cưới A tham chiếu tới một Sự kiện con thuộc Đám cưới B $\rightarrow$ Kết quả mong đợi: **Database báo lỗi vi phạm khóa ngoại phức hợp (FK violation)**.
*   *Tình huống tương tự:* Gộp khách đám cưới A sang PrimaryGroup đám cưới B, hoặc gán Payment khoản chi A sang Installment khoản chi B $\rightarrow$ Kết quả mong đợi: **Database từ chối**.

### 2. Kịch bản Bảo mật Tài chính (Finance Privacy)
*   *Hành động:* Tài khoản là COLLABORATOR Đám cưới A gọi lệnh SELECT trên bảng `budget_items`, `installments` hoặc view phái sinh tài chính $\rightarrow$ Kết quả: **Trả về 0 dòng**.

### 3. Kịch bản Khóa đám cưới đã lưu trữ (Archived Wedding)
*   *Hành động:* Đám cưới đã bị Archive $\rightarrow$ Ban tổ chức gửi lệnh UPDATE tên công việc qua Data API $\rightarrow$ Kết quả: **Bị chặn (WITH CHECK violation)**.

### 4. Kịch bản Thu hồi quyền Collaborator (Revocation)
*   *Hành vi:* Collaborator Y bị OWNER đổi trạng thái thành `REVOKED`. Collaborator Y ngay lập tức gửi yêu cầu SELECT Task $\rightarrow$ Kết quả: **Bị chặn tức thời**.
*   *Đối soát lịch sử:* OWNER SELECT Task do Y phụ trách trước đây $\rightarrow$ Kết quả: **Tên hiển thị tĩnh của Y vẫn đọc được bình thường**.

### 5. Kịch bản Xóa đợt thanh toán có liên kết (Payment / Installment Delete Integrity)
*   *Hành động:* Gọi lệnh DELETE trên một Installment đã phát sinh lịch sử liên kết với ít nhất một bản ghi Payment $\rightarrow$ Kết quả mong đợi: **Database từ chối xóa do vi phạm ràng buộc RESTRICT**.

---

## 16. Sổ Nhật Ký Gặp Phải & Khoảng Trống Phân Quyền (RLS-AUTH Gaps/Conflicts)

*   **`RLS-AUTH-GAP-001` (Finance direct mutation bypass) $\rightarrow$ RESOLVED.** Quyền INSERT/UPDATE/DELETE trực tiếp đối với vai trò `authenticated` trên bảng `payments`/`refunds` bị cấm hoàn toàn. Giao dịch dòng tiền bắt buộc chạy qua Class C.
*   **`RLS-AUTH-GAP-002` (Guest Web direct SQL exposure) $\rightarrow$ RESOLVED.** Khóa toàn bộ quyền đọc/ghi trực tiếp của vai trò `anon` trên bảng `rsvps` và `event_responses`.
*   **`RLS-AUTH-GAP-003` (Task provenance protected-column authority) $\rightarrow$ RESOLVED.** Kiểm soát nguồn Task gợi ý và cờ sửa đổi thông qua trigger nội bộ mức database (`before_insert_update_tasks_provenance`).
*   **`RLS-AUTH/DATA-GAP-004` (Member Directory Display Identity) $\rightarrow$ RESOLVED.** Bổ sung cột hiển thị `display_name` và `profile_email` vào bảng `wedding_members` làm snapshot thông tin phục vụ hiển thị nội bộ.
*   **`RLS-AUTH-CONFLICT-001` (Payment/Refund direct-read classification) $\rightarrow$ RESOLVED.** Cho phép OWNER SELECT trực tiếp các giao dịch tài chính thông qua RLS để hiển thị Dashboard di động, chặn quyền đối với Collaborator, chặn toàn bộ quyền CUD trực tiếp của tất cả các vai trò.
*   **`ERRATA-RLS-001` (Trusted Provenance Execution Privilege) $\rightarrow$ RESOLVED.** Loại bỏ thuật ngữ ràng buộc superuser/postgres owner cho quyền ghi provenance của Task; thay vào đó sử dụng định nghĩa đường dẫn thực thi hệ thống được phân quyền hẹp theo nguyên tắc Least privilege.
*   **`ERRATA-PHY-008` (Wedding DELETING Lifecycle) $\rightarrow$ RESOLVED.** Hàm trợ giúp và chính sách RLS chặn toàn bộ truy cập đột biến Class B/C thông thường khi status = DELETING, nhưng mở đường dẫn đặc quyền `can_owner_delete_wedding` để OWNER tiếp tục thực hiện recovery dọn dẹp Storage.
*   **`ERRATA-PHY-009` (Durable Trusted Operation Receipts) $\rightarrow$ RESOLVED.** Bảng biên nhận `private.trusted_operation_receipts` nằm ngoài schema public, không thể truy cập trực tiếp bởi API Class B của client, bảo vệ toàn diện chống trùng lặp.


