// lib/widgets/volume_indicator_pill.dart
//
// Glanceable Speaker Volume Indicator Pill + Quick Slider Sheet.
// -------------------------------------------------------------
// Displays current media stream volume percentage in the app bar.
// Warns the merchant if volume is muted or dangerously low for a noisy shop.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:volume_controller/volume_controller.dart';

import '../app_channels.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../tts_service.dart';

class VolumeIndicatorPill extends StatefulWidget {
  const VolumeIndicatorPill({super.key});

  static Future<void> showVolumeSheet(BuildContext context, {double initialVolume = 1.0, ValueChanged<double>? onVolumeChanged}) async {
    HapticFeedback.lightImpact();
    double currentVol = initialVolume;
    try {
      currentVol = await VolumeController.instance.getVolume();
    } catch (_) {}
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _VolumeControlSheet(
        initialVolume: currentVol,
        onVolumeChanged: onVolumeChanged ?? (_) {},
      ),
    );
  }

  @override
  State<VolumeIndicatorPill> createState() => _VolumeIndicatorPillState();
}

class _VolumeIndicatorPillState extends State<VolumeIndicatorPill> {
  double _volume = 1.0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initVolume();
  }

  Future<void> _initVolume() async {
    try {
      final vol = await VolumeController.instance.getVolume();
      if (mounted) {
        setState(() {
          _volume = vol.clamp(0.0, 1.0);
          _initialized = true;
        });
      }
      VolumeController.instance.addListener((vol) {
        if (mounted) {
          setState(() => _volume = vol.clamp(0.0, 1.0));
        }
      });
    } catch (_) {
      if (mounted) setState(() => _initialized = true);
    }
  }

  @override
  void dispose() {
    try {
      VolumeController.instance.removeListener();
    } catch (_) {}
    super.dispose();
  }

  void _showVolumeSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _VolumeControlSheet(
        initialVolume: _volume,
        onVolumeChanged: (v) {
          setState(() => _volume = v);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return const SizedBox.shrink();

    final isMuted = _volume <= 0.01;
    final isLow = _volume < 0.40;

    final Color bgColor = isMuted
        ? AppColors.errorBg
        : (isLow ? AppColors.warningBg : AppColors.surface);

    final Color borderColor = isMuted
        ? AppColors.errorBorder
        : (isLow ? AppColors.warningBorder : AppColors.cardBorder);

    final Color textColor = isMuted
        ? AppColors.error
        : (isLow ? const Color(0xFFB45309) : AppColors.textPrimary);

    final IconData icon = isMuted
        ? Icons.volume_off_rounded
        : (isLow ? Icons.volume_down_rounded : Icons.volume_up_rounded);

    final int pct = (_volume * 100).round();

    return InkWell(
      onTap: _showVolumeSheet,
      borderRadius: AppRadius.smRadius,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: AppRadius.smRadius,
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: 4),
              Text(
                isMuted ? 'MUTED' : '$pct%',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VolumeControlSheet extends StatefulWidget {
  final double initialVolume;
  final ValueChanged<double> onVolumeChanged;

  const _VolumeControlSheet({
    required this.initialVolume,
    required this.onVolumeChanged,
  });

  @override
  State<_VolumeControlSheet> createState() => _VolumeControlSheetState();
}

class _VolumeControlSheetState extends State<_VolumeControlSheet> {
  late double _currentVolume = widget.initialVolume;

  void _setVol(double v) {
    final clamped = v.clamp(0.0, 1.0);
    setState(() => _currentVolume = clamped);
    widget.onVolumeChanged(clamped);
    try {
      VolumeController.instance.setVolume(clamped);
    } catch (_) {}
  }

  void _playTestAudio() async {
    HapticFeedback.lightImpact();
    try {
      await kMethodChannel.invokeMethod('speakTest');
    } catch (_) {
      TtsService.instance.speakTest();
    }
  }

  @override
  Widget build(BuildContext context) {
    final int pct = (_currentVolume * 100).round();
    final isMuted = _currentVolume <= 0.01;
    final isLow = _currentVolume < 0.40;

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.base, AppSpacing.lg, AppSpacing.xl),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.base),
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.lightBlue,
                    borderRadius: AppRadius.smRadius,
                  ),
                  child: Icon(
                    isMuted
                        ? Icons.volume_off_rounded
                        : (isLow ? Icons.volume_down_rounded : Icons.volume_up_rounded),
                    color: isMuted ? AppColors.error : AppColors.primaryBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Soundbox Speaker Volume', style: AppTypography.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        isMuted
                            ? 'Muted — No voice will be spoken'
                            : '$pct% media volume',
                        style: AppTypography.caption.copyWith(
                          color: isMuted ? AppColors.error : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Warning note if volume is too low
            if (isMuted || isLow) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isMuted ? AppColors.errorBg : AppColors.warningBg,
                  borderRadius: AppRadius.smRadius,
                  border: Border.all(color: isMuted ? AppColors.errorBorder : AppColors.warningBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      isMuted ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
                      color: isMuted ? AppColors.error : AppColors.warning,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isMuted
                            ? 'Device is muted! Customer payment announcements will NOT be heard.'
                            : 'Volume is below 40%. Announcements may be missed in a noisy shop.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isMuted ? AppColors.error : const Color(0xFF92400E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Volume Slider
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: isMuted ? AppColors.error : AppColors.primaryBlue,
                inactiveTrackColor: AppColors.lightBlue,
                thumbColor: isMuted ? AppColors.error : AppColors.primaryBlue,
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              ),
              child: Slider(
                value: _currentVolume,
                min: 0.0,
                max: 1.0,
                onChanged: _setVol,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // Quick Preset Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPresetChip('Mute', 0.0),
                _buildPresetChip('50%', 0.5),
                _buildPresetChip('80%', 0.8),
                _buildPresetChip('Max 100%', 1.0),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Test audio button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _playTestAudio,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                  side: const BorderSide(color: AppColors.softBlueBorder, width: 1.2),
                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
                ),
                icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
                label: const Text('Test Announcement Voice', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, double val) {
    final isSelected = (_currentVolume - val).abs() < 0.05;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _setVol(val),
      selectedColor: AppColors.lightBlue,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primaryBlue : AppColors.cardBorder,
        width: 1.0,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
      visualDensity: VisualDensity.compact,
    );
  }
}
