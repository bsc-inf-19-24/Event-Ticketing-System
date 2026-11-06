import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/screens/main_shell.dart';

// Core imports
import 'core/network/api_client.dart';
import 'core/storage/secure_storage.dart';

// Authentication feature imports
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/datasources/mock_auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/usecases/login_usecase.dart';
import 'features/auth/domain/usecases/password_reset_usecase.dart';
import 'features/auth/data/presentation/provider/auth_provider.dart';
import 'features/auth/logic/auth_controller.dart';

const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

void main() {
  final secureStorage = SecureStorageService();
  final remoteDataSource = apiBaseUrl.isEmpty
      ? MockAuthRemoteDataSource(authService: fakeAuthService)
      : AuthRemoteDataSourceImpl(
          apiClient: ApiClient(
            baseUrl: apiBaseUrl.replaceFirst(RegExp(r'/+$'), ''),
          ),
        );

  final authRepository = AuthRepositoryImpl(
    remoteDataSource: remoteDataSource,
    secureStorage: secureStorage,
  );
  final loginUseCase = LoginUseCase(repository: authRepository);
  final passwordResetUseCase = PasswordResetUseCase(repository: authRepository);

  runApp(
    MyApp(
      loginUseCase: loginUseCase,
      passwordResetUseCase: passwordResetUseCase,
    ),
  );
}

class MyApp extends StatelessWidget {
  final LoginUseCase loginUseCase;
  final PasswordResetUseCase passwordResetUseCase;

  const MyApp({
    super.key,
    required this.loginUseCase,
    required this.passwordResetUseCase,
  });

  @override
  Widget build(BuildContext context) {
    // 2. Provide the AuthProvider globally using MultiProvider
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            loginUseCase: loginUseCase,
            passwordResetUseCase: passwordResetUseCase,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Ticket Master',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
        ),
        // 3. Start on the login screen
        home: const MainShell(),
      ),
    );
  }
}
