// lib/tts_service.dart
//
// TtsService — Text-to-Speech for MyUPI Soundbox
// -----------------------------------------------
// Responsibilities:
//   • Initialize flutter_tts once at app startup.
//   • Configure language, rate, pitch, volume.
//   • Convert a validated payment amount into a speech-friendly string.
//   • Speak payment announcements sequentially (queue).
//   • Provide a test-speech method for the UI test button.
//   • Handle all TTS errors safely — never crash the app.
//
// What this does NOT do:
//   • Independently detect or parse notifications.
//   • Access notification data directly.
//   • Modify Android system volume.
//   • Request additional Android permissions.
//
// TTS is ONLY triggered by a validated PaymentDetectionResult from
// UpiNotificationDetector — there is one source of truth for payment detection.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

// ─── TTS status enum ──────────────────────────────────────────────────────────

enum TtsStatus {
  /// TTS has not yet been initialized.
  uninitialized,

  /// TTS initialized and ready to speak.
  ready,

  /// Currently speaking.
  speaking,

  /// TTS engine/language unavailable on this device.
  unavailable,

  /// An error occurred during initialization or speech.
  error,
}

// ─── TtsService ───────────────────────────────────────────────────────────────

class TtsService {
  TtsService._();

  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();

  TtsStatus _status = TtsStatus.uninitialized;
  TtsStatus get status => _status;

  /// The text currently being spoken, or null if idle.
  String? _currentSpeech;
  String? get currentSpeech => _currentSpeech;

  /// Queue for announcements that arrive while speech is in progress.
  final List<String> _queue = [];

  /// Callback invoked when status or speech text changes.
  /// The UI can register here to rebuild when TTS state changes.
  VoidCallback? onStatusChanged;

  // ── Initialization ──────────────────────────────────────────────────────────

  /// Call once from [initState] of the root widget.
  Future<void> initialize() async {
    try {
      // Android: configure TTS engine. Note: androidSetAudioStream was removed
      // in flutter_tts 4.x — audio routing is handled by the OS automatically.

      // Preferred: Indian English.
      await _setLanguage();

      // Soundbox-friendly rate: slightly slower than default for clarity.
      await _tts.setSpeechRate(0.48);

      // Normal pitch.
      await _tts.setPitch(1.0);

      // Maximum volume.
      await _tts.setVolume(1.0);

      // Register callbacks.
      _tts.setStartHandler(() {
        _status = TtsStatus.speaking;
        _notifyListeners();
      });

      _tts.setCompletionHandler(() {
        _currentSpeech = null;
        _status = TtsStatus.ready;
        _notifyListeners();
        _processQueue();
      });

      _tts.setCancelHandler(() {
        _currentSpeech = null;
        _status = TtsStatus.ready;
        _notifyListeners();
        _processQueue();
      });

      _tts.setErrorHandler((dynamic message) {
        debugPrint('MyUPI TTS: Error: $message');
        _currentSpeech = null;
        _status = TtsStatus.error;
        _notifyListeners();
        // Still try the queue — the next item might succeed.
        _processQueue();
      });

      _status = TtsStatus.ready;
      _notifyListeners();
      debugPrint('MyUPI TTS: Initialized successfully.');
    } catch (e) {
      debugPrint('MyUPI TTS: Initialization failed: $e');
      _status = TtsStatus.unavailable;
      _notifyListeners();
    }
  }

  // ── Language configuration ──────────────────────────────────────────────────

