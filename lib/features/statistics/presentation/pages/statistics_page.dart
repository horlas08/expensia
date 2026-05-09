import 'dart:math' as math;
import 'package:blur/blur.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/config/premium_config.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../core/services/subscription_service.dart';
import '../../../profile/presentation/widgets/subscription_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────────────

class _SpendCategory {
  final String name;
  final double amount;
  final Color color;
  const _SpendCategory(this.name, this.amount, this.color);
}

class _StatsData {
  final List<double> income;
  final List<double> expense;
  final List<String> labels;
  final List<_SpendCategory> categories;
  final double installmentTotal;
  final int activeInstallments;
  final double debtTotal;
  final int activeDebts;

  const _StatsData({
    required this.income,
    required this.expense,
    required this.labels,
    required this.categories,
    required this.installmentTotal,
    required this.activeInstallments,
    required this.debtTotal,
    required this.activeDebts,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

// 0=week, 1=month, 2=year
final _statsPeriodProvider = StateProvider<int>((ref) => 1);

final statisticsDataProvider = FutureProvider.autoDispose
    .family<_StatsData, int>((ref, period) async {
      final db = DatabaseService();
      final rawDb = await db.database;
      final now = DateTime.now();

      // ── Date ranges per period ──
      final List<DateTime> starts;
      final List<String> labels;

      if (period == 0) {
        // Last 7 days
        labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final monday = now.subtract(Duration(days: (now.weekday - 1) % 7));
        starts = List.generate(
          7,
          (i) => DateTime(monday.year, monday.month, monday.day + i),
        );
      } else if (period == 1) {
        // Last 6 months
        starts = List.generate(6, (i) {
          final m = DateTime(now.year, now.month - 5 + i, 1);
          return DateTime(m.year, m.month, 1);
        });
        labels = starts.map((d) => DateFormat('MMM').format(d)).toList();
      } else {
        // All 12 months of current year
        starts = List.generate(12, (i) => DateTime(now.year, i + 1, 1));
        labels = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
      }

      // ── Income & Expense per period bucket ──
      final income = <double>[];
      final expense = <double>[];

      for (int i = 0; i < starts.length; i++) {
        final from = starts[i];
        final DateTime to;
        if (period == 0) {
          to = DateTime(from.year, from.month, from.day, 23, 59, 59);
        } else if (period == 1) {
          to = DateTime(from.year, from.month + 1, 0, 23, 59, 59);
        } else {
          to = DateTime(from.year, from.month + 1, 0, 23, 59, 59);
        }

        final incRes = await rawDb.rawQuery(
          '''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE type = 'income' AND date >= ? AND date <= ?
    ''',
          [from.toIso8601String(), to.toIso8601String()],
        );

        final expRes = await rawDb.rawQuery(
          '''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE type = 'expense' AND date >= ? AND date <= ?
    ''',
          [from.toIso8601String(), to.toIso8601String()],
        );

        income.add((incRes.first['total'] as num?)?.toDouble() ?? 0);
        expense.add((expRes.first['total'] as num?)?.toDouble() ?? 0);
      }

      // ── Spending Breakdown by Category (within selected period) ──
      final DateTime periodStart;
      if (period == 0) {
        final monday = now.subtract(Duration(days: (now.weekday - 1) % 7));
        periodStart = DateTime(monday.year, monday.month, monday.day);
      } else if (period == 1) {
        periodStart = starts.first;
      } else {
        periodStart = DateTime(now.year, 1, 1);
      }

      final catColors = [
        const Color(0xFFFF6B6B),
        const Color(0xFF4ECDC4),
        const Color(0xFFA29BFE),
        const Color(0xFFFDCB6E),
        const Color(0xFF6C5CE7),
        const Color(0xFF00CEC9),
        const Color(0xFFE17055),
        const Color(0xFF74B9FF),
      ];

      final catRes = await rawDb.rawQuery(
        '''
    SELECT c.name_en as name, COALESCE(SUM(t.amount), 0) as total
    FROM transactions t
    LEFT JOIN categories c ON t.category_id = c.id
    WHERE t.type = 'expense' AND t.date >= ?
    GROUP BY t.category_id
    ORDER BY total DESC
    LIMIT 8
  ''',
        [periodStart.toIso8601String()],
      );

      final categories =
          catRes
              .asMap()
              .entries
              .map((e) {
                final row = e.value;
                return _SpendCategory(
                  row['name'] as String? ?? 'wallet.other'.tr(),
                  (row['total'] as num).toDouble(),
                  catColors[e.key % catColors.length],
                );
              })
              .where((c) => c.amount > 0)
              .toList();

      // ── Installment Summary ──
      final instRes = await rawDb.rawQuery('''
    SELECT COALESCE(SUM(deposit), 0) as total, COUNT(*) as count
    FROM installments WHERE status = 'active'
  ''');
      final installmentTotal =
          (instRes.first['total'] as num?)?.toDouble() ?? 0;
      final activeInstallments = (instRes.first['count'] as num?)?.toInt() ?? 0;

      // ── Debt Summary ──
      final debtRes = await rawDb.rawQuery('''
    SELECT COALESCE(SUM(income + expense), 0) as total, COUNT(*) as count
    FROM debts WHERE status = 'active'
  ''');
      final debtTotal = (debtRes.first['total'] as num?)?.toDouble() ?? 0;
      final activeDebts = (debtRes.first['count'] as num?)?.toInt() ?? 0;

      return _StatsData(
        income: income,
        expense: expense,
        labels: labels,
        categories:
            categories.isEmpty
                ? [
                  _SpendCategory(
                    'stat.no_data',
                    1,
                    Colors.grey.withValues(alpha: 0.3),
                  ),
                ]
                : categories,
        installmentTotal: installmentTotal,
        activeInstallments: activeInstallments,
        debtTotal: debtTotal,
        activeDebts: activeDebts,
      );
    });

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key});

  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage>
    with SingleTickerProviderStateMixin {
  int _touchedIndex = -1;
  late AnimationController _progressCtrl;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progressAnim = CurvedAnimation(
      parent: _progressCtrl,
      curve: Curves.easeOutCubic,
    );
    _progressCtrl.forward();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    super.dispose();
  }

