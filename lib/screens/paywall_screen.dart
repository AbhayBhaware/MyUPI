// lib/screens/paywall_screen.dart
//
// MyUPI Smart Soundbox Premium Paywall Screen — Modern Fintech Redesign
// ---------------------------------------------------------------------
// Presents the merchant with the commercial subscription proposition:
//   • Introductory Offer: Dynamic Play price (Target: ₹1 for the first month)
//   • Recurring Price:    Dynamic Play price (Target: ₹49/month)
//
// Integrates with real Google Play Billing:
//   • Queries live Play Store product details & introductory pricing offer
//   • Launches Google Play purchase sheet via BillingService
//   • Handles purchase states: purchased, pending, canceled, error
//   • Provides one-tap "Restore Purchases" functionality
//   • Transparent terms, auto-renewal, and cancellation disclosure

import 'package:flutter/material.dart';

import '../models/subscription_state.dart';
import '../services/billing_service.dart';
import '../services/subscription_manager.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/premium_buttons.dart';
import '../widgets/premium_card.dart';

class PaywallScreen extends StatefulWidget {
  final String sourceEntry;

  const PaywallScreen({super.key, this.sourceEntry = 'direct'});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isLoading = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _loadBillingProduct();
  }

  Future<void> _loadBillingProduct() async {
    if (BillingService.instance.productDetails == null) {
      await BillingService.instance.queryProducts();
      if (mounted) setState(() {});
    }
  }

  Future<void> _handleStartSubscription() async {
    final billing = BillingService.instance;
    final product = billing.productDetails;

    if (product == null) {
      // If product details not yet resolved, attempt reload
      setState(() => _isLoading = true);
      final reloaded = await billing.queryProducts();
      setState(() => _isLoading = false);

      if (reloaded == null) {
        if (!mounted) return;
        _showUnavailableDialog(context, billing.lastErrorMessage);
        return;
      }
    }

    setState(() => _isLoading = true);
    final success = await billing.buySubscription(billing.productDetails!);
    if (mounted) setState(() => _isLoading = false);

    if (!success && billing.lastErrorMessage != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(billing.lastErrorMessage!),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleRestorePurchases() async {
    setState(() => _isRestoring = true);
    final result = await BillingService.instance.restorePurchases();
    if (mounted) setState(() => _isRestoring = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success && result.restoredCount > 0
            ? AppColors.success
            : AppColors.primaryBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final billing = BillingService.instance;

    return ValueListenableBuilder<SubscriptionInfo>(
      valueListenable: SubscriptionManager.instance.subscriptionInfoNotifier,
      builder: (context, subInfo, _) {
        final isAlreadyPremium = subInfo.state.hasPremiumEntitlement;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text(
              'MyUPI Premium',
              style: AppTypography.titleLarge,
            ),
            backgroundColor: AppColors.surface,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1.0),
              child: Divider(height: 1, color: AppColors.borderLight),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: AppSpacing.md,
              ),
              children: [
                // ── Hero Badge & Headline ─────────────────────────────────────────
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue,
                      borderRadius: AppRadius.pillRadius,
                      border: Border.all(color: AppColors.primaryBlue.withAlpha(50)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.star_rounded, size: 16, color: AppColors.primaryBlue),
                        SizedBox(width: 6),
                        Text(
                          'SMART SOUNDBOX UPGRADE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryBlue,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                const Text(
                  'Turn your phone into a smart UPI Soundbox.',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),

                const Text(
                  'Get instant voice announcements for your UPI payments without renting an expensive hardware device.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Trust Badges (Offline, No Bank Link, Cancel via Play) ────────
                _buildTrustBadges(),
                const SizedBox(height: AppSpacing.lg),

                // ── Active Subscription Status Banner (if already subscribed) ────
                if (isAlreadyPremium) ...[
                  _buildAlreadySubscribedBanner(subInfo),
                  const SizedBox(height: AppSpacing.md),
                ],

                // ── Commercial Pricing Card (Dynamic Play Store Price) ───────────
                _buildPricingCard(billing),
                const SizedBox(height: AppSpacing.base),

                // ── Value Proposition / Feature Checklist ─────────────────────────
                _buildBenefitsCard(),
                const SizedBox(height: AppSpacing.base),

                // ── Primary Action CTA (Live Google Play Purchase) ─────────────────
                PrimaryButton(
                  label: isAlreadyPremium
                      ? 'Manage Subscription'
                      : 'Start Premium — ${billing.introPriceDisplay} First Month',
                  isLoading: _isLoading,
                  icon: isAlreadyPremium ? Icons.settings_rounded : Icons.bolt_rounded,
                  onPressed: _isLoading ? null : _handleStartSubscription,
                ),
                const SizedBox(height: AppSpacing.sm),

                // ── Secondary Action (Restore Purchases Flow) ─────────────────────
                Center(
                  child: TextButton.icon(
                    onPressed: _isRestoring ? null : _handleRestorePurchases,
                    icon: _isRestoring
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                          )
                        : const Icon(Icons.restore_rounded, size: 16, color: AppColors.primaryBlue),
                    label: const Text(
                      'Restore Purchases',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),

                // ── Transparent Terms & Auto-Renewal Notice ───────────────────────
                Text(
                  'Introductory offer of ${billing.introPriceDisplay} for the first 30 days, then ${billing.recurringPriceDisplay} automatically. '
                  'No hardware lock-in. Cancel anytime via Google Play subscriptions without penalty.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Side-by-Side Comparison Table (Correction 1.5 math) ───────────
                _buildComparisonTable(billing),
                const SizedBox(height: AppSpacing.base),

                // ── Frequently Asked Questions (FAQ Accordions) ───────────────────
                _buildFaqSection(),
                const SizedBox(height: AppSpacing.base),

                // ── Transparent System Boundaries Notice ──────────────────────────
                _buildTransparentNoticeCard(),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Pricing Card Builder ───────────────────────────────────────────────────

  Widget _buildPricingCard(BillingService billing) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: AppRadius.lgRadius,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withAlpha(45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.shade300,
              borderRadius: AppRadius.pillRadius,
            ),
            child: const Text(
              'SPECIAL INTRODUCTORY OFFER',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFF78350F),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.xs,
            runSpacing: 2,
            children: [
              Text(
                billing.introPriceDisplay,
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const Text(
                'for your first month',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD6E4FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: AppRadius.smRadius,
            ),
            child: Text(
              'THEN ${billing.recurringPriceDisplay.toUpperCase()}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Save ₹1,500+ every year compared to external soundbox rental machines.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFFEAF3FF),
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Active Subscription Banner ──────────────────────────────────────────────

  Widget _buildAlreadySubscribedBanner(SubscriptionInfo subInfo) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: AppColors.successBorder),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MyUPI Premium is Active',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF065F46),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subInfo.expiresAt != null
                      ? 'Renews automatically on ${subInfo.expiresAt!.toLocal().toString().split(' ')[0]}'
                      : 'All 8 languages and shop branding are unlocked.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF047857)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Benefits Card Builder ──────────────────────────────────────────────────

  Widget _buildBenefitsCard() {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Everything Included in MyUPI Premium',
            style: AppTypography.titleSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          _benefitRow(
            icon: Icons.volume_up_rounded,
            title: 'Instant Voice Announcements',
            desc: 'Speaks incoming payments from PhonePe, GPay, Paytm, BHIM, and bank UPI apps.',
          ),
          _benefitRow(
            icon: Icons.translate_rounded,
            title: 'All 8 Supported Indian Languages',
            desc: 'Hindi, Marathi, Gujarati, Tamil, Telugu, Bengali, Kannada, and English.',
          ),
          _benefitRow(
            icon: Icons.store_rounded,
            title: 'Personalized Shop Name Voice',
            desc: 'Includes your shop name in voice audio for customer confidence.',
          ),
          _benefitRow(
            icon: Icons.record_voice_over_rounded,
            title: 'Multiple Announcement Styles',
            desc: 'Choose between brief, polite, and detailed audio styles.',
          ),
          _benefitRow(
            icon: Icons.insights_rounded,
            title: 'Daily & Weekly Collection Insights',
            desc: 'Clear summaries of your shop transactions at a glance.',
          ),
          _benefitRow(
            icon: Icons.phonelink_ring_rounded,
            title: 'No Hardware Device Required',
            desc: 'Zero monthly machine rent, zero SIM maintenance, and zero battery charging worries.',
          ),
        ],
      ),
    );
  }

  Widget _benefitRow({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: AppRadius.smRadius,
            ),
            child: Icon(icon, size: 18, color: AppColors.primaryBlue),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Trust Badges (Only True Claims: Offline, Zero Bank Link, Play Store Cancel) ──

  Widget _buildTrustBadges() {
    return Row(
      children: [
        _buildTrustBadgeItem(
          icon: Icons.wifi_off_rounded,
          title: 'Works Offline',
          subtitle: 'On-device voice',
        ),
        const SizedBox(width: 8),
        _buildTrustBadgeItem(
          icon: Icons.lock_outline_rounded,
          title: 'Zero Bank Link',
          subtitle: 'No PIN or login',
        ),
        const SizedBox(width: 8),
        _buildTrustBadgeItem(
          icon: Icons.play_arrow_rounded,
          title: 'Google Play',
          subtitle: 'Cancel anytime',
        ),
      ],
    );
  }

  Widget _buildTrustBadgeItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdRadius,
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: AppColors.primaryBlue),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  // ── Comparison Table (Hardware Soundbox vs MyUPI) ─────────────────────────

  Widget _buildComparisonTable(BillingService billing) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.compare_arrows_rounded, size: 20, color: AppColors.primaryBlue),
              SizedBox(width: 8),
              Text(
                'Hardware Soundbox vs MyUPI',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: const [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Feature',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Hardware Box',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'MyUPI App',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Rows
          _buildComparisonRow(
            feature: 'Year 1 Cost',
            hardware: 'Up to ₹1,500 – ₹1,800/yr\n(₹125–₹150/mo)',
            myupi: '₹540 in Year 1\n(${billing.introPriceDisplay} 1st mo + 11 × ${billing.recurringPriceDisplay})',
            highlight: true,
          ),
          _buildComparisonRow(
            feature: 'Year 2+ Cost',
            hardware: 'Up to ₹1,500 – ₹1,800/yr',
            myupi: '₹588/yr\n(12 × ${billing.recurringPriceDisplay})',
          ),
          _buildComparisonRow(
            feature: 'Hardware',
            hardware: 'Bulky rental machine',
            myupi: 'Your existing phone',
          ),
          _buildComparisonRow(
            feature: 'Charging',
            hardware: 'Separate charger & battery',
            myupi: 'No extra device to charge',
          ),
          _buildComparisonRow(
            feature: 'UPI Apps',
            hardware: 'Single QR brand only',
            myupi: 'All UPI Apps (GPay, PhonePe, Paytm, etc.)',
          ),
          _buildComparisonRow(
            feature: 'Cancellation',
            hardware: 'Device return & fees',
            myupi: '1-tap cancel via Google Play',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow({
    required String feature,
    required String hardware,
    required String myupi,
    bool highlight = false,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlight ? AppColors.lightBlue.withAlpha(80) : Colors.transparent,
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              feature,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              hardware,
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), height: 1.25),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              myupi,
              style: TextStyle(
                fontSize: 10,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
                color: highlight ? AppColors.primaryBlue : const Color(0xFF0F172A),
                height: 1.25,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ── FAQ Accordion Section ─────────────────────────────────────────────────

  Widget _buildFaqSection() {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.help_outline_rounded, size: 20, color: AppColors.primaryBlue),
              SizedBox(width: 8),
              Text(
                'Frequently Asked Questions',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildFaqItem(
            question: 'How is MyUPI cheaper than a physical soundbox?',
            answer:
                'Physical soundboxes charge ₹125–₹150 every month in rental fees (up to ₹1,500–₹1,800/yr) plus security deposits. MyUPI uses the loudspeaker already in your smartphone for just ₹1 for your first month and ₹49/month after, saving you over ₹1,200 every year.',
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          _buildFaqItem(
            question: 'Do I need to link my bank account or enter UPI PIN?',
            answer:
                'No! MyUPI never asks for your bank account details, netbanking passwords, or UPI PINs. It works locally by detecting legitimate incoming transaction notifications and SMS alerts directly on your device.',
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          _buildFaqItem(
            question: 'Can I cancel my subscription anytime?',
            answer:
                'Yes. You have full control. You can cancel with a single tap in Google Play Store under "Payments & subscriptions" at any time with no cancellation penalties.',
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          _buildFaqItem(
            question: 'Does voice announcement work offline?',
            answer:
                'Yes! The Text-to-Speech voice engine is downloaded directly on your smartphone. When SMS or notification alerts arrive, MyUPI speaks the payment amount aloud immediately even if internet connectivity drops.',
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem({
    required String question,
    required String answer,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        iconColor: AppColors.primaryBlue,
        collapsedIconColor: AppColors.textSecondary,
        children: [
          Text(
            answer,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Transparent Notice Card ────────────────────────────────────────────────

  Widget _buildTransparentNoticeCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: AppColors.borderLight),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.shield_outlined, size: 18, color: AppColors.textSecondary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'MyUPI uses on-device Android notifications to detect and announce payments. '
              'It operates locally for privacy and speed, and does not claim direct bank settlement verification.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Informative Unavailable Dialog ─────────────────────────────────────────

  void _showUnavailableDialog(BuildContext context, String? detail) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
        title: Row(
          children: const [
            Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Billing Connecting',
                style: AppTypography.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          detail != null && detail.isNotEmpty
              ? '$detail\n\nPlease check your internet connection or Google Play account. Your soundbox continues to announce payments offline without interruption.'
              : 'Google Play Billing is connecting. Please check your internet connection or try again shortly.',
          style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('GOT IT', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
          ),
        ],
      ),
    );
  }
}
