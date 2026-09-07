// lib/services/billing_service.dart
//
// Google Play Subscription Billing Service — Milestone 20
// --------------------------------------------------------
// Implements real Google Play subscription billing using the official Flutter
// `in_app_purchase` package backed by Android Billing Library 6/7.
//
// Features:
//   • Queries `myupi_soundbox_pro` subscription product details dynamically
//   • Resolves base plan (`monthly-recurring`) and intro offer (`intro-offer-1inr`)
//   • Mandatory purchase acknowledgement (`completePurchase`) within 3 days
//   • Restoration of existing active subscriptions (`restorePurchases`)
//   • Token sanitization (zero full token exposure in logs or UI)
//   • Isolated from core notification soundbox (soundbox never fails if billing fails)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';

import 'subscription_manager.dart';

/// Commercial Product & Plan Constants for Google Play Console.
class BillingConstants {
  static const String subscriptionId = 'myupi_soundbox_pro';
  static const String basePlanId = 'monthly-recurring';
  static const String introOfferId = 'intro-offer-1inr';

  // Default display fallbacks if Play Store is connecting or offline
  static const String defaultIntroPrice = '₹1';
  static const String defaultRecurringPrice = '₹49/month';
}

/// Result object for purchase restoration.
class RestorePurchasesResult {
  final bool success;
  final int restoredCount;
  final String message;

  const RestorePurchasesResult({
    required this.success,
    required this.restoredCount,
    required this.message,
  });
}

class BillingService {
  BillingService._internal();
  static final BillingService instance = BillingService._internal();

  InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool _isAvailable = false;
  bool _isLoadingProduct = false;
  ProductDetails? _productDetails;
  String _introPriceDisplay = BillingConstants.defaultIntroPrice;
  String _recurringPriceDisplay = BillingConstants.defaultRecurringPrice;
  String? _lastErrorMessage;
  bool _lastPurchaseAcknowledged = false;
  String? _lastPurchaseTokenSanitized;
  DateTime? _lastRefreshTime;
  String? _selectedOfferToken;

  // ── Public Getters for UI & Diagnostics ─────────────────────────────────────

  bool get isAvailable => _isAvailable;
  bool get isLoadingProduct => _isLoadingProduct;
  ProductDetails? get productDetails => _productDetails;
  String get introPriceDisplay => _introPriceDisplay;
  String get recurringPriceDisplay => _recurringPriceDisplay;
  String? get lastErrorMessage => _lastErrorMessage;
  bool get lastPurchaseAcknowledged => _lastPurchaseAcknowledged;
  String? get lastPurchaseTokenSanitized => _lastPurchaseTokenSanitized;
  DateTime? get lastRefreshTime => _lastRefreshTime;
  String? get selectedOfferToken => _selectedOfferToken;

  /// Visible for testing: inject custom InAppPurchase instance.
  @visibleForTesting
  void setInAppPurchaseInstance(InAppPurchase iap) {
    _iap = iap;
  }

  /// Initialize billing client and purchase stream listener.
  Future<void> initialize() async {
    try {
      _isAvailable = await _iap.isAvailable();
    } catch (e) {
      _isAvailable = false;
      _lastErrorMessage = 'Billing service unavailable: $e';
    }

    _purchaseSubscription?.cancel();
    _purchaseSubscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _purchaseSubscription?.cancel(),
      onError: (error) {
        _lastErrorMessage = 'Billing stream error: $error';
      },
    );

