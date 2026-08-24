class RefundModel {
  final String id;
  final String budgetItemId;
  final String amount;
  final DateTime refundDate;
  final String receiver;
  final String status;
  final String? notes;
  final DateTime? voidedAt;
  final String? voidReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  RefundModel({
    required this.id,
    required this.budgetItemId,
    required this.amount,
    required this.refundDate,
    required this.receiver,
    required this.status,
    this.notes,
    this.voidedAt,
    this.voidReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RefundModel.fromJson(Map<String, dynamic> json) {
    return RefundModel(
      id: json['id'] as String,
      budgetItemId: json['budget_item_id'] as String,
      amount: json['amount']?.toString() ?? '0.00',
      refundDate: DateTime.parse(json['refund_date'] as String),
      receiver: json['receiver'] as String,
      status: json['status'] as String? ?? 'ACTIVE',
      notes: json['notes'] as String?,
      voidedAt: json['voided_at'] != null ? DateTime.parse(json['voided_at'] as String) : null,
      voidReason: json['void_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
