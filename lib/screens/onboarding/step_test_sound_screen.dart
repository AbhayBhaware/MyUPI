// lib/screens/onboarding/step_test_sound_screen.dart
//
// Onboarding Step 5 — Test Soundbox.
// Dedicated interactive screen allowing the merchant to hear a sample
// announcement and verify volume / TTS before completing setup.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_channels.dart';
import '../../tts_service.dart';

class StepTestSoundScreen extends StatefulWidget {
  final VoidCallback onContinue;
  const StepTestSoundScreen({super.key, required this.onContinue});

  @override
  State<StepTestSoundScreen> createState() => _StepTestSoundScreenState();
}

class _StepTestSoundScreenState extends State<StepTestSoundScreen> {
  bool _testPlayed = false;
  bool _testFailed = false;
  bool _isPlaying  = false;

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
              _StepIndicator(current: 5, total: 6),
              const SizedBox(height: 32),

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
                          color: _testPlayed
                              ? Colors.green.withAlpha(30)
                              : cs.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          _testPlayed
                              ? Icons.check_circle_outline
                              : Icons.volume_up_rounded,
                          size: 40,
                          color: _testPlayed ? Colors.green : cs.primary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Title ───────────────────────────────────────────────
                      Text(
                        'Test Your Soundbox',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Turn up your phone volume and tap the button below to test how payment alerts will sound in your shop.',
                        style: TextStyle(
                          fontSize: 15,
                          color: cs.onSurface.withAlpha(180),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Test Result Banner ──────────────────────────────────
                      if (_testPlayed)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha(25),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.green.withAlpha(80)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 24),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Soundbox is working!',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Your phone is ready to announce incoming UPI payments loud and clear.',
                                      style: TextStyle(fontSize: 13, color: Colors.black87),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_testFailed)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withAlpha(20),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.orange.withAlpha(80)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Audio test could not be completed',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Please ensure media volume is high and Google TTS engine is installed.',
                                      style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),

                      // ── Big Test Button ─────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: _isPlaying ? null : _playTest,
                          icon: _isPlaying
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  _testPlayed ? Icons.replay : Icons.play_arrow_rounded,
                                  size: 26,
                                ),
                          label: Text(
                            _isPlaying
                                ? 'Speaking…'
                                : _testPlayed
                                    ? 'Test Again'
                                    : 'Test Soundbox',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: cs.primary, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Center(
                        child: Text(
                          'Test audio: "This is a MyUPI soundbox test."',
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: cs.onSurface.withAlpha(140),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'This test will not add any entry to your payment ledger.',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withAlpha(110),
                          ),
                        ),
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
