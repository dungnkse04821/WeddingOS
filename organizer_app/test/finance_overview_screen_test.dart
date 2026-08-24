import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organizer_app/models/finance_summary_model.dart';
import 'package:organizer_app/screens/finance_overview_screen.dart';
import 'package:organizer_app/services/finance_service.dart';
import 'package:organizer_app/services/supabase_service.dart';

class FakeSupabaseService extends Fake implements SupabaseService {
  @override
  String? getSelectedWeddingId() => 'w-test';
}

class FakeFinanceService extends Fake implements FinanceService {
  @override
  Future<FinanceSummaryModel?> fetchFinanceSummary(String weddingId) async {
    return FinanceSummaryModel(
      weddingId: weddingId,
      targetBudget: '500000.00',
      totalProjected: '12000.00',
      totalConfirmed: '10000.00',
      netPaid: '5000.00',
      outstanding: null, // Triggers "Không xác định"
      overpaid: '0.00',
      upcoming7d: '1000.00',
      upcoming30d: '3000.00',
    );
  }
}

void main() {
  testWidgets('FinanceOverviewScreen shows unknown semantics properly', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: FinanceOverviewScreen(
        financeService: FakeFinanceService(),
        supabaseService: FakeSupabaseService(),
      ),
    ));

    // Wait for the async _loadSummary to complete
    await tester.pump();

    expect(find.text('Tổng quan Tài chính'), findsOneWidget);
    expect(find.textContaining('Không xác định'), findsOneWidget);
  });
}
