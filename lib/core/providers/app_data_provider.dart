import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'categories_provider.dart';
import 'currency_provider.dart';
import '../../features/wallet/presentation/providers/wallet_provider.dart';
import '../../features/dashboard/presentation/providers/dashboard_provider.dart';
import '../../features/profile/presentation/providers/persons_provider.dart';

/// Helper function to invalidate all cached app data providers across Riverpod
/// after restoring a database backup or performing a full data reset.
void invalidateAppData(WidgetRef ref) {
  ref.read(walletProvider.notifier).loadWallets();
  ref.invalidate(walletProvider);
  ref.invalidate(dashboardMetricsProvider);
  ref.invalidate(recentTransactionsProvider);
  ref.invalidate(allTransactionsProvider);
  ref.invalidate(categoriesProvider('expense'));
  ref.invalidate(categoriesProvider('income'));
  ref.invalidate(defaultCurrencyProvider);
  ref.invalidate(currencyCatalogProvider);
  ref.invalidate(personsProvider);
}
