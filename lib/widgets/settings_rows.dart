// lib/widgets/settings_rows.dart
//
// Shared, overflow-proof row widgets adhering to MyUPI Layout Specification (Section 2):
// 1. SwitchRow: squircle icon, expanded title/subtitle, switch with 48x48 touch target.
// 2. NavRow: squircle icon, expanded title/subtitle, trailing value + optional badge + chevron.
// 3. StackedField: title above, full-width field/button below for long values.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// 1. SwitchRow: toggles with min 48x48 touch target and bounded text columns.
class SwitchRow extends StatelessWidget {
  final Widget? icon;
  final IconData? iconData;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color iconColor;
  final Color iconBgColor;
  final bool showDivider;

  const SwitchRow({
    super.key,
    this.icon,
    this.iconData,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.iconColor = AppColors.primaryBlue,
    this.iconBgColor = AppColors.lightBlue,
    this.showDivider = false,
  }) : assert(icon != null || iconData != null, 'Either icon or iconData must be provided');

  @override
  Widget build(BuildContext context) {
    final leadingWidget = icon ??
        Icon(
          iconData,
          size: 20,
          color: value ? iconColor : AppColors.textTertiary,
        );

    final rowContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: value ? iconBgColor : const Color(0xFFF1F5F9),
              borderRadius: AppRadius.smRadius,
            ),
            child: Center(child: leadingWidget),
          ),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              child: Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeTrackColor: AppColors.primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );

    if (!showDivider) return rowContent;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        rowContent,
        const Divider(height: 1, indent: 68, endIndent: 16, color: AppColors.borderLight),
      ],
    );
  }
}

/// 2. NavRow: tap-to-open row displaying current value + optional badge + chevron.
class NavRow extends StatelessWidget {
  final Widget? icon;
  final IconData? iconData;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? badge;
  final VoidCallback? onTap;
  final Color iconColor;
  final Color iconBgColor;
  final bool showDivider;

  const NavRow({
    super.key,
    this.icon,
    this.iconData,
    required this.title,
    this.subtitle,
    this.value,
    this.badge,
    this.onTap,
    this.iconColor = AppColors.primaryBlue,
    this.iconBgColor = AppColors.lightBlue,
    this.showDivider = false,
  }) : assert(icon != null || iconData != null, 'Either icon or iconData must be provided');

  @override
  Widget build(BuildContext context) {
    final leadingWidget = icon ?? Icon(iconData, size: 20, color: iconColor);

    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: AppRadius.smRadius,
            ),
            child: Center(child: leadingWidget),
          ),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Value, badge, and trailing chevron
          Flexible(
            fit: FlexFit.loose,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (badge != null) ...[
                  badge!,
                  const SizedBox(width: 6),
                ],
                if (value != null && value!.isNotEmpty)
                  Flexible(
                    child: Text(
                      value!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: content,
          ),
        ),
      );
    }

    if (!showDivider) return content;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        content,
        const Divider(height: 1, indent: 68, endIndent: 16, color: AppColors.borderLight),
      ],
    );
  }
}

/// 3. StackedField: title above, full-width field/button below for long values.
class StackedField extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  const StackedField({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.titleSmall.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ?trailing,
            ],
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
