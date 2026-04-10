import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/database_service.dart';

/// Provider for the dashboard metrics (Income, Expense, Debt, etc.)
final dashboardMetricsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dbService = DatabaseService();
  return await dbService.getDashboardMetrics();
});

/// Provider for recent transitions (limit 5)
final recentTransactionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dbService = DatabaseService();
  return await dbService.getRecentTransactions(limit: 5);
});

/// Provider for all transactions
final allTransactionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dbService = DatabaseService();
  return await dbService.getAllTransactions();
});
