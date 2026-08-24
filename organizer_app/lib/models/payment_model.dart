class PaymentModel {
  final String id;
  final String budgetItemId;
  final String? installmentId;
  final String amount;
  final DateTime paymentDate;
  final String payerDisplayName;
  final String? payerWeddingMemberId;
  final String status;
  final String? notes;
  final DateTime? voidedAt;
  final String? voidReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentModel({
    required this.id,
    required this.budgetItemId,
    this.installmentId,
    required this.amount,
    required this.paymentDate,
    required this.payerDisplayName,
    this.payerWeddingMemberId,
    required this.status,
    this.notes,
    this.voidedAt,
    this.voidReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String,
      budgetItemId: json['budget_item_id'] as String,
      installmentId: json['installment_id'] as String?,
      amount: json['amount']?.toString() ?? '0.00',
      paymentDate: DateTime.parse(json['payment_date'] as String),
      payerDisplayName: json['payer_display_name'] as String,
      payerWeddingMemberId: json['payer_wedding_member_id'] as String?,
      status: json['status'] as String? ?? 'ACTIVE',
      notes: json['notes'] as String?,
      voidedAt: json['voided_at'] != null ? DateTime.parse(json['voided_at'] as String) : null,
      voidReason: json['void_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
