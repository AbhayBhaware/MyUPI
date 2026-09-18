// lib/screens/onboarding/welcome_screen.dart
//
// Step 0 — Welcome (first screen of onboarding flow).
// Pure informational screen; no permissions requested here.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/premium_buttons.dart';
import '../../widgets/premium_card.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onGetStarted;
  const WelcomeScreen({super.key, required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xl),

                // ── App icon / logo area ────────────────────────────────────────
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.xxlRadius,
                    border: Border.all(color: AppColors.softBlueBorder, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withAlpha(50),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: AppRadius.xxlRadius,
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.speaker_rounded,
                          size: 52,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── App name ───────────────────────────────────────────────────
                const Text(
                  'MyUPI',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryBlue,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Turn your Android phone into a smart UPI Soundbox.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.xl),

                // ── Description ────────────────────────────────────────────────
                PremiumCard(
                  color: AppColors.lightBlue,
                  borderColor: AppColors.primaryBlue.withAlpha(50),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: const Text(
                    'Turn your Android phone into a smart payment announcement device.\n\n'
                    'Every time you receive a UPI payment, MyUPI speaks it aloud — '
                    'so you can focus on your customers without checking your phone.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.6,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // ── Get Started ────────────────────────────────────────────────
                PrimaryButton(
                  label: 'Get Started',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: onGetStarted,
                ),
                const SizedBox(height: AppSpacing.md),

                const Text(
                  'Free · No sign-up required · Works offline',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: AppSpacing.base),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
