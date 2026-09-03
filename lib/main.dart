import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tts_service.dart';
import 'upi_detector.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyUPI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'MyUPI'),
    );
  }
}

// ─── Data model ──────────────────────────────────────────────────────────────

class NotificationItem {
  final String packageName;
  final String title;
  final String text;
  final DateTime receivedAt;

  /// The dedup key sent from Kotlin (packageName|tag|id).
  final String notificationKey;

  /// Detection result from [UpiNotificationDetector].
  final PaymentDetectionResult detection;

  const NotificationItem({
    required this.packageName,
    required this.title,
    required this.text,
    required this.receivedAt,
    required this.notificationKey,
    required this.detection,
  });
}

// ─── Home page ───────────────────────────────────────────────────────────────

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  // ── Channels ────────────────────────────────────────────────────────────────
  static const _methodChannel =
      MethodChannel('com.example.myupi/notification_access');
  static const _eventChannel =
      EventChannel('com.example.myupi/notification_stream');

  // ── State ───────────────────────────────────────────────────────────────────
  bool? _notificationAccessEnabled;

  /// Latest 5 received notifications (index 0 = newest).
  final List<NotificationItem> _recentNotifications = [];

  /// Dedup set — stores notificationKeys we have already processed.
  final Set<String> _seenKeys = {};

  StreamSubscription<dynamic>? _notificationSubscription;

  /// Convenience getter for TTS status (drives UI rebuild).
  TtsStatus get _ttsStatus => TtsService.instance.status;
  String? get _ttsSpeech => TtsService.instance.currentSpeech;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize TTS and register status-change callback for UI updates.
    TtsService.instance.onStatusChanged = () {
      if (mounted) setState(() {});
    };
    TtsService.instance.initialize();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAccess();
      _startListening();
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    TtsService.instance.onStatusChanged = null;
    TtsService.instance.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check when the user returns to the app (e.g., after visiting Settings).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAccess();
    }
  }

  // ── Permission helpers ───────────────────────────────────────────────────────

  Future<void> _checkAccess() async {
    try {
      final bool enabled =
          await _methodChannel.invokeMethod<bool>('isNotificationAccessEnabled') ??
              false;
      if (!mounted) return;
      setState(() => _notificationAccessEnabled = enabled);
      if (!enabled) {
        _showPermissionDialog();
      }
    } on PlatformException catch (e) {
      debugPrint('MyUPI: isNotificationAccessEnabled error: $e');
    }
  }

  Future<void> _openSettings() async {
    try {
      await _methodChannel.invokeMethod('openNotificationAccessSettings');
    } on PlatformException catch (e) {
      debugPrint('MyUPI: openNotificationAccessSettings error: $e');
    }
  }

  void _showPermissionDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.notifications_active_outlined,
            size: 40, color: Colors.deepPurple),
        title: const Text('Notification Access Required'),
        content: const Text(
          'MyUPI needs notification access to detect UPI payment notifications '
          'and announce received payments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // ── EventChannel stream ──────────────────────────────────────────────────────

  void _startListening() {
    _notificationSubscription?.cancel();
    _notificationSubscription = _eventChannel
        .receiveBroadcastStream()
        .listen(
          _onNotificationReceived,
          onError: (dynamic error) {
            debugPrint('MyUPI: notification stream error: $error');
          },
          cancelOnError: false,
        );
  }

  void _onNotificationReceived(dynamic event) {
    if (event is! Map) return;

    final packageName     = (event['packageName']     as String?) ?? 'unknown';
    final title           = (event['title']           as String?) ?? '';
    final text            = (event['text']            as String?) ?? '';
    final notificationKey = (event['notificationKey'] as String?) ?? '$packageName|${DateTime.now().millisecondsSinceEpoch}';

    // ── Deduplication ────────────────────────────────────────────────────────
    // Notifications can be posted multiple times (e.g., content updates).
    // Skip if we have already processed this exact notification key.
    if (_seenKeys.contains(notificationKey)) {
      debugPrint('MyUPI: Duplicate notification skipped — key: $notificationKey');
      return;
    }
    _seenKeys.add(notificationKey);

    // Keep the seen-keys set from growing unbounded.
    if (_seenKeys.length > 200) {
      _seenKeys.clear();
    }

    // ── Detection ────────────────────────────────────────────────────────────
    final detection = UpiNotificationDetector.detect(
      packageName: packageName,
      title: title,
      text: text,
    );

    debugPrint(
      'MyUPI DETECT | Key: $notificationKey | '
      'Status: ${detection.isPayment ? "PAYMENT" : "NOT_PAYMENT"} | '
      'Reason: ${detection.reason}',
    );
    // NOTE: Payment TTS is now handled by NativeTtsHelper in the Kotlin
    // NotificationListenerService — this ensures speech works even when
    // the Flutter UI is closed. Do NOT call TtsService.speakPayment() here
    // to avoid double-speaking the same payment.

    final item = NotificationItem(
      packageName: packageName,
      title: title,
      text: text,
      receivedAt: DateTime.now(),
      notificationKey: notificationKey,
      detection: detection,
    );

    if (!mounted) return;
    setState(() {
      _recentNotifications.insert(0, item);
      if (_recentNotifications.length > 5) {
        _recentNotifications.removeLast();
      }
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.payments_outlined, size: 36, color: colorScheme.primary),
              const SizedBox(width: 10),
              const Text(
                'MyUPI Soundbox',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Access status ────────────────────────────────────────────────
          _buildAccessStatus(),

          const SizedBox(height: 12),

          // ── Soundbox status ──────────────────────────────────────────────
          _buildSoundboxStatus(),

          const SizedBox(height: 8),

          // ── Test Soundbox button ─────────────────────────────────────────
          _buildTestSoundboxButton(),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),

          // ── Notification Monitor header ──────────────────────────────────
          const Text(
            'Notification Monitor',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          // ── Latest notification ──────────────────────────────────────────
          if (_recentNotifications.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.notifications_none,
                        size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      'No notifications received yet.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Send yourself a WhatsApp message or trigger any app notification.',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Latest highlighted card
            _buildLatestCard(_recentNotifications.first),
            const SizedBox(height: 16),

            // Recent list
            if (_recentNotifications.length > 1) ...[
              const Text(
                'Recent Notifications',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ..._recentNotifications
                  .skip(1)
                  .toList()
                  .asMap()
                  .entries
                  .map((e) => _buildRecentTile(e.key + 2, e.value)),
            ],
          ],
        ],
      ),
    );
  }

  // ── Widget helpers ───────────────────────────────────────────────────────────

  Widget _buildSoundboxStatus() {
    switch (_ttsStatus) {
      case TtsStatus.uninitialized:
        return Chip(
          avatar: const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          label: const Text('🔊 Soundbox initializing…'),
        );

      case TtsStatus.ready:
        return Chip(
          avatar: const Icon(Icons.volume_up, color: Colors.deepPurple),
          label: const Text('🟢 Background Soundbox Ready'),
          backgroundColor: Colors.deepPurple.withAlpha(18),
        );

      case TtsStatus.speaking:
        return Chip(
          avatar: const Icon(Icons.graphic_eq, color: Colors.indigo),
          label: Text(
            '🔊 Speaking: "${_ttsSpeech ?? "..."}"',
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: Colors.indigo.withAlpha(18),
        );

      case TtsStatus.unavailable:
        return const Chip(
          avatar: Icon(Icons.volume_off, color: Colors.orange),
          label: Text('⚠️ Text-to-Speech unavailable'),
        );

      case TtsStatus.error:
        return Chip(
          avatar: const Icon(Icons.error_outline, color: Colors.red),
          label: const Text('⚠️ Soundbox error — will retry'),
          backgroundColor: Colors.red.withAlpha(15),
        );
    }
  }

  Widget _buildTestSoundboxButton() {
    final isUnavailable = _ttsStatus == TtsStatus.unavailable;
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: isUnavailable
              ? null
              : () async {
                  // Route through native Kotlin TTS (same engine as payments).
                  try {
                    await _methodChannel.invokeMethod('speakTest');
                  } on PlatformException catch (_) {
                    // Fallback: flutter_tts (e.g. during testing on emulator).
                    TtsService.instance.speakTest();
                  }
                },
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('Test Soundbox'),
        ),
        const SizedBox(width: 8),
        Text(
          '(dev test)',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildAccessStatus() {
    if (_notificationAccessEnabled == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Text('Checking notification access…'),
          ],
        ),
      );
    }

    if (_notificationAccessEnabled!) {
      return Chip(
        avatar: const Icon(Icons.check_circle, color: Colors.green),
        label: const Text('Notification Access: Enabled'),
        backgroundColor: Colors.green.withAlpha(25),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Chip(
          avatar: Icon(Icons.error_outline, color: Colors.red),
          label: Text('Notification Access: Disabled'),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: _openSettings,
          icon: const Icon(Icons.settings),
          label: const Text('Open Notification Settings'),
        ),
      ],
    );
  }

  /// Large highlighted card for the most recent notification.
  Widget _buildLatestCard(NotificationItem item) {
    final isPayment      = item.detection.isPayment;
    final displayAmount  = item.detection.displayAmount;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card header
            Row(
              children: [
                const Icon(Icons.notifications_active,
                    color: Colors.deepPurple, size: 20),
                const SizedBox(width: 6),
                const Text('Latest Notification',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple)),
              ],
            ),
            const Divider(height: 16),

            // Notification details
            _labeledRow('Package', item.packageName),
            const SizedBox(height: 4),
            _labeledRow('App', item.detection.appName),
            const SizedBox(height: 4),
            _labeledRow('Title', item.title.isEmpty ? '(no title)' : item.title),
            const SizedBox(height: 4),
            _labeledRow('Message', item.text.isEmpty ? '(no text)' : item.text),

            const Divider(height: 20),

            // ── Detection status ──────────────────────────────────────────
            Row(
              children: [
                Text(
                  isPayment ? '🟢' : '⚪',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPayment
                            ? 'UPI PAYMENT DETECTED'
                            : 'Not a payment notification',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isPayment
                              ? Colors.green.shade700
                              : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Debug reason — visible during development
                      Text(
                        item.detection.reason,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (isPayment) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified, color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Payment notification detected from ${item.detection.appName}',
                            style: TextStyle(
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w500,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    // ── Amount row (shown only when extracted) ────────────
                    if (displayAmount != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.currency_rupee,
                              color: Colors.green, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Amount:',
                            style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                                fontSize: 13),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            displayAmount,
                            style: TextStyle(
                                color: Colors.green.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 18),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Compact row for the recent list.
  Widget _buildRecentTile(int index, NotificationItem item) {
    final isPayment     = item.detection.isPayment;
    final displayAmount = item.detection.displayAmount;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPayment
              ? Colors.green.withAlpha(40)
              : Colors.deepPurple.withAlpha(25),
          child: Text(
            isPayment ? '₹' : '$index',
            style: TextStyle(
                color: isPayment ? Colors.green.shade700 : Colors.deepPurple,
                fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.detection.appName,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
            if (isPayment)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  displayAmount != null ? 'PAYMENT $displayAmount' : 'PAYMENT',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${item.title.isEmpty ? "(no title)" : item.title}  •  '
          '${item.text.isEmpty ? "(no text)" : item.text}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _labeledRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text('$label:',
              style: const TextStyle(
                  color: Colors.grey, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}
