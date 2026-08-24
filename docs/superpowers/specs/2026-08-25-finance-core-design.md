# Finance Core Design Specification
Date: 2026-08-25

## A. Finance Domain Model
- **Wedding Budget Target:** Tổng chi phí dự kiến cho đám cưới.
- **Budget Items (Hạng mục chi tiêu):** Các khoản chi cụ thể thuộc Budget. Mỗi hạng mục có thể được chia nhỏ thành nhiều kỳ thanh toán (Installments).
- **Installments (Kỳ thanh toán):** Các mốc thanh toán cho một Budget Item. Trạng thái thanh toán (PENDING/PAID) được suy ra từ các khoản thanh toán (Payments) thực tế.
- **Payments (Thanh toán):** Giao dịch trả tiền thực tế, ghi nhận số tiền, ngày trả, và người trả (Payer).
- **Refunds (Hoàn tiền):** Giao dịch nhận lại tiền từ một Budget Item đã thanh toán.
- **Payer (Người trả tiền):** Là một financial fact độc lập với Cost Side và Responsible. Có thể là WeddingMember hoặc một người ngoài.

## B. Exact Physical Schema
- `budget_items`: `id`, `wedding_id`, `category_id`, `name`, `estimated_amount`, `actual_amount`, `notes`, `created_at`, `updated_at`.
- `installments`: `id`, `budget_item_id`, `amount`, `due_date`, `notes`, `created_at`, `updated_at`.
- `payments`: `id`, `installment_id` (hoặc liên kết thẳng `budget_item_id`), `amount`, `payment_date`, `payer_wedding_member_id`, `payer_display_name`, `notes`, `created_at`, `updated_at`, `status` (ACTIVE/VOIDED).
- `refunds`: `id`, `budget_item_id`, `amount`, `refund_date`, `notes`, `created_at`, `updated_at`, `status` (ACTIVE/VOIDED).

## C. FK/Delete Semantics
- Installment references BudgetItem.
- Payment references Installment / BudgetItem.
- Refund references BudgetItem.
- Nếu có dữ liệu liên kết (history), việc xóa Budget Item hoặc Installment sẽ bị từ chối bằng Trigger/Constraint.

## D. Final Class-B/Class-C Matrix
| Resource | SELECT | INSERT | UPDATE | DELETE |
| --- | --- | --- | --- | --- |
| **BudgetItem** | OWNER Class B | OWNER Class B (Safe) | OWNER Class B (Safe) | OWNER Class B ONLY if no Installment, Payment, or Refund exists. Otherwise: DENIED. |
| **Installment** | OWNER Class B | OWNER Class B (Safe) | Class B only when no Payment history. With history: FIN-007 | Class B only when no Payment history. With history: DENIED. |
| **Payment / Refund** | OWNER only | Class C only | Class C only | Class C only (Void) |

## E. RLS / Grants
- Tất cả các bảng Finance chỉ cấp quyền `SELECT`, `INSERT`, `UPDATE`, `DELETE` cho OWNER thông qua helpers `security.is_wedding_owner(wedding_id)`. Collaborators bị block hoàn toàn.
- Bảng `payments` và `refunds` chặn CUD trực tiếp từ client (Grant không cho phép, hoặc RLS policy chặn CUD request thường).

## F. Payer Snapshot Semantics
- **Member Payer:** `payer_wedding_member_id` được gán, server tự động snapshot `display_name` hiện tại của member vào Payment. `display_name` này không bị cập nhật tự động nếu member sau này đổi tên (Historical Fact).
- **External Payer:** `payer_wedding_member_id` = NULL, `payer_display_name` là free-text (VD: "Bố chú rể"). Không tự sinh member giả.

