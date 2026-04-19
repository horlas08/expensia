import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:animated_emoji/animated_emoji.dart';
import 'package:animations/animations.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/services/database_service.dart';
import '../../../../features/transactions/presentation/widgets/add_transaction_sheet.dart';
import '../../../../core/services/shared_preferences_service.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../transactions/presentation/widgets/transaction_type_sheet.dart';
import '../../../wallet/presentation/providers/wallet_provider.dart';
import '../providers/dashboard_provider.dart';
import '../../../../core/constants/category_icons.dart';
import '../../../../features/transactions/presentation/pages/transactions_page.dart';
import '../../../../features/profile/presentation/pages/notification_settings_page.dart';
import '../../../../core/utils/transaction_grouper.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import '../widgets/debts_summary_sheet.dart';
import '../widgets/installments_summary_sheet.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  bool _balanceVisible = true;
  String _userName = '...';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferencesService.getInstance();
    setState(() {
      _userName = prefs.getUserName() ?? 'profile.user_badge'.tr();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalBalance = ref.watch(totalBalanceProvider);
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final transactionsAsync = ref.watch(recentTransactionsProvider);

    // Use global currency provider — static symbol, never translated
    final currencySymbol = ref.watch(currencySymbolProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'dashboard.welcome'.tr(),
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(width: 4),
                const AnimatedEmoji(AnimatedEmojis.wave, size: 16),
              ],
            ),
            Text(
              _userName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          Stack(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.notifications_none_rounded,
                    color: cs.onSurface,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationSettingsPage(),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                right: 12,
                top: 14,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── MAIN BALANCE CARD ──────────────────────────────────────────
            FadeInDown(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, Colors.deepPurple.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withOpacity(0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'dashboard.total_balance'.tr(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                        GestureDetector(
                          onTap:
                              () => setState(
                                () => _balanceVisible = !_balanceVisible,
                              ),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: Icon(
                                _balanceVisible
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                key: ValueKey(_balanceVisible),
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _balanceVisible
                            ? '$currencySymbol${totalBalance.toStringAsFixed(2)}'
                            : '••••••',
                        key: ValueKey(_balanceVisible),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    metricsAsync.when(
                      data:
                          (metrics) => Row(
                            children: [
                              Expanded(
                                child: _MiniBalanceStat(
                                  label: 'dashboard.income'.tr(),
                                  value: (metrics['monthly_income'] as num? ?? 0).toStringAsFixed(2),
                                  icon: Icons.arrow_downward_rounded,
                                  color: const Color(0xFF69F0AE),
                                  visible: _balanceVisible,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 36,
                                color: Colors.white.withOpacity(0.2),
                              ),
                              Expanded(
                                child: _MiniBalanceStat(
                                  label: 'dashboard.expenses'.tr(),
                                  value: (metrics['monthly_expense'] as num? ?? 0).toStringAsFixed(2),
                                  icon: Icons.arrow_upward_rounded,
                                  color: const Color(0xFFFF6E6E),
                                  visible: _balanceVisible,
                                ),
                              ),
                            ],
                          ),
                      loading:
                          () => const Center(child: LinearProgressIndicator()),
                      error: (e, _) => Text('common.error_prefix'.tr(args: ['$e'])),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── 4 UNIQUE ANIMATED SUMMARY CARDS ───────────────────────────
            metricsAsync.when(
              data:
                  (metrics) => Column(
                    children: [
                      // Row(
                      //   children: [
                      //     Expanded(
                      //       child: FadeInLeft(
                      //         delay: const Duration(milliseconds: 100),
                      //         child: _GlowingMetricCard(
                      //           label: 'dashboard.income'.tr(),
                      //           amount: '$currencySymbol${metrics['monthly_income']}',
                      //           gradient: const [Color(0xFF1A1A2E), Color(0xFF23233E)],
                      //           icon: Icons.south_west_rounded,
                      //           trend: '+12%',
                      //           trendUp: true,
                      //         ),
                      //       ),
                      //     ),
                      //     const SizedBox(width: 12),
                      //     Expanded(
                      //       child: FadeInRight(
                      //         delay: const Duration(milliseconds: 100),
                      //         child: _GlowingMetricCard(
                      //           label: 'dashboard.expenses'.tr(),
                      //           amount: '$currencySymbol${metrics['monthly_expense']}',
                      //           gradient: const [Color(0xFFFF1744), Color(0xFFFF6D00)],
                      //           icon: Icons.north_east_rounded,
                      //           trend: '-5%',
                      //           trendUp: false,
                      //         ),
                      //       ),
                      //     ),
                      //   ],
                      // ),
                      // const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FadeInLeft(
                              delay: const Duration(milliseconds: 200),
                              child: _FlipMetricCard(
                                label: 'dashboard.installment'.tr(),
                                amount:
                                    '${(metrics['installment_on_you'] ?? 0.0) + (metrics['installment_for_you'] ?? 0.0)}',
                                onYouAmount:
                                    '${metrics['installment_on_you'] ?? 0.0}',
                                forYouAmount:
                                    '${metrics['installment_for_you'] ?? 0.0}',
                                accentColor: const Color(0xFFAA00FF),
                                gradient: const [
                                  Color(0xFF8E24AA),
                                  Color(0xFFAB47BC),
                                ],
                                onDetails:
                                    () => _showInstallmentsSheet(
                                      context,
                                      currencySymbol,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FadeInRight(
                              delay: const Duration(milliseconds: 200),
                              child: _FlipMetricCard(
                                label: 'dashboard.debt'.tr(),
                                amount:
                                    '${metrics['debt_on_you'] + metrics['debt_for_you']}', //$currencySymbol
                                onYouAmount: '${metrics['debt_on_you']}',
                                forYouAmount: '${metrics['debt_for_you']}',
                                accentColor: const Color(0xFF0091EA),
                                gradient: const [
                                  Color(0xFF01579B),
                                  Color(0xFF0288D1),
                                ],
                                onDetails:
                                    () => _showDebtsSheet(
                                      context,
                                      currencySymbol,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              loading: () => const SizedBox(height: 200),
              error: (e, _) => const SizedBox(),
            ),

            const SizedBox(height: 32),

            // ── RECENT TRANSACTIONS ────────────────────────────────────────
            FadeInUp(
              delay: const Duration(milliseconds: 300),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'dashboard.recent_transactions'.tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TransactionsPage(),
                          ),
                        ),
                    child: Text(
                      '${'dashboard.view_all'.tr()} ›',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            transactionsAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) return const SizedBox();
                final grouped = groupTransactionsByDate(transactions, context);
                return Column(
                  children:
                      grouped.entries.map((entry) {
                        double income = 0;
                        double expense = 0;
                        for (var tx in entry.value) {
                          if (tx['direction'] == 'plus') {
                            income += (tx['amount'] as num?)?.toDouble() ?? 0.0;
                          } else if (tx['direction'] == 'min') {
                            expense +=
                                (tx['amount'] as num?)?.toDouble() ?? 0.0;
                          }
                        }
                        return FadeInUp(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8.0,
                                  bottom: 16.0,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cs.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        entry.key,
                                        style: TextStyle(
                                          color: cs.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Divider(
                                        color: cs.outlineVariant.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    if (income > 0) ...[
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.arrow_downward_rounded,
                                        color: Colors.green,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        income
                                            .toStringAsFixed(1)
                                            .replaceAll(RegExp(r'\.0$'), ''),
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                    if (expense > 0) ...[
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.arrow_upward_rounded,
                                        color: Colors.red,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        expense
                                            .toStringAsFixed(1)
                                            .replaceAll(RegExp(r'\.0$'), ''),
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              ...entry.value.map((tx) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: TransactionListItem(tx: tx),
                                );
                              }),
                            ],
                          ),
                        );
                      }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('common.error_prefix'.tr(args: ['$e'])),
            ),
          ],
        ),
      ),
    );
  }

  void _showDebtsSheet(BuildContext context, String sym) {
    Navigator.push(
      context,
      ModalSheetRoute(
        builder: (context) => DebtsSummarySheet(currencySymbol: sym),
      ),
    );
  }

  void _showInstallmentsSheet(BuildContext context, String sym) {
    Navigator.push(
      context,
      ModalSheetRoute(
        builder: (context) => InstallmentsSummarySheet(currencySymbol: sym),
      ),
    );
  }
}

class _MiniBalanceStat extends StatelessWidget {
  const _MiniBalanceStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.visible,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  visible ? value : '•••',
                  key: ValueKey(visible),
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlowingMetricCard extends StatelessWidget {
  const _GlowingMetricCard({
    required this.label,
    required this.amount,
    required this.gradient,
    required this.icon,
    required this.trend,
    required this.trendUp,
  });

  final String label;
  final String amount;
  final List<Color> gradient;
  final IconData icon;
  final String trend;
  final bool trendUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  trend,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlipMetricCard extends StatefulWidget {
  const _FlipMetricCard({
    required this.label,
    required this.amount,
    required this.onYouAmount,
    required this.forYouAmount,
    required this.accentColor,
    this.gradient,
    this.onDetails,
  });

  final String label;
  final String amount;
  final String onYouAmount;
  final String forYouAmount;
  final Color accentColor;
  final List<Color>? gradient;
  final VoidCallback? onDetails;

  @override
  State<_FlipMetricCard> createState() => _FlipMetricCardState();
}

class _FlipMetricCardState extends State<_FlipMetricCard>
    with SingleTickerProviderStateMixin {
  bool _showOnYou = true;
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _ctrl.value = 1.0;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() async {
    await _ctrl.reverse();
    setState(() => _showOnYou = !_showOnYou);
    _ctrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final labelText =
        _showOnYou ? 'dashboard.on_you'.tr() : 'dashboard.for_you'.tr();
    final displayAmount = _showOnYou ? widget.onYouAmount : widget.forYouAmount;
    final usesGradient = widget.gradient != null;
    final contentColor = usesGradient ? Colors.white : widget.accentColor;

    return GestureDetector(
      onTap: widget.onDetails ?? _toggle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient:
              usesGradient
                  ? LinearGradient(
                    colors: widget.gradient!,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                  : null,
          color: usesGradient ? null : widget.accentColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border:
              usesGradient
                  ? null
                  : Border.all(color: widget.accentColor.withOpacity(0.2)),
          boxShadow:
              usesGradient
                  ? [
                    BoxShadow(
                      color: widget.gradient![0].withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: contentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: IconButton(
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: _toggle,
                    icon: Icon(
                      Icons.swap_horiz_rounded,
                      color: contentColor,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              child: FadeTransition(
                opacity: _fade,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayAmount,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: contentColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            usesGradient
                                ? Colors.white.withOpacity(0.2)
                                : widget.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        labelText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: contentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
