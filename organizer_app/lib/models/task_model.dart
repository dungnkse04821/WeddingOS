class TaskModel {
  final String id;
  final String weddingId;
  final String? weddingEventId;
  final String? assigneeWeddingMemberId;
  final String name;
  final String status; // TODO, IN_PROGRESS, COMPLETED, CANCELLED
  final String deadlineIntent; // SYSTEM_RELATIVE, USER_RELATIVE, USER_ABSOLUTE, NO_DEADLINE
  final int? dateOffset;
  final DateTime? customOverrideDate;
  final DateTime? completedAt;
  final DateTime? resolvedDeadlineAt;
  final String taskSource; // SYSTEM_TEMPLATE, RECOMMENDATION, USER
  final bool isUserModified;
  final String side; // COMMON, BRIDE_SIDE, GROOM_SIDE

  TaskModel({
    required this.id,
    required this.weddingId,
    this.weddingEventId,
    this.assigneeWeddingMemberId,
    required this.name,
    required this.status,
    required this.deadlineIntent,
    this.dateOffset,
    this.customOverrideDate,
    this.completedAt,
    this.resolvedDeadlineAt,
    required this.taskSource,
    required this.isUserModified,
    required this.side,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String,
      weddingId: json['wedding_id'] as String,
      weddingEventId: json['wedding_event_id'] as String?,
      assigneeWeddingMemberId: json['assignee_wedding_member_id'] as String?,
      name: json['name'] as String,
      status: json['status'] as String,
      deadlineIntent: json['deadline_intent'] as String,
      dateOffset: json['date_offset'] as int?,
      customOverrideDate: json['custom_override_date'] != null
          ? DateTime.parse(json['custom_override_date'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      resolvedDeadlineAt: json['resolved_deadline_at'] != null
          ? DateTime.parse(json['resolved_deadline_at'] as String)
          : null,
      taskSource: json['task_source'] as String,
      isUserModified: json['is_user_modified'] as bool? ?? false,
      side: json['side'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'wedding_id': weddingId,
      'wedding_event_id': weddingEventId,
      'assignee_wedding_member_id': assigneeWeddingMemberId,
      'name': name,
      'status': status,
      'deadline_intent': deadlineIntent,
      'date_offset': dateOffset,
      'custom_override_date': customOverrideDate?.toIso8601String().split('T').first,
      'completed_at': completedAt?.toIso8601String(),
      'resolved_deadline_at': resolvedDeadlineAt?.toIso8601String().split('T').first,
      'task_source': taskSource,
      'is_user_modified': isUserModified,
      'side': side,
    };
  }

  bool get isCompleted => status == 'COMPLETED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isTODO => status == 'TODO';
  bool get isInProgress => status == 'IN_PROGRESS';

  // Helper check for display overdue state (derived status, not stored on DB)
  bool get isOverdue {
    if (isCompleted || isCancelled || resolvedDeadlineAt == null) return false;
    // Strip time for clean date comparison
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    return resolvedDeadlineAt!.isBefore(todayDateOnly);
  }
}
