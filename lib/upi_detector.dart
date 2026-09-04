// lib/upi_detector.dart
//
// UPI Payment Notification Detector
// -----------------------------------
// Responsibilities:
//   • Identify whether a notification came from a known UPI/payment app.
//   • Determine whether that notification represents a SUCCESSFUL payment received.
//   • Extract the payment amount when the format is reliably known.
//   • Avoid false-positives (failed, pending, refund, request, outgoing payments).
//
// What this does NOT do:
//   • Announce payments via TTS          (later milestone).
//   • Verify transactions with a bank   (never — notification only).

// ─── Result types ─────────────────────────────────────────────────────────────

enum DetectionStatus { payment, notPayment }

class PaymentDetectionResult {
  final DetectionStatus status;
  final String packageName;
  final String title;
  final String text;

  /// Human-readable label for the source app.
  final String appName;

  /// Why the detector reached this conclusion (for debugging).
  final String reason;

  /// Extracted payment amount as a display string, e.g. "1,250" or "25.50".
  /// null when the amount could not be safely extracted.
  final String? amount;

  /// Currency symbol, always "₹" for Indian UPI. null when amount is null.
  final String? currency;

  const PaymentDetectionResult({
    required this.status,
    required this.packageName,
    required this.title,
    required this.text,
    required this.appName,
    required this.reason,
    this.amount,
    this.currency,
  });

  bool get isPayment => status == DetectionStatus.payment;

  /// Display-ready amount string, e.g. "₹1,250" or null.
  String? get displayAmount {
    if (amount == null || currency == null) return null;
    return '$currency$amount';
  }
}

// ─── Known UPI / payment apps ─────────────────────────────────────────────────
//
// Keys   = package name as it appears in Android notifications.
// Values = human-readable app name shown in the UI.
//
// Add more entries here to support additional apps without touching
// the detection logic.

const Map<String, String> kUpiAppPackages = {
  'com.phonepe.app': 'PhonePe',
  'com.phonepe.app.b2b': 'PhonePe for Business',
  'net.one97.paytm': 'Paytm',
  'com.google.android.apps.nbu.paisa.user': 'Google Pay',
  'in.org.npci.upiapp': 'BHIM',
  // Correct Amazon Pay package (confirmed via reference format).
  // The old entry 'com.amazon.mShop.android.shopping' is intentionally
  // replaced — only one Amazon Pay package should be in the allowlist.
  'in.amazon.mShop.android.shopping': 'Amazon Pay',
  'com.mobikwik_new': 'MobiKwik',
  'com.freecharge.android': 'Freecharge',
  'com.axis.mobile': 'Axis Mobile',
  'com.sbi.lotusintouch': 'SBI YONO',
  'com.csam.icici.bank.imobile': 'iMobile (ICICI)',
  'com.snapwork.hdfc': 'HDFC MobileBanking',
};

// ─── Negative signals — generic (used for all non-PhonePe UPI apps) ──────────
//
// Checked BEFORE positive signals.
// NOTE: "sent to" is intentionally NOT in this generic list because PhonePe's
// confirmed incoming pattern is "sent ₹<amount> to you" — handled separately
// in _PhonePeDetector with a strict regex, not a keyword scan.

const List<String> _genericNegativeKeywords = [
  'failed',
  'failure',
  'declined',
  'pending',
  'cancelled',
  'canceled',
  'cancel',
  'cancellation',
  'refund',
  'refunded',
  'refunding',
  'reversed',
  'reversal',
  'expired',
  'request',
  'collect request',
  'requesting',
  'remind',
  'reminder',
  'debit',
  'debited',
  'paid to',
  'sent to',
];

// ─── PhonePe-specific detector ────────────────────────────────────────────────
//
// Known confirmed incoming-payment notification format (from real device test):
//
//   Text: "sent ₹1 to you."
//
// Pattern: sent ₹<amount> to you
//
// The amount can be:
//   • Integer:              1, 10, 500
//   • Comma-formatted:      1,250  10,00,000
//   • Decimal:              25.50
//   • Comma + decimal:      1,250.75
//
// IMPORTANT: "₹500 sent to Rahul" (outgoing) does NOT match this pattern
// because the regex requires the exact word order: sent ₹<amount> to you

