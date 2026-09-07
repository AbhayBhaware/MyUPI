// lib/screens/onboarding/step_ready_screen.dart
//
// Onboarding Step 6 — Ready! Final summary screen.
// Calls setOnboardingCompleted() then navigates to Dashboard.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_channels.dart';

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
    } on PlatformException catch (_) {
      // Even if the Kotlin call fails, proceed — worst case is onboarding shows again.
    }
    if (mounted) {
      setState(() => _saving = false);
      widget.onFinish();
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
              _StepIndicator(current: 6, total: 6),
              const SizedBox(height: 32),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),

                      // ── Celebration icon ────────────────────────────────────
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(30),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle, size: 60, color: Colors.green),
                      ),
                      const SizedBox(height: 24),

                      // ── Headline ────────────────────────────────────────────
                      Text(
                        'MyUPI is ready',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'When a supported UPI payment notification arrives, your phone will announce the payment instantly.',
                        style: TextStyle(
                          fontSize: 15,
                          color: cs.onSurface.withAlpha(180),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 28),

                      // ── Checklist ───────────────────────────────────────────
                      _buildChecklist(cs),

                      const SizedBox(height: 24),

                      // Merchant reassurance banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withAlpha(50),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.verified_user_outlined, color: cs.primary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Works offline. Zero soundbox machine rent. All notifications processed securely on this device.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withAlpha(180),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Go to Dashboard Button ──────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _finishOnboarding,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    _saving ? 'Opening Dashboard…' : 'Go to Dashboard',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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

  Widget _buildChecklist(ColorScheme cs) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withAlpha(50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _ChecklistItem(
              icon: widget.notifAccessGranted
                  ? Icons.check_circle
                  : Icons.warning_amber_rounded,
              color: widget.notifAccessGranted ? Colors.green : Colors.orange,
              label: widget.notifAccessGranted
                  ? 'Notification access enabled'
                  : 'Notification access pending (enable in Dashboard)',
            ),
            const Divider(height: 18),
            _ChecklistItem(
              icon: widget.soundboxEnabled ? Icons.check_circle : Icons.volume_off,
              color: widget.soundboxEnabled ? Colors.green : Colors.grey,
              label: widget.soundboxEnabled
                  ? 'Soundbox voice announcements ON'
                  : 'Soundbox paused (can turn on anytime)',
            ),
            const Divider(height: 18),
            const _ChecklistItem(
              icon: Icons.check_circle,
              color: Colors.green,
              label: 'PhonePe, Google Pay, Paytm & BHIM ready',
            ),
            const Divider(height: 18),
            const _ChecklistItem(
              icon: Icons.check_circle,
              color: Colors.green,
              label: '8 Indian languages & shop name supported',
            ),
          ],
        ),
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
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
