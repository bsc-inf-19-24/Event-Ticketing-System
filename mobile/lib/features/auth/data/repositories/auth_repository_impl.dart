//implements repository interface
import '../../../../core/storage/secure_storage.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import 'package:mobile/features/auth/data/model/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final SecureStorageService secureStorage;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.secureStorage,
  });

  @override
  Future<UserModel> login(String email, String password) async {
    // 1. Authenticate against the backend
    final userModel = await remoteDataSource.login(email, password);

    // 2. Securely store the returned token
    if (userModel.token.isNotEmpty) {
      await secureStorage.saveToken(userModel.token);
    }

    return userModel;
  }
}