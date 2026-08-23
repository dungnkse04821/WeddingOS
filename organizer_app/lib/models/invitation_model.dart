class InvitationModel {
  final String id;
  final String weddingId;
  final String invitationPartyId;
  final String status;
  final DateTime? markedSentAt;
  final DateTime? firstViewedAt;
  final DateTime? lastViewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  InvitationModel({
    required this.id,
    required this.weddingId,
    required this.invitationPartyId,
    required this.status,
    this.markedSentAt,
    this.firstViewedAt,
    this.lastViewedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InvitationModel.fromJson(Map<String, dynamic> json) {
    return InvitationModel(
      id: json['id'] as String,
      weddingId: json['wedding_id'] as String,
      invitationPartyId: json['invitation_party_id'] as String,
      status: json['status'] as String? ?? InvitationStatus.draft,
      markedSentAt: _parseDate(json['marked_sent_at']),
      firstViewedAt: _parseDate(json['first_viewed_at']),
      lastViewedAt: _parseDate(json['last_viewed_at']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class InvitationTargetingModel {
  final String weddingId;
  final String invitationId;
  final String weddingEventId;

  const InvitationTargetingModel({
    required this.weddingId,
    required this.invitationId,
    required this.weddingEventId,
  });

  factory InvitationTargetingModel.fromJson(Map<String, dynamic> json) {
    return InvitationTargetingModel(
      weddingId: json['wedding_id'] as String,
      invitationId: json['invitation_id'] as String,
      weddingEventId: json['wedding_event_id'] as String,
    );
  }
}

class WeddingEventInvitationOption {
  final String id;
  final String weddingId;
  final String name;
  final int? expectedYear;
  final int? expectedMonth;
  final DateTime? exactDate;
  final String lifecycleStatus;

  WeddingEventInvitationOption({
    required this.id,
    required this.weddingId,
    required this.name,
    this.expectedYear,
    this.expectedMonth,
    this.exactDate,
    required this.lifecycleStatus,
  });

  bool get isActive => lifecycleStatus == 'ACTIVE';

  bool get isRsvpReady => isActive && exactDate != null;

  bool get isSaveTheDateOnly =>
      isActive &&
      exactDate == null &&
      expectedYear != null &&
      expectedMonth != null;

  String get readinessLabel {
    if (!isActive) return 'Đã xóa - không thể chọn';
    if (isRsvpReady) return 'RSVP-ready: đã có ngày chính xác';
    if (isSaveTheDateOnly) {
      return 'Save-the-date: chỉ có tháng dự kiến, chưa mở RSVP';
    }
    return 'Chưa đủ dữ liệu hiển thị';
  }

  factory WeddingEventInvitationOption.fromJson(Map<String, dynamic> json) {
    return WeddingEventInvitationOption(
      id: json['id'] as String,
      weddingId: json['wedding_id'] as String,
      name: json['name'] as String,
      expectedYear: json['expected_year'] as int?,
      expectedMonth: json['expected_month'] as int?,
      exactDate: _parseDate(json['exact_date']),
      lifecycleStatus: json['lifecycle_status'] as String? ?? 'ACTIVE',
    );
  }
}

class InvitationCredentialResult {
  final String invitationId;
  final String credentialId;
  final String rawToken;
  final String linkFragment;

  InvitationCredentialResult({
    required this.invitationId,
    required this.credentialId,
    required this.rawToken,
    required this.linkFragment,
  });

  String get sharePath => linkFragment;

  factory InvitationCredentialResult.fromJson(Map<String, dynamic> json) {
    return InvitationCredentialResult(
      invitationId: json['invitation_id'] as String,
      credentialId: json['credential_id'] as String,
      rawToken: json['raw_token'] as String,
      linkFragment: json['link_fragment'] as String,
    );
  }
}

class InvitationStatus {
  static const String draft = 'DRAFT';
  static const String ready = 'READY';
  static const String markedAsSent = 'MARKED_AS_SENT';

  static bool canMoveToReady(InvitationModel invitation) {
    return invitation.status == draft;
  }

  static bool canMarkAsSent(InvitationModel invitation) {
    return invitation.status == ready;
  }

  static String label(String status) {
    switch (status) {
      case ready:
        return 'Sẵn sàng';
      case markedAsSent:
        return 'Đã đánh dấu gửi';
      case draft:
      default:
        return 'Bản nháp';
    }
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.parse(value as String);
}
