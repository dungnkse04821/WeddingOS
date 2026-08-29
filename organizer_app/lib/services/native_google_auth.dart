import 'package:google_sign_in/google_sign_in.dart';

import '../foundation/app_config.dart';

typedef GoogleIdTokenExchange = Future<void> Function(String idToken);
typedef GoogleInitialize = Future<void> Function({
  required String serverClientId,
});
typedef GoogleAuthenticate = Future<GoogleSignInAuthentication> Function();

class NativeGoogleAuthenticator {
  NativeGoogleAuthenticator({
    required this._initialize,
    required this._authenticate,
  });

  static final instance = NativeGoogleAuthenticator(
    initialize: ({required String serverClientId}) =>
        GoogleSignIn.instance.initialize(serverClientId: serverClientId),
    authenticate: () async =>
        (await GoogleSignIn.instance.authenticate()).authentication,
  );

  final GoogleInitialize _initialize;
  final GoogleAuthenticate _authenticate;
  String? _initializedServerClientId;

  Future<String> authenticate({required String serverClientId}) async {
    if (_initializedServerClientId != serverClientId) {
      await _initialize(serverClientId: serverClientId);
      _initializedServerClientId = serverClientId;
    }

    final idToken = (await _authenticate()).idToken;
    if (idToken == null || idToken.trim().isEmpty) {
      throw const AppConfigException(
        'Không thể lấy thông tin đăng nhập Google.',
      );
    }
    return idToken;
  }
}

/// Exchanges only the ID token exposed by google_sign_in 7.2.0.
Future<void> signInWithNativeGoogle({
  required AppConfig config,
  required NativeGoogleAuthenticator authenticator,
  required GoogleIdTokenExchange exchangeIdToken,
}) async {
  final idToken = await authenticator.authenticate(
    serverClientId: config.requireGoogleWebClientId(),
  );
  await exchangeIdToken(idToken);
}
