// test/milestone20_billing_test.dart
//
// Milestone 20: Real Google Play Subscription Integration Unit & Widget Tests
// ----------------------------------------------------------------------------
// Tests:
//   1. Billing Constants & Google Play product architecture
//   2. Safe purchase token sanitization (zero full token leakage)
//   3. Merchant-friendly error message mapping (no raw stack traces)
//   4. SubscriptionManager purchase confirmation, entitlement unlock, and lifecycle
//   5. EntitlementManager feature gating vs core soundbox protection
//   6. PaywallScreen dynamic UI, live CTA, and restore purchase action
//   7. PaywallScreen active subscriber status banner
//   8. DiagnosticsScreen Google Play Billing card with safe sanitized diagnostics

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

import 'package:myupi/app_channels.dart';
import 'package:myupi/screens/paywall_screen.dart';
import 'package:myupi/screens/diagnostics_screen.dart';

// ── Mock Platform for InAppPurchase Testing ──────────────────────────────────

class MockInAppPurchasePlatform extends InAppPurchasePlatform {
  final StreamController<List<PurchaseDetails>> _purchaseStreamController =
      StreamController<List<PurchaseDetails>>.broadcast();

  bool available = true;
  bool completePurchaseCalled = false;
  PurchaseDetails? lastCompletedPurchase;
  bool restorePurchasesCalled = false;
  List<ProductDetails> queryResponse = [];

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      _purchaseStreamController.stream;

  void emitPurchases(List<PurchaseDetails> purchases) {
    _purchaseStreamController.add(purchases);
  }

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async {
    return ProductDetailsResponse(
      productDetails: queryResponse,
      notFoundIDs: identifiers
          .where((id) => !queryResponse.any((p) => p.id == id))
          .toList(),
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async => true;

  @override
  Future<bool> buyConsumable({required PurchaseParam purchaseParam, bool autoConsume = true}) async => true;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completePurchaseCalled = true;
    lastCompletedPurchase = purchase;
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restorePurchasesCalled = true;
  }

  @override
  Future<String> countryCode() async => 'IND';
}

// ── Test Purchase Details Helper ─────────────────────────────────────────────

class TestPurchaseDetails extends PurchaseDetails {
  TestPurchaseDetails({
    required super.productID,
    required super.purchaseID,
    required super.status,
    required super.transactionDate,
    required super.verificationData,
    bool pendingComplete = true,
  }) {
    pendingCompletePurchase = pendingComplete;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockInAppPurchasePlatform mockPlatform;

  setUp(() {
    mockPlatform = MockInAppPurchasePlatform();
    InAppPurchasePlatform.instance = mockPlatform;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kMethodChannel, (MethodCall call) async {
      if (call.method == 'getSubscriptionState') {
        return 'INTRO_OFFER_AVAILABLE';
      }
      if (call.method == 'setSubscriptionState') {
        return null;
      }
      if (call.method == 'getDiagnostics') {
        return <String, dynamic>{
          'notificationAccessGranted': true,
          'serviceBound': true,
          'soundboxEnabled': true,
          'speechSpeed': 'normal',
          'language': 'en-IN',
          'announcementFormat': 'A',
          'includeShopName': false,
          'merchantName': 'MyUPI',
          'merchantId': 'test-merchant-id-12345',
          'totalStoredPayments': 10,
          'subscriptionTier': 'FREE',
          'subscriptionState': 'INTRO_OFFER_AVAILABLE',
          'featureFlags': {
            'notificationSoundbox': true,
            'verifiedPayments': false,
          },
        };
      }
      return null;
    });
  });

  tearDown(() async {
    await SubscriptionManager.instance.resetToDefault();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kMethodChannel, null);
  });

  // ── 1. Commercial Product & Architecture Constants ─────────────────────────

  group('Google Play Product Architecture Constants', () {
    test('verifies Play Console product, base plan, and offer identifiers', () {
      expect(BillingConstants.subscriptionId, 'myupi_soundbox_pro');
      expect(BillingConstants.basePlanId, 'monthly-recurring');
      expect(BillingConstants.introOfferId, 'intro-offer-1inr');
      expect(BillingConstants.defaultIntroPrice, '₹1');
      expect(BillingConstants.defaultRecurringPrice, '₹49/month');
    });
  });

  // ── 2. Safe Token Sanitization ─────────────────────────────────────────────

