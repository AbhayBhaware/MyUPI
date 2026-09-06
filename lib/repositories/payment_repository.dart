// lib/repositories/payment_repository.dart
//
// Centralized Payment Repository — Milestone 18
// ----------------------------------------------
// Abstracts payment storage and retrieval for the Flutter UI.
// Backed by Android SharedPreferences via MethodChannel.
//
// Keeps local storage safe, offline, and synchronized with the background Kotlin service.

import 'package:flutter/services.dart';

import '../app_channels.dart';

abstract class PaymentRepository {
  /// Retrieve all stored payment events (newest first).
  Future<List<PaymentEvent>> getHistory();

  /// Alias for getHistory.
  Future<List<PaymentEvent>> getPaymentHistory();

  /// Retrieve the most recent payments up to [limit].
  Future<List<PaymentEvent>> getRecentPayments({int limit = 10});

  /// Retrieve today's payments only.
  Future<List<PaymentEvent>> getTodayPayments();

  /// Calculate total rupees collected today.
  Future<double> getTodayTotal();

  /// Count of payments received today.
  Future<int> getTodayCount();

  /// Manually insert a payment event (used for UI test or local sync).
  Future<void> addPayment(PaymentEvent event);

  /// Delete all stored payment history.
  Future<void> clearHistory();

  /// Retrieve merchant profile.
  Future<MerchantProfile> getMerchantProfile();

  /// Retrieve active feature flags.
  Future<FeatureFlags> getFeatureFlags();

  /// Retrieve subscription tier.
  Future<SubscriptionTier> getSubscriptionTier();

  /// Retrieve system diagnostics.
  Future<Map<String, dynamic>> getDiagnostics();
}

class LocalPaymentRepository implements PaymentRepository {
  final MethodChannel _channel;

  const LocalPaymentRepository({MethodChannel? channel})
      : _channel = channel ?? kMethodChannel;

  @override
  Future<List<PaymentEvent>> getHistory() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getPaymentHistory') ?? [];
      final list = raw
          .whereType<Map>()
          .map((m) => PaymentEvent.fromMap(m))
          .where((e) => e.amount.isNotEmpty)
          .toList();

      // Ensure sorted newest first
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    } on PlatformException {
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<PaymentEvent>> getPaymentHistory() => getHistory();

  @override
  Future<List<PaymentEvent>> getRecentPayments({int limit = 10}) async {
    final history = await getHistory();
    if (history.length <= limit) return history;
    return history.sublist(0, limit);
  }

  @override
  Future<List<PaymentEvent>> getTodayPayments() async {
    final history = await getHistory();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return history.where((e) {
      final d = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
      return d == today;
    }).toList();
  }

  @override
  Future<double> getTodayTotal() async {
    final todayRecs = await getTodayPayments();
    return todayRecs.fold<double>(
      0.0,
      (sum, e) => sum + (double.tryParse(e.amount.replaceAll(',', '')) ?? 0.0),
    );
  }

  @override
  Future<int> getTodayCount() async {
    final todayRecs = await getTodayPayments();
    return todayRecs.length;
  }

  @override
  Future<void> addPayment(PaymentEvent event) async {
    try {
      await _channel.invokeMethod('addPayment', event.toMap());
    } on PlatformException catch (_) {}
  }

  @override
  Future<void> clearHistory() async {
    try {
      await _channel.invokeMethod('clearPaymentHistory');
    } on PlatformException catch (_) {}
  }

  @override
  Future<MerchantProfile> getMerchantProfile() async {
    try {
      final map = await _channel.invokeMapMethod<String, dynamic>('getMerchantProfile') ?? {};
      return MerchantProfile.fromMap(map);
    } catch (_) {
      return const MerchantProfile(merchantId: 'local');
    }
  }

  @override
  Future<FeatureFlags> getFeatureFlags() async {
    try {
      final map = await _channel.invokeMapMethod<String, dynamic>('getFeatureFlags') ?? {};
      return FeatureFlags.fromMap(map);
    } catch (_) {
      return const FeatureFlags();
    }
  }

  @override
  Future<SubscriptionTier> getSubscriptionTier() async {
    try {
      final str = await _channel.invokeMethod<String>('getSubscriptionTier');
      return SubscriptionTier.fromString(str);
    } catch (_) {
      return SubscriptionTier.free;
    }
  }

  @override
  Future<Map<String, dynamic>> getDiagnostics() async {
    try {
      return await _channel.invokeMapMethod<String, dynamic>('getDiagnostics') ?? {};
    } catch (_) {
      return {};
    }
  }
}
