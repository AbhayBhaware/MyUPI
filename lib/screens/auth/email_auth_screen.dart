// lib/screens/auth/email_auth_screen.dart
//
// Email Auth Screen — Single screen toggling between Log In & Create Account.
// -------------------------------------------------------------------------
// Features:
// 1. Tab toggle between "Log in" and "Create account".
// 2. Email format validation.
// 3. Password visibility toggle & min 6-char length check.
// 4. "Forgot password?" reset dialog.
// 5. Friendly Firebase error handling.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoginMode = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isLoginMode) {
        await AuthService.instance.signInWithEmail(
          email: email,
          password: password,
        );
      } else {
        await AuthService.instance.signUpWithEmail(
          email: email,
          password: password,
        );
      }

      if (mounted) {
        // Pop screen — AuthGate root listener handles setup / home routing!
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg = 'Authentication failed. Please try again.';
      if (e.code == 'user-not-found') {
        msg = 'No merchant account found with this email. Tap "Create account".';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = 'Incorrect password entered. Please try again.';
      } else if (e.code == 'email-already-in-use') {
        msg = 'This email is already registered. Please switch to "Log in".';
      } else if (e.code == 'weak-password') {
        msg = 'The password is too weak. Please use at least 6 characters.';
      } else if (e.code == 'invalid-email') {
        msg = 'Please enter a valid email address.';
      } else if (e.message != null && e.message!.isNotEmpty) {
        msg = e.message!;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  void _showForgotPasswordDialog() {
    final resetController = TextEditingController(text: _emailController.text.trim());
    showDialog(
      context: context,
      builder: (ctx) {
        bool sending = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
              title: const Text('Reset Password', style: AppTypography.titleMedium),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your registered email address and we will send you a password reset link.',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: resetController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'merchant@example.com',
                      prefixIcon: Icon(Icons.email_outlined, color: AppColors.primaryBlue),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('CANCEL', style: TextStyle(color: AppColors.textSecondary)),
                ),
                FilledButton(
                  onPressed: sending
                      ? null
                      : () async {
                          final email = resetController.text.trim();
                          if (email.isEmpty || !email.contains('@')) {
                            return;
                          }
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(ctx);
                          setDialogState(() => sending = true);
                          try {
                            await AuthService.instance.sendPasswordResetEmail(email);
                            nav.pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Password reset link sent! Check your inbox.'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          } catch (e) {
                            setDialogState(() => sending = false);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Failed to send reset email: $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primaryBlue),
                  child: sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('SEND LINK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isLoginMode ? 'Merchant Log In' : 'Create Merchant Account',
          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.sm),

                // ── Mode Toggle Switch (Log in / Create account) ─────────────
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: AppRadius.mdRadius,
                    border: Border.all(color: AppColors.cardBorder, width: 1.0),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (!_isLoginMode) {
                              setState(() {
                                _isLoginMode = true;
                                _errorMessage = null;
                              });
                            }
                          },
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: _isLoginMode ? AppColors.surface : Colors.transparent,
                              borderRadius: AppRadius.smRadius,
                              boxShadow: _isLoginMode
                                  ? [
                                      BoxShadow(
                                        color: AppColors.deepNavy.withAlpha(12),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Log In',
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontWeight: _isLoginMode ? FontWeight.w700 : FontWeight.w500,
                                color: _isLoginMode ? AppColors.primaryBlue : AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_isLoginMode) {
                              setState(() {
                                _isLoginMode = false;
                                _errorMessage = null;
                              });
                            }
                          },
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: !_isLoginMode ? AppColors.surface : Colors.transparent,
                              borderRadius: AppRadius.smRadius,
                              boxShadow: !_isLoginMode
                                  ? [
                                      BoxShadow(
                                        color: AppColors.deepNavy.withAlpha(12),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Create Account',
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontWeight: !_isLoginMode ? FontWeight.w700 : FontWeight.w500,
                                color: !_isLoginMode ? AppColors.primaryBlue : AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Email Field ───────────────────────────────────────────────
                const Text('Email Address', style: AppTypography.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'merchant@example.com',
                    prefixIcon: Icon(Icons.email_outlined, color: AppColors.primaryBlue),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your email address.';
                    }
                    final email = val.trim();
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
                      return 'Please enter a valid email format.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Password Field ───────────────────────────────────────────
                const Text('Password', style: AppTypography.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'At least 6 characters',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primaryBlue),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: AppColors.textTertiary,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please enter a password.';
                    }
                    if (val.length < 6) {
                      return 'Password must be at least 6 characters.';
                    }
                    return null;
                  },
                ),

                // ── Confirm Password Field (Only in Create Account mode) ─────
                if (!_isLoginMode) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const Text('Confirm Password', style: AppTypography.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'Re-enter your password',
                      prefixIcon: Icon(Icons.lock_reset_rounded, color: AppColors.primaryBlue),
                    ),
                    validator: (val) {
                      if (!_isLoginMode && val != _passwordController.text) {
                        return 'Passwords do not match.';
                      }
                      return null;
                    },
                  ),
                ],

                // ── Forgot Password Link (Only in Log In mode) ───────────────
                if (_isLoginMode) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordDialog,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],

                // ── Error Banner ──────────────────────────────────────────────
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.errorBg,
                      borderRadius: AppRadius.smRadius,
                      border: Border.all(color: AppColors.errorBorder, width: 1.0),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 13,
                              color: AppColors.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xxl),

                // ── Submit Button ─────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                          )
                        : Text(
                            _isLoginMode ? 'Log In' : 'Create Account',
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
