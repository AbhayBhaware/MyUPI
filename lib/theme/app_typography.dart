// lib/theme/app_typography.dart
//
// Modern, professional fintech typography hierarchy.

import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract class AppTypography {
  static const String fontFamily = 'Roboto';

  /// Page titles (Dashboard header, Onboarding welcome, etc.)
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28.0,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
    height: 1.25,
  );

  /// Major screen headers
  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22.0,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
    height: 1.3,
  );

  // Aliases for headlines
  static const TextStyle headlineLarge = displayLarge;
  static const TextStyle headlineMedium = displayMedium;

  /// Section headers (e.g. "SOUNDBOX", "TODAY", "QUICK ACTIONS")
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.0,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryBlue,
    letterSpacing: 1.1,
    height: 1.3,
  );

  /// Sub-section or card header (17-18px)
  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18.0,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.35,
  );

  /// Standard card title / list tile title (15-16px)
  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15.0,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.1,
    height: 1.4,
  );

  /// Small title (14px)
  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.0,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  /// Standard body text
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  /// Small body text / descriptions
  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13.0,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.45,
  );

  /// Captions, timestamps, secondary labels
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.0,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
    height: 1.35,
  );

  /// Tiny badges / tags (10-11px)
  static const TextStyle badge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11.0,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    height: 1.2,
  );

  /// Prominent Rupee currency amount display
  static const TextStyle currencyHero = TextStyle(
    fontFamily: fontFamily,
    fontSize: 34.0,
    fontWeight: FontWeight.w800,
    color: AppColors.primaryBlue,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle currencyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24.0,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
    height: 1.25,
  );

  static const TextStyle currencyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18.0,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.25,
  );

  static const TextStyle statValue = currencyLarge;

  /// Button label typography
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.2,
  );
}
