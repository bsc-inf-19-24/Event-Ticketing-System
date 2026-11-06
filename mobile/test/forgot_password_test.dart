import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/storage/secure_storage.dart';
import 'package:mobile/features/auth/data/datasources/mock_auth_remote_datasource.dart';
import 'package:mobile/features/auth/data/presentation/provider/auth_provider.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/auth/domain/usecases/login_usecase.dart';
import 'package:mobile/features/auth/domain/usecases/password_reset_usecase.dart';
import 'package:mobile/features/auth/services/fake_auth_service.dart';
import 'package:mobile/screens/login_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('login recovery validates email and opens the code reset flow', (
    WidgetTester tester,
  ) async {
    final service = FakeAuthService(resetCodeGenerator: () => '123456');
    final repository = AuthRepositoryImpl(
      remoteDataSource: MockAuthRemoteDataSource(authService: service),
      secureStorage: SecureStorageService(),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(
          loginUseCase: LoginUseCase(repository: repository),
          passwordResetUseCase: PasswordResetUseCase(repository: repository),
        ),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Recover your account'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'unknown@example.com');
    await tester.tap(find.text('Send verification code'));
    await tester.pumpAndSettle();
    expect(
      find.text('No account was found for this email address.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextFormField), 'demo@ticketmaster.mw');
    await tester.tap(find.text('Send verification code'));
    await tester.pumpAndSettle();

    expect(find.text('Create a new password'), findsAtLeastNWidgets(1));
    expect(
      find.text(
        'Demo mode: no email is sent. Your verification code is 123456.',
      ),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextFormField).at(0), '123456');
    await tester.enterText(find.byType(TextFormField).at(1), 'ValidPass1!');
    await tester.enterText(find.byType(TextFormField).at(2), 'Different1!');
    await tester.ensureVisible(find.text('Save new password'));
    await tester.tap(find.text('Save new password'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match'), findsOneWidget);
  });
}
