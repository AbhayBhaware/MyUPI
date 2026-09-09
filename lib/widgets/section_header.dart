// lib/widgets/section_header.dart
//
// Consistent uppercase section header with optional trailing action or count badge.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? badgeText;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.badgeText,
    this.padding = const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.lg, AppSpacing.base, AppSpacing.sm),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Text(
            title,
            style: AppTypography.sectionTitle,
          ),
          const Spacer(),
          if (badgeText != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: AppRadius.pillRadius,
                border: Border.all(color: AppColors.softBlueBorder, width: 1.0),
              ),
              child: Text(
                badgeText!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue,
                ),
              ),
            )
          else if (actionLabel != null && onAction != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.primaryBlue),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
