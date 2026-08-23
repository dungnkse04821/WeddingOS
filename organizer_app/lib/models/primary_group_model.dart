class PrimaryGroupModel {
  final String id;
  final String weddingId;
  final String name;
  final DateTime createdAt;

  PrimaryGroupModel({
    required this.id,
    required this.weddingId,
    required this.name,
    required this.createdAt,
  });

  factory PrimaryGroupModel.fromJson(Map<String, dynamic> json) {
    return PrimaryGroupModel(
      id: json['id'] as String,
      weddingId: json['wedding_id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'wedding_id': weddingId,
      'name': name,
    };
  }
}
