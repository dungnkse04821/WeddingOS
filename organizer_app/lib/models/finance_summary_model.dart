class FinanceSummaryModel {
  final String weddingId;
  final String? targetBudget;
  final String totalProjected;
  final String totalConfirmed;
  final String netPaid;
  final String? outstanding;
  final String overpaid;
  final String upcoming7d;
  final String upcoming30d;

  FinanceSummaryModel({
    required this.weddingId,
    this.targetBudget,
    required this.totalProjected,
    required this.totalConfirmed,
    required this.netPaid,
    this.outstanding,
    required this.overpaid,
    required this.upcoming7d,
    required this.upcoming30d,
  });

  factory FinanceSummaryModel.fromJson(Map<String, dynamic> json) {
    return FinanceSummaryModel(
      weddingId: json['wedding_id'] as String,
      targetBudget: json['target_budget']?.toString(),
      totalProjected: json['total_projected']?.toString() ?? '0.00',
      totalConfirmed: json['total_confirmed']?.toString() ?? '0.00',
      netPaid: json['net_paid']?.toString() ?? '0.00',
      outstanding: json['outstanding']?.toString(),
      overpaid: json['overpaid']?.toString() ?? '0.00',
      upcoming7d: json['upcoming_7d']?.toString() ?? '0.00',
      upcoming30d: json['upcoming_30d']?.toString() ?? '0.00',
    );
  }
}
