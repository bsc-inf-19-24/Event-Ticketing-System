//calls POST /auth/login
import '../../../../core/network/api_client.dart';
import 'package:mobile/features/auth/data/model/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login(String email, String password);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient apiClient;

  AuthRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<UserModel> login(String email, String password) async {
    // Calls POST /auth/login with the credentials
    final responseData = await apiClient.post('/auth/login', {
      'email': email.trim(),
      'password': password,
    });

    return UserModel.fromJson(responseData);
  }
}