  Future<void> _setLanguage() async {
    try {
      // Try preferred Indian English first.
      final result = await _tts.setLanguage('en-IN');
      if (result == 1) {
        debugPrint('MyUPI TTS: Language set to en-IN');
        return;
      }
    } catch (_) {}

    // Fallback: try plain English.
    try {
      final fallbacks = ['en-US', 'en-GB', 'en-AU', 'en'];
      for (final lang in fallbacks) {
        final result = await _tts.setLanguage(lang);
        if (result == 1) {
          debugPrint('MyUPI TTS: en-IN unavailable, fell back to $lang');
          return;
        }
      }
    } catch (e) {
      debugPrint('MyUPI TTS: Could not set any English language: $e');
    }
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Announce a validated payment amount.
  ///
  /// [amount] is the raw extracted amount string, e.g. "1", "500", "1,250",
  /// "25.50". This value comes from [PaymentDetectionResult.amount] and has
  /// already been validated by the UPI detector.
  ///
  /// This method is ONLY called from [_MyHomePageState._onNotificationReceived]
  /// when [PaymentDetectionResult.isPayment] is true AND [amount] is non-null.
  void speakPayment(String amount) {
    if (_status == TtsStatus.unavailable) {
      debugPrint('MyUPI TTS: Skipping speech — TTS unavailable.');
      return;
    }

    final speechText = _buildPaymentSpeech(amount);
    _enqueue(speechText);
  }

  /// Speak the test phrase (triggered by the "Test Soundbox" button).
  void speakTest() {
    if (_status == TtsStatus.unavailable) {
      debugPrint('MyUPI TTS: Skipping test speech — TTS unavailable.');
      return;
    }
    _enqueue('This is a MyUPI soundbox test.');
  }

  /// Stop any current speech and clear the queue.
  Future<void> stop() async {
    _queue.clear();
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('MyUPI TTS: stop() error: $e');
    }
  }

  /// Release TTS resources. Call from [dispose].
  Future<void> dispose() async {
    await stop();
    try {
      await _tts.stop();
    } catch (_) {}
  }

  // ── Speech text builder ─────────────────────────────────────────────────────

  /// Converts a raw amount string into a speech-friendly sentence.
  ///
  /// Examples:
  ///   "1"      → "Payment received, 1 rupee"
  ///   "10"     → "Payment received, 10 rupees"
  ///   "1,250"  → "Payment received, 1250 rupees"
  ///   "25.50"  → "Payment received, 25 rupees 50 paise"
  ///
  /// The UI continues to display the original formatted amount (e.g. ₹1,250).
  static String _buildPaymentSpeech(String rawAmount) {
    // Remove commas (Indian formatting: 1,250 → 1250).
    final cleaned = rawAmount.replaceAll(',', '').trim();

    if (cleaned.isEmpty) {
      return 'Payment received';
    }

    // Split on decimal point.
    final parts = cleaned.split('.');
    final rupeePart  = int.tryParse(parts[0]) ?? 0;
    final paisePart  = parts.length > 1
        ? int.tryParse(parts[1].padRight(2, '0').substring(0, 2))
        : null;

    final rupeeWord = rupeePart == 1 ? 'rupee' : 'rupees';

    if (paisePart != null && paisePart > 0) {
      final paiseWord = paisePart == 1 ? 'paise' : 'paise';
      return 'Payment received, $rupeePart $rupeeWord $paisePart $paiseWord';
    }

    return 'Payment received, $rupeePart $rupeeWord';
  }

  // ── Queue management ────────────────────────────────────────────────────────

  void _enqueue(String text) {
    _queue.add(text);
    debugPrint('MyUPI TTS: Enqueued: "$text" (queue length: ${_queue.length})');
    // If not currently speaking, start immediately.
    if (_status != TtsStatus.speaking) {
      _processQueue();
    }
  }

  Future<void> _processQueue() async {
    if (_queue.isEmpty) return;
    if (_status == TtsStatus.unavailable) {
      _queue.clear();
      return;
    }

    final text = _queue.removeAt(0);
    _currentSpeech = text;
    _status = TtsStatus.speaking;
    _notifyListeners();

    try {
      debugPrint('MyUPI TTS: Speaking: "$text"');
      await _tts.speak(text);
    } catch (e) {
      debugPrint('MyUPI TTS: speak() error: $e');
      _currentSpeech = null;
      _status = TtsStatus.error;
      _notifyListeners();
    }
  }

  // ── Internal helpers ────────────────────────────────────────────────────────

  void _notifyListeners() {
    onStatusChanged?.call();
  }
}
