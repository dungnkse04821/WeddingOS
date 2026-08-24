class InstallmentModel {
  final String id;
  final String budgetItemId;
  final String amount;
  final DateTime dueDate;
  final String status;
  final DateTime createdAt;

  InstallmentModel({
    required this.id,
    required this.budgetItemId,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.createdAt,
  });

  factory InstallmentModel.fromJson(Map<String, dynamic> json) {
    return InstallmentModel(
      id: json['id'] as String,
      budgetItemId: json['budget_item_id'] as String,
      amount: json['amount']?.toString() ?? '0.00',
      dueDate: DateTime.parse(json['due_date'] as String),
      status: json['status'] as String? ?? 'PENDING',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
