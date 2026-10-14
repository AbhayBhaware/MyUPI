import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myupi/app_channels.dart';
import 'package:myupi/models/user_profile.dart';
import 'package:myupi/screens/settings_screen.dart';
import 'package:myupi/services/firestore_service.dart';

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
          return 'hi-IN';
        case 'getMerchantName':
          return 'Abhay Kirana';
        case 'getAnnouncementFormat':
          return 'C';
        case 'getIncludeShopName':
          return true;
        case 'isNotificationAccessEnabled':
          return true;
        case 'isBatteryOptimizationIgnored':
          return true;
        default:
          return null;
      }
    });
  });

  testWidgets('Test SettingsScreen with full mock data', (tester) async {
    final List<String> errors = [];
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details.toString());
      debugPrint('SETTINGS TEST ERROR: ${details.exception}');
    };

    final profile = UserProfile(
      uid: 'test_user',
      shopName: 'Abhay Kirana Store',
      ownerName: 'Abhay',
      category: 'Grocery',
      email: 'abhay@example.com',
      phone: '+919876543210',
      authMethod: 'phone',
      upiId: 'abhay@upi',
      setupComplete: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    FirestoreService.instance.cachedProfile = profile;

    for (final state in SubscriptionState.values) {
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

      expect(errors, isEmpty, reason: 'Errors found: ${errors.join("; ")}');
    }
    FlutterError.onError = oldOnError;
  });
}
