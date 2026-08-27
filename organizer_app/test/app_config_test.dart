import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:organizer_app/foundation/app_config.dart';

String _jwtForRole(String role) {
  final payload = base64Url.encode(utf8.encode(jsonEncode({'role': role})));
  return 'header.$payload.signature-that-is-long-enough';
}

void main() {
  group('public build-time configuration', () {
    test('accepts plausible URL and publishable client key', () {
      final config = AppConfig.fromEnvironment(
        supabaseUrl: 'https://project.supabase.co',
        supabaseAnonKey: 'sb_publishable_example_key_1234567890',
      );

      expect(config.supabaseUrl, 'https://project.supabase.co');
      expect(config.supabaseAnonKey, startsWith('sb_publishable_'));
    });

    test('rejects missing and malformed URLs', () {
      expect(
        () => AppConfig.fromEnvironment(
          supabaseUrl: '',
          supabaseAnonKey: 'sb_publishable_example_key_1234567890',
        ),
        throwsA(isA<AppConfigException>()),
      );
      expect(
        () => AppConfig.fromEnvironment(
          supabaseUrl: 'project.supabase.co',
          supabaseAnonKey: 'sb_publishable_example_key_1234567890',
        ),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rejects missing client key without echoing supplied material', () {
      const supplied = 'short-private-value';
      try {
        AppConfig.fromEnvironment(
          supabaseUrl: 'http://localhost:54321',
          supabaseAnonKey: supplied,
        );
        fail('Expected invalid key');
      } on AppConfigException catch (error) {
        expect(error.message, isNot(contains(supplied)));
      }
    });

    test('rejects a service-role JWT from the client configuration path', () {
      expect(
        () => AppConfig.fromEnvironment(
          supabaseUrl: 'https://project.supabase.co',
          supabaseAnonKey: _jwtForRole('service_role'),
        ),
        throwsA(isA<AppConfigException>()),
      );
      expect(
        AppConfig.fromEnvironment(
          supabaseUrl: 'https://project.supabase.co',
          supabaseAnonKey: _jwtForRole('anon'),
        ).supabaseAnonKey,
        isNotEmpty,
      );
    });
  });
}
