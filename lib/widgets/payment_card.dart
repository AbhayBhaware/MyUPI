// lib/widgets/payment_card.dart
//
// High-polish transaction card for Dashboard recent payment and History list.

import 'package:flutter/material.dart';

import '../app_channels.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'premium_card.dart';
import 'status_badge.dart';

class PaymentCard extends StatelessWidget {
  final PaymentRecord record;
  final VoidCallback? onTap;

  const PaymentCard({
    super.key,
    required this.record,
    this.onTap,
  });

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.successBg,
              borderRadius: AppRadius.mdRadius,
              border: Border.all(color: AppColors.successBorder, width: 1.0),
            ),
            child: const Icon(Icons.currency_rupee, color: AppColors.success, size: 20),
          ),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      record.displayAmount,
                      style: AppTypography.currencyMedium.copyWith(fontSize: 18),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const StatusBadge(
                      label: 'Payment detected',
                      type: StatusBadgeType.active,
                      showDot: true,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  record.appName,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            _formatTime(record.timestamp),
            style: AppTypography.caption,
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}
