import 'package:flutter_test/flutter_test.dart';
import 'package:organizer_app/services/finance_service.dart';
import 'package:organizer_app/utils/money_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _RpcCapture {
  String? functionName;
  Map<String, dynamic>? params;
  Object? error;

  Future<dynamic> call(
    String nextFunctionName,
    Map<String, dynamic> nextParams,
  ) async {
    functionName = nextFunctionName;
    params = Map<String, dynamic>.from(nextParams);
    final nextError = error;
    if (nextError != null) throw nextError;
    return <String, dynamic>{};
  }
}

void main() {
  group('MoneyText', () {
    test(
      'normalizes exact numeric(15,2) decimal strings without floating point',
      () {
        expect(MoneyText.normalize('0.10'), '0.10');
        expect(MoneyText.normalize('0.29'), '0.29');
        expect(MoneyText.normalize('1.01'), '1.01');
        expect(MoneyText.normalize('1000000.01'), '1000000.01');
        expect(MoneyText.normalize('9999999999999.99'), '9999999999999.99');
        expect(MoneyText.normalize(' 000001.2 '), '1.20');
      },
    );

    test(
      'rejects invalid, ambiguous, non-positive, and out-of-range money',
      () {
        for (final value in [
          '1.001',
          'not-a-number',
          '1,25',
          '-1.00',
          '0',
          '99999999999999.99',
        ]) {
          expect(
            () => MoneyText.normalize(value),
            throwsA(isA<MoneyTextException>()),
          );
        }
        expect(MoneyText.normalize('0', allowZero: true), '0.00');
      },
    );
  });

  group('Finance RPC serialization', () {
    late _RpcCapture capture;
    late FinanceService service;

    setUp(() {
      capture = _RpcCapture();
      service = FinanceService.withRpcInvoker(capture.call);
    });

    test(
      'create payment sends exact decimal string and payer contract',
      () async {
        await service.createPayment(
          requestId: 'request-id',
          budgetItemId: 'budget-id',
          installmentId: 'installment-id',
          amount: '0.29',
          paymentDate: '2026-08-26',
          payerDisplayName: 'External payer',
          notes: 'note',
        );

        expect(capture.functionName, 'create_payment');
        expect(capture.params, {
          'p_request_id': 'request-id',
          'p_budget_item_id': 'budget-id',
          'p_installment_id': 'installment-id',
          'p_amount': '0.29',
          'p_payment_date': '2026-08-26',
          'p_payer_display_name': 'External payer',
          'p_payer_wedding_member_id': null,
          'p_notes': 'note',
        });
        expect(capture.params!['p_amount'], isA<String>());
      },
    );

    test('edit payment uses installed FIN-002 names and stale guard', () async {
      final updatedAt = DateTime.parse('2026-08-26T10:11:12.123456+07:00');

      await service.editPayment(
        paymentId: 'payment-id',
        installmentId: 'new-installment-id',
        amount: '1000000.01',
        paymentDate: '2026-08-27',
        payerWeddingMemberId: 'member-id',
        payerDisplayName: null,
        notes: 'updated note',
        expectedUpdatedAt: updatedAt,
      );

      expect(capture.functionName, 'edit_payment');
      expect(capture.params, {
        'p_payment_id': 'payment-id',
        'p_installment_id': 'new-installment-id',
        'p_amount': '1000000.01',
        'p_payment_date': '2026-08-27',
        'p_payer_wedding_member_id': 'member-id',
        'p_payer_display_name': null,
        'p_notes': 'updated note',
        'p_expected_updated_at': updatedAt.toUtc().toIso8601String(),
      });
      expect(
        capture.params!.keys.where((key) => key.startsWith('p_new_')),
        isEmpty,
      );
      expect(capture.params!['p_amount'], isA<String>());
    });

    test('create and edit refund use exact decimal-string contracts', () async {
      await service.createRefund(
        requestId: 'request-id',
        budgetItemId: 'budget-id',
        amount: '1.01',
        refundDate: '2026-08-26',
        receiver: 'Receiver',
        notes: null,
      );
      expect(capture.functionName, 'create_refund');
      expect(capture.params!['p_amount'], '1.01');
      expect(capture.params!['p_amount'], isA<String>());

      final updatedAt = DateTime.parse('2026-08-26T02:03:04Z');
      await service.editRefund(
        refundId: 'refund-id',
        amount: '0.10',
        refundDate: '2026-08-28',
        receiver: 'Updated receiver',
        notes: 'updated note',
        expectedUpdatedAt: updatedAt,
      );

      expect(capture.functionName, 'edit_refund');
      expect(capture.params, {
        'p_refund_id': 'refund-id',
        'p_amount': '0.10',
        'p_refund_date': '2026-08-28',
        'p_receiver': 'Updated receiver',
        'p_notes': 'updated note',
        'p_expected_updated_at': '2026-08-26T02:03:04.000Z',
      });
      expect(
        capture.params!.keys.where((key) => key.startsWith('p_new_')),
        isEmpty,
      );
      expect(capture.params!['p_amount'], isA<String>());
    });

    test('FIN-007 keeps installed names but sends decimal strings', () async {
      await service.previewInstallmentCompound(
        'installment-id',
        '0.29',
        '2026-09-01',
      );
      expect(capture.functionName, 'preview_installment_compound');
      expect(capture.params!['p_new_amount'], '0.29');
      expect(capture.params!['p_new_amount'], isA<String>());

      await service.commitInstallmentCompound(
        'installment-id',
        'fingerprint',
        '9999999999999.99',
        '2026-09-01',
      );
      expect(capture.functionName, 'commit_installment_compound');
      expect(capture.params!['p_new_amount'], '9999999999999.99');
      expect(capture.params!['p_new_amount'], isA<String>());
    });

    test('stale Payment edit maps to a bounded conflict', () async {
      capture.error = const PostgrestException(
        message: 'STALE_STATE internal detail',
        code: '40901',
        details: 'payments table detail',
        hint: 'internal hint',
      );

      await expectLater(
        service.editPayment(
          paymentId: 'payment-id',
          amount: '1.00',
          paymentDate: '2026-08-26',
          payerDisplayName: 'Payer',
          expectedUpdatedAt: DateTime.utc(2026, 8, 26),
        ),
        throwsA(
          isA<FinanceServiceException>()
              .having((error) => error.code, 'code', 'STALE_STATE')
              .having(
                (error) => error.message,
                'message',
                isNot(contains('internal detail')),
              ),
        ),
      );
    });

    test('FIN-007 stale impact keeps its existing bounded contract', () async {
      capture.error = const PostgrestException(
        message: 'STALE_IMPACT internal detail',
        code: '40901',
        details: 'installment detail',
        hint: 'internal hint',
      );

      await expectLater(
        service.previewInstallmentCompound(
          'installment-id',
          '1.00',
          '2026-08-26',
        ),
        throwsA(
          isA<FinanceServiceException>()
              .having((error) => error.code, 'code', 'STALE_IMPACT')
              .having(
                (error) => error.message,
                'message',
                isNot(contains('internal detail')),
              ),
        ),
      );
    });

    test('unknown Refund DB errors never expose raw details', () async {
      capture.error = const PostgrestException(
        message: 'relation refunds secret internal failure',
        code: 'XX000',
        details: 'raw database detail',
        hint: 'raw database hint',
      );

      await expectLater(
        service.editRefund(
          refundId: 'refund-id',
          amount: '1.00',
          refundDate: '2026-08-26',
          receiver: 'Receiver',
          expectedUpdatedAt: DateTime.utc(2026, 8, 26),
        ),
        throwsA(
          isA<FinanceServiceException>()
              .having((error) => error.code, 'code', 'SYSTEM_ERROR')
              .having(
                (error) => error.message,
                'message',
                allOf(
                  isNot(contains('refunds')),
                  isNot(contains('raw database')),
                ),
              ),
        ),
      );
    });
  });
}
