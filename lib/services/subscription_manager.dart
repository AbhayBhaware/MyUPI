// lib/services/subscription_manager.dart
//
// Centralized Subscription Manager — Milestone 19
// ------------------------------------------------
// Coordinates subscription state, reactive UI notifications, and
// local persistence via Kotlin SharedPreferences.
//
// Strictly separates real production logic from development simulation.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../app_channels.dart';

class SubscriptionManager {
  SubscriptionManager._internal();
  static final SubscriptionManager instance = SubscriptionManager._internal();

  final ValueNotifier<SubscriptionInfo> subscriptionInfoNotifier =
      ValueNotifier<SubscriptionInfo>(const SubscriptionInfo());

  SubscriptionInfo get currentInfo => subscriptionInfoNotifier.value;
  SubscriptionState get currentState => currentInfo.state;
  EntitlementManager get entitlements => EntitlementManager(subscriptionState: currentState);

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Loads stored subscription state from native SharedPreferences.
  Future<void> initialize({MethodChannel? channel}) async {
    final ch = channel ?? kMethodChannel;
    try {
      final stateStr = await ch.invokeMethod<String>('getSubscriptionState');
      final state = SubscriptionState.fromString(stateStr);
      final isSim = stateStr != null &&
          stateStr != 'INTRO_OFFER_AVAILABLE' &&
          stateStr != 'NOT_SUBSCRIBED';

      subscriptionInfoNotifier.value = SubscriptionInfo(
        state: state,
        isSimulated: isSim,
      );
    } catch (_) {
      // Fallback to default introductory offer available
      subscriptionInfoNotifier.value = const SubscriptionInfo(
        state: SubscriptionState.introOfferAvailable,
      );
    }
    _initialized = true;
  }

  /// Sets a development-only simulated subscription state.
  ///
  /// CAUTION: This method MUST only be called from Developer Diagnostics.
  /// It persists the simulated state locally for UI testing only.
  Future<void> setSimulatedState(SubscriptionState state, {MethodChannel? channel}) async {
    final ch = channel ?? kMethodChannel;
    final updated = currentInfo.copyWith(
      state: state,
      isSimulated: true,
      expiresAt: (state == SubscriptionState.active || state == SubscriptionState.gracePeriod)
          ? DateTime.now().add(const Duration(days: 30))
          : null,
      isAutoRenewing: state == SubscriptionState.active,
    );

    subscriptionInfoNotifier.value = updated;

    try {
      await ch.invokeMethod('setSubscriptionState', {
        'state': state.toStorageKey(),
      });
    } catch (_) {}
  }

  /// Updates subscription state from a confirmed Google Play purchase.
  Future<void> updateFromPurchase({
    required String orderId,
    required String purchaseToken,
    DateTime? expiresAt,
    MethodChannel? channel,
  }) async {
    final ch = channel ?? kMethodChannel;
    final updated = currentInfo.copyWith(
      state: SubscriptionState.active,
      isSimulated: false,
      expiresAt: expiresAt ?? DateTime.now().add(const Duration(days: 30)),
      isAutoRenewing: true,
    );

    subscriptionInfoNotifier.value = updated;

    try {
      await ch.invokeMethod('setSubscriptionState', {
        'state': SubscriptionState.active.toStorageKey(),
      });
    } catch (_) {}
  }

  /// Transitions an expired subscription to EXPIRED.
  /// Preserves all local merchant history while updating feature tier.
  Future<void> setSubscriptionExpired({MethodChannel? channel}) async {
    final ch = channel ?? kMethodChannel;
    final updated = currentInfo.copyWith(
      state: SubscriptionState.expired,
      isSimulated: false,
      isAutoRenewing: false,
    );

    subscriptionInfoNotifier.value = updated;

    try {
      await ch.invokeMethod('setSubscriptionState', {
        'state': SubscriptionState.expired.toStorageKey(),
      });
    } catch (_) {}
  }

  /// Resets state back to the default pre-billing introductory offer state.
  Future<void> resetToDefault({MethodChannel? channel}) async {
    final ch = channel ?? kMethodChannel;
    subscriptionInfoNotifier.value = const SubscriptionInfo(
      state: SubscriptionState.introOfferAvailable,
      isSimulated: false,
    );

    try {
      await ch.invokeMethod('setSubscriptionState', {
        'state': SubscriptionState.introOfferAvailable.toStorageKey(),
      });
    } catch (_) {}
  }
}

