// lib/screens/auth/welcome_screen.dart
//
// Welcome Screen — First merchant touchpoint.
// ------------------------------------------
// Displays app branding with the established palette (#0060F5 primary,
// #060C1C deep navy text, #F8FAFE/#FFFFFF background) and 3 unified
// authentication entry points:
// 1. Continue with Google (single tap)
// 2. Continue with Phone (navigates to Phone OTP flow)
// 3. Continue with Email (navigates to Email auth flow)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'email_auth_screen.dart';
import 'phone_auth_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isGoogleLoading = false;

  Future<void> _handleGoogleSignIn() async {
    if (_isGoogleLoading) return;
    setState(() => _isGoogleLoading = true);

    try {
      final user = await AuthService.instance.signInWithGoogle();
      if (user == null && mounted) {
        // User cancelled account selection
        setState(() => _isGoogleLoading = false);
      }
      // On success, AuthGate's authStateChanges listener automatically advances!
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isGoogleLoading = false);
      String msg = 'Google sign-in failed. Please try again.';
      if (e.code == 'account-exists-with-different-credential') {
        msg = 'An account already exists with this email using another method.';
      } else if (e.message != null && e.message!.isNotEmpty) {
        msg = e.message!;
      }
      _showErrorSnackBar(msg);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGoogleLoading = false);
      _showErrorSnackBar('Unable to sign in with Google: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xl),

                // ── Brand Mark Container ──────────────────────────────────────
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.xxlRadius,
                    border: Border.all(color: AppColors.softBlueBorder, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withAlpha(45),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: AppRadius.xxlRadius,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.speaker_rounded,
                          size: 52,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Title & Tagline ───────────────────────────────────────────
                const Text(
                  'MyUPI',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Smart Payment Soundbox for Indian Merchants',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxl),

                // ── Merchant Feature Highlights ───────────────────────────────
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.lgRadius,
                    border: Border.all(color: AppColors.cardBorder, width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.deepNavy.withAlpha(8),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: const [
                      _FeatureRow(
                        icon: Icons.record_voice_over_rounded,
                        title: 'Instant Voice Announcements',
                        subtitle: 'Speaks Hindi, English, Marathi, Tamil & 7 more languages',
                      ),
                      Divider(height: 24, color: AppColors.cardBorder),
                      _FeatureRow(
                        icon: Icons.all_inclusive_rounded,
                        title: 'Universal UPI Compatibility',
                        subtitle: 'Instant alerts for PhonePe, Google Pay, Paytm & BHIM',
                      ),
                      Divider(height: 24, color: AppColors.cardBorder),
                      _FeatureRow(
                        icon: Icons.offline_bolt_rounded,
                        title: '100% On-Device Reliability',
                        subtitle: 'Zero audio latency. Announces even when cloud lags',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // ── Auth Entry Points (Zero redundant login/signup) ───────────
                // 1. Continue with Google
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      side: const BorderSide(color: AppColors.cardBorder, width: 1.5),
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
                      elevation: 0,
                    ),
                    child: _isGoogleLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.primaryBlue),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _GoogleLogoMark(),
                              const SizedBox(width: AppSpacing.md),
                              const Text(
                                'Continue with Google',
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 2. Continue with Phone
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
                      elevation: 1,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.phone_iphone_rounded, size: 20, color: Colors.white),
                        SizedBox(width: AppSpacing.md),
                        Text(
                          'Continue with Phone',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 3. Continue with Email
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const EmailAuthScreen()),
                      );
                    },
                    style: TextButton.styleFrom(
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.email_outlined, size: 19, color: AppColors.textSecondary),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          'Continue with Email',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // ── Footer ────────────────────────────────────────────────────
                Text(
                  'By continuing, you agree to our Terms of Service\nand Privacy Policy.',
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.base),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: AppColors.lightBlue,
            borderRadius: AppRadius.smRadius,
          ),
          child: Icon(icon, color: AppColors.primaryBlue, size: 20),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoogleLogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w900,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }
}
