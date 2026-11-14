// lib/widgets/payment_card.dart
//
// High-polish transaction card for Dashboard recent payment and History list.
// Clean fintech layout with app brand tinting and one-tap re-announcement.

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

  Color _getAppBgTint(String appName) {
    final lower = appName.toLowerCase();
    if (lower.contains('phonepe')) return const Color(0xFFF4EEFD);
    if (lower.contains('google') || lower.contains('gpay')) return const Color(0xFFE8F0FE);
    if (lower.contains('paytm')) return const Color(0xFFE6EEFA);
    if (lower.contains('bhim')) return const Color(0xFFFFF3E0);
    if (lower.contains('amazon')) return const Color(0xFFFFF8E1);
    return AppColors.successBg;
  }

  Widget? _buildChannelBadge() {
    switch (record.source) {
      case PaymentSource.both:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.successBg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.successBorder, width: 0.8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mark_chat_read_rounded, size: 10, color: AppColors.success),
              SizedBox(width: 3),
              Text(
                'Dual',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ],
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
          child: const Row(
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
        );

      case PaymentSource.notification:
      default:
        // No redundant tag for standard notifications
        return null;
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
        child: const Text(
          'Verify in bank',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Color(0xFFB45309),
          ),
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final appColor = _getAppTint(record.appName);
    final appBg = _getAppBgTint(record.appName);
    final channelBadge = _buildChannelBadge();
    final trustBadge = _buildTrustBadge();

    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: 12),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          // App-branded Leading Icon Container
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: appBg,
              borderRadius: AppRadius.mdRadius,
              border: Border.all(
                color: appColor.withAlpha(35),
                width: 1.0,
              ),
            ),
            child: Center(
              child: Icon(Icons.currency_rupee_rounded, color: appColor, size: 22),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Amount and Source Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          CurrencyFormatter.format(record.amount),
                          style: AppTypography.currencyMedium.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    if (channelBadge != null) ...[
                      const SizedBox(width: 6),
                      channelBadge,
                    ],
                    if (trustBadge != null) ...[
                      const SizedBox(width: 6),
                      trustBadge,
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
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
                    Expanded(
                      child: Text(
                        '${record.appName.isEmpty ? "UPI App" : record.appName} • ${_formatTime(record.timestamp)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          // Quick Re-announce Button & Chevron
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onRespeak != null) ...[
                Tooltip(
                  message: 'Re-announce',
                  child: InkWell(
                    onTap: onRespeak,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.softBlueBorder, width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.volume_up_rounded, size: 13, color: AppColors.primaryBlue),
                          SizedBox(width: 3),
                          Text(
                            'Repeat',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textTertiary),
            ],
          ),
        ],
      ),
    );
  }
}
