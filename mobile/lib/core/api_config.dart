import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );
  static const _baseUrlKey = 'api_base_url';
  static String _baseUrl = _defaultBaseUrl;

  static String get baseUrl => _baseUrl;

  static const useFakeAuth = bool.fromEnvironment(
    'USE_FAKE_AUTH',
    defaultValue: false,
  );

  static Map<String, String> headers({String? token}) => {
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _baseUrl = preferences.getString(_baseUrlKey) ?? _defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String value) async {
    final normalized = value.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException(
        'Enter a valid server URL beginning with http:// or https://.',
      );
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_baseUrlKey, normalized);
    _baseUrl = normalized;
  }

  static Future<void> resetBaseUrl() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_baseUrlKey);
    _baseUrl = _defaultBaseUrl;
  }
}
