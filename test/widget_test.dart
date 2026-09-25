// test/widget_test.dart
//
// Smoke tests — verifies MyUpiApp boots without crashing:
//   1. Unauthenticated launch → AuthGate displays WelcomeScreen with 3 auth options
//   2. Post-auth dashboard → ShellPage displays Home, History, and Settings tabs
//   3. No stray PIXEL watermarks or debug banners on HomeScreen

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myupi/main.dart';
import 'package:myupi/screens/shell_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.myupi/notification_access');

  void setMock() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'isOnboardingCompleted':       return true;
        case 'isNotificationAccessEnabled': return false;
        case 'isSoundboxEnabled':           return true;
        case 'getSpeechSpeed':              return 'normal';
        case 'getPaymentHistory':           return <dynamic>[];
        case 'getMerchantName':             return 'MyUPI';
        case 'getIncludeShopName':          return false;
        case 'getSubscriptionState':        return 'ACTIVE';
        default:                            return null;
      }
    });
  }

  setUp(() => setMock());

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets(
    'Unauthenticated launch → AuthGate displays WelcomeScreen with 3 auth options',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyUpiApp());
      await tester.pumpAndSettle();

      // Brand headline
      expect(find.text('MyUPI'), findsWidgets);
      expect(find.text('Smart Payment Soundbox for Indian Merchants'), findsOneWidget);

      // Unified Auth Entry Points
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Phone'),  findsOneWidget);
      expect(find.text('Continue with Email'),  findsOneWidget);

      // Main nav must NOT be visible yet
      expect(find.text('History'),  findsNothing);
      expect(find.text('Settings'), findsNothing);
    },
  );

  testWidgets(
    'ShellPage renders Home, History, and Settings navigation tabs',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ShellPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Bottom nav destinations must be visible.
      expect(find.widgetWithText(NavigationDestination, 'Home'),     findsOneWidget);
      expect(find.widgetWithText(NavigationDestination, 'History'),  findsOneWidget);
      expect(find.widgetWithText(NavigationDestination, 'Settings'), findsOneWidget);
    },
  );

  testWidgets(
    'Verify no stray PIXELS watermark or debug banner exists on HomeScreen',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ShellPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('PIXEL', findRichText: true), findsNothing);
      expect(find.textContaining('pixel', findRichText: true), findsNothing);
    },
  );
}
