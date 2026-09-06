// test/milestone18_architecture_test.dart
//
// Unit tests for Milestone 18:
// - PaymentEvent model serialization & migration defaults
// - Trust vs Verification status separation
// - Parser version tracking (v1)
// - PaymentRecord backward compatibility
// - MerchantProfile domain model
// - FeatureFlags & SubscriptionTier domain models
// - PaymentSource abstraction
// - LocalPaymentRepository with mock MethodChannel

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myupi/app_channels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.myupi/notification_access');

  group('PaymentEvent & Trust vs Verification', () {
    test('Defaults: source is notification, verificationStatus is notVerified, parserVersion is 1', () {
      final event = PaymentEvent(
        amount: '500',
        appName: 'PhonePe',
        timestamp: DateTime(2026, 9, 6, 12, 0),
        trustLevel: TrustLevel.high,
      );

      expect(event.amount, '500');
      expect(event.appName, 'PhonePe');
      expect(event.trustLevel, TrustLevel.high);
      expect(event.verificationStatus, VerificationStatus.notVerified);
      expect(event.source, PaymentSource.notification);
      expect(event.parserVersion, 1);
      expect(event.displayAmount, '₹500');
    });

    test('Full serialization toMap and fromMap', () {
      final original = PaymentEvent(
        amount: '1,250.50',
        appName: 'Google Pay',
        timestamp: DateTime(2026, 9, 6, 14, 30),
        trustLevel: TrustLevel.medium,
        verificationStatus: VerificationStatus.notVerified,
        source: PaymentSource.notification,
        parserVersion: 1,
      );

      final map = original.toMap();
      expect(map['amount'], '1,250.50');
      expect(map['appName'], 'Google Pay');
      expect(map['trustLevel'], 'MEDIUM');
      expect(map['verificationStatus'], 'NOT_VERIFIED');
      expect(map['source'], 'NOTIFICATION');
      expect(map['parserVersion'], 1);

      final restored = PaymentEvent.fromMap(map);
      expect(restored.amount, original.amount);
      expect(restored.appName, original.appName);
      expect(restored.trustLevel, TrustLevel.medium);
      expect(restored.verificationStatus, VerificationStatus.notVerified);
      expect(restored.source, PaymentSource.notification);
      expect(restored.parserVersion, 1);
    });

    test('Safe migration of legacy payment records without M18 fields', () {
      final legacyMap = <String, dynamic>{
        'amount': '100',
        'appName': 'Paytm',
        'trustLevel': 'HIGH',
        'timestampMs': 1757160000000,
        // Notice: verificationStatus, source, parserVersion are missing!
      };

      final migrated = PaymentEvent.fromMap(legacyMap);
      expect(migrated.amount, '100');
      expect(migrated.appName, 'Paytm');
      expect(migrated.trustLevel, TrustLevel.high);
      // Must safely fallback to safe M18 defaults:
      expect(migrated.verificationStatus, VerificationStatus.notVerified);
      expect(migrated.source, PaymentSource.notification);
      expect(migrated.parserVersion, 1);
    });

    test('PaymentRecord subclass backward compatibility', () {
      final rec = PaymentRecord(
        amount: '200',
        appName: 'BHIM',
        timestamp: DateTime.now(),
        trustLevel: 'HIGH',
      );

      expect(rec.amount, '200');
      expect(rec.appName, 'BHIM');
      expect(rec.trustLevel, TrustLevel.high);
      expect(rec.verificationStatus, VerificationStatus.notVerified);
      expect(rec.source, PaymentSource.notification);
      expect(rec.parserVersion, 1);
    });
  });

  group('MerchantProfile', () {
    test('Default values', () {
      const profile = MerchantProfile(merchantId: 'test-uuid-1234');
      expect(profile.merchantId, 'test-uuid-1234');
      expect(profile.shopName, 'MyUPI');
      expect(profile.preferredLanguage, 'en-IN');
      expect(profile.speechSpeed, 'normal');
      expect(profile.announcementFormat, 'A');
      expect(profile.soundboxEnabled, true);
      expect(profile.includeShopName, false);
    });

    test('Serialization toMap and fromMap', () {
      final profile = MerchantProfile(
        merchantId: 'uuid-999',
        shopName: 'Sharma Grocery',
        preferredLanguage: 'hi-IN',
        speechSpeed: 'fast',
        announcementFormat: 'B',
        soundboxEnabled: true,
        includeShopName: true,
      );

      final map = profile.toMap();
      final restored = MerchantProfile.fromMap(map);

      expect(restored.merchantId, 'uuid-999');
      expect(restored.shopName, 'Sharma Grocery');
      expect(restored.preferredLanguage, 'hi-IN');
      expect(restored.speechSpeed, 'fast');
      expect(restored.announcementFormat, 'B');
      expect(restored.soundboxEnabled, true);
      expect(restored.includeShopName, true);
    });

    test('copyWith works correctly', () {
      const original = MerchantProfile(merchantId: 'm1');
      final updated = original.copyWith(shopName: 'New Shop', soundboxEnabled: false);

      expect(updated.merchantId, 'm1');
      expect(updated.shopName, 'New Shop');
      expect(updated.soundboxEnabled, false);
      expect(updated.preferredLanguage, 'en-IN');
    });
  });

  group('FeatureFlags & SubscriptionTier', () {
    test('FeatureFlags defaults to core notification soundbox enabled, rest disabled', () {
      const flags = FeatureFlags();
      expect(flags.notificationSoundbox, true);
      expect(flags.verifiedPayments, false);
      expect(flags.backendSync, false);
      expect(flags.premiumFeatures, false);

      final map = flags.toMap();
      expect(map['notificationSoundbox'], true);
      expect(map['verifiedPayments'], false);
      expect(map['backendSync'], false);
      expect(map['premiumFeatures'], false);

      final fromM = FeatureFlags.fromMap(map);
      expect(fromM, equals(flags));
    });

    test('SubscriptionTier parsing & defaults', () {
      expect(SubscriptionTier.fromString('FREE'), SubscriptionTier.free);
      expect(SubscriptionTier.fromString('PREMIUM'), SubscriptionTier.premium);
      expect(SubscriptionTier.fromString('INVALID'), SubscriptionTier.free);

      expect(SubscriptionTier.free.label, 'FREE');
      expect(SubscriptionTier.premium.label, 'PREMIUM');
    });
  });

  group('PaymentSource abstraction', () {
    test('NotificationPaymentSource is active MVP source', () {
      final source = NotificationPaymentSource();
      expect(source.sourceType, PaymentSource.notification);
      expect(source.displayName, 'Android Notification Listener');
      expect(source.isVerificationCapable, false);
    });

    test('FutureVerifiedPaymentSource is architecture placeholder', () {
      final source = FutureVerifiedPaymentSource();
      expect(source.sourceType, PaymentSource.paymentProvider);
      expect(source.isVerificationCapable, true);
    });
  });

  group('LocalPaymentRepository with Mock Channel', () {
    late LocalPaymentRepository repository;

    setUp(() {
      repository = LocalPaymentRepository(channel: channel);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'getPaymentHistory':
            return <dynamic>[
              {
                'amount': '350',
                'appName': 'PhonePe',
                'trustLevel': 'HIGH',
                'timestampMs': 1757160000000,
                'verificationStatus': 'NOT_VERIFIED',
                'source': 'NOTIFICATION',
                'parserVersion': 1,
              },
            ];
          case 'getMerchantProfile':
            return <String, dynamic>{
              'merchantId': 'local-uuid-456',
              'shopName': 'Test Store',
              'preferredLanguage': 'en-IN',
              'speechSpeed': 'normal',
              'announcementFormat': 'A',
              'soundboxEnabled': true,
              'includeShopName': false,
            };
          case 'getFeatureFlags':
            return <String, dynamic>{
              'notificationSoundbox': true,
              'verifiedPayments': false,
              'backendSync': false,
              'premiumFeatures': false,
            };
          case 'getSubscriptionTier':
            return 'FREE';
          case 'getDiagnostics':
            return <String, dynamic>{
              'notificationAccessGranted': true,
              'serviceBound': true,
              'parserVersion': 1,
              'supportedPackagesCount': 12,
              'soundboxEnabled': true,
              'speechSpeed': 'normal',
              'language': 'en-IN',
              'announcementFormat': 'A',
              'includeShopName': false,
              'totalStoredPayments': 1,
              'merchantId': 'local-uuid-456',
              'subscriptionTier': 'FREE',
              'featureFlags': {
                'notificationSoundbox': true,
                'verifiedPayments': false,
                'backendSync': false,
                'premiumFeatures': false,
              },
            };
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('getPaymentHistory loads records with M18 fields', () async {
      final history = await repository.getPaymentHistory();
      expect(history.length, 1);
      expect(history.first.amount, '350');
      expect(history.first.appName, 'PhonePe');
      expect(history.first.trustLevel, TrustLevel.high);
      expect(history.first.verificationStatus, VerificationStatus.notVerified);
      expect(history.first.source, PaymentSource.notification);
      expect(history.first.parserVersion, 1);
    });

    test('getMerchantProfile returns valid profile', () async {
      final profile = await repository.getMerchantProfile();
      expect(profile.merchantId, 'local-uuid-456');
      expect(profile.shopName, 'Test Store');
      expect(profile.preferredLanguage, 'en-IN');
    });

    test('getFeatureFlags returns valid flags', () async {
      final flags = await repository.getFeatureFlags();
      expect(flags.notificationSoundbox, true);
      expect(flags.verifiedPayments, false);
    });

    test('getSubscriptionTier returns free tier', () async {
      final tier = await repository.getSubscriptionTier();
      expect(tier, SubscriptionTier.free);
    });

    test('getDiagnostics returns safe developer diagnostics', () async {
      final diag = await repository.getDiagnostics();
      expect(diag['notificationAccessGranted'], true);
      expect(diag['parserVersion'], 1);
      expect(diag['supportedPackagesCount'], 12);
      expect(diag['subscriptionTier'], 'FREE');
    });
  });
}
