// lib/screens/settings_screen.dart
//
// MyUPI Soundbox — Merchant Settings Screen.
// Rewritten for maximum stability, resilience, and premium fintech aesthetic.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_channels.dart';
import '../services/auth_service.dart';
import '../services/counter_kiosk_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../tts_service.dart';
import '../utils/speech_template_builder.dart';
import '../widgets/selection_bottom_sheet.dart';
import '../widgets/volume_indicator_pill.dart';
import 'about_screen.dart';
import 'help_support_screen.dart';
import 'paywall_screen.dart';
import 'reliability_checklist_screen.dart';
import 'settings/settings_values.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
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

  Future<T> _safe<T>(Future<T?> Function() call, T fallback) async {
    try {
      return (await call().timeout(const Duration(seconds: 3))) ?? fallback;
    } catch (e, s) {
      debugPrint('SETTINGS_LOAD_FAIL: $e\n$s');
      return fallback;
    }
  }

  Future<void> _loadAll() async {
    try {
      await Future.wait([
        _loadSettings(),
        _checkAccess(),
        _checkBattery(),
        _loadTestSoundPlayed(),
      ]);
    } catch (e) {
      debugPrint('[SettingsScreen] _loadAll error: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final on = await _safe(() => kMethodChannel.invokeMethod<bool>('isSoundboxEnabled'), true);
      final rawSpeed = await _safe(() => kMethodChannel.invokeMethod<String>('getSpeechSpeed'), 'normal');
      final speed = safeSpeed(rawSpeed);
      final rawLang = await _safe(() => kMethodChannel.invokeMethod<String>('getLanguage'), 'en-IN');
      final lang = safeLanguage(rawLang);
      final rawMName = await _safe(() => kMethodChannel.invokeMethod<String>('getMerchantName'), 'MyUPI');
      final mName = safeMerchantName(rawMName);
      final rawAFmt = await _safe(() => kMethodChannel.invokeMethod<String>('getAnnouncementFormat'), 'A');
      final aFmt = safeFormat(rawAFmt);
      final inc = await _safe(() => kMethodChannel.invokeMethod<bool>('getIncludeShopName'), false);

      bool human = false;
      bool chime = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        human = prefs.getBool('human_voice_enabled') ?? false;
        chime = prefs.getBool('soundbox_chime_enabled') ?? true;
      } catch (_) {}

      // Reconcile shop name with Firestore UserProfile
      String effectiveShopName = mName;
      final cachedProfile = FirestoreService.instance.cachedProfile;
      if (cachedProfile != null && cachedProfile.shopName.trim().isNotEmpty) {
        if (effectiveShopName == 'MyUPI' || effectiveShopName.isEmpty) {
          effectiveShopName = cachedProfile.shopName.trim();
          try {
            await kMethodChannel.invokeMethod('setMerchantName', {'name': effectiveShopName});
          } catch (_) {}
        }
      }

      if (!mounted) return;
      setState(() {
        _soundboxEnabled = on;
        _speechSpeed = speed;
        _language = lang;
        _merchantName = effectiveShopName;
        _announceFormat = aFmt;
        _includeShopName = inc;
        _humanVoice = human;
        _chimeEnabled = chime;
      });
    } catch (e, s) {
      debugPrint('SETTINGS_LOAD_FAIL: $e\n$s');
    }
  }

  Future<void> _checkAccess() async {
    try {
      final ok = await kMethodChannel.invokeMethod<bool>('isNotificationAccessEnabled') ?? false;
      if (mounted) setState(() => _notifAccess = ok);
    } catch (_) {}
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

  Future<void> _setSoundbox(bool val) async {
    setState(() => _soundboxEnabled = val);
    try {
      await kMethodChannel.invokeMethod('setSoundboxEnabled', {'enabled': val});
    } catch (_) {}
  }

  Future<void> _setLanguage(String langCode) async {
    try {
      final available = await kMethodChannel.invokeMethod<bool>(
          'checkLanguageAvailability', {'language': langCode});
      if (!mounted) return;
      if (available == true) {
        setState(() => _language = langCode);
        await kMethodChannel.invokeMethod('setLanguage', {'language': langCode});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected language is not available on this device voice engine.'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _setHumanVoice(bool val) async {
    setState(() => _humanVoice = val);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('human_voice_enabled', val);
    } catch (_) {}
  }

  Future<void> _setAnnounceFormat(String val) async {
    setState(() => _announceFormat = val);
    try {
      await kMethodChannel.invokeMethod('setAnnouncementFormat', {'format': val});
    } catch (_) {}
  }

  Future<void> _setChime(bool val) async {
    setState(() => _chimeEnabled = val);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('soundbox_chime_enabled', val);
    } catch (_) {}
  }

  Future<void> _setSpeed(String speed) async {
    setState(() => _speechSpeed = speed);
    try {
      await kMethodChannel.invokeMethod('setSpeechSpeed', {'speed': speed});
    } catch (_) {}
  }

  Future<void> _setIncludeShopName(bool val) async {
    setState(() => _includeShopName = val);
    try {
      await kMethodChannel.invokeMethod('setIncludeShopName', {'enabled': val});
    } catch (_) {}
  }

  Future<void> _setMerchantName(String name) async {
    final clean = name.trim().isEmpty ? 'MyUPI' : name.trim();
    setState(() => _merchantName = clean);
    try {
      await kMethodChannel.invokeMethod('setMerchantName', {'name': clean});
    } catch (_) {}

    try {
      var profile = FirestoreService.instance.cachedProfile;
      if (profile == null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          profile = await FirestoreService.instance.getUserProfile(user.uid);
        }
      }
      if (profile != null) {
        final updated = profile.copyWith(shopName: clean, updatedAt: DateTime.now());
        await FirestoreService.instance.saveUserProfile(updated);
      }
    } catch (e) {
      debugPrint('[SettingsScreen] Error updating shop name in database: $e');
    }
  }

  Future<void> _openAccessSettings() async {
    try {
      await kMethodChannel.invokeMethod('openNotificationAccessSettings');
    } catch (_) {}
  }

  Future<void> _playSample() async {
    try {
      await kMethodChannel.invokeMethod('speakTest');
    } catch (_) {
      try {
        TtsService.instance.speakTest();
      } catch (_) {}
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('test_sound_played', true);
      if (mounted) setState(() => _testSoundPlayed = true);
    } catch (_) {}
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

  String _getUpiIdDisplay() {
    try {
      final profile = FirestoreService.instance.cachedProfile;
      final upi = profile?.upiId.trim() ?? '';
      return upi.isEmpty ? 'Not set' : upi;
    } catch (_) {
      return 'Not set';
    }
  }

  String _getFormatPreviewText() {
    try {
      return SpeechTemplateBuilder.getFormatPreviewText(
        format: _announceFormat,
        langCode: _language,
        merchantName: _merchantName,
        includeShopName: _includeShopName,
      );
    } catch (e) {
      debugPrint('[SettingsScreen] _getFormatPreviewText error: $e');
      return '500 rupees received on My U P I';
    }
  }

  String _getLanguageLabel(String langCode) {
    return kLanguages[langCode] ?? 'English';
  }

  String _getFormatName(String fmt) {
    switch (fmt) {
      case 'B': return 'Short';
      case 'C': return 'With shop name';
      default: return 'Standard';
    }
  }

  Widget _safeCard({required String sectionName, required Widget Function() builder}) {
    try {
      return builder();
    } catch (e, st) {
      debugPrint('SETTINGS_SECTION_FAIL[$sectionName]: $e\n$st');
      return _buildCardWrapper(
        color: AppColors.surface,
        borderColor: AppColors.cardBorder,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.textTertiary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '$sectionName is temporarily unavailable',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => setState(() {}),
                child: const Text('RETRY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
              ),
            ],
          ),
        ),
      );
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
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
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Setup Health
              _safeCard(sectionName: 'Setup Health', builder: _buildSetupHealthCard),
              const SizedBox(height: AppSpacing.md),

              // 2. Voice
              _buildSectionHeader('VOICE'),
              _safeCard(sectionName: 'Voice Settings', builder: _buildVoiceCard),
              const SizedBox(height: AppSpacing.md),

              // 3. Shop
              _buildSectionHeader('SHOP'),
              _safeCard(sectionName: 'Shop Details', builder: _buildShopCard),
              const SizedBox(height: AppSpacing.md),

              // 4. Counter Mode
              _buildSectionHeader('COUNTER MODE'),
              _safeCard(sectionName: 'Counter Mode', builder: _buildCounterModeCard),
              const SizedBox(height: AppSpacing.md),

              // 5. Subscription Plan
              _buildSectionHeader('PLAN'),
              _safeCard(sectionName: 'Subscription Plan', builder: _buildPlanCard),
              const SizedBox(height: AppSpacing.md),

              // 6. Help & Reliability
              _buildSectionHeader('HELP & RELIABILITY'),
              _safeCard(sectionName: 'Help & Reliability', builder: _buildHelpAndReliabilityCard),
              const SizedBox(height: AppSpacing.md),

              // 7. Merchant Account
              _buildSectionHeader('ACCOUNT'),
              _safeCard(sectionName: 'Merchant Account', builder: _buildAccountCard),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SECTION COMPONENTS
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryBlue,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildCardWrapper({required Widget child, Color? color, Color? borderColor}) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: borderColor ?? AppColors.cardBorder, width: 1.0),
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.lgRadius,
        child: child,
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
      return _buildCardWrapper(
        color: AppColors.successBg,
        borderColor: AppColors.successBorder,
        child: Padding(
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
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success.withAlpha(40),
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
              const Text(
                'Notification access, battery optimization, UPI ID, and sound preview are verified.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return _buildCardWrapper(
      color: AppColors.warningBg,
      borderColor: AppColors.warningBorder,
      child: Padding(
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
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(40),
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
            const Text(
              'Complete setup to prevent missed payment announcements.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
          size: 18,
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
          SizedBox(
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
        ],
      ],
    );
  }

  // ── 2. Voice Card ──────────────────────────────────────────────────────────

  Widget _buildVoiceCard() {
    return _buildCardWrapper(
      child: Column(
        children: [
          // Master Soundbox toggle
          _buildSwitchRow(
            icon: _soundboxEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            iconColor: _soundboxEnabled ? AppColors.success : AppColors.textTertiary,
            iconBgColor: _soundboxEnabled ? AppColors.successBg : AppColors.background,
            title: 'Soundbox',
            subtitle: _soundboxEnabled
                ? 'Payment announcements are on'
                : 'Payment announcements are paused',
            value: _soundboxEnabled,
            onChanged: _setSoundbox,
            showDivider: true,
          ),

          // Language
          _buildNavRow(
            icon: Icons.language_rounded,
            title: 'Announcement Language',
            subtitle: 'Spoken language for payments',
            valueText: _getLanguageLabel(_language),
            onTap: _showLanguagePicker,
            showDivider: true,
          ),

          // Voice Type
          _buildNavRow(
            icon: Icons.record_voice_over_rounded,
            title: 'Announcement Voice',
            subtitle: _humanVoice
                ? (_includeShopName
                    ? 'Human voice active • Shop name uses system TTS'
                    : 'Natural human voice (offline pack)')
                : 'Standard voice (device system TTS)',
            valueText: _humanVoice ? 'Human Voice' : 'Standard',
            badge: _humanVoice ? _buildTag('HUMAN', AppColors.success) : null,
            onTap: _showVoicePicker,
            showDivider: true,
          ),

          // Announcement Style
          _buildNavRow(
            icon: Icons.style_rounded,
            title: 'Announcement Style',
            subtitle: 'Format spoken on payment',
            valueText: _getFormatName(_announceFormat),
            onTap: _showAnnounceFormatPicker,
            showDivider: true,
          ),

          // Attention Chime
          _buildSwitchRow(
            icon: _chimeEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
            title: 'Payment Attention Chime',
            subtitle: 'Play melodic chime before speech',
            value: _chimeEnabled,
            onChanged: _setChime,
            showDivider: true,
          ),

          // Sample preview box
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
                    children: const [
                      Icon(Icons.hearing_rounded, size: 16, color: AppColors.primaryBlue),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Sample Announcement',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Preview: "${_getFormatPreviewText()}"',
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

          // Speed
          _buildNavRow(
            icon: Icons.speed_rounded,
            title: 'Speech Speed (Advanced)',
            subtitle: 'Pacing of voice announcements',
            valueText: _speechSpeed.toUpperCase(),
            onTap: _showSpeedPicker,
            showDivider: false,
          ),
        ],
      ),
    );
  }

  // ── 3. Shop Card ───────────────────────────────────────────────────────────

  Widget _buildShopCard() {
    return _buildCardWrapper(
      child: Column(
        children: [
          _buildNavRow(
            icon: Icons.storefront_rounded,
            title: 'Shop / Business Name',
            subtitle: 'Spoken in announcement and displayed on QR',
            valueText: _merchantName,
            onTap: _showEditMerchantNameDialog,
            showDivider: true,
          ),
          _buildSwitchRow(
            icon: Icons.store_rounded,
            title: 'Include Shop Name',
            subtitle: _includeShopName
                ? 'Shop name included in announcement'
                : 'Standard announcement without shop name',
            value: _includeShopName,
            onChanged: _setIncludeShopName,
            showDivider: true,
          ),
          _buildNavRow(
            icon: Icons.qr_code_2_rounded,
            title: 'UPI ID',
            subtitle: 'Payment address for QR code generation',
            valueText: _getUpiIdDisplay(),
            onTap: _showEditUpiIdDialog,
            showDivider: false,
          ),
        ],
      ),
    );
  }

  // ── 4. Counter Mode Card ───────────────────────────────────────────────────

  Widget _buildCounterModeCard() {
    bool isAwake = false;
    try {
      isAwake = CounterKioskService.instance.isKeepAwake;
    } catch (_) {}

    return _buildCardWrapper(
      child: Column(
        children: [
          _buildSwitchRow(
            icon: Icons.screen_lock_portrait_rounded,
            title: 'Keep Screen Awake on Counter',
            subtitle: 'Storefront counter display (increases battery drain)',
            value: isAwake,
            onChanged: (v) async {
              try {
                await CounterKioskService.instance.setKeepAwake(v);
              } catch (_) {}
              if (mounted) setState(() {});
            },
            showDivider: true,
          ),
          _buildNavRow(
            icon: Icons.volume_up_rounded,
            title: 'Announcement Volume',
            subtitle: 'Adjust phone media volume',
            valueText: 'Media Volume',
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
        return _buildCardWrapper(
          color: isEntitled ? AppColors.surface : AppColors.lightBlue,
          borderColor: isEntitled ? AppColors.successBorder : AppColors.softBlueBorder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.workspace_premium_rounded, size: 22, color: AppColors.primaryBlue),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'MyUPI Premium',
                            style: AppTypography.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildTag(
                          isEntitled ? 'ACTIVE' : 'OFFER',
                          isEntitled ? AppColors.success : AppColors.primaryBlue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isEntitled
                          ? 'All 8 Indian languages, custom shop branding, and priority announcements active.'
                          : 'Introductory Offer: ₹1 for first month, then ₹49/month. Cancel anytime via Play Store.',
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primaryBlue),
                          shape: const RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
                        ),
                        icon: const Icon(Icons.star_rounded, size: 18, color: AppColors.primaryBlue),
                        label: Text(
                          isEntitled ? 'Manage Subscription' : 'View Premium Plans',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) => const PaywallScreen(sourceEntry: 'settings'),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.borderLight),
              _buildNavRow(
                icon: Icons.restore_rounded,
                title: 'Restore Purchases',
                subtitle: 'Restore active Play Store subscription',
                valueText: _isRestoring ? 'Restoring…' : 'Restore',
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
    return _buildCardWrapper(
      child: Column(
        children: [
          _buildNavRow(
            icon: Icons.shield_rounded,
            title: 'Reliability Checklist',
            subtitle: 'Battery exemption, SMS backup & autostart',
            valueText: _batteryIgnored ? 'Optimal' : 'Needs Review',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const ReliabilityChecklistScreen()),
              );
            },
            showDivider: true,
          ),
          _buildNavRow(
            icon: _notifAccess == true ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            iconColor: _notifAccess == true ? AppColors.success : AppColors.warning,
            iconBgColor: _notifAccess == true ? AppColors.successBg : AppColors.warningBg,
            title: 'Notification Access',
            subtitle: _notifAccess == true
                ? 'Enabled — MyUPI hears payment notifications'
                : 'Disabled — payments cannot be announced',
            valueText: _notifAccess == true ? 'Active' : 'Enable',
            onTap: _openAccessSettings,
            showDivider: true,
          ),
          _buildNavRow(
            icon: Icons.help_outline_rounded,
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
          _buildNavRow(
            icon: Icons.chat_rounded,
            iconColor: const Color(0xFF25D366),
            iconBgColor: const Color(0xFFE8F8EE),
            title: 'Chat on WhatsApp',
            subtitle: 'Instant support for merchants via WhatsApp',
            valueText: 'Chat',
            onTap: _launchWhatsAppSupport,
            showDivider: true,
          ),
          _buildNavRow(
            icon: Icons.info_outline_rounded,
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
    final user = AuthService.instance.currentUser;
    final profile = FirestoreService.instance.cachedProfile;

    String accountTitle = 'Merchant Profile';
    final userDisplayName = user?.displayName?.trim();
    final profileOwner = profile?.ownerName.trim();
    final profileShop = profile?.shopName.trim();

    if (userDisplayName != null && userDisplayName.isNotEmpty) {
      accountTitle = userDisplayName;
    } else if (profileOwner != null && profileOwner.isNotEmpty) {
      accountTitle = profileOwner;
    } else if (profileShop != null && profileShop.isNotEmpty) {
      accountTitle = profileShop;
    }

    String accountSubtitle = 'Signed in';
    final userEmail = user?.email?.trim();
    final userPhone = user?.phoneNumber?.trim();
    final profilePhone = profile?.phone.trim();

    if (userEmail != null && userEmail.isNotEmpty) {
      accountSubtitle = userEmail;
    } else if (userPhone != null && userPhone.isNotEmpty) {
      accountSubtitle = userPhone;
    } else if (profilePhone != null && profilePhone.isNotEmpty) {
      accountSubtitle = profilePhone;
    }

    return _buildCardWrapper(
      child: Column(
        children: [
          _buildNavRow(
            icon: Icons.person_outline_rounded,
            title: accountTitle,
            subtitle: accountSubtitle,
            showDivider: true,
          ),
          _buildNavRow(
            icon: Icons.logout_rounded,
            iconColor: AppColors.error,
            iconBgColor: AppColors.errorBg,
            title: 'Sign Out',
            subtitle: 'Sign out and switch merchant accounts',
            onTap: _showSignOutDialog,
            showDivider: true,
          ),
          _buildNavRow(
            icon: Icons.delete_forever_rounded,
            iconColor: AppColors.error,
            iconBgColor: AppColors.errorBg,
            title: 'Delete Account & Data',
            subtitle: 'Permanently remove your merchant data',
            onTap: _showDeleteAccountDialog,
            showDivider: false,
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ROW ATOMS
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildSwitchRow({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color iconColor = AppColors.primaryBlue,
    Color iconBgColor = AppColors.lightBlue,
    bool showDivider = false,
  }) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: value ? iconBgColor : const Color(0xFFF1F5F9),
              borderRadius: AppRadius.smRadius,
            ),
            child: Icon(icon, size: 20, color: value ? iconColor : AppColors.textTertiary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primaryBlue,
          ),
        ],
      ),
    );

    if (!showDivider) return content;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        content,
        const Divider(height: 1, indent: 68, endIndent: 16, color: AppColors.borderLight),
      ],
    );
  }

  Widget _buildNavRow({
    required IconData icon,
    required String title,
    String? subtitle,
    String? valueText,
    Widget? badge,
    VoidCallback? onTap,
    Color iconColor = AppColors.primaryBlue,
    Color iconBgColor = AppColors.lightBlue,
    bool showDivider = false,
  }) {
    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: AppRadius.smRadius,
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 6),
            badge,
          ],
          if (valueText != null && valueText.isNotEmpty) ...[
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                valueText,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
          ],
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textTertiary),
          ],
        ],
      ),
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: content,
        ),
      );
    }

    if (!showDivider) return content;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        content,
        const Divider(height: 1, indent: 68, endIndent: 16, color: AppColors.borderLight),
      ],
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DIALOGS & PICKERS
  // ════════════════════════════════════════════════════════════════════════════

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
          child: const Text('HUMAN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success)),
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
      const SelectionItem<String>(value: 'A', title: 'Standard', subtitle: 'Amount first + My U P I'),
      const SelectionItem<String>(value: 'B', title: 'Short', subtitle: 'Amount received only'),
      const SelectionItem<String>(value: 'C', title: 'With shop name', subtitle: 'Amount first + My U P I + Shop name'),
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
      const SelectionItem<String>(value: 'slow', title: 'Slow', subtitle: 'Clear, slower pacing for noisy shops'),
      const SelectionItem<String>(value: 'normal', title: 'Normal', subtitle: 'Standard conversational speed'),
      const SelectionItem<String>(value: 'fast', title: 'Fast', subtitle: 'Brisk, fast pacing'),
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
              const Text(
                'Your payment address for QR code generation.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                  if (mounted) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('UPI ID updated successfully'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.success,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
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
            style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
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

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
          title: const Text('Delete Account & Data', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          content: const Text(
            'This will permanently delete your merchant profile and clear local transaction history. This action cannot be undone.',
            style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
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
}
