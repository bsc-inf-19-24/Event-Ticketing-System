// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/auth/logic/auth_controller.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('Main shell updates ticket and profile tabs after auth changes', (
    WidgetTester tester,
  ) async {
    authController.logOut();
    await tester.pumpWidget(const MyApp());

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.selectedIndex, 0);
    expect(navigationBar.destinations, hasLength(3));

    await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
    await tester.pump();
    expect(find.text('Log in to see your tickets'), findsOneWidget);

    await tester.runAsync(
      () => authController.logIn('demo@ticketmaster.mw', 'demo1234'),
    );
    await tester.pump();
    expect(find.text('Log in to see your tickets'), findsNothing);
    expect(find.text('My Tickets'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pump();
    expect(find.text('Log in to view profile'), findsNothing);

    authController.logOut();
    await tester.pump();
    expect(find.text('Log in to view profile'), findsOneWidget);
  });
}