class _PhonePeDetector {
  // Regex matches: "sent ₹<amount> to you"
  // ₹ may be followed directly by the number with no space.
  // Amount: digits with optional commas and one optional decimal part.
  // "to you" allows trailing punctuation (period, etc.).
  static final _incomingPattern = RegExp(
    r'sent\s+₹\s*([\d,]+(?:\.\d{1,2})?)\s+to\s+you',
    caseSensitive: false,
  );

  /// Negative keywords specific to PhonePe outgoing / non-payment notifications.
  /// NOTE: 'sent to' is intentionally ABSENT — "sent ₹X to you" is the valid
  /// incoming pattern. The regex will still reject bare "sent to Rahul" forms
  /// because the pattern requires the full "sent ₹amount to you" structure.
  static const _negatives = [
    'failed',
    'failure',
    'declined',
    'pending',
    'cancelled',
    'canceled',
    'cancel',
    'cancellation',
    'refund',
    'refunded',
    'refunding',
    'reversed',
    'reversal',
    'expired',
    'request',
    'collect request',
    'remind',
    'reminder',
    'debit',
    'debited',
    'paid to',
  ];

  static PaymentDetectionResult detect({
    required String packageName,
    required String appName,
    required String title,
    required String text,
  }) {
    // Work on the raw text (not lowercased) so ₹ is preserved for the regex.
    // Use lowercase only for negative keyword checks.
    final combined = '${title.toLowerCase()} ${text.toLowerCase()}';

    // 1. Check PhonePe-specific negatives first.
    for (final neg in _negatives) {
      if (combined.contains(neg)) {
        return PaymentDetectionResult(
          status: DetectionStatus.notPayment,
          packageName: packageName,
          title: title,
          text: text,
          appName: appName,
          reason: 'PhonePe: Negative signal found: "$neg"',
        );
      }
    }

    // 2. Try to match the confirmed incoming-payment pattern.
    //    Search in both title and text — PhonePe sometimes puts content in title.
    final searchIn = '$title $text';
    final match = _incomingPattern.firstMatch(searchIn);

    if (match != null) {
      final rawAmount = match.group(1) ?? '';
      // Validate: the captured group must not be empty.
      if (rawAmount.isNotEmpty) {
        debugLog(
          'PhonePe incoming payment matched. Raw amount: "$rawAmount"',
        );
        return PaymentDetectionResult(
          status: DetectionStatus.payment,
          packageName: packageName,
          title: title,
          text: text,
          appName: appName,
          reason: 'PhonePe incoming payment notification',
          amount: rawAmount,
          currency: '₹',
        );
      }
    }

    // 3. No matching pattern — not a payment we recognise.
    return PaymentDetectionResult(
      status: DetectionStatus.notPayment,
      packageName: packageName,
      title: title,
      text: text,
      appName: appName,
      reason: 'PhonePe notification does not match incoming-payment pattern.',
    );
  }
}

// ─── Paytm-specific detector ─────────────────────────────────────────────────
//
// Confirmed incoming-payment notification format (from real device test):
//
//   Title: "PAYMENT"
//   Text:  "Received ₹1 from Kaushal · Deposited in you..."
//
// Pattern: Received ₹<amount> from <sender> [optional trailing text]
//
// The amount can be:
//   • Integer:              1, 10, 500
//   • Comma-formatted:      1,250  10,00,000
//   • Decimal:              25.50
//   • Comma + decimal:      1,250.75
//
// IMPORTANT:
//   • "Received ₹<amount> from" is required — loose keywords like just
//     "Received" or just "₹" are NOT sufficient to confirm a payment.
//   • Outgoing patterns like "Sent ₹500 to Rahul" do NOT match.
//   • SMS/Google Messages notifications never reach this class because
//     com.google.android.apps.messaging is not in kUpiAppPackages.

class _PaytmDetector {
  // Regex: "received ₹<amount> from" — case-insensitive.
  // Trailing content after sender is intentionally not constrained,
  // so "Received ₹1 from Kaushal · Deposited in you..." is matched.
  static final _incomingPattern = RegExp(
    r'received\s+₹\s*([\d,]+(?:\.\d{1,2})?)\s+from',
    caseSensitive: false,
  );

