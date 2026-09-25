// lib/widgets/qr_code_card.dart
//
// Payment QR Code Card — Displays the merchant's UPI QR code and VPA.
// -------------------------------------------------------------------
// Reads UPI ID from FirestoreService.cachedProfile (Dart-side only).
// Does NOT touch native SharedPreferencesManager.kt.
//
// Features:
//   • Prominent 205px high-contrast QR code for instant counter scanning
//   • Live soundbox status pill (Live / Paused)
//   • Copy UPI ID to clipboard with haptic feedback
//   • Edit UPI ID inline
//   • Tap-to-enlarge full-screen presentation mode for customers
//   • Supported UPI apps badges (GPay, PhonePe, Paytm, BHIM, Any UPI)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class QrCodeCard extends StatelessWidget {
  final String upiId;
  final String merchantName;
  final bool soundboxActive;
  final VoidCallback? onEdit;
  final VoidCallback? onTap;

  const QrCodeCard({
    super.key,
    required this.upiId,
    required this.merchantName,
    this.soundboxActive = true,
    this.onEdit,
    this.onTap,
  });

  /// Generates NPCI-compliant UPI payment URI.
  String get _upiUri {
    final encodedName = Uri.encodeComponent(merchantName.isEmpty ? 'Merchant' : merchantName);
    return 'upi://pay?pa=$upiId&pn=$encodedName&cu=INR';
  }

  void _copyUpiId(BuildContext context) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: upiId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('UPI ID copied: $upiId'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showFullScreenQr(BuildContext context) {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.xlRadius,
              boxShadow: AppShadows.elevated,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: AppRadius.smRadius,
                      ),
                      child: const Icon(Icons.storefront_rounded, color: AppColors.primaryBlue, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  merchantName.isEmpty ? 'MyUPI Merchant' : merchantName,
                                  style: AppTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_rounded, size: 16, color: AppColors.success),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Scan with any UPI app to pay',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── QR Code in clean container ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.lgRadius,
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: _upiUri,
                    version: QrVersions.auto,
                    size: 240,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppColors.deepNavy,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.deepNavy,
                    ),
                    gapless: true,
                  ),
                ),
                const SizedBox(height: 16),

                // ── UPI ID Pill ──
                InkWell(
                  onTap: () => _copyUpiId(ctx),
                  borderRadius: AppRadius.mdRadius,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: AppRadius.mdRadius,
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            upiId,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.deepNavy,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.copy_rounded, size: 16, color: AppColors.primaryBlue),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Accepted UPI Apps List ──
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildAppBadge('GPay'),
                    _buildAppBadge('PhonePe'),
                    _buildAppBadge('Paytm'),
                    _buildAppBadge('BHIM'),
                    _buildAppBadge('Any UPI App'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBadge(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        name,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (upiId.isEmpty) {
      return _buildEmptyState(context);
    }

    return GestureDetector(
      onTap: onTap ?? () => _showFullScreenQr(context),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.xlRadius,
          border: Border.all(color: AppColors.softBlueBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withAlpha(14),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Header Row: Shop Info & Status ──
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppColors.lightBlue,
                    borderRadius: AppRadius.smRadius,
                  ),
                  child: const Icon(Icons.storefront_rounded, color: AppColors.primaryBlue, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              merchantName.isEmpty ? 'MyUPI Merchant' : merchantName,
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, size: 15, color: AppColors.success),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Scan & Pay with Any UPI App',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Soundbox Status indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: soundboxActive ? AppColors.successBg : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: soundboxActive ? AppColors.successBorder : AppColors.cardBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: soundboxActive ? AppColors.success : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        soundboxActive ? 'Soundbox Live' : 'Soundbox Off',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: soundboxActive ? AppColors.success : AppColors.textMuted,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (onEdit != null)
                  InkWell(
                    onTap: onEdit,
                    borderRadius: AppRadius.smRadius,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: AppRadius.smRadius,
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: const Icon(Icons.edit_rounded, size: 15, color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Big QR Code Centerpiece ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.lgRadius,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(6),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: QrImageView(
                data: _upiUri,
                version: QrVersions.auto,
                size: 205,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.deepNavy,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.deepNavy,
                ),
                gapless: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Tap to enlarge hint ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.fullscreen_rounded, size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 4),
                Text(
                  'Tap to enlarge for customers',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.primaryBlue.withAlpha(220),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── UPI ID + Copy Pill ──
            InkWell(
              onTap: () => _copyUpiId(context),
              borderRadius: AppRadius.mdRadius,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: AppRadius.mdRadius,
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 16, color: AppColors.primaryBlue),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        upiId,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepNavy,
                          letterSpacing: 0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded, size: 11, color: AppColors.primaryBlue),
                          SizedBox(width: 3),
                          Text(
                            'COPY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Supported UPI Apps Banner ──
            Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                _buildAppBadge('GPay'),
                _buildAppBadge('PhonePe'),
                _buildAppBadge('Paytm'),
                _buildAppBadge('BHIM'),
                _buildAppBadge('Cred'),
                _buildAppBadge('Any UPI App'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xlRadius,
        border: Border.all(color: AppColors.softBlueBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withAlpha(12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: AppRadius.mdRadius,
                ),
                child: const Icon(Icons.qr_code_2_rounded, color: AppColors.primaryBlue, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set Up Payment QR Code',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Add your UPI ID so customers can scan and pay directly at your counter.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
              ),
              onPressed: onEdit,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Add UPI ID to Generate QR',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
