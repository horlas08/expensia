import 'package:flutter/material.dart';
import 'package:animated_theme_switcher/animated_theme_switcher.dart';
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
    const TransactionsPage(),
    const WalletPage(),
    const StatisticsPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    // ThemeSwitchingArea must wrap the content that shows the ripple animation
    return ThemeSwitchingArea(
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _pages[_currentIndex],
        ),
        floatingActionButton: _currentIndex < 3
            ?

        FloatingActionButton(
                heroTag: 'add_transaction_fab',
                onPressed: () => showTransactionTypeSheet(context),
                backgroundColor: Theme.of(context).colorScheme.primary,
                elevation: 6,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(56 / 2)),
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Activity',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Wallet',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Stats',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
