// lib/screens/history_screen.dart
//
// Payment History screen — Phase 2 Enhanced
// ------------------------------------------------
// Features:
//   • Grouped by Today, Yesterday, and older dates (newest first)
//   • Today's total collection & count summary in a hero stat card
//   • WhatsApp / Daily Reconciliation share button (totals only, no PII, Indian grouping)
//   • Sticky in-memory Search by amount / app name
//   • Source filter chips (All, Google Pay, PhonePe, Paytm, SMS)
//   • Zero-PII Transaction Detail sheet on card tap
//   • Audio-only "Play Test Announcement" empty state (never touches ledger)
//   • Repeat announcement on cards without ledger mutation

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../app_channels.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../tts_service.dart';
import '../utils/currency_formatter.dart';
import '../widgets/empty_state.dart';
import '../widgets/payment_card.dart';
import '../widgets/premium_card.dart';
import '../widgets/section_header.dart';
import '../widgets/transaction_detail_bottom_sheet.dart';

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

  // Search & Filter state (In-memory, local)
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';

  final List<String> _filters = const [
    'All',
    'Google Pay',
    'PhonePe',
    'Paytm',
    'SMS',
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                source: (m['source'] as String?) ?? 'NOTIFICATION',
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

  String get _todayTotalFmt => CurrencyFormatter.format(_todayTotal);

  List<PaymentRecord> get _filteredHistory {
    return _history.where((r) {
      // 1. Channel / App filter
      if (_selectedFilter != 'All') {
        if (_selectedFilter == 'SMS') {
          if (r.source != PaymentSource.sms && r.source != PaymentSource.both) {
            return false;
          }
        } else {
          final app = r.appName.toLowerCase();
          final target = _selectedFilter.toLowerCase();
          if (!app.contains(target)) return false;
        }
      }

      // 2. Query filter (amount or app)
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final amt = r.amount.toLowerCase();
        final app = r.appName.toLowerCase();
        if (!amt.contains(q) && !app.contains(q)) return false;
      }

      return true;
    }).toList();
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

  Map<String, List<PaymentRecord>> get _groupedFilteredHistory {
    final map = <String, List<PaymentRecord>>{};
    for (final rec in _filteredHistory) {
      final key = _dateGroupKey(rec.timestamp);
      map.putIfAbsent(key, () => []).add(rec);
    }
    return map;
  }

  // ── Share Daily Reconciliation (Correction 1.2 & 1.5: Zero PII, totals only) ──

  void _shareDailySummary() {
    final today = _todayRecs;
    if (today.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No transactions recorded today to share.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateStr = '${now.day} ${months[now.month - 1]} ${now.year}';

    // Per-app totals and counts
    final Map<String, (double, int)> appStats = {};
    for (final r in today) {
      final name = r.appName.isEmpty ? 'Other UPI' : r.appName;
      final amt = double.tryParse(r.amount.replaceAll(',', '')) ?? 0.0;
      final cur = appStats[name] ?? (0.0, 0);
      appStats[name] = (cur.$1 + amt, cur.$2 + 1);
    }

    final buffer = StringBuffer();
    buffer.writeln('📊 *MyUPI Daily Collection Summary*');
    buffer.writeln('📅 Date: $dateStr');
    buffer.writeln('💰 Total Collection: $_todayTotalFmt');
    buffer.writeln('🔢 Total Payments: ${today.length}');
    buffer.writeln('');
    buffer.writeln('📱 *App Breakdown:*');
    for (final entry in appStats.entries) {
      final subtotalFmt = CurrencyFormatter.format(entry.value.$1);
      final count = entry.value.$2;
      buffer.writeln('• ${entry.key}: $subtotalFmt ($count ${count == 1 ? "payment" : "payments"})');
    }
    buffer.writeln('');
    buffer.writeln('Generated securely via MyUPI Soundbox');

    // ignore: deprecated_member_use
    Share.share(
      buffer.toString(),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final grouped = _groupedFilteredHistory;

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
            icon: const Icon(Icons.share_outlined, color: AppColors.primaryBlue),
            tooltip: 'Share Daily Summary',
            onPressed: _shareDailySummary,
          ),
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
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.base,
                            AppSpacing.base,
                            AppSpacing.base,
                            AppSpacing.sm,
                          ),
                          child: _buildSummaryBar(),
                        ),
                        const SizedBox(height: 20),
                        EmptyState(
                          icon: Icons.receipt_long_rounded,
                          badgeText: 'SOUNDBOX READY',
                          title: 'No payment history yet',
                          subtitle: 'Tip: Scan your QR code on Home and make a ₹1 payment to test your soundbox in action.',
                          actionLabel: 'Play Test Announcement',
                          onAction: () {
                            TtsService.instance.speakTest();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Playing sample soundbox announcement...'),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
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

                        // ── Search & Filter Controls ──────────────────────
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                            child: Column(
                              children: [
                                _buildSearchBar(),
                                const SizedBox(height: 10),
                                _buildFilterChips(),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),

                        // ── Empty Filter Results ─────────────────────────
                        if (_filteredHistory.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                              child: Center(
                                child: Column(
                                  children: [
                                    const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textTertiary),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No matching payments found',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Try adjusting your search query or channel filter.',
                                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(height: 16),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _searchController.clear();
                                          _searchQuery = '';
                                          _selectedFilter = 'All';
                                        });
                                      },
                                      icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                                      label: const Text('Reset Filters'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          // ── Grouped History sections with per-day total ──────────────────────
                          for (final entry in grouped.entries) ...[
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.base,
                                  AppSpacing.md,
                                  AppSpacing.base,
                                  AppSpacing.xs,
                                ),
                                child: Builder(
                                  builder: (context) {
                                    final dayTotal = entry.value.fold<double>(
                                      0.0,
                                      (sum, rec) => sum + (double.tryParse(rec.amount.replaceAll(',', '')) ?? 0.0),
                                    );
                                    final dayTotalFmt = CurrencyFormatter.format(dayTotal);
                                    return SectionHeader(
                                      title: entry.key,
                                      badgeText: '$dayTotalFmt (${entry.value.length})',
                                    );
                                  },
                                ),
                              ),
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (ctx, i) {
                                    final record = entry.value[i];
                                    return PaymentCard(
                                      record: record,
                                      onTap: () => TransactionDetailBottomSheet.show(context, record),
                                      onRespeak: () {
                                        TtsService.instance.speakPayment(record.amount);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Re-announcing ${record.displayAmount}...'),
                                            duration: const Duration(seconds: 2),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
                                    );
                                  },
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

  // ── Search Bar ───────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search by amount or app...',
          hintStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  // ── Source Filter Chips ──────────────────────────────────────────────────

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                filter,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.primaryBlue,
              backgroundColor: AppColors.surface,
              side: BorderSide(
                color: isSelected ? AppColors.primaryBlue : AppColors.cardBorder,
                width: 1,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              showCheckmark: false,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedFilter = filter);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Summary Bar with Share button ────────────────────────────────────────

  Widget _buildSummaryBar() {
    final today = _todayRecs;
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.base),
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
                    const Expanded(
                      child: Text(
                        "Today's Collection",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    today.isEmpty ? '₹0' : _todayTotalFmt,
                    style: AppTypography.currencyLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: _shareDailySummary,
                borderRadius: AppRadius.mdRadius,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.lightBlue,
                    borderRadius: AppRadius.mdRadius,
                    border: Border.all(color: AppColors.softBlueBorder, width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.share_rounded, size: 13, color: AppColors.primaryBlue),
                      const SizedBox(width: 5),
                      Text(
                        '${today.length} ${today.length == 1 ? "payment" : "payments"}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
