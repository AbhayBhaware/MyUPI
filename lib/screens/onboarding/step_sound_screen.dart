// lib/screens/onboarding/step_sound_screen.dart
//
// Onboarding Step 2 — Soundbox toggle + Step 3 — Test Sound (combined).
// Reuses existing persistent soundbox setting and native TTS test.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_channels.dart';
import '../../tts_service.dart';

class StepSoundScreen extends StatefulWidget {
  final VoidCallback onContinue;
  const StepSoundScreen({super.key, required this.onContinue});

  @override
  State<StepSoundScreen> createState() => _StepSoundScreenState();
}

class _StepSoundScreenState extends State<StepSoundScreen> {

  bool  _soundboxEnabled = true;
  bool  _testPlayed      = false;
  bool  _testFailed      = false;
  bool  _loadingSettings = true;

  @override
  void initState() {
    super.initState();
    TtsService.instance.onStatusChanged = () {
      if (mounted) setState(() {});
    };
    TtsService.instance.initialize();
    _loadSettings();
  }

  @override
  void dispose() {
    TtsService.instance.onStatusChanged = null;
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final on = await kMethodChannel.invokeMethod<bool>('isSoundboxEnabled') ?? true;
      if (mounted) setState(() { _soundboxEnabled = on; _loadingSettings = false; });
    } on PlatformException catch (_) {
      if (mounted) setState(() => _loadingSettings = false);
    }
  }

  Future<void> _toggleSoundbox(bool v) async {
    setState(() => _soundboxEnabled = v);
    try { await kMethodChannel.invokeMethod('setSoundboxEnabled', {'enabled': v}); }
    on PlatformException catch (_) {}
  }

  Future<void> _playTest() async {
    setState(() { _testFailed = false; });
    try {
      // Try native TTS first (real device).
      await kMethodChannel.invokeMethod('speakTest');
      if (mounted) setState(() => _testPlayed = true);
    } on PlatformException catch (_) {
      // Flutter TTS fallback.
      try {
        TtsService.instance.speakTest();
        if (mounted) setState(() => _testPlayed = true);
      } catch (_) {
        if (mounted) setState(() => _testFailed = true);
      }
    }
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
              _buildStepIndicator(cs),
              const SizedBox(height: 32),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ═══════════════════════════════════
                      // PART A: Soundbox toggle
                      // ═══════════════════════════════════
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          color: cs.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(Icons.volume_up_outlined,
                            size: 40, color: cs.primary),
                      ),
                      const SizedBox(height: 20),
                      Text('Turn on Soundbox',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: cs.onSurface)),
                      const SizedBox(height: 8),
                      Text(
                        'MyUPI will announce successful UPI payments through your phone speaker.',
                        style: TextStyle(
                            fontSize: 15,
                            color: cs.onSurface.withAlpha(180),
                            height: 1.6),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        child: _loadingSettings
                            ? const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                    child: CircularProgressIndicator()))
                            : SwitchListTile(
                                title: const Text('Soundbox',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16)),
                                subtitle: Text(
                                  _soundboxEnabled
                                      ? 'Payment announcements are on'
                                      : 'Payment announcements are off',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _soundboxEnabled
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                ),
                                secondary: Icon(
                                  _soundboxEnabled
                                      ? Icons.volume_up
                                      : Icons.volume_off,
                                  color: _soundboxEnabled
                                      ? cs.primary
                                      : Colors.grey,
                                ),
                                value: _soundboxEnabled,
                                onChanged: _toggleSoundbox,
                              ),
                      ),

                      const SizedBox(height: 32),

                      // ═══════════════════════════════════
                      // PART B: Test sound
                      // ═══════════════════════════════════
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          color: _testPlayed
                              ? Colors.green.withAlpha(30)
                              : cs.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          _testPlayed
                              ? Icons.check_circle_outline
                              : Icons.play_circle_outline,
                          size: 40,
                          color: _testPlayed ? Colors.green : cs.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text("Let's test your soundbox",
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: cs.onSurface)),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the button below to hear a sample announcement '
                        'before you start using MyUPI.',
                        style: TextStyle(
                            fontSize: 15,
                            color: cs.onSurface.withAlpha(180),
                            height: 1.6),
                      ),
                      const SizedBox(height: 20),

                      // Test status
                      if (_testPlayed)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.withAlpha(80)),
                          ),
                          child: const Row(children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 10),
                            Text('Sound is working',
                                style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        )
                      else if (_testFailed)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.orange.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.withAlpha(80)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(children: [
                                Icon(Icons.warning_amber, color: Colors.orange),
                                SizedBox(width: 10),
                                Text('Sound test could not be completed.',
                                    style: TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w600)),
                              ]),
                              const SizedBox(height: 6),
                              Text('Check that your volume is turned up.',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.orange.shade800)),
                            ],
                          ),
                        ),

                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _playTest,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(
                            _testPlayed ? 'Play Again' : 'Play Test Sound',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The test sound will not create any payment record.',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurface.withAlpha(110)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // ── Continue button ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  // Allow continue even without playing test (user may skip).
                  onPressed: widget.onContinue,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Continue',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
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

  Widget _buildStepIndicator(ColorScheme cs) {
    return Row(children: [
      for (int i = 1; i <= 3; i++) ...[
        Container(
          width: i == 2 ? 28 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: i == 2
                ? cs.primary
                : i < 2
                    ? cs.primary.withAlpha(120)
                    : cs.onSurface.withAlpha(40),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        if (i < 3) const SizedBox(width: 6),
      ],
      const SizedBox(width: 12),
      Text('Step 2 of 3',
          style: TextStyle(fontSize: 12, color: cs.onSurface.withAlpha(140))),
    ]);
  }
}
