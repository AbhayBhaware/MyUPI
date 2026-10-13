import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myupi/screens/shell_page.dart';

void main() {
  testWidgets('Debug SettingsScreen build inside ShellPage', (tester) async {
    FlutterErrorDetails? caughtDetails;
    FlutterError.onError = (details) {
      caughtDetails = details;
      debugPrint('SHELL BUILD ERROR: ${details.exception}');
      debugPrint('STACK: ${details.stack}');
    };

    await tester.pumpWidget(
      const MaterialApp(
        home: ShellPage(initialIndex: 0),
      ),
    );
    await tester.pump();

    // Tap Settings destination
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    if (caughtDetails != null) {
      fail('Caught error in ShellPage tab 2: ${caughtDetails!.exception}');
    }
  });
}
