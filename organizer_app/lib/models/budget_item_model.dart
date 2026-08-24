class BudgetItemModel {
  final String id;
  final String weddingId;
  final String? weddingEventId;
  final String? responsibleWeddingMemberId;
  final String name;
  final String? estimatedCost;
  final String? confirmedCost;
  final String side;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  BudgetItemModel({
    required this.id,
    required this.weddingId,
    this.weddingEventId,
    this.responsibleWeddingMemberId,
    required this.name,
    this.estimatedCost,
    this.confirmedCost,
    required this.side,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BudgetItemModel.fromJson(Map<String, dynamic> json) {
    return BudgetItemModel(
      id: json['id'] as String,
      weddingId: json['wedding_id'] as String,
      weddingEventId: json['wedding_event_id'] as String?,
      responsibleWeddingMemberId: json['responsible_wedding_member_id'] as String?,
      name: json['name'] as String,
      estimatedCost: json['estimated_cost']?.toString(),
      confirmedCost: json['confirmed_cost']?.toString(),
      side: json['side'] as String? ?? 'COMMON',
      status: json['status'] as String? ?? 'ACTIVE',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
