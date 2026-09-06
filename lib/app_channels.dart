// lib/app_channels.dart
//
// Shared channel constants, exports, and backward-compatible models.
// Milestone 18 — Architecture Foundation & Future Verification Readiness

import 'package:flutter/services.dart';

import 'models/payment_event.dart';

export 'models/payment_event.dart';
export 'models/merchant_profile.dart';
export 'models/feature_flags.dart';
export 'models/subscription_tier.dart';
export 'repositories/payment_repository.dart';
export 'services/payment_source.dart';

// ─── Channel references ───────────────────────────────────────────────────────

const kMethodChannel = MethodChannel('com.example.myupi/notification_access');
const kEventChannel  = EventChannel('com.example.myupi/notification_stream');

// ─── Backward-compatible PaymentRecord ────────────────────────────────────────

class PaymentRecord extends PaymentEvent {
  const PaymentRecord({
    required super.amount,
    required super.appName,
    required super.timestamp,
    dynamic trustLevel = TrustLevel.high,
    super.verificationStatus = VerificationStatus.notVerified,
    super.source = PaymentSource.notification,
    super.parserVersion = 1,
  }) : super(
          trustLevel: trustLevel is TrustLevel
              ? trustLevel
              : (trustLevel == 'MEDIUM'
                  ? TrustLevel.medium
                  : (trustLevel == 'LOW' ? TrustLevel.low : TrustLevel.high)),
        );
}

// ─── Live payment event (from EventChannel while UI is open) ─────────────────

class LivePaymentEvent {
  final String amount;
  final String appName;
  final DateTime receivedAt;

  const LivePaymentEvent({
    required this.amount,
    required this.appName,
    required this.receivedAt,
  });

  String get displayAmount => '₹$amount';
  String get timeLabel     => PaymentEvent.formatTimeOnly(receivedAt);
}
