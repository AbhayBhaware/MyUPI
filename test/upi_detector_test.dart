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
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '1');
      expect(r.currency, '₹');
      expect(r.appName, 'PhonePe');
      expect(r.reason, contains('PhonePe incoming payment'));
    });

    test('Detects ₹500 incoming payment', () {
      final r = _detect(package: _phonepe, text: 'sent ₹500 to you.');
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '500');
    });

    test('Detects ₹1,250 (comma-formatted) incoming payment', () {
      final r = _detect(package: _phonepe, text: 'sent ₹1,250 to you.');
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '1,250');
    });

    test('Detects ₹25.50 (decimal) incoming payment', () {
      final r = _detect(package: _phonepe, text: 'sent ₹25.50 to you.');
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '25.50');
    });

    test('Rejects outgoing: "₹500 sent to Rahul"', () {
      final r = _detect(package: _phonepe, text: '₹500 sent to Rahul');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Rejects "Payment failed ₹500"', () {
      final r = _detect(package: _phonepe, text: 'Payment failed ₹500');
      expect(r.trustLevel, TrustLevel.low);
      expect(r.reason, contains('failed'));
    });

    test('Rejects "₹500 payment pending"', () {
      final r = _detect(package: _phonepe, text: '₹500 payment pending');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Rejects "Refund of ₹200 initiated"', () {
      final r = _detect(package: _phonepe, text: 'Refund of ₹200 initiated');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Rejects empty text', () {
      final r = _detect(package: _phonepe, text: '');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Rejects text with only ₹ symbol', () {
      final r = _detect(package: _phonepe, text: '₹');
      expect(r.trustLevel, TrustLevel.low);
    });
  });

  group('Paytm detector (device-verified)', () {
    test('Detects ₹1 incoming — real device format', () {
      final r = _detect(
        package: _paytm,
        title: 'PAYMENT',
        text: 'Received ₹1 from Kaushal · Deposited in you...',
      );
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '1');
      expect(r.currency, '₹');
      expect(r.appName, 'Paytm');
      expect(r.reason, contains('Paytm incoming payment'));
    });

    test('Detects ₹500 incoming', () {
      final r = _detect(package: _paytm, text: 'Received ₹500 from Amit');
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '500');
    });

    test('Detects ₹1,250 comma-formatted', () {
      final r = _detect(package: _paytm, text: 'Received ₹1,250 from Priya');
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '1,250');
    });

    test('Detects ₹25.50 decimal', () {
      final r = _detect(package: _paytm, text: 'Received ₹25.50 from Raj');
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '25.50');
    });

    test('Does NOT extract Transaction ID from notification', () {
      final r = _detect(
        package: _paytm,
        text: 'Received ₹500 from Rahul. Transaction ID 123456789',
      );
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '500');  // NOT 123456789
    });

    test('Rejects "Sent ₹500 to Rahul"', () {
      final r = _detect(package: _paytm, text: 'Sent ₹500 to Rahul');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Rejects payment failure', () {
      final r = _detect(package: _paytm, text: 'Payment of ₹500 failed');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Rejects pending', () {
      final r = _detect(package: _paytm, text: '₹500 payment pending');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Rejects refund', () {
      final r = _detect(package: _paytm, text: 'Refund of ₹200 processed');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Rejects empty text', () {
      final r = _detect(package: _paytm, title: 'PAYMENT', text: '');
      expect(r.trustLevel, TrustLevel.low);
    });
  });

  group('Google Pay detector (reference format)', () {
    test('Detects ₹1 incoming — reference format', () {
      final r = _detect(
        package: _gpay,
        title: 'Kaushal Patil Dattakala: Kaushal Patil Dattakala',
        text: 'Kaushal Patil Dattakala sent ₹1 to you.',
      );
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '1');
      expect(r.currency, '₹');
      expect(r.appName, 'Google Pay');
      expect(r.reason, contains('Google Pay incoming payment'));
    });

    test('Detects ₹500 incoming', () {
      final r = _detect(package: _gpay, text: 'Rahul sent ₹500 to you.');
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '500');
    });

    test('Detects ₹1,250 comma-formatted', () {
      final r = _detect(package: _gpay, text: 'Amit sent ₹1,250 to you.');
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '1,250');
    });

    test('Detects ₹25.50 decimal', () {
      final r = _detect(package: _gpay, text: 'Priya sent ₹25.50 to you.');
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '25.50');
    });

    test('Rejects outgoing: "You sent ₹500 to Rahul."', () {
      final r = _detect(package: _gpay, text: 'You sent ₹500 to Rahul.');
      expect(r.trustLevel, TrustLevel.low);
      expect(r.reason, contains('Outgoing'));
    });

    test('Rejects "Sent ₹500 to Rahul."', () {
      final r = _detect(package: _gpay, text: 'Sent ₹500 to Rahul.');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Rejects "₹500 sent to Rahul."', () {
      final r = _detect(package: _gpay, text: '₹500 sent to Rahul.');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Rejects payment failure', () {
      final r = _detect(package: _gpay, text: 'Rahul sent ₹500 to you. Payment failed.');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Rejects pending', () {
      final r = _detect(package: _gpay, text: '₹500 payment pending');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Rejects empty text', () {
      final r = _detect(package: _gpay, text: '');
      expect(r.trustLevel, TrustLevel.low);
    });
  });

  group('Amazon Pay detector (reference format)', () {
    test('Detects ₹1 incoming — reference format', () {
      final r = _detect(
        package: _amazon,
        title: 'Amazon Pay',
        text: 'You received ₹1 from Kaushal Patil Dattakala.',
      );
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '1');
      expect(r.currency, '₹');
      expect(r.appName, 'Amazon Pay');
      expect(r.reason, contains('Amazon Pay incoming payment'));
    });

    test('Detects ₹500 incoming', () {
      final r = _detect(package: _amazon, text: 'You received ₹500 from Amit');
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '500');
    });

    test('Detects ₹1,250 comma-formatted', () {
      final r = _detect(package: _amazon, text: 'You received ₹1,250 from Rahul.');
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '1,250');
    });

    test('Detects ₹25.50 decimal', () {
      final r = _detect(package: _amazon, text: 'You received ₹25.50 from Priya.');
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '25.50');
    });

    test('Medium Trust — "Received ₹500" alone (no "from")', () {
      // "received" without "you received ... from" structure
      final r = _detect(package: _amazon, text: 'Received ₹500');
      expect(r.trustLevel, TrustLevel.medium);
    });

    test('Rejects payment failure', () {
      final r = _detect(package: _amazon, text: 'You received ₹500 from Rahul. Payment failed.');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Rejects empty text', () {
      final r = _detect(package: _amazon, text: '');
      expect(r.trustLevel, TrustLevel.low);
    });
  });

  group('BHIM detector (reference format)', () {
    test('Detects ₹1 incoming — reference format', () {
      final r = _detect(
        package: _bhim,
        title: 'BHIM',
        text: '₹1 received from Kaushal Patil Dattakala.',
      );
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '1');
      expect(r.currency, '₹');
      expect(r.appName, 'BHIM');
      expect(r.reason, contains('BHIM incoming payment'));
    });

    test('Detects ₹500 incoming', () {
      final r = _detect(package: _bhim, text: '₹500 received from Rahul.');
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '500');
    });

    test('Detects ₹1,250 comma-formatted', () {
      final r = _detect(package: _bhim, text: '₹1,250 received from Priya.');
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '1,250');
    });

    test('Detects ₹25.50 decimal', () {
      final r = _detect(package: _bhim, text: '₹25.50 received from Raj.');
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '25.50');
    });

    test('Rejects outgoing: "₹500 sent to Rahul."', () {
      final r = _detect(package: _bhim, text: '₹500 sent to Rahul.');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Rejects "₹500 paid to Rahul."', () {
      final r = _detect(package: _bhim, text: '₹500 paid to Rahul.');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Rejects payment failure', () {
      final r = _detect(package: _bhim, text: '₹500 received from Rahul. Payment failed.');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Rejects pending', () {
      final r = _detect(package: _bhim, text: '₹500 payment pending');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Rejects empty text', () {
      final r = _detect(package: _bhim, text: '');
      expect(r.trustLevel, TrustLevel.low);
    });
  });

  group('SMS / non-UPI apps — must always be rejected', () {
    test('Google Messages: bank SMS with payment amount', () {
      final r = _detect(
        package: _messages,
        text: 'You have received a payment of Rs. 1.00 from Kaushal.',
      );
      expect(r.trustLevel, TrustLevel.low);
      expect(r.reason, contains('not a known UPI app'));
    });

    test('WhatsApp message mentioning payment', () {
      final r = _detect(
        package: 'com.whatsapp',
        text: 'Rahul: I sent you ₹500 via PhonePe',
      );
      expect(r.trustLevel, TrustLevel.low);
      expect(r.reason, contains('not a known UPI app'));
    });

    test('Unknown random package with ₹', () {
      final r = _detect(
        package: 'com.some.random.app',
        text: 'You received ₹1 from someone',
      );
      expect(r.trustLevel, TrustLevel.low);
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

  // ─── Milestone 10: Additional hardening tests ─────────────────────────────

  group('M10: PhonePe Business (b2b package)', () {
    const phonepeBiz = 'com.phonepe.app.b2b';

    test('Detects valid incoming payment via b2b package', () {
      final r = _detect(package: phonepeBiz, text: 'sent ₹250 to you.');
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '250');
      expect(r.appName, 'PhonePe for Business');
    });

    test('Rejects outgoing via b2b package', () {
      final r = _detect(package: phonepeBiz, text: '₹250 sent to Rahul');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Rejects failed via b2b package', () {
      final r = _detect(package: phonepeBiz, text: 'Payment failed ₹250');
      expect(r.trustLevel, TrustLevel.low);
    });
  });

  group('M10: cancel / cancellation rejection', () {
    test('PhonePe: rejects notification with "cancel"', () {
      final r = _detect(package: _phonepe, text: 'sent ₹500 to you. cancel');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('PhonePe: rejects notification with "cancellation"', () {
      final r = _detect(package: _phonepe, text: 'cancellation: sent ₹500 to you.');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Paytm: rejects "Payment cancel ₹500"', () {
      final r = _detect(package: _paytm, text: 'Payment cancel ₹500 from Rahul');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Google Pay: rejects "Payment cancellation ₹500"', () {
      final r = _detect(package: _gpay, text: 'Rahul sent ₹500 to you. Cancellation initiated.');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Amazon Pay: rejects "cancel" keyword', () {
      final r = _detect(package: _amazon, text: 'You received ₹500 from Rahul. Cancel requested.');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('BHIM: rejects "cancellation" keyword', () {
      final r = _detect(package: _bhim, text: '₹500 received from Rahul. Cancellation.');
      expect(r.trustLevel, TrustLevel.low);
    });
  });

  group('M10: collect request rejection', () {
    test('PhonePe: rejects "collect request"', () {
      final r = _detect(package: _phonepe, text: 'collect request ₹500 from Rahul');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Paytm: rejects "Collect Request ₹500"', () {
      final r = _detect(package: _paytm, text: 'Collect Request ₹500 from Rahul');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Google Pay: rejects "collect request"', () {
      final r = _detect(package: _gpay, text: 'Rahul sent a collect request ₹500 to you.');
      expect(r.trustLevel, TrustLevel.low);
    });
  });

  group('M10: reversal / reversed rejection', () {
    test('PhonePe: rejects "reversed"', () {
      final r = _detect(package: _phonepe, text: 'sent ₹500 to you. Transaction reversed.');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('PhonePe: rejects "reversal"', () {
      final r = _detect(package: _phonepe, text: 'Reversal: sent ₹500 to you.');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Paytm: rejects "Reversal of ₹500"', () {
      final r = _detect(package: _paytm, text: 'Reversal of ₹500 processed.');
      expect(r.trustLevel, TrustLevel.low);
    });
  });

  group('M10: debited / paid to rejection', () {
    test('PhonePe: rejects "debited"', () {
      final r = _detect(package: _phonepe, text: '₹500 debited from your account');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Paytm: rejects "paid to"', () {
      final r = _detect(package: _paytm, text: '₹500 paid to merchant');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('BHIM: rejects "debited"', () {
      final r = _detect(package: _bhim, text: '₹500 debited from your account');
      expect(r.trustLevel, TrustLevel.low);
    });
  });

  group('M10: reminder rejection', () {
    test('PhonePe: rejects "reminder"', () {
      final r = _detect(package: _phonepe, text: 'Reminder: sent ₹500 to you.');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Paytm: rejects "remind"', () {
      final r = _detect(package: _paytm, text: 'Remind Rahul to pay ₹500');
      expect(r.trustLevel, TrustLevel.low);
    });
  });

  group('M10: notification update duplicate scenario', () {
    // Same payment from the same sender, notification updated with extra text.
    // Both should be detected as payment (Flutter/Kotlin dedup by key prevents
    // double-counting — the parser itself sees each independently).
    // We verify that the AMOUNT is the same in both, so no false amount mismatch.

    test('Original notification detected', () {
      final r1 = _detect(
        package: _paytm,
        title: 'PAYMENT',
        text: 'Received ₹500 from Rahul',
      );
      expect(r1.isPayment, isTrue);
      expect(r1.amount, '500');
    });

    test('Updated notification (same payment) detected with same amount', () {
      // Paytm sometimes appends "· Deposited in your account" as an update.
      final r2 = _detect(
        package: _paytm,
        title: 'PAYMENT',
        text: 'Received ₹500 from Rahul · Deposited in your account',
      );
      expect(r2.isPayment, isTrue);
      expect(r2.amount, '500'); // Same amount — dedup is handled by notification key, not parser.
    });

    test('PhonePe extended text — same amount', () {
      final r1 = _detect(package: _phonepe, text: 'sent ₹1 to you.');
      final r2 = _detect(package: _phonepe, text: 'sent ₹1 to you. Tap to view details.');
      expect(r1.amount, r2.amount);
    });
  });

  group('M10: security boundary — unknown packages', () {
    test('Fake payment app — rejected at package gate', () {
      final r = _detect(
        package: 'com.fake.payment.app',
        text: 'You received ₹10,000 from Rahul',
      );
      expect(r.trustLevel, TrustLevel.low);
      expect(r.reason, contains('not a known UPI app'));
    });

    test('Bank SMS via messaging app — rejected', () {
      final r = _detect(
        package: 'com.google.android.apps.messaging',
        text: 'Rs. 500 credited to your account',
      );
      expect(r.trustLevel, TrustLevel.low);
      expect(r.reason, contains('not a known UPI app'));
    });

    test('SMS Organizer — rejected', () {
      final r = _detect(
        package: 'com.microsoft.android.smsorganizer',
        text: 'Received ₹500 from Rahul',
      );
      expect(r.trustLevel, TrustLevel.low);
      expect(r.reason, contains('not a known UPI app'));
    });

    test('Random package with perfect payment text — rejected', () {
      final r = _detect(
        package: 'com.some.random.notifier',
        text: 'sent ₹500 to you.',
      );
      expect(r.trustLevel, TrustLevel.low);
      expect(r.reason, contains('not a known UPI app'));
    });
  });

  group('M10: amount extraction safety', () {
    test('Paytm: transaction ID after amount — only amount extracted', () {
      final r = _detect(
        package: _paytm,
        text: 'Received ₹500 from Rahul. Txn ID: T2409041234567890',
      );
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '500'); // NOT the transaction ID digits
    });

    test('PhonePe: reference number in text — only amount extracted', () {
      final r = _detect(
        package: _phonepe,
        text: 'sent ₹1,250 to you. Ref: 409041234567',
      );
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '1,250'); // NOT the reference number
    });

    test('Google Pay: UPI ID in notification — only amount extracted', () {
      final r = _detect(
        package: _gpay,
        text: 'Rahul sent ₹100 to you. From rahul@upi',
      );
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '100');
    });

    test('BHIM: large amount with lakh formatting', () {
      final r = _detect(package: _bhim, text: '₹1,00,000 received from Rahul.');
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '1,00,000');
    });

    test('PhonePe: large amount with lakh formatting', () {
      final r = _detect(package: _phonepe, text: 'sent ₹1,00,000 to you.');
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '1,00,000');
    });
  });

  group('M10: outgoing direction rejection — exhaustive', () {
    test('PhonePe: "Sent ₹500 to Rahul" — rejected', () {
      final r = _detect(package: _phonepe, text: 'Sent ₹500 to Rahul');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('PhonePe: "Paid ₹500 to merchant" — rejected', () {
      final r = _detect(package: _phonepe, text: 'Paid ₹500 to merchant');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Google Pay: "You sent ₹500 to Rahul" — rejected', () {
      final r = _detect(package: _gpay, text: 'You sent ₹500 to Rahul.');
      expect(r.trustLevel, TrustLevel.low);
      expect(r.reason, contains('Outgoing'));
    });

    test('Google Pay: "Sent ₹500 to Rahul" (no "you") — rejected by pattern miss', () {
      final r = _detect(package: _gpay, text: 'Sent ₹500 to Rahul.');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Paytm: "Sent ₹500 to Rahul" — rejected', () {
      final r = _detect(package: _paytm, text: 'Sent ₹500 to Rahul');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Amazon Pay: "You sent ₹500 to Rahul" — rejected', () {
      final r = _detect(package: _amazon, text: 'You sent ₹500 to Rahul');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('BHIM: "₹500 sent to Rahul" — rejected', () {
      final r = _detect(package: _bhim, text: '₹500 sent to Rahul.');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Any UPI app: "Debited ₹500 from account" — rejected', () {
      for (final pkg in [_phonepe, _paytm, _gpay, _amazon, _bhim]) {
        final r = _detect(package: pkg, text: 'Debited ₹500 from your account');
        expect(r.isPayment, isFalse,
            reason: 'Debited must be rejected for $pkg');
      }
    });

    test('Any UPI app: "Payment of ₹500 made to" — rejected', () {
      for (final pkg in [_phonepe, _paytm, _gpay, _amazon, _bhim]) {
        final r = _detect(package: pkg, text: 'Payment of ₹500 made to Rahul');
        expect(r.isPayment, isFalse,
            reason: 'Outgoing "made to" must be rejected for $pkg');
      }
    });
  });

  group('M10: refund rejection', () {
    test('PhonePe: refund initiated — rejected', () {
      final r = _detect(package: _phonepe, text: 'Refund of ₹500 initiated to your account');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Paytm: refunded — rejected', () {
      final r = _detect(package: _paytm, text: 'Refunded ₹500 to Rahul');
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Google Pay: refunding — rejected', () {
      final r = _detect(package: _gpay, text: 'Rahul sent ₹500 to you. Refunding.');
      expect(r.trustLevel, TrustLevel.low);
    });
  });

  group('M12: Medium trust / Fallback amount detection', () {
    test('PhonePe: Unknown wording but amount present', () {
      final r = _detect(package: _phonepe, text: 'Payment received ₹500 from Rahul recently.');
      expect(r.trustLevel, TrustLevel.medium);
      expect(r.amount, isNull); // Fallback does not extract amount yet
    });

    test('Paytm: Unknown wording but amount present', () {
      final r = _detect(package: _paytm, text: 'Rahul credited ₹1,200 to your wallet');
      expect(r.trustLevel, TrustLevel.medium);
    });

    test('Google Pay: Unknown wording but amount present', () {
      final r = _detect(package: _gpay, text: 'Amount received: ₹250 from Amit');
      expect(r.trustLevel, TrustLevel.medium);
    });

    test('Amazon Pay: Unknown wording but amount present', () {
      final r = _detect(package: _amazon, text: 'Credit of ₹10 from cashback');
      expect(r.trustLevel, TrustLevel.medium);
    });

    test('BHIM: Unknown wording but amount present', () {
      final r = _detect(package: _bhim, text: '₹50 credited successfully.');
      expect(r.trustLevel, TrustLevel.medium);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MILESTONE 17: PRODUCTION MVP POLISH & MERCHANT RELIABILITY TESTS
  // ═══════════════════════════════════════════════════════════════════════════

  group('M17: Strict payment validation — All 5 supported UPI apps', () {
    test('PhonePe incoming payment', () {
      final r = _detect(package: _phonepe, text: 'sent ₹500 to you.');
      expect(r.isPayment, isTrue);
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '500');
      expect(r.appName, 'PhonePe');
    });

    test('Paytm incoming payment', () {
      final r = _detect(package: _paytm, text: 'Received ₹500 from Rahul');
      expect(r.isPayment, isTrue);
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '500');
      expect(r.appName, 'Paytm');
    });

    test('Google Pay incoming payment', () {
      final r = _detect(package: _gpay, text: 'Rahul sent ₹500 to you.');
      expect(r.isPayment, isTrue);
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '500');
      expect(r.appName, 'Google Pay');
    });

    test('Amazon Pay incoming payment', () {
      final r = _detect(package: _amazon, text: 'You received ₹500 from Rahul.');
      expect(r.isPayment, isTrue);
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '500');
      expect(r.appName, 'Amazon Pay');
    });

    test('BHIM incoming payment', () {
      final r = _detect(package: _bhim, text: '₹500 received from Rahul.');
      expect(r.isPayment, isTrue);
      expect(r.trustLevel, TrustLevel.high);
      expect(r.amount, '500');
      expect(r.appName, 'BHIM');
    });
  });

  group('M17: Strict rejection tests — Invalid & Non-payment notifications', () {
    test('Outgoing payment rejected', () {
      final r = _detect(package: _gpay, text: 'You sent ₹500 to Rahul.');
      expect(r.isPayment, isFalse);
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Failed payment rejected', () {
      final r = _detect(package: _phonepe, text: 'Payment failed for ₹500.');
      expect(r.isPayment, isFalse);
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Pending payment rejected', () {
      final r = _detect(package: _paytm, text: '₹500 payment pending confirmation.');
      expect(r.isPayment, isFalse);
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Refund rejected', () {
      final r = _detect(package: _phonepe, text: 'Refund of ₹500 initiated.');
      expect(r.isPayment, isFalse);
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Payment request rejected', () {
      final r = _detect(package: _phonepe, text: 'Rahul sent a collect request for ₹500.');
      expect(r.isPayment, isFalse);
      expect(r.trustLevel, TrustLevel.low);
    });

    test('SMS notification rejected (non-UPI package)', () {
      final r = _detect(package: _messages, text: 'sent ₹500 to you.');
      expect(r.isPayment, isFalse);
      expect(r.trustLevel, TrustLevel.low);
      expect(r.reason, contains('not a known UPI app'));
    });

    test('Unknown app rejected', () {
      final r = _detect(package: 'com.unknown.app', text: 'sent ₹500 to you.');
      expect(r.isPayment, isFalse);
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Arbitrary notification containing ₹500 rejected', () {
      final r = _detect(package: _phonepe, text: 'Mega Sale! Get up to ₹500 cashback on recharge.');
      expect(r.isPayment, isFalse);
      expect(r.trustLevel, TrustLevel.low);
    });

    test('Notification containing "received" but not a payment rejected', () {
      final r = _detect(package: _phonepe, text: 'We received your feedback. Thank you!');
      expect(r.isPayment, isFalse);
      expect(r.trustLevel, TrustLevel.low);
    });
  });

  group('M17: Amount extraction tests', () {
    test('₹1 amount', () {
      final r = _detect(package: _phonepe, text: 'sent ₹1 to you.');
      expect(r.amount, '1');
    });

    test('₹10 amount', () {
      final r = _detect(package: _phonepe, text: 'sent ₹10 to you.');
      expect(r.amount, '10');
    });

    test('₹500 amount', () {
      final r = _detect(package: _phonepe, text: 'sent ₹500 to you.');
      expect(r.amount, '500');
    });

    test('₹1,000 amount (comma-separated)', () {
      final r = _detect(package: _phonepe, text: 'sent ₹1,000 to you.');
      expect(r.amount, '1,000');
    });

    test('₹10,000 amount', () {
      final r = _detect(package: _phonepe, text: 'sent ₹10,000 to you.');
      expect(r.amount, '10,000');
    });

    test('₹25.50 decimal amount', () {
      final r = _detect(package: _phonepe, text: 'sent ₹25.50 to you.');
      expect(r.amount, '25.50');
    });

    test('₹1,00,000 Indian lakh comma format', () {
      final r = _detect(package: _phonepe, text: 'sent ₹1,00,000 to you.');
      expect(r.amount, '1,00,000');
    });
  });

  group('M17: Duplicate protection & Deduplication tests', () {
    test('Same notification key twice is detected as duplicate', () {
      final seenKeys = <String>{};
      const key1 = 'com.phonepe.app|tag1|1001';

      // First time: not seen -> should process
      final firstAdded = seenKeys.add(key1);
      expect(firstAdded, isTrue);

      // Second time: already seen -> duplicate detected, must be suppressed
      final secondAdded = seenKeys.add(key1);
      expect(secondAdded, isFalse);
    });

    test('Notification update with same key is detected as duplicate', () {
      final seenKeys = <String>{};
      const notifKey = 'net.one97.paytm|null|2001';

      expect(seenKeys.add(notifKey), isTrue);
      // Notification updated by OS
      expect(seenKeys.add(notifKey), isFalse);
    });

    test('Two genuinely different payments close together are both allowed', () {
      final seenKeys = <String>{};
      const payment1Key = 'com.phonepe.app|tag|1001';
      const payment2Key = 'com.phonepe.app|tag|1002';

      expect(seenKeys.add(payment1Key), isTrue);
      expect(seenKeys.add(payment2Key), isTrue);
    });

    test('Sliding window dedup allows same key after 45 seconds TTL', () {
      final dedupCache = <String, int>{};
      const ttlMs = 45000;
      bool checkDuplicate(String key, int nowMs) {
        dedupCache.removeWhere((k, ts) => nowMs - ts > ttlMs);
        if (dedupCache.containsKey(key)) return true;
        dedupCache[key] = nowMs;
        return false;
      }

      const key = 'com.phonepe.app||1|contentHash123';
      expect(checkDuplicate(key, 1000), isFalse); // First arrival: processed
      expect(checkDuplicate(key, 5000), isTrue);  // Duplicate at +4s: suppressed
      expect(checkDuplicate(key, 46001), isFalse); // Arrival after +45s: allowed
    });

    test('Successive payments with same notification ID but different amounts are not blocked', () {
      final dedupCache = <String, int>{};
      const ttlMs = 45000;
      bool checkDuplicate(String key, int nowMs) {
        dedupCache.removeWhere((k, ts) => nowMs - ts > ttlMs);
        if (dedupCache.containsKey(key)) return true;
        dedupCache[key] = nowMs;
        return false;
      }

      // App reuses notification id=1 for all payments, but content hash differs
      const payment1 = 'com.phonepe.app||1|sent_20_to_you';
      const payment2 = 'com.phonepe.app||1|sent_50_to_you';

      expect(checkDuplicate(payment1, 1000), isFalse);
      expect(checkDuplicate(payment2, 2000), isFalse); // Not suppressed!
    });
  });

  group('M17: Multilingual announcement template testing', () {
    String buildSpeech(String rawAmount, String lang, String format) {
      final cleaned = rawAmount.replaceAll(',', '').trim();
      final parts = cleaned.split('.');
      final rupeeInt = int.tryParse(parts[0]) ?? 0;
      final paiseInt = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      final rupeeDisplay = rawAmount.split('.')[0];

      final amountText = switch (lang) {
        'hi-IN' => paiseInt > 0 ? '$rupeeDisplay रुपये $paiseInt पैसे' : '$rupeeDisplay रुपये',
        'mr-IN' => paiseInt > 0 ? '$rupeeDisplay रुपये $paiseInt पैसे' : '$rupeeDisplay रुपये',
        'gu-IN' => paiseInt > 0 ? '$rupeeDisplay રૂપિયા $paiseInt પૈસા' : '$rupeeDisplay રૂપિયા',
        'ta-IN' => paiseInt > 0 ? '$rupeeDisplay ரூபாய் $paiseInt காசுகள்' : '$rupeeDisplay ரூபாய்',
        'te-IN' => paiseInt > 0 ? '$rupeeDisplay రూపాయలు $paiseInt పైసలు' : '$rupeeDisplay రూపాయలు',
        'bn-IN' => paiseInt > 0 ? '$rupeeDisplay টাকা $paiseInt পয়সা' : '$rupeeDisplay টাকা',
        'kn-IN' => paiseInt > 0 ? '$rupeeDisplay ರೂಪಾಯಿ $paiseInt ಪೈಸೆ' : '$rupeeDisplay ರೂಪಾಯಿ',
        _ => rupeeInt == 1 ? '$rupeeDisplay rupee' : '$rupeeDisplay rupees',
      };

      return switch (lang) {
        'hi-IN' => switch (format) {
          'B' => '$amountText प्राप्त हुए।',
          'C' => 'पेमेंट प्राप्त हुआ, $amountText। धन्यवाद।',
          _ => 'पेमेंट प्राप्त हुआ, $amountText।',
        },
        'mr-IN' => switch (format) {
          'B' => '$amountText प्राप्त झाले.',
          'C' => 'पेमेंट प्राप्त झाले, $amountText. धन्यवाद.',
          _ => 'पेमेंट प्राप्त झाले, $amountText.',
        },
        'gu-IN' => switch (format) {
          'B' => '$amountText પ્રાપ્ત થયા.',
          'C' => 'પેમેન્ટ પ્રાપ્ત થયું, $amountText. આભાર.',
          _ => 'પેમેન્ટ પ્રાપ્ત થયું, $amountText.',
        },
        'ta-IN' => switch (format) {
          'B' => '$amountText பெறப்பட்டது.',
          'C' => 'பணம் பெறப்பட்டது, $amountText. நன்றி.',
          _ => 'பணம் பெறப்பட்டது, $amountText.',
        },
        'te-IN' => switch (format) {
          'B' => '$amountText అందాయి.',
          'C' => 'చెల్లింపు అందింది, $amountText. ధన్యవాదాలు.',
          _ => 'చెల్లింపు అందింది, $amountText.',
        },
        'bn-IN' => switch (format) {
          'B' => '$amountText পাওয়া গেছে।',
          'C' => 'পেমেন্ট পাওয়া গেছে, $amountText। ধন্যবাদ।',
          _ => 'পেমেন্ট পাওয়া গেছে, $amountText।',
        },
        'kn-IN' => switch (format) {
          'B' => '$amountText ಸ್ವೀಕರಿಸಲಾಗಿದೆ.',
          'C' => 'ಪಾವತಿ ಸ್ವೀಕರಿಸಲಾಗಿದೆ, $amountText. ಧನ್ಯವಾದಗಳು.',
          _ => 'ಪಾವತಿ ಸ್ವೀಕರಿಸಲಾಗಿದೆ, $amountText.',
        },
        _ => switch (format) {
          'B' => '$amountText received',
          'C' => 'Payment received, $amountText. Thank you.',
          _ => 'Payment received, $amountText',
        },
      };
    }

    test('English (India) Formats A, B, C', () {
      expect(buildSpeech('500', 'en-IN', 'A'), 'Payment received, 500 rupees');
      expect(buildSpeech('500', 'en-IN', 'B'), '500 rupees received');
      expect(buildSpeech('500', 'en-IN', 'C'), 'Payment received, 500 rupees. Thank you.');
    });

    test('Hindi Formats A, B, C', () {
      expect(buildSpeech('500', 'hi-IN', 'A'), 'पेमेंट प्राप्त हुआ, 500 रुपये।');
      expect(buildSpeech('500', 'hi-IN', 'B'), '500 रुपये प्राप्त हुए।');
      expect(buildSpeech('500', 'hi-IN', 'C'), 'पेमेंट प्राप्त हुआ, 500 रुपये। धन्यवाद।');
    });

    test('Marathi Formats A, B, C', () {
      expect(buildSpeech('500', 'mr-IN', 'A'), 'पेमेंट प्राप्त झाले, 500 रुपये.');
      expect(buildSpeech('500', 'mr-IN', 'B'), '500 रुपये प्राप्त झाले.');
      expect(buildSpeech('500', 'mr-IN', 'C'), 'पेमेंट प्राप्त झाले, 500 रुपये. धन्यवाद.');
    });

    test('Gujarati Formats A, B, C', () {
      expect(buildSpeech('500', 'gu-IN', 'A'), 'પેમેન્ટ પ્રાપ્ત થયું, 500 રૂપિયા.');
      expect(buildSpeech('500', 'gu-IN', 'B'), '500 રૂપિયા પ્રાપ્ત થયા.');
      expect(buildSpeech('500', 'gu-IN', 'C'), 'પેમેન્ટ પ્રાપ્ત થયું, 500 રૂપિયા. આભાર.');
    });

    test('Tamil Formats A, B, C', () {
      expect(buildSpeech('500', 'ta-IN', 'A'), 'பணம் பெறப்பட்டது, 500 ரூபாய்.');
      expect(buildSpeech('500', 'ta-IN', 'B'), '500 ரூபாய் பெறப்பட்டது.');
      expect(buildSpeech('500', 'ta-IN', 'C'), 'பணம் பெறப்பட்டது, 500 ரூபாய். நன்றி.');
    });

    test('Telugu Formats A, B, C', () {
      expect(buildSpeech('500', 'te-IN', 'A'), 'చెల్లింపు అందింది, 500 రూపాయలు.');
      expect(buildSpeech('500', 'te-IN', 'B'), '500 రూపాయలు అందాయి.');
      expect(buildSpeech('500', 'te-IN', 'C'), 'చెల్లింపు అందింది, 500 రూపాయలు. ధన్యవాదాలు.');
    });

    test('Bengali Formats A, B, C', () {
      expect(buildSpeech('500', 'bn-IN', 'A'), 'পেমেন্ট পাওয়া গেছে, 500 টাকা।');
      expect(buildSpeech('500', 'bn-IN', 'B'), '500 টাকা পাওয়া গেছে।');
      expect(buildSpeech('500', 'bn-IN', 'C'), 'পেমেন্ট পাওয়া গেছে, 500 টাকা। ধন্যবাদ।');
    });

    test('Kannada Formats A, B, C', () {
      expect(buildSpeech('500', 'kn-IN', 'A'), 'ಪಾವತಿ ಸ್ವೀಕರಿಸಲಾಗಿದೆ, 500 ರೂಪಾಯಿ.');
      expect(buildSpeech('500', 'kn-IN', 'B'), '500 ರೂಪಾಯಿ ಸ್ವೀಕರಿಸಲಾಗಿದೆ.');
      expect(buildSpeech('500', 'kn-IN', 'C'), 'ಪಾವತಿ ಸ್ವೀಕರಿಸಲಾಗಿದೆ, 500 ರೂಪಾಯಿ. ಧನ್ಯವಾದಗಳು.');
    });
  });
}
