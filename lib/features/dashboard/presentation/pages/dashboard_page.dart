import 'package:flutter/material.dart';
import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/dashboard/presentation/pages/home_tab.dart';
import '../../../../features/transactions/presentation/pages/transactions_page.dart';
import '../../../../features/statistics/presentation/pages/statistics_page.dart';
import '../../../../features/profile/presentation/pages/profile_page.dart';
import '../../../../features/dashboard/presentation/pages/wallet_page.dart';
import '../../../../features/transactions/presentation/widgets/transaction_type_sheet.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeTab(),
    // const TransactionsPage(),
    const WalletPage(),
    const StatisticsPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    // ThemeSwitchingArea is now global in main.dart — no wrapper needed here.
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pages[_currentIndex],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_transaction_fab',
        onPressed: () => showTransactionTypeSheet(context),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 6,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(56 / 2)),
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        height: 65,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavDestination(context, 0, Icons.home_rounded, Icons.home_outlined, 'bottom_bar.home'.tr()),
            _buildNavDestination(context, 1, Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined, 'bottom_bar.wallet'.tr()),
            const SizedBox(width: 40), // Gap for FAB
            _buildNavDestination(context, 2, Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'bottom_bar.stat'.tr()),
            _buildNavDestination(context, 3, Icons.person_rounded, Icons.person_outline, 'bottom_bar.profile'.tr()),
          ],
        ),
      ),
    );
  }

  Widget _buildNavDestination(BuildContext ctx, int index, IconData selectedIcon, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? Theme.of(ctx).colorScheme.primary : Theme.of(ctx).colorScheme.onSurfaceVariant;
    
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSelected ? selectedIcon : icon, color: color),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