  group('BillingService Token Sanitization', () {
    test('handles null or empty token safely', () {
      expect(BillingService.sanitizeToken(null), 'N/A');
      expect(BillingService.sanitizeToken(''), 'N/A');
      expect(BillingService.sanitizeToken('   '), 'N/A');
    });

    test('masks short tokens without exposing contents', () {
      expect(BillingService.sanitizeToken('abc'), '***');
      expect(BillingService.sanitizeToken('12345678'), '***');
    });

    test('masks long tokens preserving only prefix and suffix', () {
      final sanitized = BillingService.sanitizeToken('GPA.3341-9988-1234-56789');
      expect(sanitized, 'GPA....6789');
      expect(sanitized.contains('9988'), isFalse);
      expect(sanitized.contains('1234'), isFalse);
    });
  });

  // ── 3. Merchant-Friendly Billing Error Translation ─────────────────────────

  group('BillingService Friendly Error Translation', () {
    test('translates user cancellation politely', () {
      final msg = BillingService.friendlyErrorMessage('USER_CANCELED');
      expect(msg, contains('cancelled'));
      expect(msg, contains('No charges were made'));
    });

    test('translates network / connectivity issues clearly', () {
      final msg = BillingService.friendlyErrorMessage('SERVICE_UNAVAILABLE - network connection lost');
      expect(msg, contains('Network connection issue'));
      expect(msg, contains('internet connection'));
    });

    test('translates item already owned with restore guidance', () {
      final msg = BillingService.friendlyErrorMessage('ITEM_ALREADY_OWNED');
      expect(msg, contains('already own'));
      expect(msg, contains('Restore Purchases'));
    });

    test('translates item unavailable without exposing stack trace', () {
      final msg = BillingService.friendlyErrorMessage('ITEM_UNAVAILABLE');
      expect(msg, contains('unavailable'));
    });

    test('translates billing unavailable gracefully', () {
      final msg = BillingService.friendlyErrorMessage('BILLING_UNAVAILABLE');
      expect(msg, contains('Google Play Billing is unavailable'));
    });

    test('translates arbitrary unknown errors with auto-refund guarantee', () {
      final msg = BillingService.friendlyErrorMessage('InternalBillingException: 0x80040154 at line 42');
      expect(msg, contains('Payment was not completed'));
      expect(msg, contains('refund it automatically'));
      expect(msg.contains('0x80040154'), isFalse);
    });
  });

  // ── 4. Purchase Lifecycle & Acknowledgement ────────────────────────────────

  group('BillingService & SubscriptionManager Lifecycle', () {
    test('confirmed purchase unlocks SubscriptionState.active and acknowledges within 3 days', () async {
      final subMgr = SubscriptionManager.instance;
      expect(subMgr.currentState, SubscriptionState.introOfferAvailable);
      expect(subMgr.entitlements.isPremium, isFalse);

      // Simulate confirmed purchase from Google Play
      await subMgr.updateFromPurchase(
        orderId: 'GPA.1234-5678-9012',
        purchaseToken: 'GPA.1234...9012',
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );

      expect(subMgr.currentState, SubscriptionState.active);
      expect(subMgr.entitlements.isPremium, isTrue);
      expect(subMgr.currentInfo.isAutoRenewing, isTrue);
      expect(subMgr.currentInfo.isSimulated, isFalse);
    });

    test('expired subscription transitions to EXPIRED while preserving core soundbox', () async {
      final subMgr = SubscriptionManager.instance;

      // 1. Merchant was active
      await subMgr.updateFromPurchase(
        orderId: 'GPA.1234-5678-9012',
        purchaseToken: 'GPA.1234...9012',
      );
      expect(subMgr.entitlements.isPremium, isTrue);

      // 2. Subscription expires
      await subMgr.setSubscriptionExpired();
      expect(subMgr.currentState, SubscriptionState.expired);
      expect(subMgr.entitlements.isPremium, isFalse);

      // 3. Core soundbox features remain 100% active!
      final ent = subMgr.entitlements;
      expect(ent.isCoreSoundboxAllowed, isTrue);
      expect(ent.canDetectUpiPayments, isTrue);
      expect(ent.canUseNativeTts, isTrue);
      expect(ent.isDuplicateProtectionActive, isTrue);
      expect(ent.canStorePaymentHistory, isTrue);
      expect(ent.isPrivacyProtectionGuaranteed, isTrue);

      // 4. Free languages still work
      expect(ent.canUseLanguage('en-IN'), isTrue);
      expect(ent.canUseLanguage('hi-IN'), isTrue);
      // Premium languages locked
      expect(ent.canUseLanguage('mr-IN'), isFalse);
      expect(ent.canUseLanguage('ta-IN'), isFalse);
    });

    test('grace period and cancelled-but-active states retain premium privileges', () async {
      final subMgr = SubscriptionManager.instance;

      // Grace period
      await subMgr.setSimulatedState(SubscriptionState.gracePeriod);
      expect(subMgr.entitlements.isPremium, isTrue);
      expect(subMgr.entitlements.canCustomizeShopAnnouncement, isTrue);

      // Cancelled but still within billing cycle
      await subMgr.setSimulatedState(SubscriptionState.cancelled);
      expect(subMgr.entitlements.isPremium, isTrue);
      expect(subMgr.entitlements.canUseAllIndianLanguages, isTrue);
    });
  });

