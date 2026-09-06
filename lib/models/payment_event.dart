// lib/models/payment_event.dart
//
// Standard Payment Event Domain Model — Milestone 18
// ----------------------------------------------------
// Represents a detected or verified payment within the MyUPI system.
//
// Core principles:
//   1. Notification-detected payments are NEVER labeled as VERIFIED.
//      They always have:
//        source = PaymentSource.notification
//        verificationStatus = VerificationStatus.notVerified
//   2. The trustLevel indicates the confidence of the local regex parser
//      (high, medium, low).
//   3. Future payment aggregator webhooks will produce events with:
//        source = PaymentSource.paymentProvider
//        verificationStatus = VerificationStatus.verified

enum TrustLevel {
  high,
  medium,
  low,
}

enum VerificationStatus {
  notVerified,
  verified,
  failed,
  unknown,
}

enum PaymentSource {
  notification,
  paymentProvider,
  unknown,
}

class PaymentEvent {
  final String amount;
  final String appName;
  final DateTime timestamp;
  final TrustLevel trustLevel;
  final VerificationStatus verificationStatus;
  final PaymentSource source;
  final int parserVersion;

  const PaymentEvent({
    required this.amount,
    required this.appName,
    required this.timestamp,
    this.trustLevel = TrustLevel.high,
    this.verificationStatus = VerificationStatus.notVerified,
    this.source = PaymentSource.notification,
    this.parserVersion = 1,
  });

  /// Display-ready formatted amount, e.g. "₹500".
  String get displayAmount => '₹$amount';

  /// Whether this payment has been cryptographically confirmed by a bank/PA.
  /// For notification MVP, this is ALWAYS false.
  bool get isVerified => verificationStatus == VerificationStatus.verified;

  /// Human-readable time label (e.g. "Today, 10:30 AM" or "Yesterday, 4:15 PM").
  String get timeLabel {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yest  = today.subtract(const Duration(days: 1));
    final d     = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final t     = formatTimeOnly(timestamp);
    if (d == today) return 'Today, $t';
    if (d == yest)  return 'Yesterday, $t';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}, $t';
  }

  static String formatTimeOnly(DateTime dt) {
    final h    = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m    = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  /// Create a PaymentEvent from a Map (e.g. from Kotlin SharedPreferences via MethodChannel).
  /// Safe against missing fields in older records (data migration safety).
  factory PaymentEvent.fromMap(Map<dynamic, dynamic> map) {
    final rawAmount = (map['amount'] as String?) ?? '';
    final rawAppName = (map['appName'] as String?) ?? '';
    final timestampMs = (map['timestampMs'] as int?) ?? 0;

    // Parse TrustLevel (HIGH, MEDIUM, LOW)
    final trustStr = ((map['trustLevel'] as String?) ?? 'HIGH').toUpperCase();
    final trust = switch (trustStr) {
      'MEDIUM' => TrustLevel.medium,
      'LOW'    => TrustLevel.low,
      _        => TrustLevel.high,
    };

    // Parse VerificationStatus (defaults to notVerified for migration safety)
    final verStr = ((map['verificationStatus'] as String?) ?? 'NOT_VERIFIED').toUpperCase();
    final verStatus = switch (verStr) {
      'VERIFIED' => VerificationStatus.verified,
      'FAILED'   => VerificationStatus.failed,
      'UNKNOWN'  => VerificationStatus.unknown,
      _          => VerificationStatus.notVerified,
    };

    // Parse PaymentSource (defaults to notification for migration safety)
    final srcStr = ((map['source'] as String?) ?? 'NOTIFICATION').toUpperCase();
    final src = switch (srcStr) {
      'PAYMENT_PROVIDER' => PaymentSource.paymentProvider,
      'UNKNOWN'          => PaymentSource.unknown,
      _                  => PaymentSource.notification,
    };

    final pVersion = (map['parserVersion'] as int?) ?? 1;

    return PaymentEvent(
      amount: rawAmount,
      appName: rawAppName,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
      trustLevel: trust,
      verificationStatus: verStatus,
      source: src,
      parserVersion: pVersion,
    );
  }

  /// Convert to JSON-compatible Map for MethodChannel transfer or local persistence.
  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'appName': appName,
      'timestampMs': timestamp.millisecondsSinceEpoch,
      'trustLevel': trustLevel.name.toUpperCase(),
      'verificationStatus': switch (verificationStatus) {
        VerificationStatus.verified => 'VERIFIED',
        VerificationStatus.failed => 'FAILED',
        VerificationStatus.unknown => 'UNKNOWN',
        VerificationStatus.notVerified => 'NOT_VERIFIED',
      },
      'source': switch (source) {
        PaymentSource.paymentProvider => 'PAYMENT_PROVIDER',
        PaymentSource.unknown => 'UNKNOWN',
        PaymentSource.notification => 'NOTIFICATION',
      },
      'parserVersion': parserVersion,
    };
  }

  @override
  String toString() =>
      'PaymentEvent(amount: $amount, app: $appName, status: $verificationStatus, source: $source)';
}
