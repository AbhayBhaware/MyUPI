// lib/services/counter_kiosk_service.dart
//
// Counter Kiosk Mode Service — Controls "Keep Screen Awake on Counter".
// ---------------------------------------------------------------------
// Allows merchants to keep their smartphone screen active on the checkout counter.
// Safely releases wake-lock on pause/dispose to conserve battery.

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class CounterKioskService with WidgetsBindingObserver {
  CounterKioskService._();
  static final CounterKioskService instance = CounterKioskService._();

  static const String _prefKey = 'counter_mode_keep_awake';
  bool _isKeepAwake = false;
  bool _initialized = false;

  bool get isKeepAwake => _isKeepAwake;

  final ValueNotifier<bool> keepAwakeNotifier = ValueNotifier<bool>(false);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);

    try {
      final prefs = await SharedPreferences.getInstance();
      _isKeepAwake = prefs.getBool(_prefKey) ?? false;
      keepAwakeNotifier.value = _isKeepAwake;
      if (_isKeepAwake) {
        await WakelockPlus.enable();
      }
    } catch (_) {}
  }

  Future<void> setKeepAwake(bool enabled) async {
    _isKeepAwake = enabled;
    keepAwakeNotifier.value = enabled;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, enabled);
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isKeepAwake) return;
    if (state == AppLifecycleState.resumed) {
      WakelockPlus.enable().catchError((_) {});
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      WakelockPlus.disable().catchError((_) {});
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_isKeepAwake) {
      WakelockPlus.disable().catchError((_) {});
    }
  }
}
