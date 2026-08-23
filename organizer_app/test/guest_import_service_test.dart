import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organizer_app/models/guest_import_model.dart';
import 'package:organizer_app/models/guest_model.dart';
import 'package:organizer_app/services/guest_import_service.dart';

void main() {
  final service = GuestImportService();
  final existingGuests = [
    GuestModel(
      id: 'g-existing',
      weddingId: 'w1',
      name: 'Nguyễn Văn A',
      phone: '0912345678',
      normalizedPhone: '0912345678',
      email: 'old@example.com',
      normalizedEmail: 'old@example.com',
      side: 'COMMON',
      guestSource: 'OTHER',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  test('template uses approved flat row columns', () {
    final preview = service.parseXlsxBytes(
      bytes: service.buildTemplateBytes(),
      existingGuests: const [],
    );

    expect(GuestImportTemplate.columns, [
      'Guest Name',
      'Phone',
      'Email',
      'Side',
      'PrimaryGroup',
      'Party Key',
      'Party Display Name',
      'Invited Count',
      'Guest Source',
    ]);
    expect(preview.totalRows, 2);
    expect(preview.rows.first.partyKey, 'P001');
    expect(preview.rows.last.partyKey, isEmpty);
  });

  test(
    'blank Party Key remains unassigned and does not require party facts',
    () {
      final preview = service.parseXlsxBytes(
        bytes: _xlsx([
          ['Khách lẻ', '', '', 'COMMON', '', '', '', '', 'OTHER'],
        ]),
        existingGuests: const [],
      );

      expect(preview.hasFatalRows, isFalse);
      expect(preview.toConfirmRows().single['party_key'], isEmpty);
      expect(preview.toConfirmRows().single['party_display_name'], isEmpty);
    },
  );

  test('same Party Key requires consistent party-level facts', () {
    final preview = service.parseXlsxBytes(
      bytes: _xlsx([
        ['A', '', '', 'COMMON', '', 'P1', 'Gia đình A', '2', 'OTHER'],
        ['B', '', '', 'COMMON', '', 'P1', 'Gia đình A', '3', 'OTHER'],
      ]),
      existingGuests: const [],
    );

    expect(preview.errorRows, 1);
    expect(preview.hasFatalRows, isTrue);
  });

  test(
    'duplicate phone email and weak name warnings do not block confirm rows',
    () {
      final preview = service.parseXlsxBytes(
        bytes: _xlsx([
          [
            'Nguyễn Văn A',
            '0912345678',
            'new@example.com',
            'COMMON',
            '',
            '',
            '',
            '',
            'OTHER',
          ],
          [
            'Nguyễn Văn B',
            '0922222222',
            'same@example.com',
            'COMMON',
            '',
            '',
            '',
            '',
            'OTHER',
          ],
          [
            'Nguyễn Văn C',
            '0933333333',
            'same@example.com',
            'COMMON',
            '',
            '',
            '',
            '',
            'OTHER',
          ],
        ]),
        existingGuests: existingGuests,
      );

      expect(preview.warningRows, 3);
      expect(preview.hasFatalRows, isFalse);
      expect(preview.toConfirmRows(), hasLength(3));
    },
  );

  test('unknown Guest Source requires mapping before confirm', () {
    final preview = service.parseXlsxBytes(
      bytes: _xlsx([
        ['Khách cần map', '', '', 'COMMON', '', '', '', '', 'Bố CR'],
      ]),
      existingGuests: const [],
    );

    expect(preview.mappingRequiredRows, 1);
    expect(preview.hasFatalRows, isTrue);

    final mapped = preview.applySourceMapping('BỐ CR', 'GROOM_PARENTS');
    expect(mapped.hasFatalRows, isFalse);
    expect(mapped.toConfirmRows().single['guest_source'], 'GROOM_PARENTS');
  });

  test('300 row parser benchmark stays under MVP target', () {
    final rows = List.generate(300, (index) {
      return [
        'Khách $index',
        '09${(10000000 + index).toString().padLeft(8, '0')}',
        'guest$index@example.com',
        'COMMON',
        'Nhóm benchmark',
        'P${index ~/ 3}',
        'Party ${index ~/ 3}',
        '3',
        'OTHER',
      ];
    });

    final preview = service.parseXlsxBytes(
      bytes: _xlsx(rows),
      existingGuests: const [],
    );

    // The approved MVP target is preview parsing under 5 seconds for ~300 rows.
    expect(preview.totalRows, 300);
    // ignore: avoid_print
    print('M2B.3 300 row parse: ${preview.parseMilliseconds}ms');
    expect(preview.parseMilliseconds, lessThan(5000));
  });
}

Uint8List _xlsx(List<List<String>> dataRows) {
  final excel = Excel.createExcel();
  excel.rename('Sheet1', GuestImportTemplate.sheetName);
  final sheet = excel[GuestImportTemplate.sheetName];
  sheet.appendRow(GuestImportTemplate.columns.map(TextCellValue.new).toList());
  for (final row in dataRows) {
    sheet.appendRow(row.map(TextCellValue.new).toList());
  }
  return Uint8List.fromList(excel.encode() ?? <int>[]);
}
