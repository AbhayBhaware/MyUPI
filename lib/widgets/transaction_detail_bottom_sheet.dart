// lib/widgets/transaction_detail_bottom_sheet.dart
//
// Zero-PII Transaction Detail Sheet — Phase 2 Enhancement
// --------------------------------------------------------
// Safety rules strictly adhered:
// 1. Zero-PII: NEVER shows or logs raw notification or SMS text, customer names,
//    VPAs, or account numbers.
// 2. Never claims "verified": displays neutral "Payment detected".
// 3. Includes "Confirm large payments in your bank app" reminder.
// 4. Re-speak button triggers audio announcement only; never touches the ledger.

import 'package:flutter/material.dart';

import '../app_channels.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../tts_service.dart';
import '../utils/currency_formatter.dart';

class TransactionDetailBottomSheet extends StatelessWidget {
  final PaymentRecord record;

  const TransactionDetailBottomSheet({
    super.key,
    required this.record,
  });

  static Future<void> show(BuildContext context, PaymentRecord record) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TransactionDetailBottomSheet(record: record),
    );
  }

  String _formatTimestampWithSeconds(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year;

    final hourNum = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final hour = hourNum.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';

    return '$day $month $year, $hour:$minute:$second $ampm';
  }

  String _getSourceLabel() {
    switch (record.source) {
      case PaymentSource.both:
        return 'Notification + SMS';
      case PaymentSource.sms:
        return 'SMS Alert';
      case PaymentSource.notification:
      default:
        return 'Notification Alert';
    }
  }

  String _getTrustLevelLabel() {
    switch (record.trustLevel) {
      case TrustLevel.high:
        return 'High';
      case TrustLevel.medium:
        return 'Medium';
      case TrustLevel.low:
        return 'Low';
    }
  }

  String _getTrustLevelDescription() {
    switch (record.trustLevel) {
      case TrustLevel.high:
        return 'Direct notification from trusted UPI app';
      case TrustLevel.medium:
        return 'Notification details parsed successfully';
      case TrustLevel.low:
        return 'SMS alert only — please verify in bank app';
    }
  }

  Color _getAppTint(String appName) {
    final lower = appName.toLowerCase();
    if (lower.contains('phonepe')) return const Color(0xFF5F259F);
    if (lower.contains('google') || lower.contains('gpay')) return const Color(0xFF1A73E8);
    if (lower.contains('paytm')) return const Color(0xFF002970);
    if (lower.contains('bhim')) return const Color(0xFFE65100);
    if (lower.contains('amazon')) return const Color(0xFFFF9900);
    return AppColors.primaryBlue;
  }

  @override
  Widget build(BuildContext context) {
    final appColor = _getAppTint(record.appName);
    final amtVal = double.tryParse(record.amount.replaceAll(',', '')) ?? 0.0;
    final formattedAmt = amtVal > 0 ? CurrencyFormatter.format(amtVal) : record.displayAmount;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.xl),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Transaction Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Dominant Amount Center Box (Neutral badge without green check mark)
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderLight, width: 0.8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.payments_outlined, size: 14, color: AppColors.textSecondary),
                        SizedBox(width: 5),
                        Text(
                          'Payment detected',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    formattedAmt,
                    style: AppTypography.currencyLarge.copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Key-Value Details Container
            Container(
              padding: const EdgeInsets.all(AppSpacing.base),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: AppRadius.mdRadius,
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    label: 'Source App',
                    value: record.appName,
                    leading: Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(color: appColor, shape: BoxShape.circle),
                    ),
                  ),
                  const Divider(height: 20, color: AppColors.borderLight),
                  _buildDetailRow(
                    label: 'Detection Source',
                    value: _getSourceLabel(),
                    valueColor: AppColors.textPrimary,
                  ),
                  const Divider(height: 20, color: AppColors.borderLight),
                  _buildDetailRow(
                    label: 'Timestamp (Exact)',
                    value: _formatTimestampWithSeconds(record.timestamp),
                    valueColor: AppColors.textPrimary,
                  ),
                  const Divider(height: 20, color: AppColors.borderLight),
                  _buildDetailRow(
                    label: 'Confidence Level',
                    value: _getTrustLevelLabel(),
                    valueColor: record.trustLevel == TrustLevel.high
                        ? AppColors.success
                        : (record.trustLevel == TrustLevel.medium ? const Color(0xFFC2410C) : const Color(0xFFB45309)),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _getTrustLevelDescription(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Amber "Verify in bank" hint shown only for SMS-only detections per spec
            if (record.source == PaymentSource.sms) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: AppRadius.smRadius,
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFB45309)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Verify in bank • SMS-only detection without push notification.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            // Calm Bank Verification Footnote
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF9C3).withValues(alpha: 0.5),
                borderRadius: AppRadius.smRadius,
                border: Border.all(color: const Color(0xFFFEF08A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: Color(0xFF854D0E)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Confirm large payments in your bank app before handing over high-value goods.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF713F12),
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Re-speak Action Button (Per Correction 1.4: Pure audio, zero ledger writes)
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
                ),
                onPressed: () {
                  TtsService.instance.speakPayment(record.amount);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Re-announcing ${record.displayAmount}...'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.volume_up_rounded, size: 20),
                label: const Text(
                  'Re-announce Payment',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    Widget? leading,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ?leading,
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
