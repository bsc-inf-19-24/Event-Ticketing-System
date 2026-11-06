import 'package:mobile/features/auth/data/model/user_model.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';

class RegisterUseCase {
  const RegisterUseCase({required this.repository});

  final AuthRepository repository;

  Future<UserModel> execute({
    required String name,
    required String email,
    required String password,
    required String role,
  }) {
    return repository.register(
      name: name,
      email: email,
      password: password,
      role: role,
    );
  }
}
