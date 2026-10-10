// lib/widgets/qr_code_card.dart
//
// Payment QR Code Card — Displays the merchant's UPI QR code and VPA.
// -------------------------------------------------------------------
// Reads UPI ID from FirestoreService.cachedProfile (Dart-side only).
// Does NOT touch native SharedPreferencesManager.kt.
//
// Features:
//   • Prominent 205px high-contrast QR code for instant counter scanning
//   • Dynamic Specific-Amount generation (e.g. &am=450) with 1-tap clear (Correction 1.9)
//   • Live soundbox status pill (Live / Paused)
//   • Copy UPI ID to clipboard with haptic feedback
//   • Edit UPI ID inline with clipboard-on-tap paste (Correction 1.7)
//   • Tap-to-enlarge full-screen presentation mode with brightness & wakelock safety
//   • Supported UPI apps badges (GPay, PhonePe, Paytm, BHIM, Any UPI) (Correction 1.8)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/counter_kiosk_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/currency_formatter.dart';

class QrCodeCard extends StatefulWidget {
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

  @override
  State<QrCodeCard> createState() => _QrCodeCardState();
}

class _QrCodeCardState extends State<QrCodeCard> {
  String? _fixedAmount;

  /// Generates NPCI-compliant UPI payment URI.
  /// Includes '&am=' only when a valid specific amount is set (Correction 1.9).
  String get _upiUri {
    final encodedName = Uri.encodeComponent(
      widget.merchantName.trim().isEmpty ? 'Merchant' : widget.merchantName.trim(),
    );
    final baseUri = 'upi://pay?pa=${widget.upiId}&pn=$encodedName&cu=INR';
    if (_fixedAmount != null && _fixedAmount!.isNotEmpty) {
      return '$baseUri&am=$_fixedAmount';
    }
    return baseUri;
  }