  /// Negatives that indicate a non-incoming-payment Paytm notification.
  static const _negatives = [
    'failed',
    'failure',
    'declined',
    'pending',
    'cancelled',
    'canceled',
    'cancel',
    'cancellation',
    'refund',
    'refunded',
    'refunding',
    'reversed',
    'reversal',
    'expired',
    'request',
    'collect request',
    'remind',
    'reminder',
    'debit',
    'debited',
    'sent to',
    'paid to',
  ];

  static PaymentDetectionResult detect({
    required String packageName,
    required String appName,
    required String title,
    required String text,
  }) {
    final combined = '${title.toLowerCase()} ${text.toLowerCase()}';

    // 1. Check negatives first — any match means NOT a payment.
    for (final neg in _negatives) {
      if (combined.contains(neg)) {
        return PaymentDetectionResult(
          status: DetectionStatus.notPayment,
          packageName: packageName,
          title: title,
          text: text,
          appName: appName,
          reason: 'Paytm: Negative signal found: "$neg"',
        );
      }
    }

    // 2. Try to match the confirmed incoming-payment pattern.
    //    Search across title + text — Paytm may put text in either field.
    final searchIn = '$title $text';
    final match = _incomingPattern.firstMatch(searchIn);

    if (match != null) {
      final rawAmount = match.group(1) ?? '';
      if (rawAmount.isNotEmpty) {
        debugLog('Paytm incoming payment matched. Raw amount: "$rawAmount"');
        return PaymentDetectionResult(
          status: DetectionStatus.payment,
          packageName: packageName,
          title: title,
          text: text,
          appName: appName,
          reason: 'Paytm incoming payment notification',
          amount: rawAmount,
          currency: '₹',
        );
      }
    }

    // 3. No matching pattern — not a payment we recognise.
    return PaymentDetectionResult(
      status: DetectionStatus.notPayment,
      packageName: packageName,
      title: title,
      text: text,
      appName: appName,
      reason: 'Paytm notification does not match incoming-payment pattern.',
    );
  }
}

// ─── Google Pay-specific detector ────────────────────────────────────────────
//
// Reference incoming-payment notification format (NOT yet verified on device):
//
//   Title: "Kaushal Patil Dattakala: Kaushal Patil Dattakala"
//   Text:  "Kaushal Patil Dattakala sent ₹1 to you."
//
// Pattern: <sender> sent ₹<amount> to you
//
// IMPORTANT:
//   • "You sent ₹500 to Rahul" (outgoing) does NOT match because the regex
//     requires text *before* "sent" that is NOT "you".
//   • Bare "₹", "sent", or "payment" alone are NOT sufficient.

class _GooglePayDetector {
  // Regex: "<something-not-'you'> sent ₹<amount> to you"
  // The leading \S+ ensures at least one non-whitespace sender token exists
  // before the word "sent", which rules out "You sent ₹..."
  static final _incomingPattern = RegExp(
    r'(?<!\byou\b.{0,5})\bsent\s+₹\s*([\d,]+(?:\.\d{1,2})?)\s+to\s+you',
    caseSensitive: false,
  );

  // Simpler complementary approach: reject if the text starts with "you sent"
  static final _outgoingYouSent = RegExp(
    r'^\s*you\s+sent\b',
    caseSensitive: false,
  );

  static const _negatives = [
    'failed',
    'failure',
    'declined',
    'pending',
    'cancelled',
    'canceled',
    'cancel',
    'cancellation',
    'refund',
    'refunded',
    'refunding',
    'reversed',
    'reversal',
    'expired',
    'request',
    'collect request',
    'remind',
    'reminder',
    'debit',
    'debited',
    'paid to',
  ];

