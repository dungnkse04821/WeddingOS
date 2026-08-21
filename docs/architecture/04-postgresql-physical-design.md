# Đặc Tả Kiến Trúc: 04 — PostgreSQL Physical Design (Thiết Kế Vật Lý PostgreSQL)

*   **Trạng thái (Status):** Approved (Đã Phê duyệt)
*   **Người thực hiện:** Antigravity (AI Architect)
*   **Ngày cập nhật:** 20/08/2026

---

> [!IMPORTANT]
> **NON-EXECUTABLE PHYSICAL SCHEMA SPECIFICATION**
> Tài liệu này là đặc tả thiết kế cơ sở dữ liệu vật lý mức logic-vật lý dưới dạng ngôn ngữ SQL minh họa. Đây KHÔNG phải là tệp migration SQL thực thi trực tiếp và không được phép chạy trực tiếp trên môi trường database.

---

## 1. Quy Chuẩn Đặt Tên Vật Lý (Naming Conventions)

Toàn bộ cấu trúc cơ sở dữ liệu vật lý tuân thủ quy chuẩn đặt tên chuẩn hóa của PostgreSQL:
*   **Kiểu chữ:** `snake_case` cho tất cả tên bảng, tên cột, chỉ mục, ràng buộc và hàm.
*   **Tên Bảng (Tables):** Số nhiều (ví dụ: `weddings`, `tasks`, `guests`).
*   **Khóa chính (PK):** Cột định danh mặc định tên là `id`.
*   **Khóa ngoại (FK):** `singular_table_name_id` (ví dụ: `wedding_id`, `guest_id`).
*   **Ràng buộc Duy nhất (Unique Constraints):** `uq_table_name_columns` (ví dụ: `uq_wedding_members_wedding_user`).
*   **Ràng buộc Kiểm tra (Check Constraints):** `chk_table_name_condition` (ví dụ: `chk_payments_amount_positive`).
*   **Chỉ mục (Indexes):** `idx_table_name_columns` (ví dụ: `idx_tasks_wedding_status`).
*   **Mốc thời gian (Timestamps):** Kiểu dữ liệu thời gian có múi giờ (`timestamptz`) làm chuẩn lưu trữ.

---

## 2. Chiến Lược Chọn Định Danh (Identifier Strategy)

WeddingOS sử dụng **`UUIDv4`** (kiểu `uuid` mặc định `gen_random_uuid()`) làm kiểu dữ liệu khóa chính thống nhất cho toàn bộ các thực thể nghiệp vụ chính.

### A. Lý do lựa chọn:
*   **Định danh phi tuần tự (Non-sequential identifiers):** Khóa chính dạng UUIDv4 ngẫu nhiên ngăn chặn việc dò quét dữ liệu trên Guest Web công khai.
*   **Tương thích PostgreSQL/Supabase:** Định dạng chuẩn của Supabase Auth và PostgreSQL.
*   **Sinh định danh độc lập:** Hỗ trợ client tự cấp phát ID khi thực thi các cấu trúc nháp cục bộ, loại bỏ phụ thuộc vào sequence tập trung của database.
*   *Lưu ý an ninh:* Tính bảo mật của phân quyền hoàn toàn dựa vào cơ chế RLS và các điểm kiểm duyệt nghiệp vụ tin cậy (trusted boundaries), không dựa vào sự khó đoán (opacity) của UUID.

### B. Bảng liên kết nhiều-nhiều (Association Tables):
*   Các bảng liên kết như `invitation_event_targetings` sử dụng trực tiếp **khóa chính hỗn hợp (composite PK)** thay vì surrogate UUID PK nhằm tối giản dung lượng lưu trữ.

---

## 3. Quản Lý Tài Khoản Người Dùng (Auth User Reference)

*   **Xác thực ngoài:** Bảng `auth.users` thuộc schema nội bộ của Supabase quản lý thông tin tài khoản.
*   **WeddingMember:** Tham chiếu tài khoản qua cột `user_id uuid REFERENCES auth.users (id) ON DELETE RESTRICT`. Cấm xóa tài khoản nếu còn liên kết thành viên active.
*   **Mời Collaborator:** Lời mời (`pending_collaborator_invitations`) lưu display email và email chuẩn hóa (`normalized_invited_email`) để đối soát. Khi chấp nhận, tư cách thành viên `wedding_members` được liên kết với ID tài khoản thực (`auth.users.id`). Không dùng email làm khóa phân quyền dài hạn.

---

## 4. Giải Quyết Câu Hỏi Mở `OPEN-DATA-001` (Finance Transaction Semantics)

Sự kiện nhập sai thông tin giao dịch tài chính được giải quyết bằng cơ chế **Kiểm soát Sửa đổi và Hủy bỏ (CONTROLLED EDIT + VOID)** thông qua Giao dịch Nghiệp vụ Tin cậy Class C:

### 1. Hiệu chỉnh Giao dịch ACTIVE
*   Ban tổ chức được phép sửa đổi các trường thông tin nghiệp vụ: `amount`, `payment_date`/`refund_date`, `payer_display_name`, `notes`, và liên kết đợt thanh toán `installment_id`.
*   Hệ thống không lưu lịch sử thay đổi phiên bản toàn bộ trường. Giữ nguyên `created_at` và tự động cập nhật `updated_at`.

### 2. Ràng buộc sở hữu BudgetItem
*   **Tuyệt đối cấm** thay đổi liên kết `budget_item_id` của một Payment/Refund sang khoản chi tiêu khác sau khi đã tạo để bảo vệ ranh giới Aggregate.
*   Nếu ghi nhận nhầm khoản chi: Ban tổ chức phải **HỦY (VOID)** giao dịch cũ và **TẠO MỚI** giao dịch dưới khoản chi đúng.

### 3. Vô hiệu hóa (Void)
*   Không xóa cứng giao dịch trong luồng nghiệp vụ thông thường. Giao dịch bị hủy chuyển trạng thái logic `status = 'VOIDED'`.
*   Lưu trữ vết hủy qua: `voided_at timestamptz` (thời điểm hủy), `voided_by_user_id uuid` (người hủy - đại diện cho tài khoản Auth thực hiện, không dùng trực tiếp làm dữ liệu phân quyền), và `void_reason text` (lý do hủy).
*   Giao dịch `VOIDED` bị loại trừ hoàn toàn khỏi các phép tính toán tài chính và không được phép khôi phục ngầm.

