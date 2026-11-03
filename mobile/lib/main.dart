import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/screens/main_shell.dart';

// Core imports
import 'core/storage/secure_storage.dart';

// Authentication feature imports (Corrected paths & using Mock Data Source)
import 'features/auth/data/datasources/mock_auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/usecases/login_usecase.dart';
import 'features/auth/data/presentation/provider/auth_provider.dart';
import 'features/auth/logic/auth_controller.dart';

void main() {
  // 1. Initialize core services and dependencies using the Mock Data Source
  final secureStorage = SecureStorageService();
  final mockRemoteDataSource = MockAuthRemoteDataSource(
    authService: fakeAuthService,
  );

  final authRepository = AuthRepositoryImpl(
    remoteDataSource: mockRemoteDataSource,
    secureStorage: secureStorage,
  );
  final loginUseCase = LoginUseCase(repository: authRepository);

  runApp(MyApp(loginUseCase: loginUseCase));
}

class MyApp extends StatelessWidget {
  final LoginUseCase loginUseCase;

  const MyApp({super.key, required this.loginUseCase});

  @override
  Widget build(BuildContext context) {
    // 2. Provide the AuthProvider globally using MultiProvider
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(loginUseCase: loginUseCase),
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
