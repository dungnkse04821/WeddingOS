import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

enum WeddingDeleteResult {
  deleted,
  retryRequired,
  unauthorized,
  authLost,
  failed,
}

typedef RpcInvoker = Future<dynamic> Function(
  String functionName,
  Map<String, dynamic> params,
);
typedef EdgeInvoker = Future<Map<String, dynamic>> Function(
  String functionName,
  Map<String, dynamic> body,
);
typedef AuthLostHandler = Future<void> Function();

class WeddingLifecycleService {
  WeddingLifecycleService({
    SupabaseService? supabaseService,
    RpcInvoker? rpcInvoker,
    EdgeInvoker? edgeInvoker,
    AuthLostHandler? authLostHandler,
  }) : _supabase = supabaseService ?? SupabaseService.instance,
       _rpcInvoker = rpcInvoker,
       _edgeInvoker = edgeInvoker,
       _authLostHandler = authLostHandler;

  final SupabaseService _supabase;
  final RpcInvoker? _rpcInvoker;
  final EdgeInvoker? _edgeInvoker;
  final AuthLostHandler? _authLostHandler;

  Future<void> archiveWedding(String weddingId) async {
    final params = {'p_wedding_id': weddingId};
    if (_rpcInvoker != null) {
      await _rpcInvoker('archive_wedding', params);
      return;
    }
    await _supabase.client.rpc('archive_wedding', params: params);
  }

  Future<WeddingDeleteResult> deleteWedding(String weddingId) async {
    try {
      final body = {'wedding_id': weddingId};
      final data = _edgeInvoker != null
          ? await _edgeInvoker('wedding-delete', body)
          : Map<String, dynamic>.from(
              (await _supabase.client.functions.invoke(
                    'wedding-delete',
                    body: body,
                  )).data
                  as Map,
            );
      return data['status'] == 'DELETED'
          ? WeddingDeleteResult.deleted
          : WeddingDeleteResult.retryRequired;
    } on FunctionException catch (error) {
      if (error.status == 401) {
        await (_authLostHandler ?? _supabase.handleAuthLost)();
        return WeddingDeleteResult.authLost;
      }
      if (error.status == 403) {
        return WeddingDeleteResult.unauthorized;
      }
      return WeddingDeleteResult.retryRequired;
    } catch (_) {
      return WeddingDeleteResult.failed;
    }
  }
}