  void _copyUpiId(BuildContext context) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: widget.upiId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('UPI ID copied: ${widget.upiId}'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showSetAmountDialog(BuildContext context) {
    HapticFeedback.selectionClick();
    final controller = TextEditingController(text: _fixedAmount ?? '');
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            void submitAmount(String val) {
              final parsed = CurrencyFormatter.parseValidUpiAmount(val);
              if (parsed == null) {
                setDialogState(() {
                  errorText = 'Enter a valid amount between ₹1 and ₹1,00,000 (max 2 decimals)';
                });
                return;
              }
              Navigator.pop(ctx);
              setState(() => _fixedAmount = parsed);
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('QR Code set to Fixed ₹$parsed. Tap Clear to return to standard QR.'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.primaryBlue,
                ),
              );
            }

            return AlertDialog(
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
              title: Row(
                children: const [
                  Icon(Icons.request_quote_rounded, color: AppColors.primaryBlue),
                  SizedBox(width: 8),
                  Text('Set Bill Amount', style: AppTypography.titleMedium),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer will scan this QR to pay the exact amount without typing it manually.',
                    style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      prefixStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                      hintText: 'e.g. 450 or 450.50',
                      errorText: errorText,
                    ),
                    onSubmitted: submitAmount,
                  ),
                  const SizedBox(height: 12),
                  // Quick Preset Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: ['50', '100', '250', '500', '1000'].map((amt) {
                      return ActionChip(
                        label: Text('₹$amt'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: AppColors.lightBlue,
                        side: const BorderSide(color: AppColors.softBlueBorder),
                        labelStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue,
                        ),
                        onPressed: () {
                          controller.text = amt;
                          setDialogState(() => errorText = null);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('CANCEL', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: const RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
                  ),
                  onPressed: () => submitAmount(controller.text),
                  child: const Text('SET AMOUNT', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _clearAmount() {
    HapticFeedback.lightImpact();
    setState(() => _fixedAmount = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cleared fixed amount. QR is now static for any customer amount.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showFullScreenQr(BuildContext context) {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      builder: (ctx) => _FullScreenQrDialog(
        upiUri: _upiUri,
        upiId: widget.upiId,
        merchantName: widget.merchantName,
        fixedAmount: _fixedAmount,
        onCopy: () => _copyUpiId(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.upiId.isEmpty) {
      return _buildEmptyState(context);
    }

    return GestureDetector(
      onTap: widget.onTap ?? () => _showFullScreenQr(context),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.xlRadius,
          border: Border.all(
            color: _fixedAmount != null ? AppColors.primaryBlue : AppColors.softBlueBorder,
            width: _fixedAmount != null ? 1.8 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withAlpha(_fixedAmount != null ? 22 : 14),
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
                      Text(
                        widget.merchantName.isEmpty ? 'MyUPI Merchant' : widget.merchantName,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

                if (widget.onEdit != null)
                  InkWell(
                    onTap: widget.onEdit,
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

            // ── Fixed Amount Active Banner (Correction 1.9) ──
            if (_fixedAmount != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: AppRadius.smRadius,
                  border: Border.all(color: AppColors.primaryBlue, width: 1.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.sell_rounded, size: 16, color: AppColors.primaryBlue),
                        const SizedBox(width: 6),
                        Text(
                          'Fixed Bill: ₹$_fixedAmount',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: _clearAmount,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          children: const [
                            Icon(Icons.close_rounded, size: 14, color: AppColors.textSecondary),
                            SizedBox(width: 2),
                            Text('Clear', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

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
                size: 170,
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

            // ── Show QR & Set Amount action buttons (Bounded, responsive) ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showFullScreenQr(context),
                    icon: const Icon(Icons.fullscreen_rounded, size: 16),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Show QR to customer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      side: const BorderSide(color: AppColors.softBlueBorder),
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
                      minimumSize: const Size(0, 40),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showSetAmountDialog(context),
                    icon: Icon(
                      _fixedAmount != null ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
                      size: 16,
                    ),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _fixedAmount != null ? 'Edit Bill (₹$_fixedAmount)' : 'Set Amount',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      side: BorderSide(
                        color: _fixedAmount != null ? AppColors.primaryBlue : AppColors.softBlueBorder,
                      ),
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
                      minimumSize: const Size(0, 40),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── UPI ID + Copy Pill (Flexible + FittedBox bounded) ──
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
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.upiId,
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepNavy,
                            letterSpacing: 0.4,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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

            // ── Short Centered UPI Banner (Rule 5: "Scan with any UPI app") ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined, size: 14, color: AppColors.primaryBlue),
                  SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Scan with any UPI app',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
              onPressed: widget.onEdit,
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

/// Full-Screen Presentation QR Dialog with Brightness & Wakelock Management
class _FullScreenQrDialog extends StatefulWidget {
  final String upiUri;
  final String upiId;
  final String merchantName;
  final String? fixedAmount;
  final VoidCallback onCopy;

  const _FullScreenQrDialog({
    required this.upiUri,
    required this.upiId,
    required this.merchantName,
    this.fixedAmount,
    required this.onCopy,
  });

  @override
  State<_FullScreenQrDialog> createState() => _FullScreenQrDialogState();
}

class _FullScreenQrDialogState extends State<_FullScreenQrDialog> with WidgetsBindingObserver {
  double? _originalBrightness;
  bool _brightnessRaised = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applyBrightnessAndWakelock();
  }

  Future<void> _applyBrightnessAndWakelock() async {
    try {
      _originalBrightness = await ScreenBrightness.instance.application;
      await ScreenBrightness.instance.setApplicationScreenBrightness(1.0);
      _brightnessRaised = true;
    } catch (_) {}
    try {
      await WakelockPlus.enable();
    } catch (_) {}
  }

  Future<void> _restoreBrightness() async {
    if (_brightnessRaised) {
      try {
        if (_originalBrightness != null) {
          await ScreenBrightness.instance.setApplicationScreenBrightness(_originalBrightness!);
        } else {
          await ScreenBrightness.instance.resetApplicationScreenBrightness();
        }
      } catch (_) {}
      _brightnessRaised = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _restoreBrightness();
    } else if (state == AppLifecycleState.resumed) {
      _applyBrightnessAndWakelock();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restoreBrightness();
    // Safely hand wakelock state back to CounterKioskService
    if (!CounterKioskService.instance.isKeepAwake) {
      WakelockPlus.disable().catchError((_) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                              widget.merchantName.isEmpty ? 'MyUPI Merchant' : widget.merchantName,
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
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
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Fixed Amount Notice in Fullscreen
            if (widget.fixedAmount != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: AppRadius.pillRadius,
                  border: Border.all(color: AppColors.primaryBlue),
                ),
                child: Text(
                  'FIXED AMOUNT: ₹${widget.fixedAmount}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryBlue,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],

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
                data: widget.upiUri,
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
              onTap: widget.onCopy,
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
                        widget.upiId,
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

            // ── Accepted UPI Apps List (Correction 1.8) ──
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
}