### 4. Giao dịch Hoàn tiền (Refund)
*   Refund biểu diễn dòng tiền mặt nhận lại thực tế (`Refund.amount > 0`). Không sử dụng Refund để sửa sai cho Payment nhập lỗi.

---

## 5. Đặc Tả Chi Tiết Schema Vật Lý Các Bảng (Non-Executable Spec)

#### Bảng 1: `weddings` (Danh sách Đám cưới)

```sql
CREATE TABLE weddings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name varchar(255) NOT NULL,
  target_budget numeric(15, 2),
  expected_year integer,
  expected_month integer,
  exact_date date,
  cultural_context varchar(50) NOT NULL DEFAULT 'TUY_CHON',
  rsvp_cutoff_date date,
  timezone varchar(50) NOT NULL DEFAULT 'Asia/Ho_Chi_Minh',
  cover_photo_key text,
  vietqr_bank_id varchar(50),
  vietqr_account_no varchar(100),
  vietqr_account_name varchar(255),
  vietqr_enabled boolean NOT NULL DEFAULT false,
  vietqr_photo_key text,
  public_contact_phone varchar(50),
  public_contact_email varchar(255),
  status varchar(50) NOT NULL DEFAULT 'ACTIVE',
  initial_plan_generated_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_weddings_status CHECK (status IN ('ACTIVE', 'ARCHIVED', 'DELETING')),
  CONSTRAINT chk_weddings_budget_pos CHECK (target_budget > 0),
  CONSTRAINT chk_weddings_expected_month CHECK (expected_month BETWEEN 1 AND 12),
  CONSTRAINT chk_wedding_date_precision CHECK (
    (exact_date IS NOT NULL AND expected_year IS NULL AND expected_month IS NULL) OR 
    (exact_date IS NULL AND expected_year IS NOT NULL AND expected_month IS NOT NULL)
  )
);
```

#### Bảng 2: `wedding_members` (Thành viên đám cưới)

```sql
CREATE TABLE wedding_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id uuid NOT NULL REFERENCES weddings (id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
  display_name varchar(255) NOT NULL,
  profile_email varchar(255) NOT NULL,
  role varchar(50) NOT NULL,
  status varchar(50) NOT NULL DEFAULT 'ACTIVE',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_members_role_enum CHECK (role IN ('OWNER', 'COLLABORATOR')),
  CONSTRAINT chk_members_status_enum CHECK (status IN ('ACTIVE', 'REVOKED')),
  CONSTRAINT uq_wedding_member UNIQUE (wedding_id, user_id),
  -- Dùng ràng buộc duy nhất phức hợp để hỗ trợ khóa ngoại cùng Wedding ở Task và BudgetItem
  CONSTRAINT uq_member_wedding_key UNIQUE (wedding_id, id)
);
```

#### Bảng 3: `pending_collaborator_invitations` (Lời mời Collaborator đang chờ)

```sql
CREATE TABLE pending_collaborator_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id uuid NOT NULL REFERENCES weddings (id) ON DELETE CASCADE,
  invited_email varchar(255) NOT NULL,
  normalized_invited_email varchar(255) NOT NULL,
  role varchar(50) NOT NULL DEFAULT 'COLLABORATOR',
  status varchar(50) NOT NULL DEFAULT 'PENDING',
  created_at timestamptz NOT NULL DEFAULT now(),
  accepted_at timestamptz,
  accepted_user_id uuid REFERENCES auth.users (id) ON DELETE SET NULL,
  CONSTRAINT chk_invitations_status_enum CHECK (status IN ('PENDING', 'ACCEPTED', 'REVOKED'))
);

CREATE UNIQUE INDEX uq_pending_collaborator ON pending_collaborator_invitations (wedding_id, normalized_invited_email) WHERE (status = 'PENDING');
```

#### Bảng 4: `wedding_events` (Sự kiện cưới con)

```sql
CREATE TABLE wedding_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id uuid NOT NULL REFERENCES weddings (id) ON DELETE CASCADE,
  name varchar(255) NOT NULL,
  expected_year integer,
  expected_month integer,
  exact_date date,
  start_time time,
  location text,
  map_link text,
  is_main_event boolean NOT NULL DEFAULT false,
  lifecycle_status varchar(50) NOT NULL DEFAULT 'ACTIVE',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_events_expected_month CHECK (expected_month BETWEEN 1 AND 12),
  CONSTRAINT chk_event_date_precision CHECK (
    (exact_date IS NOT NULL AND expected_year IS NULL AND expected_month IS NULL) OR 
    (exact_date IS NULL AND expected_year IS NOT NULL AND expected_month IS NOT NULL)
  ),
  CONSTRAINT chk_events_lifecycle CHECK (lifecycle_status IN ('ACTIVE', 'REMOVED')),
  -- Ràng buộc duy nhất phức hợp để hỗ trợ tham chiếu khóa ngoại cùng Đám cưới
  CONSTRAINT uq_events_wedding_key UNIQUE (wedding_id, id)
);
```

#### Bảng 5: `tasks` (Đầu việc lập kế hoạch)

