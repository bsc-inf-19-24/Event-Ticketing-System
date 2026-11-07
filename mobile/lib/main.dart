import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/screens/main_shell.dart';

// Core imports
import 'core/api_config.dart';
import 'core/network/api_client.dart';
import 'core/storage/secure_storage.dart';
import 'features/tickets/logic/connectivity_monitor.dart';

// Authentication feature imports
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/datasources/mock_auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/usecases/login_usecase.dart';
import 'features/auth/domain/usecases/password_reset_usecase.dart';
import 'features/auth/data/presentation/provider/auth_provider.dart';
import 'features/auth/logic/auth_controller.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/register_usecase.dart';

const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await connectivityMonitor.start();
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.load();
  final secureStorage = SecureStorageService();
  final apiClient = ApiClient.instance;
  final apiAuthService = ApiAuthService(apiClient: apiClient);
  final AuthRemoteDataSource remoteDataSource = ApiConfig.useFakeAuth
      ? MockAuthRemoteDataSource(authService: fakeAuthService)
      : AuthRemoteDataSourceImpl(
          apiClient: ApiClient(
            baseUrl: apiBaseUrl.replaceFirst(RegExp(r'/+$'), ''),
          ),
        );
      : apiAuthService;

  apiClient.tokenProvider = secureStorage.getToken;
  if (!ApiConfig.useFakeAuth) {
    apiClient.tokenRefresher = () async {
      final refreshToken = await secureStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return null;

      final tokens = await apiAuthService.refreshTokens(refreshToken);
      await secureStorage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      return tokens.accessToken;
    };
    apiClient.onUnauthorized = () async {
      await secureStorage.clearTokens();
      authController.logOut();
    };
  }

  final authRepository = AuthRepositoryImpl(
    remoteDataSource: remoteDataSource,
    secureStorage: secureStorage,
  );
  final loginUseCase = LoginUseCase(repository: authRepository);
  final registerUseCase = RegisterUseCase(repository: authRepository);
  final passwordResetUseCase = PasswordResetUseCase(repository: authRepository);

  runApp(
    MyApp(
      loginUseCase: loginUseCase,
      registerUseCase: registerUseCase,
      authRepository: authRepository,
      passwordResetUseCase: passwordResetUseCase,
      restoreSessionOnLaunch: !ApiConfig.useFakeAuth,
    ),
  );
}

class MyApp extends StatelessWidget {
  final LoginUseCase loginUseCase;
  final RegisterUseCase? registerUseCase;
  final AuthRepository? authRepository;
  final PasswordResetUseCase passwordResetUseCase;
  final bool restoreSessionOnLaunch;

  const MyApp({
    super.key,
    required this.loginUseCase,
    required this.passwordResetUseCase,
    this.registerUseCase,
    this.authRepository,
    this.restoreSessionOnLaunch = false,
  });

  @override
  Widget build(BuildContext context) {
    // 2. Provide the AuthProvider globally using MultiProvider
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final authProvider = AuthProvider(
              loginUseCase: loginUseCase,
              registerUseCase:
                  registerUseCase ??
                  RegisterUseCase(repository: loginUseCase.repository),
              passwordResetUseCase: passwordResetUseCase,
              authRepository: authRepository ?? loginUseCase.repository,
            );
            if (restoreSessionOnLaunch) {
              unawaited(authProvider.restoreSession());
            }
            return authProvider;
          },
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
