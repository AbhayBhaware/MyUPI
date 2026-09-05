// lib/screens/onboarding/step_notif_screen.dart
//
// Onboarding Step 1 — Notification Access.
// Uses the EXISTING MethodChannel implementation — no new permission logic.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_channels.dart';

class StepNotifScreen extends StatefulWidget {
  final VoidCallback onContinue;
  const StepNotifScreen({super.key, required this.onContinue});

  @override
  State<StepNotifScreen> createState() => _StepNotifScreenState();
}

class _StepNotifScreenState extends State<StepNotifScreen>
    with WidgetsBindingObserver {

  bool? _accessGranted; // null = checking
  bool  _checking = true;

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
    // Re-check when the user returns from Android Settings.
    if (state == AppLifecycleState.resumed) _checkAccess();
  }

  Future<void> _checkAccess() async {
    setState(() => _checking = true);
    try {
      final ok = await kMethodChannel
          .invokeMethod<bool>('isNotificationAccessEnabled') ?? false;
      if (mounted) setState(() { _accessGranted = ok; _checking = false; });
    } on PlatformException catch (_) {
      if (mounted) setState(() { _accessGranted = false; _checking = false; });
    }
  }

  Future<void> _openSettings() async {
    try {
      await kMethodChannel.invokeMethod('openNotificationAccessSettings');
    } on PlatformException catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final granted = _accessGranted == true;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Step indicator ──────────────────────────────────────────────
              _StepIndicator(current: 1, total: 3),
              const SizedBox(height: 32),

              // ── Icon ────────────────────────────────────────────────────────
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: granted
                      ? Colors.green.withAlpha(30)
                      : cs.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  granted ? Icons.check_circle_outline : Icons.notifications_outlined,
                  size: 40,
                  color: granted ? Colors.green : cs.primary,
                ),
              ),
              const SizedBox(height: 24),

              // ── Title ───────────────────────────────────────────────────────
              Text(
                'Enable Notification Access',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface),
              ),
              const SizedBox(height: 12),

              // ── Body ────────────────────────────────────────────────────────
              Text(
                'MyUPI needs notification access to hear payment notifications '
                'from your UPI apps such as PhonePe, Paytm, and Google Pay.',
                style: TextStyle(
                    fontSize: 15,
                    color: cs.onSurface.withAlpha(180),
                    height: 1.6),
              ),
              const SizedBox(height: 8),
              Text(
                'MyUPI does not read the content of other app notifications or '
                'messages.',
                style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withAlpha(130),
                    height: 1.5),
              ),

              const SizedBox(height: 28),

              // ── Status card ─────────────────────────────────────────────────
              _AccessStatusCard(
                checking: _checking,
                granted: granted,
                onOpenSettings: _openSettings,
              ),

              const Spacer(),

              // ── Continue / action button ─────────────────────────────────
              if (granted)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: widget.onContinue,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Continue',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Enable Notification Access',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
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
    final cs = Theme.of(context).colorScheme;

    if (checking) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(children: [
          SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 14),
          Text('Checking notification access…'),
        ]),
      );
    }

    if (granted) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withAlpha(80)),
        ),
        child: const Row(children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Notification access enabled',
              style: TextStyle(
                  color: Colors.green, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withAlpha(80)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Notification access is still disabled.',
              style: TextStyle(
                  color: Colors.orange, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Text(
          'MyUPI cannot detect UPI payments until you enable notification access.',
          style: TextStyle(
              fontSize: 13, color: Colors.orange.shade800, height: 1.5),
        ),
      ]),
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
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
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
    ]);
  }
}
