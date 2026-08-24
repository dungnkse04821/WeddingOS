import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/finance_summary_model.dart';
import '../models/budget_item_model.dart';
import '../models/installment_model.dart';
import '../models/payment_model.dart';
import '../models/refund_model.dart';
import 'supabase_service.dart';

class FinanceServiceException implements Exception {
  final String code;
  final String message;

  FinanceServiceException(this.code, this.message);

  @override
  String toString() => 'FinanceServiceException(code: $code, message: $message)';
}

class FinanceService {
  static final FinanceService instance = FinanceService._internal();
  FinanceService._internal();

  SupabaseClient get _client => SupabaseService.instance.client;
  
  void _handleError(dynamic error) {
    if (error is PostgrestException) {
      if (error.message.contains('REQUEST_ID_REUSED')) {
        throw FinanceServiceException('REQUEST_ID_REUSED', 'Yêu cầu này đã được xử lý trước đó.');
      } else if (error.message.contains('STALE_IMPACT') || error.message.contains('IMPACT_FINGERPRINT_MISMATCH')) {
        throw FinanceServiceException('STALE_IMPACT', 'Dữ liệu đã thay đổi, vui lòng làm mới trang.');
      } else if (error.message.contains('HISTORY_GUARD')) {
        throw FinanceServiceException('HISTORY_GUARD', 'Không thể xoá vì đã có dữ liệu thanh toán.');
      } else if (error.message.contains('FINANCE_INTEGRITY')) {
        throw FinanceServiceException('FINANCE_INTEGRITY', 'Lỗi toàn vẹn dữ liệu tài chính.');
      }
      throw FinanceServiceException('db_error', error.message);
    }
    throw FinanceServiceException('unknown', error.toString());
  }

  Future<FinanceSummaryModel?> fetchFinanceSummary(String weddingId) async {
    try {
      final data = await _client
          .from('finance_summaries')
          .select()
          .eq('wedding_id', weddingId)
          .maybeSingle();
      if (data == null) return null;
      return FinanceSummaryModel.fromJson(data);
    } catch (e) {
      _handleError(e);
      return null;
    }
  }

  Future<List<BudgetItemModel>> listBudgetItems(String weddingId) async {
    try {
      final response = await _client
          .from('budget_items')
          .select()
          .eq('wedding_id', weddingId)
          .order('created_at', ascending: false);
      return response.map((e) => BudgetItemModel.fromJson(e)).toList();
    } catch (e) {
      _handleError(e);
      return [];
    }
  }
  
  Future<List<InstallmentModel>> listInstallments(String budgetItemId) async {
    try {
      final response = await _client
          .from('installments')
          .select()
          .eq('budget_item_id', budgetItemId)
          .order('due_date', ascending: true);
      return response.map((e) => InstallmentModel.fromJson(e)).toList();
    } catch (e) {
      _handleError(e);
      return [];
    }
  }
  
  Future<List<PaymentModel>> listPayments(String budgetItemId) async {
    try {
      final response = await _client
          .from('payments')
          .select()
          .eq('budget_item_id', budgetItemId)
          .order('payment_date', ascending: false);
      return response.map((e) => PaymentModel.fromJson(e)).toList();
    } catch (e) {
      _handleError(e);
      return [];
    }
  }

  Future<List<RefundModel>> listRefunds(String budgetItemId) async {
    try {
      final response = await _client
          .from('refunds')
          .select()
          .eq('budget_item_id', budgetItemId)
          .order('refund_date', ascending: false);
      return response.map((e) => RefundModel.fromJson(e)).toList();
    } catch (e) {
      _handleError(e);
      return [];
    }
  }

