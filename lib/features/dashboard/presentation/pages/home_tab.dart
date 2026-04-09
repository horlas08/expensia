import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:animated_emoji/animated_emoji.dart';
import 'package:animations/animations.dart';
import '../../../../features/transactions/presentation/widgets/add_transaction_sheet.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool _balanceVisible = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Welcome again',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(width: 4),
                const AnimatedEmoji(AnimatedEmojis.wave, size: 16),
              ],
            ),
            const Text(
              'John Doe',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          Stack(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.notifications_none_rounded,
                    color: cs.onSurface,
                  ),
                  onPressed: () {},
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
                      color: cs.primary.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── top row: label + hide toggle ───────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Balance',
                          style: TextStyle(
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
                              color: Colors.white.withValues(alpha: 0.15),
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

                    // ── balance amount ─────────────────────────────────────
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder:
                          (child, anim) => FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.15),
                                end: Offset.zero,
                              ).animate(anim),
                              child: child,
                            ),
                          ),
                      child: Text(
                        _balanceVisible ? '\$12,450.00' : '••••••',
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

                    // ── bottom row: income/expense mini stats ──────────────
                    Row(
                      children: [
                        Expanded(
                          child: _MiniBalanceStat(
                            label: 'Income',
                            value: '\$4,200',
                            icon: Icons.arrow_downward_rounded,
                            color: const Color(0xFF69F0AE),
                            visible: _balanceVisible,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        Expanded(
                          child: _MiniBalanceStat(
                            label: 'Expenses',
                            value: '\$1,100',
                            icon: Icons.arrow_upward_rounded,
                            color: const Color(0xFFFF6E6E),
                            visible: _balanceVisible,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── 4 UNIQUE ANIMATED SUMMARY CARDS ───────────────────────────
            Row(
              children: [
                Expanded(
                  child: FadeInLeft(
                    delay: const Duration(milliseconds: 100),
                    child: _GlowingMetricCard(
                      label: 'Income',
                      amount: '\$4,200',
                      gradient: const [
                        Color(0xFF1A1A2E),
                        Color(0xFF23233E),
                      ], // dark/black
                      icon: Icons.south_west_rounded,
                      trend: '+12%',
                      trendUp: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FadeInRight(
                    delay: const Duration(milliseconds: 100),
                    child: _GlowingMetricCard(
                      label: 'Expenses',
                      amount: '\$1,100',
                      gradient: const [Color(0xFFFF1744), Color(0xFFFF6D00)],
                      icon: Icons.north_east_rounded,
                      trend: '-5%',
                      trendUp: false,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: FadeInLeft(
                    delay: const Duration(milliseconds: 200),
                    child: const _FlipMetricCard(
                      label: 'Installment',
                      amount: '\$500',
                      onYouAmount: '\$300',
                      forYouAmount: '\$200',
                      accentColor: Color(0xFFAA00FF),
                      gradient: [Color(0xFF8E24AA), Color(0xFFAB47BC)],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FadeInRight(
                    delay: const Duration(milliseconds: 200),
                    child: const _FlipMetricCard(
                      label: 'Debt',
                      amount: '\$200',
                      onYouAmount: '\$120',
                      forYouAmount: '\$80',
                      accentColor: Color(0xFF0091EA),
                      gradient: [Color(0xFF01579B), Color(0xFF0288D1)],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── RECENT TRANSACTIONS ────────────────────────────────────────
            FadeInUp(
              delay: const Duration(milliseconds: 300),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Transactions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      'View All ›',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(3, (index) {
              final icons = [
                Icons.shopping_bag,
                Icons.restaurant,
                Icons.directions_car,
              ];
              final names = ['Shopping', 'Dining', 'Transport'];
              final amounts = ['-\$120.00', '-\$45.00', '-\$30.00'];
              final colors = [Colors.purple, Colors.orange, Colors.blue];
              return FadeInUp(
                delay: Duration(milliseconds: 350 + (index * 80)),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors[index].withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icons[index],
                          color: colors[index],
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              names[index],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const Text(
                              'Today',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        amounts[index],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      floatingActionButton: OpenContainer(
        transitionType: ContainerTransitionType.fade,
        openBuilder: (context, _) => const AddTransactionSheet(),
        closedElevation: 6.0,
        closedShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(56 / 2)),
        ),
        closedColor: cs.primary,
        closedBuilder: (context, openContainer) {
          return SizedBox(
            height: 56,
            width: 56,
            child: Center(child: Icon(Icons.add, color: cs.onPrimary)),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini income/expense stat inside the balance card
// ─────────────────────────────────────────────────────────────────────────────
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
              color: color.withValues(alpha: 0.2),
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

// ─────────────────────────────────────────────────────────────────────────────
// Glowing gradient metric card (Income / Expense)
// ─────────────────────────────────────────────────────────────────────────────
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
            color: gradient[0].withValues(alpha: 0.3),
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
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
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
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Flip-style card for Installment / Debt
// ─────────────────────────────────────────────────────────────────────────────
class _FlipMetricCard extends StatefulWidget {
  const _FlipMetricCard({
    required this.label,
    required this.amount,
    required this.onYouAmount,
    required this.forYouAmount,
    required this.accentColor,
    this.gradient,
  });

  final String label;
  final String amount;
  final String onYouAmount;
  final String forYouAmount;
  final Color accentColor;
  final List<Color>? gradient;

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
    final label = _showOnYou ? 'On You' : 'For You';
    final displayAmount = _showOnYou ? widget.onYouAmount : widget.forYouAmount;

    return GestureDetector(
      onTap: _toggle,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: widget.gradient != null
              ? LinearGradient(
                  colors: widget.gradient!,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: widget.gradient == null
              ? widget.accentColor.withValues(alpha: 0.08)
              : null,
          borderRadius: BorderRadius.circular(20),
          border: widget.gradient == null
              ? Border.all(color: widget.accentColor.withValues(alpha: 0.2))
              : null,
          boxShadow: widget.gradient != null
              ? [
                  BoxShadow(
                    color: widget.gradient![0].withValues(alpha: 0.3),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.gradient != null ? Colors.white : widget.accentColor,
                  ),
                ),
                Icon(
                  Icons.swap_horiz_rounded,
                  color: widget.gradient != null ? Colors.white : widget.accentColor,
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 10),
            FadeTransition(
              opacity: _fade,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayAmount,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: widget.gradient != null ? Colors.white : widget.accentColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: widget.gradient != null
                          ? Colors.white.withValues(alpha: 0.2)
                          : widget.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: widget.gradient != null ? Colors.white : widget.accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