  static PaymentDetectionResult detect({
    required String packageName,
    required String appName,
    required String title,
    required String text,
  }) {
    final combined = '${title.toLowerCase()} ${text.toLowerCase()}';
    final searchIn = '$title $text';

    // 1. Explicit outgoing rejection: "you sent ₹... to <someone>".
    if (_outgoingYouSent.hasMatch(text) || _outgoingYouSent.hasMatch(title)) {
      return PaymentDetectionResult(
        status: DetectionStatus.notPayment,
        packageName: packageName,
        title: title,
        text: text,
        appName: appName,
        reason: 'Google Pay: Outgoing payment ("you sent ...") — not incoming.',
      );
    }

    // 2. Negative keywords.
    for (final neg in _negatives) {
      if (combined.contains(neg)) {
        return PaymentDetectionResult(
          status: DetectionStatus.notPayment,
          packageName: packageName,
          title: title,
          text: text,
          appName: appName,
          reason: 'Google Pay: Negative signal found: "$neg"',
        );
      }
    }

    // 3. Match incoming-payment pattern: "<sender> sent ₹<amount> to you".
    final match = _incomingPattern.firstMatch(searchIn);
    if (match != null) {
      final rawAmount = match.group(1) ?? '';
      if (rawAmount.isNotEmpty) {
        debugLog('Google Pay incoming payment matched. Amount: "$rawAmount"');
        return PaymentDetectionResult(
          status: DetectionStatus.payment,
          packageName: packageName,
          title: title,
          text: text,
          appName: appName,
          reason: 'Google Pay incoming payment notification',
          amount: rawAmount,
          currency: '₹',
        );
      }
    }

    return PaymentDetectionResult(
      status: DetectionStatus.notPayment,
      packageName: packageName,
      title: title,
      text: text,
      appName: appName,
      reason: 'Google Pay: Notification does not match incoming-payment pattern.',
    );
  }
}

// ─── Amazon Pay-specific detector ─────────────────────────────────────────────
//
// Reference incoming-payment notification format (NOT yet verified on device):
//
//   Title: "Amazon Pay"
//   Text:  "You received ₹1 from Kaushal Patil Dattakala."
//
// Pattern: You received ₹<amount> from <sender>

class _AmazonPayDetector {
  // Regex: "you received ₹<amount> from" — case-insensitive.
  static final _incomingPattern = RegExp(
    r'you\s+received\s+₹\s*([\d,]+(?:\.\d{1,2})?)\s+from',
    caseSensitive: false,
  );

  static const _negatives = [
    'failed',
    'failure',
    'declined',
    'pending',
    'cancelled',
    'canceled',
    'cancel',
    'cancellation',
    'refund',
    'refunded',
    'refunding',
    'reversed',
    'reversal',
    'expired',
    'request',
    'collect request',
    'remind',
    'reminder',
    'debit',
    'debited',
    'sent to',
    'paid to',
  ];

  static PaymentDetectionResult detect({
    required String packageName,
    required String appName,
    required String title,
    required String text,
  }) {
    final combined = '${title.toLowerCase()} ${text.toLowerCase()}';
    final searchIn = '$title $text';

    // 1. Negative keywords first.
    for (final neg in _negatives) {
      if (combined.contains(neg)) {
        return PaymentDetectionResult(
          status: DetectionStatus.notPayment,
          packageName: packageName,
          title: title,
          text: text,
          appName: appName,
          reason: 'Amazon Pay: Negative signal found: "$neg"',
        );
      }
    }

    // 2. Match incoming-payment pattern: "You received ₹<amount> from <sender>".
    final match = _incomingPattern.firstMatch(searchIn);
    if (match != null) {
      final rawAmount = match.group(1) ?? '';
      if (rawAmount.isNotEmpty) {
        debugLog('Amazon Pay incoming payment matched. Amount: "$rawAmount"');
        return PaymentDetectionResult(
          status: DetectionStatus.payment,
          packageName: packageName,
          title: title,
          text: text,
          appName: appName,
          reason: 'Amazon Pay incoming payment notification',
          amount: rawAmount,
          currency: '₹',
        );
      }
    }

    return PaymentDetectionResult(
      status: DetectionStatus.notPayment,
      packageName: packageName,
      title: title,
      text: text,
      appName: appName,
      reason: 'Amazon Pay: Notification does not match incoming-payment pattern.',
    );
  }
}

