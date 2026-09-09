// lib/screens/history_screen.dart
//
// Payment History screen — Modern Fintech Redesign
// ------------------------------------------------
// Shows:
//   • Grouped by Today, Yesterday, and older dates
//   • Newest payment first
//   • Today's total collection & count summary in a hero stat card
//   • Clear history with confirmation
//   • Merchant-friendly indicators
//   • Display only; no payment processing happens here

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_channels.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/empty_state.dart';
import '../widgets/payment_card.dart';
import '../widgets/premium_card.dart';
import '../widgets/section_header.dart';

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
                amount: (m['amount'] as String?) ?? '',
                appName: (m['appName'] as String?) ?? '',
                trustLevel: (m['trustLevel'] as String?) ?? 'HIGH',
                timestamp: DateTime.fromMillisecondsSinceEpoch(
                    (m['timestampMs'] as int?) ?? 0),
              ))
          .where((r) => r.amount.isNotEmpty)
          .toList();
      // Ensure newest first (descending by timestamp)
      recs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (!mounted) return;
      setState(() {
        _history = recs;
        _loading = false;
      });
    } on PlatformException catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _clearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
        title: const Text('Clear Payment History', style: AppTypography.titleMedium),
        content: const Text(
          'Are you sure you want to delete all payment history records?\n\nThis cannot be undone.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.bold)),
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

  String _dateGroupKey(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yest = today.subtract(const Duration(days: 1));
    final d = DateTime(dt.year, dt.month, dt.day);

    if (d == today) return 'Today';
    if (d == yest) return 'Yesterday';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dayStr = dt.day.toString().padLeft(2, '0');
    return '$dayStr ${months[dt.month - 1]} ${dt.year}';
  }

  Map<String, List<PaymentRecord>> get _groupedHistory {
    final map = <String, List<PaymentRecord>>{};
    for (final rec in _history) {
      final key = _dateGroupKey(rec.timestamp);
      map.putIfAbsent(key, () => []).add(rec);
    }
    return map;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final grouped = _groupedHistory;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payment History', style: AppTypography.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1, color: AppColors.borderLight),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            tooltip: 'Refresh',
            onPressed: _loadHistory,
          ),
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textSecondary),
              tooltip: 'Clear history',
              onPressed: _clearHistory,
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : RefreshIndicator(
              color: AppColors.primaryBlue,
              backgroundColor: AppColors.surface,
              onRefresh: _loadHistory,
              child: _history.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 80),
                        EmptyState(
                          icon: Icons.receipt_long_rounded,
                          title: 'No payment history yet',
                          subtitle: 'Incoming UPI payments will appear here.',
                        ),
                      ],
                    )
                  : CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // ── Today's summary bar ──────────────────────────
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.base,
                              AppSpacing.base,
                              AppSpacing.base,
                              AppSpacing.sm,
                            ),
                            child: _buildSummaryBar(),
                          ),
                        ),

                        // ── Grouped History sections ──────────────────────
                        for (final entry in grouped.entries) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.base,
                                AppSpacing.md,
                                AppSpacing.base,
                                AppSpacing.xs,
                              ),
                              child: SectionHeader(
                                title: entry.key,
                                badgeText: '${entry.value.length}',
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) => PaymentCard(record: entry.value[i]),
                                childCount: entry.value.length,
                              ),
                            ),
                          ),
                        ],

                        const SliverToBoxAdapter(
                          child: SizedBox(height: AppSpacing.xxl),
                        ),
                      ],
                    ),
            ),
    );
  }

  Widget _buildSummaryBar() {
    final today = _todayRecs;
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    const Text(
                      "Today's Total",
                      style: AppTypography.caption,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  today.isEmpty ? '₹0' : _todayTotalFmt,
                  style: AppTypography.currencyLarge.copyWith(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: AppRadius.mdRadius,
              border: Border.all(color: AppColors.borderLight, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Payments Today',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${today.length}',
                  style: AppTypography.statValue.copyWith(
                    fontSize: 20,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
