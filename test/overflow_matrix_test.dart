// test/overflow_matrix_test.dart
//
// Automated Overflow Matrix Guard (Section 2):
// Pumps Home, History, Settings, Paywall, Onboarding, and QR card at:
// - Widths: 320 dp (small device), 360 dp (standard), 411 dp (large phone)
// - Text Scales: 1.0x, 1.3x, 1.6x, 2.0x (accessibility maximum)
// - Shop name: 40-character merchant name with symbols and numbers
// Asserts zero RenderFlex overflow exceptions across every frame.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myupi/screens/history_screen.dart';
import 'package:myupi/screens/home_screen.dart';
import 'package:myupi/screens/onboarding/step_shop_profile_screen.dart';
import 'package:myupi/screens/onboarding/welcome_screen.dart';
import 'package:myupi/screens/paywall_screen.dart';
import 'package:myupi/screens/settings_screen.dart';
import 'package:myupi/widgets/qr_code_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.myupi/notification_access');

  const testShopName = 'Ramesh Supermarket & General Kirana 1234';
  const testUpiId = 'rameshsupermarketkirana1234@okhdfcbank';

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'isNotificationAccessEnabled':
          return true;
        case 'isSoundboxEnabled':
          return true;
        case 'getMerchantName':
          return testShopName;
        case 'getIncludeShopName':
          return true;
        case 'getLanguage':
          return 'en-IN';
        case 'getSpeechSpeed':
          return 'normal';
        case 'getAnnouncementFormat':
          return 'A';
        case 'getPaymentHistory':
          return <dynamic>[
            {
              'amount': '1,250',
              'appName': 'PhonePe',
              'timestampMs': DateTime.now().millisecondsSinceEpoch,
            },
            {
              'amount': '1,00,000',
              'appName': 'Google Pay',
              'timestampMs': DateTime.now().millisecondsSinceEpoch - 3600000,
            },
          ];
        case 'getSubscriptionState':
          return 'ACTIVE';
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  final widths = [320.0, 360.0, 411.0];
  final textScales = [1.0, 1.3, 1.6, 2.0];

  Widget buildTestHost(Widget child, {required double width, required double textScale}) {
    return MediaQuery(
      data: MediaQueryData(
        size: Size(width, 800),
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: Material(child: child),
      ),
    );
  }

  group('Overflow Matrix Test Suite — Zero RenderFlex Overflow', () {
    for (final width in widths) {
      for (final textScale in textScales) {
        testWidgets('HomeScreen at ${width.toInt()}dp width × ${textScale}x text scale',
            (tester) async {
          tester.view.physicalSize = Size(width * 2, 800 * 2);
          tester.view.devicePixelRatio = 2.0;

          final oldOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            debugPrint('HOMESCREEN CAUSE: ${details.toDiagnosticsNode().toStringDeep()}');
            oldOnError?.call(details);
          };

          await tester.pumpWidget(
            buildTestHost(const HomeScreen(), width: width, textScale: textScale),
          );
          await tester.pumpAndSettle();
          FlutterError.onError = oldOnError;

          expect(tester.takeException(), isNull);
        });

        testWidgets('QrCodeCard at ${width.toInt()}dp width × ${textScale}x text scale',
            (tester) async {
          tester.view.physicalSize = Size(width * 2, 800 * 2);
          tester.view.devicePixelRatio = 2.0;

          await tester.pumpWidget(
            buildTestHost(
              SingleChildScrollView(
                child: QrCodeCard(
                  upiId: testUpiId,
                  merchantName: testShopName,
                  soundboxActive: true,
                ),
              ),
              width: width,
              textScale: textScale,
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        });

        testWidgets('SettingsScreen at ${width.toInt()}dp width × ${textScale}x text scale',
            (tester) async {
          tester.view.physicalSize = Size(width * 2, 800 * 2);
          tester.view.devicePixelRatio = 2.0;

          await tester.pumpWidget(
            buildTestHost(const SettingsScreen(), width: width, textScale: textScale),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        });

        testWidgets('HistoryScreen at ${width.toInt()}dp width × ${textScale}x text scale',
            (tester) async {
          tester.view.physicalSize = Size(width * 2, 800 * 2);
          tester.view.devicePixelRatio = 2.0;

          await tester.pumpWidget(
            buildTestHost(const HistoryScreen(), width: width, textScale: textScale),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        });

        testWidgets('PaywallScreen at ${width.toInt()}dp width × ${textScale}x text scale',
            (tester) async {
          tester.view.physicalSize = Size(width * 2, 800 * 2);
          tester.view.devicePixelRatio = 2.0;

          final oldOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            debugPrint('RENDERFLEX CAUSE: ${details.toDiagnosticsNode().toStringDeep()}');
            oldOnError?.call(details);
          };

          await tester.pumpWidget(
            buildTestHost(
              const PaywallScreen(sourceEntry: 'matrix_test'),
              width: width,
              textScale: textScale,
            ),
          );
          await tester.pumpAndSettle();
          FlutterError.onError = oldOnError;

          final ex = tester.takeException();
          if (ex != null) {
            if (ex is FlutterError) {
              debugPrint('PAYWALL DETAILS: ${ex.toStringDeep()}');
            } else {
              debugPrint('PAYWALL EXCEPTION: $ex');
            }
          }
          expect(ex, isNull);
        });

        testWidgets('WelcomeScreen at ${width.toInt()}dp width × ${textScale}x text scale',
            (tester) async {
          tester.view.physicalSize = Size(width * 2, 800 * 2);
          tester.view.devicePixelRatio = 2.0;

          await tester.pumpWidget(
            buildTestHost(
              WelcomeScreen(onGetStarted: () {}),
              width: width,
              textScale: textScale,
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        });

        testWidgets('StepShopProfileScreen at ${width.toInt()}dp width × ${textScale}x text scale',
            (tester) async {
          tester.view.physicalSize = Size(width * 2, 800 * 2);
          tester.view.devicePixelRatio = 2.0;

          await tester.pumpWidget(
            buildTestHost(
              StepShopProfileScreen(onContinue: () {}),
              width: width,
              textScale: textScale,
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
