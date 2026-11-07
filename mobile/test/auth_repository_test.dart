import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/storage/secure_storage.dart';
import 'package:mobile/features/auth/data/datasources/mock_auth_remote_datasource.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/auth/services/fake_auth_service.dart';

class _MemorySecureStorage extends SecureStorageService {
  String? accessToken;
  String? refreshToken;

  @override
  Future<String?> getToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clearTokens() async {
    accessToken = null;
    refreshToken = null;
  }
}

void main() {
  test(
    'login persists tokens, restores the profile, and logout clears tokens',
    () async {
      final storage = _MemorySecureStorage();
      final repository = AuthRepositoryImpl(
        remoteDataSource: MockAuthRemoteDataSource(
          authService: FakeAuthService(),
        ),
        secureStorage: storage,
      );

      final signedIn = await repository.login(
        'demo@ticketmaster.mw',
        'demo1234',
      );
      final restored = await repository.restoreSession();

      expect(storage.accessToken, signedIn.token);
      expect(storage.refreshToken, signedIn.refreshToken);
      expect(restored?.email, signedIn.email);

      await repository.logout();

      expect(storage.accessToken, isNull);
      expect(storage.refreshToken, isNull);
    },
  );
}
