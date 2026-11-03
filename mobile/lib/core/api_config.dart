class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  static const useFakeAuth =
  bool.fromEnvironment('USE_FAKE_AUTH', defaultValue: true);
  static const useFakeEvents =
  bool.fromEnvironment('USE_FAKE_EVENTS', defaultValue: true);

  static Map<String, String> headers({String? token}) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}