```sql
CREATE TABLE tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id uuid NOT NULL REFERENCES weddings (id) ON DELETE CASCADE,
  wedding_event_id uuid,
  assignee_wedding_member_id uuid,
  name varchar(255) NOT NULL,
  status varchar(50) NOT NULL DEFAULT 'TODO',
  deadline_intent varchar(50) NOT NULL,
  date_offset integer,
  custom_override_date date,
  completed_at timestamptz,
  resolved_deadline_at date,
  task_source varchar(50) NOT NULL DEFAULT 'SYSTEM_TEMPLATE',
  is_user_modified boolean NOT NULL DEFAULT false,
  side varchar(50) NOT NULL DEFAULT 'COMMON',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_tasks_status_enum CHECK (status IN ('TODO', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
  CONSTRAINT chk_tasks_source_enum CHECK (task_source IN ('SYSTEM_TEMPLATE', 'RECOMMENDATION', 'USER')),
  CONSTRAINT chk_tasks_side CHECK (side IN ('COMMON', 'BRIDE_SIDE', 'GROOM_SIDE')),
  CONSTRAINT chk_task_deadline_intent CHECK (
    (deadline_intent = 'SYSTEM_RELATIVE' AND wedding_event_id IS NOT NULL AND date_offset IS NOT NULL AND custom_override_date IS NULL) OR
    (deadline_intent = 'USER_RELATIVE' AND wedding_event_id IS NOT NULL AND date_offset IS NOT NULL AND custom_override_date IS NULL) OR
    (deadline_intent = 'USER_ABSOLUTE' AND custom_override_date IS NOT NULL AND date_offset IS NULL AND wedding_event_id IS NULL) OR
    (deadline_intent = 'NO_DEADLINE' AND date_offset IS NULL AND custom_override_date IS NULL)
  ),
  -- Ràng buộc khóa ngoại ghép đảm bảo Assignee thuộc cùng một Đám cưới với Task
  CONSTRAINT fk_tasks_assignee_wedding FOREIGN KEY (wedding_id, assignee_wedding_member_id) 
    REFERENCES wedding_members (wedding_id, id) ON DELETE SET NULL (assignee_wedding_member_id),
  -- Ràng buộc khóa ngoại ghép đảm bảo Event thuộc cùng một Đám cưới với Task
  CONSTRAINT fk_tasks_event_wedding FOREIGN KEY (wedding_id, wedding_event_id) 
    REFERENCES wedding_events (wedding_id, id) ON DELETE RESTRICT
);
```

#### Bảng 6: `budget_items` (Danh mục khoản chi tiêu)

```sql
CREATE TABLE budget_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id uuid NOT NULL REFERENCES weddings (id) ON DELETE CASCADE,
  wedding_event_id uuid,
  responsible_wedding_member_id uuid,
  name varchar(255) NOT NULL,
  estimated_cost numeric(15, 2),
  confirmed_cost numeric(15, 2),
  side varchar(50) NOT NULL DEFAULT 'COMMON',
  status varchar(50) NOT NULL DEFAULT 'ACTIVE',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_budget_items_estimated CHECK (estimated_cost >= 0),
  CONSTRAINT chk_budget_items_confirmed CHECK (confirmed_cost >= 0),
  CONSTRAINT chk_budget_items_side CHECK (side IN ('COMMON', 'BRIDE_SIDE', 'GROOM_SIDE')),
  CONSTRAINT chk_budget_items_status CHECK (status IN ('ACTIVE', 'CANCELLED', 'ARCHIVED')),
  -- Ràng buộc khóa ngoại ghép đảm bảo Responsible thuộc cùng một Đám cưới với BudgetItem
  CONSTRAINT fk_budget_items_responsible_wedding FOREIGN KEY (wedding_id, responsible_wedding_member_id) 
    REFERENCES wedding_members (wedding_id, id) ON DELETE SET NULL (responsible_wedding_member_id),
  -- Ràng buộc khóa ngoại ghép đảm bảo Event thuộc cùng một Đám cưới với BudgetItem
  CONSTRAINT fk_budget_items_event_wedding FOREIGN KEY (wedding_id, wedding_event_id) 
    REFERENCES wedding_events (wedding_id, id) ON DELETE RESTRICT
);
```

#### Bảng 7: `installments` (Lịch thanh toán đợt)

```sql
CREATE TABLE installments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  budget_item_id uuid NOT NULL REFERENCES budget_items (id) ON DELETE CASCADE,
  amount numeric(15, 2) NOT NULL,
  due_date date NOT NULL,
  status varchar(50) NOT NULL DEFAULT 'PENDING',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_installments_amount CHECK (amount > 0),
  CONSTRAINT chk_installments_status CHECK (status IN ('PENDING', 'PAID')),
  -- Ràng buộc duy nhất phức hợp để hỗ trợ khóa ngoại cùng BudgetItem ở Payment
  CONSTRAINT uq_installments_item_key UNIQUE (budget_item_id, id)
);
```

#### Bảng 8: `payments` (Giao dịch chi ra thực tế)

```sql
CREATE TABLE payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  budget_item_id uuid NOT NULL REFERENCES budget_items (id) ON DELETE RESTRICT,
  installment_id uuid,
  amount numeric(15, 2) NOT NULL,
  payment_date date NOT NULL,
  payer_display_name varchar(255) NOT NULL,
  payer_wedding_member_id uuid REFERENCES wedding_members (id) ON DELETE SET NULL,
  status varchar(50) NOT NULL DEFAULT 'ACTIVE',
  notes text,
  voided_at timestamptz,
  voided_by_user_id uuid REFERENCES auth.users (id) ON DELETE SET NULL,
  void_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_payments_amount CHECK (amount > 0),
  CONSTRAINT chk_payments_status CHECK (status IN ('ACTIVE', 'VOIDED')),
  -- Ràng buộc khóa ngoại ghép đảm bảo Installment thuộc cùng một BudgetItem với Payment
  CONSTRAINT fk_payments_installment_item FOREIGN KEY (budget_item_id, installment_id) 
    REFERENCES installments (budget_item_id, id) ON DELETE RESTRICT
);
```

#### Bảng 9: `refunds` (Giao dịch hoàn tiền nhận về)

```sql
CREATE TABLE refunds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  budget_item_id uuid NOT NULL REFERENCES budget_items (id) ON DELETE RESTRICT,
  amount numeric(15, 2) NOT NULL,
  refund_date date NOT NULL,
  receiver varchar(100) NOT NULL,
  status varchar(50) NOT NULL DEFAULT 'ACTIVE',
  notes text,
  voided_at timestamptz,
  voided_by_user_id uuid REFERENCES auth.users (id) ON DELETE SET NULL,
  void_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_refunds_amount CHECK (amount > 0),
  CONSTRAINT chk_refunds_status CHECK (status IN ('ACTIVE', 'VOIDED'))
);
```

#### Bảng 10: `primary_groups` (Nhóm mối quan hệ)

