// lib/widgets/status_badge.dart
//
// Elegant pill status badge with semantic colors and optional live indicator dot.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

enum StatusBadgeType {
  active,
  inactive,
  warning,
  info,
  accent,
}

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusBadgeType type;
  final bool showDot;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    this.type = StatusBadgeType.active,
    this.showDot = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color text;
    Color dot;

    switch (type) {
      case StatusBadgeType.active:
        bg = AppColors.successBg;
        border = AppColors.successBorder;
        text = AppColors.success;
        dot = AppColors.success;
        break;
      case StatusBadgeType.inactive:
        bg = const Color(0xFFF3F4F6);
        border = const Color(0xFFE5E7EB);
        text = AppColors.textSecondary;
        dot = AppColors.textMuted;
        break;
      case StatusBadgeType.warning:
        bg = AppColors.warningBg;
        border = AppColors.warningBorder;
        text = const Color(0xFFB45309);
        dot = AppColors.warning;
        break;
      case StatusBadgeType.info:
      case StatusBadgeType.accent:
        bg = AppColors.lightBlue;
        border = AppColors.softBlueBorder;
        text = AppColors.primaryBlue;
        dot = AppColors.primaryBlue;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: border, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: dot,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: 12, color: text),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: AppTypography.badge.copyWith(color: text),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
