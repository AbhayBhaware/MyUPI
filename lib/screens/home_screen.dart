// lib/screens/home_screen.dart
//
// Merchant Dashboard — Premium Fintech Redesign.
// ----------------------------------------------------
// Core Soundbox status hero card, Today's performance metrics,
// Most recent payment card, quick merchant shortcuts, and live payment banner.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_channels.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../tts_service.dart';
import '../upi_detector.dart';
import '../widgets/payment_card.dart';
import '../widgets/premium_buttons.dart';
import '../widgets/premium_card.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_badge.dart';
import 'paywall_screen.dart';
import 'reliability_checklist_screen.dart';

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
      setState(() => _history = recs);
    } on PlatformException catch (_) {}
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
    _bannerTimer = Timer(const Duration(seconds: 7), () {
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

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final notifOk  = _notifAccess == true;
    final checking = _notifAccess == null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryBlue,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Top Header ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.lg, AppSpacing.base, AppSpacing.sm),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadius.mdRadius,
                          border: Border.all(color: AppColors.softBlueBorder, width: 1.0),
                          boxShadow: AppShadows.card,
                        ),
                        child: ClipRRect(
                          borderRadius: AppRadius.mdRadius,
                          child: Padding(
                            padding: const EdgeInsets.all(3.0),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.storefront_rounded,
                                color: AppColors.primaryBlue,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getGreeting(),
                              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                            ),
                            Text(
                              _merchantName,
                              style: AppTypography.titleLarge.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadius.smRadius,
                          border: Border.all(color: AppColors.cardBorder, width: 1.0),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.textPrimary),
                          tooltip: 'Refresh',
                          onPressed: _refresh,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Main Content Area ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.md),

                      // ── Live Payment Banner (When in-app payment occurs) ─────
                      if (_livePayment != null) ...[
                        _buildLivePaymentOverlay(_livePayment!),
                        const SizedBox(height: AppSpacing.base),
                      ],

                      // ── Soundbox Status Hero Card ───────────────────────────
                      _buildSoundboxHeroCard(notifOk, checking),
                      const SizedBox(height: AppSpacing.base),

                      // ── Notification Access Warning (if disabled) ───────────
                      if (!checking && !notifOk) ...[
                        _buildAccessWarningCard(),
                        const SizedBox(height: AppSpacing.base),
                      ],

                      // ── Today's Performance ─────────────────────────────────
                      const SectionHeader(
                        title: "Today's Collection",
                        padding: EdgeInsets.only(bottom: AppSpacing.sm),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              title: "Today's Earnings",
                              value: _todayRecs.isEmpty ? '₹0' : _todayTotalFmt,
                              subtitle: _todayRecs.isEmpty ? 'Waiting for 1st payment' : 'Total received today',
                              icon: Icons.currency_rupee_rounded,
                              iconColor: AppColors.primaryBlue,
                              iconBgColor: AppColors.lightBlue,
                              onTap: () => widget.onNavigateToTab?.call(1),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: StatCard(
                              title: 'Payments',
                              value: '${_todayRecs.length}',
                              subtitle: _todayRecs.length == 1 ? '1 transaction' : '${_todayRecs.length} transactions',
                              icon: Icons.receipt_long_outlined,
                              iconColor: AppColors.success,
                              iconBgColor: AppColors.successBg,
                              onTap: () => widget.onNavigateToTab?.call(1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Most Recent Payment ─────────────────────────────────
                      SectionHeader(
                        title: 'Most Recent Payment',
                        actionLabel: 'View History',
                        onAction: () => widget.onNavigateToTab?.call(1),
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      ),
                      _buildRecentPaymentSection(),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Test Soundbox CTA ───────────────────────────────────
                      PrimaryButton(
                        label: 'Test Soundbox',
                        icon: Icons.volume_up_rounded,
                        onPressed: _ttsStatus == TtsStatus.unavailable
                            ? null
                            : () async {
                                try {
                                  await kMethodChannel.invokeMethod('speakTest');
                                } on PlatformException catch (_) {
                                  TtsService.instance.speakTest();
                                }
                              },
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ── MyUPI Premium Banner Card ───────────────────────────
                      _buildSubscriptionBannerCard(),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Quick Actions Grid ──────────────────────────────────
                      const SectionHeader(
                        title: 'Quick Actions',
                        padding: EdgeInsets.only(bottom: AppSpacing.sm),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: CustomOutlineButton(
                              label: 'View History',
                              icon: Icons.history_rounded,
                              height: 48,
                              onPressed: () => widget.onNavigateToTab?.call(1),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: CustomOutlineButton(
                              label: 'Soundbox Settings',
                              icon: Icons.tune_rounded,
                              height: 48,
                              onPressed: () => widget.onNavigateToTab?.call(2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ReliabilityChecklistScreen()),
                        ),
                        borderRadius: AppRadius.mdRadius,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: 13),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: AppRadius.mdRadius,
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.checklist_rounded, color: AppColors.primaryBlue, size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Reliability & Protection Checklist',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Merchant Anti-Fraud Disclaimer Footnote ─────────────
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: AppRadius.mdRadius,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textMuted),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Convenience alert only. For large payments, always verify in your banking app before releasing goods.',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hero Soundbox Card ─────────────────────────────────────────────────────

  Widget _buildSoundboxHeroCard(bool notifOk, bool checking) {
    final bool isActive = _soundboxEnabled && notifOk;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFFAFDFB) : AppColors.surface,
        borderRadius: AppRadius.xlRadius,
        border: Border.all(
          color: isActive ? AppColors.successBorder : AppColors.cardBorder,
          width: 1.2,
        ),
        boxShadow: isActive ? AppShadows.card : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.successBg : AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive ? Icons.sensors_rounded : Icons.speaker_rounded,
                      size: 14,
                      color: isActive ? AppColors.success : AppColors.primaryBlue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'MYUPI SOUNDBOX',
                      style: AppTypography.sectionTitle.copyWith(
                        color: isActive ? AppColors.success : AppColors.primaryBlue,
                        fontSize: 11,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (checking)
                const StatusBadge(label: 'CHECKING', type: StatusBadgeType.inactive)
              else if (!notifOk)
                const StatusBadge(label: 'ACTION REQUIRED', type: StatusBadgeType.warning, showDot: true)
              else if (isActive)
                const StatusBadge(label: 'ACTIVE', type: StatusBadgeType.active, showDot: true)
              else
                const StatusBadge(label: 'OFF', type: StatusBadgeType.inactive),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.success : const Color(0xFFF3F4F6),
                  borderRadius: AppRadius.lgRadius,
                  boxShadow: isActive ? AppShadows.successGlow : null,
                ),
                child: Icon(
                  isActive ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: isActive ? Colors.white : AppColors.textMuted,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isActive ? 'Soundbox is Live' : 'Soundbox is Paused',
                      style: AppTypography.titleLarge.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      checking
                          ? 'Verifying notification listener…'
                          : !notifOk
                              ? 'Notification access is required to announce payments'
                              : _soundboxEnabled
                                  ? 'Ready to announce incoming UPI payments'
                                  : 'Payment announcements are switched off',
                      style: AppTypography.bodySmall.copyWith(
                        color: isActive ? const Color(0xFF15803D) : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _soundboxEnabled,
                onChanged: _toggleSoundbox,
                activeThumbColor: AppColors.success,
                activeTrackColor: AppColors.successBg,
              ),
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.successBg.withAlpha(120),
                borderRadius: AppRadius.smRadius,
                border: Border.all(color: AppColors.successBorder.withAlpha(120), width: 0.8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, size: 14, color: AppColors.success),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Dual Detection: Notifications Active • SMS Backup Active',
                      style: TextStyle(fontSize: 11, color: Color(0xFF166534), fontWeight: FontWeight.w600),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ReliabilityChecklistScreen()),
                    ),
                    child: const Text(
                      'Setup',
                      style: TextStyle(fontSize: 11, color: AppColors.primaryBlue, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Access Warning Card ────────────────────────────────────────────────────

  Widget _buildAccessWarningCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: AppColors.warningBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
              const SizedBox(width: 10),
              Text(
                'Notification Access Required',
                style: AppTypography.titleMedium.copyWith(
                  color: const Color(0xFFB45309),
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'MyUPI needs notification access to hear and speak incoming payment alerts from PhonePe, Google Pay, and Paytm.',
            style: AppTypography.bodySmall.copyWith(color: const Color(0xFF92400E)),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
              ),
              onPressed: _openAccessSettings,
              icon: const Icon(Icons.settings, size: 16),
              label: const Text('Enable Notification Access', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Recent Payment Section ─────────────────────────────────────────────────

  Widget _buildRecentPaymentSection() {
    final last = _lastPayment;

    if (last == null) {
      return PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.base),
        color: AppColors.surface,
        borderColor: AppColors.borderLight,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: AppRadius.mdRadius,
                border: Border.all(color: AppColors.softBlueBorder, width: 1),
              ),
              child: const Icon(Icons.wifi_tethering_rounded, color: AppColors.primaryBlue, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Ready & Waiting for Payments',
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'When customers scan your QR code to pay, the payment will appear here and speak aloud.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return PaymentCard(
      record: last,
      onTap: () => widget.onNavigateToTab?.call(1),
    );
  }

  // ── Live Payment Overlay ───────────────────────────────────────────────────

  Widget _buildLivePaymentOverlay(LivePaymentEvent payment) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        gradient: AppColors.livePaymentGradient,
        borderRadius: AppRadius.lgRadius,
        boxShadow: AppShadows.successGlow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(50),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PAYMENT RECEIVED',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  payment.displayAmount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${payment.appName} • Just now',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            onPressed: () => setState(() => _livePayment = null),
          ),
        ],
      ),
    );
  }

  // ── Subscription Banner Card ───────────────────────────────────────────────

  Widget _buildSubscriptionBannerCard() {
    return ValueListenableBuilder<SubscriptionInfo>(
      valueListenable: SubscriptionManager.instance.subscriptionInfoNotifier,
      builder: (context, subInfo, _) {
        final isPrem = subInfo.state.hasPremiumEntitlement;

        return PremiumCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => const PaywallScreen(sourceEntry: 'dashboard'),
              ),
            );
          },
          padding: const EdgeInsets.all(AppSpacing.base),
          borderColor: isPrem ? AppColors.successBorder : AppColors.softBlueBorder,
          backgroundColor: isPrem ? AppColors.successBg : AppColors.lightBlue,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isPrem ? AppColors.success : AppColors.primaryBlue,
                  borderRadius: AppRadius.mdRadius,
                ),
                child: Icon(
                  isPrem ? Icons.verified_rounded : Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isPrem ? 'MyUPI Premium Active' : 'Special Offer: ₹1 First Month',
                          style: AppTypography.titleMedium.copyWith(
                            color: isPrem ? AppColors.success : AppColors.deepBlue,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPrem
                          ? 'All 8 languages and shop branding enabled.'
                          : 'Then ₹49/month. Tap to explore premium soundbox benefits.',
                      style: AppTypography.caption.copyWith(
                        color: isPrem ? const Color(0xFF15803D) : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: isPrem ? AppColors.success : AppColors.primaryBlue,
              ),
            ],
          ),
        );
      },
    );
  }
}
