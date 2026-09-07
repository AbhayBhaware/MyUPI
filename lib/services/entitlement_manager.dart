// lib/services/entitlement_manager.dart
//
// Centralized Subscription Entitlement Layer — Milestone 19
// ---------------------------------------------------------
// Manages feature access decisions across MyUPI.
//
// Architectural Rules:
//   1. NEVER scatter `if (isPremium)` checks across screens and widgets.
//   2. Core soundbox capabilities (detection, deduplication, native TTS,
//      local history, privacy) MUST NEVER be blocked by subscription state.
//   3. High-tier features (shop name in voice, export, advanced analytics)
//      are queried through this centralized manager.

import '../models/subscription_state.dart';

class EntitlementManager {
  final SubscriptionState subscriptionState;

  const EntitlementManager({required this.subscriptionState});

  // ── Protected Core Capabilities (NEVER BLOCKED) ───────────────────────────

  /// Core soundbox audio announcement engine is always operational.
  bool get isCoreSoundboxAllowed => true;

  /// Background notification listener & strict UPI parser are always operational.
  bool get canDetectUpiPayments => true;

  /// Native Android Text-to-Speech is always available for valid payments.
  bool get canUseNativeTts => true;

  /// 45-second duplicate payment protection is always active.
  bool get isDuplicateProtectionActive => true;

  /// Local on-device ledger storage is always active.
  bool get canStorePaymentHistory => true;

  /// Zero-PII privacy filtering is always enforced.
  bool get isPrivacyProtectionGuaranteed => true;

  // ── Premium Gated Features ────────────────────────────────────────────────

  /// Whether the current subscription state has active premium privileges.
  bool get isPremium => subscriptionState.hasPremiumEntitlement;

  /// Multi-language voice announcements across all 8 supported Indian languages.
  /// (In current MVP free tier, standard languages like English and Hindi are open).
  bool canUseLanguage(String langCode) {
    if (isPremium) return true;
    // Free tier includes English (India) and Hindi
    return langCode == 'en-IN' || langCode == 'hi-IN';
  }

  /// All 8 Indian languages accessible simultaneously.
  bool get canUseAllIndianLanguages => isPremium;

  /// Advanced announcement formats (Format B and Format C).
  /// Format A ("Payment received, 500 rupees") is available to all merchants.
  bool canUseAnnouncementFormat(String format) {
    if (isPremium) return true;
    return format == 'A'; // Format A is always free
  }

  /// Customizing announcement format beyond Format A.
  bool get canUseAdvancedAnnouncements => isPremium;

  /// Announcing merchant shop name in voice audio ("Payment received at [Shop Name]").
  bool get canCustomizeShopAnnouncement => isPremium;

  /// Advanced analytics, trends, and collection reports.
  bool get canUseAdvancedAnalytics => isPremium;

  /// Exporting payment history as CSV / PDF.
  bool get canExportHistory => isPremium;

  /// Extended payment history depth (e.g. 500 records vs 50 records).
  bool get canUseExtendedHistory => isPremium;

  /// Maximum stored records allowed based on tier.
  int get maxHistoryRecords => isPremium ? 500 : 50;

  /// Summary description of current tier entitlement.
  String get planDescription {
    switch (subscriptionState) {
      case SubscriptionState.active:
        return 'Full access to all 8 languages, shop voice branding, and advanced soundbox features.';
      case SubscriptionState.gracePeriod:
        return 'Subscription requires renewal. Premium benefits remain active temporarily.';
      case SubscriptionState.cancelled:
        return 'Subscription cancelled. Premium benefits active until period end.';
      case SubscriptionState.introOfferAvailable:
        return 'Free soundbox with ₹1 first-month intro offer available.';
      case SubscriptionState.expired:
        return 'Standard soundbox. Upgrade to re-enable shop branding and regional voices.';
      case SubscriptionState.notSubscribed:
      case SubscriptionState.unknown:
        return 'Standard soundbox active.';
    }
  }
}
