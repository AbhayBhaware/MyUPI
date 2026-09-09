// lib/screens/about_screen.dart
//
// About MyUPI Screen — Modern Fintech Redesign
// Provides app version information, merchant terms, privacy policy,
// and a hidden 7-tap developer unlock for DiagnosticsScreen.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/premium_card.dart';
import '../widgets/status_badge.dart';
import 'diagnostics_screen.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  int _tapCount = 0;
  bool _developerUnlocked = false;

  void _onVersionTap() {
    setState(() {
      _tapCount++;
    });

    if (_tapCount >= 7) {
      setState(() {
        _developerUnlocked = true;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Developer Diagnostics unlocked!'),
          backgroundColor: AppColors.primaryBlue,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
      );
    } else if (_tapCount >= 4) {
      final remaining = 7 - _tapCount;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are $remaining step${remaining == 1 ? '' : 's'} away from Developer Diagnostics.'),
          duration: const Duration(milliseconds: 900),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
        title: Row(
          children: const [
            Icon(Icons.shield_outlined, color: AppColors.success),
            SizedBox(width: 10),
            Text('Privacy Policy', style: AppTypography.titleMedium),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            '100% On-Device & Zero-PII Policy\n\n'
            '1. Notification Processing: MyUPI uses Android\'s NotificationListenerService solely '
            'to detect incoming payment notifications from supported UPI apps. All text parsing '
            'and extraction happens entirely on your phone.\n\n'
            '2. Zero Data Collection: MyUPI does NOT collect, store, or transmit your personal data, '
            'bank details, UPI PINs, customer phone numbers, or account balances to any remote server.\n\n'
            '3. Offline Operation: The core payment soundbox works completely offline without requiring '
            'an active internet connection.\n\n'
            '4. In-App Subscriptions: Subscription payments are securely processed by Google Play Billing. '
            'MyUPI never accesses or stores your credit/debit card numbers or bank credentials.\n\n'
            '5. Local Storage: Payment ledger entries and soundbox settings are stored exclusively in '
            'your device\'s local storage and can be cleared anytime by uninstalling the app or clearing app data.',
            style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
        title: Row(
          children: const [
            Icon(Icons.gavel_outlined, color: AppColors.primaryBlue),
            SizedBox(width: 10),
            Text('Terms of Service', style: AppTypography.titleMedium),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'Merchant Soundbox Agreement\n\n'
            '1. Service Description: MyUPI provides audio announcement of incoming UPI payments based on '
            'system notifications received from installed UPI apps on the merchant\'s device.\n\n'
            '2. Notification Fallback: Soundbox announcements depend on the merchant\'s phone receiving and '
            'displaying notifications from third-party UPI apps. If a UPI app fails to post a notification '
            'due to device battery saver, network outage, or DND mode, MyUPI cannot announce the payment.\n\n'
            '3. Merchant Responsibility: Merchants must ensure their phone is sufficiently charged, media volume '
            'is audible, and notifications for banking/UPI apps are enabled.\n\n'
            '4. No Bank Affiliation: MyUPI is an independent productivity utility and is not affiliated with, '
            'sponsored by, or endorsed by NPCI, PhonePe, Google Pay, Paytm, or any bank.\n\n'
            '5. Subscription Terms: Introductory offers (e.g. ₹1 for 1st month) and recurring monthly plans '
            'are billed through Google Play in accordance with Google Play subscription policies.',
            style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('About MyUPI', style: AppTypography.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1, color: AppColors.borderLight),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.lg,
        ),
        children: [
          // App Logo & Info
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: AppRadius.lgRadius,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withAlpha(60),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.speaker_rounded, size: 44, color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'MyUPI Soundbox',
                  style: AppTypography.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Turn your phone into a smart UPI payment soundbox.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Version Tile (with 7-tap gesture)
          PremiumCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                InkWell(
                  onTap: _onVersionTap,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: AppColors.lightBlue,
                            borderRadius: AppRadius.smRadius,
                          ),
                          child: const Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue, size: 20),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('App Version', style: AppTypography.titleSmall),
                              SizedBox(height: 2),
                              Text('1.0.0 (Build 1) · Production Ready', style: AppTypography.bodySmall),
                            ],
                          ),
                        ),
                        if (_developerUnlocked)
                          const StatusBadge(
                            label: 'Dev Mode',
                            type: StatusBadgeType.active,
                            showDot: true,
                          ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 68, endIndent: 16, color: AppColors.borderLight),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.successBg,
                      borderRadius: AppRadius.smRadius,
                    ),
                    child: const Icon(Icons.verified_outlined, color: AppColors.success, size: 20),
                  ),
                  title: const Text('Architecture', style: AppTypography.titleSmall),
                  subtitle: const Text('100% On-Device · Zero Cloud Dependency', style: AppTypography.caption),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.base),

          // Legal & Policies
          PremiumCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.lightBlue,
                      borderRadius: AppRadius.smRadius,
                    ),
                    child: const Icon(Icons.privacy_tip_outlined, color: AppColors.primaryBlue, size: 20),
                  ),
                  title: const Text('Privacy Policy', style: AppTypography.titleSmall),
                  subtitle: const Text('Zero PII · No personal data collected', style: AppTypography.caption),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                  onTap: () => _showPrivacyPolicy(context),
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
                    child: const Icon(Icons.description_outlined, color: AppColors.primaryBlue, size: 20),
                  ),
                  title: const Text('Terms of Service', style: AppTypography.titleSmall),
                  subtitle: const Text('Merchant rights and usage terms', style: AppTypography.caption),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                  onTap: () => _showTermsOfService(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.base),

          // If developer mode unlocked, provide direct navigation button
          if (_developerUnlocked) ...[
            PremiumCard(
              color: AppColors.lightBlue,
              borderColor: AppColors.primaryBlue.withAlpha(50),
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withAlpha(20),
                    borderRadius: AppRadius.smRadius,
                  ),
                  child: const Icon(Icons.developer_mode_rounded, color: AppColors.primaryBlue, size: 20),
                ),
                title: const Text(
                  'Developer Diagnostics',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                ),
                subtitle: const Text('Inspect engine state, billing tokens, parser tests', style: AppTypography.caption),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primaryBlue),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.base),
          ],

          Center(
            child: Text(
              'Made with pride for Indian small business owners.\nMyUPI © 2026',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(height: 1.5),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
