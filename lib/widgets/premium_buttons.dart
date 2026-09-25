// lib/widgets/premium_buttons.dart
//
// Standardized fintech button hierarchy: Primary, Secondary, Outline, and Ghost.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_typography.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final bool isFullWidth;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = 52.0,
    this.isFullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final btn = Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: AppRadius.mdRadius,
        boxShadow: onPressed == null || isLoading ? null : AppShadows.primaryGlow,
      ),
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primaryBlue.withAlpha(120),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(label, style: AppTypography.button),
                ],
              ),
      ),
    );

    return isFullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final bool isFullWidth;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = 50.0,
    this.isFullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final btn = SizedBox(
      height: height,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.lightBlue,
          foregroundColor: AppColors.primaryBlue,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: const BorderSide(color: AppColors.softBlueBorder, width: 1.0),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  color: AppColors.primaryBlue,
                ),
              )
            : Row(
                mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: AppColors.primaryBlue),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: AppTypography.button.copyWith(color: AppColors.primaryBlue),
                  ),
                ],
              ),
      ),
    );

    return isFullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

class CustomOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final bool isFullWidth;
  final Color? borderColor;
  final Color? textColor;

  const CustomOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 48.0,
    this.isFullWidth = true,
    this.borderColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? AppColors.primaryBlue;
    final border = borderColor ?? AppColors.cardBorder;

    final btn = SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: border, width: 1.2),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: Row(
          mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                style: AppTypography.button.copyWith(color: color, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    return isFullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}
