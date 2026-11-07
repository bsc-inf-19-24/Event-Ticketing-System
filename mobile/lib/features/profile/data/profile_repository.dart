import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/storage/secure_storage.dart';

class ProfileRepository {
  ProfileRepository({ApiClient? apiClient, SecureStorageService? storage})
    : _apiClient = apiClient ?? ApiClient.instance,
      _storage = storage ?? SecureStorageService();

  final ApiClient _apiClient;
  final SecureStorageService _storage;

  Future<Map<String, dynamic>> fetchUserProfile() async {
    final response = await _apiClient.get('/api/customers/me');
    return _asMap(response);
  }

  Future<Map<String, dynamic>> updateUserProfile(
    Map<String, dynamic> changes,
  ) async {
    final response = await _apiClient.put('/api/customers/me', changes);
    return _asMap(response);
  }

  Future<void> logout() => _storage.clearTokens();

  Map<String, dynamic> _asMap(dynamic response) {
    if (response is! Map) {
      throw const ApiException('The server returned an invalid profile.');
    }
    final data = response['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return Map<String, dynamic>.from(response);
  }
}
