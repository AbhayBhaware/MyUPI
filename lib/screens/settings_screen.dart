// lib/screens/settings_screen.dart
//
// Settings screen — Modern Fintech Redesign
// Organized strictly into 3 merchant categories:
// 1. SOUNDBOX (toggle, shop name, language, speed, format, volume)
// 2. SUBSCRIPTION (MyUPI Premium status, upgrade plans, restore purchases)
// 3. APP (notification access, Help & Support, About MyUPI)
//
// Developer Diagnostics is kept behind a 7-tap version gesture in AboutScreen.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_channels.dart';
import '../services/firestore_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../tts_service.dart';
import '../utils/speech_template_builder.dart';
import '../widgets/premium_buttons.dart';
import '../widgets/premium_card.dart';
import '../widgets/section_header.dart';
import '../widgets/status_badge.dart';
import 'about_screen.dart';
import 'help_support_screen.dart';
import 'paywall_screen.dart';
import 'reliability_checklist_screen.dart';
import '../services/auth_service.dart';
import '../services/counter_kiosk_service.dart';
import '../widgets/selection_bottom_sheet.dart';
import '../widgets/settings_rows.dart';
import '../widgets/volume_indicator_pill.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  bool _soundboxEnabled = true;
  String _speechSpeed = 'normal';
  String _language = 'en-IN';
  String _merchantName = 'MyUPI';
  String _announceFormat = 'A';
  bool _includeShopName = false;
  bool _humanVoice = false;
  bool _chimeEnabled = true;
  bool? _notifAccess;
  bool _batteryIgnored = false;
  bool _testSoundPlayed = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAccess();
      _checkBattery();
    }
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadSettings(),
      _checkAccess(),
      _checkBattery(),
      _loadTestSoundPlayed(),
    ]);
  }

  Future<void> _checkBattery() async {
    try {
      final ignored = await kMethodChannel.invokeMethod<bool>('isBatteryOptimizationIgnored') ?? false;
      final prefs = await SharedPreferences.getInstance();
      final checklistDone = prefs.getBool('battery_checklist_completed') ?? false;
      if (mounted) setState(() => _batteryIgnored = ignored || checklistDone);
    } catch (_) {}
  }

  Future<void> _loadTestSoundPlayed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final played = prefs.getBool('test_sound_played') ?? false;
      if (mounted) setState(() => _testSoundPlayed = played);
    } catch (_) {}
  }

  Future<void> _playSample() async {
    try {
      await kMethodChannel.invokeMethod('speakTest');
    } on PlatformException catch (_) {
      TtsService.instance.speakTest();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('test_sound_played', true);
    if (mounted) setState(() => _testSoundPlayed = true);
  }

  Future<void> _launchWhatsAppSupport() async {
    const whatsappUrl = 'https://wa.me/919999999999?text=Hi%20MyUPI%20Support%2C%20I%20need%20help%20with%20my%20Soundbox';
    try {
      await kMethodChannel.invokeMethod('openUrl', {'url': whatsappUrl});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open WhatsApp. Please check if WhatsApp is installed.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _loadSettings() async {
    try {
      final on = await kMethodChannel.invokeMethod<bool>('isSoundboxEnabled') ?? true;
      final speed = await kMethodChannel.invokeMethod<String>('getSpeechSpeed') ?? 'normal';
      final lang = await kMethodChannel.invokeMethod<String>('getLanguage') ?? 'en-IN';
      final mName = await kMethodChannel.invokeMethod<String>('getMerchantName') ?? 'MyUPI';
      final aFmt = await kMethodChannel.invokeMethod<String>('getAnnouncementFormat') ?? 'A';
      final inc = await kMethodChannel.invokeMethod<bool>('getIncludeShopName') ?? false;

      final prefs = await SharedPreferences.getInstance();
      final human = prefs.getBool('human_voice_enabled') ?? false;
      final chime = prefs.getBool('soundbox_chime_enabled') ?? true;

      if (!mounted) return;
      setState(() {
        _soundboxEnabled = on;
        _speechSpeed = speed;
        _language = lang;
        _merchantName = mName;
        _announceFormat = aFmt;
        _includeShopName = inc;
        _humanVoice = human;
        _chimeEnabled = chime;
      });
    } on PlatformException catch (_) {}
  }

  Future<void> _setHumanVoice(bool val) async {
    setState(() => _humanVoice = val);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('human_voice_enabled', val);
    } catch (_) {}
  }

  Future<void> _setChime(bool val) async {
    setState(() => _chimeEnabled = val);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('soundbox_chime_enabled', val);
    } catch (_) {}
  }

  Future<void> _checkAccess() async {
    try {
      final ok = await kMethodChannel.invokeMethod<bool>('isNotificationAccessEnabled') ?? false;
      if (!mounted) return;
      setState(() => _notifAccess = ok);
    } on PlatformException catch (_) {}
  }

  Future<void> _setSoundbox(bool v) async {
    setState(() => _soundboxEnabled = v);
    try {
      await kMethodChannel.invokeMethod('setSoundboxEnabled', {'enabled': v});
    } on PlatformException catch (_) {}
  }

  Future<void> _setSpeed(String v) async {
    setState(() => _speechSpeed = v);
    try {
      await kMethodChannel.invokeMethod('setSpeechSpeed', {'speed': v});
    } on PlatformException catch (_) {}
  }

  Future<void> _setLanguage(String langCode) async {
    try {
      final available = await kMethodChannel.invokeMethod<bool>(
          'checkLanguageAvailability', {'language': langCode});
      if (available == true) {
        setState(() => _language = langCode);
        await kMethodChannel.invokeMethod('setLanguage', {'language': langCode});
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected language is not available on this device voice engine.'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on PlatformException catch (_) {}
  }

  Future<void> _setMerchantName(String name) async {
    setState(() => _merchantName = name);
    try {
      await kMethodChannel.invokeMethod('setMerchantName', {'name': name});
    } on PlatformException catch (_) {}
  }

  Future<void> _setAnnounceFormat(String v) async {
    setState(() => _announceFormat = v);
    try {
      await kMethodChannel.invokeMethod('setAnnouncementFormat', {'format': v});
    } on PlatformException catch (_) {}
  }

  Future<void> _setIncludeShopName(bool v) async {
    setState(() => _includeShopName = v);
    try {
      await kMethodChannel.invokeMethod('setIncludeShopName', {'enabled': v});
    } on PlatformException catch (_) {}
  }

  Future<void> _openAccessSettings() async {
    try {
      await kMethodChannel.invokeMethod('openNotificationAccessSettings');
    } on PlatformException catch (_) {}
  }

  Future<void> _handleRestorePurchases() async {
    if (_isRestoring) return;
    setState(() => _isRestoring = true);
    try {
      final result = await BillingService.instance.restorePurchases();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? AppColors.success : AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to reach Google Play Store. Please check connection.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings', style: AppTypography.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1, color: AppColors.borderLight),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          // ════════════════════════════════════════════════════════════════════
          // 1. SETUP HEALTH CARD (TOP — "NOBODY GETS STUCK")
          // ════════════════════════════════════════════════════════════════════
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: _buildSetupHealthCard(),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ════════════════════════════════════════════════════════════════════
          // 2. VOICE (ONE CARD)
          // ════════════════════════════════════════════════════════════════════
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: SectionHeader(title: 'VOICE'),
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: _buildVoiceCard(),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ════════════════════════════════════════════════════════════════════
          // 3. SHOP
          // ════════════════════════════════════════════════════════════════════
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: SectionHeader(title: 'SHOP'),
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: _buildShopCard(),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ════════════════════════════════════════════════════════════════════
          // 4. COUNTER MODE
          // ════════════════════════════════════════════════════════════════════
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: SectionHeader(title: 'COUNTER MODE'),
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: _buildCounterModeCard(),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ════════════════════════════════════════════════════════════════════
          // 5. PLAN
          // ════════════════════════════════════════════════════════════════════
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: SectionHeader(title: 'PLAN'),
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: _buildPlanCard(),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ════════════════════════════════════════════════════════════════════
          // 6. HELP & RELIABILITY
          // ════════════════════════════════════════════════════════════════════
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: SectionHeader(title: 'HELP & RELIABILITY'),
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: _buildHelpAndReliabilityCard(),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ════════════════════════════════════════════════════════════════════
          // 7. ACCOUNT
          // ════════════════════════════════════════════════════════════════════
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: SectionHeader(title: 'ACCOUNT'),
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: _buildAccountCard(),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  // ── 1. Setup Health Card ───────────────────────────────────────────────────

  Widget _buildSetupHealthCard() {
    final notifOk = _notifAccess == true;
    final batteryOk = _batteryIgnored;
    final upiOk = _getUpiIdDisplay() != 'Not set';
    final soundOk = _testSoundPlayed;

    final completedCount = (notifOk ? 1 : 0) +
        (batteryOk ? 1 : 0) +
        (upiOk ? 1 : 0) +
        (soundOk ? 1 : 0);

    final isAllSet = completedCount == 4;

    if (isAllSet) {
      return PremiumCard(
        color: AppColors.successBg,
        borderColor: AppColors.successBorder,
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text(
                    'All Set • Soundbox Ready',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '4/4 ✓',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Notification access, battery optimization, UPI ID, and sound preview are verified.',
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return PremiumCard(
      color: AppColors.warningBg,
      borderColor: AppColors.warningBorder,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Setup Health • $completedCount of 4 complete',
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$completedCount/4',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Complete setup to prevent missed payment announcements.',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          _buildHealthCheckRow(
            title: 'Notification Access',
            isDone: notifOk,
            actionLabel: 'Enable',
            onAction: _openAccessSettings,
          ),
          const SizedBox(height: 8),
          _buildHealthCheckRow(
            title: 'Battery & Autostart',
            isDone: batteryOk,
            actionLabel: 'Review',
            onAction: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const ReliabilityChecklistScreen()),
              );
              _checkBattery();
            },
          ),
          const SizedBox(height: 8),
          _buildHealthCheckRow(
            title: 'UPI ID Added',
            isDone: upiOk,
            actionLabel: 'Add',
            onAction: _showEditUpiIdDialog,
          ),
          const SizedBox(height: 8),
          _buildHealthCheckRow(
            title: 'Test Sound Played',
            isDone: soundOk,
            actionLabel: 'Play',
            onAction: _playSample,
          ),
        ],
      ),
    );
  }

  Widget _buildHealthCheckRow({
    required String title,
    required bool isDone,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Row(
      children: [
        Icon(
          isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 16,
          color: isDone ? AppColors.success : AppColors.textTertiary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isDone ? FontWeight.w500 : FontWeight.w600,
              color: isDone ? AppColors.textSecondary : AppColors.textPrimary,
              decoration: isDone ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        if (!isDone) ...[
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                height: 28,
                child: FilledButton(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(actionLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── 2. Voice Card ──────────────────────────────────────────────────────────

  Widget _buildVoiceCard() {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Master Soundbox switch
          SwitchRow(
            iconData: _soundboxEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            title: 'Soundbox',
            subtitle: _soundboxEnabled
                ? 'Payment announcements are on'
                : 'Payment announcements are paused',
            value: _soundboxEnabled,
            onChanged: _setSoundbox,
            iconColor: _soundboxEnabled ? AppColors.success : AppColors.textTertiary,
            iconBgColor: _soundboxEnabled ? AppColors.successBg : AppColors.background,
            showDivider: true,
          ),

          // Language NavRow
          NavRow(
            iconData: Icons.language_rounded,
            title: 'Announcement Language',
            subtitle: 'Spoken language for payments',
            value: _getLanguageLabel(_language),
            onTap: _showLanguagePicker,
            showDivider: true,
          ),

          // Voice Type NavRow (with HUMAN tag)
          NavRow(
            iconData: Icons.record_voice_over_rounded,
            title: 'Announcement Voice',
            subtitle: _humanVoice
                ? (_includeShopName
                    ? 'Human voice active • Shop name uses system TTS'
                    : 'Natural human voice (offline pack)')
                : 'Standard voice (device system TTS)',
            value: _humanVoice ? 'Human Voice' : 'Standard',
            badge: _humanVoice
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'HUMAN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  )
                : null,
            onTap: _showVoicePicker,
            showDivider: true,
          ),

          // Announcement Style NavRow
          NavRow(
            iconData: Icons.style_rounded,
            title: 'Announcement Style',
            subtitle: 'Format spoken on payment',
            value: _getFormatName(_announceFormat),
            onTap: _showAnnounceFormatPicker,
            showDivider: true,
          ),

          // Melodic Attention Chime SwitchRow
          SwitchRow(
            iconData: _chimeEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
            title: 'Payment Attention Chime',
            subtitle: 'Play melodic chime before speech',
            value: _chimeEnabled,
            onChanged: _setChime,
            showDivider: true,
          ),

          // Single Play Sample Box with exact sentence preview
          Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: AppRadius.mdRadius,
                border: Border.all(color: AppColors.softBlueBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.hearing_rounded, size: 16, color: AppColors.primaryBlue),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Sample Announcement',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleSmall.copyWith(fontSize: 13, color: AppColors.primaryBlue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _getFormatPreviewText(_announceFormat),
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
                      ),
                      onPressed: _playSample,
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Play Sample', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Advanced ▸ Speech speed
          NavRow(
            iconData: Icons.speed_rounded,
            title: 'Speech Speed (Advanced)',
            subtitle: 'Pacing of voice announcements',
            value: _speechSpeed.toUpperCase(),
            onTap: _showSpeedPicker,
            showDivider: false,
          ),
        ],
      ),
    );
  }

  // ── 3. Shop Card ───────────────────────────────────────────────────────────

  Widget _buildShopCard() {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          NavRow(
            iconData: Icons.storefront_rounded,
            title: 'Shop / Business Name',
            subtitle: 'Spoken in announcement and displayed on QR',
            value: _merchantName,
            onTap: _showEditMerchantNameDialog,
            showDivider: true,
          ),
          SwitchRow(
            iconData: Icons.store_rounded,
            title: 'Include Shop Name',
            subtitle: _includeShopName
                ? 'Shop name included in announcement'
                : 'Standard announcement without shop name',
            value: _includeShopName,
            onChanged: _setIncludeShopName,
            showDivider: true,
          ),
          NavRow(
            iconData: Icons.qr_code_2_rounded,
            title: 'UPI ID',
            subtitle: 'Payment address for QR code generation',
            value: _getUpiIdDisplay(),
            onTap: _showEditUpiIdDialog,
            showDivider: false,
          ),
        ],
      ),
    );
  }

  // ── 4. Counter Mode Card ───────────────────────────────────────────────────

  Widget _buildCounterModeCard() {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SwitchRow(
            iconData: Icons.screen_lock_portrait_rounded,
            title: 'Keep Screen Awake on Counter',
            subtitle: 'Storefront counter display (increases battery drain)',
            value: CounterKioskService.instance.isKeepAwake,
            onChanged: (v) async {
              await CounterKioskService.instance.setKeepAwake(v);
              setState(() {});
            },
            showDivider: true,
          ),
          NavRow(
            iconData: Icons.volume_up_rounded,
            title: 'Announcement Volume',
            subtitle: 'Adjust phone media volume',
            value: 'Media Volume',
            onTap: () => VolumeIndicatorPill.showVolumeSheet(context),
            showDivider: false,
          ),
        ],
      ),
    );
  }

  // ── 5. Plan Card ───────────────────────────────────────────────────────────

  Widget _buildPlanCard() {
    return ValueListenableBuilder<SubscriptionInfo>(
      valueListenable: SubscriptionManager.instance.subscriptionInfoNotifier,
      builder: (context, subInfo, _) {
        final isEntitled = subInfo.state.hasPremiumEntitlement;
        return PremiumCard(
          padding: EdgeInsets.zero,
          color: isEntitled ? AppColors.surface : AppColors.lightBlue,
          borderColor: isEntitled ? AppColors.successBorder : AppColors.primaryBlue.withValues(alpha: 0.2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: const [
                              Icon(
                                Icons.workspace_premium_rounded,
                                size: 22,
                                color: AppColors.primaryBlue,
                              ),
                              SizedBox(width: AppSpacing.sm),
                              Flexible(
                                child: Text(
                                  'MyUPI Premium',
                                  style: AppTypography.titleSmall,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: StatusBadge(
                              label: subInfo.state.label.toUpperCase(),
                              type: isEntitled ? StatusBadgeType.active : StatusBadgeType.info,
                              showDot: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      isEntitled
                          ? 'All 8 Indian languages, custom shop branding, and priority announcements active.'
                          : 'Introductory Offer: ₹1 for first month, then ₹49/month. Cancel anytime via Play Store.',
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SecondaryButton(
                      label: isEntitled ? 'Manage Subscription' : 'View Premium Plans',
                      icon: Icons.star_rounded,
                      height: 42,
                      isFullWidth: true,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => const PaywallScreen(sourceEntry: 'settings'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.borderLight),
              // Restore Purchases as a clean NavRow INSIDE the card per spec
              NavRow(
                iconData: Icons.restore_rounded,
                title: 'Restore Purchases',
                subtitle: 'Restore active Play Store subscription',
                value: _isRestoring ? 'Restoring…' : 'Restore',
                onTap: _isRestoring ? null : _handleRestorePurchases,
                showDivider: false,
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 6. Help & Reliability Card ─────────────────────────────────────────────

  Widget _buildHelpAndReliabilityCard() {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          NavRow(
            iconData: Icons.shield_rounded,
            title: 'Reliability Checklist',
            subtitle: 'Battery exemption, SMS backup & autostart',
            value: _batteryIgnored ? 'Optimal' : 'Needs Review',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const ReliabilityChecklistScreen()),
              );
            },
            showDivider: true,
          ),
          NavRow(
            iconData: _notifAccess == true ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            title: 'Notification Access',
            subtitle: _notifAccess == true
                ? 'Enabled — MyUPI hears payment notifications'
                : 'Disabled — payments cannot be announced',
            value: _notifAccess == true ? 'Active' : 'Enable',
            iconColor: _notifAccess == true ? AppColors.success : AppColors.warning,
            iconBgColor: _notifAccess == true ? AppColors.successBg : AppColors.warningBg,
            onTap: _openAccessSettings,
            showDivider: true,
          ),
          NavRow(
            iconData: Icons.help_outline_rounded,
            title: 'Help & Support',
            subtitle: 'FAQs, setup guides, and troubleshooting',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const HelpSupportScreen()),
              );
            },
            showDivider: true,
          ),
          NavRow(
            iconData: Icons.chat_rounded,
            title: 'Chat on WhatsApp',
            subtitle: 'Instant support for merchants via WhatsApp',
            value: 'Chat',
            iconColor: const Color(0xFF25D366),
            iconBgColor: const Color(0xFFE8F8EE),
            onTap: _launchWhatsAppSupport,
            showDivider: true,
          ),
          NavRow(
            iconData: Icons.info_outline_rounded,
            title: 'About MyUPI',
            subtitle: 'Version 1.0.0, privacy policy, and terms',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const AboutScreen()),
              );
            },
            showDivider: false,
          ),
        ],
      ),
    );
  }

  // ── 7. Account Card ────────────────────────────────────────────────────────

  Widget _buildAccountCard() {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          NavRow(
            iconData: Icons.person_outline_rounded,
            title: AuthService.instance.currentUser?.displayName ??
                FirestoreService.instance.cachedProfile?.ownerName ??
                'Merchant Profile',
            subtitle: AuthService.instance.currentUser?.email ??
                AuthService.instance.currentUser?.phoneNumber ??
                FirestoreService.instance.cachedProfile?.phone ??
                'Signed in',
            showDivider: true,
          ),
          NavRow(
            iconData: Icons.logout_rounded,
            title: 'Sign Out',
            subtitle: 'Sign out and switch merchant accounts',
            iconColor: AppColors.error,
            iconBgColor: AppColors.errorBg,
            onTap: _showSignOutDialog,
            showDivider: true,
          ),
          NavRow(
            iconData: Icons.delete_forever_rounded,
            title: 'Delete Account & Data',
            subtitle: 'Permanently remove your merchant data',
            iconColor: AppColors.error,
            iconBgColor: AppColors.errorBg,
            onTap: _showDeleteAccountDialog,
            showDivider: false,
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
          title: const Text('Delete Account & Data', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          content: const Text(
            'This will permanently delete your merchant profile and clear local transaction history. This action cannot be undone.',
            style: AppTypography.bodySmall,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await FirestoreService.instance.deleteUserProfile(user.uid);
                    await user.delete();
                  }
                  await kMethodChannel.invokeMethod('clearPaymentHistory');
                  await AuthService.instance.signOut();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete account: $e. You may need to sign in again first.'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('DELETE PERMANENTLY', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
          title: const Text('Sign Out', style: AppTypography.titleMedium),
          content: const Text(
            'Are you sure you want to sign out of your MyUPI merchant account?',
            style: AppTypography.bodySmall,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await AuthService.instance.signOut();
              },
              child: const Text('SIGN OUT', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }



  String _getFormatPreviewText(String f) {
    final preview = SpeechTemplateBuilder.getFormatPreviewText(
      format: f,
      langCode: _language,
      merchantName: _merchantName,
      includeShopName: _includeShopName,
    );
    return 'Preview: "$preview"';
  }

  String _getLanguageLabel(String langCode) {
    switch (langCode) {
      case 'hi-IN':
        return 'Hindi (हिन्दी)';
      case 'mr-IN':
        return 'Marathi (मराठी)';
      case 'gu-IN':
        return 'Gujarati (ગુજરાતી)';
      case 'ta-IN':
        return 'Tamil (தமிழ்)';
      case 'te-IN':
        return 'Telugu (తెలుగు)';
      case 'bn-IN':
        return 'Bengali (বাংলা)';
      case 'kn-IN':
        return 'Kannada (ಕನ್ನಡ)';
      default:
        return 'English';
    }
  }

  String _getFormatName(String f) {
    switch (f) {
      case 'B':
        return 'Short';
      case 'C':
        return 'With shop name';
      default:
        return 'Standard';
    }
  }

  Future<void> _showLanguagePicker() async {
    HapticFeedback.selectionClick();
    final items = [
      const SelectionItem(value: 'en-IN', title: 'English', subtitle: 'English (India)'),
      const SelectionItem(value: 'hi-IN', title: 'हिन्दी', subtitle: 'Hindi'),
      const SelectionItem(value: 'mr-IN', title: 'मराठी', subtitle: 'Marathi'),
      const SelectionItem(value: 'gu-IN', title: 'ગુજરાતી', subtitle: 'Gujarati'),
      const SelectionItem(value: 'ta-IN', title: 'தமிழ்', subtitle: 'Tamil'),
      const SelectionItem(value: 'te-IN', title: 'తెలుగు', subtitle: 'Telugu'),
      const SelectionItem(value: 'bn-IN', title: 'বাংলা', subtitle: 'Bengali'),
      const SelectionItem(value: 'kn-IN', title: 'ಕನ್ನಡ', subtitle: 'Kannada'),
    ];
    final selected = await showSelectionBottomSheet<String>(
      context: context,
      title: 'Announcement Language',
      subtitle: 'Select the language spoken for payments',
      items: items,
      selectedValue: _language,
    );
    if (selected != null && selected != _language) {
      await _setLanguage(selected);
    }
  }

  Future<void> _showVoicePicker() async {
    HapticFeedback.selectionClick();
    final items = [
      const SelectionItem<bool>(
        value: false,
        title: 'Standard Voice',
        subtitle: 'Device system TTS engine',
      ),
      SelectionItem<bool>(
        value: true,
        title: 'Human Voice',
        subtitle: 'Natural human voice (offline pack)',
        trailingBadge: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.success.withAlpha(25),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.success.withAlpha(60)),
          ),
          child: const Text(
            'HUMAN',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success),
          ),
        ),
      ),
    ];
    final selected = await showSelectionBottomSheet<bool>(
      context: context,
      title: 'Announcement Voice',
      subtitle: 'Choose your soundbox voice type',
      items: items,
      selectedValue: _humanVoice,
    );
    if (selected != null && selected != _humanVoice) {
      await _setHumanVoice(selected);
    }
  }

  Future<void> _showAnnounceFormatPicker() async {
    HapticFeedback.selectionClick();
    final items = [
      const SelectionItem<String>(
        value: 'A',
        title: 'Standard',
        subtitle: 'Amount first + My U P I',
      ),
      const SelectionItem<String>(
        value: 'B',
        title: 'Short',
        subtitle: 'Amount received only',
      ),
      const SelectionItem<String>(
        value: 'C',
        title: 'With shop name',
        subtitle: 'Amount first + My U P I + Shop name',
      ),
    ];
    final selected = await showSelectionBottomSheet<String>(
      context: context,
      title: 'Announcement Style',
      subtitle: 'Format spoken when payment is received',
      items: items,
      selectedValue: _announceFormat,
    );
    if (selected != null && selected != _announceFormat) {
      await _setAnnounceFormat(selected);
    }
  }

  Future<void> _showSpeedPicker() async {
    HapticFeedback.selectionClick();
    final items = [
      const SelectionItem<String>(
        value: 'slow',
        title: 'Slow',
        subtitle: 'Clear, slower pacing for noisy shops',
      ),
      const SelectionItem<String>(
        value: 'normal',
        title: 'Normal',
        subtitle: 'Standard conversational speed',
      ),
      const SelectionItem<String>(
        value: 'fast',
        title: 'Fast',
        subtitle: 'Brisk, fast pacing',
      ),
    ];
    final selected = await showSelectionBottomSheet<String>(
      context: context,
      title: 'Speech Speed',
      subtitle: 'Pacing of voice announcements',
      items: items,
      selectedValue: _speechSpeed,
    );
    if (selected != null && selected != _speechSpeed) {
      await _setSpeed(selected);
    }
  }

  void _showEditMerchantNameDialog() {
    final controller = TextEditingController(text: _merchantName);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
          title: const Text('Edit Shop Name', style: AppTypography.titleMedium),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Shop / Business Name',
              hintText: 'e.g. Abhay General Store',
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
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
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  _setMerchantName(text);
                }
                Navigator.pop(ctx);
              },
              child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  String _getUpiIdDisplay() {
    final profile = FirestoreService.instance.cachedProfile;
    final upiId = profile?.upiId ?? '';
    return upiId.isEmpty ? 'Not set' : upiId;
  }

  void _showEditUpiIdDialog() {
    HapticFeedback.selectionClick();
    final profile = FirestoreService.instance.cachedProfile;
    final currentUpi = profile?.upiId ?? '';
    final controller = TextEditingController(text: currentUpi);
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
                'Your payment address for QR code generation.',
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
                var targetProfile = profile;
                if (targetProfile == null) {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    targetProfile = await FirestoreService.instance.getUserProfile(user.uid);
                  }
                }
                if (targetProfile != null) {
                  final updated = targetProfile.copyWith(upiId: text, updatedAt: DateTime.now());
                  await FirestoreService.instance.saveUserProfile(updated);
                  if (mounted) setState(() {});
                }
              },
              child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