  // CUD Budget Items
  Future<void> createBudgetItem(Map<String, dynamic> data) async {
    try {
      await _client.from('budget_items').insert(data);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> updateBudgetItem(String id, Map<String, dynamic> data) async {
    try {
      await _client.from('budget_items').update(data).eq('id', id);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> deleteBudgetItem(String id) async {
    try {
      await _client.from('budget_items').delete().eq('id', id);
    } catch (e) {
      _handleError(e);
    }
  }

  // CUD Installments (Direct)
  Future<void> createInstallment(Map<String, dynamic> data) async {
    try {
      await _client.from('installments').insert(data);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> updateInstallment(String id, Map<String, dynamic> data) async {
    try {
      await _client.from('installments').update(data).eq('id', id);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> deleteInstallment(String id) async {
    try {
      await _client.from('installments').delete().eq('id', id);
    } catch (e) {
      _handleError(e);
    }
  }

  // FIN-007 Preview & Commit Installment
  Future<Map<String, dynamic>> previewInstallmentCompound(
      String installmentId, String amount, String dueDate) async {
    try {
      return await _client.rpc('preview_installment_compound', params: {
        'p_installment_id': installmentId,
        'p_new_amount': double.parse(amount), // Note: Postgres RPC takes numeric.
        'p_new_due_date': dueDate
      });
    } catch (e) {
      _handleError(e);
      return {};
    }
  }

  Future<void> commitInstallmentCompound(
      String installmentId, String impactFingerprint, String amount, String dueDate) async {
    try {
      await _client.rpc('commit_installment_compound', params: {
        'p_installment_id': installmentId,
        'p_impact_fingerprint': impactFingerprint,
        'p_new_amount': double.parse(amount),
        'p_new_due_date': dueDate
      });
    } catch (e) {
      _handleError(e);
    }
  }

  // RPC for Payments
  Future<void> createPayment({
    required String budgetItemId,
    String? installmentId,
    required String amount,
    required String paymentDate,
    required String payerDisplayName,
    String? payerWeddingMemberId,
    String? notes,
    required String requestId,
  }) async {
    try {
      await _client.rpc('create_payment', params: {
        'p_request_id': requestId,
        'p_budget_item_id': budgetItemId,
        'p_installment_id': installmentId,
        'p_amount': double.parse(amount),
        'p_payment_date': paymentDate,
        'p_payer_display_name': payerDisplayName,
        'p_payer_wedding_member_id': payerWeddingMemberId,
        'p_notes': notes
      });
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> editPayment({
    required String paymentId,
    required String amount,
    required String paymentDate,
    required String payerDisplayName,
    String? payerWeddingMemberId,
    String? notes,
  }) async {
    try {
      await _client.rpc('edit_payment', params: {
        'p_payment_id': paymentId,
        'p_new_amount': double.parse(amount),
        'p_new_payment_date': paymentDate,
        'p_new_payer_display_name': payerDisplayName,
        'p_new_payer_wedding_member_id': payerWeddingMemberId,
        'p_new_notes': notes
      });
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> voidPayment(String paymentId, String voidReason) async {
    try {
      await _client.rpc('void_payment', params: {
        'p_payment_id': paymentId,
        'p_void_reason': voidReason
      });
    } catch (e) {
      _handleError(e);
    }
  }

  // RPC for Refunds
  Future<void> createRefund({
    required String budgetItemId,
    required String amount,
    required String refundDate,
    required String receiver,
    String? notes,
    required String requestId,
  }) async {
    try {
      await _client.rpc('create_refund', params: {
        'p_request_id': requestId,
        'p_budget_item_id': budgetItemId,
        'p_amount': double.parse(amount),
        'p_refund_date': refundDate,
        'p_receiver': receiver,
        'p_notes': notes
      });
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> editRefund({
    required String refundId,
    required String amount,
    required String refundDate,
    required String receiver,
    String? notes,
  }) async {
    try {
      await _client.rpc('edit_refund', params: {
        'p_refund_id': refundId,
        'p_new_amount': double.parse(amount),
        'p_new_refund_date': refundDate,
        'p_new_receiver': receiver,
        'p_new_notes': notes
      });
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> voidRefund(String refundId, String voidReason) async {
    try {
      await _client.rpc('void_refund', params: {
        'p_refund_id': refundId,
        'p_void_reason': voidReason
      });
    } catch (e) {
      _handleError(e);
    }
  }
}
