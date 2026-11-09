import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_config.dart';
import 'package:mobile/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiConfig.resetBaseUrl();
  });

  testWidgets('saving server URL closes the settings dialog safely', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    await tester.tap(find.text('Server connection').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'http://10.0.2.2:8080');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(ApiConfig.baseUrl, 'http://10.0.2.2:8080');
    expect(find.text('Server URL saved.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
