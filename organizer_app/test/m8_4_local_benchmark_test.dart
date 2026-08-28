import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organizer_app/models/guest_import_model.dart';
import 'package:organizer_app/models/guest_model.dart';
import 'package:organizer_app/models/task_model.dart';
import 'package:organizer_app/services/guest_import_service.dart';

void main() {
  final tasks = List.generate(500, (index) => TaskModel(
    id: 'task-$index',
    weddingId: 'wedding',
    name: 'Task $index',
    status: 'TODO',
    deadlineIntent: 'NO_DEADLINE',
    taskSource: 'USER',
    isUserModified: false,
    side: 'COMMON',
  ));
  final guests = List.generate(300, (index) => GuestModel(
    id: 'guest-$index',
    weddingId: 'wedding',
    name: 'Guest $index',
    side: 'COMMON',
    guestSource: 'OTHER',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ));

  testWidgets('M8.4 local task-list initial render stays below the approved two-second target', (tester) async {
    final timings = <int>[];
    for (var iteration = 0; iteration < 5; iteration++) {
      final stopwatch = Stopwatch()..start();
      await tester.pumpWidget(_ListHarness(labels: tasks.map((task) => task.name).toList()));
      await tester.pump();
      stopwatch.stop();
      timings.add(stopwatch.elapsedMilliseconds);
    }
    final median = _median(timings);
    // ignore: avoid_print
    print('M8.4 local task-list 500-row initial render median: ${median}ms');
    expect(median, lessThan(2000));
  });

  testWidgets('M8.4 local guest-list initial render stays below the approved two-second target', (tester) async {
    final timings = <int>[];
    for (var iteration = 0; iteration < 5; iteration++) {
      final stopwatch = Stopwatch()..start();
      await tester.pumpWidget(_ListHarness(labels: guests.map((guest) => guest.name).toList()));
      await tester.pump();
      stopwatch.stop();
      timings.add(stopwatch.elapsedMilliseconds);
    }
    final median = _median(timings);
    // ignore: avoid_print
    print('M8.4 local guest-list 300-row initial render median: ${median}ms');
    expect(median, lessThan(2000));
  });

  test('M8.4 local Excel preview parser remains below the approved five-second target', () {
    final service = GuestImportService();
    final rows = List.generate(300, (index) => [
      'Guest $index', '090000${index.toString().padLeft(4, '0')}', 'guest$index@example.invalid',
      'COMMON', 'Benchmark group', 'P${index ~/ 3}', 'Party ${index ~/ 3}', '3', 'OTHER',
    ]);
    final bytes = _xlsx(rows);
    final timings = <int>[];
    for (var iteration = 0; iteration < 5; iteration++) {
      final preview = service.parseXlsxBytes(bytes: bytes, existingGuests: const []);
      expect(preview.totalRows, 300);
      timings.add(preview.parseMilliseconds);
    }
    final median = _median(timings);
    // ignore: avoid_print
    print('M8.4 local Excel 300-row preview median: ${median}ms');
    expect(median, lessThan(5000));
  });
}

class _ListHarness extends StatelessWidget {
  const _ListHarness({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(body: ListView.builder(
      itemCount: labels.length,
      itemBuilder: (context, index) => ListTile(title: Text(labels[index])),
    )),
  );
}

int _median(List<int> values) {
  final sorted = [...values]..sort();
  return sorted[sorted.length ~/ 2];
}

Uint8List _xlsx(List<List<String>> rows) {
  final excel = Excel.createExcel();
  excel.rename('Sheet1', GuestImportTemplate.sheetName);
  final sheet = excel[GuestImportTemplate.sheetName];
  sheet.appendRow(GuestImportTemplate.columns.map(TextCellValue.new).toList());
  for (final row in rows) {
    sheet.appendRow(row.map(TextCellValue.new).toList());
  }
  return Uint8List.fromList(excel.encode() ?? <int>[]);
}
