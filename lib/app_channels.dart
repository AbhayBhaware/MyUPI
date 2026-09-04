// lib/app_channels.dart
//
// Shared channel constants and data models for all screens.
// Kotlin files are NOT modified — this is Flutter-side only.

import 'package:flutter/services.dart';

// ─── Channel references ───────────────────────────────────────────────────────

const kMethodChannel = MethodChannel('com.example.myupi/notification_access');
const kEventChannel  = EventChannel('com.example.myupi/notification_stream');

// ─── Payment record ───────────────────────────────────────────────────────────

class PaymentRecord {
  final String amount;
  final String appName;
  final DateTime timestamp;

  const PaymentRecord({
    required this.amount,
    required this.appName,
    required this.timestamp,
  });

  /// Display-friendly amount string, e.g. "₹500".
  String get displayAmount => '₹$amount';

  /// Formatted date/time label.
  String get timeLabel {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yest  = today.subtract(const Duration(days: 1));
    final d     = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final t     = _fmtTime(timestamp);
    if (d == today) return 'Today, $t';
    if (d == yest)  return 'Yesterday, $t';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}, $t';
  }

  static String _fmtTime(DateTime dt) {
    final h    = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m    = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }
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
  String get timeLabel     => PaymentRecord._fmtTime(receivedAt);
}