// ─── BHIM-specific detector ───────────────────────────────────────────────────
//
// Reference incoming-payment notification format (NOT yet verified on device):
//
//   Title: "BHIM"
//   Text:  "₹1 received from Kaushal Patil Dattakala."
//
// Pattern: ₹<amount> received from <sender>

class _BhimDetector {
  // Regex: "₹<amount> received from" — case-insensitive.
  static final _incomingPattern = RegExp(
    r'₹\s*([\d,]+(?:\.\d{1,2})?)\s+received\s+from',
    caseSensitive: false,
  );

  static const _negatives = [
    'failed',
    'failure',
    'declined',
    'pending',
    'cancelled',
    'canceled',
    'cancel',
    'cancellation',
    'refund',
    'refunded',
    'refunding',
    'reversed',
    'reversal',
    'expired',
    'request',
    'collect request',
    'remind',
    'reminder',
    'debit',
    'debited',
    'sent to',
    'paid to',
  ];

  static PaymentDetectionResult detect({
    required String packageName,
    required String appName,
    required String title,
    required String text,
  }) {
    final combined = '${title.toLowerCase()} ${text.toLowerCase()}';
    final searchIn = '$title $text';

    // 1. Negative keywords first.
    for (final neg in _negatives) {
      if (combined.contains(neg)) {
        return PaymentDetectionResult(
          status: DetectionStatus.notPayment,
          packageName: packageName,
          title: title,
          text: text,
          appName: appName,
          reason: 'BHIM: Negative signal found: "$neg"',
        );
      }
    }

    // 2. Match incoming-payment pattern: "₹<amount> received from <sender>".
    final match = _incomingPattern.firstMatch(searchIn);
    if (match != null) {
      final rawAmount = match.group(1) ?? '';
      if (rawAmount.isNotEmpty) {
        debugLog('BHIM incoming payment matched. Amount: "$rawAmount"');
        return PaymentDetectionResult(
          status: DetectionStatus.payment,
          packageName: packageName,
          title: title,
          text: text,
          appName: appName,
          reason: 'BHIM incoming payment notification',
          amount: rawAmount,
          currency: '₹',
        );
      }
    }

    return PaymentDetectionResult(
      status: DetectionStatus.notPayment,
      packageName: packageName,
      title: title,
      text: text,
      appName: appName,
      reason: 'BHIM: Notification does not match incoming-payment pattern.',
    );
  }
}

// ─── Generic UPI detector (MobiKwik, Freecharge, bank apps, etc.) ─────────────
//
// Last-resort fallback — only used when no app-specific detector exists.
// Requires BOTH a positive keyword AND an amount-like pattern (₹\d).
// Amount extraction is NOT attempted — format is not yet confirmed.
// Conservative: an ambiguous notification is silently rejected.

/// Matches a rupee amount pattern: ₹ followed immediately by a digit.
/// Used to guard the generic detector against bare keyword-only matches.
final _genericAmountPresent = RegExp(r'₹\s*\d', caseSensitive: false);

class _GenericUpiDetector {
  static PaymentDetectionResult detect({
    required String packageName,
    required String appName,
    required String title,
    required String text,
  }) {
    final combined = '${title.toLowerCase()} ${text.toLowerCase()}';

    // 1. Negative signals — checked first.
    for (final neg in _genericNegativeKeywords) {
      if (combined.contains(neg)) {
        return PaymentDetectionResult(
          status: DetectionStatus.notPayment,
          packageName: packageName,
          title: title,
          text: text,
          appName: appName,
          reason: 'Negative signal found: "$neg"',
        );
      }
    }

    // 2. Must have a ₹-amount pattern — bare keywords like 'received' alone
    //    are insufficient to confirm a payment from an unverified app.
    final hasAmount = _genericAmountPresent.hasMatch('$title $text');
    if (!hasAmount) {
      return PaymentDetectionResult(
        status: DetectionStatus.notPayment,
        packageName: packageName,
        title: title,
        text: text,
        appName: appName,
        reason: 'No ₹-amount pattern found — not confirming as payment.',
      );
    }

    // 3. Positive signals — at least one must match.
    final matched = <String>[];
    // Use a tighter subset — exclude bare '₹' and 'inr' as standalone signals.
    const positiveSubset = [
      'received',
      'credited',
      'credit',
      'money received',
      'payment received',
      'upi payment received',
      'amount received',
      'amount credited',
    ];
    for (final pos in positiveSubset) {
      if (combined.contains(pos)) matched.add(pos);
    }

    if (matched.isNotEmpty) {
      return PaymentDetectionResult(
        status: DetectionStatus.payment,
        packageName: packageName,
        title: title,
        text: text,
        appName: appName,
        reason: 'Payment keywords found: ${matched.join(", ")}',
        // Amount not extracted — format for this app is not yet confirmed.
        amount: null,
        currency: null,
      );
    }

    return PaymentDetectionResult(
      status: DetectionStatus.notPayment,
      packageName: packageName,
      title: title,
      text: text,
      appName: appName,
      reason: 'From UPI app "$appName" but no confirmed payment pattern found.',
    );
  }
}

