// lib/theme/app_theme.dart
//
// Centralized ThemeData builder for MyUPI.
// Enforces the Blue + White fintech design language globally.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

abstract class AppTheme {
  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryBlue,
        primary: AppColors.primaryBlue,
        onPrimary: AppColors.textOnPrimary,
        primaryContainer: AppColors.lightBlue,
        onPrimaryContainer: AppColors.deepBlue,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.background,
        outlineVariant: AppColors.cardBorder,
        outline: AppColors.textMuted,
        error: AppColors.error,
        onError: Colors.white,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,

      // ── App Bar Theme ──────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 18.0,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),

      // ── Card Theme ─────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgRadius,
          side: const BorderSide(color: AppColors.cardBorder, width: 1.0),
        ),
      ),

      // ── Filled Button Theme ────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: AppColors.textOnPrimary,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.mdRadius,
          ),
          textStyle: AppTypography.button,
        ),
      ),

      // ── Outlined Button Theme ──────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: AppColors.primaryBlue, width: 1.2),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.mdRadius,
          ),
          textStyle: AppTypography.button,
        ),
      ),

      // ── Text Button Theme ──────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          textStyle: AppTypography.button.copyWith(fontSize: 14),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.smRadius,
          ),
        ),
      ),

      // ── Input Decoration Theme ─────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
      ),

      // ── Divider Theme ──────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1.0,
        space: 1.0,
      ),

      // ── Navigation Bar Theme ───────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        height: 68,
        indicatorColor: AppColors.lightBlue,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryBlue,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
              color: AppColors.primaryBlue,
              size: 24,
            );
          }
          return const IconThemeData(
            color: AppColors.textSecondary,
            size: 24,
          );
        }),
      ),

      // ── SnackBar Theme ─────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    );
  }
}
