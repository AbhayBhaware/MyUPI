// lib/screens/home_screen.dart
//
// Merchant Dashboard — Milestone 17 Polish
// ----------------------------------------
// Shows:
//   • MyUPI / Shop name
//   • Soundbox status: ACTIVE / OFF / ACTION REQUIRED
//   • Today's total collection & payment count
//   • Most recent payment (amount, source app, time)
//   • Notification Access status & fix action
//   • Clear merchant action shortcuts (Test Soundbox, View History, Settings)
//   • Zero developer terminology

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_channels.dart';
import '../tts_service.dart';
import '../upi_detector.dart';

class HomeScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {

  // ── App state ──────────────────────────────────────────────────────────────
  bool? _notifAccess;        // null = checking, true = granted, false = denied
  bool  _soundboxEnabled = true;
  String _merchantName = 'MyUPI';

  // ── History state ──────────────────────────────────────────────────────────
  List<PaymentRecord> _history = [];
  bool _loadingHistory = true;

  // ── Live payment banner ────────────────────────────────────────────────────
  LivePaymentEvent? _livePayment;
  Timer? _bannerTimer;

  // ── EventChannel dedup ─────────────────────────────────────────────────────
  final Set<String> _seenKeys = {};
  StreamSubscription<dynamic>? _eventSub;

  // ── Flutter TTS (test fallback only) ───────────────────────────────────────
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
    try {
      await kMethodChannel.invokeMethod('openNotificationAccessSettings');
    } on PlatformException catch (_) {}
  }

  // ── Settings ───────────────────────────────────────────────────────────────

  Future<void> _loadSettings() async {
    try {
      final on = await kMethodChannel.invokeMethod<bool>('isSoundboxEnabled') ?? true;
      final name = await kMethodChannel.invokeMethod<String>('getMerchantName') ?? 'MyUPI';
      if (!mounted) return;
      setState(() {
        _soundboxEnabled = on;
        _merchantName = name.trim().isEmpty ? 'MyUPI' : name.trim();
      });
    } on PlatformException catch (_) {}
  }

  Future<void> _toggleSoundbox(bool v) async {
    setState(() => _soundboxEnabled = v);
    try {
      await kMethodChannel.invokeMethod('setSoundboxEnabled', {'enabled': v});
    } on PlatformException catch (_) {}
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

  // ── EventChannel (live payment banner) ─────────────────────────────────────

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

    // Detect to get amount (for live in-app banner display only — Kotlin already announced TTS and saved to history).
    final result = UpiNotificationDetector.detect(
      packageName: pkg, title: title, text: text,
    );

    if (result.isPayment && result.amount != null) {
      _loadHistory();
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
    final notifOk  = _notifAccess == true;
    final checking = _notifAccess == null;

    return Scaffold(
      backgroundColor: cs.surface,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            // ── App bar ──────────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 90,
              pinned: true,
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              flexibleSpace: FlexibleSpaceBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.speaker, size: 20, color: Colors.white),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _merchantName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                titlePadding: const EdgeInsets.only(left: 16, bottom: 14),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    _buildSoundboxStatusCard(cs, notifOk, checking),
                    const SizedBox(height: 16),

                    // ── Notification Access warning banner (if disabled) ─────
                    if (!checking && !notifOk) ...[
                      _buildAccessWarningCard(cs),
                      const SizedBox(height: 16),
                    ],

                    // ── Today's summary card ─────────────────────────────────
                    _buildTodaySummaryCard(cs),
                    const SizedBox(height: 16),

                    // ── Last payment card ────────────────────────────────────
                    _buildLastPaymentCard(cs),
                    const SizedBox(height: 16),

                    // ── Quick Merchant Actions ───────────────────────────────
                    _buildMerchantActions(cs),
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

  Widget _buildSoundboxStatusCard(ColorScheme cs, bool notifOk, bool checking) {
    final bool isActive = _soundboxEnabled && notifOk;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.green.withAlpha(30)
                    : cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isActive ? Icons.volume_up : Icons.volume_off,
                color: isActive ? Colors.green : Colors.grey,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Soundbox Status',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      _buildStatusPill(isActive, notifOk, checking),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    checking
                        ? 'Checking soundbox status…'
                        : !notifOk
                            ? 'Notification access is required'
                            : _soundboxEnabled
                                ? 'Announces incoming UPI payments'
                                : 'Announcements are switched off',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withAlpha(150),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Switch(
              value: _soundboxEnabled,
              onChanged: _toggleSoundbox,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(bool isActive, bool notifOk, bool checking) {
    if (checking) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.grey.withAlpha(30),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('CHECKING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
      );
    }

    if (!notifOk) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orange.withAlpha(35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: const Text(
          'ACTION REQUIRED',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange),
        ),
      );
    }

    if (isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.green.withAlpha(30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade400),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, color: Colors.green, size: 8),
            SizedBox(width: 5),
            Text(
              'ACTIVE',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'OFF',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }

  // ── Notification Access warning card ───────────────────────────────────────

  Widget _buildAccessWarningCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
              SizedBox(width: 8),
              Text(
                'Notification Access Disabled',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'MyUPI needs notification access to detect and announce payments from PhonePe, Paytm, and Google Pay.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
              onPressed: _openAccessSettings,
              icon: const Icon(Icons.settings, size: 16),
              label: const Text('Fix Notification Access'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Today's summary card ───────────────────────────────────────────────────

  Widget _buildTodaySummaryCard(ColorScheme cs) {
    final today = _todayRecs;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Today's Collection",
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withAlpha(160),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => widget.onNavigateToTab?.call(1),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View History',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.arrow_forward_ios, size: 11, color: cs.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _loadingHistory
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              today.isEmpty ? '₹0' : _todayTotalFmt,
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: today.isEmpty ? Colors.grey : cs.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Total received today',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withAlpha(130),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${today.length}',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                            Text(
                              today.length == 1 ? 'Payment' : 'Payments',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: cs.onPrimaryContainer.withAlpha(180),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  // ── Last payment card ──────────────────────────────────────────────────────

  Widget _buildLastPaymentCard(ColorScheme cs) {
    final last = _lastPayment;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Most Recent Payment',
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withAlpha(160),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            if (last == null)
              Row(
                children: [
                  Icon(Icons.receipt_long_outlined, color: Colors.grey.shade400, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'No payments received yet today',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              )
            else
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.green.withAlpha(30),
                    child: const Icon(Icons.currency_rupee, color: Colors.green, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          last.displayAmount,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          last.appName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          last.timeLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withAlpha(130),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                        SizedBox(width: 4),
                        Text('Payment detected', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ── Merchant Actions ───────────────────────────────────────────────────────

  Widget _buildMerchantActions(ColorScheme cs) {
    final unavail = _ttsStatus == TtsStatus.unavailable;

    return Column(
      children: [
        // Test Soundbox Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
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
            label: const Text('Test Soundbox', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Quick Navigation Buttons: View History & Settings
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => widget.onNavigateToTab?.call(1),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('View Payment History'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => widget.onNavigateToTab?.call(2),
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: const Text('Soundbox Settings'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PAYMENT RECEIVED',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  payment.displayAmount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${payment.appName}  •  Just now',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
