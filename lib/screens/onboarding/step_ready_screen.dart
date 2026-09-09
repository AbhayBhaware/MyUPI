// lib/screens/onboarding/step_ready_screen.dart
//
// Onboarding Step 6 — Ready! Final summary screen.
// Calls setOnboardingCompleted() then navigates to Dashboard.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_channels.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/premium_buttons.dart';
import '../../widgets/premium_card.dart';

class StepReadyScreen extends StatefulWidget {
  final VoidCallback onFinish;
  final bool notifAccessGranted;
  final bool soundboxEnabled;

  const StepReadyScreen({
    super.key,
    required this.onFinish,
    required this.notifAccessGranted,
    required this.soundboxEnabled,
  });

  @override
  State<StepReadyScreen> createState() => _StepReadyScreenState();
}

class _StepReadyScreenState extends State<StepReadyScreen> {
  bool _saving = false;

  Future<void> _finishOnboarding() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await kMethodChannel.invokeMethod('setOnboardingCompleted');
    } on PlatformException catch (_) {}
    if (mounted) {
      setState(() => _saving = false);
      widget.onFinish();
    }
  }

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
              const _StepIndicator(current: 6, total: 6),
              const SizedBox(height: AppSpacing.xl),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.md),

                      // ── Celebration icon ────────────────────────────────────
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: AppColors.successBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.successBorder, width: 2.0),
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          size: 56,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Headline ────────────────────────────────────────────
                      const Text(
                        'MyUPI is ready',
                        style: AppTypography.headlineLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'When a supported UPI payment notification arrives, your phone will announce the payment instantly.',
                        style: AppTypography.bodyMedium,
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // ── Checklist ───────────────────────────────────────────
                      _buildChecklist(),

                      const SizedBox(height: AppSpacing.lg),

                      // Merchant reassurance banner
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.lightBlue,
                          borderRadius: AppRadius.mdRadius,
                          border: Border.all(color: AppColors.primaryBlue.withAlpha(50)),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.verified_user_rounded, color: AppColors.primaryBlue, size: 20),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Works offline. Zero soundbox machine rent. All notifications processed securely on this device.',
                                style: AppTypography.caption,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),

              // ── Go to Dashboard Button ──────────────────────────────────────
              PrimaryButton(
                label: _saving ? 'Opening Dashboard…' : 'Go to Dashboard',
                isLoading: _saving,
                icon: Icons.arrow_forward_rounded,
                onPressed: _saving ? null : _finishOnboarding,
              ),
              const SizedBox(height: AppSpacing.base),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChecklist() {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          _ChecklistItem(
            icon: widget.notifAccessGranted
                ? Icons.check_circle_rounded
                : Icons.warning_amber_rounded,
            color: widget.notifAccessGranted ? AppColors.success : AppColors.warning,
            label: widget.notifAccessGranted
                ? 'Notification access enabled'
                : 'Notification access pending (enable in Dashboard)',
          ),
          const Divider(height: 20, color: AppColors.borderLight),
          _ChecklistItem(
            icon: widget.soundboxEnabled ? Icons.check_circle_rounded : Icons.volume_off_rounded,
            color: widget.soundboxEnabled ? AppColors.success : AppColors.textTertiary,
            label: widget.soundboxEnabled
                ? 'Soundbox voice announcements ON'
                : 'Soundbox paused (can turn on anytime)',
          ),
          const Divider(height: 20, color: AppColors.borderLight),
          const _ChecklistItem(
            icon: Icons.check_circle_rounded,
            color: AppColors.success,
            label: 'PhonePe, Google Pay, Paytm & BHIM ready',
          ),
          const Divider(height: 20, color: AppColors.borderLight),
          const _ChecklistItem(
            icon: Icons.check_circle_rounded,
            color: AppColors.success,
            label: '8 Indian languages & shop name supported',
          ),
        ],
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _ChecklistItem({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 1; i <= total; i++) ...[
          Container(
            width: i == current ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == current
                  ? AppColors.primaryBlue
                  : i < current
                      ? AppColors.primaryBlue.withAlpha(120)
                      : AppColors.borderMedium,
              borderRadius: AppRadius.pillRadius,
            ),
          ),
          if (i < total) const SizedBox(width: 5),
        ],
        const SizedBox(width: AppSpacing.md),
        Text(
          'Step $current of $total',
          style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
