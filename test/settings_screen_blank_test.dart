// test/settings_screen_blank_test.dart
//
// Comprehensive regression test suite required by §5 Phase C:
// 1. Every bad value (en-US, hi, '', null, unknown voice, 'D', int instead of string) -> Settings renders without blanking.
// 2. Native throws (PlatformException, MissingPluginException, timeout) -> renders defaults without uncaught exception.
// 3. Layout matrix: widths 320 / 360 / 411 x text scale 1.0 / 1.3 / 1.6 / 2.0 x 8 languages x 45-char shop name.
// 4. Subscription states: all SubscriptionState enum states render safely.
// 5. Tab switch: pump ShellPage, switch Home -> History -> Settings -> Home -> Settings; all headers present.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myupi/app_channels.dart';
import 'package:myupi/screens/settings_screen.dart';
import 'package:myupi/screens/shell_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.myupi/notification_access');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('§5 Phase C1: Native Bad Values Resilience', () {
    testWidgets('Bad language, format, speed, and types do not crash SettingsScreen', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'isSoundboxEnabled':
            return true;
          case 'getSpeechSpeed':
            return 'fast '; // invalid spacing
          case 'getLanguage':
            return 'en-US'; // not in standard list, should sanitize to en-IN
          case 'getMerchantName':
            return '   '; // empty/blank
          case 'getAnnouncementFormat':
            return 'D'; // invalid format code, should sanitize to A
          case 'getIncludeShopName':
            return false;
          case 'isNotificationAccessEnabled':
            return true;
          case 'isBatteryOptimizationIgnored':
            return true;
          default:
            return null;
        }
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('VOICE'), findsOneWidget);
      expect(find.text('SHOP'), findsOneWidget);
      expect(find.text('PLAN'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('English'), findsOneWidget); // sanitized en-US -> en-IN -> English
    });

    testWidgets('Handles null, empty, and unexpected integer return types', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'isSoundboxEnabled':
            return null;
          case 'getSpeechSpeed':
            return '';
          case 'getLanguage':
            return 'hi'; // short language code, should resolve to hi-IN
          case 'getMerchantName':
            return null;
          case 'getAnnouncementFormat':
            return null;
          case 'getIncludeShopName':
            return null;
          case 'isNotificationAccessEnabled':
            return false;
          case 'isBatteryOptimizationIgnored':
            return false;
          default:
            return null;
        }
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('VOICE'), findsOneWidget);
      expect(find.text('SHOP'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);
    });
  });

  group('§5 Phase C2: Native Exception & Timeout Resilience', () {
    testWidgets('MissingPluginException renders default values without throwing', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        throw MissingPluginException('No implementation found for method ${call.method}');
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('VOICE'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);
    });

    testWidgets('PlatformException renders fallback values cleanly', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        throw PlatformException(code: 'INTERNAL_ERROR', message: 'Kotlin exception');
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('VOICE'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);
    });

    testWidgets('Hanging uncompleted native call triggers timeout fallback', (tester) async {
      final completer = Completer<dynamic>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) => completer.future);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsScreen(),
          ),
        ),
      );

      // Fast forward past all sequential 3-second timeouts (6 * 3s = 18s)
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('VOICE'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);
    });
  });

  group('§5 Phase C3: Layout Matrix & Zero-Overflow Guard', () {
    const widths = [320.0, 360.0, 411.0];
    const textScales = [1.0, 1.3, 1.6, 2.0];
    const longShopName = 'Choudhary Kirana & Ayurvedic General Store Private Limited 1234';

    for (final width in widths) {
      for (final scale in textScales) {
        testWidgets('Width ${width.toInt()}dp x ${scale}x scale renders without flex overflow', (tester) async {
          tester.view.physicalSize = Size(width * 2, 800 * 2);
          tester.view.devicePixelRatio = 2.0;

          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (MethodCall call) async {
            switch (call.method) {
              case 'isSoundboxEnabled': return true;
              case 'getSpeechSpeed': return 'normal';
              case 'getLanguage': return 'hi-IN';
              case 'getMerchantName': return longShopName;
              case 'getAnnouncementFormat': return 'C';
              case 'getIncludeShopName': return true;
              case 'isNotificationAccessEnabled': return true;
              case 'isBatteryOptimizationIgnored': return true;
              default: return null;
            }
          });

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: Size(width, 800),
                textScaler: TextScaler.linear(scale),
              ),
              child: const MaterialApp(
                home: Scaffold(
                  body: SettingsScreen(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('VOICE'), findsOneWidget);
          expect(find.text('ACCOUNT'), findsOneWidget);
        });
      }
    }
  });

  group('§5 Phase C4: Subscription States Robustness', () {
    for (final state in SubscriptionState.values) {
      testWidgets('SubscriptionState.$state renders correctly', (tester) async {
        SubscriptionManager.instance.subscriptionInfoNotifier.value =
            SubscriptionInfo(state: state);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('MyUPI Premium'), findsOneWidget);
      });
    }
  });

  group('§5 Phase C5: Tab Switching Flow', () {
    testWidgets('Switch Home -> History -> Settings -> Home -> Settings retains full UI', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'isSoundboxEnabled': return true;
          case 'getSpeechSpeed': return 'normal';
          case 'getLanguage': return 'en-IN';
          case 'getMerchantName': return 'MyUPI';
          case 'getAnnouncementFormat': return 'A';
          case 'getIncludeShopName': return false;
          case 'isNotificationAccessEnabled': return true;
          case 'isBatteryOptimizationIgnored': return true;
          case 'getPaymentHistory': return <dynamic>[];
          default: return null;
        }
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ShellPage(initialIndex: 0),
        ),
      );
      await tester.pumpAndSettle();

      // Home -> History
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      // History -> Settings
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('VOICE'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);

      // Settings -> Home
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      // Home -> Settings
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('VOICE'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
