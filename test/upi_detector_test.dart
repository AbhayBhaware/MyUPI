// test/upi_detector_test.dart
//
// Unit tests for UpiNotificationDetector.
//
// These tests run on the host Dart VM (no Android device needed) and cover:
//   • PhonePe  — verified on real device
//   • Paytm    — verified on real device
//   • Google Pay — reference format (not yet device-verified)
//   • Amazon Pay — reference format (not yet device-verified)
//   • BHIM       — reference format (not yet device-verified)
//   • SMS/non-UPI apps — must always be rejected
//   • General rejection cases (failed, pending, outgoing)

import 'package:flutter_test/flutter_test.dart';
import 'package:myupi/upi_detector.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

PaymentDetectionResult _detect({
  required String package,
  String title = '',
  required String text,
}) =>
    UpiNotificationDetector.detect(
      packageName: package,
      title: title,
      text: text,
    );

// Packages
const _phonepe  = 'com.phonepe.app';
const _paytm    = 'net.one97.paytm';
const _gpay     = 'com.google.android.apps.nbu.paisa.user';
const _amazon   = 'in.amazon.mShop.android.shopping';
const _bhim     = 'in.org.npci.upiapp';
const _messages = 'com.google.android.apps.messaging';  // SMS — must be rejected

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('PhonePe detector (device-verified)', () {
    test('Detects ₹1 incoming payment', () {
      final r = _detect(package: _phonepe, title: 'Kaushal Patil Dattakala: Kaushal Patil Dattakala', text: 'sent ₹1 to you.');
      expect(r.isPayment, isTrue);
      expect(r.amount, '1');
      expect(r.currency, '₹');
      expect(r.appName, 'PhonePe');
      expect(r.reason, contains('PhonePe incoming payment'));
    });

    test('Detects ₹500 incoming payment', () {
      final r = _detect(package: _phonepe, text: 'sent ₹500 to you.');
      expect(r.isPayment, isTrue);
      expect(r.amount, '500');
    });

    test('Detects ₹1,250 (comma-formatted) incoming payment', () {
      final r = _detect(package: _phonepe, text: 'sent ₹1,250 to you.');
      expect(r.isPayment, isTrue);
      expect(r.amount, '1,250');
    });

    test('Detects ₹25.50 (decimal) incoming payment', () {
      final r = _detect(package: _phonepe, text: 'sent ₹25.50 to you.');
      expect(r.isPayment, isTrue);
      expect(r.amount, '25.50');
    });

    test('Rejects outgoing: "₹500 sent to Rahul"', () {
      final r = _detect(package: _phonepe, text: '₹500 sent to Rahul');
      expect(r.isPayment, isFalse);
    });

    test('Rejects "Payment failed ₹500"', () {
      final r = _detect(package: _phonepe, text: 'Payment failed ₹500');
      expect(r.isPayment, isFalse);
      expect(r.reason, contains('failed'));
    });

    test('Rejects "₹500 payment pending"', () {
      final r = _detect(package: _phonepe, text: '₹500 payment pending');
      expect(r.isPayment, isFalse);
    });

    test('Rejects "Refund of ₹200 initiated"', () {
      final r = _detect(package: _phonepe, text: 'Refund of ₹200 initiated');
      expect(r.isPayment, isFalse);
    });

    test('Rejects empty text', () {
      final r = _detect(package: _phonepe, text: '');
      expect(r.isPayment, isFalse);
    });

    test('Rejects text with only ₹ symbol', () {
      final r = _detect(package: _phonepe, text: '₹');
      expect(r.isPayment, isFalse);
    });
  });

  group('Paytm detector (device-verified)', () {
    test('Detects ₹1 incoming — real device format', () {
      final r = _detect(
        package: _paytm,
        title: 'PAYMENT',
        text: 'Received ₹1 from Kaushal · Deposited in you...',
      );
      expect(r.isPayment, isTrue);
      expect(r.amount, '1');
      expect(r.currency, '₹');
      expect(r.appName, 'Paytm');
      expect(r.reason, contains('Paytm incoming payment'));
    });

    test('Detects ₹500 incoming', () {
      final r = _detect(package: _paytm, text: 'Received ₹500 from Amit');
      expect(r.isPayment, isTrue);
      expect(r.amount, '500');
    });

    test('Detects ₹1,250 comma-formatted', () {
      final r = _detect(package: _paytm, text: 'Received ₹1,250 from Priya');
      expect(r.isPayment, isTrue);
      expect(r.amount, '1,250');
    });

    test('Detects ₹25.50 decimal', () {
      final r = _detect(package: _paytm, text: 'Received ₹25.50 from Raj');
      expect(r.isPayment, isTrue);
      expect(r.amount, '25.50');
    });

    test('Does NOT extract Transaction ID from notification', () {
      final r = _detect(
        package: _paytm,
        text: 'Received ₹500 from Rahul. Transaction ID 123456789',
      );
      expect(r.isPayment, isTrue);
      expect(r.amount, '500');  // NOT 123456789
    });

    test('Rejects "Sent ₹500 to Rahul"', () {
      final r = _detect(package: _paytm, text: 'Sent ₹500 to Rahul');
      expect(r.isPayment, isFalse);
    });

    test('Rejects payment failure', () {
      final r = _detect(package: _paytm, text: 'Payment of ₹500 failed');
      expect(r.isPayment, isFalse);
    });

    test('Rejects pending', () {
      final r = _detect(package: _paytm, text: '₹500 payment pending');
      expect(r.isPayment, isFalse);
    });

    test('Rejects refund', () {
      final r = _detect(package: _paytm, text: 'Refund of ₹200 processed');
      expect(r.isPayment, isFalse);
    });

    test('Rejects empty text', () {
      final r = _detect(package: _paytm, title: 'PAYMENT', text: '');
      expect(r.isPayment, isFalse);
    });
  });

  group('Google Pay detector (reference format)', () {
    test('Detects ₹1 incoming — reference format', () {
      final r = _detect(
        package: _gpay,
        title: 'Kaushal Patil Dattakala: Kaushal Patil Dattakala',
        text: 'Kaushal Patil Dattakala sent ₹1 to you.',
      );
      expect(r.isPayment, isTrue);
      expect(r.amount, '1');
      expect(r.currency, '₹');
      expect(r.appName, 'Google Pay');
      expect(r.reason, contains('Google Pay incoming payment'));
    });

    test('Detects ₹500 incoming', () {
      final r = _detect(package: _gpay, text: 'Rahul sent ₹500 to you.');
      expect(r.isPayment, isTrue);
      expect(r.amount, '500');
    });

    test('Detects ₹1,250 comma-formatted', () {
      final r = _detect(package: _gpay, text: 'Amit sent ₹1,250 to you.');
      expect(r.isPayment, isTrue);
      expect(r.amount, '1,250');
    });

    test('Detects ₹25.50 decimal', () {
      final r = _detect(package: _gpay, text: 'Priya sent ₹25.50 to you.');
      expect(r.isPayment, isTrue);
      expect(r.amount, '25.50');
    });

    test('Rejects outgoing: "You sent ₹500 to Rahul."', () {
      final r = _detect(package: _gpay, text: 'You sent ₹500 to Rahul.');
      expect(r.isPayment, isFalse);
      expect(r.reason, contains('Outgoing'));
    });

    test('Rejects "Sent ₹500 to Rahul."', () {
      final r = _detect(package: _gpay, text: 'Sent ₹500 to Rahul.');
      expect(r.isPayment, isFalse);
    });

    test('Rejects "₹500 sent to Rahul."', () {
      final r = _detect(package: _gpay, text: '₹500 sent to Rahul.');
      expect(r.isPayment, isFalse);
    });

    test('Rejects payment failure', () {
      final r = _detect(package: _gpay, text: 'Rahul sent ₹500 to you. Payment failed.');
      expect(r.isPayment, isFalse);
    });

    test('Rejects pending', () {
      final r = _detect(package: _gpay, text: '₹500 payment pending');
      expect(r.isPayment, isFalse);
    });

    test('Rejects empty text', () {
      final r = _detect(package: _gpay, text: '');
      expect(r.isPayment, isFalse);
    });
  });

  group('Amazon Pay detector (reference format)', () {
    test('Detects ₹1 incoming — reference format', () {
      final r = _detect(
        package: _amazon,
        title: 'Amazon Pay',
        text: 'You received ₹1 from Kaushal Patil Dattakala.',
      );
      expect(r.isPayment, isTrue);
      expect(r.amount, '1');
      expect(r.currency, '₹');
      expect(r.appName, 'Amazon Pay');
      expect(r.reason, contains('Amazon Pay incoming payment'));
    });

    test('Detects ₹500 incoming', () {
      final r = _detect(package: _amazon, text: 'You received ₹500 from Amit');
      expect(r.isPayment, isTrue);
      expect(r.amount, '500');
    });

    test('Detects ₹1,250 comma-formatted', () {
      final r = _detect(package: _amazon, text: 'You received ₹1,250 from Rahul.');
      expect(r.isPayment, isTrue);
      expect(r.amount, '1,250');
    });

    test('Detects ₹25.50 decimal', () {
      final r = _detect(package: _amazon, text: 'You received ₹25.50 from Priya.');
      expect(r.isPayment, isTrue);
      expect(r.amount, '25.50');
    });

    test('Rejects — "Received ₹500" alone (no "from")', () {
      // "received" without "you received ... from" structure
      final r = _detect(package: _amazon, text: 'Received ₹500');
      expect(r.isPayment, isFalse);
    });

    test('Rejects payment failure', () {
      final r = _detect(package: _amazon, text: 'You received ₹500 from Rahul. Payment failed.');
      expect(r.isPayment, isFalse);
    });

    test('Rejects empty text', () {
      final r = _detect(package: _amazon, text: '');
      expect(r.isPayment, isFalse);
    });
  });

  group('BHIM detector (reference format)', () {
    test('Detects ₹1 incoming — reference format', () {
      final r = _detect(
        package: _bhim,
        title: 'BHIM',
        text: '₹1 received from Kaushal Patil Dattakala.',
      );
      expect(r.isPayment, isTrue);
      expect(r.amount, '1');
      expect(r.currency, '₹');
      expect(r.appName, 'BHIM');
      expect(r.reason, contains('BHIM incoming payment'));
    });

    test('Detects ₹500 incoming', () {
      final r = _detect(package: _bhim, text: '₹500 received from Rahul.');
      expect(r.isPayment, isTrue);
      expect(r.amount, '500');
    });

    test('Detects ₹1,250 comma-formatted', () {
      final r = _detect(package: _bhim, text: '₹1,250 received from Priya.');
      expect(r.isPayment, isTrue);
      expect(r.amount, '1,250');
    });

    test('Detects ₹25.50 decimal', () {
      final r = _detect(package: _bhim, text: '₹25.50 received from Raj.');
      expect(r.isPayment, isTrue);
      expect(r.amount, '25.50');
    });

    test('Rejects outgoing: "₹500 sent to Rahul."', () {
      final r = _detect(package: _bhim, text: '₹500 sent to Rahul.');
      expect(r.isPayment, isFalse);
    });

    test('Rejects "₹500 paid to Rahul."', () {
      final r = _detect(package: _bhim, text: '₹500 paid to Rahul.');
      expect(r.isPayment, isFalse);
    });

    test('Rejects payment failure', () {
      final r = _detect(package: _bhim, text: '₹500 received from Rahul. Payment failed.');
      expect(r.isPayment, isFalse);
    });

    test('Rejects pending', () {
      final r = _detect(package: _bhim, text: '₹500 payment pending');
      expect(r.isPayment, isFalse);
    });

    test('Rejects empty text', () {
      final r = _detect(package: _bhim, text: '');
      expect(r.isPayment, isFalse);
    });
  });

  group('SMS / non-UPI apps — must always be rejected', () {
    test('Google Messages: bank SMS with payment amount', () {
      final r = _detect(
        package: _messages,
        text: 'You have received a payment of Rs. 1.00 from Kaushal.',
      );
      expect(r.isPayment, isFalse);
      expect(r.reason, contains('not a known UPI app'));
    });

    test('WhatsApp message mentioning payment', () {
      final r = _detect(
        package: 'com.whatsapp',
        text: 'Rahul: I sent you ₹500 via PhonePe',
      );
      expect(r.isPayment, isFalse);
      expect(r.reason, contains('not a known UPI app'));
    });

    test('Unknown random package with ₹', () {
      final r = _detect(
        package: 'com.some.random.app',
        text: 'You received ₹1 from someone',
      );
      expect(r.isPayment, isFalse);
      expect(r.reason, contains('not a known UPI app'));
    });
  });

  group('General rejection cases', () {
    test('"₹500 sent to Rahul." — any UPI app', () {
      // This string alone should never be a payment for any of our parsers.
      for (final pkg in [_phonepe, _paytm, _gpay, _amazon, _bhim]) {
        final r = _detect(package: pkg, text: '₹500 sent to Rahul.');
        expect(r.isPayment, isFalse,
            reason: 'Should be rejected for package $pkg');
      }
    });

    test('"Payment failed ₹500." — any UPI app', () {
      for (final pkg in [_phonepe, _paytm, _gpay, _amazon, _bhim]) {
        final r = _detect(package: pkg, text: 'Payment failed ₹500.');
        expect(r.isPayment, isFalse,
            reason: 'Should be rejected for package $pkg');
      }
    });

    test('"₹500 payment pending." — any UPI app', () {
      for (final pkg in [_phonepe, _paytm, _gpay, _amazon, _bhim]) {
        final r = _detect(package: pkg, text: '₹500 payment pending.');
        expect(r.isPayment, isFalse,
            reason: 'Should be rejected for package $pkg');
      }
    });

    test('Empty title AND empty text — no crash', () {
      for (final pkg in [_phonepe, _paytm, _gpay, _amazon, _bhim]) {
        expect(
          () => _detect(package: pkg, title: '', text: ''),
          returnsNormally,
        );
      }
    });

    test('Null-like inputs (whitespace only) — no crash', () {
      for (final pkg in [_phonepe, _paytm, _gpay, _amazon, _bhim]) {
        expect(
          () => _detect(package: pkg, title: '   ', text: '   '),
          returnsNormally,
        );
      }
    });
  });

  group('displayAmount helper', () {
    test('Returns formatted string when amount and currency are set', () {
      final r = _detect(package: _paytm, text: 'Received ₹1,250 from Rahul');
      expect(r.displayAmount, '₹1,250');
    });

    test('Returns null when not a payment', () {
      final r = _detect(package: _paytm, text: 'Payment failed ₹500');
      expect(r.displayAmount, isNull);
    });

    test('Returns null for non-UPI app', () {
      final r = _detect(package: _messages, text: 'You received ₹1 from Kaushal');
      expect(r.displayAmount, isNull);
    });
  });
}
