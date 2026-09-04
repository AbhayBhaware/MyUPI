// lib/screens/home_screen.dart
//
// Professional Soundbox Dashboard — Milestone 9
// -----------------------------------------------
// Shows:
//   • Soundbox ON/OFF status + live payment banner
//   • Notification access status
//   • Today's total and payment count
//   • Last payment
//   • Test Soundbox button
//   • Navigation to History and Settings

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_channels.dart';
import '../tts_service.dart';
import '../upi_detector.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {

  // ── App state ──────────────────────────────────────────────────────────────
  bool? _notifAccess;        // null = checking
  bool  _soundboxEnabled = true;

  // ── History state ──────────────────────────────────────────────────────────
  List<PaymentRecord> _history = [];
  bool _loadingHistory = true;

  // ── Live payment banner ────────────────────────────────────────────────────
  LivePaymentEvent? _livePayment;
  Timer? _bannerTimer;

  // ── EventChannel dedup ─────────────────────────────────────────────────────
  final Set<String> _seenKeys = {};
  StreamSubscription<dynamic>? _eventSub;

  // ── Flutter TTS (test button only) ────────────────────────────────────────
  TtsStatus get _ttsStatus => TtsService.instance.status;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TtsService.instance.onStatusChanged = () {
      if (mounted) setState(() {});
    };
    TtsService.instance.initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
      _startEventChannel();
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _eventSub?.cancel();
    TtsService.instance.onStatusChanged = null;
    TtsService.instance.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    await Future.wait([_checkAccess(), _loadSettings(), _loadHistory()]);
  }

  // ── Permission ─────────────────────────────────────────────────────────────

  Future<void> _checkAccess() async {
    try {
      final ok = await kMethodChannel.invokeMethod<bool>('isNotificationAccessEnabled') ?? false;
      if (!mounted) return;
      setState(() => _notifAccess = ok);
    } on PlatformException catch (_) {}
  }

  Future<void> _openAccessSettings() async {
    try { await kMethodChannel.invokeMethod('openNotificationAccessSettings'); }
    on PlatformException catch (_) {}
  }

  // ── Settings ───────────────────────────────────────────────────────────────

  Future<void> _loadSettings() async {
    try {
      final on = await kMethodChannel.invokeMethod<bool>('isSoundboxEnabled') ?? true;
      if (!mounted) return;
      setState(() => _soundboxEnabled = on);
    } on PlatformException catch (_) {}
  }

  Future<void> _toggleSoundbox(bool v) async {
    setState(() => _soundboxEnabled = v);
    try { await kMethodChannel.invokeMethod('setSoundboxEnabled', {'enabled': v}); }
    on PlatformException catch (_) {}
  }

  // ── History ────────────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    try {
      final raw = await kMethodChannel.invokeMethod<List<dynamic>>('getPaymentHistory') ?? [];
      final recs = raw.whereType<Map>().map((m) => PaymentRecord(
        amount:    (m['amount']  as String?) ?? '',
        appName:   (m['appName'] as String?) ?? '',
        timestamp: DateTime.fromMillisecondsSinceEpoch((m['timestampMs'] as int?) ?? 0),
      )).where((r) => r.amount.isNotEmpty).toList();
      if (!mounted) return;
      setState(() { _history = recs; _loadingHistory = false; });
    } on PlatformException catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  // ── EventChannel (live payment banner) ────────────────────────────────────

  void _startEventChannel() {
    _eventSub?.cancel();
    _eventSub = kEventChannel.receiveBroadcastStream().listen(
      _onEvent,
      onError: (_) {},
      cancelOnError: false,
    );
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;

    final pkg  = (event['packageName']     as String?) ?? '';
    final key  = (event['notificationKey'] as String?) ?? '$pkg|${DateTime.now().millisecondsSinceEpoch}';
    final title = (event['title'] as String?) ?? '';
    final text  = (event['text']  as String?) ?? '';

    if (_seenKeys.contains(key)) return;
    _seenKeys.add(key);
    if (_seenKeys.length > 200) _seenKeys.clear();

    // Detect to get amount (for banner display only — Kotlin already handled TTS/history).
    final result = UpiNotificationDetector.detect(
      packageName: pkg, title: title, text: text,
    );

    if (result.isPayment && result.amount != null) {
      // Refresh history from Kotlin store.
      _loadHistory();
      // Show live banner.
      _showPaymentBanner(result.amount!, result.appName);
    }
  }

  void _showPaymentBanner(String amount, String appName) {
    _bannerTimer?.cancel();
    setState(() {
      _livePayment = LivePaymentEvent(
        amount: amount, appName: appName, receivedAt: DateTime.now(),
      );
    });
    // Auto-dismiss after 6 seconds.
    _bannerTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _livePayment = null);
    });
  }

  // ── Computed ───────────────────────────────────────────────────────────────

  List<PaymentRecord> get _todayRecs {
    final t = DateTime.now();
    final today = DateTime(t.year, t.month, t.day);
    return _history.where((r) {
      final d = DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day);
      return d == today;
    }).toList();
  }

  double get _todayTotal => _todayRecs.fold(0, (s, r) =>
      s + (double.tryParse(r.amount.replaceAll(',', '')) ?? 0));

  String get _todayTotalFmt {
    final t = _todayTotal;
    if (t == t.truncateToDouble()) {
      return '₹${t.toInt().toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    }
    return '₹${t.toStringAsFixed(2)}';
  }

  PaymentRecord? get _lastPayment => _history.isNotEmpty ? _history.first : null;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            // ── App bar ──────────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 100,
              pinned: true,
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  'MyUPI Soundbox',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                titlePadding: const EdgeInsets.only(left: 16, bottom: 12),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: _refresh,
                ),
              ],
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // ── Live payment banner ──────────────────────────────────
                    if (_livePayment != null) ...[
                      _LivePaymentBanner(
                        payment: _livePayment!,
                        onDismiss: () => setState(() => _livePayment = null),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Soundbox status card ─────────────────────────────────
                    _buildSoundboxCard(cs),
                    const SizedBox(height: 16),

                    // ── Today's summary ──────────────────────────────────────
                    _buildTodaySummary(cs),
                    const SizedBox(height: 16),

                    // ── Last payment ─────────────────────────────────────────
                    _buildLastPayment(cs),
                    const SizedBox(height: 16),

                    // ── Test Soundbox ────────────────────────────────────────
                    _buildTestButton(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Soundbox status card ───────────────────────────────────────────────────

  Widget _buildSoundboxCard(ColorScheme cs) {
    final notifOk  = _notifAccess == true;
    final checking = _notifAccess == null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Icon(Icons.speaker,
                  color: _soundboxEnabled && notifOk ? cs.primary : Colors.grey,
                  size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Soundbox',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    _buildStatusLabel(notifOk, checking),
                  ],
                ),
              ),
              Switch(
                value: _soundboxEnabled,
                onChanged: _toggleSoundbox,
              ),
            ]),

            // Notification access warning
            if (!checking && !notifOk) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Notification access is required for payment detection.',
                    style: TextStyle(fontSize: 13, color: Colors.orange),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openAccessSettings,
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Enable Notification Access'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusLabel(bool notifOk, bool checking) {
    if (checking) {
      return const Text('Checking…',
          style: TextStyle(color: Colors.grey, fontSize: 13));
    }
    if (!notifOk) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.circle, color: Colors.red, size: 10),
        const SizedBox(width: 6),
        const Text('Notification access required',
            style: TextStyle(color: Colors.red, fontSize: 13)),
      ]);
    }
    if (!_soundboxEnabled) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.circle, color: Colors.grey, size: 10),
        const SizedBox(width: 6),
        const Text('Soundbox is turned off',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
      ]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.circle, color: Colors.green, size: 10),
      const SizedBox(width: 6),
      const Text('Ready to announce payments',
          style: TextStyle(color: Colors.green, fontSize: 13,
              fontWeight: FontWeight.w500)),
    ]);
  }

  // ── Today's summary ────────────────────────────────────────────────────────

  Widget _buildTodaySummary(ColorScheme cs) {
    final today = _todayRecs;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Today's Payments",
              style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface.withAlpha(160),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          _loadingHistory
              ? const Center(child: CircularProgressIndicator())
              : Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                        today.isEmpty ? '₹0' : _todayTotalFmt,
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: today.isEmpty ? Colors.grey : cs.primary),
                      ),
                      const SizedBox(height: 2),
                      Text('Today\'s Total',
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withAlpha(130))),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(children: [
                      Text(
                        '${today.length}',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: cs.onPrimaryContainer),
                      ),
                      Text('Payments',
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onPrimaryContainer.withAlpha(180))),
                    ]),
                  ),
                ]),
        ]),
      ),
    );
  }

  // ── Last payment ───────────────────────────────────────────────────────────

  Widget _buildLastPayment(ColorScheme cs) {
    final last = _lastPayment;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Last Payment',
              style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface.withAlpha(160),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 14),
          if (last == null)
            Row(children: [
              Icon(Icons.receipt_long_outlined,
                  color: Colors.grey.shade400, size: 28),
              const SizedBox(width: 12),
              Text('No payments yet',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
            ])
          else
            Row(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.green.withAlpha(30),
                child: const Icon(Icons.currency_rupee,
                    color: Colors.green, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(last.displayAmount,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green)),
                  const SizedBox(height: 2),
                  Text(last.appName,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface)),
                  Text(last.timeLabel,
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withAlpha(130))),
                ]),
              ),
            ]),
        ]),
      ),
    );
  }

  // ── Test button ────────────────────────────────────────────────────────────

  Widget _buildTestButton() {
    final unavail = _ttsStatus == TtsStatus.unavailable;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: unavail
            ? null
            : () async {
                try {
                  await kMethodChannel.invokeMethod('speakTest');
                } on PlatformException catch (_) {
                  TtsService.instance.speakTest();
                }
              },
        icon: const Icon(Icons.play_circle_outline),
        label: const Text('Test Soundbox',
            style: TextStyle(fontSize: 16)),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ─── Live payment banner ──────────────────────────────────────────────────────

class _LivePaymentBanner extends StatelessWidget {
  final LivePaymentEvent payment;
  final VoidCallback onDismiss;

  const _LivePaymentBanner({required this.payment, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withAlpha(80),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'PAYMENT RECEIVED',
              style: TextStyle(
                  color: Colors.white70, fontSize: 11,
                  fontWeight: FontWeight.w600, letterSpacing: 1.2),
            ),
            const SizedBox(height: 6),
            Text(
              payment.displayAmount,
              style: const TextStyle(
                  color: Colors.white, fontSize: 36,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              '${payment.appName}  •  Just now',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: onDismiss,
        ),
      ]),
    );
  }
}
