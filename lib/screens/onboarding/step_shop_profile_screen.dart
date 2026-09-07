// lib/screens/onboarding/step_shop_profile_screen.dart
//
// Onboarding Step 4 — Shop / Merchant Profile.
// Allows merchant to set their shop name and toggle whether it is included
// in voice announcements. Persisted locally via native SharedPreferencesManager.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_channels.dart';

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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Step indicator ──────────────────────────────────────────────
              _StepIndicator(current: 4, total: 6),
              const SizedBox(height: 32),

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
                          color: cs.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          Icons.storefront_outlined,
                          size: 40,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Title ───────────────────────────────────────────────
                      Text(
                        'Your Shop Name',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Add your shop or business name to personalize payment announcements.',
                        style: TextStyle(
                          fontSize: 15,
                          color: cs.onSurface.withAlpha(180),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Shop Name Input ─────────────────────────────────────
                      if (_loading)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        Text(
                          'Shop or Business Name',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameController,
                          maxLength: 40,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: 'e.g. Abhay General Store',
                            prefixIcon: const Icon(Icons.business_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: cs.surfaceContainerHighest.withAlpha(50),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Include Shop Name in Announcement Switch ─────────
                        Card(
                          elevation: 0,
                          color: cs.surfaceContainerHighest.withAlpha(60),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: cs.outlineVariant.withAlpha(80)),
                          ),
                          child: SwitchListTile(
                            title: const Text(
                              'Announce shop name',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              _includeShopName
                                  ? 'Example: "Received ₹100 at ${_nameController.text.trim().isEmpty ? 'Your Shop' : _nameController.text.trim()}"'
                                  : 'Example: "Received ₹100 on PhonePe"',
                              style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurface.withAlpha(160),
                              ),
                            ),
                            secondary: Icon(
                              Icons.record_voice_over_outlined,
                              color: _includeShopName ? cs.primary : Colors.grey,
                            ),
                            value: _includeShopName,
                            onChanged: (val) {
                              setState(() => _includeShopName = val);
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Privacy note
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lock_outline, size: 18, color: cs.onSurface.withAlpha(140)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Saved only on your phone. Never uploaded to any server or cloud.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withAlpha(140),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // ── Continue Button ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _saveAndContinue,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (int i = 1; i <= total; i++) ...[
          Container(
            width: i == current ? 28 : 10,
            height: 10,
            decoration: BoxDecoration(
              color: i == current
                  ? cs.primary
                  : i < current
                      ? cs.primary.withAlpha(120)
                      : cs.onSurface.withAlpha(40),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          if (i < total) const SizedBox(width: 6),
        ],
        const SizedBox(width: 12),
        Text(
          'Step $current of $total',
          style: TextStyle(fontSize: 12, color: cs.onSurface.withAlpha(140)),
        ),
      ],
    );
  }
}
