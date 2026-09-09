// lib/screens/onboarding/step_notif_screen.dart
//
// Onboarding Step 1 — Notification Access.
// Uses the EXISTING MethodChannel implementation — no new permission logic.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_channels.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/premium_buttons.dart';

class StepNotifScreen extends StatefulWidget {
  final VoidCallback onContinue;
  const StepNotifScreen({super.key, required this.onContinue});

  @override
  State<StepNotifScreen> createState() => _StepNotifScreenState();
}

class _StepNotifScreenState extends State<StepNotifScreen>
    with WidgetsBindingObserver {
  bool? _accessGranted; // null = checking
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAccess();
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

  Future<void> _checkAccess() async {
    setState(() => _checking = true);
    try {
      final ok = await kMethodChannel
              .invokeMethod<bool>('isNotificationAccessEnabled') ??
          false;
      if (mounted) {
        setState(() {
          _accessGranted = ok;
          _checking = false;
        });
      }
    } on PlatformException catch (_) {
      if (mounted) {
        setState(() {
          _accessGranted = false;
          _checking = false;
        });
      }
    }
  }

  Future<void> _openSettings() async {
    try {
      await kMethodChannel.invokeMethod('openNotificationAccessSettings');
    } on PlatformException catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final granted = _accessGranted == true;

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
              const _StepIndicator(current: 2, total: 6),
              const SizedBox(height: AppSpacing.xl),

              // ── Icon ────────────────────────────────────────────────────────
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: granted ? AppColors.successBg : AppColors.lightBlue,
                  borderRadius: AppRadius.lgRadius,
                  border: Border.all(
                    color: granted ? AppColors.successBorder : AppColors.primaryBlue.withAlpha(50),
                    width: 1.0,
                  ),
                ),
                child: Icon(
                  granted ? Icons.check_circle_rounded : Icons.notifications_active_rounded,
                  size: 38,
                  color: granted ? AppColors.success : AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Title ───────────────────────────────────────────────────────
              const Text(
                'Allow MyUPI to hear payment notifications',
                style: AppTypography.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Body ────────────────────────────────────────────────────────
              const Text(
                'MyUPI uses payment notifications from supported UPI apps to announce incoming payments aloud.',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: AppRadius.mdRadius,
                  border: Border.all(color: AppColors.successBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.shield_rounded, size: 20, color: AppColors.success),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'MyUPI does not need or access your UPI PIN, bank password, or card details. Everything stays private on your phone.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF14532D),
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Status card ─────────────────────────────────────────────────
              _AccessStatusCard(
                checking: _checking,
                granted: granted,
                onOpenSettings: _openSettings,
              ),

              const Spacer(),

              // ── Continue / action button ─────────────────────────────────
              if (granted)
                PrimaryButton(
                  label: 'Continue',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: widget.onContinue,
                )
              else
                PrimaryButton(
                  label: 'Enable Notification Access',
                  icon: Icons.open_in_new_rounded,
                  onPressed: _openSettings,
                ),
              const SizedBox(height: AppSpacing.base),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Access status card ──────────────────────────────────────────────────────

class _AccessStatusCard extends StatelessWidget {
  final bool checking;
  final bool granted;
  final VoidCallback onOpenSettings;

  const _AccessStatusCard({
    required this.checking,
    required this.granted,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: AppRadius.mdRadius,
          border: Border.all(color: AppColors.borderLight),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
            ),
            SizedBox(width: AppSpacing.md),
            Text('Checking notification access…', style: AppTypography.bodySmall),
          ],
        ),
      );
    }

    if (granted) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.successBg,
          borderRadius: AppRadius.mdRadius,
          border: Border.all(color: AppColors.successBorder),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Notification access enabled',
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: AppColors.warningBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Notification access is still disabled.',
                  style: TextStyle(
                    color: Color(0xFFB45309),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'MyUPI cannot detect UPI payments until you enable notification access.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF92400E),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step indicator ───────────────────────────────────────────────────────────

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
