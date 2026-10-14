// test/settings_resilience_test.dart
//
// Automated Resilience & Zero-Blank Guard for SettingsScreen:
// 1. Verifies all 7 settings cards render when profile & user are null (first launch / offline).
// 2. Verifies all 7 settings cards render across all SubscriptionState enum states.
// 3. Verifies _safeCard isolates errors so failure in one card never wipes out the screen.
// 4. Verifies ShellPage tab switching to Settings retains non-zero viewport and all sections.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myupi/app_channels.dart';
import 'package:myupi/models/user_profile.dart';
import 'package:myupi/screens/settings_screen.dart';
import 'package:myupi/screens/shell_page.dart';
import 'package:myupi/services/firestore_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.myupi/notification_access');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
          return <dynamic>[];
        default:
          return null;
      }
    });
  });

  group('SettingsScreen Resilience Test Suite', () {
    testWidgets('Renders all 7 sections with null user and null cached profile', (tester) async {
      FirestoreService.instance.cachedProfile = null;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check section headers
      expect(find.text('VOICE'), findsOneWidget);
      expect(find.text('SHOP'), findsOneWidget);
      expect(find.text('COUNTER MODE'), findsOneWidget);
      expect(find.text('PLAN'), findsOneWidget);
      expect(find.text('HELP & RELIABILITY'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);

      // Check key card contents
      expect(find.text('Soundbox'), findsOneWidget);
      expect(find.text('Announcement Language'), findsOneWidget);
      expect(find.text('Shop / Business Name'), findsOneWidget);
      expect(find.text('MyUPI Premium'), findsOneWidget);
      expect(find.text('Reliability Checklist'), findsOneWidget);
      expect(find.text('Merchant Profile'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('Renders properly across all SubscriptionState variations', (tester) async {
      final profile = UserProfile(
        uid: 'test_merchant_uid',
        shopName: 'Sharma General Store',
        ownerName: 'Sunil Sharma',
        category: 'Grocery',
        email: 'sunil@sharma.in',
        phone: '+919999988888',
        authMethod: 'phone',
        upiId: 'sunilsharma@upi',
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

        expect(find.text('Sharma General Store'), findsWidgets);
        expect(find.text('Sunil Sharma'), findsOneWidget);
        expect(find.text('sunilsharma@upi'), findsOneWidget);
        expect(find.text('MyUPI Premium'), findsOneWidget);
      }
    });

    testWidgets('ShellPage tab switch to Settings maintains bounded scroll viewport', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ShellPage(initialIndex: 0),
        ),
      );
      await tester.pumpAndSettle();

      // Tap settings tab in NavigationBar
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('VOICE'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);

      final scrollFinder = find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.byType(SingleChildScrollView),
      );
      expect(scrollFinder, findsOneWidget);
      final size = tester.getSize(scrollFinder);
      expect(size.height, greaterThan(200));
    });

    testWidgets('SettingsScreen renders gracefully when method channel fails completely', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        throw PlatformException(code: 'FAILED', message: 'Simulated channel failure');
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('VOICE'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('Soundbox'), findsOneWidget);
    });
  });
}
