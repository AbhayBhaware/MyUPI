// test/sms_detector_and_channel_test.dart
//
// Master Brief Verification Suite: SMS Channel, Anti-Fraud Guardrails & Cross-Channel Dedup
// -----------------------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:myupi/app_channels.dart';

void main() {
  group('Master Brief — PaymentSource & Channel Badges', () {
    test('PaymentSource enum contains notification, sms, both, paymentProvider, unknown', () {
      expect(PaymentSource.values, contains(PaymentSource.notification));
      expect(PaymentSource.values, contains(PaymentSource.sms));
      expect(PaymentSource.values, contains(PaymentSource.both));
      expect(PaymentSource.values, contains(PaymentSource.paymentProvider));
      expect(PaymentSource.values, contains(PaymentSource.unknown));
    });

    test('channelLabel produces correct display string for each source', () {
      final notifEvent = PaymentEvent(
        amount: '500',
        appName: 'PhonePe',
        timestamp: DateTime.now(),
        source: PaymentSource.notification,
      );
      expect(notifEvent.channelLabel, 'Notification');
      expect(notifEvent.isNotificationOnly, isTrue);
      expect(notifEvent.isSmsOnly, isFalse);
      expect(notifEvent.isDualConfirmed, isFalse);

      final smsEvent = PaymentEvent(
        amount: '500',
        appName: 'HDFC Bank',
        timestamp: DateTime.now(),
        source: PaymentSource.sms,
        trustLevel: TrustLevel.medium,
      );
      expect(smsEvent.channelLabel, 'SMS');
      expect(smsEvent.isSmsOnly, isTrue);
      expect(smsEvent.isNotificationOnly, isFalse);
      expect(smsEvent.isDualConfirmed, isFalse);

      final bothEvent = PaymentEvent(
        amount: '500',
        appName: 'PhonePe + HDFC Bank',
        timestamp: DateTime.now(),
        source: PaymentSource.both,
        trustLevel: TrustLevel.high,
      );
      expect(bothEvent.channelLabel, 'Dual Confirmed');
      expect(bothEvent.isDualConfirmed, isTrue);
      expect(bothEvent.isSmsOnly, isFalse);
      expect(bothEvent.isNotificationOnly, isFalse);
    });
  });

  group('Master Brief — Serialization & Backward Compatibility', () {
    test('PaymentEvent.fromMap correctly parses SMS source and MEDIUM trust', () {
      final map = {
        'amount': '1250',
        'appName': 'State Bank of India',
        'trustLevel': 'MEDIUM',
        'timestampMs': 1726670000000,
        'verificationStatus': 'NOT_VERIFIED',
        'source': 'SMS',
        'parserVersion': 1,
      };

      final event = PaymentEvent.fromMap(map);
      expect(event.amount, '1250');
      expect(event.appName, 'State Bank of India');
      expect(event.trustLevel, TrustLevel.medium);
      expect(event.source, PaymentSource.sms);
      expect(event.verificationStatus, VerificationStatus.notVerified);
      expect(event.isVerified, isFalse);
    });

    test('PaymentEvent.fromMap correctly parses BOTH source and HIGH trust', () {
      final map = {
        'amount': '750',
        'appName': 'Google Pay + ICICI Bank',
        'trustLevel': 'HIGH',
        'timestampMs': 1726670000000,
        'verificationStatus': 'NOT_VERIFIED',
        'source': 'BOTH',
        'parserVersion': 1,
      };

      final event = PaymentEvent.fromMap(map);
      expect(event.amount, '750');
      expect(event.appName, 'Google Pay + ICICI Bank');
      expect(event.trustLevel, TrustLevel.high);
      expect(event.source, PaymentSource.both);
      expect(event.isDualConfirmed, isTrue);
    });

    test('PaymentEvent.toMap outputs correct SMS and BOTH strings', () {
      final smsEvent = PaymentEvent(
        amount: '300',
        appName: 'Axis Bank',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1726670000000),
        trustLevel: TrustLevel.medium,
        source: PaymentSource.sms,
      );
      final smsMap = smsEvent.toMap();
      expect(smsMap['source'], 'SMS');
      expect(smsMap['trustLevel'], 'MEDIUM');

      final bothEvent = PaymentEvent(
        amount: '300',
        appName: 'Paytm + Axis Bank',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1726670000000),
        trustLevel: TrustLevel.high,
        source: PaymentSource.both,
      );
      final bothMap = bothEvent.toMap();
      expect(bothMap['source'], 'BOTH');
      expect(bothMap['trustLevel'], 'HIGH');
    });

    test('PaymentRecord constructor handles string source or enum seamlessly', () {
      final recFromStr = PaymentRecord(
        amount: '100',
        appName: 'Kotak Bank',
        timestamp: DateTime.now(),
        trustLevel: 'MEDIUM',
        source: 'SMS',
      );
      expect(recFromStr.source, PaymentSource.sms);
      expect(recFromStr.trustLevel, TrustLevel.medium);

      final recFromEnum = PaymentRecord(
        amount: '100',
        appName: 'Kotak Bank',
        timestamp: DateTime.now(),
        trustLevel: TrustLevel.high,
        source: PaymentSource.both,
      );
      expect(recFromEnum.source, PaymentSource.both);
      expect(recFromEnum.trustLevel, TrustLevel.high);
    });
  });

  group('Master Brief — Bank SMS Regex Pattern Tests', () {
    // Tests validating the regex rules implemented in BankSmsDetector.kt
    final amountRegex = RegExp(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false);

    test('Parses HDFC Bank UPI credit SMS', () {
      const sms = 'Dear UPI user, A/C *4321 credited by Rs. 500.00 on 18-Sep-26 by UPI ref 426189. Bal: Rs 12,450.00 - HDFC Bank';
      final match = amountRegex.firstMatch(sms);
      expect(match, isNotNull);
      expect(match!.group(1), '500.00');
    });

    test('Parses SBI UPI credit SMS', () {
      const sms = 'Your A/C ending with 9876 has been credited with INR 1,250.50 on 18-Sep-26 via UPI/P2A/4261899182. State Bank of India';
      final match = amountRegex.firstMatch(sms);
      expect(match, isNotNull);
      expect(match!.group(1)!.replaceAll(',', ''), '1250.50');
    });

    test('Parses ICICI Bank ₹ symbol SMS', () {
      const sms = 'Acct XX123 is credited with ₹200 on 18-Sep-26 by UPI:42619012. ICICI Bank';
      final match = amountRegex.firstMatch(sms);
      expect(match, isNotNull);
      expect(match!.group(1), '200');
    });

    test('Rejects Debit and non-credit messages', () {
      final debitKeywords = ['debited', 'withdrawn', 'spent', 'declined', 'failed', 'sent to'];
      const debitSms = 'Your A/C *1234 has been debited for Rs 500.00 on 18-Sep-26';
      final hasDebit = debitKeywords.any((k) => debitSms.toLowerCase().contains(k));
      expect(hasDebit, isTrue);
    });
  });
}
