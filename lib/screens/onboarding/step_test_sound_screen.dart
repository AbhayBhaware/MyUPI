// lib/screens/onboarding/step_test_sound_screen.dart
//
// Onboarding Step 5 — Test Soundbox.
// Dedicated interactive screen allowing the merchant to hear a sample
// announcement and verify volume / TTS before completing setup.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_channels.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../tts_service.dart';
import '../../widgets/premium_buttons.dart';

class StepTestSoundScreen extends StatefulWidget {
  final VoidCallback onContinue;
  const StepTestSoundScreen({super.key, required this.onContinue});

  @override
  State<StepTestSoundScreen> createState() => _StepTestSoundScreenState();
}

class _StepTestSoundScreenState extends State<StepTestSoundScreen> {
  bool _testPlayed = false;
  bool _testFailed = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    TtsService.instance.onStatusChanged = () {
      if (mounted) setState(() {});
    };
    TtsService.instance.initialize();
  }

  @override
  void dispose() {
    TtsService.instance.onStatusChanged = null;
    super.dispose();
  }

  Future<void> _playTest() async {
    setState(() {
      _isPlaying = true;
      _testFailed = false;
    });

    try {
      // Try native TTS first (active on real Android devices).
      await kMethodChannel.invokeMethod('speakTest');
      if (mounted) {
        setState(() {
          _testPlayed = true;
          _isPlaying = false;
        });
      }
    } on PlatformException catch (_) {
      // Fallback to Flutter TTS engine.
      try {
        TtsService.instance.speakTest();
        if (mounted) {
          setState(() {
            _testPlayed = true;
            _isPlaying = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _testFailed = true;
            _isPlaying = false;
          });
        }
      }
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
              const _StepIndicator(current: 5, total: 6),
              const SizedBox(height: AppSpacing.xl),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Icon ────────────────────────────────────────────────
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: _testPlayed ? AppColors.successBg : AppColors.lightBlue,
                          borderRadius: AppRadius.lgRadius,
                          border: Border.all(
                            color: _testPlayed ? AppColors.successBorder : AppColors.primaryBlue.withAlpha(50),
                            width: 1.0,
                          ),
                        ),
                        child: Icon(
                          _testPlayed ? Icons.check_circle_rounded : Icons.volume_up_rounded,
                          size: 38,
                          color: _testPlayed ? AppColors.success : AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Title ───────────────────────────────────────────────
                      const Text(
                        'Test Your Soundbox',
                        style: AppTypography.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Turn up your phone volume and tap the button below to test how payment alerts will sound in your shop.',
                        style: AppTypography.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ── Test Result Banner ──────────────────────────────────
                      if (_testPlayed)
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.base),
                          decoration: BoxDecoration(
                            color: AppColors.successBg,
                            borderRadius: AppRadius.mdRadius,
                            border: Border.all(color: AppColors.successBorder),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
                              SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Soundbox is working!',
                                      style: TextStyle(
                                        color: AppColors.success,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Your phone is ready to announce incoming UPI payments loud and clear.',
                                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_testFailed)
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.base),
                          decoration: BoxDecoration(
                            color: AppColors.warningBg,
                            borderRadius: AppRadius.mdRadius,
                            border: Border.all(color: AppColors.warningBorder),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
                              SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Audio test could not be completed',
                                      style: TextStyle(
                                        color: Color(0xFFB45309),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Please ensure media volume is high and Google TTS engine is installed.',
                                      style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: AppSpacing.lg),

                      // ── Big Test Button ─────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _isPlaying ? null : _playTest,
                          icon: _isPlaying
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                                )
                              : Icon(
                                  _testPlayed ? Icons.replay_rounded : Icons.play_arrow_rounded,
                                  size: 24,
                                  color: AppColors.primaryBlue,
                                ),
                          label: Text(
                            _isPlaying
                                ? 'Speaking…'
                                : _testPlayed
                                    ? 'Test Again'
                                    : 'Test Soundbox',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                            shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
                            backgroundColor: AppColors.lightBlue.withAlpha(50),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      Center(
                        child: Text(
                          'Test audio: "This is a MyUPI soundbox test."',
                          style: AppTypography.caption,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),

              // ── Continue Button ─────────────────────────────────────────────
              PrimaryButton(
                label: 'Continue',
                icon: Icons.arrow_forward_rounded,
                onPressed: widget.onContinue,
              ),
              const SizedBox(height: AppSpacing.base),
            ],
          ),
        ),
      ),
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
