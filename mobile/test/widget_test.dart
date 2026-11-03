// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/storage/secure_storage.dart';
import 'package:mobile/features/auth/data/datasources/mock_auth_remote_datasource.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/auth/domain/usecases/login_usecase.dart';
import 'package:mobile/features/auth/logic/auth_controller.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('Guests can browse the ticket and profile tabs', (
    WidgetTester tester,
  ) async {
    authController.logOut();

    final secureStorage = SecureStorageService();
    final mockRemoteDataSource = MockAuthRemoteDataSource();
    final authRepository = AuthRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      secureStorage: secureStorage,
    );
    final loginUseCase = LoginUseCase(repository: authRepository);

    await tester.pumpWidget(MyApp(loginUseCase: loginUseCase));

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.selectedIndex, 0);
    expect(navigationBar.destinations, hasLength(3));

    await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
    await tester.pump();
    expect(find.text('My Tickets'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pump();
    expect(find.text('Log in to view profile'), findsNothing);
    expect(find.text('Settings'), findsOneWidget);
  });
}