```sql
CREATE TABLE primary_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id uuid NOT NULL REFERENCES weddings (id) ON DELETE CASCADE,
  name varchar(100) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  -- Ràng buộc duy nhất phức hợp để hỗ trợ tham chiếu khóa ngoại cùng Đám cưới
  CONSTRAINT uq_primary_groups_wedding_key UNIQUE (wedding_id, id)
);
```

#### Bảng 11: `invitation_parties` (Nhóm mời / Hộ gia đình)

```sql
CREATE TABLE invitation_parties (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id uuid NOT NULL REFERENCES weddings (id) ON DELETE CASCADE,
  display_name varchar(255) NOT NULL,
  invited_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_parties_invited_count CHECK (invited_count >= 0),
  -- Ràng buộc duy nhất phức hợp để hỗ trợ tham chiếu khóa ngoại cùng Đám cưới
  CONSTRAINT uq_parties_wedding_key UNIQUE (wedding_id, id)
);
```

#### Bảng 12: `guests` (Hồ sơ khách lẻ)

```sql
CREATE TABLE guests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id uuid NOT NULL REFERENCES weddings (id) ON DELETE CASCADE,
  invitation_party_id uuid,
  primary_group_id uuid,
  name varchar(255) NOT NULL,
  phone varchar(50),
  normalized_phone varchar(50),
  email varchar(255),
  normalized_email varchar(255),
  side varchar(50) NOT NULL DEFAULT 'COMMON',
  guest_source varchar(50) NOT NULL DEFAULT 'OTHER',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_guests_side CHECK (side IN ('COMMON', 'BRIDE_SIDE', 'GROOM_SIDE')),
  CONSTRAINT chk_guests_source CHECK (guest_source IN ('BRIDE', 'GROOM', 'BRIDE_PARENTS', 'GROOM_PARENTS', 'OTHER')),
  -- Ràng buộc khóa ngoại ghép đảm bảo Party thuộc cùng một Đám cưới với Guest
  CONSTRAINT fk_guests_party_wedding FOREIGN KEY (wedding_id, invitation_party_id) 
    REFERENCES invitation_parties (wedding_id, id) ON DELETE RESTRICT,
  -- Ràng buộc khóa ngoại ghép đảm bảo Group thuộc cùng một Đám cưới với Guest
  CONSTRAINT fk_guests_group_wedding FOREIGN KEY (wedding_id, primary_group_id) 
    REFERENCES primary_groups (wedding_id, id) ON DELETE RESTRICT
);
```

#### Bảng 13: `invitations` (Quản lý thiệp mời trực tuyến)

```sql
CREATE TABLE invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id uuid NOT NULL REFERENCES weddings (id) ON DELETE CASCADE,
  invitation_party_id uuid NOT NULL,
  status varchar(50) NOT NULL DEFAULT 'DRAFT',
  marked_sent_at timestamptz,
  first_viewed_at timestamptz,
  last_viewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_invitations_status CHECK (status IN ('DRAFT', 'READY', 'MARKED_AS_SENT')),
  -- Ràng buộc khóa ngoại ghép đảm bảo Party thuộc cùng một Đám cưới với Invitation
  CONSTRAINT fk_invitations_party_wedding FOREIGN KEY (wedding_id, invitation_party_id) 
    REFERENCES invitation_parties (wedding_id, id) ON DELETE RESTRICT,
  -- Ràng buộc duy nhất phức hợp để hỗ trợ tham chiếu khóa ngoại cùng Đám cưới
  CONSTRAINT uq_invitations_wedding_key UNIQUE (wedding_id, id)
);

CREATE UNIQUE INDEX uq_invitation_party ON invitations (invitation_party_id);
```

#### Bảng 14: `invitation_event_targetings` (Nhắm mục tiêu sự kiện của thiệp)

```sql
CREATE TABLE invitation_event_targetings (
  wedding_id uuid NOT NULL,
  invitation_id uuid NOT NULL,
  wedding_event_id uuid NOT NULL,
  CONSTRAINT pk_invitation_event_targeting PRIMARY KEY (invitation_id, wedding_event_id),
  -- Đảm bảo cả thiệp mời và sự kiện con đều thuộc cùng một Đám cưới của liên kết targeting
  CONSTRAINT fk_targeting_invitation_wedding FOREIGN KEY (wedding_id, invitation_id) 
    REFERENCES invitations (wedding_id, id) ON DELETE CASCADE,
  CONSTRAINT fk_targeting_event_wedding FOREIGN KEY (wedding_id, wedding_event_id) 
    REFERENCES wedding_events (wedding_id, id) ON DELETE CASCADE
);
```

#### Bảng 15: `invitation_credentials` (Quản lý mã truy cập thiệp bảo mật)

```sql
CREATE TABLE invitation_credentials (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invitation_id uuid NOT NULL REFERENCES invitations (id) ON DELETE CASCADE,
  token_hash bytea NOT NULL UNIQUE,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz,
  CONSTRAINT chk_credential_hash_length CHECK (octet_length(token_hash) = 32),
  CONSTRAINT chk_credential_revocation CHECK (
    (is_active = true AND revoked_at IS NULL) OR 
    (is_active = false AND revoked_at IS NOT NULL)
  )
);

CREATE UNIQUE INDEX uq_active_credential ON invitation_credentials (invitation_id) WHERE (is_active = true);
```

#### Bảng 16: `rsvps` (Phản hồi tham dự tổng hợp)

```sql
CREATE TABLE rsvps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invitation_id uuid NOT NULL REFERENCES invitations (id) ON DELETE CASCADE,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  notes text,
  companion_names text[],
  dietary_info text,
  guest_message text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX uq_invitation_rsvp ON rsvps (invitation_id);
```

#### Bảng 17: `event_responses` (Phản hồi chi tiết theo sự kiện)

```sql
CREATE TABLE event_responses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rsvp_id uuid NOT NULL REFERENCES rsvps (id) ON DELETE CASCADE,
  wedding_event_id uuid NOT NULL REFERENCES wedding_events (id) ON DELETE RESTRICT,
  is_attending boolean NOT NULL,
  attending_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_responses_count_pos CHECK (attending_count >= 0),
  CONSTRAINT chk_attending_count_rule CHECK (
    (is_attending = true AND attending_count >= 1) OR 
    (is_attending = false AND attending_count = 0)
  )
);

CREATE UNIQUE INDEX uq_rsvp_event_response ON event_responses (rsvp_id, wedding_event_id);
```

