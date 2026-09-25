// lib/screens/auth/phone_auth_screen.dart
//
// Phone Auth Screen — Unified phone OTP verification.
// ----------------------------------------------------
// Features:
// 1. Phone number entry (+91 formatted, 10 digits).
// 2. 6-digit individual boxed PIN inputs with auto-focus advance.
// 3. Auto-submit when 6th digit is entered.
// 4. Resend OTP countdown timer to prevent spamming.
// 5. Clear error state for wrong / expired codes.

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isCodeSent = false;
  bool _isLoading = false;
  String? _verificationId;
  int? _resendToken;
  String? _errorMessage;

  Timer? _countdownTimer;
  int _secondsRemaining = 30;

  @override
  void dispose() {
    _phoneController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _secondsRemaining = 30);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        if (mounted) setState(() => _secondsRemaining = 0);
      }
    });
  }

  Future<void> _sendOtp() async {
    final rawPhone = _phoneController.text.trim();
    final digitsOnly = rawPhone.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.length != 10) {
      setState(() => _errorMessage = 'Please enter a valid 10-digit mobile number.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await AuthService.instance.sendPhoneOtp(
      rawPhone: rawPhone,
      resendToken: _resendToken,
      onCodeSent: (verificationId, token) {
        if (!mounted) return;
        setState(() {
          _isCodeSent = true;
          _verificationId = verificationId;
          _resendToken = token;
          _isLoading = false;
          _errorMessage = null;
        });
        _startCountdown();
        // Focus first OTP box
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted && _otpFocusNodes[0].canRequestFocus) {
            _otpFocusNodes[0].requestFocus();
          }
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = error;
        });
      },
      onAutoVerified: (credential) async {
        if (!mounted) return;
        setState(() => _isLoading = true);
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);
          if (mounted) Navigator.of(context).pop();
        } catch (e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Auto-verification failed: $e';
            });
          }
        }
      },
    );
  }

  Future<void> _verifyOtp() async {
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits of the OTP.');
      return;
    }
    if (_verificationId == null) {
      setState(() => _errorMessage = 'Verification session expired. Please resend OTP.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.instance.verifyOtp(
        verificationId: _verificationId!,
        smsCode: code,
      );
      if (mounted) {
        // Pop screen — AuthGate root listener handles setup / home routing!
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'Invalid OTP code. Please check and try again.';
      if (e.code == 'invalid-verification-code') {
        message = 'Wrong OTP code entered. Please try again.';
      } else if (e.code == 'session-expired') {
        message = 'OTP has expired. Please tap Resend OTP.';
      } else if (e.message != null && e.message!.isNotEmpty) {
        message = e.message!;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = message;
      });
      // Clear boxes on error
      for (final c in _otpControllers) {
        c.clear();
      }
      _otpFocusNodes[0].requestFocus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Verification failed: $e';
      });
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // User pasted or typed multiple digits
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < digits.length && (index + i) < 6; i++) {
        _otpControllers[index + i].text = digits[i];
      }
      final nextIndex = (index + digits.length).clamp(0, 5);
      _otpFocusNodes[nextIndex].requestFocus();
      _checkAutoSubmit();
      return;
    }

    if (value.isNotEmpty) {
      if (index < 5) {
        _otpFocusNodes[index + 1].requestFocus();
      } else {
        _otpFocusNodes[index].unfocus();
      }
      _checkAutoSubmit();
    }
  }

  void _checkAutoSubmit() {
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length == 6) {
      _verifyOtp();
    }
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
          onPressed: () {
            if (_isCodeSent) {
              setState(() {
                _isCodeSent = false;
                _errorMessage = null;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          _isCodeSent ? 'Verify OTP' : 'Phone Sign In',
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),

              // ── Header Icon ────────────────────────────────────────────────
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: AppRadius.mdRadius,
                ),
                child: Icon(
                  _isCodeSent ? Icons.mark_email_read_outlined : Icons.phone_android_rounded,
                  size: 32,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Step 1: Phone Number Input ──────────────────────────────────
              if (!_isCodeSent) ...[
                const Text(
                  'Enter your mobile number',
                  style: AppTypography.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'We will send a 6-digit one-time password to verify your merchant account.',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xl),

                // Mobile number field with +91 indicator
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 54,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: AppRadius.mdRadius,
                        border: Border.all(color: AppColors.cardBorder, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        children: const [
                          Text('🇮🇳', style: TextStyle(fontSize: 18)),
                          SizedBox(width: 6),
                          Text(
                            '+91',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        autofocus: true,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                        decoration: InputDecoration(
                          hintText: '98765 43210',
                          hintStyle: const TextStyle(
                            color: AppColors.textMuted,
                            letterSpacing: 0,
                          ),
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.mdRadius,
                            borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: AppRadius.mdRadius,
                            borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.5),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: AppRadius.mdRadius,
                            borderSide: BorderSide(color: AppColors.primaryBlue, width: 2.0),
                          ),
                        ),
                        onSubmitted: (_) => _sendOtp(),
                      ),
                    ),
                  ],
                ),
              ],

              // ── Step 2: 6-Digit OTP Input ───────────────────────────────────
              if (_isCodeSent) ...[
                const Text(
                  'Enter 6-digit OTP',
                  style: AppTypography.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text(
                      'Sent to +91 ${_phoneController.text.trim()}',
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isCodeSent = false;
                          _errorMessage = null;
                        });
                      },
                      child: const Text(
                        'Edit',
                        style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // 6 individual boxed inputs
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 48,
                      height: 56,
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: (event) {
                          if (event is KeyDownEvent &&
                              event.logicalKey == LogicalKeyboardKey.backspace) {
                            if (_otpControllers[index].text.isEmpty && index > 0) {
                              _otpFocusNodes[index - 1].requestFocus();
                              _otpControllers[index - 1].clear();
                            }
                          }
                        },
                        child: TextField(
                          controller: _otpControllers[index],
                          focusNode: _otpFocusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryBlue,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(1),
                          ],
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: _otpControllers[index].text.isNotEmpty
                                ? AppColors.lightBlue
                                : AppColors.background,
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: AppRadius.smRadius,
                              borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.5),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: AppRadius.smRadius,
                              borderSide: BorderSide(
                                color: _otpControllers[index].text.isNotEmpty
                                    ? AppColors.primaryBlue
                                    : AppColors.cardBorder,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: AppRadius.smRadius,
                              borderSide: BorderSide(color: AppColors.primaryBlue, width: 2.2),
                            ),
                          ),
                          onChanged: (val) => _onDigitChanged(index, val),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Resend Countdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_secondsRemaining > 0)
                      Text(
                        'Resend OTP in ${_secondsRemaining}s',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      TextButton.icon(
                        onPressed: _isLoading ? null : _sendOtp,
                        icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.primaryBlue),
                        label: const Text(
                          'Resend OTP',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              // ── Error Message Banner ───────────────────────────────────────
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

              // ── Action CTA Button ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isLoading
                      ? null
                      : (_isCodeSent ? _verifyOtp : _sendOtp),
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
                          _isCodeSent ? 'Verify & Continue' : 'Send OTP',
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
    );
  }
}
