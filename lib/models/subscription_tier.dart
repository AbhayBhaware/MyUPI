// lib/models/subscription_tier.dart
//
// Subscription-Ready Foundation — Milestone 18
// ---------------------------------------------
// Architectural preparation for future commercial tiers.
// Defaults strictly to FREE.
// No billing SDKs, no payment collection, no server validation.

enum SubscriptionTier {
  free,
  premium;

  static SubscriptionTier fromString(String? val) {
    if (val == null) return SubscriptionTier.free;
    switch (val.trim().toUpperCase()) {
      case 'PREMIUM':
        return SubscriptionTier.premium;
      case 'FREE':
      default:
        return SubscriptionTier.free;
    }
  }

  String get label => switch (this) {
        SubscriptionTier.free => 'FREE',
        SubscriptionTier.premium => 'PREMIUM',
      };
}
