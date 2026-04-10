import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:fl_chart/fl_chart.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> with SingleTickerProviderStateMixin {
  int _selectedPeriod = 1; // 0=week, 1=month, 2=year
  int _touchedIndex = -1;
  late AnimationController _progressCtrl;
  late Animation<double> _progressAnim;

  final _periods = ['Week', 'Month', 'Year'];

  // Monthly spending data by category
  final _categories = [
    _SpendCategory('Food', 850, const Color(0xFFFF6B6B)),
    _SpendCategory('Transport', 320, const Color(0xFF4ECDC4)),
    _SpendCategory('Shopping', 580, const Color(0xFFA29BFE)),
    _SpendCategory('Bills', 410, const Color(0xFFFDCB6E)),
    _SpendCategory('Health', 190, const Color(0xFF6C5CE7)),
  ];

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _progressAnim = CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOutCubic);
    _progressCtrl.forward();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    super.dispose();
  }

  // Spending data per period
  List<double> get _incomeData {
    if (_selectedPeriod == 0) return [320, 440, 280, 510, 390, 460, 420];
    if (_selectedPeriod == 1) return [3200, 4400, 2800, 5100, 3900, 4600];
    return [38000, 42000, 35000, 48000, 44000, 51000, 47000, 43000, 50000, 46000, 52000, 55000];
  }

  List<double> get _expenseData {
    if (_selectedPeriod == 0) return [180, 260, 150, 310, 220, 290, 240];
    if (_selectedPeriod == 1) return [1800, 2600, 1500, 3100, 2200, 2900];
    return [22000, 28000, 19000, 33000, 27000, 31000, 29000, 25000, 32000, 28000, 35000, 38000];
  }

  List<String> get _xLabels {
    if (_selectedPeriod == 0) return ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    if (_selectedPeriod == 1) return ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
    return ['J','F','M','A','M','J','J','A','S','O','N','D'];
  }

  double get _maxY {
    final max = [..._incomeData, ..._expenseData].reduce(math.max);
    return (max * 1.25).ceilToDouble();
  }

  double get _totalSpent => _categories.fold(0, (s, c) => s + c.amount);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
            title: const Text('Analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
                padding: const EdgeInsets.fromLTRB(24, 90, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text(
                      'Analytics',
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your financial overview',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
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
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: List.generate(_periods.length, (i) {
                          final selected = i == _selectedPeriod;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedPeriod = i);
                                _progressCtrl.reset();
                                _progressCtrl.forward();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: selected ? cs.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: selected
                                      ? [BoxShadow(color: cs.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
                                      : null,
                                ),
                                child: Text(
                                  _periods[i],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: selected ? Colors.white : cs.onSurfaceVariant,
                                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
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

                  // ── INCOME VS EXPENSE LINE CHART ───────────────────────────
                  FadeInUp(
                    delay: const Duration(milliseconds: 100),
                    child: _ChartCard(
                      title: 'Income vs Expense',
                      subtitle: 'Tap bars to inspect',
                      child: SizedBox(
                        height: 200, // Explicit height for the Bar Chart
                        child: AnimatedBuilder(
                          animation: _progressAnim,
                          builder: (_, __) => BarChart(
                            BarChartData(
                              maxY: _maxY,
                              alignment: BarChartAlignment.spaceAround,
                              barTouchData: BarTouchData(
                                enabled: true,
                                touchCallback: (event, response) {
                                  setState(() {
                                    if (response?.spot?.touchedBarGroupIndex != null) {
                                      _touchedIndex = response!.spot!.touchedBarGroupIndex;
                                    } else {
                                      _touchedIndex = -1;
                                    }
                                  });
                                },
                                touchTooltipData: BarTouchTooltipData(
                                  getTooltipColor: (_) => Colors.black87,
                                  tooltipRoundedRadius: 8,
                                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                    return BarTooltipItem(
                                      rodIndex == 0 ? 'Inc\n' : 'Exp\n',
                                      const TextStyle(color: Colors.white70, fontSize: 10),
                                      children: [
                                        TextSpan(
                                          text: '\$${rod.toY.toStringAsFixed(0)}',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
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
                                    getTitlesWidget: (val, meta) {
                                      final labels = _xLabels;
                                      final i = val.toInt();
                                      if (i >= labels.length) return const SizedBox();
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(labels[i], style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (_) => FlLine(
                                  color: cs.outlineVariant.withValues(alpha: 0.2),
                                  strokeWidth: 1,
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              barGroups: List.generate(_incomeData.length, (i) {
                                final isTouched = i == _touchedIndex;
                                return BarChartGroupData(
                                  x: i,
                                  groupVertically: false,
                                  barsSpace: 4,
                                  barRods: [
                                    BarChartRodData(
                                      toY: _incomeData[i] * _progressAnim.value,
                                      gradient: LinearGradient(
                                        colors: [const Color(0xFF00C853), const Color(0xFF64DD17)],
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                      ),
                                      width: isTouched ? 14 : 10,
                                      borderRadius: BorderRadius.circular(6),
                                      rodStackItems: [],
                                    ),
                                    BarChartRodData(
                                      toY: _expenseData[i] * _progressAnim.value,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFFF1744), Color(0xFFFF6D00)],
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                      ),
                                      width: isTouched ? 14 : 10,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── CHART LEGEND ───────────────────────────────────────────
                  FadeInUp(
                    delay: const Duration(milliseconds: 150),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _LegendDot(color: const Color(0xFF00C853), label: 'Income'),
                          const SizedBox(width: 24),
                          _LegendDot(color: const Color(0xFFFF1744), label: 'Expense'),
                        ],
                      ),
                    ),
                  ),

                  // ── SPENDING BY CATEGORY (DONUT + LIST) ───────────────────
                  FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    child: _ChartCard(
                      title: 'Spending Breakdown',
                      subtitle: 'This ${_periods[_selectedPeriod].toLowerCase()}',
                      child: Column(
                        children: [
                          SizedBox(
                            height: 180,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                PieChart(
                                  PieChartData(
                                    sections: List.generate(_categories.length, (i) {
                                      final cat = _categories[i];
                                      final isTouched = i == _touchedIndex - 100;
                                      return PieChartSectionData(
                                        value: cat.amount,
                                        color: cat.color,
                                        radius: isTouched ? 55 : 48,
                                        title: '',
                                        borderSide: BorderSide.none,
                                      );
                                    }),
                                    centerSpaceRadius: 52,
                                    sectionsSpace: 3,
                                    pieTouchData: PieTouchData(
                                      touchCallback: (event, response) {
                                        setState(() {
                                          _touchedIndex = (response?.touchedSection?.touchedSectionIndex ?? -1) + 100;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Total', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    Text(
                                      '\$${_totalSpent.toStringAsFixed(0)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._categories.map((cat) {
                            final pct = cat.amount / _totalSpent;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(color: cat.color, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(cat.name, style: const TextStyle(fontSize: 13))),
                                      Text(
                                        '\$${cat.amount.toStringAsFixed(0)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${(pct * 100).toStringAsFixed(0)}%',
                                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  AnimatedBuilder(
                                    animation: _progressAnim,
                                    builder: (_, __) => ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: pct * _progressAnim.value,
                                        backgroundColor: cat.color.withValues(alpha: 0.1),
                                        valueColor: AlwaysStoppedAnimation(cat.color),
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

                  // ── INSTALLMENT & DEBT SUMMARY ROWS ───────────────────────
                  FadeInUp(
                    delay: const Duration(milliseconds: 300),
                    child: Row(
                      children: [
                        Expanded(
                          child: _MiniStatCard(
                            label: 'Installment',
                            amount: '\$500',
                            icon: Icons.calendar_today_outlined,
                            color: const Color(0xFFAA00FF),
                            sub: '3 active',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MiniStatCard(
                            label: 'Debt',
                            amount: '\$200',
                            icon: Icons.account_balance_outlined,
                            color: const Color(0xFF0091EA),
                            sub: '2 owed',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
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

class _SpendCategory {
  final String name;
  final double amount;
  final Color color;
  const _SpendCategory(this.name, this.amount, this.color);
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.subtitle, required this.child});
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
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
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
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
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
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
              Text(amount, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
              Text(sub, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