  void _changePeriod(int i) {
    ref.read(_statsPeriodProvider.notifier).state = i;
    _progressCtrl.reset();
    _progressCtrl.forward();
    setState(() => _touchedIndex = -1);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selectedPeriod = ref.watch(_statsPeriodProvider);
    final statsAsync = ref.watch(statisticsDataProvider(selectedPeriod));
    final currencySymbol = ref.watch(currencySymbolProvider);
    final isPro = ref.watch(isProProvider);
    final periods = [
      'stat.period_week'.tr(),
      'stat.period_month'.tr(),
      'stat.period_year'.tr(),
    ];

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          // ── HEADER ────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: cs.primary,
            foregroundColor: Colors.white,
            title: Text(
              'stat.title'.tr(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cs.primary, Colors.deepPurple],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'stat.title'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'stat.overview_desc'.tr(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── PERIOD SELECTOR ────────────────────────────────────────
                  FadeInDown(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: List.generate(periods.length, (i) {
                          final selected = i == selectedPeriod;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => _changePeriod(i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      selected
                                          ? cs.primary
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow:
                                      selected
                                          ? [
                                            BoxShadow(
                                              color: cs.primary.withValues(
                                                alpha: 0.3,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                          : null,
                                ),
                                child: Text(
                                  periods[i],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color:
                                        selected
                                            ? Colors.white
                                            : cs.onSurfaceVariant,
                                    fontWeight:
                                        selected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Builder(
                    builder: (context) {
                      final statsContent = statsAsync.when(
                        loading:
                            () => const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 80),
                                child: CircularProgressIndicator(),
                              ),
                            ),
                        error:
                            (err, _) => Center(
                              child: Text(
                                'common.error_prefix'.tr(args: ['$err']),
                              ),
                            ),
                        data: (stats) {
                          final maxY =
                              [...stats.income, ...stats.expense].isEmpty
                                  ? 100.0
                                  : ([
                                            ...stats.income,
                                            ...stats.expense,
                                          ].reduce(math.max) *
                                          1.25)
                                      .ceilToDouble();
                          final totalSpent = stats.categories.fold(
                            0.0,
                            (s, c) => s + c.amount,
                          );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── INCOME VS EXPENSE BAR CHART ──────────────────────
                              FadeInUp(
                                delay: const Duration(milliseconds: 100),
                                child: _ChartCard(
                                  title: 'stat.income_vs_expense'.tr(),
                                  subtitle: 'stat.tap_to_inspect'.tr(),
                                  child: SizedBox(
                                    height: 200,
                                    child: AnimatedBuilder(
                                      animation: _progressAnim,
                                      builder:
                                          (_, __) => BarChart(
                                            BarChartData(
                                              maxY: maxY,
                                              alignment:
                                                  BarChartAlignment.spaceAround,
                                              barTouchData: BarTouchData(
                                                enabled: true,
                                                touchCallback: (
                                                  event,
                                                  response,
                                                ) {
                                                  setState(() {
                                                    if (response
                                                            ?.spot
                                                            ?.touchedBarGroupIndex !=
                                                        null) {
                                                      _touchedIndex =
                                                          response!
                                                              .spot!
                                                              .touchedBarGroupIndex;
                                                    } else {
                                                      _touchedIndex = -1;
                                                    }
                                                  });
                                                },
                                                touchTooltipData: BarTouchTooltipData(
                                                  getTooltipColor:
                                                      (_) => Colors.black87,
                                                  tooltipRoundedRadius: 8,
                                                  getTooltipItem: (
                                                    group,
                                                    groupIndex,
                                                    rod,
                                                    rodIndex,
                                                  ) {
                                                    return BarTooltipItem(
                                                      '${rodIndex == 0 ? 'stat.income_short'.tr() : 'stat.expense_short'.tr()}\n',
                                                      const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 10,
                                                      ),
                                                      children: [
                                                        TextSpan(
                                                          text:
                                                              '$currencySymbol ${rod.toY.toStringAsFixed(0)}',
                                                          style:
                                                              const TextStyle(
                                                                color:
                                                                    Colors
                                                                        .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 12,
                                                              ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ),
                                              titlesData: FlTitlesData(
                                                bottomTitles: AxisTitles(
                                                  sideTitles: SideTitles(
                                                    showTitles: true,
                                                    getTitlesWidget: (
                                                      val,
                                                      meta,
                                                    ) {
                                                      final i = val.toInt();
                                                      if (i >=
                                                          stats.labels.length) {
                                                        return const SizedBox();
                                                      }
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              top: 6,
                                                            ),
                                                        child: Text(
                                                          stats.labels[i],
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color:
                                                                cs.onSurfaceVariant,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                                leftTitles: const AxisTitles(
                                                  sideTitles: SideTitles(
                                                    showTitles: false,
                                                  ),
                                                ),
                                                topTitles: const AxisTitles(
                                                  sideTitles: SideTitles(
                                                    showTitles: false,
                                                  ),
                                                ),
                                                rightTitles: const AxisTitles(
                                                  sideTitles: SideTitles(
                                                    showTitles: false,
                                                  ),
                                                ),
                                              ),
                                              gridData: FlGridData(
                                                show: true,
                                                drawVerticalLine: false,
                                                getDrawingHorizontalLine:
                                                    (_) => FlLine(
                                                      color: cs.outlineVariant
                                                          .withValues(
                                                            alpha: 0.2,
                                                          ),
                                                      strokeWidth: 1,
                                                    ),
                                              ),
                                              borderData: FlBorderData(
                                                show: false,
                                              ),
                                              barGroups: List.generate(
                                                stats.income.length,
                                                (i) {
                                                  final isTouched =
                                                      i == _touchedIndex;
                                                  return BarChartGroupData(
                                                    x: i,
                                                    groupVertically: false,
                                                    barsSpace: 4,
                                                    barRods: [
                                                      BarChartRodData(
                                                        toY:
                                                            stats.income[i] *
                                                            _progressAnim.value,
                                                        gradient:
                                                            const LinearGradient(
                                                              colors: [
                                                                Color(
                                                                  0xFF00C853,
                                                                ),
                                                                Color(
                                                                  0xFF64DD17,
                                                                ),
                                                              ],
                                                              begin:
                                                                  Alignment
                                                                      .bottomCenter,
                                                              end:
                                                                  Alignment
                                                                      .topCenter,
                                                            ),
                                                        width:
                                                            isTouched ? 14 : 10,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                        rodStackItems: [],
                                                      ),
                                                      BarChartRodData(
                                                        toY:
                                                            stats.expense[i] *
                                                            _progressAnim.value,
                                                        gradient:
                                                            const LinearGradient(
                                                              colors: [
                                                                Color(
                                                                  0xFFFF1744,
                                                                ),
                                                                Color(
                                                                  0xFFFF6D00,
                                                                ),
                                                              ],
                                                              begin:
                                                                  Alignment
                                                                      .bottomCenter,
                                                              end:
                                                                  Alignment
                                                                      .topCenter,
                                                            ),
                                                        width:
                                                            isTouched ? 14 : 10,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                    ),
                                  ),
                                ),
                              ),

                              // ── CHART LEGEND ──────────────────────────────────────
                              FadeInUp(
                                delay: const Duration(milliseconds: 150),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    4,
                                    12,
                                    4,
                                    24,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _LegendDot(
                                        color: const Color(0xFF00C853),
                                        label: 'stat.income'.tr(),
                                      ),
                                      const SizedBox(width: 24),
                                      _LegendDot(
                                        color: const Color(0xFFFF1744),
                                        label: 'stat.expense'.tr(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // ── SPENDING BY CATEGORY (DONUT + LIST) ──────────────
                              FadeInUp(
                                delay: const Duration(milliseconds: 200),
                                child: _ChartCard(
                                  title: 'stat.spending_breakdown'.tr(),
                                  subtitle: 'stat.this_period'.tr(
                                    args: [periods[selectedPeriod]],
                                  ),
                                  child:
                                      totalSpent == 0
                                          ? Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 32,
                                            ),
                                            child: Center(
                                              child: Text(
                                                'stat.no_expense_data'.tr(),
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                          )
                                          : Column(
                                            children: [
                                              SizedBox(
                                                height: 180,
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    PieChart(
                                                      PieChartData(
                                                        sections: List.generate(
                                                          stats
                                                              .categories
                                                              .length,
                                                          (i) {
                                                            final cat =
                                                                stats
                                                                    .categories[i];
                                                            final isTouched =
                                                                i ==
                                                                _touchedIndex -
                                                                    100;
                                                            return PieChartSectionData(
                                                              value: cat.amount,
                                                              color: cat.color,
                                                              radius:
                                                                  isTouched
                                                                      ? 55
                                                                      : 48,
                                                              title: '',
                                                              borderSide:
                                                                  BorderSide
                                                                      .none,
                                                            );
                                                          },
                                                        ),
                                                        centerSpaceRadius: 52,
                                                        sectionsSpace: 3,
                                                        pieTouchData: PieTouchData(
                                                          touchCallback: (
                                                            event,
                                                            response,
                                                          ) {
                                                            setState(() {
                                                              _touchedIndex =
                                                                  (response
                                                                          ?.touchedSection
                                                                          ?.touchedSectionIndex ??
                                                                      -1) +
                                                                  100;
                                                            });
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                    Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          'stat.total'.tr(),
                                                          style:
                                                              const TextStyle(
                                                                color:
                                                                    Colors.grey,
                                                                fontSize: 12,
                                                              ),
                                                        ),
                                                        Text(
                                                          '$currencySymbol ${totalSpent.toStringAsFixed(0)}',
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 18,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              ...stats.categories.map((cat) {
                                                final pct =
                                                    totalSpent > 0
                                                        ? cat.amount /
                                                            totalSpent
                                                        : 0.0;
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 10,
                                                      ),
                                                  child: Column(
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Container(
                                                            width: 10,
                                                            height: 10,
                                                            decoration:
                                                                BoxDecoration(
                                                                  color:
                                                                      cat.color,
                                                                  shape:
                                                                      BoxShape
                                                                          .circle,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              cat.name ==
                                                                      'stat.no_data'
                                                                  ? cat.name
                                                                      .tr()
                                                                  : cat.name,
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                            ),
                                                          ),
                                                          Text(
                                                            '$currencySymbol ${cat.amount.toStringAsFixed(0)}',
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 13,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Text(
                                                            '${(pct * 100).toStringAsFixed(0)}%',
                                                            style: TextStyle(
                                                              color:
                                                                  cs.onSurfaceVariant,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                      AnimatedBuilder(
                                                        animation:
                                                            _progressAnim,
                                                        builder:
                                                            (
                                                              _,
                                                              __,
                                                            ) => ClipRRect(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    4,
                                                                  ),
                                                              child: LinearProgressIndicator(
                                                                value:
                                                                    pct *
                                                                    _progressAnim
                                                                        .value,
                                                                backgroundColor: cat
                                                                    .color
                                                                    .withValues(
                                                                      alpha:
                                                                          0.1,
                                                                    ),
                                                                valueColor:
                                                                    AlwaysStoppedAnimation(
                                                                      cat.color,
                                                                    ),
                                                                minHeight: 6,
                                                              ),
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }),
                                            ],
                                          ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // ── INSTALLMENT & DEBT SUMMARY ROWS ──────────────────
                              FadeInUp(
                                delay: const Duration(milliseconds: 300),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _MiniStatCard(
                                        label: 'dashboard.installment'.tr(),
                                        amount:
                                            '$currencySymbol ${stats.installmentTotal.toStringAsFixed(0)}',
                                        icon: Icons.calendar_today_outlined,
                                        color: const Color(0xFFAA00FF),
                                        sub:
                                            '${stats.activeInstallments} ${'dashboard.active'.tr().toLowerCase()}',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _MiniStatCard(
                                        label: 'dashboard.debt'.tr(),
                                        amount:
                                            '$currencySymbol ${stats.debtTotal.toStringAsFixed(0)}',
                                        icon: Icons.account_balance_outlined,
                                        color: const Color(0xFF0091EA),
                                        sub:
                                            '${stats.activeDebts} ${'dashboard.active'.tr().toLowerCase()}',
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 32),
                            ],
                          );
                        },
                      );

                      final isLocked = PremiumConfig.isLocked(
                        feature: PremiumFeature.statistics,
                        isPro: isPro,
                      );
                      if (!isLocked) return statsContent;

                      return Blur(
                        blur: 12,
                        blurColor: cs.surface,
                        colorOpacity: 0.18,
                        borderRadius: BorderRadius.circular(28),
                        overlay: _StatisticsLockedOverlay(
                          onUpgrade: () => SubscriptionSheet.show(context),
                        ),
                        child: IgnorePointer(child: statsContent),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    required this.sub,
  });
  final String label;
  final String amount;
  final IconData icon;
  final Color color;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                amount,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                sub,
                style: TextStyle(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatisticsLockedOverlay extends StatelessWidget {
  const _StatisticsLockedOverlay({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(Icons.lock_rounded, color: cs.primary, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                'subscription.advanced_analytics'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'subscription.advanced_analytics_desc'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onUpgrade,
                icon: const Icon(Icons.workspace_premium_rounded),
                label: Text('profile.upgrade_premium'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
