class GuestModel {
  final String id;
  final String weddingId;
  final String? invitationPartyId;
  final String? primaryGroupId;
  final String name;
  final String? phone;
  final String? normalizedPhone;
  final String? email;
  final String? normalizedEmail;
  final String side; // COMMON, BRIDE_SIDE, GROOM_SIDE
  final String guestSource; // BRIDE, GROOM, BRIDE_PARENTS, GROOM_PARENTS, OTHER
  final DateTime createdAt;
  final DateTime updatedAt;

  GuestModel({
    required this.id,
    required this.weddingId,
    this.invitationPartyId,
    this.primaryGroupId,
    required this.name,
    this.phone,
    this.normalizedPhone,
    this.email,
    this.normalizedEmail,
    required this.side,
    required this.guestSource,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GuestModel.fromJson(Map<String, dynamic> json) {
    return GuestModel(
      id: json['id'] as String,
      weddingId: json['wedding_id'] as String,
      invitationPartyId: json['invitation_party_id'] as String?,
      primaryGroupId: json['primary_group_id'] as String?,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      normalizedPhone: json['normalized_phone'] as String?,
      email: json['email'] as String?,
      normalizedEmail: json['normalized_email'] as String?,
      side: json['side'] as String? ?? 'COMMON',
      guestSource: json['guest_source'] as String? ?? 'OTHER',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wedding_id': weddingId,
      'invitation_party_id': invitationPartyId,
      'primary_group_id': primaryGroupId,
      'name': name,
      'phone': phone,
      'email': email,
      // client must NOT directly specify or edit normalized columns
      'side': side,
      'guest_source': guestSource,
    };
  }
}