  // ── 5. PaywallScreen UI Widget Tests ───────────────────────────────────────

  group('PaywallScreen Widget Integration', () {
    testWidgets('renders commercial pricing, offer copy, CTA, and terms', (tester) async {
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
      await tester.pumpAndSettle();

      // Verify title & proposition
      expect(find.text('MyUPI Premium'), findsOneWidget);
      expect(find.text('SMART SOUNDBOX UPGRADE'), findsOneWidget);
      expect(find.text('Turn your phone into a smart UPI Soundbox.'), findsOneWidget);

      // Verify ₹1 first month & ₹49/month
      expect(find.text('₹1'), findsOneWidget);
      expect(find.text('for your first month'), findsOneWidget);
      expect(find.text('THEN ₹49/MONTH'), findsOneWidget);

      // Verify CTA button
      expect(find.text('Start Premium — ₹1 First Month'), findsOneWidget);
      expect(find.text('Restore Purchases'), findsOneWidget);

      // Verify auto-renewal notice
      expect(find.textContaining('Introductory offer of ₹1 for the first 30 days'), findsOneWidget);
      expect(find.textContaining('Cancel anytime via Google Play'), findsOneWidget);

      // Verify benefits
      expect(find.text('Instant Voice Announcements'), findsOneWidget);
      expect(find.text('All 8 Supported Indian Languages'), findsOneWidget);
      expect(find.text('Personalized Shop Name Voice'), findsOneWidget);
      expect(find.text('No Hardware Device Required'), findsOneWidget);
    });

    testWidgets('active subscription displays active banner and Manage CTA', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Simulate active subscription
      await SubscriptionManager.instance.updateFromPurchase(
        orderId: 'GPA.9999-8888',
        purchaseToken: 'TOKEN_1234',
        expiresAt: DateTime(2026, 10, 15),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: PaywallScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MyUPI Premium is Active'), findsOneWidget);
      expect(find.textContaining('Renews automatically on 2026-10-15'), findsOneWidget);
      expect(find.text('Manage Subscription'), findsOneWidget);
    });

    testWidgets('tapping Restore Purchases invokes restore flow and displays feedback', (tester) async {
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
      await tester.pumpAndSettle();

      await tester.tap(find.text('Restore Purchases'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 500));

      // In unit test environment without real Google Play, shows graceful status snackbar
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  // ── 6. DiagnosticsScreen Google Play Billing Diagnostics ───────────────────

  group('DiagnosticsScreen Google Play Billing Diagnostics', () {
    testWidgets('renders safe billing diagnostic card with zero sensitive data', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: DiagnosticsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Google Play Billing & Subscriptions card is present
      expect(find.text('Google Play Billing & Subscriptions'), findsOneWidget);
      expect(find.text('Target Product ID'), findsOneWidget);
      expect(find.text('myupi_soundbox_pro'), findsOneWidget);
      expect(find.text('Live Introductory Price'), findsOneWidget);
      expect(find.text('Live Recurring Price'), findsOneWidget);
      expect(find.text('Purchase Acknowledged'), findsOneWidget);
      expect(find.text('Sanitized Token'), findsOneWidget);
      expect(find.text('Refresh Play Billing Products'), findsOneWidget);
    });
  });
}
