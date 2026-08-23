enum GuestImportStatus { valid, warning, mappingRequired, error }

enum GuestImportDuplicateType { phone, email, name }

class GuestImportTemplate {
  static const sheetName = 'WeddingOS Guests';
  static const columns = [
    'Guest Name',
    'Phone',
    'Email',
    'Side',
    'PrimaryGroup',
    'Party Key',
    'Party Display Name',
    'Invited Count',
    'Guest Source',
  ];

  static const sideValues = ['COMMON', 'BRIDE_SIDE', 'GROOM_SIDE'];
  static const guestSourceValues = [
    'BRIDE',
    'GROOM',
    'BRIDE_PARENTS',
    'GROOM_PARENTS',
    'OTHER',
  ];
}

class GuestImportRow {
  final int rowNumber;
  final String guestName;
  final String phone;
  final String email;
  final String side;
  final String primaryGroupName;
  final String partyKey;
  final String partyDisplayName;
  final int? invitedCount;
  final String guestSource;
  final GuestImportStatus status;
  final List<String> errors;
  final List<String> warnings;

  const GuestImportRow({
    required this.rowNumber,
    required this.guestName,
    required this.phone,
    required this.email,
    required this.side,
    required this.primaryGroupName,
    required this.partyKey,
    required this.partyDisplayName,
    required this.invitedCount,
    required this.guestSource,
    required this.status,
    required this.errors,
    required this.warnings,
  });

  bool get canConfirm =>
      status == GuestImportStatus.valid || status == GuestImportStatus.warning;

  Map<String, dynamic> toConfirmJson() {
    return {
      'row_number': rowNumber,
      'guest_name': guestName,
      'phone': phone,
      'email': email,
      'side': side,
      'primary_group_name': primaryGroupName,
      'party_key': partyKey,
      'party_display_name': partyDisplayName,
      'invited_count': invitedCount?.toString() ?? '',
      'guest_source': guestSource,
    };
  }

  GuestImportRow copyWith({
    GuestImportStatus? status,
    List<String>? errors,
    List<String>? warnings,
    String? guestSource,
  }) {
    return GuestImportRow(
      rowNumber: rowNumber,
      guestName: guestName,
      phone: phone,
      email: email,
      side: side,
      primaryGroupName: primaryGroupName,
      partyKey: partyKey,
      partyDisplayName: partyDisplayName,
      invitedCount: invitedCount,
      guestSource: guestSource ?? this.guestSource,
      status: status ?? this.status,
      errors: errors ?? this.errors,
      warnings: warnings ?? this.warnings,
    );
  }
}

class GuestImportPreview {
  final List<GuestImportRow> rows;
  final Map<String, String> sourceMappings;
  final int parseMilliseconds;

  const GuestImportPreview({
    required this.rows,
    required this.sourceMappings,
    required this.parseMilliseconds,
  });

  int get totalRows => rows.length;
  int get validRows =>
      rows.where((row) => row.status == GuestImportStatus.valid).length;
  int get warningRows =>
      rows.where((row) => row.status == GuestImportStatus.warning).length;
  int get errorRows =>
      rows.where((row) => row.status == GuestImportStatus.error).length;
  int get mappingRequiredRows => rows
      .where((row) => row.status == GuestImportStatus.mappingRequired)
      .length;
  int get newParties => rows
      .map((row) => row.partyKey)
      .where((key) => key.isNotEmpty)
      .toSet()
      .length;
  int get newGroups => rows
      .map((row) => row.primaryGroupName)
      .where((name) => name.isNotEmpty)
      .toSet()
      .length;
  bool get hasFatalRows => errorRows > 0 || mappingRequiredRows > 0;

  List<Map<String, dynamic>> toConfirmRows() {
    return rows
        .where((row) => row.canConfirm)
        .map((row) => row.toConfirmJson())
        .toList();
  }

  GuestImportPreview applySourceMapping(String rawSource, String mappedSource) {
    final updatedMappings = Map<String, String>.from(sourceMappings)
      ..[rawSource] = mappedSource;
    return GuestImportPreview(
      rows: rows.map((row) {
        if (row.guestSource != rawSource) return row;
        final warnings = row.warnings
            .where((warning) => !warning.startsWith('Nguồn mời cần ánh xạ'))
            .toList();
        final status = row.errors.isNotEmpty
            ? GuestImportStatus.error
            : warnings.isNotEmpty
            ? GuestImportStatus.warning
            : GuestImportStatus.valid;
        return row.copyWith(
          status: status,
          warnings: warnings,
          guestSource: mappedSource,
        );
      }).toList(),
      sourceMappings: updatedMappings,
      parseMilliseconds: parseMilliseconds,
    );
  }
}

class GuestImportConfirmResult {
  final bool replayed;
  final int guestCount;
  final int newGroupCount;
  final int newPartyCount;
  final int warningCount;

  const GuestImportConfirmResult({
    required this.replayed,
    required this.guestCount,
    required this.newGroupCount,
    required this.newPartyCount,
    required this.warningCount,
  });

  factory GuestImportConfirmResult.fromJson(Map<String, dynamic> json) {
    final summary = Map<String, dynamic>.from(json['summary'] as Map);
    return GuestImportConfirmResult(
      replayed: json['replayed'] as bool? ?? false,
      guestCount: summary['guest_count'] as int? ?? 0,
      newGroupCount: summary['new_group_count'] as int? ?? 0,
      newPartyCount: summary['new_party_count'] as int? ?? 0,
      warningCount: summary['warning_count'] as int? ?? 0,
    );
  }
}
