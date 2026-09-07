// test/milestone19_subscription_test.dart
//
// Comprehensive Automated Tests for Milestone 19:
// - SubscriptionState lifecycle & transitions
// - SubscriptionInfo model & pricing disclosures (₹1 first month, ₹49/month)
// - Centralized EntitlementManager logic
// - Core Soundbox protection guarantees
// - SubscriptionManager singleton & dev simulation
// - PaywallScreen widget rendering & transparent disclosures
// - StepPremiumIntroScreen widget rendering & non-aggressive flow

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myupi/app_channels.dart';
import 'package:myupi/screens/paywall_screen.dart';
import 'package:myupi/screens/onboarding/step_premium_intro_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.myupi/notification_access');

  group('SubscriptionState & Model Tests', () {
    test('SubscriptionState parsing and storage keys', () {
      expect(SubscriptionState.fromString('NOT_SUBSCRIBED'), SubscriptionState.notSubscribed);
      expect(SubscriptionState.fromString('INTRO_OFFER_AVAILABLE'), SubscriptionState.introOfferAvailable);
      expect(SubscriptionState.fromString('ACTIVE'), SubscriptionState.active);
      expect(SubscriptionState.fromString('GRACE_PERIOD'), SubscriptionState.gracePeriod);
      expect(SubscriptionState.fromString('EXPIRED'), SubscriptionState.expired);
      expect(SubscriptionState.fromString('CANCELLED'), SubscriptionState.cancelled);
      expect(SubscriptionState.fromString('UNKNOWN_XYZ'), SubscriptionState.introOfferAvailable);
      expect(SubscriptionState.fromString(null), SubscriptionState.introOfferAvailable);

      expect(SubscriptionState.introOfferAvailable.toStorageKey(), 'INTRO_OFFER_AVAILABLE');
      expect(SubscriptionState.active.toStorageKey(), 'ACTIVE');
      expect(SubscriptionState.gracePeriod.toStorageKey(), 'GRACE_PERIOD');
      expect(SubscriptionState.expired.toStorageKey(), 'EXPIRED');
      expect(SubscriptionState.cancelled.toStorageKey(), 'CANCELLED');
    });

    test('SubscriptionState hasPremiumEntitlement boundaries', () {
      expect(SubscriptionState.active.hasPremiumEntitlement, isTrue);
      expect(SubscriptionState.gracePeriod.hasPremiumEntitlement, isTrue);
      expect(SubscriptionState.cancelled.hasPremiumEntitlement, isTrue);

      expect(SubscriptionState.introOfferAvailable.hasPremiumEntitlement, isFalse);
      expect(SubscriptionState.notSubscribed.hasPremiumEntitlement, isFalse);
      expect(SubscriptionState.expired.hasPremiumEntitlement, isFalse);
      expect(SubscriptionState.unknown.hasPremiumEntitlement, isFalse);
    });

    test('SubscriptionInfo pricing and disclosures', () {
      const info = SubscriptionInfo();

      expect(info.state, SubscriptionState.introOfferAvailable);
      expect(info.introPriceRupees, 1);
      expect(info.regularPriceRupees, 49);
      expect(info.currency, '₹');
      expect(info.introOfferHeadline, '₹1 for your first month');
      expect(info.recurringPriceNotice, 'Then ₹49/month');
      expect(info.fullPricingDisclosure, contains('₹1 for first month, then ₹49/month'));
    });

    test('SubscriptionInfo serialization round-trip', () {
      final original = SubscriptionInfo(
        state: SubscriptionState.active,
        introPriceRupees: 1,
        regularPriceRupees: 49,
        currency: '₹',
        expiresAt: DateTime(2026, 10, 7),
        isAutoRenewing: true,
        isSimulated: true,
      );

      final map = original.toMap();
      final restored = SubscriptionInfo.fromMap(map);

      expect(restored.state, SubscriptionState.active);
      expect(restored.introPriceRupees, 1);
      expect(restored.regularPriceRupees, 49);
      expect(restored.isAutoRenewing, isTrue);
      expect(restored.isSimulated, isTrue);
      expect(restored.expiresAt, equals(DateTime(2026, 10, 7)));
    });
  });

  group('EntitlementManager & Core Protection Tests', () {
    test('Core soundbox features are NEVER blocked under any subscription state', () {
      for (final state in SubscriptionState.values) {
        final manager = EntitlementManager(subscriptionState: state);
        expect(manager.isCoreSoundboxAllowed, isTrue, reason: 'State $state blocked core soundbox');
        expect(manager.canDetectUpiPayments, isTrue, reason: 'State $state blocked UPI detection');
        expect(manager.canUseNativeTts, isTrue, reason: 'State $state blocked native TTS');
        expect(manager.isDuplicateProtectionActive, isTrue, reason: 'State $state blocked dedup');
        expect(manager.canStorePaymentHistory, isTrue, reason: 'State $state blocked ledger storage');
        expect(manager.isPrivacyProtectionGuaranteed, isTrue, reason: 'State $state broke privacy guarantee');
      }
    });

    test('Free tier entitlements (Intro Offer Available)', () {
      const manager = EntitlementManager(subscriptionState: SubscriptionState.introOfferAvailable);

      expect(manager.isPremium, isFalse);
      expect(manager.canUseLanguage('en-IN'), isTrue);
      expect(manager.canUseLanguage('hi-IN'), isTrue);
      expect(manager.canUseLanguage('mr-IN'), isFalse);
      expect(manager.canUseAllIndianLanguages, isFalse);
      expect(manager.canUseAnnouncementFormat('A'), isTrue);
      expect(manager.canUseAnnouncementFormat('B'), isFalse);
      expect(manager.canUseAdvancedAnnouncements, isFalse);
      expect(manager.canCustomizeShopAnnouncement, isFalse);
      expect(manager.canExportHistory, isFalse);
      expect(manager.canUseAdvancedAnalytics, isFalse);
      expect(manager.maxHistoryRecords, 50);
    });

    test('Premium tier entitlements (Active)', () {
      const manager = EntitlementManager(subscriptionState: SubscriptionState.active);

      expect(manager.isPremium, isTrue);
      expect(manager.canUseLanguage('en-IN'), isTrue);
      expect(manager.canUseLanguage('hi-IN'), isTrue);
      expect(manager.canUseLanguage('mr-IN'), isTrue);
      expect(manager.canUseLanguage('ta-IN'), isTrue);
      expect(manager.canUseAllIndianLanguages, isTrue);
      expect(manager.canUseAnnouncementFormat('A'), isTrue);
      expect(manager.canUseAnnouncementFormat('B'), isTrue);
      expect(manager.canUseAnnouncementFormat('C'), isTrue);
      expect(manager.canUseAdvancedAnnouncements, isTrue);
      expect(manager.canCustomizeShopAnnouncement, isTrue);
      expect(manager.canExportHistory, isTrue);
      expect(manager.canUseAdvancedAnalytics, isTrue);
      expect(manager.maxHistoryRecords, 500);
    });

    test('Grace period tier entitlements remain temporarily active', () {
      const manager = EntitlementManager(subscriptionState: SubscriptionState.gracePeriod);

      expect(manager.isPremium, isTrue);
      expect(manager.canCustomizeShopAnnouncement, isTrue);
      expect(manager.canUseAllIndianLanguages, isTrue);
    });

    test('Expired tier revokes premium privileges cleanly', () {
      const manager = EntitlementManager(subscriptionState: SubscriptionState.expired);

      expect(manager.isPremium, isFalse);
      expect(manager.canCustomizeShopAnnouncement, isFalse);
      expect(manager.canUseAnnouncementFormat('B'), isFalse);
      expect(manager.isCoreSoundboxAllowed, isTrue); // Core soundbox still runs!
    });
  });

  group('SubscriptionManager Lifecycle & Simulation Tests', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'getSubscriptionState':
            return 'INTRO_OFFER_AVAILABLE';
          case 'setSubscriptionState':
            return null;
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('Initialization defaults to introOfferAvailable', () async {
      final mgr = SubscriptionManager.instance;
      await mgr.initialize(channel: channel);

      expect(mgr.currentState, SubscriptionState.introOfferAvailable);
      expect(mgr.currentInfo.introPriceRupees, 1);
      expect(mgr.currentInfo.regularPriceRupees, 49);
      expect(mgr.entitlements.isPremium, isFalse);
      expect(mgr.entitlements.isCoreSoundboxAllowed, isTrue);
    });

    test('Simulated state update from developer diagnostics', () async {
      final mgr = SubscriptionManager.instance;
      await mgr.setSimulatedState(SubscriptionState.active, channel: channel);

      expect(mgr.currentState, SubscriptionState.active);
      expect(mgr.currentInfo.isSimulated, isTrue);
      expect(mgr.currentInfo.isAutoRenewing, isTrue);
      expect(mgr.entitlements.isPremium, isTrue);
      expect(mgr.entitlements.canCustomizeShopAnnouncement, isTrue);
    });

    test('Reset to default returns to introOfferAvailable', () async {
      final mgr = SubscriptionManager.instance;
      await mgr.resetToDefault(channel: channel);

      expect(mgr.currentState, SubscriptionState.introOfferAvailable);
      expect(mgr.currentInfo.isSimulated, isFalse);
      expect(mgr.entitlements.isPremium, isFalse);
    });
  });

  group('Paywall & Onboarding Widgets', () {
    testWidgets('PaywallScreen renders transparent pricing and coming-soon CTA', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: PaywallScreen(),
        ),
      );

      // Verify headline & value proposition
      expect(find.text('MyUPI Premium'), findsOneWidget);
      expect(find.text('Turn your phone into a smart UPI Soundbox.'), findsOneWidget);

      // Verify ₹1 first month & ₹49/month disclosures
      expect(find.text('₹1'), findsOneWidget);
      expect(find.text('for your first month'), findsOneWidget);
      expect(find.text('THEN ₹49/MONTH'), findsOneWidget);

      // Verify CTA & restoration buttons (Milestone 20 live Play billing CTA)
      expect(find.text('Start Premium — ₹1 First Month'), findsOneWidget);
      expect(find.text('Restore Purchases'), findsOneWidget);

      // Verify benefit items
      expect(find.text('Instant Voice Announcements'), findsOneWidget);
      expect(find.text('All 8 Supported Indian Languages'), findsOneWidget);

      // Tap CTA to verify billing connecting dialog in test environment
      await tester.tap(find.text('Start Premium — ₹1 First Month'));
      await tester.pumpAndSettle();

      expect(find.text('Billing Connecting'), findsOneWidget);
      expect(find.text('GOT IT'), findsOneWidget);

      await tester.tap(find.text('GOT IT'));
      await tester.pumpAndSettle();
      expect(find.text('Billing Connecting'), findsNothing);
    });

    testWidgets('StepPremiumIntroScreen renders non-aggressive intro and action buttons', (tester) async {
      bool finished = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StepPremiumIntroScreen(
            onFinish: () => finished = true,
          ),
        ),
      );

      expect(find.text('Try MyUPI for ₹1'), findsOneWidget);
      expect(find.text('View Premium Offer'), findsOneWidget);
      expect(find.text('Continue with Free Soundbox'), findsOneWidget);

      // Tap "Continue with Free Soundbox" without paying
      await tester.tap(find.text('Continue with Free Soundbox'));
      await tester.pump();

      expect(finished, isTrue);
    });
  });
}
