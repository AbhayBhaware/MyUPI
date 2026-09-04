// test/widget_test.dart
//
// Smoke test — verifies MyUpiApp boots without crashing.
// Detailed UPI detection tests are in test/upi_detector_test.dart.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myupi/main.dart';

void main() {
  // Stub every MethodChannel call so the widget can initialise without a
  // real Android host.
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.myupi/notification_access');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'isNotificationAccessEnabled': return false;
        case 'isSoundboxEnabled':           return true;
        case 'getSpeechSpeed':              return 'normal';
        case 'getPaymentHistory':           return <dynamic>[];
        default:                            return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('MyUpiApp smoke test — renders without crash',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyUpiApp());
    await tester.pump(); // settle first frame

    // The bottom navigation bar must be visible.
    expect(find.text('Home'),     findsOneWidget);
    expect(find.text('History'),  findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
