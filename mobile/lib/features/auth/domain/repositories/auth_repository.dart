//abstract repository contract
import 'package:mobile/features/auth/data/model/user_model.dart';

abstract class AuthRepository {
  Future<UserModel> login(String email, String password);
}