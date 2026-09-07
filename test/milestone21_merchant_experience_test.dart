// test/milestone21_merchant_experience_test.dart
//
// Comprehensive Automated Tests for Milestone 21:
// - 6-Step Merchant Onboarding flow (Welcome -> Notif -> Setup -> Shop -> Test -> Ready)
// - Shop Profile persistence (setMerchantName / setIncludeShopName)
// - Soundbox Test interactive verification (speakTest)
// - Settings Screen reorganization (SOUNDBOX, SUBSCRIPTION, APP)
// - Removal of Developer Diagnostics from merchant view
// - Help & Support Screen (8 merchant FAQ topics)
// - About Screen (Version, Privacy, Terms, and 7-Tap Developer Unlock)
// - Dashboard Status and merchant greeting

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myupi/screens/about_screen.dart';
import 'package:myupi/screens/diagnostics_screen.dart';
import 'package:myupi/screens/help_support_screen.dart';
import 'package:myupi/screens/home_screen.dart';
import 'package:myupi/screens/onboarding/step_notif_screen.dart';
import 'package:myupi/screens/onboarding/step_ready_screen.dart';
import 'package:myupi/screens/onboarding/step_shop_profile_screen.dart';
import 'package:myupi/screens/onboarding/step_sound_screen.dart';
import 'package:myupi/screens/onboarding/step_test_sound_screen.dart';
import 'package:myupi/screens/onboarding/welcome_screen.dart';
import 'package:myupi/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.myupi/notification_access');

  // Track method invocations during test
  final List<MethodCall> methodCalls = [];
  String currentMerchantName = 'Abhay General Store';
  bool currentSoundboxEnabled = true;
  bool currentNotifAccess = true;
  bool currentIncludeShopName = true;
  String currentLanguage = 'en-IN';
  String currentSpeed = 'normal';
  String currentFormat = 'A';

  setUp(() {
    methodCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      methodCalls.add(call);
      switch (call.method) {
        case 'isNotificationAccessEnabled':
          return currentNotifAccess;
        case 'isSoundboxEnabled':
          return currentSoundboxEnabled;
        case 'setSoundboxEnabled':
          currentSoundboxEnabled = call.arguments['enabled'] as bool;
          return null;
        case 'getMerchantName':
          return currentMerchantName;
        case 'setMerchantName':
          currentMerchantName = call.arguments['name'] as String;
          return null;
        case 'getIncludeShopName':
          return currentIncludeShopName;
        case 'setIncludeShopName':
          currentIncludeShopName = call.arguments['enabled'] as bool;
          return null;
        case 'getLanguage':
          return currentLanguage;
        case 'setLanguage':
          currentLanguage = call.arguments['language'] as String;
          return null;
        case 'checkLanguageAvailability':
          return true;
        case 'getSpeechSpeed':
          return currentSpeed;
        case 'setSpeechSpeed':
          currentSpeed = call.arguments['speed'] as String;
          return null;
        case 'getAnnouncementFormat':
          return currentFormat;
        case 'setAnnouncementFormat':
          currentFormat = call.arguments['format'] as String;
          return null;
        case 'speakTest':
          return null;
        case 'setOnboardingCompleted':
          return null;
        case 'getPaymentHistory':
          return [
            {
              'amount': '500',
              'appName': 'PhonePe',
              'timestampMs': DateTime.now().millisecondsSinceEpoch,
            }
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

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. ONBOARDING 6-STEP FLOW TESTS
  // ═══════════════════════════════════════════════════════════════════════════
  group('Milestone 21: 6-Step Onboarding Flow', () {
    testWidgets('Step 1: WelcomeScreen renders tagline and triggers callback', (tester) async {
      bool started = false;
      await tester.pumpWidget(MaterialApp(
        home: WelcomeScreen(onGetStarted: () => started = true),
      ));

      expect(find.text('MyUPI'), findsOneWidget);
      expect(
        find.text('Turn your Android phone into a smart UPI Soundbox.'),
        findsOneWidget,
      );
      expect(find.text('Get Started'), findsOneWidget);

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      expect(started, isTrue);
    });

    testWidgets('Step 2: StepNotifScreen renders reassuring copy and Step 2 of 6', (tester) async {
      bool continued = false;
      await tester.pumpWidget(MaterialApp(
        home: StepNotifScreen(onContinue: () => continued = true),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Step 2 of 6'), findsOneWidget);
      expect(find.text('Allow MyUPI to hear payment notifications'), findsOneWidget);
      expect(
        find.textContaining('MyUPI does not need or access your UPI PIN'),
        findsOneWidget,
      );

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(continued, isTrue);
    });

    testWidgets('Step 3: StepSoundScreen renders Soundbox setup and Step 3 of 6', (tester) async {
      bool continued = false;
      await tester.pumpWidget(MaterialApp(
        home: StepSoundScreen(onContinue: () => continued = true),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Step 3 of 6'), findsOneWidget);
      expect(find.text('Soundbox Setup'), findsOneWidget);
      expect(find.text('Voice Soundbox'), findsOneWidget);
      expect(find.text('Announcement Language'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(continued, isTrue);
    });

    testWidgets('Step 4: StepShopProfileScreen saves shop name and Step 4 of 6', (tester) async {
      bool continued = false;
      await tester.pumpWidget(MaterialApp(
        home: StepShopProfileScreen(onContinue: () => continued = true),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Step 4 of 6'), findsOneWidget);
      expect(find.text('Your Shop Name'), findsOneWidget);
      expect(find.text('Announce shop name'), findsOneWidget);

      // Enter new shop name
      await tester.enterText(find.byType(TextField), 'Sharma Kirana');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(continued, isTrue);
      expect(currentMerchantName, 'Sharma Kirana');
      expect(methodCalls.any((c) => c.method == 'setMerchantName'), isTrue);
    });

    testWidgets('Step 5: StepTestSoundScreen triggers audio test and Step 5 of 6', (tester) async {
      bool continued = false;
      await tester.pumpWidget(MaterialApp(
        home: StepTestSoundScreen(onContinue: () => continued = true),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Step 5 of 6'), findsOneWidget);
      expect(find.text('Test Your Soundbox'), findsOneWidget);

      // Tap test button
      await tester.tap(find.text('Test Soundbox'));
      await tester.pumpAndSettle();

      expect(methodCalls.any((c) => c.method == 'speakTest'), isTrue);
      expect(find.text('Soundbox is working!'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(continued, isTrue);
    });

    testWidgets('Step 6: StepReadyScreen renders final summary and completes onboarding', (tester) async {
      bool finished = false;
      await tester.pumpWidget(MaterialApp(
        home: StepReadyScreen(
          onFinish: () => finished = true,
          notifAccessGranted: true,
          soundboxEnabled: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Step 6 of 6'), findsOneWidget);
      expect(find.text('MyUPI is ready'), findsOneWidget);
      expect(find.text('Go to Dashboard'), findsOneWidget);

      await tester.tap(find.text('Go to Dashboard'));
      await tester.pumpAndSettle();

      expect(finished, isTrue);
      expect(methodCalls.any((c) => c.method == 'setOnboardingCompleted'), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. SETTINGS SCREEN REORGANIZATION & DEVELOPER JARGON REMOVAL
  // ═══════════════════════════════════════════════════════════════════════════
  group('Milestone 21: Settings Screen Reorganization', () {
    testWidgets('Settings renders SOUNDBOX, SUBSCRIPTION, and APP categories', (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const MaterialApp(
        home: SettingsScreen(),
      ));
      await tester.pumpAndSettle();

      // Section headers
      expect(find.text('SOUNDBOX'), findsOneWidget);
      expect(find.text('SUBSCRIPTION'), findsOneWidget);
      expect(find.text('APP'), findsOneWidget);

      // Soundbox items
      expect(find.text('Soundbox'), findsOneWidget);
      expect(find.text('Shop / Business Name'), findsOneWidget);
      expect(find.text('Include Shop Name'), findsOneWidget);
      expect(find.text('Announcement Language'), findsOneWidget);

      // Developer diagnostics is REMOVED from the list view
      expect(find.text('Developer Diagnostics'), findsNothing);

      // App items
      expect(find.text('Notification Access'), findsOneWidget);
      expect(find.text('Help & Support'), findsOneWidget);
      expect(find.text('About MyUPI'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. HELP & SUPPORT SCREEN
  // ═══════════════════════════════════════════════════════════════════════════
  group('Milestone 21: Help & Support Screen', () {
    testWidgets('HelpSupportScreen renders 8 FAQ topics and expands answers', (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const MaterialApp(
        home: HelpSupportScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Help & Support'), findsOneWidget);
      expect(find.text('Merchant Soundbox Guide'), findsOneWidget);

      // Check all 8 essential topics
      expect(find.textContaining('1. How does MyUPI work'), findsOneWidget);
      expect(find.textContaining('2. How do I enable Notification Access'), findsOneWidget);
      expect(find.textContaining('3. How do I test the soundbox audio'), findsOneWidget);
      expect(find.textContaining('4. Which UPI apps are supported'), findsOneWidget);
      expect(find.textContaining('5. Why was a payment not announced'), findsOneWidget);
      expect(find.textContaining('6. Battery saver & keeping MyUPI active'), findsOneWidget);
      expect(find.textContaining('7. Voice engine troubleshooting'), findsOneWidget);
      expect(find.textContaining('8. How to manage or cancel MyUPI Premium'), findsOneWidget);

      // Tap first FAQ to expand
      await tester.tap(find.textContaining('1. How does MyUPI work'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Everything happens 100% locally on your device'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. ABOUT SCREEN & 7-TAP DEVELOPER UNLOCK
  // ═══════════════════════════════════════════════════════════════════════════
  group('Milestone 21: About Screen & 7-Tap Developer Unlock', () {
    testWidgets('AboutScreen renders version, legal dialogs, and unlocks Dev mode after 7 taps', (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const MaterialApp(
        home: AboutScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('About MyUPI'), findsOneWidget);
      expect(find.text('1.0.0 (Build 1) · Production Ready'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);

      // Privacy Policy Dialog
      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();
      expect(find.textContaining('100% On-Device & Zero-PII Policy'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Terms of Service Dialog
      await tester.tap(find.text('Terms of Service'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Merchant Soundbox Agreement'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Developer mode is initially hidden
      expect(find.text('Dev Mode'), findsNothing);

      // Tap version row 7 times
      final versionFinder = find.text('1.0.0 (Build 1) · Production Ready');
      for (int i = 0; i < 7; i++) {
        await tester.tap(versionFinder);
        await tester.pump(const Duration(milliseconds: 80));
      }
      await tester.pumpAndSettle();

      // DiagnosticsScreen should have been pushed
      expect(find.byType(DiagnosticsScreen), findsOneWidget);

      // Pop DiagnosticsScreen back to AboutScreen
      final navigator = Navigator.of(tester.element(find.byType(DiagnosticsScreen)));
      navigator.pop();
      await tester.pumpAndSettle();

      // Dev Mode chip and diagnostics tile should now be visible on AboutScreen!
      expect(find.text('Dev Mode'), findsOneWidget);
      expect(find.text('Developer Diagnostics'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. DASHBOARD MERCHANT EXPERIENCE
  // ═══════════════════════════════════════════════════════════════════════════
  group('Milestone 21: Merchant Dashboard Polish', () {
    testWidgets('HomeScreen renders shop name and ACTIVE status pill', (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      currentMerchantName = 'Abhay General Store';
      currentSoundboxEnabled = true;
      currentNotifAccess = true;

      await tester.pumpWidget(const MaterialApp(
        home: HomeScreen(),
      ));
      await tester.pumpAndSettle();

      // Merchant shop name
      expect(find.text('Abhay General Store'), findsOneWidget);

      // Soundbox status pill
      expect(find.text('ACTIVE'), findsOneWidget);

      // Recent payment card displays cleanly
      expect(find.text('Most Recent Payment'), findsOneWidget);
      expect(find.text('₹500'), findsWidgets);
      expect(find.text('PhonePe'), findsWidgets);
    });
  });
}
