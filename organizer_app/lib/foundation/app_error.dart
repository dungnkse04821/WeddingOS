import 'package:supabase_flutter/supabase_flutter.dart';

enum AppErrorKind {
  authLost,
  accessRevoked,
  validation,
  conflict,
  staleState,
  staleImpact,
  retryRequired,
  generic,
}

class AppFailure {
  const AppFailure(this.kind, this.message);

  final AppErrorKind kind;
  final String message;
}

class AppErrorMapper {
  static const authLostMessage =
      'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
  static const accessRevokedMessage =
      'Bạn không còn quyền truy cập đám cưới này.';
  static const retryMessage = 'Không thể kết nối lúc này. Vui lòng thử lại.';
  static const genericMessage = 'Có lỗi xảy ra. Vui lòng thử lại.';

  static AppFailure map(Object error) {
    final details = _details(error);

    if (error is AuthException ||
        (error is FunctionException && error.status == 401) ||
        details.contains('AUTH_LOST') ||
        details.contains('JWT EXPIRED') ||
        details.contains('INVALID JWT')) {
      return const AppFailure(AppErrorKind.authLost, authLostMessage);
    }
    if ((error is FunctionException && error.status == 403) ||
        details.contains('ACCESS_REVOKED') ||
        details.contains('NOT_AUTHORIZED') ||
        details.contains('42501') ||
        details.contains('PERMISSION DENIED')) {
      return const AppFailure(AppErrorKind.accessRevoked, accessRevokedMessage);
    }
    if (details.contains('STALE_IMPACT') ||
        details.contains('IMPACT_FINGERPRINT_MISMATCH')) {
      return const AppFailure(
        AppErrorKind.staleImpact,
        'Dữ liệu đã thay đổi. Vui lòng làm mới trước khi tiếp tục.',
      );
    }
    if (details.contains('STALE_STATE')) {
      return const AppFailure(
        AppErrorKind.staleState,
        'Dữ liệu đã thay đổi. Vui lòng tải lại trước khi lưu.',
      );
    }
    if (details.contains('DELETE_RETRY_REQUIRED')) {
      return const AppFailure(
        AppErrorKind.retryRequired,
        'Quá trình xóa chưa hoàn tất. Bạn có thể thử lại.',
      );
    }
    if (details.contains('REQUEST_ID_REUSED') || details.contains('CONFLICT')) {
      return const AppFailure(
        AppErrorKind.conflict,
        'Dữ liệu đã thay đổi hoặc yêu cầu đã được xử lý.',
      );
    }
    if (details.contains('INVALID_INPUT') || details.contains('VALIDATION')) {
      return const AppFailure(
        AppErrorKind.validation,
        'Dữ liệu không hợp lệ. Vui lòng kiểm tra lại.',
      );
    }
    if (error is FunctionException || error is PostgrestException) {
      return const AppFailure(AppErrorKind.retryRequired, retryMessage);
    }
    return const AppFailure(AppErrorKind.generic, genericMessage);
  }

  static String message(Object error) => map(error).message;

  static String _details(Object error) {
    if (error is FunctionException) {
      return '${error.reasonPhrase ?? ''} ${error.details ?? ''}'.toUpperCase();
    }
    if (error is PostgrestException) {
      return '${error.code ?? ''} ${error.message} ${error.details ?? ''}'
          .toUpperCase();
    }
    return error.toString().toUpperCase();
  }
}
