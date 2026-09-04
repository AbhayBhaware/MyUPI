// lib/screens/settings_screen.dart
//
// Settings screen — Soundbox, Speech, Notification Access, About.
// All settings are persisted in Kotlin SharedPreferences via MethodChannel.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_channels.dart';

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
      if (!mounted) return;
      setState(() { _soundboxEnabled = on; _speechSpeed = speed; });
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

          // ── SPEECH ────────────────────────────────────────────────────────
          _sectionHeader('SPEECH'),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language',
                style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text('English (India)'),
            trailing: const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
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
}
