// lib/screens/auth/setup_wizard_screen.dart
//
// Setup Wizard — One-time post-auth merchant configuration.
// -----------------------------------------------------------
// Guardrails:
// 1. Single scrolling form (no step indicators or progress bar).
// 2. Hardware/gesture back-button blocked via PopScope(canPop: false).
// 3. Zero redundancy: skips/locks already known auth fields.
// 4. Shop name writes to existing Settings field (native setMerchantName).
// 5. Writes setupComplete: true to Firestore users/{uid} using kFieldSetupComplete.
// 6. Detects duplicate phone/email across different auth methods.

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
  final _formKey = GlobalKey<FormState>();

  final _ownerController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _categoryOtherController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _upiIdController = TextEditingController();

  String? _selectedCategory;
  bool _isLoading = false;
  String? _duplicateAccountWarning;

  late final bool _authenticatedViaPhone;
  late final bool _authenticatedViaEmailOrGoogle;

  @override
  void initState() {
    super.initState();

    final user = widget.user;
    final hasPhone = user.phoneNumber != null && user.phoneNumber!.isNotEmpty;
    final hasEmail = user.email != null && user.email!.isNotEmpty;

    _authenticatedViaPhone = hasPhone;
    _authenticatedViaEmailOrGoogle = hasEmail;

    if (hasPhone) {
      _phoneController.text = user.phoneNumber!;
    }
    if (hasEmail) {
      _emailController.text = user.email!;
    }
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      _ownerController.text = user.displayName!;
    }
  }

  @override
  void dispose() {
    _ownerController.dispose();
    _shopNameController.dispose();
    _categoryOtherController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    if (_ownerController.text.trim().isEmpty) return false;
    if (_shopNameController.text.trim().isEmpty) return false;
    if (_selectedCategory == null || _selectedCategory!.isEmpty) return false;
    if (_selectedCategory == 'Other' && _categoryOtherController.text.trim().isEmpty) {
      return false;
    }
    if (!_authenticatedViaPhone && _phoneController.text.trim().length < 10) {
      return false;
    }
    return true;
  }

  Future<void> _handleCompleteSetup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _duplicateAccountWarning = null;
    });

    final uid = widget.user.uid;
    final ownerName = _ownerController.text.trim();
    final shopName = _shopNameController.text.trim();
    final category = _selectedCategory ?? '';
    final categoryOther = category == 'Other' ? _categoryOtherController.text.trim() : null;
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final upiId = _upiIdController.text.trim().toLowerCase();

    String authMethod = 'phone';
    if (widget.user.providerData.any((p) => p.providerId == 'google.com')) {
      authMethod = 'google';
    } else if (widget.user.providerData.any((p) => p.providerId == 'password')) {
      authMethod = 'email';
    }

    // ── Duplicate Account Check across methods ──────────────────────────────
    final duplicateMsg = await FirestoreService.instance.findDuplicateAccount(
      currentUid: uid,
      phone: phone.isNotEmpty ? phone : null,
      email: email.isNotEmpty ? email : null,
    );

    if (duplicateMsg != null && mounted) {
      setState(() {
        _isLoading = false;
        _duplicateAccountWarning = duplicateMsg;
      });
      return;
    }

    // ── 1. Synchronize to native Soundbox engine (Settings parity) ─────────
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
              'Could not save shop setup to database. Please check your internet connection or database security rules.';
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
      // Hardware & gesture back-button blocked while setup is incomplete
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
          automaticallyImplyLeading: false, // No back arrow affordance
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            child: Form(
              key: _formKey,
              onChanged: () => setState(() {}), // Refresh button state
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hero Header ─────────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.lightBlue,
                          borderRadius: AppRadius.mdRadius,
                          border: Border.all(color: AppColors.softBlueBorder, width: 1.0),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          size: 30,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Setup Your Soundbox',
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Takes 30 seconds · One-time setup',
                              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Duplicate Account Alert ─────────────────────────────────
                  if (_duplicateAccountWarning != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warningBg,
                        borderRadius: AppRadius.mdRadius,
                        border: Border.all(color: AppColors.warningBorder, width: 1.0),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _duplicateAccountWarning!,
                              style: const TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // ── 1. Owner / Business Person Name (Required) ──────────────
                  const Text('Owner / Merchant Name *', style: AppTypography.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  TextFormField(
                    controller: _ownerController,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'e.g. Ramesh Kumar',
                      prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.primaryBlue),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Owner name is required.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── 2. Shop / Business Name (Required) ──────────────────────
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
                    style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'e.g. Ramesh Kirana Store',
                      prefixIcon: Icon(Icons.store_rounded, color: AppColors.primaryBlue),
                      counterText: '',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Shop name is required for voice announcements.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── 3. Shop Category Dropdown (Required) ────────────────────
                  const Text('Shop Category *', style: AppTypography.titleSmall),
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
                      hintText: 'Select category',
                      prefixIcon: Icon(Icons.category_outlined, color: AppColors.primaryBlue),
                    ),
                    items: kShopCategories.map((cat) {
                      return DropdownMenuItem(value: cat, child: Text(cat));
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedCategory = val);
                    },
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Please select your shop category.';
                      }
                      return null;
                    },
                  ),

                  // Free-text field if "Other" is chosen
                  if (_selectedCategory == 'Other') ...[
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _categoryOtherController,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Specify your shop type (e.g. Dairy, Gift Shop)',
                        prefixIcon: Icon(Icons.edit_note_rounded, color: AppColors.primaryBlue),
                      ),
                      validator: (val) {
                        if (_selectedCategory == 'Other' && (val == null || val.trim().isEmpty)) {
                          return 'Please specify your business type.';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),

                  // ── 4. Phone Number (Conditional) ───────────────────────────
                  if (_authenticatedViaPhone) ...[
                    const Text('Mobile Number', style: AppTypography.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    TextFormField(
                      controller: _phoneController,
                      readOnly: true,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.phone_android_rounded, color: AppColors.textTertiary),
                        suffixIcon: Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
                        filled: true,
                        fillColor: AppColors.background,
                      ),
                    ),
                  ] else ...[
                    const Text('Mobile Number *', style: AppTypography.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      'Used for SMS payment detection & soundbox alerts',
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: '98765 43210',
                        prefixIcon: Icon(Icons.phone_android_rounded, color: AppColors.primaryBlue),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().length < 10) {
                          return 'Please enter a valid 10-digit mobile number.';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),

                  // ── 5. Email (Conditional) ──────────────────────────────────
                  if (_authenticatedViaEmailOrGoogle) ...[
                    const Text('Email Address', style: AppTypography.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    TextFormField(
                      controller: _emailController,
                      readOnly: true,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.email_outlined, color: AppColors.textTertiary),
                        suffixIcon: Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
                        filled: true,
                        fillColor: AppColors.background,
                      ),
                    ),
                  ] else ...[
                    const Text('Email Address (Optional)', style: AppTypography.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      'Optional — for monthly summaries & receipts',
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'merchant@example.com',
                        prefixIcon: Icon(Icons.email_outlined, color: AppColors.primaryBlue),
                      ),
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty) {
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                            return 'Please enter a valid email format.';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),

                  // ── 6. UPI ID (Optional) ─────────────────────────────────
                  const Text('UPI ID (Optional)', style: AppTypography.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    'Your payment address for QR code generation (e.g. shop@upi)',
                    style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextFormField(
                    controller: _upiIdController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'yourname@upi / 9876543210@ybl',
                      prefixIcon: Icon(Icons.qr_code_rounded, color: AppColors.primaryBlue),
                    ),
                    validator: (val) {
                      if (val != null && val.trim().isNotEmpty) {
                        if (!val.trim().contains('@')) {
                          return 'UPI ID must contain @ (e.g. name@upi).';
                        }
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // ── Submit Button ───────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: (_isLoading || !_isFormValid) ? null : _handleCompleteSetup,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        disabledBackgroundColor: AppColors.cardBorder,
                        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                            )
                          : const Text(
                              'Get Started',
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
