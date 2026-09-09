// lib/screens/onboarding/step_shop_profile_screen.dart
//
// Onboarding Step 4 — Shop / Merchant Profile.
// Allows merchant to set their shop name and toggle whether it is included
// in voice announcements. Persisted locally via native SharedPreferencesManager.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_channels.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/premium_buttons.dart';
import '../../widgets/premium_card.dart';

class StepShopProfileScreen extends StatefulWidget {
  final VoidCallback onContinue;
  const StepShopProfileScreen({super.key, required this.onContinue});

  @override
  State<StepShopProfileScreen> createState() => _StepShopProfileScreenState();
}

class _StepShopProfileScreenState extends State<StepShopProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _includeShopName = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMerchantData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadMerchantData() async {
    try {
      final name = await kMethodChannel.invokeMethod<String>('getMerchantName') ?? 'MyUPI';
      final inc = await kMethodChannel.invokeMethod<bool>('getIncludeShopName') ?? false;
      if (mounted) {
        setState(() {
          _nameController.text = (name == 'MyUPI') ? '' : name;
          _includeShopName = inc;
          _loading = false;
        });
      }
    } on PlatformException catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAndContinue() async {
    final text = _nameController.text.trim();
    final finalName = text.isEmpty ? 'MyUPI' : text;
    try {
      await kMethodChannel.invokeMethod('setMerchantName', {'name': finalName});
      await kMethodChannel.invokeMethod('setIncludeShopName', {'enabled': _includeShopName});
    } on PlatformException catch (_) {}

    if (mounted) {
      widget.onContinue();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Step indicator ──────────────────────────────────────────────
              const _StepIndicator(current: 4, total: 6),
              const SizedBox(height: AppSpacing.xl),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Icon ────────────────────────────────────────────────
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.lightBlue,
                          borderRadius: AppRadius.lgRadius,
                          border: Border.all(color: AppColors.primaryBlue.withAlpha(50), width: 1.0),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          size: 38,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Title ───────────────────────────────────────────────
                      const Text(
                        'Your Shop Name',
                        style: AppTypography.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Add your shop or business name to personalize payment announcements.',
                        style: AppTypography.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ── Shop Name Input ─────────────────────────────────────
                      if (_loading)
                        const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
                      else ...[
                        const Text(
                          'Shop or Business Name',
                          style: AppTypography.titleSmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        TextField(
                          controller: _nameController,
                          maxLength: 40,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: 'e.g. Abhay General Store',
                            prefixIcon: const Icon(Icons.store_rounded, color: AppColors.primaryBlue),
                            border: OutlineInputBorder(
                              borderRadius: AppRadius.mdRadius,
                              borderSide: const BorderSide(color: AppColors.borderMedium),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: AppRadius.mdRadius,
                              borderSide: const BorderSide(color: AppColors.borderMedium),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: AppRadius.mdRadius,
                              borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                            ),
                            filled: true,
                            fillColor: AppColors.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // ── Include Shop Name in Announcement Switch ─────────
                        PremiumCard(
                          padding: EdgeInsets.zero,
                          child: SwitchListTile(
                            activeThumbColor: AppColors.primaryBlue,
                            title: const Text(
                              'Announce shop name',
                              style: AppTypography.titleSmall,
                            ),
                            subtitle: Text(
                              _includeShopName
                                  ? 'Example: "Received ₹100 at ${_nameController.text.trim().isEmpty ? 'Your Shop' : _nameController.text.trim()}"'
                                  : 'Example: "Received ₹100 on PhonePe"',
                              style: AppTypography.caption,
                            ),
                            secondary: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _includeShopName ? AppColors.lightBlue : AppColors.background,
                                borderRadius: AppRadius.smRadius,
                              ),
                              child: Icon(
                                Icons.record_voice_over_rounded,
                                color: _includeShopName ? AppColors.primaryBlue : AppColors.textTertiary,
                                size: 20,
                              ),
                            ),
                            value: _includeShopName,
                            onChanged: (val) {
                              setState(() => _includeShopName = val);
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.base),

                        // Privacy note
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textTertiary),
                            SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                'Saved only on your phone. Never uploaded to any server or cloud.',
                                style: AppTypography.caption,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),

              // ── Continue Button ─────────────────────────────────────────────
              PrimaryButton(
                label: 'Continue',
                icon: Icons.arrow_forward_rounded,
                onPressed: _saveAndContinue,
              ),
              const SizedBox(height: AppSpacing.base),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 1; i <= total; i++) ...[
          Container(
            width: i == current ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == current
                  ? AppColors.primaryBlue
                  : i < current
                      ? AppColors.primaryBlue.withAlpha(120)
                      : AppColors.borderMedium,
              borderRadius: AppRadius.pillRadius,
            ),
          ),
          if (i < total) const SizedBox(width: 5),
        ],
        const SizedBox(width: AppSpacing.md),
        Text(
          'Step $current of $total',
          style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
