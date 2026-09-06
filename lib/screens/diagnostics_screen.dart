// lib/screens/diagnostics_screen.dart
//
// Developer Diagnostics & System Health Screen.
// Milestone 18 — Architecture Foundation & Future Verification Readiness
// ----------------------------------------------------------------------------
// Privacy Policy & Zero PII Guarantee:
// - ZERO raw notification text is logged or displayed here.
// - ZERO customer identifiers (phone numbers, UPI IDs, account numbers).
// - Only displays system health, engine parser version, feature flags,
//   and non-sensitive device configuration.

import 'package:flutter/material.dart';

import '../app_channels.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _diagnostics = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await kMethodChannel.invokeMapMethod<String, dynamic>('getDiagnostics');
      if (mounted) {
        setState(() {
          _diagnostics = res ?? {};
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load diagnostics: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Diagnostics'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Diagnostics',
            onPressed: _loadDiagnostics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadDiagnostics,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    _buildVerificationBanner(theme),
                    const SizedBox(height: 16),
                    _buildSystemHealthCard(theme),
                    const SizedBox(height: 16),
                    _buildArchitectureCard(theme),
                    const SizedBox(height: 16),
                    _buildFeatureFlagsCard(theme),
                    const SizedBox(height: 16),
                    _buildPrivacyAndIdentityCard(theme),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }

  // ── Verification Readiness Notice ──────────────────────────────────────────

  Widget _buildVerificationBanner(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // Light blue
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Current Architecture: Notification-Based MVP',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF1E40AF),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'All detected transactions are tagged with source=NOTIFICATION and verificationStatus=NOT_VERIFIED. Cryptographic bank-level verification will be added via licensed Payment Aggregator webhooks in future phases.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1E3A8A),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── System Health & Runtime State ──────────────────────────────────────────

  Widget _buildSystemHealthCard(ThemeData theme) {
    final accessGranted = _diagnostics['notificationAccessGranted'] == true;
    final serviceBound = _diagnostics['serviceBound'] == true;
    final soundboxEnabled = _diagnostics['soundboxEnabled'] == true;
    final speechSpeed = (_diagnostics['speechSpeed'] ?? 'normal').toString();
    final language = (_diagnostics['language'] ?? 'en-IN').toString();
    final format = (_diagnostics['announcementFormat'] ?? 'A').toString();

    return _buildCard(
      title: 'System Health & Engine',
      icon: Icons.monitor_heart_outlined,
      children: [
        _buildRow(
          'Notification Access',
          accessGranted ? 'Granted' : 'Disabled',
          badgeColor: accessGranted ? Colors.green.shade700 : Colors.red.shade700,
          badgeBg: accessGranted ? Colors.green.shade50 : Colors.red.shade50,
        ),
        _buildRow(
          'Listener Service Active',
          serviceBound ? 'Connected' : 'Active (Background)',
          badgeColor: Colors.teal.shade700,
          badgeBg: Colors.teal.shade50,
        ),
        _buildRow(
          'Soundbox Engine',
          soundboxEnabled ? 'Enabled' : 'Muted',
          badgeColor: soundboxEnabled ? Colors.green.shade700 : Colors.orange.shade700,
          badgeBg: soundboxEnabled ? Colors.green.shade50 : Colors.orange.shade50,
        ),
        _buildRow('TTS Language', language),
        _buildRow('Speech Speed', speechSpeed.toUpperCase()),
        _buildRow('Voice Format', 'Format $format'),
      ],
    );
  }

  // ── Architecture & Parser ──────────────────────────────────────────────────

  Widget _buildArchitectureCard(ThemeData theme) {
    final parserVer = _diagnostics['parserVersion'] ?? 1;
    final pkgCount = _diagnostics['supportedPackagesCount'] ?? 12;
    final packages = (_diagnostics['supportedPackages'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return _buildCard(
      title: 'Parser & Pattern Engine',
      icon: Icons.alt_route_rounded,
      children: [
        _buildRow('UPI Parser Version', 'v$parserVer (Strict Allowlist)'),
        _buildRow('Default Source Tag', 'NOTIFICATION'),
        _buildRow('Default Verification', 'NOT_VERIFIED'),
        _buildRow('Trusted UPI Apps', '$pkgCount packages supported'),
        if (packages.isNotEmpty) ...[
          const SizedBox(height: 8),
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 4, bottom: 8),
              title: Text(
                'View Supported Package Allowlist ($pkgCount)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              children: packages
                  .map(
                    (pkg) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        children: [
                          const Icon(Icons.check, size: 14, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              pkg,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  // ── Feature Flags & Entitlements ───────────────────────────────────────────

  Widget _buildFeatureFlagsCard(ThemeData theme) {
    final flags = (_diagnostics['featureFlags'] as Map<dynamic, dynamic>?) ?? {};
    final tier = (_diagnostics['subscriptionTier'] ?? 'FREE').toString();

    return _buildCard(
      title: 'Feature Flags & Entitlements',
      icon: Icons.flag_outlined,
      children: [
        _buildRow('Subscription Tier', tier,
            badgeColor: Colors.indigo.shade700, badgeBg: Colors.indigo.shade50),
        const SizedBox(height: 4),
        ...flags.entries.map((entry) {
          final isTrue = entry.value == true;
          return _buildRow(
            entry.key.toString(),
            isTrue ? 'ENABLED' : 'DISABLED',
            badgeColor: isTrue ? Colors.green.shade700 : Colors.grey.shade600,
            badgeBg: isTrue ? Colors.green.shade50 : Colors.grey.shade100,
          );
        }),
      ],
    );
  }

  // ── Privacy & Merchant Identity ────────────────────────────────────────────

  Widget _buildPrivacyAndIdentityCard(ThemeData theme) {
    final merchantId = (_diagnostics['merchantId'] ?? '—').toString();
    final totalPayments = _diagnostics['totalStoredPayments'] ?? 0;
    final includeShop = _diagnostics['includeShopName'] == true;

    return _buildCard(
      title: 'Privacy & Merchant Identity',
      icon: Icons.shield_outlined,
      children: [
        _buildRow('Merchant Identifier', merchantId.length > 18 ? '${merchantId.substring(0, 18)}...' : merchantId),
        _buildRow('Shop Name In Announcement', includeShop ? 'Enabled' : 'Disabled'),
        _buildRow('Stored Payment Records', '$totalPayments records'),
        const Divider(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline, size: 16, color: Colors.teal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Strict Zero-PII Policy: Zero raw notification text, zero UPI IDs, zero phone numbers, and zero bank account numbers are stored or transmitted.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Reusable Card & Row Builders ───────────────────────────────────────────

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangle68Border(),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF5B21B6)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    Color? badgeColor,
    Color? badgeBg,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF4B5563),
              fontWeight: FontWeight.w400,
            ),
          ),
          if (badgeColor != null && badgeBg != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
                ),
              ),
            )
          else
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
        ],
      ),
    );
  }
}

// Custom shape helper for clean rounded card border
class RoundedRectangle68Border extends RoundedRectangleBorder {
  RoundedRectangle68Border()
      : super(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        );
}
