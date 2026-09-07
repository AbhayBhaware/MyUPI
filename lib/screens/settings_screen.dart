// lib/screens/settings_screen.dart
//
// Settings screen — organized strictly into 3 merchant categories:
// 1. SOUNDBOX (toggle, shop name, language, speed, format)
// 2. SUBSCRIPTION (MyUPI Premium status, upgrade plans, restore purchases)
// 3. APP (notification access, Help & Support, About MyUPI)
//
// Developer Diagnostics is removed from direct view and placed behind
// a 7-tap version gesture in AboutScreen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_channels.dart';
import 'about_screen.dart';
import 'help_support_screen.dart';
import 'paywall_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {

  @override
  bool get wantKeepAlive => true;

  bool   _soundboxEnabled = true;
  String _speechSpeed     = 'normal';
  String _language        = 'en-IN';
  String _merchantName    = 'MyUPI';
  String _announceFormat  = 'A';
  bool   _includeShopName = false;
  bool?  _notifAccess;
  bool   _isRestoring     = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkAccess();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadSettings(), _checkAccess()]);
  }

  Future<void> _loadSettings() async {
    try {
      final on    = await kMethodChannel.invokeMethod<bool>('isSoundboxEnabled')  ?? true;
      final speed = await kMethodChannel.invokeMethod<String>('getSpeechSpeed')   ?? 'normal';
      final lang  = await kMethodChannel.invokeMethod<String>('getLanguage')      ?? 'en-IN';
      final mName = await kMethodChannel.invokeMethod<String>('getMerchantName')  ?? 'MyUPI';
      final aFmt  = await kMethodChannel.invokeMethod<String>('getAnnouncementFormat') ?? 'A';
      final inc   = await kMethodChannel.invokeMethod<bool>('getIncludeShopName') ?? false;
      if (!mounted) return;
      setState(() { 
        _soundboxEnabled = on; 
        _speechSpeed = speed;
        _language = lang;
        _merchantName = mName;
        _announceFormat = aFmt;
        _includeShopName = inc;
      });
    } on PlatformException catch (_) {}
  }

  Future<void> _checkAccess() async {
    try {
      final ok = await kMethodChannel.invokeMethod<bool>('isNotificationAccessEnabled') ?? false;
      if (!mounted) return;
      setState(() => _notifAccess = ok);
    } on PlatformException catch (_) {}
  }

  Future<void> _setSoundbox(bool v) async {
    setState(() => _soundboxEnabled = v);
    try { await kMethodChannel.invokeMethod('setSoundboxEnabled', {'enabled': v}); }
    on PlatformException catch (_) {}
  }

  Future<void> _setSpeed(String v) async {
    setState(() => _speechSpeed = v);
    try { await kMethodChannel.invokeMethod('setSpeechSpeed', {'speed': v}); }
    on PlatformException catch (_) {}
  }

  Future<void> _setLanguage(String langCode) async {
    try {
      final available = await kMethodChannel.invokeMethod<bool>('checkLanguageAvailability', {'language': langCode});
      if (available == true) {
        setState(() => _language = langCode);
        await kMethodChannel.invokeMethod('setLanguage', {'language': langCode});
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected language is not available on this device voice engine.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on PlatformException catch (_) {}
  }

  Future<void> _setMerchantName(String name) async {
    setState(() => _merchantName = name);
    try { await kMethodChannel.invokeMethod('setMerchantName', {'name': name}); }
    on PlatformException catch (_) {}
  }

  Future<void> _setAnnounceFormat(String v) async {
    setState(() => _announceFormat = v);
    try { await kMethodChannel.invokeMethod('setAnnouncementFormat', {'format': v}); }
    on PlatformException catch (_) {}
  }

  Future<void> _setIncludeShopName(bool v) async {
    setState(() => _includeShopName = v);
    try { await kMethodChannel.invokeMethod('setIncludeShopName', {'enabled': v}); }
    on PlatformException catch (_) {}
  }

  Future<void> _openAccessSettings() async {
    try { await kMethodChannel.invokeMethod('openNotificationAccessSettings'); }
    on PlatformException catch (_) {}
  }

  Future<void> _handleRestorePurchases() async {
    if (_isRestoring) return;
    setState(() => _isRestoring = true);
    try {
      final result = await BillingService.instance.restorePurchases();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to reach Google Play Store. Please check connection.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: ListView(
        children: [

          // ════════════════════════════════════════════════════════════════════
          // 1. SOUNDBOX SECTION
          // ════════════════════════════════════════════════════════════════════
          _sectionHeader('SOUNDBOX'),
          SwitchListTile(
            title: const Text('Soundbox', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
              _soundboxEnabled
                  ? 'Payment announcements are on'
                  : 'Payment announcements are paused',
              style: TextStyle(
                fontSize: 12,
                color: _soundboxEnabled ? Colors.green : Colors.grey,
              ),
            ),
            secondary: Icon(
              _soundboxEnabled ? Icons.volume_up : Icons.volume_off,
              color: _soundboxEnabled ? cs.primary : Colors.grey,
            ),
            value: _soundboxEnabled,
            onChanged: _setSoundbox,
          ),
          const Divider(height: 1, indent: 72, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.storefront),
            title: const Text('Shop / Business Name', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(_merchantName),
            trailing: const Icon(Icons.edit, size: 20, color: Colors.grey),
            onTap: _showEditMerchantNameDialog,
          ),
          const Divider(height: 1, indent: 72, endIndent: 16),
          SwitchListTile(
            secondary: const Icon(Icons.store),
            title: const Text('Include Shop Name', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
              _includeShopName
                  ? 'Shop name included in announcement'
                  : 'Standard announcement without shop name',
              style: const TextStyle(fontSize: 12),
            ),
            value: _includeShopName,
            onChanged: _setIncludeShopName,
          ),
          const Divider(height: 1, indent: 72, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Announcement Language', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(_getLanguageLabel(_language)),
            trailing: DropdownButton<String>(
              value: _language,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'en-IN', child: Text('English (India)')),
                DropdownMenuItem(value: 'hi-IN', child: Text('Hindi')),
                DropdownMenuItem(value: 'mr-IN', child: Text('Marathi')),
                DropdownMenuItem(value: 'gu-IN', child: Text('Gujarati')),
                DropdownMenuItem(value: 'ta-IN', child: Text('Tamil')),
                DropdownMenuItem(value: 'te-IN', child: Text('Telugu')),
                DropdownMenuItem(value: 'bn-IN', child: Text('Bengali')),
                DropdownMenuItem(value: 'kn-IN', child: Text('Kannada')),
              ],
              onChanged: (v) { if (v != null) _setLanguage(v); },
            ),
          ),
          const Divider(height: 1, indent: 72, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('Speech Speed', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text('How fast payments are announced'),
            trailing: DropdownButton<String>(
              value: _speechSpeed,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'slow',   child: Text('Slow')),
                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                DropdownMenuItem(value: 'fast',   child: Text('Fast')),
              ],
              onChanged: (v) { if (v != null) _setSpeed(v); },
            ),
          ),
          const Divider(height: 1, indent: 72, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.record_voice_over),
            title: const Text('Announcement Format', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(_getFormatLabel(_announceFormat)),
            trailing: DropdownButton<String>(
              value: _announceFormat,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'A', child: Text('Format A (Standard)')),
                DropdownMenuItem(value: 'B', child: Text('Format B (Short)')),
                DropdownMenuItem(value: 'C', child: Text('Format C (Quick)')),
              ],
              onChanged: (v) { if (v != null) _setAnnounceFormat(v); },
            ),
          ),
          const Divider(height: 1, indent: 72, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.volume_up),
            title: const Text('Announcement Volume', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text(
              'Uses phone media volume. Adjust via your device volume buttons.',
              style: TextStyle(fontSize: 12),
            ),
          ),

          // ════════════════════════════════════════════════════════════════════
          // 2. SUBSCRIPTION SECTION
          // ════════════════════════════════════════════════════════════════════
          _sectionHeader('SUBSCRIPTION'),
          ValueListenableBuilder<SubscriptionInfo>(
            valueListenable: SubscriptionManager.instance.subscriptionInfoNotifier,
            builder: (context, subInfo, _) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                elevation: 0,
                color: const Color(0xFFFBF8FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: subInfo.state.hasPremiumEntitlement
                        ? Colors.green.shade200
                        : const Color(0xFFE9D5FF),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.workspace_premium_rounded,
                                  size: 20, color: Color(0xFF7E22CE)),
                              SizedBox(width: 8),
                              Text(
                                'MyUPI Premium',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: subInfo.state.hasPremiumEntitlement
                                  ? Colors.green.shade50
                                  : const Color(0xFFF3E8FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              subInfo.state.label.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: subInfo.state.hasPremiumEntitlement
                                    ? Colors.green.shade700
                                    : const Color(0xFF7E22CE),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subInfo.state.hasPremiumEntitlement
                            ? 'All 8 Indian languages, custom shop branding, and priority announcements active.'
                            : 'Introductory Offer: ₹1 for first month, then ₹49/month. Cancel anytime via Play Store.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), height: 1.35),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (ctx) => const PaywallScreen(sourceEntry: 'settings'),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF5B21B6),
                                side: const BorderSide(color: Color(0xFF8B5CF6)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: Text(
                                subInfo.state.hasPremiumEntitlement ? 'Manage Subscription' : 'View Premium Plans',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _isRestoring ? null : _handleRestorePurchases,
                            icon: _isRestoring
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.restore, size: 16),
                            label: const Text('Restore', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ════════════════════════════════════════════════════════════════════
          // 3. APP SECTION
          // ════════════════════════════════════════════════════════════════════
          _sectionHeader('APP'),
          ListTile(
            leading: Icon(
              _notifAccess == true
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              color: _notifAccess == true ? Colors.green : Colors.orange,
            ),
            title: const Text('Notification Access', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
              _notifAccess == null
                  ? 'Checking…'
                  : _notifAccess!
                      ? 'Enabled — MyUPI can hear payment notifications'
                      : 'Disabled — payments cannot be announced',
              style: TextStyle(
                fontSize: 12,
                color: _notifAccess == true ? Colors.green : Colors.orange,
              ),
            ),
            trailing: _notifAccess == false
                ? OutlinedButton(
                    onPressed: _openAccessSettings,
                    child: const Text('Enable', style: TextStyle(fontSize: 12)),
                  )
                : null,
          ),
          const Divider(height: 1, indent: 72, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text('FAQs, setup guides, and troubleshooting', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const HelpSupportScreen()),
              );
            },
          ),
          const Divider(height: 1, indent: 72, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About MyUPI', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text('Version 1.0.0, privacy policy, and terms', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const AboutScreen()),
              );
            },
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  String _getFormatLabel(String f) {
    switch(f) {
      case 'B': return 'Format B: "500 rupees received"';
      case 'C': return 'Format C: "Payment received, 500 rupees. Thank you."';
      default:  return 'Format A: "Payment received, 500 rupees"';
    }
  }

  String _getLanguageLabel(String langCode) {
    switch(langCode) {
      case 'hi-IN': return 'Hindi';
      case 'mr-IN': return 'Marathi';
      case 'gu-IN': return 'Gujarati';
      case 'ta-IN': return 'Tamil';
      case 'te-IN': return 'Telugu';
      case 'bn-IN': return 'Bengali';
      case 'kn-IN': return 'Kannada';
      default: return 'English (India)';
    }
  }

  void _showEditMerchantNameDialog() {
    final controller = TextEditingController(text: _merchantName);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Shop Name'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Shop / Business Name',
              hintText: 'e.g. Abhay General Store',
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  _setMerchantName(text);
                }
                Navigator.pop(ctx);
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
  }
}
