import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/logic/auth_controller.dart';
import 'package:mobile/features/auth/models/app_user.dart';
import 'package:mobile/features/profile/ui/profile_screen.dart';

void main() {
  testWidgets('profile immediately shows restored name and email offline', (
    tester,
  ) async {
    authController.setAuthenticatedUser(
      const AppUser(
        id: 'cached-customer',
        name: 'Offline Customer',
        email: 'offline@example.com',
        role: 'CUSTOMER',
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pump();

    expect(find.text('Offline Customer'), findsOneWidget);
    expect(find.text('offline@example.com'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    authController.logOut();
  });
}
