import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:organizer_app/foundation/app_config.dart';
import 'package:organizer_app/services/native_google_auth.dart';

AppConfig config({String? googleWebClientId}) => AppConfig(
  supabaseUrl: 'https://project.supabase.co',
  supabaseAnonKey: 'sb_publishable_example_key_1234567890',
  googleWebClientId: googleWebClientId,
);

void main() {
  test(
    'native Google auth initializes once with configured serverClientId',
    () async {
      final initializedIds = <String>[];
      final authenticator = NativeGoogleAuthenticator(
        initialize: ({required serverClientId}) async =>
            initializedIds.add(serverClientId),
        authenticate: () async =>
            const GoogleSignInAuthentication(idToken: 'google-id-token'),
      );

      await authenticator.authenticate(
        serverClientId: 'example.apps.googleusercontent.com',
      );
      await authenticator.authenticate(
        serverClientId: 'example.apps.googleusercontent.com',
      );

      expect(initializedIds, ['example.apps.googleusercontent.com']);
    },
  );

  test('missing native Google config fails before authentication', () async {
    var authenticateCalls = 0;
    final authenticator = NativeGoogleAuthenticator(
      initialize: ({required serverClientId}) async {},
      authenticate: () async {
        authenticateCalls++;
        return const GoogleSignInAuthentication(idToken: 'unused');
      },
    );

    await expectLater(
      signInWithNativeGoogle(
        config: config(),
        authenticator: authenticator,
        exchangeIdToken: (_) async {},
      ),
      throwsA(isA<AppConfigException>()),
    );
    expect(authenticateCalls, 0);
  });

  test(
    'google_sign_in 7 authentication hands only its ID token to Supabase',
    () async {
      final authenticator = NativeGoogleAuthenticator(
        initialize: ({required serverClientId}) async {},
        authenticate: () async =>
            const GoogleSignInAuthentication(idToken: 'google-id-token'),
      );
      String? exchangedIdToken;

      await signInWithNativeGoogle(
        config: config(googleWebClientId: 'example.apps.googleusercontent.com'),
        authenticator: authenticator,
        exchangeIdToken: (idToken) async => exchangedIdToken = idToken,
      );

      expect(exchangedIdToken, 'google-id-token');
    },
  );

  test('missing Google ID token never reaches Supabase exchange', () async {
    final authenticator = NativeGoogleAuthenticator(
      initialize: ({required serverClientId}) async {},
      authenticate: () async => const GoogleSignInAuthentication(idToken: null),
    );
    var exchangeCalls = 0;

    await expectLater(
      signInWithNativeGoogle(
        config: config(googleWebClientId: 'example.apps.googleusercontent.com'),
        authenticator: authenticator,
        exchangeIdToken: (_) async => exchangeCalls++,
      ),
      throwsA(isA<AppConfigException>()),
    );
    expect(exchangeCalls, 0);
  });
}
