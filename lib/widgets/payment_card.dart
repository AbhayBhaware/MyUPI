// lib/widgets/payment_card.dart
//
// High-polish transaction card for Dashboard recent payment and History list.
// Master Brief Part 2 & Part 3: Dominant amount, channel badges (Notification / SMS / Both),
// and trust-level indicators.

import 'package:flutter/material.dart';

import '../app_channels.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/currency_formatter.dart';
import 'premium_card.dart';

class PaymentCard extends StatelessWidget {
  final PaymentRecord record;
  final VoidCallback? onTap;
  final VoidCallback? onRespeak;

  const PaymentCard({
    super.key,
    required this.record,
    this.onTap,
    this.onRespeak,
  });

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  Color _getAppTint(String appName) {
    final lower = appName.toLowerCase();
    if (lower.contains('phonepe')) return const Color(0xFF5F259F);
    if (lower.contains('google') || lower.contains('gpay')) return const Color(0xFF1A73E8);
    if (lower.contains('paytm')) return const Color(0xFF002970);
    if (lower.contains('bhim')) return const Color(0xFFE65100);
    if (lower.contains('amazon')) return const Color(0xFFFF9900);
    if (lower.contains('hdfc')) return const Color(0xFF004C8F);
    if (lower.contains('sbi')) return const Color(0xFF280071);
    if (lower.contains('icici')) return const Color(0xFFB02A30);
    return AppColors.primaryBlue;
  }

  Widget _buildChannelBadge() {
    switch (record.source) {
      case PaymentSource.both:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.successBg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.successBorder, width: 0.8),
          ),
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mark_chat_read_rounded, size: 10, color: AppColors.success),
                SizedBox(width: 3),
                Text(
                  'Notif + SMS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        );

      case PaymentSource.sms:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
          ),
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sms_rounded, size: 10, color: Color(0xFF475569)),
                SizedBox(width: 3),
                Text(
                  'SMS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        );

      case PaymentSource.notification:
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.lightBlue,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.softBlueBorder, width: 0.8),
          ),
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_active_rounded, size: 10, color: AppColors.primaryBlue),
                SizedBox(width: 3),
                Text(
                  'Notif',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }

  Widget? _buildTrustBadge() {
    if (record.source == PaymentSource.sms && record.trustLevel == TrustLevel.low) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFFDE68A), width: 0.8),
        ),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Verify in bank',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Color(0xFFB45309),
            ),
          ),
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final appColor = _getAppTint(record.appName);
    final trustBadge = _buildTrustBadge();

    // Leading icon tint and symbol
    final isDual = record.source == PaymentSource.both;
    final isSms = record.source == PaymentSource.sms;

    final IconData leadingIcon = isDual
        ? Icons.currency_rupee_rounded
        : (isSms ? Icons.mark_chat_read_rounded : Icons.currency_rupee_rounded);

    final Color leadingBg = isDual
        ? AppColors.successBg
        : (isSms ? const Color(0xFFF1F5F9) : AppColors.successBg);

    final Color leadingColor = isDual
        ? AppColors.success
        : (isSms ? const Color(0xFF475569) : AppColors.success);

    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: 14),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: leadingBg,
              borderRadius: AppRadius.mdRadius,
              border: Border.all(
                color: isDual ? AppColors.successBorder : (isSms ? const Color(0xFFE2E8F0) : AppColors.successBorder),
                width: 1.0,
              ),
            ),
            child: Center(
              child: Icon(leadingIcon, color: leadingColor, size: 22),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Amount and App Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    // Dominant Amount with Indian grouping
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        CurrencyFormatter.format(record.amount),
                        style: AppTypography.currencyMedium.copyWith(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    _buildChannelBadge(),
                    ?trustBadge,
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: appColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        record.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          // Timestamp & Action (single source badge is already on the card)
          Flexible(
            flex: 0,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(record.timestamp),
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (onRespeak != null) ...[
                    const SizedBox(height: 5),
                    InkWell(
                      onTap: onRespeak,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.lightBlue,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.softBlueBorder, width: 0.8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.volume_up_rounded, size: 11, color: AppColors.primaryBlue),
                            SizedBox(width: 3),
                            Text(
                              'Repeat',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