#### Bảng 18 (Bảng kỹ thuật nội bộ): `private.trusted_operation_receipts` (Biên nhận nghiệp vụ tin cậy)

```sql
CREATE TABLE private.trusted_operation_receipts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  operation_type varchar(100) NOT NULL,
  actor_user_id uuid NOT NULL,
  request_id uuid NOT NULL,
  wedding_id uuid REFERENCES public.weddings (id) ON DELETE CASCADE,
  request_hash varchar(64) NOT NULL,
  result_resource_id uuid,
  result_summary jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_operation_receipt UNIQUE (operation_type, actor_user_id, request_id)
);
```

---

## 6. Quyền Ghi Của Nguồn Công Việc (Task Provenance Write Authority)

Thiết kế an ninh quy định rõ quyền hạn thiết lập nguồn gốc công việc để tránh gian lận dữ liệu từ Flutter Client:
1.  **Direct Class B Create:** Client có thể gọi trực tiếp API để tạo Task mới, nhưng biên máy chủ sẽ cưỡng chế thiết lập `task_source = 'USER'` và `is_user_modified = false`, client không được phép tự khai báo `SYSTEM_TEMPLATE` hoặc `RECOMMENDATION`.
2.  **Direct Class B Edit:** Khi client chỉnh sửa một công việc có nguồn gốc `SYSTEM_TEMPLATE` hoặc `RECOMMENDATION`, biên máy chủ tự động gán `is_user_modified = true`. Client cấm tuyệt đối việc tự đặt lại cờ này về `false`.
3.  *Thực thi:* Luật phân quyền ghi này sẽ được đặc tả cụ thể tại phase RLS và Trusted Operation kế tiếp.

---

## 7. Ảnh Hưởng Khi Thu Hồi Thành Viên (Membership Revocation Reference Semantics)

Khi trạng thái của một thành viên ban tổ chức `WeddingMember` chuyển sang `REVOKED`:
*   **Không tự động xóa sạch** hay đặt `NULL` các liên kết cũ trong quá khứ để tránh phá hỏng dữ liệu. Lịch sử phân vai trò công việc (`assignee_wedding_member_id`), quản lý khoản chi (`responsible_wedding_member_id`) và lịch sử trả tiền (`payer_wedding_member_id`) được **giữ nguyên vẹn**.
*   **Quy tắc phân công mới:** API và RLS chỉ cho phép lựa chọn và phân công cho các thành viên có `status = 'ACTIVE'`.
*   **Needs Review Warning:** Nếu một công việc chưa hoàn thành (`TODO` hoặc `IN_PROGRESS`) hoặc một danh mục khoản chi hoạt động liên kết với một thành viên đã bị `REVOKED`, hệ thống sẽ tự động hiển thị trong Attention Center để ban tổ chức tự chỉnh sửa thủ công (không tự ý gán lại tự động).

---

## 8. Ràng Buộc Phân Quyền RLS & wedding_id (Tenant Ownership Matrix)

| Tên Bảng (Physical Table) | Có cột `wedding_id` trực tiếp? | Đường dẫn sở hữu RLS (Tenant Path) | Lý do Kiến trúc lựa chọn |
| :--- | :---: | :--- | :--- |
| `weddings` | YES | `id` | Thực thể gốc sở hữu. |
| `wedding_members` | YES | `wedding_id` | RLS trực tiếp bảo vệ thành viên. |
| `pending_collaborator_invitations`| YES | `wedding_id` | RLS trực tiếp bảo vệ danh sách mời. |
| `wedding_events` | YES | `wedding_id` | RLS trực tiếp bảo vệ sự kiện con. |
| `tasks` | YES | `wedding_id` | RLS trực tiếp tải danh sách task. |
| `budget_items` | YES | `wedding_id` | RLS trực tiếp (Chỉ gán quyền cho OWNER). |
| `installments` | NO | Bắc cầu qua `budget_items.wedding_id` | RLS qua JOIN. |
| `payments` | NO | Bắc cầu qua `budget_items.wedding_id` | RLS qua JOIN (Đảm bảo an toàn dòng tiền). |
| `refunds` | NO | Bắc cầu qua `budget_items.wedding_id` | RLS qua JOIN (Đảm bảo an toàn dòng tiền). |
| `primary_groups` | YES | `wedding_id` | RLS trực tiếp bảo vệ nhóm quan hệ. |
| `guests` | YES | `wedding_id` | RLS trực tiếp tải danh bạ. |
| `invitation_parties` | YES | `wedding_id` | RLS trực tiếp bảo vệ nhóm thiệp. |
| `invitations` | YES | `wedding_id` | RLS trực tiếp bảo vệ thiệp. |
| `invitation_event_targetings` | NO | Bắc cầu qua `invitations.wedding_id` | RLS qua JOIN. |
| `invitation_credentials` | NO | Bắc cầu qua `invitations.wedding_id` | RLS qua JOIN. |
| `rsvps` | NO | Bắc cầu qua `invitations.wedding_id` | RLS qua JOIN (OWNER). Bypass ghi (Guest). |
| `event_responses` | NO | Bắc cầu qua `rsvps` $\rightarrow$ `invitations` | RLS qua JOIN (OWNER). Bypass ghi (Guest). |

---

## 9. Quy Tắc Xóa Khóa Ngoại (Foreign Key Delete Matrix)

