import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myupi/screens/shell_page.dart';
import 'package:myupi/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.myupi/notification_access');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'isSoundboxEnabled':
          return true;
        case 'getSpeechSpeed':
          return 'normal';
        case 'getLanguage':
          return 'en-IN';
        case 'getMerchantName':
          return 'MyUPI';
        case 'getAnnouncementFormat':
          return 'A';
        case 'getIncludeShopName':
          return false;
        case 'isNotificationAccessEnabled':
          return true;
        case 'isBatteryOptimizationIgnored':
          return true;
        case 'getPaymentHistory':
          return [];
        default:
          return null;
      }
    });
  });

  testWidgets('ShellPage tab switch to Settings and inspect layout', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ShellPage(initialIndex: 0),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Settings tab (destination 2)
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);

    final settingsTexts = tester.widgetList<Text>(
      find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.byType(Text),
      ),
    );
    expect(settingsTexts.length, greaterThanOrEqualTo(10));

    final scrollViewFinder = find.descendant(
      of: find.byType(SettingsScreen),
      matching: find.byType(SingleChildScrollView),
    );
    expect(scrollViewFinder, findsOneWidget);
    final scrollSize = tester.getSize(scrollViewFinder);
    expect(scrollSize.height, greaterThan(0));
  });
}
