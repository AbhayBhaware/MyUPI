// lib/widgets/premium_card.dart
//
// Reusable Premium Card with subtle hairline border, soft shadow,
// and optional tap feedback.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color backgroundColor;
  final Color borderColor;
  final BorderRadius borderRadius;
  final Gradient? gradient;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.base),
    this.margin,
    Color? color,
    Color? backgroundColor,
    this.borderColor = AppColors.cardBorder,
    this.borderRadius = AppRadius.lgRadius,
    this.gradient,
    this.shadows = AppShadows.card,
    this.onTap,
  }) : backgroundColor = color ?? backgroundColor ?? AppColors.surface;

  @override
  Widget build(BuildContext context) {
    Widget inner = Padding(
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      inner = InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: inner,
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: shadows,
      ),
      child: Material(
        color: gradient == null ? backgroundColor : Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: gradient != null
            ? Container(
                decoration: BoxDecoration(gradient: gradient),
                child: inner,
              )
            : inner,
      ),
    );
  }
}
