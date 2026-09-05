// lib/screens/onboarding/welcome_screen.dart
//
// Step 0 — Welcome (first screen of onboarding flow).
// Pure informational screen; no permissions requested here.

import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onGetStarted;
  const WelcomeScreen({super.key, required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── App icon / logo area ────────────────────────────────────────
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(Icons.speaker, size: 54, color: cs.onPrimary),
              ),
              const SizedBox(height: 28),

              // ── App name ───────────────────────────────────────────────────
              Text(
                'MyUPI',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your smart UPI soundbox',
                style: TextStyle(
                  fontSize: 18,
                  color: cs.onSurface.withAlpha(170),
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // ── Description ────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withAlpha(120),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Turn your Android phone into a smart payment announcement device.\n\n'
                  'Every time you receive a UPI payment, MyUPI speaks it aloud — '
                  'so you can focus on your customers without checking your phone.',
                  style: TextStyle(
                    fontSize: 15,
                    color: cs.onSurface.withAlpha(200),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const Spacer(flex: 3),

              // ── Get Started ────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: onGetStarted,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text(
                    'Get Started',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Text(
                'Free · No sign-up required · Works offline',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withAlpha(110),
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
