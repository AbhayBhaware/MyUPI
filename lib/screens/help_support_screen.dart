// lib/screens/help_support_screen.dart
//
// Merchant Help & Support Screen — Modern Fintech Redesign
// Provides clear, non-technical guidance for Indian merchants using MyUPI.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/premium_card.dart';
import '../widgets/section_header.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Help & Support', style: AppTypography.titleLarge),
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
          vertical: AppSpacing.md,
        ),
        children: [
          // Header Card
          PremiumCard(
            color: AppColors.lightBlue,
            borderColor: AppColors.primaryBlue.withAlpha(50),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withAlpha(20),
                    borderRadius: AppRadius.mdRadius,
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: AppColors.primaryBlue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Merchant Soundbox Guide',
                        style: AppTypography.titleSmall,
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Answers to common questions about payment announcements and device setup.',
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          const SectionHeader(title: 'FREQUENTLY ASKED QUESTIONS'),
          const SizedBox(height: AppSpacing.xs),

          // 1. How MyUPI works
          const _FaqTile(
            icon: Icons.info_outline_rounded,
            question: '1. How does MyUPI work without machine rent?',
            answer:
                'MyUPI turns your existing Android phone into a payment soundbox. '
                'When you receive a payment, your UPI app (like PhonePe, Google Pay, or Paytm) sends a notification. '
                'MyUPI detects this notification directly on your phone and speaks the amount aloud using your phone speaker. '
                'Everything happens 100% locally on your device — no external server, no bank passwords, and no costly machine rental.',
          ),

          // 2. Enabling notification access
          const _FaqTile(
            icon: Icons.notifications_active_outlined,
            question: '2. How do I enable Notification Access?',
            answer:
                'Notification Access is required so MyUPI can hear incoming payment alerts:\n\n'
                '1. In MyUPI, open Settings and tap "Notification Access".\n'
                '2. Your phone will open the Android "Notification access" screen.\n'
                '3. Find "MyUPI" in the list and switch it ON.\n'
                '4. Tap "Allow" on the system confirmation prompt.\n'
                '5. Return to MyUPI — the status will show ACTIVE in green.',
          ),

          // 3. Audio & volume testing
          const _FaqTile(
            icon: Icons.volume_up_outlined,
            question: '3. How do I test the soundbox audio?',
            answer:
                'You can test the soundbox anytime from the Dashboard or Settings screen by tapping "Test Soundbox". '
                'Your phone will speak: "This is a MyUPI soundbox test." Make sure your phone Media volume is turned up high so you can hear it clearly in your shop.',
          ),

          // 4. Supported UPI apps
          const _FaqTile(
            icon: Icons.apps_outlined,
            question: '4. Which UPI apps are supported?',
            answer:
                'MyUPI supports notifications from all major Indian UPI and merchant applications:\n\n'
                '• PhonePe & PhonePe Business\n'
                '• Google Pay & Google Pay for Business\n'
                '• Paytm & Paytm for Business\n'
                '• BHIM UPI\n'
                '• Major Indian bank apps (SBI YONO, HDFC PayZapp, ICICI iMobile, Axis Pay, etc.)\n\n'
                'Personal payments and merchant QR payments are both detected automatically.',
          ),

          // 5. Why payment wasn't announced
          const _FaqTile(
            icon: Icons.help_outline_rounded,
            question: '5. Why was a payment not announced?',
            answer:
                'If a payment did not announce, check the following:\n\n'
                '1. Media Volume: Your phone media/music volume might be low or muted.\n'
                '2. Do Not Disturb / Silent Mode: If DND is blocking app notifications, MyUPI cannot hear them.\n'
                '3. Notification Muted: Ensure notifications are turned on inside your UPI app settings.\n'
                '4. Duplicate Protection: If identical notifications arrive within 45 seconds, MyUPI ignores the duplicate to prevent speaking twice.\n'
                '5. Soundbox Toggle: Check that the Soundbox switch is ON in MyUPI settings.',
          ),

          // 6. Battery optimization & OEM restrictions
          const _FaqTile(
            icon: Icons.battery_saver_outlined,
            question: '6. Battery saver & keeping MyUPI active in the background',
            answer:
                'Many phones (Vivo, Xiaomi/Redmi, Realme, Oppo, Samsung) aggressively close background apps. To keep MyUPI active all day:\n\n'
                '• Battery Optimization: Set MyUPI battery usage to "Unrestricted" or "Don\'t optimize" in phone Settings > Apps > MyUPI > Battery.\n'
                '• Auto-start / Background Launch: Allow MyUPI to run in background.\n'
                '• Lock in Recent Apps: Open Android recent apps overview, press and hold MyUPI, and tap the Lock icon.',
          ),

          // 7. Voice & language troubleshooting
          const _FaqTile(
            icon: Icons.record_voice_over_outlined,
            question: '7. Voice engine troubleshooting (TTS)',
            answer:
                'MyUPI uses Android\'s built-in Text-to-Speech (TTS) engine. If voice sounds robotic or fails:\n\n'
                '1. Open Google Play Store and search for "Speech Recognition and Synthesis from Google".\n'
                '2. Tap "Update" or "Install" if not up to date.\n'
                '3. On your phone, go to Settings > System > Languages & input > Text-to-speech output.\n'
                '4. Select "Speech Services by Google" as the preferred engine.',
          ),

          // 8. Subscriptions & cancellation
          const _FaqTile(
            icon: Icons.payment_outlined,
            question: '8. How to manage or cancel MyUPI Premium?',
            answer:
                'All MyUPI subscriptions are handled securely through Google Play. You can cancel at any time with zero penalty:\n\n'
                '1. Open the Google Play Store app.\n'
                '2. Tap your profile icon in the top right.\n'
                '3. Tap "Payments & subscriptions" > "Subscriptions".\n'
                '4. Select "MyUPI" and tap "Cancel subscription".\n\n'
                'You will retain all Premium features until the end of your current billing period.',
          ),

          const SizedBox(height: AppSpacing.lg),

          // Privacy note
          Center(
            child: Text(
              'MyUPI runs 100% locally on your phone.\nYour payment data is private and never uploaded to any server.',
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

class _FaqTile extends StatelessWidget {
  final IconData icon;
  final String question;
  final String answer;

  const _FaqTile({
    required this.icon,
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: AppColors.borderLight, width: 1.0),
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.mdRadius,
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            0,
            AppSpacing.base,
            AppSpacing.base,
          ),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: AppRadius.smRadius,
            ),
            child: Icon(icon, color: AppColors.primaryBlue, size: 20),
          ),
          title: Text(
            question,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                answer,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
