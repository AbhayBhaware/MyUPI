// lib/theme/app_colors.dart
//
// Centralized Color Palette for MyUPI Premium Fintech Theme.
// Strict Blue + White identity with restrained semantic accents.

import 'package:flutter/material.dart';

abstract class AppColors {
  // ── Primary Brand Blue Palette ─────────────────────────────────────────────
  static const Color primaryBlue     = Color(0xFF1565D8); // Primary brand blue
  static const Color deepBlue        = Color(0xFF0B3D91); // Deep rich navy blue
  static const Color brightAccent    = Color(0xFF2F80ED); // Vibrant interactive blue
  static const Color lightBlue       = Color(0xFFEAF3FF); // Soft blue surface/tint
  static const Color softBlueBorder  = Color(0xFFD3E4FE); // Hairline border for blue cards

  // ── Neutral Surface & Canvas ──────────────────────────────────────────────
  static const Color background      = Color(0xFFF7F9FC); // Premium cool off-white canvas
  static const Color surface         = Color(0xFFFFFFFF); // Pure white card surface
  static const Color surfaceElevated = Color(0xFFFFFFFF); // Elevated modal surface
  static const Color cardBorder      = Color(0xFFE5EBF5); // Hairline subtle card border
  static const Color divider         = Color(0xFFEEF2F6); // Clean horizontal divider

  // Aliases for borders
  static const Color borderLight     = cardBorder;
  static const Color borderMedium    = softBlueBorder;

  // ── Typography & Content ──────────────────────────────────────────────────
  static const Color textPrimary     = Color(0xFF111827); // High contrast slate black
  static const Color textSecondary   = Color(0xFF6B7280); // Cool neutral gray
  static const Color textMuted       = Color(0xFF9CA3AF); // Placeholder / subtle caption
  static const Color textTertiary    = textMuted;
  static const Color textOnPrimary   = Color(0xFFFFFFFF); // White text on blue surfaces

  // ── Semantic Feedback ─────────────────────────────────────────────────────
  // Success (Green)
  static const Color success         = Color(0xFF16A34A);
  static const Color successBg       = Color(0xFFF0FDF4);
  static const Color successBorder   = Color(0xFFDCFCE7);

  // Warning (Amber/Orange)
  static const Color warning         = Color(0xFFF59E0B);
  static const Color warningBg       = Color(0xFFFFFBEB);
  static const Color warningBorder   = Color(0xFFFEF3C7);

  // Error (Crimson)
  static const Color error           = Color(0xFFDC2626);
  static const Color errorBg         = Color(0xFFFEF2F2);
  static const Color errorBorder     = Color(0xFFFEE2E2);

  // ── Subtle Luxury Gradients ───────────────────────────────────────────────
  static const LinearGradient primaryHeroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1565D8),
      Color(0xFF0B3D91),
    ],
  );

  static const LinearGradient heroGradient = primaryHeroGradient;

  static const LinearGradient softHeroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFEAF3FF),
      Color(0xFFF0F6FF),
    ],
  );

  static const LinearGradient livePaymentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF15803D),
      Color(0xFF166534),
    ],
  );
}
