import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/home_screen.dart';

void main() {
  testWidgets('Home search filters events using partial input', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(onViewTickets: _onViewTickets)),
    );

    await tester.enterText(find.byType(TextField), 'za');
    await tester.pumpAndSettle();

    expect(find.text('ZaMusic Festival'), findsOneWidget);
    expect(find.text('Blantyre Football Cup'), findsNothing);
  });
}

void _onViewTickets() {}
