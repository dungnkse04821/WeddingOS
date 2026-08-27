import 'package:flutter_test/flutter_test.dart';
import 'package:organizer_app/foundation/app_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('safe organizer error mapping', () {
    test('redacts database and provider diagnostics', () {
      const raw = PostgrestException(
        message: 'SQLSTATE 42501 api_v1.secret_rpc failed',
        code: '42501',
        details: 'https://provider.invalid stack trace storage/path',
      );

      final failure = AppErrorMapper.map(raw);

      expect(failure.message, AppErrorMapper.accessRevokedMessage);
      expect(failure.message, isNot(contains('42501')));
      expect(failure.message, isNot(contains('api_v1')));
      expect(failure.message, isNot(contains('provider')));
    });

    test('preserves approved stale and delete retry distinctions', () {
      expect(
        AppErrorMapper.map(Exception('STALE_STATE')).kind,
        AppErrorKind.staleState,
      );
      expect(
        AppErrorMapper.map(Exception('STALE_IMPACT')).kind,
        AppErrorKind.staleImpact,
      );
      expect(
        AppErrorMapper.map(Exception('DELETE_RETRY_REQUIRED')).kind,
        AppErrorKind.retryRequired,
      );
    });

    test('maps expired auth and unknown stack-like errors safely', () {
      expect(
        AppErrorMapper.map(const AuthException('JWT expired')).kind,
        AppErrorKind.authLost,
      );
      final generic = AppErrorMapper.map(
        Exception('StackTrace at provider.example/rpc private_table'),
      );
      expect(generic.message, AppErrorMapper.genericMessage);
      expect(generic.message, isNot(contains('StackTrace')));
    });
  });
}