| Tên Khóa ngoại (FK) | Bảng con (Child) | Bảng cha (Parent) | Hành vi (ON DELETE) | Ý nghĩa nghiệp vụ |
| :--- | :--- | :--- | :--- | :--- |
| `fk_members_wedding` | `wedding_members` | `weddings` | **CASCADE** | Xóa đám cưới xóa toàn bộ thành viên. |
| `fk_members_user` | `wedding_members` | `auth.users` | **RESTRICT** | Cấm xóa tài khoản Auth nếu còn thành viên active. |
| `fk_invites_wedding` | `pending_collaborator_invitations` | `weddings` | **CASCADE** | Xóa đám cưới xóa toàn bộ lời mời. |
| `fk_events_wedding` | `wedding_events` | `weddings` | **CASCADE** | Xóa đám cưới xóa toàn bộ sự kiện con. |
| `fk_tasks_wedding` | `tasks` | `weddings` | **CASCADE** | Xóa đám cưới xóa toàn bộ công việc. |
| `fk_tasks_event` | `tasks` | `wedding_events`| **RESTRICT** | Cấm xóa cứng sự kiện nếu còn task liên kết. |
| `fk_budget_items_wedding`| `budget_items` | `weddings` | **CASCADE** | Xóa đám cưới xóa toàn bộ khoản chi. |
| `fk_budget_items_event` | `budget_items` | `wedding_events`| **RESTRICT** | Cấm xóa cứng sự kiện nếu còn khoản chi liên kết. |
| `fk_installments_item` | `installments` | `budget_items` | **CASCADE** | Xóa khoản chi xóa toàn bộ đợt thanh toán. |
| `fk_payments_item` | `payments` | `budget_items` | **RESTRICT** | Cấm xóa khoản chi nếu đã phát sinh giao dịch chi ra. |
| `fk_payments_member` | `payments` | `wedding_members`| **SET NULL** | Người trả tiền là thành viên bị xóa thì giữ lại giao dịch. |
| `fk_refunds_item` | `refunds` | `budget_items` | **RESTRICT** | Cấm xóa khoản chi nếu đã phát sinh giao dịch hoàn tiền. |
| `fk_guests_party` | `guests` | `invitation_parties`| **RESTRICT** | Chặn tự động gỡ khách khỏi thiệp khi xóa Party. Luồng gỡ/move phải kiểm duyệt. |
| `fk_guests_group` | `guests` | `primary_groups` | **RESTRICT** | Chặn xóa nhóm làm mất liên kết khách. |
| `fk_invitations_party` | `invitations` | `invitation_parties`| **RESTRICT** | **Tuyệt đối cấm** xóa Party nếu đã có thiệp mời phát sinh (bảo toàn RSVP). |
| `fk_responses_rsvp` | `event_responses` | `rsvps` | **CASCADE** | Xóa RSVP xóa toàn bộ phản hồi sự kiện con. |
| `fk_responses_event` | `event_responses` | `wedding_events`| **RESTRICT** | Cấm xóa cứng sự kiện nếu còn câu trả lời của khách. |

---

## 10. Ma Trận Giá Trị Rỗng (Nullability Matrix)

| Tên Bảng | Tên Cột | Nullable? | Ý nghĩa nghiệp vụ |
| :--- | :--- | :---: | :--- |
| `weddings` | `exact_date` | YES | Có thể chưa chốt ngày (Expected Month mode). |
| `weddings` | `expected_year` | YES | Có thể đã chốt ngày (Exact mode). |
| `weddings` | `expected_month`| YES | Có thể đã chốt ngày (Exact mode). |
| `weddings` | `target_budget` | YES | Hạn mức ngân sách là tùy chọn. |
| `wedding_events` | `exact_date` | YES | Có thể chưa chốt ngày (Expected Month mode). |
| `tasks` | `assignee_wedding_member_id`| YES | Công việc có thể chưa được phân công. |
| `tasks` | `completed_at` | YES | Chỉ ghi nhận khi trạng thái là `COMPLETED`. |
| `tasks` | `resolved_deadline_at`| YES | Chỉ ghi nhận khi trạng thái là `COMPLETED`. |
| `budget_items` | `responsible_wedding_member_id`| YES | Khoản chi tiêu có thể chưa được gán người quản lý. |
| `budget_items` | `estimated_cost`| YES | Dự toán có thể chưa nhập. |
| `budget_items` | `confirmed_cost`| YES | Chi phí thực tế chỉ có sau khi chốt hợp đồng. |
| `payments` | `installment_id`| YES | Giao dịch chi tiêu không theo kế hoạch đợt cố định. |
| `payments` | `voided_at` | YES | Chỉ ghi nhận đối với giao dịch trạng thái `VOIDED`. |
| `refunds` | `voided_at` | YES | Chỉ ghi nhận đối với giao dịch trạng thái `VOIDED`. |
| `guests` | `invitation_party_id`| YES | Khách chưa phân nhóm thiệp mời. |
| `guests` | `primary_group_id`| YES | Khách chưa phân nhóm quan hệ. |

---

## 11. Danh Sách Ràng Buộc Kiểm Tra (CHECK Constraint Matrix)

| Tên Bảng | Tên Ràng buộc | Biểu thức điều kiện kiểm tra (CHECK expression) | Ý nghĩa |
| :--- | :--- | :--- | :--- |
| `weddings` | `chk_weddings_status` | `status IN ('ACTIVE', 'ARCHIVED', 'DELETING')` | Giới hạn trạng thái đám cưới. |
| `weddings` | `chk_weddings_budget_pos` | `target_budget > 0` | Ngân sách phải dương. |
| `weddings` | `chk_weddings_expected_month` | `expected_month BETWEEN 1 AND 12` | Tháng dự kiến từ 1..12. |
| `weddings` | `chk_wedding_date_precision` | Trượt cấu hình exact/expected. | Ngăn mâu thuẫn mốc ngày cưới. |
| `wedding_members` | `chk_members_role_enum` | `role IN ('OWNER', 'COLLABORATOR')` | Giới hạn vai trò. |
| `wedding_events` | `chk_events_expected_month` | `expected_month BETWEEN 1 AND 12` | Tháng dự kiến từ 1..12. |
| `wedding_events` | `chk_event_date_precision` | Trượt cấu hình exact/expected. | Ngăn mâu thuẫn mốc ngày lễ. |
| `tasks` | `chk_tasks_status_enum` | `status IN ('TODO', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')` | Giới hạn trạng thái đầu việc. |
| `tasks` | `chk_tasks_side` | `side IN ('COMMON', 'BRIDE_SIDE', 'GROOM_SIDE')` | Giới hạn Side. |
| `tasks` | `chk_task_deadline_intent` | Đảm bảo các trường đi kèm đúng ý định hạn chót. | Chống hỗn hợp dữ liệu rác. |
| `budget_items` | `chk_budget_items_estimated` | `estimated_cost >= 0` | Chi phí dự toán không âm. |
| `budget_items` | `chk_budget_items_confirmed` | `confirmed_cost >= 0` | Chi phí thực tế không âm. |
| `installments` | `chk_installments_amount` | `amount > 0` | Số tiền đợt trả phải dương. |
| `payments` | `chk_payments_amount` | `amount > 0` | Số tiền giao dịch chi phải dương. |
| `refunds` | `chk_refunds_amount` | `amount > 0` | Số tiền hoàn lại phải dương. |
| `invitation_parties`| `chk_parties_invited_count`| `invited_count >= 0` | Hạn mức người mời không âm. |
| `event_responses` | `chk_responses_count_pos` | `attending_count >= 0` | Số người đi RSVP không âm. |
| `event_responses` | `chk_attending_count_rule` | Attending count khớp is_attending. | Ràng buộc nghiệp vụ RSVP. |

