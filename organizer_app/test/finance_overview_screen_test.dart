import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organizer_app/screens/finance_overview_screen.dart';

void main() {
  testWidgets('FinanceOverviewScreen shows unknown semantics properly', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: FinanceOverviewScreen(),
    ));

    expect(find.text('Tổng quan Tài chính'), findsOneWidget);
    expect(find.textContaining('Không xác định'), findsOneWidget);
  });
}
