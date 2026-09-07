// lib/screens/onboarding/step_premium_intro_screen.dart
//
// Onboarding Step 4 — Premium Introduction & ₹1 Offer
// ----------------------------------------------------
// Presented after the merchant has tested and verified the Soundbox setup.
//
// Strictly non-aggressive:
//   • Merchant can tap "Continue to Dashboard" immediately without payment.
//   • Merchant can tap "Explore Premium" to view the full paywall.

import 'package:flutter/material.dart';

import '../paywall_screen.dart';

class StepPremiumIntroScreen extends StatelessWidget {
  final VoidCallback onFinish;

  const StepPremiumIntroScreen({super.key, required this.onFinish});

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
                child: Column(
                  children: [
                    const Spacer(),

                    // ── Sparkle Icon ──────────────────────────────────────────
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFD8B4FE)),
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        size: 44,
                        color: Color(0xFF7E22CE),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Headline ──────────────────────────────────────────────
                    Text(
                      'Try MyUPI for ₹1',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    Text(
                      'Get your first month of MyUPI Smart Soundbox for just ₹1, then ₹49/month.',
                      style: TextStyle(
                        fontSize: 15,
                        color: cs.onSurface.withAlpha(180),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // ── Key Highlights ────────────────────────────────────────
                    _buildHighlightRow(
                      icon: Icons.check_circle_outline,
                      text: 'Instant audio on every customer UPI payment',
                    ),
                    const SizedBox(height: 12),
                    _buildHighlightRow(
                      icon: Icons.translate,
                      text: 'Available in Hindi, Marathi, Gujarati, Tamil & more',
                    ),
                    const SizedBox(height: 12),
                    _buildHighlightRow(
                      icon: Icons.savings_outlined,
                      text: 'Save ₹1,500+ every year over hardware soundboxes',
                    ),

                    const Spacer(flex: 2),

                    // ── View Offer Button ─────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) => const PaywallScreen(sourceEntry: 'onboarding'),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF5B21B6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'View Premium Offer',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Continue to Dashboard ─────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: onFinish,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Continue with Free Soundbox',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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
    );
  }

  Widget _buildStepIndicator(ColorScheme cs) {
    return Row(
      children: List.generate(5, (i) {
        final active = i == 4;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF5B21B6) : const Color(0xFF5B21B6).withAlpha(60),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildHighlightRow({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF5B21B6)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
