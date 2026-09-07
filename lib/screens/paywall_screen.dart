// lib/screens/paywall_screen.dart
//
// MyUPI Smart Soundbox Premium Paywall Screen — Milestone 20
// ---------------------------------------------------------
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
import '../services/billing_service.dart';
import '../services/subscription_manager.dart';
import '../models/subscription_state.dart';

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
          backgroundColor: Colors.red.shade800,
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
            ? Colors.green.shade800
            : Colors.indigo.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final billing = BillingService.instance;

    return ValueListenableBuilder<SubscriptionInfo>(
      valueListenable: SubscriptionManager.instance.subscriptionInfoNotifier,
      builder: (context, subInfo, _) {
        final isAlreadyPremium = subInfo.state.hasPremiumEntitlement;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'MyUPI Premium',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            backgroundColor: cs.surface,
            elevation: 0,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // ── Hero Badge & Headline ─────────────────────────────────────────
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFD8B4FE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.star_rounded, size: 18, color: Color(0xFF7E22CE)),
                        SizedBox(width: 6),
                        Text(
                          'SMART SOUNDBOX UPGRADE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF7E22CE),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Turn your phone into a smart UPI Soundbox.',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: Color(0xFF1F2937),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                const Text(
                  'Get instant voice announcements for your UPI payments without renting an expensive hardware device.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4B5563),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // ── Active Subscription Status Banner (if already subscribed) ────
                if (isAlreadyPremium) ...[
                  _buildAlreadySubscribedBanner(subInfo),
                  const SizedBox(height: 20),
                ],

                // ── Commercial Pricing Card (Dynamic Play Store Price) ───────────
                _buildPricingCard(cs, billing),
                const SizedBox(height: 20),

                // ── Value Proposition / Feature Checklist ─────────────────────────
                _buildBenefitsCard(),
                const SizedBox(height: 16),

                // ── Transparent System Boundaries Notice ──────────────────────────
                _buildTransparentNoticeCard(),
                const SizedBox(height: 24),

                // ── Primary Action CTA (Live Google Play Purchase) ─────────────────
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _handleStartSubscription,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF5B21B6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isAlreadyPremium
                                ? 'Manage Subscription'
                                : 'Start Premium — ${billing.introPriceDisplay} First Month',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Secondary Action (Restore Purchases Flow) ─────────────────────
                Center(
                  child: TextButton.icon(
                    onPressed: _isRestoring ? null : _handleRestorePurchases,
                    icon: _isRestoring
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.restore, size: 16, color: Color(0xFF6B7280)),
                    label: const Text(
                      'Restore Purchases',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Transparent Terms & Auto-Renewal Notice ───────────────────────
                Text(
                  'Introductory offer of ${billing.introPriceDisplay} for the first 30 days, then ${billing.recurringPriceDisplay} automatically. '
                  'No hardware lock-in. Cancel anytime via Google Play subscriptions without penalty.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Pricing Card Builder ───────────────────────────────────────────────────

  Widget _buildPricingCard(ColorScheme cs, BillingService billing) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B21B6).withAlpha(40),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.shade300,
              borderRadius: BorderRadius.circular(20),
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
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                billing.introPriceDisplay,
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'for your first month',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE9D5FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(35),
              borderRadius: BorderRadius.circular(8),
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
          const SizedBox(height: 12),
          const Text(
            'Save ₹1,500+ every year compared to external soundbox rental machines.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFFF3E8FF),
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
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 24),
          const SizedBox(width: 12),
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
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Everything Included in MyUPI Premium',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 14),
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
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF5B21B6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
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

  // ── Transparent Notice Card ────────────────────────────────────────────────

  Widget _buildTransparentNoticeCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.shield_outlined, size: 18, color: Color(0xFF4B5563)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'MyUPI uses on-device Android notifications to detect and announce payments. '
              'It operates locally for privacy and speed, and does not claim direct bank settlement verification.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF6B7280),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.info_outline_rounded, color: Color(0xFF5B21B6)),
            SizedBox(width: 8),
            Text('Billing Connecting'),
          ],
        ),
        content: Text(
          detail != null && detail.isNotEmpty
              ? '$detail\n\nPlease check your internet connection or Google Play account. Your soundbox continues to announce payments offline without interruption.'
              : 'Google Play Billing is connecting. Please check your internet connection or try again shortly.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('GOT IT'),
          ),
        ],
      ),
    );
  }
}
