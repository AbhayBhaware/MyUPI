// lib/screens/onboarding/step_ready_screen.dart
//
// Onboarding Step 3 — Ready! Final summary screen.
// Calls setOnboardingCompleted() then navigates to Dashboard.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_channels.dart';

class StepReadyScreen extends StatefulWidget {
  /// Called after the user taps "Go to Dashboard" and onboarding is persisted.
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
    } on PlatformException catch (_) {
      // Even if the Kotlin call fails, proceed — worst case is onboarding shows again.
    }
    if (mounted) widget.onFinish();
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
              const SizedBox(height: 40),

              Expanded(
                child: Column(
                  children: [
                    const Spacer(),

                    // ── Celebration icon ──────────────────────────────────────
                    Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle,
                          size: 60, color: Colors.green),
                    ),
                    const SizedBox(height: 24),

                    // ── Headline ──────────────────────────────────────────────
                    Text(
                      "You're all set!",
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'MyUPI is ready to announce your UPI payments.',
                      style: TextStyle(
                          fontSize: 16,
                          color: cs.onSurface.withAlpha(170),
                          height: 1.5),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 36),

                    // ── Checklist ─────────────────────────────────────────────
                    _buildChecklist(cs),

                    const Spacer(flex: 2),

                    // ── Go to Dashboard ───────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _finishOnboarding,
                        icon: _saving
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Icon(Icons.home_outlined),
                        label: Text(
                          _saving ? 'Starting…' : 'Go to Dashboard',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChecklist(ColorScheme cs) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          _ChecklistItem(
            icon: widget.notifAccessGranted
                ? Icons.check_circle
                : Icons.warning_amber_rounded,
            color: widget.notifAccessGranted ? Colors.green : Colors.orange,
            label: widget.notifAccessGranted
                ? 'Notification access enabled'
                : 'Notification access not yet enabled',
          ),
          const Divider(height: 20),
          _ChecklistItem(
            icon: widget.soundboxEnabled
                ? Icons.check_circle
                : Icons.volume_off,
            color: widget.soundboxEnabled ? Colors.green : Colors.grey,
            label: widget.soundboxEnabled
                ? 'Soundbox is on'
                : 'Soundbox is off (you can enable it in Settings)',
          ),
          const Divider(height: 20),
          const _ChecklistItem(
            icon: Icons.check_circle,
            color: Colors.green,
            label: 'Setup complete',
          ),
        ]),
      ),
    );
  }

  Widget _buildStepIndicator(ColorScheme cs) {
    return Row(children: [
      for (int i = 1; i <= 3; i++) ...[
        Container(
          width: i == 3 ? 28 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: cs.primary.withAlpha(i <= 3 ? 180 : 40),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        if (i < 3) const SizedBox(width: 6),
      ],
      const SizedBox(width: 12),
      Text('Step 3 of 3',
          style: TextStyle(fontSize: 12, color: cs.onSurface.withAlpha(140))),
    ]);
  }
}

// ─── Checklist item ───────────────────────────────────────────────────────────

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
    return Row(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(width: 12),
      Expanded(
        child: Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      ),
    ]);
  }
}
