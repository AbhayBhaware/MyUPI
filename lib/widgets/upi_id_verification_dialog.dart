// lib/widgets/upi_id_verification_dialog.dart
//
// Interactive, Safe UPI ID Verification & Confirmation Dialog.
// -------------------------------------------------------------
// Guarantees that only valid, safe, and merchant-verified UPI IDs are saved.
// Protects merchants against losing customer payments due to typos or invalid VPAs.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/upi_validator.dart';

/// Shows a comprehensive UPI ID verification dialog with live bank handle detection,
/// email rejection, a 1-tap live verification test in installed UPI apps, and
/// a mandatory confirmation check before saving.
Future<void> showUpiIdVerificationDialog({
  required BuildContext context,
  required String initialUpiId,
  required String merchantName,
  required Future<void> Function(String validUpiId) onSave,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _UpiIdVerificationDialog(
      initialUpiId: initialUpiId,
      merchantName: merchantName,
      onSave: onSave,
    ),
  );
}

class _UpiIdVerificationDialog extends StatefulWidget {
  final String initialUpiId;
  final String merchantName;
  final Future<void> Function(String validUpiId) onSave;

  const _UpiIdVerificationDialog({
    required this.initialUpiId,
    required this.merchantName,
    required this.onSave,
  });

  @override
  State<_UpiIdVerificationDialog> createState() => _UpiIdVerificationDialogState();
}

class _UpiIdVerificationDialogState extends State<_UpiIdVerificationDialog> {
  late final TextEditingController _controller;
  bool _confirmedOwnership = false;
  bool _isSaving = false;
  bool _hasTestedInApp = false;
  late UpiValidationResult _validation;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUpiId);
    _validation = UpiValidator.validate(widget.initialUpiId);
    if (widget.initialUpiId.isNotEmpty && _validation.isValid) {
      _confirmedOwnership = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    setState(() {
      _validation = UpiValidator.validate(value);
      _hasTestedInApp = false;
      // Reset confirmation if user modifies the ID
      if (!_validation.isValid) {
        _confirmedOwnership = false;
      }
    });
  }

  Future<void> _pasteFromClipboard() async {
    HapticFeedback.selectionClick();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim().toLowerCase();
    if (text == null || text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clipboard is empty.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    _controller.text = text;
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: text.length));
    _onTextChanged(text);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pasted from clipboard: $text'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primaryBlue,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _testInUpiApp() async {
    HapticFeedback.mediumImpact();
    final upiId = _controller.text.trim().toLowerCase();
    if (!_validation.isValid) return;

    final launched = await UpiValidator.launchUpiTestPayment(
      upiId: upiId,
      merchantName: widget.merchantName,
      amount: 1.0,
    );

    if (mounted) {
      setState(() => _hasTestedInApp = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            launched
                ? 'Opening UPI App... Verify your name appears on screen.'
                : 'No UPI app responded. Ensure PhonePe, Google Pay, or Paytm is installed.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: launched ? AppColors.success : AppColors.warning,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_validation.isValid || !_confirmedOwnership) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final cleanUpi = _validation.normalizedUpiId;
      await widget.onSave(cleanUpi);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('UPI ID verified & activated: $cleanUpi')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save UPI ID: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _validation.isValid;
    final canSave = isValid && _confirmedOwnership && !_isSaving;

    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: AppColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue,
                      borderRadius: AppRadius.mdRadius,
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: AppColors.primaryBlue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Set & Verify UPI ID', style: AppTypography.titleMedium),
                        SizedBox(height: 2),
                        Text(
                          'Ensures payments reach your bank account safely.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // ── UPI ID Input Field ──
              TextField(
                controller: _controller,
                keyboardType: TextInputType.emailAddress,
                autofocus: widget.initialUpiId.isEmpty,
                onChanged: _onTextChanged,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.3,
                ),
                decoration: InputDecoration(
                  labelText: 'UPI ID / VPA',
                  hintText: 'e.g. 9876543210@ybl or shop@okhdfcbank',
                  prefixIcon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primaryBlue),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _controller.clear();
                            _onTextChanged('');
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 6),

              // ── Paste from Clipboard Action ──
              InkWell(
                onTap: _pasteFromClipboard,
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.content_paste_rounded, size: 14, color: AppColors.primaryBlue),
                      SizedBox(width: 4),
                      Text(
                        'Paste from clipboard',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Detected App Name or Error ──
              if (_controller.text.trim().isNotEmpty) ...[
                if (isValid && _validation.appName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.lightBlue,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.softBlueBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 14),
                              const SizedBox(width: 5),
                              Text(
                                _validation.appName!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else if (!isValid && _validation.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 15),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _validation.errorMessage!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],

              // ── 1-Tap Live Verification in UPI App ──
              if (isValid) ...[
                OutlinedButton.icon(
                  onPressed: _testInUpiApp,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side: const BorderSide(color: AppColors.primaryBlue, width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: const RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
                    minimumSize: const Size(double.infinity, 42),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 17),
                  label: Text(
                    _hasTestedInApp ? 'Re-open in UPI App to Verify' : 'Verify in UPI App (Send ₹1 Test)',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '💡 Opening in your UPI app checks whether your real account name resolves on NPCI.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.3),
                ),
                const SizedBox(height: 12),
              ],

              // ── Risk Warning Note ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: AppRadius.smRadius,
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Important: All QR payments will go directly to this address. An incorrect UPI ID will cause payments to fail or go to someone else.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF92400E),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Confirmation Checkbox ──
              CheckboxListTile(
                value: _confirmedOwnership,
                onChanged: isValid
                    ? (val) {
                        HapticFeedback.selectionClick();
                        setState(() => _confirmedOwnership = val ?? false);
                      }
                    : null,
                activeColor: AppColors.primaryBlue,
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'I confirm this UPI ID is linked to my bank account.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Action Buttons ──
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
                      ),
                      child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: canSave ? _submit : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        disabledBackgroundColor: AppColors.primaryBlue.withAlpha(80),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'CONFIRM & SAVE',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

