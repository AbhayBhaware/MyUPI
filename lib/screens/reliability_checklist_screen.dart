// lib/screens/reliability_checklist_screen.dart
//
// Reliability & Anti-Fraud Setup Checklist (Master Brief Part 1d & Part 2)
// ------------------------------------------------------------------------
// Guided merchant checklist to guarantee zero missed payments:
//   1. Notification Listener Access
//   2. Battery Optimization Exemption (prevents OS from killing background listener)
//   3. SMS Backup Detection Permission
//   4. OEM-specific Background & Autostart Settings (Realme/Xiaomi/Vivo/Oppo)
//   5. Installed UPI Apps Notification Verification (deep-links to per-app settings)
//   6. Anti-Fraud Merchant Disclosure

import 'package:flutter/material.dart';

import '../app_channels.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/premium_card.dart';
import '../widgets/section_header.dart';
import '../widgets/status_badge.dart';

class ReliabilityChecklistScreen extends StatefulWidget {
  const ReliabilityChecklistScreen({super.key});

  @override
  State<ReliabilityChecklistScreen> createState() => _ReliabilityChecklistScreenState();
}

class _ReliabilityChecklistScreenState extends State<ReliabilityChecklistScreen>
    with WidgetsBindingObserver {

  bool _loading = true;
  bool _notifGranted = false;
  bool _smsGranted = false;
  bool _batteryIgnored = false;
  String _manufacturer = 'Android';
  List<Map<String, String>> _installedUpiApps = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    setState(() => _loading = true);
    try {
      final notif = await kMethodChannel.invokeMethod<bool>('isNotificationAccessEnabled') ?? false;
      final sms = await kMethodChannel.invokeMethod<bool>('isSmsPermissionGranted') ?? false;
      final battery = await kMethodChannel.invokeMethod<bool>('isBatteryOptimizationIgnored') ?? false;
      final mfg = await kMethodChannel.invokeMethod<String>('getDeviceManufacturer') ?? 'Android';
      final appsRaw = await kMethodChannel.invokeMethod<List<dynamic>>('getInstalledUpiApps') ?? [];

      final apps = appsRaw
          .whereType<Map>()
          .map((m) => {
                'package': (m['package'] as String?) ?? '',
                'name': (m['name'] as String?) ?? '',
              })
          .where((m) => m['package']!.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _notifGranted = notif;
        _smsGranted = sms;
        _batteryIgnored = battery;
        _manufacturer = mfg;
        _installedUpiApps = apps;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openNotifSettings() async {
    try {
      await kMethodChannel.invokeMethod('openNotificationAccessSettings');
    } catch (_) {}
  }

  Future<void> _requestSmsPermission() async {
    try {
      await kMethodChannel.invokeMethod('requestSmsPermission');
    } catch (_) {}
  }

  Future<void> _requestBatteryOptimization() async {
    try {
      await kMethodChannel.invokeMethod('requestIgnoreBatteryOptimization');
    } catch (_) {}
  }

  Future<void> _openAutostart() async {
    try {
      await kMethodChannel.invokeMethod('openAutostartSettings');
    } catch (_) {}
  }

  Future<void> _openAppNotif(String pkg) async {
    try {
      await kMethodChannel.invokeMethod('openAppNotificationSettings', {'package': pkg});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reliability & Protection', style: AppTypography.titleMedium),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Status',
            onPressed: _refreshStatus,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.base),
              children: [
                // ── Hero Banner ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.awningNavy, AppColors.primaryBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: AppRadius.lgRadius,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield_rounded, color: Colors.white, size: 28),
                          SizedBox(width: AppSpacing.sm),
                          Text(
                            'Dual-Channel Detection',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'MyUPI listens simultaneously to Notifications and Bank SMS with 45-second cross-channel deduplication. Complete these checks so Android never delays an announcement.',
                        style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Checklist Section ─────────────────────────────────────────
                const SectionHeader(title: 'BACKGROUND RELIABILITY CHECKLIST'),
                const SizedBox(height: AppSpacing.sm),

                // 1. Notification Listener
                _buildCheckItem(
                  icon: Icons.notifications_active_rounded,
                  title: 'Notification Listener Access',
                  subtitle: 'Primary channel for instant UPI payment detection.',
                  isDone: _notifGranted,
                  actionText: 'Enable Access',
                  onAction: _openNotifSettings,
                ),

                // 2. Battery Saver Exemption
                _buildCheckItem(
                  icon: Icons.battery_charging_full_rounded,
                  title: 'Battery Optimization Exemption',
                  subtitle: 'Prevents Android Doze from putting the Soundbox service to sleep.',
                  isDone: _batteryIgnored,
                  actionText: 'Exempt App',
                  onAction: _requestBatteryOptimization,
                ),

                // 3. SMS Backup Channel
                _buildCheckItem(
                  icon: Icons.sms_rounded,
                  title: 'SMS Backup Channel',
                  subtitle: 'Secondary channel that detects bank credit texts if notifications drop.',
                  isDone: _smsGranted,
                  actionText: 'Allow SMS',
                  onAction: _requestSmsPermission,
                ),

                // 4. OEM Autostart Guidance
                _buildOemGuidanceCard(),

                const SizedBox(height: AppSpacing.lg),

                // ── Installed UPI Apps Section ────────────────────────────────
                const SectionHeader(
                  title: 'INSTALLED UPI APPS',
                  actionLabel: 'Verify Notifications',
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Confirm each UPI app is permitted to post notifications on your device lock screen and system tray.',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: AppSpacing.sm),

                if (_installedUpiApps.isEmpty)
                  PremiumCard(
                    padding: const EdgeInsets.all(AppSpacing.base),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue),
                        const SizedBox(width: AppSpacing.md),
                        const Expanded(
                          child: Text(
                            'No standard UPI apps automatically detected. Ensure PhonePe, Google Pay, or Paytm are installed.',
                            style: AppTypography.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._installedUpiApps.map((app) => _buildUpiAppTile(app)),

                const SizedBox(height: AppSpacing.xl),

                // ── Anti-Fraud Merchant Disclosure ───────────────────────────
                Container(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: AppRadius.mdRadius,
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Merchant Anti-Fraud Notice',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'MyUPI voice announcements are convenience alerts. Never release high-value merchandise based solely on an SMS or audio prompt. Always confirm large payments in your actual banking app.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF78350F), height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
    );
  }

  Widget _buildCheckItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDone,
    required String actionText,
    required VoidCallback onAction,
  }) {
    return PremiumCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDone ? AppColors.successBg : AppColors.lightBlue,
              borderRadius: AppRadius.mdRadius,
            ),
            child: Icon(
              icon,
              color: isDone ? AppColors.success : AppColors.primaryBlue,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: AppTypography.titleSmall),
                    ),
                    StatusBadge(
                      label: isDone ? 'ACTIVE' : 'ACTION NEEDED',
                      type: isDone ? StatusBadgeType.active : StatusBadgeType.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTypography.caption),
                if (!isDone) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 34,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryBlue,
                        side: const BorderSide(color: AppColors.primaryBlue),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
                      ),
                      onPressed: onAction,
                      child: Text(actionText, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOemGuidanceCard() {
    final mfgLower = _manufacturer.toLowerCase();
    String oemAdvice = 'Your device manufacturer may restrict background apps. Allow autostart and background activity for MyUPI.';
    if (mfgLower.contains('realme') || mfgLower.contains('oppo')) {
      oemAdvice = 'Realme / Oppo devices aggressively close background apps. Ensure MyUPI is set to "Allow Background Activity" and "Allow Auto-launch" in App Management.';
    } else if (mfgLower.contains('xiaomi') || mfgLower.contains('redmi') || mfgLower.contains('poco')) {
      oemAdvice = 'MIUI / HyperOS requires enabling "Autostart" and setting Battery Saver to "No restrictions".';
    } else if (mfgLower.contains('vivo') || mfgLower.contains('iqoo')) {
      oemAdvice = 'Vivo FuntouchOS / OriginOS requires enabling "High background power consumption" in Battery settings.';
    }

    return PremiumCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: AppRadius.mdRadius,
                ),
                child: const Icon(Icons.settings_suggest_rounded, color: Color(0xFFEA580C), size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Device Autostart ($_manufacturer)', style: AppTypography.titleSmall),
                    const Text('OEM Background Optimization', style: AppTypography.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(oemAdvice, style: AppTypography.bodySmall),
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
              ),
              onPressed: _openAutostart,
              child: const Text('Open Autostart Settings', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpiAppTile(Map<String, String> app) {
    return PremiumCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primaryBlue, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              app['name'] ?? '',
              style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => _openAppNotif(app['package'] ?? ''),
            child: const Text('Check Settings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
