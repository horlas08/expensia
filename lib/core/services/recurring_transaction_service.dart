import 'package:expensia/core/services/database_service.dart';

class RecurringTransactionService {
  static final RecurringTransactionService _instance = RecurringTransactionService._internal();

  factory RecurringTransactionService() {
    return _instance;
  }

  RecurringTransactionService._internal();

  Future<void> processDueTransactions() async {
    final dbService = DatabaseService();
    final db = await dbService.database;
    final now = DateTime.now();

    // Find all active, auto_add recurring transactions where next execution date is in the past or today.
    final dueRecurringTransactions = await db.rawQuery('''
      SELECT * FROM recurring_transactions 
      WHERE is_active = 1 
        AND auto_add = 1 
        AND datetime(next_execution_date) <= datetime('now', 'localtime')
    ''');

    if (dueRecurringTransactions.isEmpty) return;

    await db.transaction((txn) async {
      for (final recurring in dueRecurringTransactions) {
        final recurringId = recurring['id'] as int;
        final parentTransactionId = recurring['transaction_id'] as int;
        final repeatType = recurring['repeat_type'] as String;
        var nextExecutionDateStr = recurring['next_execution_date'] as String;
        var nextExecutionDate = DateTime.parse(nextExecutionDateStr);

        // Fetch parent transaction to clone it
        final parentTransactions = await txn.query(
          'transactions',
          where: 'id = ?',
          whereArgs: [parentTransactionId],
        );

        if (parentTransactions.isEmpty) continue;
        final parent = parentTransactions.first;

        // Determine if we need to loop if it's been missed multiple times
        while (nextExecutionDate.isBefore(now) || _isSameDay(nextExecutionDate, now)) {
          // 1. Clone the transaction
          final Map<String, dynamic> newTransaction = Map<String, dynamic>.from(parent);
          newTransaction.remove('id'); // Remove original ID so it auto-increments
          newTransaction['date'] = nextExecutionDate.toIso8601String();
          newTransaction['recurring_id'] = recurringId;
          newTransaction['is_opening'] = 0;
          newTransaction['is_repeat'] = 0; // The generated transaction itself isn't the template

          await txn.insert('transactions', newTransaction);

          // 2. Update wallet balance
          final walletId = newTransaction['wallet_id'] as int;
          final amount = newTransaction['amount'] as double;
          final direction = newTransaction['direction'] as String;
          final type = newTransaction['type'] as String;

          final walletRows = await txn.query('wallets', where: 'id = ?', whereArgs: [walletId]);
          if (walletRows.isNotEmpty) {
            final currentBalance = walletRows.first['balance'] as double;
            double newBalance = currentBalance;

            if (type == 'expense' || type == 'installment' || direction == 'min') {
              newBalance -= amount;
            } else if (type == 'income' || type == 'debt' || direction == 'plus') {
              newBalance += amount;
            }

            await txn.update(
              'wallets',
              {'balance': newBalance},
              where: 'id = ?',
              whereArgs: [walletId],
            );
          }

          // 3. Advance to the next execution date
          nextExecutionDate = _calculateNextDate(nextExecutionDate, repeatType);
        }

        // 4. Update the recurring transaction record with the new future date
        await txn.update(
          'recurring_transactions',
          {'next_execution_date': nextExecutionDate.toIso8601String()},
          where: 'id = ?',
          whereArgs: [recurringId],
        );
      }
    });
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  DateTime _calculateNextDate(DateTime fromDate, String repeatType) {
    switch (repeatType.toLowerCase()) {
      case 'daily':
        return fromDate.add(const Duration(days: 1));
      case 'weekly':
        return fromDate.add(const Duration(days: 7));
      case 'monthly':
        var month = fromDate.month + 1;
        var year = fromDate.year;
        if (month > 12) {
          month = 1;
          year++;
        }
        try {
          return DateTime(year, month, fromDate.day, fromDate.hour, fromDate.minute);
        } catch (_) {
          return DateTime(year, month + 1, 0, fromDate.hour, fromDate.minute);
        }
      case 'yearly':
        try {
          return DateTime(fromDate.year + 1, fromDate.month, fromDate.day, fromDate.hour, fromDate.minute);
        } catch (_) {
          // Leap year fallback
          return DateTime(fromDate.year + 1, fromDate.month + 1, 0, fromDate.hour, fromDate.minute);
        }
      default:
        return fromDate.add(const Duration(days: 30));
    }
  }
}
