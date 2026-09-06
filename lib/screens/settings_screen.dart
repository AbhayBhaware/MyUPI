// lib/screens/settings_screen.dart
//
// Settings screen — Soundbox, Speech, Notification Access, About.
// All settings are persisted in Kotlin SharedPreferences via MethodChannel.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_channels.dart';
import 'diagnostics_screen.dart';

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
            content: Text('Selected language is not available on this device.'),
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: ListView(
        children: [

          // ── MERCHANT ────────────────────────────────────────────────────────
          _sectionHeader('MERCHANT'),
          ListTile(
            leading: const Icon(Icons.storefront),
            title: const Text('Shop / Business Name',
                style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(_merchantName),
            trailing: const Icon(Icons.edit, size: 20, color: Colors.grey),
            onTap: _showEditMerchantNameDialog,
          ),

          // ── SOUNDBOX ──────────────────────────────────────────────────────
          _sectionHeader('SOUNDBOX'),
          SwitchListTile(
            title: const Text('Soundbox',
                style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
              _soundboxEnabled
                  ? 'Payment announcements are on'
                  : 'Payment announcements are off',
              style: TextStyle(
                  fontSize: 12,
                  color: _soundboxEnabled ? Colors.green : Colors.grey),
            ),
            secondary: Icon(
              _soundboxEnabled ? Icons.volume_up : Icons.volume_off,
              color: _soundboxEnabled ? cs.primary : Colors.grey,
            ),
            value: _soundboxEnabled,
            onChanged: _setSoundbox,
          ),

          // ── VOICE ────────────────────────────────────────────────────────
          _sectionHeader('VOICE'),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language',
                style: TextStyle(fontWeight: FontWeight.w500)),
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
            title: const Text('Speech Speed',
                style: TextStyle(fontWeight: FontWeight.w500)),
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
            title: const Text('Announcement Format',
                style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(_getFormatLabel(_announceFormat)),
            trailing: DropdownButton<String>(
              value: _announceFormat,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'A', child: Text('Format A')),
                DropdownMenuItem(value: 'B', child: Text('Format B')),
                DropdownMenuItem(value: 'C', child: Text('Format C')),
              ],
              onChanged: (v) { if (v != null) _setAnnounceFormat(v); },
            ),
          ),
          const Divider(height: 1, indent: 72, endIndent: 16),
          SwitchListTile(
            secondary: const Icon(Icons.store),
            title: const Text('Include Shop Name',
                style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text('Announce the shop name at the end'),
            value: _includeShopName,
            onChanged: _setIncludeShopName,
          ),
          const Divider(height: 1, indent: 72, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.volume_up),
            title: const Text('Announcement Volume',
                style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text(
              'Uses system volume. Cannot be changed independently.',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
            trailing: const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
          ),

          // ── NOTIFICATION ACCESS ───────────────────────────────────────────
          _sectionHeader('NOTIFICATION ACCESS'),
          ListTile(
            leading: Icon(
              _notifAccess == true
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              color: _notifAccess == true ? Colors.green : Colors.orange,
            ),
            title: const Text('Notification Access',
                style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
              _notifAccess == null
                  ? 'Checking…'
                  : _notifAccess!
                      ? 'Enabled — MyUPI can detect payments'
                      : 'Disabled — payments cannot be detected',
              style: TextStyle(
                  fontSize: 12,
                  color: _notifAccess == true ? Colors.green : Colors.orange),
            ),
          ),
          if (_notifAccess == false)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openAccessSettings,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Enable Notification Access'),
                ),
              ),
            ),

          // ── ABOUT ─────────────────────────────────────────────────────────
          _sectionHeader('ABOUT'),
          const ListTile(
            leading: Icon(Icons.battery_alert_outlined),
            title: Text('Keep MyUPI running reliably',
                style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
              'Some phones restrict background apps to save battery. '
              'For reliable payment announcements, allow MyUPI to run in the background without battery restrictions.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('MyUPI Soundbox',
                style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text('Version 1.0.0'),
          ),
          const ListTile(
            leading: Icon(Icons.security_outlined),
            title: Text('Privacy',
                style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
              'Payment history is stored only on this device. '
              'No personal data is uploaded or shared.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.developer_mode_outlined),
            title: const Text('Developer Diagnostics',
                style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text(
              'System health, parser version, flags, and architecture',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => const DiagnosticsScreen(),
                ),
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
      }
    );
  }
}