// ─── Main entry point ─────────────────────────────────────────────────────────

class UpiNotificationDetector {
  /// Analyse a single notification and return a [PaymentDetectionResult].
  ///
  /// [packageName] — Android package name of the source app.
  /// [title]       — Notification title (may be empty).
  /// [text]        — Notification body text (may be empty).
  static PaymentDetectionResult detect({
    required String packageName,
    required String title,
    required String text,
  }) {
    // Guard against null-ish inputs.
    final safeTitle = title.trim();
    final safeText  = text.trim();

    // 1. Is this from a known UPI app?
    final appName = kUpiAppPackages[packageName];
    if (appName == null) {
      return PaymentDetectionResult(
        status: DetectionStatus.notPayment,
        packageName: packageName,
        title: safeTitle,
        text: safeText,
        appName: _fallbackAppName(packageName),
        reason: 'Package "$packageName" is not a known UPI app.',
      );
    }

    debugLog('Detecting | Package: $packageName | Title: "$safeTitle" | Text: "$safeText"');

    // 2. Route to the appropriate app-specific detector.
    switch (packageName) {
      case 'com.phonepe.app':
      case 'com.phonepe.app.b2b':
        return _PhonePeDetector.detect(
          packageName: packageName,
          appName: appName,
          title: safeTitle,
          text: safeText,
        );

      case 'net.one97.paytm':
        return _PaytmDetector.detect(
          packageName: packageName,
          appName: appName,
          title: safeTitle,
          text: safeText,
        );

      case 'com.google.android.apps.nbu.paisa.user':
        return _GooglePayDetector.detect(
          packageName: packageName,
          appName: appName,
          title: safeTitle,
          text: safeText,
        );

      case 'in.amazon.mShop.android.shopping':
        return _AmazonPayDetector.detect(
          packageName: packageName,
          appName: appName,
          title: safeTitle,
          text: safeText,
        );

      case 'in.org.npci.upiapp':
        return _BhimDetector.detect(
          packageName: packageName,
          appName: appName,
          title: safeTitle,
          text: safeText,
        );

      default:
        // All other known UPI apps fall back to the generic keyword detector
        // until their real notification format has been confirmed on a device.
        return _GenericUpiDetector.detect(
          packageName: packageName,
          appName: appName,
          title: safeTitle,
          text: safeText,
        );
    }
  }

  /// Best-effort human name from a raw package name (non-UPI apps).
  static String _fallbackAppName(String packageName) {
    const extras = <String, String>{
      'com.whatsapp': 'WhatsApp',
      'com.whatsapp.w4b': 'WhatsApp Business',
      'com.instagram.android': 'Instagram',
      'com.facebook.katana': 'Facebook',
      'com.twitter.android': 'Twitter / X',
      'com.google.android.apps.messaging': 'Messages',
      'com.android.systemui': 'System UI',
      'com.android.phone': 'Phone',
    };
    if (extras.containsKey(packageName)) return extras[packageName]!;
    final parts = packageName.split('.');
    final last = parts.last;
    if (last.isEmpty) return packageName;
    return last[0].toUpperCase() + last.substring(1);
  }
}

// ─── Logging helper ───────────────────────────────────────────────────────────

// ignore: avoid_print
void debugLog(String message) => print('MyUPI_DETECTOR: $message');