## G. FIN-001 → FIN-007 Contracts (api_v1)
1. `api_v1.create_payment` (FIN-001)
2. `api_v1.edit_payment` (FIN-002)
3. `api_v1.void_payment` (FIN-003)
4. `api_v1.create_refund` (FIN-004)
5. `api_v1.edit_refund` (FIN-005)
6. `api_v1.void_refund` (FIN-006)
7. `api_v1.preview_installment_compound` (FIN-007 Preview)
8. `api_v1.commit_installment_compound` (FIN-007 Commit)
Không tồn tại FIN-008.

## H. Receipt/Idempotency Semantics
- Áp dụng cho receipt-backed RPC (FIN-001, FIN-004).
- Client sinh `request_id` (UUIDv4) đóng vai trò là idempotency/retry key. Nó KHÔNG phải là authorization token.
- Tính duy nhất: `(operation_type, actor_user_id, request_id)`.
- Replay: Cùng `request_id` + cùng semantics -> trả về authoritative result. Cùng `request_id` + khác semantics -> `REQUEST_ID_REUSED`.

## I. FIN-007 Preview/Commit/Fingerprint
- **Preview:** Tính toán state dự kiến, trả về `impact_fingerprint` (SHA-256 của installment identity, current amount/due_date/status, deterministic linked Payment semantic set).
- **Commit:** Xác minh lại `impact_fingerprint`. Fingerprint chỉ dùng cho stale-review detection, KHÔNG dùng làm receipt, idempotency hay authorization.

## J. Aggregate Formulas
- Tổng chi phí thực tế (Actual Amount) = Sum(Payments ACTIVE) - Sum(Refunds ACTIVE).
- Số tiền đã trả cho Installment = Sum(Payments ACTIVE linked to Installment).

## K. Installment Status Derivation
- Không lưu status dưới dạng Enum client CUD trực tiếp.
- `status` (PENDING / PAID) được server derived dựa trên `Sum(ACTIVE linked payments)` >= `installment.amount`.

## L. Delete-History Guards
- Database Triggers chặn DELETE trên `budget_items` và `installments` nếu client (không phải `trusted_function_owner`) cố ý thực hiện hành động DELETE khi đã có lịch sử.
- Trigger sử dụng `current_user` để phân biệt luồng trusted và luồng client. Không dùng session variables hay GUC bypass.

## M. Flutter Finance UX
- Giao diện Organizer sẽ reflect quyền OWNER.
- Hỗ trợ xem tổng quan, chi tiết từng hạng mục. Khi thao tác compound (FIN-007), phải hiển thị màn hình preview trước khi commit.

## N. Test Strategy
- Unit tests kiểm tra RLS policies chặn CUD từ Collaborator/Guest.
- Integration tests đảm bảo Trigger chặn DELETE khi có History.
- API tests cho 8 RPCs của FIN-001 -> FIN-007 (bao gồm Idempotency check và Fingerprint validation).

## O. Security Invariants
- Direct client CUD is blocked for Payments/Refunds.
- `current_user = 'trusted_function_owner'` is the only authorized bypass.
- Budget Item ID is immutable for Payments/Refunds.

## P. Resolved IMPL-CONFLICT-014
- **BudgetItem hard delete:** Được phép CHỈ KHI không có bất kỳ installments, payments, refunds nào liên kết. Client gọi Class-B DELETE bình thường. Trigger tự động phát hiện History và Reject. KHÔNG tự động chuyển sang `status = CANCELLED`.

## Q. Resolved IMPL-CONFLICT-015
- **Installment hard delete:** Được phép CHỈ KHI không có bất kỳ Payment history nào (ACTIVE hay VOIDED). Trigger sẽ phát hiện và Reject nếu có history. Xóa thông qua Class-B DELETE khi an toàn. KHÔNG dùng thủ thuật `amount = 0` hay đổi trạng thái ẩn.

## R. Remaining Known Tech Debt
- Các tính năng phức tạp hơn về Vendor, Hóa đơn OCR, đồng bộ ngân hàng (VietQR) bị hoãn khỏi Scope của M5.
