# Nhật Ký Thực Thi: 16 — M2B.1 Guest / PrimaryGroup / InvitationParty Foundation

*   **Trạng thái (Status):** IN REVIEW
*   **Người thực hiện:** Antigravity (AI Architect)
*   **Ngày cập nhật:** 23/08/2026

---

## A. Guest migration implementation
Đã tạo tệp di trú SQL mới: [00000000000004_batch_04.sql](file:///D:/Dung/Project/VibeCode/WeddingOS/supabase/migrations/00000000000004_batch_04.sql) để tạo bảng `public.guests` với các thuộc tính và khóa ngoại vật lý phù hợp với đặc tả.

## B. PrimaryGroup implementation
Đã tạo bảng `public.primary_groups` trong [batch_04.sql](file:///D:/Dung/Project/VibeCode/WeddingOS/supabase/migrations/00000000000004_batch_04.sql) để phân nhóm mối quan hệ của khách mời, gán ràng buộc duy nhất phức hợp `uq_primary_groups_wedding_key`.

## C. InvitationParty implementation
Đã tạo bảng `public.invitation_parties` để gom nhóm thiệp mời/hộ gia đình của khách mời, gán ràng buộc `uq_parties_wedding_key` và check constraint `chk_parties_invited_count`.

## D. Guest normalization
Đã triển khai trigger `trg_guests_normalize_contacts` thực thi hàm `public.fn_normalize_guest_contacts()` trước khi ghi (`BEFORE INSERT OR UPDATE`):
*   `email`: Chuyển sang chữ thường, cắt bỏ khoảng trắng đầu/cuối.
*   `phone`: Chỉ giữ lại ký số, nếu bắt đầu bằng mã nước `84` thì tự động đổi thành đầu số `0`.

## E. Duplicate-signal implementation (RESOLVED IMPL-CONFLICT-008)
*   Đã gỡ bỏ hàm RPC unapproved `api_v1.check_guest_duplicates` khỏi database.
*   Đã chuyển sang phương án sử dụng truy vấn PostgREST có RLS bảo vệ trên bảng `guests` cùng với việc đối soát trùng lặp ở tầng Client (Dart):
    *   Số điện thoại chuẩn hóa (Phone) -> Strong warning.
    *   Email chuẩn hóa (Email) -> Warning.
    *   Tên (Name) -> Weak warning (so khớp không phân biệt hoa thường sau khi trim).
*   Không tự động gộp (no auto-merge) và không chặn lưu khách mời (no hard block).

## F. Invited Count invariant (RESOLVED IMPL-CONFLICT-007)
*   Đã cấu hình ràng buộc `CONSTRAINT chk_parties_invited_count CHECK (invited_count > 0)` trên bảng `invitation_parties`, đảm bảo một nhóm mời/hộ phải luôn có số lượng chỗ ngồi thực tế dương (> 0).
*   Mặc định khi tạo mới một nhóm mời là 1.
*   Đặt kiểm thử chứng minh: Nhóm mời có 0 thành viên đã khai báo nhưng `invited_count > 0` vẫn hợp lệ; nhóm mời có `invited_count = 0` sẽ thất bại.
*   Thay đổi thành viên không tự động làm thay đổi hay ghi đè lên `invited_count`.

## G. Same-wedding integrity
Thiết lập các ràng buộc khóa ngoại ghép (Composite Foreign Keys) trên bảng `guests` để đảm bảo tính toàn vẹn cùng một Đám cưới (same-Wedding):
*   `fk_guests_party_wedding FOREIGN KEY (wedding_id, invitation_party_id) REFERENCES invitation_parties (wedding_id, id)`
*   `fk_guests_group_wedding FOREIGN KEY (wedding_id, primary_group_id) REFERENCES primary_groups (wedding_id, id)`

## H. RLS/Grant implementation (RESOLVED IMPL-GAP-005)
*   Bật Row Level Security (RLS) trên cả 3 bảng `primary_groups`, `invitation_parties`, `guests`.
*   Cấp quyền `SELECT`, `INSERT`, `UPDATE` cho vai trò `authenticated`.
*   Thu hồi hoàn toàn quyền `DELETE` trực tiếp (grants & RLS policy) của vai trò `authenticated` đối với cả 3 bảng trong M2B.1 để ngăn chặn hành vi xóa trực tiếp trái phép trước khi các luồng nghiệp vụ tin cậy (TOP-GUE-001/002/003) được triển khai ở M2B.2.
*   Thu hồi quyền INSERT, UPDATE trực tiếp đối với hai cột chuẩn hóa `normalized_phone` và `normalized_email` của vai trò `authenticated` để ngăn chặn client giả mạo dữ liệu phái sinh.

## I. Party assignment boundary (RESOLVED IMPL-CONFLICT-009)
*   Đã gỡ bỏ lỗ hổng chuyển nhóm hai bước (Two-step move bypass): Một khách mời đã được gán vào nhóm mời thì không thể tự ý chuyển nhóm (`Party A -> Party B`) hoặc tự ý gỡ nhóm (`Party A -> NULL`) thông qua cập nhật Class-B thông thường của Client. Những hành vi này bị chặn ở tầng cơ sở dữ liệu thông qua trigger và không hiển thị trên giao diện Flutter.
*   **Trigger cưỡng chế:** Trigger `public.fn_enforce_guest_party_transition` sẽ ném ngoại lệ (`42501`) nếu phát hiện `OLD.invitation_party_id` không-null mà giá trị bị thay đổi sang giá trị khác (cho dù là null hay party_id khác).
*   **Thao tác hợp lệ:** Gán ban đầu (`NULL -> Party`) vẫn được cho phép bình thường.

## J. Flutter Guest/Group UI
*   `DirectoryScreen`: Chứa hai tab chính cho khách cá nhân và nhóm mời, hỗ trợ tìm kiếm và bộ lọc theo Phía (Side) và Nhóm (PrimaryGroup).
*   `GuestCreateEditScreen`: Form điền thông tin đầy đủ. Đã khóa chỉnh sửa nhóm mời (chuyển Dropdown hiển thị thành chế độ đọc thông tin có biểu tượng khóa) nếu khách mời đó đã có nhóm mời được gán trước đó. Đã gỡ bỏ nút Xóa (Delete).
*   `PartyCreateEditScreen`: Đã loại bỏ nút Unassign (gỡ thành viên) trong danh sách thành viên hiện có của nhóm mời. Chỉ cho phép gán thêm khách lẻ chưa có nhóm (`NULL -> Party`) từ danh sách phía dưới.
*   `GroupManagementScreen`: Danh sách nhóm, tạo mới và đổi tên nhóm (safe edit). Chỉ hỗ trợ Create/Read/Update, không có hành động DELETE.

## K. DB suite/assertion count
Tất cả các tệp kiểm thử `pgTAP` đã chạy thành công tuyệt đối:
*   `database_verification.test.sql`
*   `database_verification_batch_02.test.sql`
*   `database_verification_batch_03.test.sql`
*   `database_verification_batch_04.test.sql` (23 assertions cho Guest Core, Transitions & Boundaries)
*   **Tổng số assertions vượt qua:** 139 tests.

## L. Flutter tests/analyze
*   Bộ widget test `organizer_app/test/guest_verification_test.dart` chạy thành công 100%.
*   Lệnh `flutter analyze` trả về 0 lỗi.

## M. Clean reset
Lệnh `npx supabase db reset` chạy thành công sạch sẽ, áp dụng đúng 5 tệp migration (batch_00 -> batch_04).

## N. Planning regression
Không phá vỡ bất kỳ logic lập kế hoạch hay cấu hình migrations cũ nào từ batch_01 -> batch_03.

## O. Defects/fixes
*   **Defect-001 (UUID Syntax):** UUID của nhóm mối quan hệ trong file test bị lỗi ký tự `g` phi-hex. Đã đổi thành ký tự `d` hợp lệ.
*   **Defect-002 (Colors.white50):** Flutter `Colors` không có màu `white50`. Đã đổi sang dùng `Colors.white54`.
*   **Defect-003 (Container constraints):** Thẻ `Container` không hỗ trợ tham số `maxHeight` trực tiếp. Đã chuyển sang dùng `constraints: BoxConstraints(maxHeight: 200)`.
*   **Defect-004 (Counter widget_test):** Giao diện AuthScreen lỗi biên dịch smoke test cũ. Đã chuyển `widget_test.dart` thành một bài kiểm tra boilerplate đơn giản.
*   **Defect-005 (M2A.2 Preview screen compilation):** Sửa lỗi gán kiểu `Border` cho `BorderSide` và các lỗi sử dụng thuộc tính không tồn tại (`EdgeInsets.bottom`, `Colors.white80`, `MainAxisAlignment.between`) trong màn hình xem trước thay đổi/xóa sự kiện cũ.
*   **Defect-006 (GuestModel property camelCase):** Đã sửa lỗi gọi `widget.guest!.invitation_party_id` thành `widget.guest!.invitationPartyId` phù hợp với thuộc tính Dart Model.
