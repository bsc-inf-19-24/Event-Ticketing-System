import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/screens/main_shell.dart';

import 'core/api_config.dart';
import 'core/network/api_client.dart';
import 'core/storage/secure_storage.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/datasources/mock_auth_remote_datasource.dart';
import 'features/auth/data/presentation/provider/auth_provider.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/login_usecase.dart';
import 'features/auth/domain/usecases/password_reset_usecase.dart';
import 'features/auth/domain/usecases/register_usecase.dart';
import 'features/auth/logic/auth_controller.dart';
import 'features/tickets/logic/connectivity_monitor.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.load();
  await connectivityMonitor.start();

  final secureStorage = SecureStorageService();
  final apiClient = ApiClient.instance;
  final apiAuthService = ApiAuthService(apiClient: apiClient);
  apiClient.tokenProvider = secureStorage.getToken;

  final AuthRemoteDataSource remoteDataSource = ApiConfig.useFakeAuth
      ? MockAuthRemoteDataSource()
      : apiAuthService;

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
      passwordResetUseCase: passwordResetUseCase,
      authRepository: authRepository,
      restoreSessionOnLaunch: !ApiConfig.useFakeAuth,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.loginUseCase,
    required this.passwordResetUseCase,
    this.registerUseCase,
    this.authRepository,
    this.restoreSessionOnLaunch = false,
  });

  final LoginUseCase loginUseCase;
  final RegisterUseCase? registerUseCase;
  final PasswordResetUseCase passwordResetUseCase;
  final AuthRepository? authRepository;
  final bool restoreSessionOnLaunch;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final authProvider = AuthProvider(
              loginUseCase: loginUseCase,
              registerUseCase: registerUseCase,
              passwordResetUseCase: passwordResetUseCase,
              authRepository: authRepository,
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
        home: const MainShell(),
      ),
    );
  }
}
