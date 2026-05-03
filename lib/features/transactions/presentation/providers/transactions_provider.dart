import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/database_service.dart';
import 'transaction_filter_provider.dart';

/// Provider for filtered transactions based on the current filter state.
final filteredTransactionsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async {
    final filter = ref.watch(transactionFilterProvider);
    final dbService = DatabaseService();

    if (filter.isEmpty) {
      return dbService.getAllTransactions();
    }

    return dbService.getFilteredTransactions(
      type: filter.type,
      direction: filter.direction,
      categoryId: filter.categoryId,
      walletId: filter.walletId,
      personId: filter.personId,
      fromDate: filter.fromDate,
      toDate: filter.toDate,
    );
  },
);
