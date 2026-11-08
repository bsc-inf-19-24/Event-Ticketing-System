import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/api_config.dart';
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
import 'screens/main_shell.dart';

const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.load();
  await connectivityMonitor.start();

  final secureStorage = SecureStorageService();
  final apiClient = ApiClient.instance;
  final apiAuthService = ApiAuthService(apiClient: apiClient);
  final useFakeAuth = ApiConfig.useFakeAuth || _configuredApiBaseUrl.isEmpty;
  final AuthRemoteDataSource remoteDataSource = useFakeAuth
      ? MockAuthRemoteDataSource(authService: fakeAuthService)
      : AuthRemoteDataSourceImpl(apiClient: apiClient);

  apiClient.tokenProvider = secureStorage.getToken;
  if (!useFakeAuth) {
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

  final repository = AuthRepositoryImpl(
    remoteDataSource: remoteDataSource,
    secureStorage: secureStorage,
  );
  runApp(
    MyApp(
      loginUseCase: LoginUseCase(repository: repository),
      registerUseCase: RegisterUseCase(repository: repository),
      authRepository: repository,
      passwordResetUseCase: PasswordResetUseCase(repository: repository),
      restoreSessionOnLaunch: !useFakeAuth,
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
  final AuthRepository? authRepository;
  final PasswordResetUseCase passwordResetUseCase;
  final bool restoreSessionOnLaunch;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) {
      final provider = AuthProvider(
        loginUseCase: loginUseCase,
        registerUseCase: registerUseCase,
        authRepository: authRepository,
        passwordResetUseCase: passwordResetUseCase,
      );
      if (restoreSessionOnLaunch) unawaited(provider.restoreSession());
      return provider;
    },
    child: MaterialApp(
      title: 'Ticket Master',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
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
      home: const MainShell(),
    ),
  );
}
