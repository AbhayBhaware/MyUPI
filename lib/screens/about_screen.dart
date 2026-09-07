// lib/screens/about_screen.dart
//
// About MyUPI Screen — provides app version information, merchant terms,
// privacy policy, and a hidden 7-tap developer unlock for DiagnosticsScreen.

import 'package:flutter/material.dart';

import 'diagnostics_screen.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  int _tapCount = 0;
  bool _developerUnlocked = false;

  void _onVersionTap() {
    setState(() {
      _tapCount++;
    });

    if (_tapCount >= 7) {
      setState(() {
        _developerUnlocked = true;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Developer Diagnostics unlocked!'),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
      );
    } else if (_tapCount >= 4) {
      final remaining = 7 - _tapCount;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are $remaining step${remaining == 1 ? '' : 's'} away from Developer Diagnostics.'),
          duration: const Duration(milliseconds: 900),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.green),
            SizedBox(width: 10),
            Text('Privacy Policy'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            '100% On-Device & Zero-PII Policy\n\n'
            '1. Notification Processing: MyUPI uses Android\'s NotificationListenerService solely '
            'to detect incoming payment notifications from supported UPI apps. All text parsing '
            'and extraction happens entirely on your phone.\n\n'
            '2. Zero Data Collection: MyUPI does NOT collect, store, or transmit your personal data, '
            'bank details, UPI PINs, customer phone numbers, or account balances to any remote server.\n\n'
            '3. Offline Operation: The core payment soundbox works completely offline without requiring '
            'an active internet connection.\n\n'
            '4. In-App Subscriptions: Subscription payments are securely processed by Google Play Billing. '
            'MyUPI never accesses or stores your credit/debit card numbers or bank credentials.\n\n'
            '5. Local Storage: Payment ledger entries and soundbox settings are stored exclusively in '
            'your device\'s local storage and can be cleared anytime by uninstalling the app or clearing app data.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.gavel_outlined, color: Colors.blue),
            SizedBox(width: 10),
            Text('Terms of Service'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'Merchant Soundbox Agreement\n\n'
            '1. Service Description: MyUPI provides audio announcement of incoming UPI payments based on '
            'system notifications received from installed UPI apps on the merchant\'s device.\n\n'
            '2. Notification Fallback: Soundbox announcements depend on the merchant\'s phone receiving and '
            'displaying notifications from third-party UPI apps. If a UPI app fails to post a notification '
            'due to device battery saver, network outage, or DND mode, MyUPI cannot announce the payment.\n\n'
            '3. Merchant Responsibility: Merchants must ensure their phone is sufficiently charged, media volume '
            'is audible, and notifications for banking/UPI apps are enabled.\n\n'
            '4. No Bank Affiliation: MyUPI is an independent productivity utility and is not affiliated with, '
            'sponsored by, or endorsed by NPCI, PhonePe, Google Pay, Paytm, or any bank.\n\n'
            '5. Subscription Terms: Introductory offers (e.g. ₹1 for 1st month) and recurring monthly plans '
            'are billed through Google Play in accordance with Google Play subscription policies.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About MyUPI'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // App Logo & Info
          Center(
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withAlpha(80),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(Icons.speaker, size: 48, color: cs.onPrimary),
                ),
                const SizedBox(height: 16),
                Text(
                  'MyUPI Soundbox',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Turn your phone into a smart UPI payment soundbox.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withAlpha(160),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Version Tile (with 7-tap gesture)
          Card(
            elevation: 0,
            color: cs.surfaceContainerHighest.withAlpha(40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: cs.outlineVariant.withAlpha(60)),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: _onVersionTap,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('App Version'),
                    subtitle: const Text('1.0.0 (Build 1) · Production Ready'),
                    trailing: _developerUnlocked
                        ? const Chip(
                            label: Text('Dev Mode', style: TextStyle(fontSize: 11)),
                            backgroundColor: Colors.tealAccent,
                          )
                        : null,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.verified_outlined, color: Colors.green),
                  title: const Text('Architecture'),
                  subtitle: const Text('100% On-Device · Zero Cloud Dependency'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Legal & Policies
          Card(
            elevation: 0,
            color: cs.surfaceContainerHighest.withAlpha(40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: cs.outlineVariant.withAlpha(60)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  subtitle: const Text('Zero PII · No personal data collected'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showPrivacyPolicy(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms of Service'),
                  subtitle: const Text('Merchant rights and usage terms'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showTermsOfService(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // If developer mode unlocked, provide direct navigation button
          if (_developerUnlocked) ...[
            Card(
              elevation: 0,
              color: Colors.teal.withAlpha(20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.teal.withAlpha(80)),
              ),
              child: ListTile(
                leading: const Icon(Icons.developer_mode, color: Colors.teal),
                title: const Text(
                  'Developer Diagnostics',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                ),
                subtitle: const Text('Inspect engine state, billing tokens, parser tests'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.teal),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],

          Center(
            child: Text(
              'Made with pride for Indian small business owners.\nMyUPI © 2026',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withAlpha(120),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
