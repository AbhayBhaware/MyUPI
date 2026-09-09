// lib/screens/onboarding/step_premium_intro_screen.dart
//
// Onboarding Step 4 — Premium Introduction & ₹1 Offer
// ----------------------------------------------------
// Presented after the merchant has tested and verified the Soundbox setup.
//
// Strictly non-aggressive:
//   • Merchant can tap "Continue with Free Soundbox" immediately without payment.
//   • Merchant can tap "View Premium Offer" to view the full paywall.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/premium_buttons.dart';
import '../paywall_screen.dart';

class StepPremiumIntroScreen extends StatelessWidget {
  final VoidCallback onFinish;

  const StepPremiumIntroScreen({super.key, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Step indicator ──────────────────────────────────────────────
              _buildStepIndicator(),
              const SizedBox(height: AppSpacing.xl),

              Expanded(
                child: Column(
                  children: [
                    const Spacer(),

                    // ── Sparkle Icon ──────────────────────────────────────────
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primaryBlue.withAlpha(60), width: 1.5),
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        size: 42,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Headline ──────────────────────────────────────────────
                    const Text(
                      'Try MyUPI for ₹1',
                      style: AppTypography.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),

                    const Text(
                      'Get your first month of MyUPI Smart Soundbox for just ₹1, then ₹49/month.',
                      style: AppTypography.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── Key Highlights ────────────────────────────────────────
                    _buildHighlightRow(
                      icon: Icons.check_circle_outline_rounded,
                      text: 'Instant audio on every customer UPI payment',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildHighlightRow(
                      icon: Icons.translate_rounded,
                      text: 'Available in Hindi, Marathi, Gujarati, Tamil & more',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildHighlightRow(
                      icon: Icons.savings_outlined,
                      text: 'Save ₹1,500+ every year over hardware soundboxes',
                    ),

                    const Spacer(flex: 2),

                    // ── View Offer Button ─────────────────────────────────────
                    PrimaryButton(
                      label: 'View Premium Offer',
                      icon: Icons.star_rounded,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => const PaywallScreen(sourceEntry: 'onboarding'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // ── Continue to Dashboard ─────────────────────────────────
                    CustomOutlineButton(
                      label: 'Continue with Free Soundbox',
                      onPressed: onFinish,
                    ),
                    const SizedBox(height: AppSpacing.base),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: List.generate(5, (i) {
        final active = i == 4;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: active ? AppColors.primaryBlue : AppColors.primaryBlue.withAlpha(60),
              borderRadius: AppRadius.pillRadius,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildHighlightRow({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryBlue),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