---

## 12. Ràng Buộc Duy Nhất (Unique Constraints Matrix)

| Tên Bảng | Tên Chỉ mục / Ràng buộc | Cú pháp định nghĩa vật lý | Ý nghĩa nghiệp vụ |
| :--- | :--- | :--- | :--- |
| `wedding_members` | `uq_wedding_member` | `UNIQUE(wedding_id, user_id)` | Một User chỉ có duy nhất 1 membership dòng trạng thái cho mỗi wedding. |
| `pending_collaborator_invitations`| `uq_pending_collaborator` | `UNIQUE(wedding_id, normalized_invited_email) WHERE (status = 'PENDING')` | Chống gửi trùng lời mời đang chờ. |
| `invitations` | `uq_invitation_party` | `UNIQUE(invitation_party_id)` | Mỗi nhóm mời chỉ có duy nhất 1 thiệp active. |
| `invitation_event_targetings` | `pk_invitation_event_targeting`| `PRIMARY KEY (invitation_id, wedding_event_id)` | Chống nhắm trùng lặp lễ cho thiệp. |
| `invitation_credentials` | `uq_active_credential` | `UNIQUE(invitation_id) WHERE (is_active = true)` | Mỗi thiệp mời chỉ có tối đa 1 link active. |
| `invitation_credentials` | `uq_credentials_token_hash`| `UNIQUE(token_hash)` | Token băm SHA-256 là duy nhất toàn cầu. |
| `rsvps` | `uq_invitation_rsvp` | `UNIQUE(invitation_id)` | Tối đa 1 phản hồi tham dự cho mỗi thiệp. |
| `event_responses` | `uq_rsvp_event_response` | `UNIQUE(rsvp_id, wedding_event_id)` | Mỗi lễ chỉ báo đi/bận 1 lần trong RSVP. |

---

## 13. Danh Sách Đánh Chỉ Mục (Index Matrix)

| Tên Bảng | Tên Chỉ mục | Cột dữ liệu | Loại | Query Use Case |
| :--- | :--- | :--- | :---: | :--- |
| `wedding_members` | `idx_members_user` | `(user_id)` | B-Tree | Tìm kiếm đám cưới của tài khoản khi login. |
| `tasks` | `idx_tasks_wedding_status` | `(wedding_id, status)` | B-Tree | Tải danh sách công việc theo trạng thái. |
| `budget_items` | `idx_budget_items_wedding` | `(wedding_id)` | B-Tree | Tải báo cáo chi tiêu tài chính. |
| `guests` | `idx_guests_wedding_phone`| `(wedding_id, normalized_phone)`| B-Tree | Quét tìm trùng lặp SĐT phục vụ duplicate warning. |
| `guests` | `idx_guests_wedding_email`| `(wedding_id, normalized_email)`| B-Tree | Quét tìm trùng lặp email khách mời. |
| `guests` | `idx_guests_wedding_name` | `(wedding_id, name)` | B-Tree | Sắp xếp danh bạ theo tên của đám cưới. |
| `invitation_credentials`| `idx_credentials_hash` | `(token_hash)` | B-Tree | So khớp mã hash khi khách mở link. |
| `rsvps` | `idx_rsvps_invitation` | `(invitation_id)` | B-Tree | Tra cứu phản hồi của thiệp mời. |

---

## 14. Chiến Lược Tính Chỉ Tiêu Phái Sinh (Derived-value Matrix)

Hệ thống phân định phương án thực thi cho từng chỉ số phái sinh để tối ưu hóa hiệu năng MVP:

| Chỉ số Phái sinh | Môi trường lưu trữ gốc (Source facts) | Phương án thực thi vật lý (Physical Strategy) | Cách thức tính toán nghiệp vụ |
| :--- | :--- | :--- | :--- |
| **Net Paid** | `payments` + `refunds` | Authorized Derived Read (Query/View) | Tổng Payment thành công (ACTIVE) trừ đi tổng Refund thành công (ACTIVE) của BudgetItem. |
| **Outstanding** | `budget_items` + Net Paid | Authorized Derived Read (Query/View) | `Confirmed Cost - Net Paid`. Null nếu confirmed cost chưa chốt. |
| **Overpaid** | `budget_items` + Net Paid | Authorized Derived Read (Query/View) | `Net Paid - Confirmed Cost` (khi Net Paid > Confirmed Cost). |
| **Projected Cost**| `budget_items` | Authorized Derived Read (Query/View) | `COALESCE(confirmed_cost, estimated_cost)`. |
| **Planning Progress**| `tasks` | Authorized Derived Read (Query/View) | Tỷ lệ phần trăm công việc có `status = 'COMPLETED'` trên tổng số Task của đám cưới. |
| **Task Overdue** | `tasks` + `wedding_events` | Authorized Derived Read (Query/View) | Đầu việc có trạng thái khác `COMPLETED` và có thời hạn chót dương lịch bé hơn ngày hiện tại của máy chủ. |
| **Installment status**| `installments` + `payments` | Authorized Derived Read (Query/View) | Trả về trạng thái đợt: UPCOMING (chưa đến due_date, chưa thanh toán đủ) / PARTIALLY_PAID (đã thanh toán > 0 nhưng chưa đủ amount) / PAID (đã thanh toán đủ amount) / OVERDUE (quá due_date nhưng chưa đủ). |
| **Cash Flow 7/30 days**| `payments` | Authorized Derived Read (Trusted/Query)| Quét tính tổng lượng Payments thành công (ACTIVE) trong khoảng 7 hoặc 30 ngày gần nhất. |
| **Payment Schedule Review**| `budget_items` + `installments`| Authorized Derived Read (Query/View) | Phát hiện chênh lệch khi `Confirmed Cost` khác biệt hoàn toàn với `SUM(Installment.amount)` của khoản chi. |
| **RSVP Summary** | `event_responses` | Authorized Derived Read (Query/View) | Tổng hợp số lượng đi thực tế (`attending_count`) của các sự kiện để hiện thị Dashboard. |
| **RSVP Overcount Warning**| `event_responses` + Party | Authorized Derived Read (Query/View) | Phát hiện khi tổng `attending_count` của một RSVP lớn hơn hạn mức mời `invited_count` của Party. |

