class InvitationPartyModel {
  final String id;
  final String weddingId;
  final String displayName;
  final int invitedCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  InvitationPartyModel({
    required this.id,
    required this.weddingId,
    required this.displayName,
    required this.invitedCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InvitationPartyModel.fromJson(Map<String, dynamic> json) {
    return InvitationPartyModel(
      id: json['id'] as String,
      weddingId: json['wedding_id'] as String,
      displayName: json['display_name'] as String,
      invitedCount: json['invited_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'wedding_id': weddingId,
      'display_name': displayName,
      'invited_count': invitedCount,
    };
  }
}
