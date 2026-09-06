// lib/services/payment_source.dart
//
// Payment Source Architecture — Milestone 18
// -------------------------------------------
// Separates the concept of:
//   1. Payment Detection:
//      "An allowed UPI app produced an Android notification matching our strict regex parser."
//   2. Payment Verification:
//      "A legitimate authorized payment provider/backend independently verified the transaction."
//
// The current MVP only supports NotificationPaymentSource.
// FutureVerifiedPaymentSource is an architectural contract / extension point only.

import '../models/payment_event.dart';

/// Abstract contract for any mechanism that supplies payment events to MyUPI.
abstract class PaymentSourceProvider {
  const PaymentSourceProvider();

  /// Unique identifier of the payment source (e.g. 'notification', 'payment_provider').
  String get sourceId;

  /// Domain model enum category of this source.
  PaymentSource get sourceType;

  /// User-friendly label.
  String get displayName;

  /// Whether payments from this source are considered cryptographically verified.
  bool get providesVerification;

  /// Alias for verification capability.
  bool get isVerificationCapable => providesVerification;
}

/// Notification-based payment detector (Current Production MVP).
///
/// Observes Android StatusBarNotifications from trusted UPI packages
/// and strictly parses payment amounts.
///
/// NOTE: Provides detection ONLY, NOT cryptographic verification.
class NotificationPaymentSource extends PaymentSourceProvider {
  const NotificationPaymentSource();

  @override
  String get sourceId => 'notification';

  @override
  PaymentSource get sourceType => PaymentSource.notification;

  @override
  String get displayName => 'Android Notification Listener';

  @override
  bool get providesVerification => false;
}

/// Future extension point for licensed Payment Aggregators (Razorpay, Cashfree, PhonePe PG).
///
/// In a future milestone, this source will receive authenticated webhooks or push tokens
/// from a secure backend to provide bank-confirmed payments.
///
/// NOT implemented in current MVP.
class FutureVerifiedPaymentSource extends PaymentSourceProvider {
  final String providerName;

  const FutureVerifiedPaymentSource({this.providerName = 'GenericPA'});

  @override
  String get sourceId => 'payment_provider';

  @override
  PaymentSource get sourceType => PaymentSource.paymentProvider;

  @override
  String get displayName => 'Payment Aggregator ($providerName)';

  @override
  bool get providesVerification => true;
}
