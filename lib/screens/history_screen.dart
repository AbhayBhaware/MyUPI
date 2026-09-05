// lib/screens/history_screen.dart
//
// Payment History screen — reads from Kotlin SharedPreferences via MethodChannel.
// No payment processing happens here. Display only.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_channels.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  List<PaymentRecord> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    try {
      final raw = await kMethodChannel.invokeMethod<List<dynamic>>('getPaymentHistory') ?? [];
      final recs = raw
          .whereType<Map>()
          .map((m) => PaymentRecord(
                amount:    (m['amount']  as String?) ?? '',
                appName:   (m['appName'] as String?) ?? '',
                trustLevel: (m['trustLevel'] as String?) ?? 'HIGH',
                timestamp: DateTime.fromMillisecondsSinceEpoch(
                    (m['timestampMs'] as int?) ?? 0),
              ))
          .where((r) => r.amount.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() { _history = recs; _loading = false; });
    } on PlatformException catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Payment History'),
        content: const Text(
            'Are you sure you want to delete all payment history?\n\n'
            'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await kMethodChannel.invokeMethod('clearPaymentHistory');
      if (!mounted) return;
      setState(() => _history = []);
    } on PlatformException catch (_) {}
  }

  // ── Computed ─────────────────────────────────────────────────────────────

  List<PaymentRecord> get _todayRecs {
    final t = DateTime.now();
    final today = DateTime(t.year, t.month, t.day);
    return _history.where((r) {
      final d = DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day);
      return d == today;
    }).toList();
  }

  double get _todayTotal => _todayRecs.fold(
      0, (s, r) => s + (double.tryParse(r.amount.replaceAll(',', '')) ?? 0));

  String get _todayTotalFmt {
    final t = _todayTotal;
    if (t == t.truncateToDouble()) {
      return '₹${t.toInt().toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    }
    return '₹${t.toStringAsFixed(2)}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _loadHistory),
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear history',
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: _history.isEmpty
                  ? _buildEmpty()
                  : CustomScrollView(
                      slivers: [
                        // ── Today's mini-summary ──────────────────────────
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: _buildSummaryBar(cs),
                          ),
                        ),

                        // ── History list ──────────────────────────────────
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) => _HistoryTile(record: _history[i]),
                              childCount: _history.length,
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(
                            child: SizedBox(height: 24)),
                      ],
                    ),
            ),
    );
  }

  Widget _buildSummaryBar(ColorScheme cs) {
    final today = _todayRecs;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Today's Total",
                style: TextStyle(
                    fontSize: 12, color: cs.onPrimaryContainer.withAlpha(180))),
            const SizedBox(height: 2),
            Text(
              today.isEmpty ? '₹0' : _todayTotalFmt,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: cs.onPrimaryContainer),
            ),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('Payments',
              style: TextStyle(
                  fontSize: 12, color: cs.onPrimaryContainer.withAlpha(180))),
          const SizedBox(height: 2),
          Text(
            '${today.length}',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: cs.onPrimaryContainer),
          ),
        ]),
      ]),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(children: [
            Icon(Icons.receipt_long_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No payment history yet.',
                style: TextStyle(
                    fontSize: 16, color: Colors.grey.shade500)),
            const SizedBox(height: 6),
            Text(
              'Incoming UPI payments will appear here.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ]),
        ),
      ],
    );
  }
}

// ─── History tile ─────────────────────────────────────────────────────────────

class _HistoryTile extends StatelessWidget {
  final PaymentRecord record;
  const _HistoryTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.green.withAlpha(30),
            child: const Icon(Icons.currency_rupee,
                color: Colors.green, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                children: [
                  Text(
                    record.displayAmount,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (record.trustLevel == 'MEDIUM') ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(40),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 12, color: Colors.amber.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'MEDIUM TRUST',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (record.trustLevel == 'HIGH') ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 12, color: Colors.green.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'HIGH TRUST',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(record.appName,
                  style: TextStyle(
                      fontSize: 13, color: cs.onSurface.withAlpha(170))),
            ]),
          ),
          Text(
            record.timeLabel,
            style: TextStyle(
                fontSize: 12, color: cs.onSurface.withAlpha(130)),
            textAlign: TextAlign.right,
          ),
        ]),
      ),
    );
  }
}
