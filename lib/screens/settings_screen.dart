// lib/screens/settings_screen.dart
//
// Settings screen — Modern Fintech Redesign
// Organized strictly into 3 merchant categories:
// 1. SOUNDBOX (toggle, shop name, language, speed, format, volume)
// 2. SUBSCRIPTION (MyUPI Premium status, upgrade plans, restore purchases)
// 3. APP (notification access, Help & Support, About MyUPI)
//
// Developer Diagnostics is kept behind a 7-tap version gesture in AboutScreen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_channels.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/premium_buttons.dart';
import '../widgets/premium_card.dart';
import '../widgets/section_header.dart';
import '../widgets/status_badge.dart';
import 'about_screen.dart';
import 'help_support_screen.dart';
import 'paywall_screen.dart';

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
  bool? _notifAccess;
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
    if (state == AppLifecycleState.resumed) _checkAccess();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadSettings(), _checkAccess()]);
  }

  Future<void> _loadSettings() async {
    try {
      final on = await kMethodChannel.invokeMethod<bool>('isSoundboxEnabled') ?? true;
      final speed = await kMethodChannel.invokeMethod<String>('getSpeechSpeed') ?? 'normal';
      final lang = await kMethodChannel.invokeMethod<String>('getLanguage') ?? 'en-IN';
      final mName = await kMethodChannel.invokeMethod<String>('getMerchantName') ?? 'MyUPI';
      final aFmt = await kMethodChannel.invokeMethod<String>('getAnnouncementFormat') ?? 'A';
      final inc = await kMethodChannel.invokeMethod<bool>('getIncludeShopName') ?? false;
      if (!mounted) return;
      setState(() {
        _soundboxEnabled = on;
        _speechSpeed = speed;
        _language = lang;
        _merchantName = mName;
        _announceFormat = aFmt;
        _includeShopName = inc;
      });
    } on PlatformException catch (_) {}
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
          // 1. SOUNDBOX SECTION
          // ════════════════════════════════════════════════════════════════════
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: SectionHeader(title: 'SOUNDBOX'),
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: PremiumCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    activeThumbColor: AppColors.primaryBlue,
                    title: const Text('Soundbox', style: AppTypography.titleSmall),
                    subtitle: Text(
                      _soundboxEnabled
                          ? 'Payment announcements are on'
                          : 'Payment announcements are paused',
                      style: AppTypography.caption.copyWith(
                        color: _soundboxEnabled ? AppColors.success : AppColors.textTertiary,
                      ),
                    ),
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _soundboxEnabled ? AppColors.lightBlue : AppColors.background,
                        borderRadius: AppRadius.smRadius,
                      ),
                      child: Icon(
                        _soundboxEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                        color: _soundboxEnabled ? AppColors.primaryBlue : AppColors.textTertiary,
                        size: 20,
                      ),
                    ),
                    value: _soundboxEnabled,
                    onChanged: _setSoundbox,
                  ),
                  const Divider(height: 1, indent: 68, endIndent: 16, color: AppColors.borderLight),
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: AppRadius.smRadius,
                      ),
                      child: const Icon(Icons.storefront_rounded, color: AppColors.primaryBlue, size: 20),
                    ),
                    title: const Text('Shop / Business Name', style: AppTypography.titleSmall),
                    subtitle: Text(_merchantName, style: AppTypography.bodySmall),
                    trailing: const Icon(Icons.edit_rounded, size: 18, color: AppColors.textSecondary),
                    onTap: _showEditMerchantNameDialog,
                  ),
                  const Divider(height: 1, indent: 68, endIndent: 16, color: AppColors.borderLight),
                  SwitchListTile(
                    activeThumbColor: AppColors.primaryBlue,
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: AppRadius.smRadius,
                      ),
                      child: const Icon(Icons.store_rounded, color: AppColors.primaryBlue, size: 20),
                    ),
                    title: const Text('Include Shop Name', style: AppTypography.titleSmall),
                    subtitle: Text(
                      _includeShopName
                          ? 'Shop name included in announcement'
                          : 'Standard announcement without shop name',
                      style: AppTypography.caption,
                    ),
                    value: _includeShopName,
                    onChanged: _setIncludeShopName,
                  ),
                  const Divider(height: 1, indent: 68, endIndent: 16, color: AppColors.borderLight),
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: AppRadius.smRadius,
                      ),
                      child: const Icon(Icons.language_rounded, color: AppColors.primaryBlue, size: 20),
                    ),
                    title: const Text('Announcement Language', style: AppTypography.titleSmall),
                    subtitle: Text(_getLanguageLabel(_language), style: AppTypography.bodySmall),
                    trailing: DropdownButton<String>(
                      value: _language,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                      items: const [
                        DropdownMenuItem(value: 'en-IN', child: Text('English (India)')),
                        DropdownMenuItem(value: 'hi-IN', child: Text('Hindi')),
                        DropdownMenuItem(value: 'mr-IN', child: Text('Marathi')),
                        DropdownMenuItem(value: 'gu-IN', child: Text('Gujarati')),
                        DropdownMenuItem(value: 'ta-IN', child: Text('Tamil')),
                        DropdownMenuItem(value: 'te-IN', child: Text('Telugu')),
                        DropdownMenuItem(value: 'bn-IN', child: Text('Bengali')),
                        DropdownMenuItem(value: 'kn-IN', child: Text('Kannada')),
                      ],
                      onChanged: (v) {
                        if (v != null) _setLanguage(v);
                      },
                    ),
                  ),
                  const Divider(height: 1, indent: 68, endIndent: 16, color: AppColors.borderLight),
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: AppRadius.smRadius,
                      ),
                      child: const Icon(Icons.speed_rounded, color: AppColors.primaryBlue, size: 20),
                    ),
                    title: const Text('Speech Speed', style: AppTypography.titleSmall),
                    subtitle: const Text('How fast payments are announced', style: AppTypography.caption),
                    trailing: DropdownButton<String>(
                      value: _speechSpeed,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                      items: const [
                        DropdownMenuItem(value: 'slow', child: Text('Slow')),
                        DropdownMenuItem(value: 'normal', child: Text('Normal')),
                        DropdownMenuItem(value: 'fast', child: Text('Fast')),
                      ],
                      onChanged: (v) {
                        if (v != null) _setSpeed(v);
                      },
                    ),
                  ),
                  const Divider(height: 1, indent: 68, endIndent: 16, color: AppColors.borderLight),
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: AppRadius.smRadius,
                      ),
                      child: const Icon(Icons.record_voice_over_rounded, color: AppColors.primaryBlue, size: 20),
                    ),
                    title: const Text('Announcement Format', style: AppTypography.titleSmall),
                    subtitle: Text(_getFormatLabel(_announceFormat), style: AppTypography.bodySmall),
                    trailing: DropdownButton<String>(
                      value: _announceFormat,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                      items: const [
                        DropdownMenuItem(value: 'A', child: Text('Format A (Standard)')),
                        DropdownMenuItem(value: 'B', child: Text('Format B (Short)')),
                        DropdownMenuItem(value: 'C', child: Text('Format C (Quick)')),
                      ],
                      onChanged: (v) {
                        if (v != null) _setAnnounceFormat(v);
                      },
                    ),
                  ),
                  const Divider(height: 1, indent: 68, endIndent: 16, color: AppColors.borderLight),
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: AppRadius.smRadius,
                      ),
                      child: const Icon(Icons.volume_up_rounded, color: AppColors.primaryBlue, size: 20),
                    ),
                    title: const Text('Announcement Volume', style: AppTypography.titleSmall),
                    subtitle: const Text(
                      'Uses phone media volume. Adjust via your device volume buttons.',
                      style: AppTypography.caption,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ════════════════════════════════════════════════════════════════════
          // 2. SUBSCRIPTION SECTION
          // ════════════════════════════════════════════════════════════════════
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: SectionHeader(title: 'SUBSCRIPTION'),
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: ValueListenableBuilder<SubscriptionInfo>(
              valueListenable: SubscriptionManager.instance.subscriptionInfoNotifier,
              builder: (context, subInfo, _) {
                final isEntitled = subInfo.state.hasPremiumEntitlement;
                return PremiumCard(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  color: isEntitled ? AppColors.surface : AppColors.lightBlue,
                  borderColor: isEntitled ? AppColors.successBorder : AppColors.primaryBlue.withAlpha(50),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(
                                Icons.workspace_premium_rounded,
                                size: 22,
                                color: AppColors.primaryBlue,
                              ),
                              SizedBox(width: AppSpacing.sm),
                              Text(
                                'MyUPI Premium',
                                style: AppTypography.titleSmall,
                              ),
                            ],
                          ),
                          StatusBadge(
                            label: subInfo.state.label.toUpperCase(),
                            type: isEntitled ? StatusBadgeType.active : StatusBadgeType.info,
                            showDot: true,
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
                      Row(
                        children: [
                          Expanded(
                            child: SecondaryButton(
                              label: isEntitled ? 'Manage Subscription' : 'View Premium Plans',
                              icon: Icons.star_rounded,
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
                          const SizedBox(width: AppSpacing.sm),
                          TextButton.icon(
                            onPressed: _isRestoring ? null : _handleRestorePurchases,
                            icon: _isRestoring
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                                  )
                                : const Icon(Icons.restore_rounded, size: 16, color: AppColors.primaryBlue),
                            label: const Text('Restore', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryBlue)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ════════════════════════════════════════════════════════════════════
          // 3. APP SECTION
          // ════════════════════════════════════════════════════════════════════
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: SectionHeader(title: 'APP'),
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: PremiumCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _notifAccess == true ? AppColors.successBg : AppColors.warningBg,
                        borderRadius: AppRadius.smRadius,
                      ),
                      child: Icon(
                        _notifAccess == true ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                        color: _notifAccess == true ? AppColors.success : AppColors.warning,
                        size: 20,
                      ),
                    ),
                    title: const Text('Notification Access', style: AppTypography.titleSmall),
                    subtitle: Text(
                      _notifAccess == null
                          ? 'Checking…'
                          : _notifAccess!
                              ? 'Enabled — MyUPI can hear payment notifications'
                              : 'Disabled — payments cannot be announced',
                      style: AppTypography.caption.copyWith(
                        color: _notifAccess == true ? AppColors.success : AppColors.warning,
                      ),
                    ),
                    trailing: _notifAccess == false
                        ? OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.warning),
                              foregroundColor: AppColors.warning,
                              shape: const RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
                            ),
                            onPressed: _openAccessSettings,
                            child: const Text('Enable', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          )
                        : null,
                  ),
                  const Divider(height: 1, indent: 68, endIndent: 16, color: AppColors.borderLight),
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: AppRadius.smRadius,
                      ),
                      child: const Icon(Icons.help_outline_rounded, color: AppColors.primaryBlue, size: 20),
                    ),
                    title: const Text('Help & Support', style: AppTypography.titleSmall),
                    subtitle: const Text('FAQs, setup guides, and troubleshooting', style: AppTypography.caption),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const HelpSupportScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 68, endIndent: 16, color: AppColors.borderLight),
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: AppRadius.smRadius,
                      ),
                      child: const Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue, size: 20),
                    ),
                    title: const Text('About MyUPI', style: AppTypography.titleSmall),
                    subtitle: const Text('Version 1.0.0, privacy policy, and terms', style: AppTypography.caption),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const AboutScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  String _getFormatLabel(String f) {
    switch (f) {
      case 'B':
        return 'Format B: "500 rupees received"';
      case 'C':
        return 'Format C: "Payment received, 500 rupees. Thank you."';
      default:
        return 'Format A: "Payment received, 500 rupees"';
    }
  }

  String _getLanguageLabel(String langCode) {
    switch (langCode) {
      case 'hi-IN':
        return 'Hindi';
      case 'mr-IN':
        return 'Marathi';
      case 'gu-IN':
        return 'Gujarati';
      case 'ta-IN':
        return 'Tamil';
      case 'te-IN':
        return 'Telugu';
      case 'bn-IN':
        return 'Bengali';
      case 'kn-IN':
        return 'Kannada';
      default:
        return 'English (India)';
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
}
