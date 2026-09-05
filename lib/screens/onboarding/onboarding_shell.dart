// lib/screens/onboarding/onboarding_shell.dart
//
// Onboarding orchestrator — manages the 4-step (0–3) flow.
// Uses a PageView with physics disabled so only programmatic
// navigation is possible (no swipe-to-skip).
//
// Step 0: Welcome
// Step 1: Notification Access
// Step 2: Soundbox + Test Sound
// Step 3: Ready / Complete

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_channels.dart';
import 'welcome_screen.dart';
import 'step_notif_screen.dart';
import 'step_sound_screen.dart';
import 'step_ready_screen.dart';

class OnboardingShell extends StatefulWidget {
  /// Called when the user completes onboarding — navigate to the main shell.
  final VoidCallback onComplete;
  const OnboardingShell({super.key, required this.onComplete});

  @override
  State<OnboardingShell> createState() => _OnboardingShellState();
}

class _OnboardingShellState extends State<OnboardingShell> {

  final _controller = PageController();
  int   _page = 0;

  // State forwarded to the Ready screen.
  bool _notifAccess = false;
  bool _soundboxOn  = true;

  void _goNext() {
    _refreshState();
    final next = _page + 1;
    setState(() => _page = next);
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  /// Re-read notification access and soundbox state so the Ready screen
  /// reflects the real current values.
  Future<void> _refreshState() async {
    try {
      final access = await kMethodChannel
          .invokeMethod<bool>('isNotificationAccessEnabled') ?? false;
      final soundbox = await kMethodChannel
          .invokeMethod<bool>('isSoundboxEnabled') ?? true;
      if (mounted) setState(() { _notifAccess = access; _soundboxOn = soundbox; });
    } on PlatformException catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Intercept back button — go to previous step instead of exiting.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_page > 0) {
          setState(() => _page -= 1);
          _controller.animateToPage(
            _page,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
          );
        }
        // Page 0: do nothing — don't exit the app from onboarding.
      },
      child: PageView(
        controller: _controller,
        physics: const NeverScrollableScrollPhysics(), // no swipe skipping
        children: [
          // Step 0 — Welcome
          WelcomeScreen(onGetStarted: _goNext),

          // Step 1 — Notification Access
          StepNotifScreen(onContinue: _goNext),

          // Step 2 — Soundbox + Test Sound
          StepSoundScreen(onContinue: _goNext),

          // Step 3 — Ready
          StepReadyScreen(
            onFinish: widget.onComplete,
            notifAccessGranted: _notifAccess,
            soundboxEnabled: _soundboxOn,
          ),
        ],
      ),
    );
  }
}