---

## 15. Sổ Nhật Ký Xung Đột & Khoảng Trống Vật Lý (Conflict & Gap Register)

Dưới đây là danh sách các Gap và Conflict được phát hiện và giải quyết triệt để ở đặc tả schema vật lý:

*   **`PHYSICAL-DATA-GAP-001` đến `007`:** Đã giải quyết.
*   **`PHYSICAL-DATA-GAP-008` (Task Assignee):** Đã giải quyết. Bổ sung `assignee_wedding_member_id` và `side` vào `tasks`.
*   **`PHYSICAL-DATA-GAP-009` (Finance Responsible):** Đã giải quyết. Bổ sung `responsible_wedding_member_id` vào `budget_items`.
*   **`PHYSICAL-DATA-GAP-010` (RSVP optional data):** Đã giải quyết. Bổ sung `companion_names text[]`, `dietary_info text`, và `guest_message text` vào `rsvps`.
*   **`PHYSICAL-DATA-GAP-011` (Invitation lifecycle tracking):** Đã giải quyết. Tách biệt `status` (`DRAFT`/`READY`/`MARKED_AS_SENT`) và các trường tracking.
*   **`PHYSICAL-DATA-GAP-012` (Guest normalized email):** Đã giải quyết. Bổ sung trường `normalized_email` vào `guests` (có index không unique `idx_guests_wedding_email`).
*   **`PHYSICAL-DATA-GAP-013` (Membership revocation reference semantics):** Đã giải quyết. Khi member bị REVOKED, giữ nguyên các liên kết cũ trong lịch sử, chỉ cho phép phân công mới cho ACTIVE member, và hiển thị cảnh báo Needs Review trong Attention Center nếu có Task chưa xong hoặc BudgetItem liên kết với REVOKED member.
*   **`PHYSICAL-DATA-CONFLICT-001` (Invitation lifecycle vs Credential lifecycle):** Đã giải quyết. Loại bỏ `REVOKED` khỏi trạng thái thiệp mời `invitations.status` (Invitation primary status chỉ gồm `DRAFT`, `READY`, `MARKED_AS_SENT`). Thu hồi link/mã truy cập được quản lý riêng bởi bảng `invitation_credentials` thông qua trường `is_active` và `revoked_at`.
*   **`ERRATA-PHY-001` (Composite FK SET NULL):** Đã giải quyết. Cấu hình rõ ràng `ON DELETE SET NULL (column_name)` cho các khóa ngoại ghép của Task và BudgetItem để tránh làm rỗng trường `wedding_id`.
*   **`ERRATA-PHY-002` (System-origin Task Removal):** Đã giải quyết. Nhóm công việc mẫu hệ thống chưa sửa bao gồm cả `SYSTEM_TEMPLATE` và `RECOMMENDATION` khi `is_user_modified = false`.
*   **`ERRATA-PHY-003` (Tenant-Scoped Referential Integrity):** Đã giải quyết. Thực thi các ràng buộc khóa ngoại ghép ở mức database để đảm bảo tính nhất quán đám cưới chéo (cross-tenant referential integrity) giữa các bảng thực thể con và sự kiện, nhóm mời, nhóm quan hệ, và đợt thanh toán.
*   **`ERRATA-PHY-004` (Payment / Installment Delete Integrity):** Đã giải quyết. Đổi cơ chế xóa của khóa ngoại phức hợp từ `ON DELETE SET NULL` sang `ON DELETE RESTRICT` để bảo toàn lịch sử liên kết đợt chi tiêu.
*   **`ERRATA-PHY-005` (Authoritative Template Source):** Đã giải quyết. Xác định nguồn mẫu của hệ thống là nội dung tĩnh/config ở phía máy chủ (version-controlled server-side content), không phụ thuộc vào Flutter client khai báo.
*   **`ERRATA-PHY-006` (Active Member for New References):** Đã giải quyết. Định nghĩa quy tắc an ninh chỉ cho phép gán người phụ trách (assignee/responsible) là ACTIVE member cho bản ghi mới hoặc thay đổi, giữ nguyên các tham chiếu lịch sử tới REVOKED member.
*   **`ERRATA-PHY-007` (Initial Plan Generation Marker):** Đã giải quyết. Thay thế cờ boolean bằng trường `initial_plan_generated_at timestamptz` có đặc quyền ghi hệ thống tin cậy.
*   **`ERRATA-PHY-008` (Wedding DELETING Lifecycle):** Đã giải quyết. Bổ sung trạng thái `DELETING` vào vòng đời đám cưới `weddings.status` để hỗ trợ quy trình xóa an toàn liên kết Storage.
*   **`ERRATA-PHY-009` (Durable Trusted Operation Receipts):** Đã giải quyết. Bổ sung bảng kỹ thuật nội bộ `private.trusted_operation_receipts` phục vụ cơ chế chống trùng lặp ghi nhận an toàn cho các tác vụ tạo/nhập dữ liệu nhạy cảm.




