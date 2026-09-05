// test/widget_test.dart
//
// Smoke tests — verifies MyUpiApp boots without crashing in two states:
//   1. Onboarding complete  → main navigation shell is shown
//   2. Onboarding not done  → Welcome screen is shown
//
// Detailed UPI detection tests are in test/upi_detector_test.dart.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myupi/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.myupi/notification_access');

  // Helper to register a mock handler with a configurable onboarding flag.
  void setMock({required bool onboardingDone}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'isOnboardingCompleted':       return onboardingDone;
        case 'isNotificationAccessEnabled': return false;
        case 'isSoundboxEnabled':           return true;
        case 'getSpeechSpeed':              return 'normal';
        case 'getPaymentHistory':           return <dynamic>[];
        default:                            return null;
      }
    });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets(
    'Onboarding DONE → main navigation shell is shown',
    (WidgetTester tester) async {
      setMock(onboardingDone: true);

      await tester.pumpWidget(const MyUpiApp());
      // Allow the async isOnboardingCompleted call to complete.
      await tester.pumpAndSettle();

      // Bottom nav destinations must be visible.
      expect(find.text('Home'),     findsOneWidget);
      expect(find.text('History'),  findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    },
  );

  testWidgets(
    'Onboarding NOT done → Welcome screen is shown',
    (WidgetTester tester) async {
      setMock(onboardingDone: false);

      await tester.pumpWidget(const MyUpiApp());
      await tester.pumpAndSettle();

      // Welcome screen headline.
      expect(find.text('MyUPI'),         findsWidgets);
      expect(find.text('Get Started'),   findsOneWidget);

      // Main nav must NOT be visible yet.
      expect(find.text('History'),  findsNothing);
      expect(find.text('Settings'), findsNothing);
    },
  );
}
