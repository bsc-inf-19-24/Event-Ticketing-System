//business logic for login
import 'package:mobile/features/auth/data/model/user_model.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase({required this.repository});

  Future<UserModel> execute(String email, String password) async {
    return await repository.login(email, password);
  }
}