    if (_isAvailable) {
      await queryProducts();
    }
  }

  /// Dispose listeners when shutting down.
  void dispose() {
    _purchaseSubscription?.cancel();
  }

  /// Queries the subscription product details and pricing phases from Google Play.
  Future<ProductDetails?> queryProducts() async {
    if (!_isAvailable) {
      _lastErrorMessage = 'Google Play Billing is not available on this device.';
      return null;
    }

    _isLoadingProduct = true;
    _lastErrorMessage = null;

    try {
      final ProductDetailsResponse response =
          await _iap.queryProductDetails({BillingConstants.subscriptionId});

      if (response.error != null) {
        _lastErrorMessage = friendlyErrorMessage(response.error!.message);
        _isLoadingProduct = false;
        return null;
      }

      if (response.productDetails.isEmpty) {
        _lastErrorMessage = 'Subscription product not found on Google Play.';
        _isLoadingProduct = false;
        return null;
      }

      final details = response.productDetails.firstWhere(
        (p) => p.id == BillingConstants.subscriptionId,
        orElse: () => response.productDetails.first,
      );

      _productDetails = details;
      _parsePricingAndOffers(details);
      _lastRefreshTime = DateTime.now();
      _isLoadingProduct = false;
      return details;
    } catch (e) {
      _lastErrorMessage = 'Failed to load subscription details: $e';
      _isLoadingProduct = false;
      return null;
    }
  }

  /// Parses pricing and offers from standard or Android-specific ProductDetails.
  void _parsePricingAndOffers(ProductDetails details) {
    // 1. Android-specific offer details (PBL 5/6/7)
    if (details is GooglePlayProductDetails) {
      final offers = details.productDetails.subscriptionOfferDetails;
      if (offers != null && offers.isNotEmpty) {
        // Look for the specific intro offer ID or one with multiple pricing phases
        SubscriptionOfferDetailsWrapper? bestOffer;
        for (final offer in offers) {
          if (offer.offerId == BillingConstants.introOfferId) {
            bestOffer = offer;
            break;
          }
        }

        bestOffer ??= offers.firstWhere(
          (o) => o.pricingPhases.length > 1,
          orElse: () => offers.first,
        );

        _selectedOfferToken = bestOffer.offerIdToken;

        if (bestOffer.pricingPhases.isNotEmpty) {
          final firstPhase = bestOffer.pricingPhases.first;
          _introPriceDisplay = firstPhase.formattedPrice;

          if (bestOffer.pricingPhases.length > 1) {
            final recurringPhase = bestOffer.pricingPhases[1];
            _recurringPriceDisplay = '${recurringPhase.formattedPrice}/month';
          } else {
            _recurringPriceDisplay = '${details.price}/month';
          }
          return;
        }
      }
    }

    // 2. Standard fallback
    _introPriceDisplay = details.price;
    _recurringPriceDisplay = '${details.price}/month';
  }

  /// Initiates a subscription purchase via Google Play sheet.
  Future<bool> buySubscription(ProductDetails product) async {
    _lastErrorMessage = null;
    try {
      PurchaseParam purchaseParam;
      if (product is GooglePlayProductDetails && _selectedOfferToken != null) {
        purchaseParam = GooglePlayPurchaseParam(
          productDetails: product,
          offerToken: _selectedOfferToken!,
        );
      } else {
        purchaseParam = PurchaseParam(productDetails: product);
      }

      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      _lastErrorMessage = 'Purchase failed to start: $e';
      return false;
    }
  }

  /// Restores previous active purchases for the merchant's Google Account.
  Future<RestorePurchasesResult> restorePurchases() async {
    _lastErrorMessage = null;
    if (!_isAvailable) {
      return const RestorePurchasesResult(
        success: false,
        restoredCount: 0,
        message: 'Google Play Billing is not available on this device.',
      );
    }

    try {
      await _iap.restorePurchases();
      _lastRefreshTime = DateTime.now();

      // Check current state after restore stream processing
      final isSubscribed = SubscriptionManager.instance.currentState.hasPremiumEntitlement;
      if (isSubscribed) {
        return const RestorePurchasesResult(
          success: true,
          restoredCount: 1,
          message: 'MyUPI Premium restored successfully!',
        );
      } else {
        return const RestorePurchasesResult(
          success: true,
          restoredCount: 0,
          message: 'No active MyUPI subscription found for this Google account.',
        );
      }
    } catch (e) {
      _lastErrorMessage = 'Restore failed: $e';
      return RestorePurchasesResult(
        success: false,
        restoredCount: 0,
        message: 'Unable to restore purchases: ${friendlyErrorMessage(e.toString())}',
      );
    }
  }

  /// Handles incoming purchase updates from Google Play Billing stream.
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchase in purchaseDetailsList) {
      if (purchase.productID != BillingConstants.subscriptionId) {
        continue;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _handlePendingPurchase(purchase);
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _handleSuccessfulPurchase(purchase);
          break;

        case PurchaseStatus.canceled:
          _handleCanceledPurchase(purchase);
          break;

        case PurchaseStatus.error:
          _handleErrorPurchase(purchase);
          break;
      }
    }
  }

  /// Pending purchase state (e.g. slow credit card, UPI bank processing, parental control).
  void _handlePendingPurchase(PurchaseDetails purchase) {
    _lastPurchaseTokenSanitized = sanitizeToken(purchase.purchaseID);
    // Do NOT grant entitlement while pending
    _lastErrorMessage = 'Payment pending. Premium will unlock once bank confirmation is received.';
  }

  /// Successful or restored purchase state.
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    _lastErrorMessage = null;
    final token = purchase.purchaseID;
    _lastPurchaseTokenSanitized = sanitizeToken(token);

    // CRITICAL FACT: Google Play requires acknowledgement within 3 days
    // otherwise the purchase is automatically refunded and revoked.
    if (purchase.pendingCompletePurchase) {
      try {
        await _iap.completePurchase(purchase);
        _lastPurchaseAcknowledged = true;
      } catch (e) {
        _lastErrorMessage = 'Purchase acknowledgement failed: $e';
      }
    } else {
      _lastPurchaseAcknowledged = true;
    }

    // Unlock entitlement via centralized SubscriptionManager
    await SubscriptionManager.instance.updateFromPurchase(
      orderId: purchase.purchaseID ?? 'UNKNOWN_ORDER',
      purchaseToken: _lastPurchaseTokenSanitized ?? 'VALID_TOKEN',
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );
  }

  /// User cancelled the Google Play purchase dialog.
  void _handleCanceledPurchase(PurchaseDetails purchase) {
    _lastErrorMessage = null; // Cancellation is normal user action, not a system failure
  }

  /// Billing error state.
  void _handleErrorPurchase(PurchaseDetails purchase) {
    final rawMsg = purchase.error?.message ?? 'Unknown error';
    _lastErrorMessage = friendlyErrorMessage(rawMsg);
  }

  /// Strictly sanitizes purchase tokens to prevent sensitive data leakage.
  /// Never reveals full tokens in logs, diagnostics, or UI.
  static String sanitizeToken(String? rawToken) {
    if (rawToken == null || rawToken.trim().isEmpty) return 'N/A';
    final trimmed = rawToken.trim();
    if (trimmed.length <= 8) return '***';
    return '${trimmed.substring(0, 4)}...${trimmed.substring(trimmed.length - 4)}';
  }

  /// Translates raw technical billing exceptions into clear, merchant-friendly text.
  static String friendlyErrorMessage(String? raw) {
    if (raw == null) return 'Billing is currently unavailable.';
    final lower = raw.toLowerCase();

    if (lower.contains('user_canceled') || lower.contains('cancelled') || lower.contains('canceled')) {
      return 'Purchase was cancelled. No charges were made.';
    }
    if (lower.contains('service_unavailable') || lower.contains('network') || lower.contains('connection')) {
      return 'Network connection issue. Please check your internet connection and try again.';
    }
    if (lower.contains('item_already_owned') || lower.contains('already owned')) {
      return 'You already own this subscription. Tap "Restore Purchases" to sync.';
    }
    if (lower.contains('item_unavailable') || lower.contains('not found')) {
      return 'The subscription product is currently unavailable in the Play Store.';
    }
    if (lower.contains('billing_unavailable')) {
      return 'Google Play Billing is unavailable on this device or needs an update.';
    }
    return 'Payment was not completed. If amount was deducted, Google Play will refund it automatically.';
  }
}
