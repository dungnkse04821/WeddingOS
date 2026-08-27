import 'dart:convert';

class AppConfigException implements Exception {
  const AppConfigException(this.message);

  final String message;
}

class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.supabaseAnonKey});

  final String supabaseUrl;
  final String supabaseAnonKey;

  factory AppConfig.fromEnvironment({
    String supabaseUrl = const String.fromEnvironment('SUPABASE_URL'),
    String supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY'),
  }) {
    final url = supabaseUrl.trim();
    final key = supabaseAnonKey.trim();
    final uri = Uri.tryParse(url);

    if (url.isEmpty) {
      throw const AppConfigException('Thiếu cấu hình SUPABASE_URL.');
    }
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const AppConfigException('SUPABASE_URL không hợp lệ.');
    }
    if (key.length < 20 || _isServiceRoleKey(key)) {
      throw const AppConfigException('Thiếu hoặc sai SUPABASE_ANON_KEY.');
    }

    return AppConfig(supabaseUrl: url, supabaseAnonKey: key);
  }

  static bool _isServiceRoleKey(String key) {
    final parts = key.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final claims = jsonDecode(payload) as Map<String, dynamic>;
      return claims['role'] == 'service_role';
    } catch (_) {
      return false;
    }
  }
}
