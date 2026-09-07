// lib/screens/onboarding/step_sound_screen.dart
//
// Onboarding Step 3 — Soundbox Setup.
// Configures soundbox toggle, language, speech speed, and announcement style.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_channels.dart';

class StepSoundScreen extends StatefulWidget {
  final VoidCallback onContinue;
  const StepSoundScreen({super.key, required this.onContinue});

  @override
  State<StepSoundScreen> createState() => _StepSoundScreenState();
}

class _StepSoundScreenState extends State<StepSoundScreen> {
  bool   _soundboxEnabled = true;
  String _language        = 'en-IN';
  String _speechSpeed     = 'normal';
  String _announceFormat  = 'A';
  bool   _loading         = true;

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
            backgroundColor: Colors.orange,
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Step indicator ──────────────────────────────────────────────
              _StepIndicator(current: 3, total: 6),
              const SizedBox(height: 32),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Icon ──────────────────────────────────────────
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: cs.primary.withAlpha(25),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                Icons.tune_rounded,
                                size: 40,
                                color: cs.primary,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ── Title ─────────────────────────────────────────
                            Text(
                              'Soundbox Setup',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Choose your preferred voice language, speech speed, and announcement style.',
                              style: TextStyle(
                                fontSize: 15,
                                color: cs.onSurface.withAlpha(180),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ── 1. Soundbox ON/OFF ─────────────────────────────
                            Card(
                              elevation: 0,
                              color: cs.surfaceContainerHighest.withAlpha(60),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: cs.outlineVariant.withAlpha(80)),
                              ),
                              child: SwitchListTile(
                                title: const Text(
                                  'Voice Soundbox',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                ),
                                subtitle: Text(
                                  _soundboxEnabled
                                      ? 'Payment announcements are enabled'
                                      : 'Payment announcements are paused',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _soundboxEnabled ? Colors.green : Colors.grey,
                                  ),
                                ),
                                secondary: Icon(
                                  _soundboxEnabled ? Icons.volume_up : Icons.volume_off,
                                  color: _soundboxEnabled ? cs.primary : Colors.grey,
                                ),
                                value: _soundboxEnabled,
                                onChanged: _toggleSoundbox,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ── 2. Announcement Language ──────────────────────
                            Text(
                              'Announcement Language',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _language,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.language),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: cs.surfaceContainerHighest.withAlpha(40),
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
                            const SizedBox(height: 16),

                            // ── 3. Speech Speed ───────────────────────────────
                            Text(
                              'Voice Speed',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'slow', label: Text('Slow')),
                                ButtonSegment(value: 'normal', label: Text('Normal')),
                                ButtonSegment(value: 'fast', label: Text('Fast')),
                              ],
                              selected: {_speechSpeed},
                              onSelectionChanged: (set) {
                                if (set.isNotEmpty) _setSpeed(set.first);
                              },
                            ),
                            const SizedBox(height: 16),

                            // ── 4. Announcement Style ─────────────────────────
                            Text(
                              'Announcement Format',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Column(
                              children: [
                                _FormatOption(
                                  id: 'A',
                                  title: 'Standard',
                                  sample: 'Received ₹100 on PhonePe',
                                  selected: _announceFormat == 'A',
                                  onSelect: () => _setAnnounceFormat('A'),
                                ),
                                const SizedBox(height: 8),
                                _FormatOption(
                                  id: 'B',
                                  title: 'Short',
                                  sample: '₹100 received',
                                  selected: _announceFormat == 'B',
                                  onSelect: () => _setAnnounceFormat('B'),
                                ),
                                const SizedBox(height: 8),
                                _FormatOption(
                                  id: 'C',
                                  title: 'Quick',
                                  sample: 'Paid ₹100',
                                  selected: _announceFormat == 'C',
                                  onSelect: () => _setAnnounceFormat('C'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
              ),

              // ── Continue Button ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: widget.onContinue,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant.withAlpha(80),
            width: selected ? 2 : 1,
          ),
          color: selected ? cs.primaryContainer.withAlpha(50) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? cs.primary : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    sample,
                    style: TextStyle(fontSize: 12, color: cs.onSurface.withAlpha(140)),
                  ),
                ],
              ),
            ),
          ],
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
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (int i = 1; i <= total; i++) ...[
          Container(
            width: i == current ? 28 : 10,
            height: 10,
            decoration: BoxDecoration(
              color: i == current
                  ? cs.primary
                  : i < current
                      ? cs.primary.withAlpha(120)
                      : cs.onSurface.withAlpha(40),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          if (i < total) const SizedBox(width: 6),
        ],
        const SizedBox(width: 12),
        Text(
          'Step $current of $total',
          style: TextStyle(fontSize: 12, color: cs.onSurface.withAlpha(140)),
        ),
      ],
    );
  }
}
