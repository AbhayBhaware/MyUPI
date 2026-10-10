// lib/screens/home_screen.dart
//
// Merchant Dashboard — Premium Fintech Redesign.
// ----------------------------------------------------
// Core Soundbox status hero card, Today's performance metrics,
// Most recent payment card, quick merchant shortcuts, and live payment banner.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_channels.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../tts_service.dart';
import '../upi_detector.dart';
import '../widgets/premium_card.dart';
import '../widgets/qr_code_card.dart';
import 'paywall_screen.dart';
import '../services/counter_kiosk_service.dart';
import '../utils/currency_formatter.dart';
import '../widgets/volume_indicator_pill.dart';

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
  String _upiId = '';

  // ── History state ──────────────────────────────────────────────────────────
  List<PaymentRecord> _history = [];

  // ── Live payment banner ────────────────────────────────────────────────────
  LivePaymentEvent? _livePayment;
  Timer? _bannerTimer;

  // ── EventChannel dedup ─────────────────────────────────────────────────────
  final Set<String> _seenKeys = {};
  StreamSubscription<dynamic>? _eventSub;
  StreamSubscription<UserProfile?>? _profileSub;


  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _profileSub = FirestoreService.instance.profileStream.listen((profile) {
      if (profile != null && mounted) {
        setState(() {
          _upiId = profile.upiId;
          if (profile.shopName.isNotEmpty) {
            _merchantName = profile.shopName;
          }
        });
      }
    });
    TtsService.instance.onStatusChanged = () {
      if (mounted) setState(() {});
    };
    TtsService.instance.initialize();
    CounterKioskService.instance.initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
      _startEventChannel();
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _eventSub?.cancel();
    _profileSub?.cancel();
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
    await Future.wait([_checkAccess(), _loadSettings(), _loadHistory(), _loadUpiId()]);
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
    HapticFeedback.lightImpact();
    setState(() => _soundboxEnabled = v);
    try {
      await kMethodChannel.invokeMethod('setSoundboxEnabled', {'enabled': v});
    } on PlatformException catch (_) {}
  }

  // ── UPI ID (Dart-side only — from FirestoreService cached profile) ────────

  Future<void> _loadUpiId() async {
    var profile = FirestoreService.instance.cachedProfile;
    if (profile == null) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          profile = await FirestoreService.instance.getUserProfile(user.uid);
        }
      } catch (_) {}
    }
    if (profile != null && mounted) {
      setState(() {
        _upiId = profile!.upiId;
        if (profile.shopName.isNotEmpty) {
          _merchantName = profile.shopName;
        }
      });
    }
  }

  void _showEditUpiIdDialog() {
    HapticFeedback.selectionClick();
    final controller = TextEditingController(text: _upiId);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
          title: const Text('Edit UPI ID', style: AppTypography.titleMedium),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your UPI payment address. This will be used to generate your QR code.',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'UPI ID',
                  hintText: 'yourname@upi / 9876543210@ybl',
                  prefixIcon: Icon(Icons.qr_code_rounded, color: AppColors.primaryBlue),
                ),
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  final text = data?.text?.trim().toLowerCase();
                  if (!ctx.mounted) return;
                  if (text != null && text.contains('@')) {
                    controller.text = text;
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Pasted from clipboard: $text'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.success,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Clipboard text is not a valid UPI ID (must contain @)'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.warning,
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.content_paste_rounded, size: 14, color: AppColors.primaryBlue),
                      SizedBox(width: 4),
                      Text(
                        'Paste from clipboard',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
              ),
              onPressed: () async {
                final text = controller.text.trim().toLowerCase();
                if (text.isNotEmpty && !text.contains('@')) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('UPI ID must contain @ (e.g. name@upi)'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.warning,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);
                setState(() => _upiId = text);
                // Persist to Firestore via cached profile update
                var cached = FirestoreService.instance.cachedProfile;
                final user = FirebaseAuth.instance.currentUser;
                if (cached == null && user != null) {
                  cached = await FirestoreService.instance.getUserProfile(user.uid);
                }
                if (cached != null) {
                  final updated = cached.copyWith(upiId: text, updatedAt: DateTime.now());
                  await FirestoreService.instance.saveUserProfile(updated);
                }
              },
              child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
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

  String get _todayTotalFmt => CurrencyFormatter.format(_todayTotal);

  PaymentRecord? get _lastPayment => _history.isNotEmpty ? _history.first : null;

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
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
                      const VolumeIndicatorPill(),
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
                      const SizedBox(height: AppSpacing.sm),

                      // ── ONE Full-Width Soundbox Status Card (Wireframe 4.1) ─
                      _buildSoundboxStatusCard(notifOk: notifOk, checking: checking),
                      const SizedBox(height: AppSpacing.md),

                      // ── Live Payment Banner (When in-app payment occurs) ─────
                      if (_livePayment != null) ...[
                        _buildLivePaymentOverlay(_livePayment!),
                        const SizedBox(height: AppSpacing.md),
                      ],

                      // ── Hero: Last Payment & Combined Stats ──────────────────
                      _buildLastPaymentHeroCard(),
                      const SizedBox(height: AppSpacing.md),

                      // ── Compact Payment QR Code Card ─────────────────────────
                      QrCodeCard(
                        upiId: _upiId,
                        merchantName: _merchantName,
                        soundboxActive: _soundboxEnabled && notifOk,
                        onEdit: _showEditUpiIdDialog,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ── Alert Strip (Only if needed, most urgent first) ─────
                      if (!checking && !notifOk) ...[
                        _buildAccessWarningCard(),
                        const SizedBox(height: AppSpacing.md),
                      ],

                      // ── Offer Banner (Only if not subscribed) ───────────────
                      _buildSubscriptionBannerCard(),
                      const SizedBox(height: AppSpacing.md),

                      // ── Anti-Fraud Footnote Notice ──────────────────────────
                      _buildAntiFraudNotice(),
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

  // ── One Full-Width Soundbox Status Card (Wireframe 4.1) ───────────────────

  Widget _buildSoundboxStatusCard({required bool notifOk, required bool checking}) {
    if (!_soundboxEnabled) {
      // OFF = prominent Amber card: "Soundbox is OFF — payments won't be spoken" + [Turn on]
      return Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.warningBg,
          borderRadius: AppRadius.mdRadius,
          border: Border.all(color: AppColors.warningBorder, width: 1.2),
        ),
        child: Row(
          children: [
            const Icon(Icons.volume_off_rounded, color: AppColors.warning, size: 24),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Soundbox is OFF',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Payments won't be spoken",
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
                minimumSize: const Size(0, 36),
              ),
              onPressed: () => _toggleSoundbox(true),
              child: const Text('Turn on', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ],
        ),
      );
    }

    // ON = Calm healthy card: "● Soundbox is ON [ ON ▮] / Listening for payments"
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Soundbox is ON',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepNavy,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Listening for payments',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: true,
            activeTrackColor: AppColors.primaryBlue,
            onChanged: (v) => _toggleSoundbox(v),
          ),
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
              Expanded(
                child: Text(
                  'Notification Access Required',
                  style: AppTypography.titleMedium.copyWith(
                    color: const Color(0xFFB45309),
                    fontSize: 15,
                  ),
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

  // ── Last Payment Hero & Combined Stats Card (Section 4.1) ─────────────────

  Widget _buildLastPaymentHeroCard() {
    final last = _lastPayment;
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Last payment',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (last != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    TtsService.instance.speakPayment(last.amount);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Re-announcing ${CurrencyFormatter.format(last.amount)}...'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.softBlueBorder, width: 0.8),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.volume_up_rounded, size: 13, color: AppColors.primaryBlue),
                          SizedBox(width: 4),
                          Text(
                            'Repeat',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (last != null) ...[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 4,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyFormatter.format(last.amount),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
                Text(
                  '${last.appName} · ${_formatTime(last.timestamp)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ] else ...[
            const Row(
              children: [
                Icon(Icons.wifi_tethering_rounded, color: AppColors.primaryBlue, size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Waiting for payments... Soundbox is ready.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 12),
          // Combined stats row (→ History)
          InkWell(
            onTap: () => widget.onNavigateToTab?.call(1),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Today ${_todayRecs.isEmpty ? '₹0' : _todayTotalFmt} · ${_todayRecs.length} ${_todayRecs.length == 1 ? "payment" : "payments"}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Anti-Fraud Footnote Notice ─────────────────────────────────────────────

  Widget _buildAntiFraudNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textSecondary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Confirm large payments in your bank app.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
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
                        Expanded(
                          child: Text(
                            isPrem ? 'MyUPI Premium Active' : 'Special Offer: ₹1 First Month',
                            style: AppTypography.titleMedium.copyWith(
                              color: isPrem ? AppColors.success : AppColors.deepBlue,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
