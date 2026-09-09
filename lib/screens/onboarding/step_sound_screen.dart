// lib/screens/onboarding/step_sound_screen.dart
//
// Onboarding Step 3 — Soundbox Setup.
// Configures soundbox toggle, language, speech speed, and announcement style.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_channels.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/premium_buttons.dart';
import '../../widgets/premium_card.dart';

class StepSoundScreen extends StatefulWidget {
  final VoidCallback onContinue;
  const StepSoundScreen({super.key, required this.onContinue});

  @override
  State<StepSoundScreen> createState() => _StepSoundScreenState();
}

class _StepSoundScreenState extends State<StepSoundScreen> {
  bool _soundboxEnabled = true;
  String _language = 'en-IN';
  String _speechSpeed = 'normal';
  String _announceFormat = 'A';
  bool _loading = true;

  static const _kLanguages = [
    ('en-IN', 'English (India)', 'English'),
    ('hi-IN', 'Hindi', 'हिन्दी'),
    ('mr-IN', 'Marathi', 'मराठी'),
    ('gu-IN', 'Gujarati', 'ગુજરાતી'),
    ('ta-IN', 'Tamil', 'தமிழ்'),
    ('te-IN', 'Telugu', 'తెలుగు'),
    ('bn-IN', 'Bengali', 'বাংলা'),
    ('kn-IN', 'Kannada', 'ಕನ್ನಡ'),
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final on = await kMethodChannel.invokeMethod<bool>('isSoundboxEnabled') ?? true;
      final lang = await kMethodChannel.invokeMethod<String>('getLanguage') ?? 'en-IN';
      final speed = await kMethodChannel.invokeMethod<String>('getSpeechSpeed') ?? 'normal';
      final fmt = await kMethodChannel.invokeMethod<String>('getAnnouncementFormat') ?? 'A';
      if (mounted) {
        setState(() {
          _soundboxEnabled = on;
          _language = lang;
          _speechSpeed = speed;
          _announceFormat = fmt;
          _loading = false;
        });
      }
    } on PlatformException catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleSoundbox(bool v) async {
    setState(() => _soundboxEnabled = v);
    try {
      await kMethodChannel.invokeMethod('setSoundboxEnabled', {'enabled': v});
    } on PlatformException catch (_) {}
  }

  Future<void> _setLanguage(String langCode) async {
    try {
      final available = await kMethodChannel.invokeMethod<bool>(
        'checkLanguageAvailability',
        {'language': langCode},
      );
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

  Future<void> _setSpeed(String v) async {
    setState(() => _speechSpeed = v);
    try {
      await kMethodChannel.invokeMethod('setSpeechSpeed', {'speed': v});
    } on PlatformException catch (_) {}
  }

  Future<void> _setAnnounceFormat(String v) async {
    setState(() => _announceFormat = v);
    try {
      await kMethodChannel.invokeMethod('setAnnouncementFormat', {'format': v});
    } on PlatformException catch (_) {}
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
              const _StepIndicator(current: 3, total: 6),
              const SizedBox(height: AppSpacing.xl),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Icon ──────────────────────────────────────────
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: AppColors.lightBlue,
                                borderRadius: AppRadius.lgRadius,
                                border: Border.all(color: AppColors.primaryBlue.withAlpha(50), width: 1.0),
                              ),
                              child: const Icon(
                                Icons.tune_rounded,
                                size: 38,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),

                            // ── Title ─────────────────────────────────────────
                            const Text(
                              'Soundbox Setup',
                              style: AppTypography.headlineMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            const Text(
                              'Choose your preferred voice language, speech speed, and announcement style.',
                              style: AppTypography.bodyMedium,
                            ),
                            const SizedBox(height: AppSpacing.lg),

                            // ── 1. Soundbox ON/OFF ─────────────────────────────
                            PremiumCard(
                              padding: EdgeInsets.zero,
                              child: SwitchListTile(
                                activeThumbColor: AppColors.primaryBlue,
                                title: const Text(
                                  'Voice Soundbox',
                                  style: AppTypography.titleSmall,
                                ),
                                subtitle: Text(
                                  _soundboxEnabled
                                      ? 'Payment announcements are enabled'
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
                                onChanged: _toggleSoundbox,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.base),

                            // ── 2. Announcement Language ──────────────────────
                            const Text(
                              'Announcement Language',
                              style: AppTypography.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            DropdownButtonFormField<String>(
                              initialValue: _language,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.language_rounded, color: AppColors.primaryBlue),
                                border: OutlineInputBorder(
                                  borderRadius: AppRadius.mdRadius,
                                  borderSide: const BorderSide(color: AppColors.borderMedium),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: AppRadius.mdRadius,
                                  borderSide: const BorderSide(color: AppColors.borderMedium),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: AppRadius.mdRadius,
                                  borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                                ),
                                filled: true,
                                fillColor: AppColors.surface,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              items: _kLanguages.map((item) {
                                final (code, enName, natName) = item;
                                return DropdownMenuItem<String>(
                                  value: code,
                                  child: Text('$enName ($natName)'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) _setLanguage(val);
                              },
                            ),
                            const SizedBox(height: AppSpacing.base),

                            // ── 3. Speech Speed ───────────────────────────────
                            const Text(
                              'Voice Speed',
                              style: AppTypography.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'slow', label: Text('Slow')),
                                ButtonSegment(value: 'normal', label: Text('Normal')),
                                ButtonSegment(value: 'fast', label: Text('Fast')),
                              ],
                              selected: {_speechSpeed},
                              style: ButtonStyle(
                                visualDensity: VisualDensity.comfortable,
                                shape: WidgetStateProperty.all(
                                  const RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
                                ),
                              ),
                              onSelectionChanged: (set) {
                                if (set.isNotEmpty) _setSpeed(set.first);
                              },
                            ),
                            const SizedBox(height: AppSpacing.base),

                            // ── 4. Announcement Style ─────────────────────────
                            const Text(
                              'Announcement Format',
                              style: AppTypography.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Column(
                              children: [
                                _FormatOption(
                                  id: 'A',
                                  title: 'Standard',
                                  sample: 'Received ₹100 on PhonePe',
                                  selected: _announceFormat == 'A',
                                  onSelect: () => _setAnnounceFormat('A'),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                _FormatOption(
                                  id: 'B',
                                  title: 'Short',
                                  sample: '₹100 received',
                                  selected: _announceFormat == 'B',
                                  onSelect: () => _setAnnounceFormat('B'),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                _FormatOption(
                                  id: 'C',
                                  title: 'Quick',
                                  sample: 'Paid ₹100',
                                  selected: _announceFormat == 'C',
                                  onSelect: () => _setAnnounceFormat('C'),
                                ),
                              ],
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

class _FormatOption extends StatelessWidget {
  final String id;
  final String title;
  final String sample;
  final bool selected;
  final VoidCallback onSelect;

  const _FormatOption({
    required this.id,
    required this.title,
    required this.sample,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.lightBlue : AppColors.surface,
      borderRadius: AppRadius.mdRadius,
      child: InkWell(
        onTap: onSelect,
        borderRadius: AppRadius.mdRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdRadius,
            border: Border.all(
              color: selected ? AppColors.primaryBlue : AppColors.borderLight,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? AppColors.primaryBlue : AppColors.textTertiary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: selected ? AppColors.primaryBlue : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      sample,
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
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
