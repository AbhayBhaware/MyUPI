// lib/theme/app_colors.dart
//
// Centralized Color Palette for MyUPI derived from the brand logo.
// Palette tokens:
// - Primary Blue: #0060F5
// - Primary Gradient End: #0057EB
// - Deep Navy: #060C1C
// - Awning Navy: #002C89
// - Accent Orange: #FF6600
// - Background: #F8FAFE / #FFFFFF
// - Surface: #FFFFFF
// - Semantic Green: #16A34A (Success)

import 'package:flutter/material.dart';

abstract class AppColors {
  // ── Brand Identity Colors (from Logo) ─────────────────────────────────────
  static const Color primaryBlue        = Color(0xFF0060F5); // Brand primary blue
  static const Color primaryGradientEnd = Color(0xFF0057EB); // Primary gradient end
  static const Color deepNavy           = Color(0xFF060C1C); // Logo outline & high-contrast dark
  static const Color awningNavy         = Color(0xFF002C89); // Deep navy from awning & phone body
  static const Color accentOrange       = Color(0xFFFF6600); // Warm highlight from storefront awning

  // Backward-compatible & contextual aliases
  static const Color deepBlue           = awningNavy;
  static const Color brightAccent       = primaryBlue;
  static const Color lightBlue          = Color(0xFFEFF5FF); // Soft blue tint
  static const Color softBlueBorder     = Color(0xFFD6E4FF); // Hairline border for blue cards

  // ── Neutral Surface & Canvas ──────────────────────────────────────────────
  static const Color background         = Color(0xFFF8FAFE); // Premium crisp off-white canvas
  static const Color surface            = Color(0xFFFFFFFF); // Pure white card surface
  static const Color surfaceElevated    = Color(0xFFFFFFFF); // Elevated modal surface
  static const Color cardBorder         = Color(0xFFE5EBF5); // Hairline subtle card border
  static const Color divider            = Color(0xFFEEF2F6); // Clean horizontal divider

  // Aliases for borders
  static const Color borderLight        = cardBorder;
  static const Color borderMedium       = softBlueBorder;

  // ── Typography & Content ──────────────────────────────────────────────────
  static const Color textPrimary        = deepNavy;          // High contrast deep navy (#060C1C)
  static const Color textSecondary      = Color(0xFF4B5563); // Crisp readable slate gray
  static const Color textMuted          = Color(0xFF94A3B8); // Placeholder / subtle caption
  static const Color textTertiary       = textMuted;
  static const Color textOnPrimary      = Color(0xFFFFFFFF); // White text on primary surfaces

  // ── Semantic Feedback ─────────────────────────────────────────────────────
  // Success (Green - Payment Received)
  static const Color success            = Color(0xFF16A34A);
  static const Color successBg          = Color(0xFFDCFCE7);
  static const Color successBorder      = Color(0xFFBBF7D0);

  // Warning (Amber/Orange)
  static const Color warning            = Color(0xFFF59E0B);
  static const Color warningBg          = Color(0xFFFFFBEB);
  static const Color warningBorder      = Color(0xFFFEF3C7);

  // Error (Crimson)
  static const Color error              = Color(0xFFDC2626);
  static const Color errorBg            = Color(0xFFFEF2F2);
  static const Color errorBorder        = Color(0xFFFEE2E2);

  // ── Brand Gradients ───────────────────────────────────────────────────────
  static const LinearGradient primaryHeroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primaryBlue,
      primaryGradientEnd,
    ],
  );

  static const LinearGradient awningHeroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primaryBlue,
      awningNavy,
    ],
  );

  static const LinearGradient orangeAccentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF7A1A),
      accentOrange,
    ],
  );

  static const LinearGradient heroGradient = primaryHeroGradient;

  static const LinearGradient softHeroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFEFF5FF),
      Color(0xFFF6F9FE),
    ],
  );

  static const LinearGradient livePaymentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF16A34A),
      Color(0xFF15803D),
    ],
  );
}
