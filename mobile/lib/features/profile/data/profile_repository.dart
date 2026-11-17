import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/storage/secure_storage.dart';
import 'package:mobile/features/auth/logic/auth_controller.dart';
import 'package:mobile/features/auth/models/app_user.dart';

class ProfileRepository {
  ProfileRepository({ApiClient? apiClient, SecureStorageService? storage})
    : _apiClient = apiClient ?? ApiClient.instance,
      _storage = storage ?? SecureStorageService();

  final ApiClient _apiClient;
  final SecureStorageService _storage;

  Future<Map<String, dynamic>> fetchUserProfile() async {
    final requestingUserId = authController.stableUserId;
    final response = await _apiClient.get('/api/customers/me');
    final profile = _asMap(response);
    final nested = profile['user'] ?? profile['customer'] ?? profile['profile'];
    final data = nested is Map ? Map<String, dynamic>.from(nested) : profile;
    final current = authController.user;
    if (current != null && requestingUserId == authController.stableUserId) {
      final email = (data['email'] ?? current.email).toString();
      final name =
          (data['name'] ??
                  data['fullName'] ??
                  data['full_name'] ??
                  current.name)
              .toString();
      final updated = AppUser(
        id: current.id,
        name: name,
        email: email,
        role: current.role,
      );
      await _storage.saveUser(updated);
      authController.setAuthenticatedUser(updated);
    }
    return data;
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
