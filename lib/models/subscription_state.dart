// lib/models/subscription_state.dart
//
// Subscription State & Product Architecture — Milestone 19
// --------------------------------------------------------
// Represents the commercial lifecycle of a merchant's MyUPI Soundbox subscription.
//
// Commercial Model:
//   • Introductory Offer: ₹1 for the first month
//   • Recurring Price:    ₹49/month
//
// NOTE: Actual billing (Google Play / Payment Gateways) is NOT implemented in this milestone.
// The default state for new merchants is INTRO_OFFER_AVAILABLE.

enum SubscriptionState {
  notSubscribed,
  introOfferAvailable,
  active,
  gracePeriod,
  expired,
  cancelled,
  unknown;

  static SubscriptionState fromString(String? val) {
    if (val == null) return SubscriptionState.introOfferAvailable;
    switch (val.trim().toUpperCase()) {
      case 'NOT_SUBSCRIBED':
        return SubscriptionState.notSubscribed;
      case 'INTRO_OFFER_AVAILABLE':
        return SubscriptionState.introOfferAvailable;
      case 'ACTIVE':
        return SubscriptionState.active;
      case 'GRACE_PERIOD':
      case 'GRACE':
        return SubscriptionState.gracePeriod;
      case 'EXPIRED':
        return SubscriptionState.expired;
      case 'CANCELLED':
      case 'CANCELED':
        return SubscriptionState.cancelled;
      default:
        return SubscriptionState.introOfferAvailable;
    }
  }

  String toStorageKey() {
    switch (this) {
      case SubscriptionState.notSubscribed:
        return 'NOT_SUBSCRIBED';
      case SubscriptionState.introOfferAvailable:
        return 'INTRO_OFFER_AVAILABLE';
      case SubscriptionState.active:
        return 'ACTIVE';
      case SubscriptionState.gracePeriod:
        return 'GRACE_PERIOD';
      case SubscriptionState.expired:
        return 'EXPIRED';
      case SubscriptionState.cancelled:
        return 'CANCELLED';
      case SubscriptionState.unknown:
        return 'UNKNOWN';
    }
  }

  String get label {
    switch (this) {
      case SubscriptionState.notSubscribed:
        return 'Free Plan';
      case SubscriptionState.introOfferAvailable:
        return 'Intro Offer Available';
      case SubscriptionState.active:
        return 'MyUPI Premium Active';
      case SubscriptionState.gracePeriod:
        return 'Grace Period';
      case SubscriptionState.expired:
        return 'Plan Expired';
      case SubscriptionState.cancelled:
        return 'Cancelled (Active Until Period End)';
      case SubscriptionState.unknown:
        return 'Standard Plan';
    }
  }

  /// Whether this state grants access to advanced/premium features.
  /// Only ACTIVE, GRACE_PERIOD, and CANCELLED (until end date) grant premium access.
  bool get hasPremiumEntitlement {
    switch (this) {
      case SubscriptionState.active:
      case SubscriptionState.gracePeriod:
      case SubscriptionState.cancelled:
        return true;
      case SubscriptionState.notSubscribed:
      case SubscriptionState.introOfferAvailable:
      case SubscriptionState.expired:
      case SubscriptionState.unknown:
        return false;
    }
  }
}

/// Rich domain model representing the current subscription details.
class SubscriptionInfo {
  final SubscriptionState state;
  final int introPriceRupees;
  final int regularPriceRupees;
  final String currency;
  final DateTime? expiresAt;
  final bool isAutoRenewing;
  final bool isSimulated;

  const SubscriptionInfo({
    this.state = SubscriptionState.introOfferAvailable,
    this.introPriceRupees = 1,
    this.regularPriceRupees = 49,
    this.currency = '₹',
    this.expiresAt,
    this.isAutoRenewing = false,
    this.isSimulated = false,
  });

  /// Formatted headline for the introductory offer.
  String get introOfferHeadline => '$currency$introPriceRupees for your first month';

  /// Formatted recurring price notice.
  String get recurringPriceNotice => 'Then $currency$regularPriceRupees/month';

  /// Complete pricing statement for paywall and terms.
  String get fullPricingDisclosure =>
      '$currency$introPriceRupees for first month, then $currency$regularPriceRupees/month. Renews automatically unless cancelled.';

  SubscriptionInfo copyWith({
    SubscriptionState? state,
    int? introPriceRupees,
    int? regularPriceRupees,
    String? currency,
    DateTime? expiresAt,
    bool? isAutoRenewing,
    bool? isSimulated,
  }) {
    return SubscriptionInfo(
      state: state ?? this.state,
      introPriceRupees: introPriceRupees ?? this.introPriceRupees,
      regularPriceRupees: regularPriceRupees ?? this.regularPriceRupees,
      currency: currency ?? this.currency,
      expiresAt: expiresAt ?? this.expiresAt,
      isAutoRenewing: isAutoRenewing ?? this.isAutoRenewing,
      isSimulated: isSimulated ?? this.isSimulated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'state': state.toStorageKey(),
      'introPriceRupees': introPriceRupees,
      'regularPriceRupees': regularPriceRupees,
      'currency': currency,
      'expiresAtMs': expiresAt?.millisecondsSinceEpoch,
      'isAutoRenewing': isAutoRenewing,
      'isSimulated': isSimulated,
    };
  }

  factory SubscriptionInfo.fromMap(Map<dynamic, dynamic> map) {
    return SubscriptionInfo(
      state: SubscriptionState.fromString(map['state'] as String?),
      introPriceRupees: (map['introPriceRupees'] as int?) ?? 1,
      regularPriceRupees: (map['regularPriceRupees'] as int?) ?? 49,
      currency: (map['currency'] as String?) ?? '₹',
      expiresAt: map['expiresAtMs'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expiresAtMs'] as int)
          : null,
      isAutoRenewing: (map['isAutoRenewing'] as bool?) ?? false,
      isSimulated: (map['isSimulated'] as bool?) ?? false,
    );
  }
}
