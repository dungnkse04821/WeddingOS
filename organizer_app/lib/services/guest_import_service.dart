import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart';

import '../models/guest_import_model.dart';
import '../models/guest_model.dart';

class GuestImportFilePicker {
  static const _channel = MethodChannel('weddingos/file_picker');

  Future<Uint8List?> pickXlsxBytes() async {
    final bytes = await _channel.invokeMethod<Uint8List>('pickXlsx');
    return bytes;
  }
}

class GuestImportService {
  static const maxRows = 300;

  Uint8List buildTemplateBytes() {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', GuestImportTemplate.sheetName);
    final sheet = excel[GuestImportTemplate.sheetName];
    sheet.appendRow(
      GuestImportTemplate.columns.map(TextCellValue.new).toList(),
    );
    sheet.appendRow([
      TextCellValue('Nguyễn Văn A'),
      TextCellValue('0912345678'),
      TextCellValue('khach@example.com'),
      TextCellValue('COMMON'),
      TextCellValue('Đồng nghiệp'),
      TextCellValue('P001'),
      TextCellValue('Gia đình anh A'),
      TextCellValue('4'),
      TextCellValue('BRIDE'),
    ]);
    sheet.appendRow([
      TextCellValue('Trần Thị B'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue('BRIDE_SIDE'),
      TextCellValue('Bạn cấp 3'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue('BRIDE_PARENTS'),
    ]);
    return Uint8List.fromList(excel.encode() ?? <int>[]);
  }

  Future<File> writeTemplateToDownloads() async {
    final bytes = buildTemplateBytes();
    final directory = Directory.systemTemp;
    final file = File(
      '${directory.path}${Platform.pathSeparator}weddingos_guest_import_template.xlsx',
    );
    return file.writeAsBytes(bytes, flush: true);
  }

  GuestImportPreview parseXlsxBytes({
    required Uint8List bytes,
    required List<GuestModel> existingGuests,
    Map<String, String> sourceMappings = const {},
  }) {
    final stopwatch = Stopwatch()..start();
    final workbook = Excel.decodeBytes(bytes);
    final sheet = workbook[GuestImportTemplate.sheetName];
    final rows = sheet.rows;
    if (rows.isEmpty) {
      throw const FormatException('Tệp import không có dòng tiêu đề.');
    }

    final headers = rows.first.map(_cellText).toList();
    _validateHeaders(headers);

    final parsedRows = <GuestImportRow>[];
    final partyFacts = <String, ({String displayName, int? invitedCount})>{};

    for (var index = 1; index < rows.length; index++) {
      final row = rows[index];
      if (_isBlankRow(row)) continue;
      if (parsedRows.length >= maxRows) {
        throw const FormatException(
          'MVP chỉ hỗ trợ tối đa 300 dòng mỗi lần import.',
        );
      }

      final rawSource = _value(row, 8).toUpperCase();
      final mappedSource = sourceMappings[rawSource] ?? rawSource;
      final invitedCountText = _value(row, 7);
      final invitedCount = invitedCountText.isEmpty
          ? null
          : int.tryParse(invitedCountText);
      final importRow = GuestImportRow(
        rowNumber: index + 1,
        guestName: _value(row, 0),
        phone: _value(row, 1),
        email: _value(row, 2).toLowerCase(),
        side: _value(row, 3).toUpperCase(),
        primaryGroupName: _value(row, 4),
        partyKey: _value(row, 5),
        partyDisplayName: _value(row, 6),
        invitedCount: invitedCount,
        guestSource: mappedSource,
        status: GuestImportStatus.valid,
        errors: const [],
        warnings: const [],
      );

      final validated = _validateRow(
        importRow,
        rawSource: rawSource,
        sourceMappings: sourceMappings,
        partyFacts: partyFacts,
        invitedCountText: invitedCountText,
      );
      parsedRows.add(validated);
    }

    final withDuplicates = _applyDuplicateWarnings(parsedRows, existingGuests);
    stopwatch.stop();
    return GuestImportPreview(
      rows: withDuplicates,
      sourceMappings: sourceMappings,
      parseMilliseconds: stopwatch.elapsedMilliseconds,
    );
  }

  void _validateHeaders(List<String> headers) {
    for (var index = 0; index < GuestImportTemplate.columns.length; index++) {
      if (index >= headers.length ||
          headers[index] != GuestImportTemplate.columns[index]) {
        throw FormatException(
          'Sai định dạng template tại cột ${index + 1}: cần "${GuestImportTemplate.columns[index]}".',
        );
      }
    }
  }

  GuestImportRow _validateRow(
    GuestImportRow row, {
    required String rawSource,
    required Map<String, String> sourceMappings,
    required Map<String, ({String displayName, int? invitedCount})> partyFacts,
    required String invitedCountText,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    if (row.guestName.isEmpty) {
      errors.add('Thiếu tên khách mời.');
    } else if (row.guestName.length > 50) {
      errors.add('Tên khách mời vượt quá 50 ký tự.');
    }

    if (!GuestImportTemplate.sideValues.contains(row.side)) {
      errors.add('Side không hợp lệ.');
    }

    if (row.phone.isNotEmpty && !_isValidPhone(row.phone)) {
      errors.add('Số điện thoại không hợp lệ.');
    }

    if (row.email.isNotEmpty && !_isValidEmail(row.email)) {
      errors.add('Email không hợp lệ.');
    }

    if (!GuestImportTemplate.guestSourceValues.contains(row.guestSource)) {
      warnings.add('Nguồn mời cần ánh xạ: $rawSource.');
    }

    if (row.primaryGroupName.isNotEmpty) {
      warnings.add(
        'Nhóm mới có thể được tạo nếu chưa tồn tại: ${row.primaryGroupName}.',
      );
    }

    if (row.partyKey.isEmpty) {
      if (row.partyDisplayName.isNotEmpty || invitedCountText.isNotEmpty) {
        errors.add('Thông tin Party chỉ hợp lệ khi có Party Key.');
      }
    } else {
      if (row.partyDisplayName.isEmpty) {
        errors.add('Party Key cần Party Display Name.');
      }
      if (invitedCountText.isEmpty ||
          row.invitedCount == null ||
          row.invitedCount! <= 0) {
        errors.add('Invited Count phải là số nguyên dương.');
      }

      final existing = partyFacts[row.partyKey];
      if (existing == null) {
        partyFacts[row.partyKey] = (
          displayName: row.partyDisplayName,
          invitedCount: row.invitedCount,
        );
        warnings.add('Party mới sẽ được tạo từ Party Key: ${row.partyKey}.');
      } else if (existing.displayName != row.partyDisplayName ||
          existing.invitedCount != row.invitedCount) {
        errors.add(
          'Party Key ${row.partyKey} có Display Name hoặc Invited Count không nhất quán.',
        );
      }
    }

    final status = errors.isNotEmpty
        ? GuestImportStatus.error
        : warnings.any((warning) => warning.startsWith('Nguồn mời cần ánh xạ'))
        ? GuestImportStatus.mappingRequired
        : warnings.isNotEmpty
        ? GuestImportStatus.warning
        : GuestImportStatus.valid;

    return row.copyWith(status: status, errors: errors, warnings: warnings);
  }

  List<GuestImportRow> _applyDuplicateWarnings(
    List<GuestImportRow> rows,
    List<GuestModel> existingGuests,
  ) {
    final normalizedExistingPhones = existingGuests
        .map((guest) => guest.normalizedPhone)
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet();
    final normalizedExistingEmails = existingGuests
        .map((guest) => guest.normalizedEmail)
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet();
    final existingNames = existingGuests
        .map((guest) => guest.name.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();

    final importPhones = <String, int>{};
    final importEmails = <String, int>{};
    final importNames = <String, int>{};
    for (final row in rows) {
      final phone = _normalizePhone(row.phone);
      if (phone != null) importPhones[phone] = (importPhones[phone] ?? 0) + 1;
      final email = row.email.trim().toLowerCase();
      if (email.isNotEmpty) {
        importEmails[email] = (importEmails[email] ?? 0) + 1;
      }
      final name = row.guestName.trim().toLowerCase();
      if (name.isNotEmpty) importNames[name] = (importNames[name] ?? 0) + 1;
    }

    return rows.map((row) {
      final warnings = [...row.warnings];
      final phone = _normalizePhone(row.phone);
      if (phone != null &&
          (normalizedExistingPhones.contains(phone) ||
              (importPhones[phone] ?? 0) > 1)) {
        warnings.add('Cảnh báo trùng số điện thoại.');
      }
      final email = row.email.trim().toLowerCase();
      if (email.isNotEmpty &&
          (normalizedExistingEmails.contains(email) ||
              (importEmails[email] ?? 0) > 1)) {
        warnings.add('Cảnh báo trùng email.');
      }
      final name = row.guestName.trim().toLowerCase();
      if (name.isNotEmpty &&
          (existingNames.contains(name) || (importNames[name] ?? 0) > 1)) {
        warnings.add('Cảnh báo trùng tên.');
      }

      if (row.status == GuestImportStatus.error ||
          row.status == GuestImportStatus.mappingRequired) {
        return row.copyWith(warnings: warnings);
      }
      return row.copyWith(
        status: warnings.isEmpty
            ? GuestImportStatus.valid
            : GuestImportStatus.warning,
        warnings: warnings,
      );
    }).toList();
  }

  bool _isBlankRow(List<Data?> row) =>
      row.every((cell) => _cellText(cell).isEmpty);

  String _value(List<Data?> row, int index) =>
      index >= row.length ? '' : _cellText(row[index]);

  String _cellText(Data? cell) {
    final value = cell?.value;
    if (value == null) return '';
    return switch (value) {
      TextCellValue() => value.value.toString().trim(),
      IntCellValue() => value.value.toString(),
      DoubleCellValue() => value.value.toString(),
      BoolCellValue() => value.value ? 'true' : 'false',
      FormulaCellValue() => value.formula.trim(),
      DateCellValue() => '${value.year}-${value.month}-${value.day}',
      TimeCellValue() => '${value.hour}:${value.minute}:${value.second}',
      DateTimeCellValue() =>
        '${value.year}-${value.month}-${value.day} ${value.hour}:${value.minute}:${value.second}',
    };
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  bool _isValidPhone(String phone) {
    final normalized = _normalizePhone(phone);
    return normalized != null &&
        normalized.length >= 9 &&
        normalized.length <= 11;
  }

  String? _normalizePhone(String phone) {
    if (phone.trim().isEmpty) return null;
    var cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('84')) {
      cleaned = '0${cleaned.substring(2)}';
    }
    return cleaned.isEmpty ? null : cleaned;
  }
}
