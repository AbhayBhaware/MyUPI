// lib/screens/auth/setup_wizard_screen.dart
//
// Setup Wizard — Polished 2-Step Onboarding per Section 5.
// -----------------------------------------------------------
// Step 1: Shop Details (Shop name is the ONLY required field; owner & category optional).
// Step 2: UPI ID setup with handle-suggestion chips & Soundbox Sample Announcement.
// Hardware/gesture back-button blocked via PopScope(canPop: false).
// Sets native setMerchantName and Firestore setupComplete: true.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_channels.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../tts_service.dart';

class SetupWizardScreen extends StatefulWidget {
  final User user;
  final VoidCallback? onSetupComplete;

  const SetupWizardScreen({
    super.key,
    required this.user,
    this.onSetupComplete,
  });

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _currentStep = 1;

  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  final _shopNameController = TextEditingController();
  final _ownerController = TextEditingController();
  final _categoryOtherController = TextEditingController();
  final _upiIdController = TextEditingController();

  String? _selectedCategory;
  bool _isLoading = false;
  String? _duplicateAccountWarning;

  final List<String> _upiHandles = const [
    '@okhdfcbank',
    '@okaxis',
    '@oksbi',
    '@okicici',
    '@ybl',
    '@paytm',
  ];

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      _ownerController.text = user.displayName!;
    }
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerController.dispose();
    _categoryOtherController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  bool get _isStep1Valid => _shopNameController.text.trim().isNotEmpty;

  void _applyHandle(String handle) {
    HapticFeedback.selectionClick();
    final text = _upiIdController.text.trim();
    if (text.isEmpty) {
      _upiIdController.text = handle;
    } else if (text.contains('@')) {
      final prefix = text.split('@').first;
      _upiIdController.text = '$prefix$handle';
    } else {
      _upiIdController.text = '$text$handle';
    }
    setState(() {});
  }

  void _playSampleAnnouncement() {
    final shop = _shopNameController.text.trim();
    final name = shop.isEmpty ? 'MyUPI' : shop;
    try {
      kMethodChannel.invokeMethod('speakTest');
    } catch (_) {
      TtsService.instance.speakPayment('500');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playing sample announcement for "$name"...'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleCompleteSetup() async {
    if (_currentStep == 2 && !_step2FormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _duplicateAccountWarning = null;
    });

    final uid = widget.user.uid;
    final ownerName = _ownerController.text.trim();
    final shopName = _shopNameController.text.trim();
    final category = _selectedCategory ?? '';
    final categoryOther = category == 'Other' ? _categoryOtherController.text.trim() : null;
    final phone = widget.user.phoneNumber ?? '';
    final email = widget.user.email ?? '';
    final upiId = _upiIdController.text.trim().toLowerCase();

    String authMethod = 'phone';
    if (widget.user.providerData.any((p) => p.providerId == 'google.com')) {
      authMethod = 'google';
    } else if (widget.user.providerData.any((p) => p.providerId == 'password')) {
      authMethod = 'email';
    }

    // ── 1. Synchronize to native Soundbox engine ─────────────────────────────
    try {
      await kMethodChannel.invokeMethod('setMerchantName', {'name': shopName});
      await kMethodChannel.invokeMethod('setIncludeShopName', {'enabled': true});
    } on PlatformException catch (_) {}

    // ── 2. Persist to Firestore users/{uid} with setupComplete: true ────────
    final profile = UserProfile(
      uid: uid,
      ownerName: ownerName,
      shopName: shopName,
      category: category,
      categoryOther: categoryOther,
      phone: phone,
      email: email,
      authMethod: authMethod,
      upiId: upiId,
      setupComplete: true, // kFieldSetupComplete
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await FirestoreService.instance.saveUserProfile(profile);

    if (mounted) {
      if (!success) {
        setState(() {
          _isLoading = false;
          _duplicateAccountWarning =
              'Could not save shop setup to database. Please check your internet connection.';
        });
        return;
      }
      setState(() => _isLoading = false);
      widget.onSetupComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please complete your shop setup to continue.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: _currentStep == 2
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                  onPressed: () => setState(() => _currentStep = 1),
                )
              : null,
          title: const Text(
            'Shop Setup',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // ── 2-Step Progress Indicator ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _currentStep == 1 ? 'Step 1 of 2: Shop Details' : 'Step 2 of 2: QR & Soundbox',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        Text(
                          _currentStep == 1 ? '50%' : '100%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _currentStep == 1 ? 0.5 : 1.0,
                        minHeight: 6,
                        backgroundColor: AppColors.borderLight,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Step Content ────────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  child: _currentStep == 1 ? _buildStep1() : _buildStep2(),
                ),
              ),

              // ── Bottom Action Bar ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(AppSpacing.base),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.borderLight)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_currentStep == 1 && !_isStep1Valid) ...[
                      const Text(
                        'Enter your shop name to continue',
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      ),
                      const SizedBox(height: 6),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _isLoading
                            ? null
                            : (_currentStep == 1
                                ? (_isStep1Valid ? () => setState(() => _currentStep = 2) : null)
                                : _handleCompleteSetup),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          disabledBackgroundColor: AppColors.cardBorder,
                          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                _currentStep == 1 ? 'Continue to Step 2' : 'Complete Setup & Open Soundbox',
                                style: const TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
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
      ),
    );
  }

  // ── Step 1: Shop Profile ───────────────────────────────────────────────────

  Widget _buildStep1() {
    return Form(
      key: _step1FormKey,
      onChanged: () => setState(() {}),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: AppRadius.mdRadius,
                  border: Border.all(color: AppColors.softBlueBorder, width: 1.0),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 26,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Business Name',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'The only required field to get started',
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Shop Name (ONLY Required Field) ───────────────────────────────
          const Text('Shop / Business Name *', style: AppTypography.titleSmall),
          const SizedBox(height: 2),
          Text(
            'Announced aloud on every payment receipt',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            controller: _shopNameController,
            textCapitalization: TextCapitalization.words,
            maxLength: 40,
            autofocus: true,
            style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'e.g. Ramesh Kirana Store / Chai Point',
              prefixIcon: Icon(Icons.store_rounded, color: AppColors.primaryBlue),
              counterText: '',
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Shop name is required.';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Owner Name (Optional) ─────────────────────────────────────────
          const Text('Owner Name (Optional)', style: AppTypography.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            controller: _ownerController,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'e.g. Ramesh Kumar',
              prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.primaryBlue),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Category (Optional) ───────────────────────────────────────────
          const Text('Category (Optional)', style: AppTypography.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(
              hintText: 'Select category (Grocery, Restaurant, etc.)',
              prefixIcon: Icon(Icons.category_outlined, color: AppColors.primaryBlue),
            ),
            items: kShopCategories.map((cat) {
              return DropdownMenuItem(value: cat, child: Text(cat));
            }).toList(),
            onChanged: (val) {
              setState(() => _selectedCategory = val);
            },
          ),

          if (_selectedCategory == 'Other') ...[
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _categoryOtherController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Specify business type (e.g. Dairy, Gift Shop)',
                prefixIcon: Icon(Icons.edit_note_rounded, color: AppColors.primaryBlue),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Step 2: UPI ID & Soundbox Preview ──────────────────────────────────────

  Widget _buildStep2() {
    final shop = _shopNameController.text.trim();
    final displayName = shop.isEmpty ? 'MyUPI' : shop;

    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: AppRadius.mdRadius,
                  border: Border.all(color: AppColors.softBlueBorder, width: 1.0),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  size: 26,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'QR Code & Soundbox Check',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Add your UPI ID and test speaker announcement',
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── UPI ID Field ──────────────────────────────────────────────────
          const Text('UPI ID (Optional)', style: AppTypography.titleSmall),
          const SizedBox(height: 2),
          Text(
            'Generates your payment QR card on the Home dashboard',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            controller: _upiIdController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'e.g. shopname@okhdfcbank',
              prefixIcon: Icon(Icons.qr_code_rounded, color: AppColors.primaryBlue),
            ),
            validator: (val) {
              if (val != null && val.trim().isNotEmpty && !val.trim().contains('@')) {
                return 'UPI ID must contain @ (e.g. name@okhdfcbank).';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),

          // ── Handle suggestion chips ───────────────────────────────────────
          const Text(
            'Popular handle suggestions:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _upiHandles.map((handle) {
              return ActionChip(
                label: Text(
                  handle,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
                ),
                backgroundColor: AppColors.lightBlue,
                side: const BorderSide(color: AppColors.softBlueBorder),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                visualDensity: VisualDensity.compact,
                onPressed: () => _applyHandle(handle),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Audio Soundbox Preview Card ───────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: AppRadius.mdRadius,
              border: Border.all(color: AppColors.softBlueBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.volume_up_rounded, color: AppColors.primaryBlue, size: 20),
                    const SizedBox(width: 8),
                    const Text('Hear Your Soundbox', style: AppTypography.titleSmall),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Sample payment announcement:',
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Text(
                    'Preview: "₹500 received on My U P I for $displayName."',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
                    ),
                    onPressed: _playSampleAnnouncement,
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text('Play Sample Announcement', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),

          if (_duplicateAccountWarning != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _duplicateAccountWarning!,
              style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}
