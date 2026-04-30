import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

import 'currency_catalog_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<void> closeConnection() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }

  void resetInstance() {
    _db = null;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'expensia.db');

    return await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Check if 'type' column exists in installments
      final result = await db.rawQuery('PRAGMA table_info(installments)');
      final hasTypeColumn = result.any((column) => column['name'] == 'type');

      if (!hasTypeColumn) {
        await db.execute('ALTER TABLE installments ADD COLUMN type TEXT');
      }
    }
    if (oldVersion < 3) {
      // Ensure recently added tables exist for users upgrading from older versions
      await db.execute(_sqlTransfers);
      await db.execute(_sqlInstallmentDetails);
      await db.execute(_sqlScheduledNotifications);
    }
    if (oldVersion < 4) {
      await syncCurrencyCatalog(database: db);
    }
    if (oldVersion < 5) {
      final result = await db.rawQuery('PRAGMA table_info(categories)');
      final hasParentId = result.any((column) => column['name'] == 'parent_id');
      if (!hasParentId) {
        await db.execute('ALTER TABLE categories ADD COLUMN parent_id INTEGER');
      }
    }
    if (oldVersion < 6) {
      await _forceReseedCategories(db);
    }
    if (oldVersion < 7) {
      // Add body column to reminders table for custom reminder descriptions
      final reminderCols = await db.rawQuery('PRAGMA table_info(reminders)');
      final hasBody = reminderCols.any((c) => c['name'] == 'body');
      if (!hasBody) {
        await db.execute('ALTER TABLE reminders ADD COLUMN body TEXT');
      }
      final hasScheduledDate = reminderCols.any((c) => c['name'] == 'scheduled_date');
      if (!hasScheduledDate) {
        await db.execute('ALTER TABLE reminders ADD COLUMN scheduled_date TEXT');
      }
    }
    if (oldVersion < 8) {
      final installmentDetailCols = await db.rawQuery('PRAGMA table_info(installment_details)');
      final hasWalletId = installmentDetailCols.any((c) => c['name'] == 'wallet_id');
      if (!hasWalletId) {
        await db.execute('ALTER TABLE installment_details ADD COLUMN wallet_id INTEGER');
      }
    }
    if (oldVersion < 9) {
      final installmentCols = await db.rawQuery('PRAGMA table_info(installments)');
      final hasLastPayment = installmentCols.any((c) => c['name'] == 'last_payment');
      if (!hasLastPayment) {
        await db.execute('ALTER TABLE installments ADD COLUMN last_payment REAL NOT NULL DEFAULT 0');
      }
    }
    if (oldVersion < 10) {
      final installmentDetailCols = await db.rawQuery('PRAGMA table_info(installment_details)');
      final hasIsInitial = installmentDetailCols.any((c) => c['name'] == 'is_initial');
      if (!hasIsInitial) {
        await db.execute('ALTER TABLE installment_details ADD COLUMN is_initial INTEGER NOT NULL DEFAULT 0');
      }
    }
    if (oldVersion < 11) {
      // Expand wallets.type CHECK constraint to include 'investment'
      // SQLite doesn't support ALTER TABLE to change constraints, so we recreate the table.
      await db.execute('ALTER TABLE wallets RENAME TO wallets_old');
      await db.execute(_sqlWallets);
      await db.execute('''
        INSERT INTO wallets (id, name, type, balance, currency_id, hide, bloc, is_visible, created_at)
        SELECT id, name,
          CASE WHEN type IN (\'cash\', \'bank\', \'investment\', \'credit_card\', \'other\') THEN type ELSE \'other\' END,
          balance, currency_id,
          COALESCE(hide, 0),
          COALESCE(bloc, 0),
          COALESCE(is_visible, 1),
          COALESCE(created_at, CURRENT_TIMESTAMP)
        FROM wallets_old
      ''');
      await db.execute('DROP TABLE wallets_old');
    }
    if (oldVersion < 12) {
      // 1. Rename existing categories table
      await db.execute('ALTER TABLE categories RENAME TO categories_old');
      
      // 2. Recreate categories table with updated constraints ('installment' added)
      await db.execute(_sqlCategories);
      
      // 3. Copy data over
      await db.execute('''
        INSERT INTO categories (id, name_ar, name_en, image_name, type, parent_id)
        SELECT id, name_ar, name_en, image_name, type, parent_id FROM categories_old
      ''');
      
      // 4. Drop the old table
      await db.execute('DROP TABLE categories_old');
      
      // 5. Update old combined Debt/Installment default categories to just Debt
      await db.execute("UPDATE categories SET name_en = 'Pay Debts', name_ar = 'دفع ديون' WHERE id = 3");
      await db.execute("UPDATE categories SET name_en = 'Receive Debts', name_ar = 'استلام ديون' WHERE id = 4");
      
      // 6. Insert new Installment default categories
      await db.execute('''
        INSERT OR IGNORE INTO categories (id, name_ar, name_en, type, parent_id, image_name) VALUES 
        (1001, 'دفع أقساط', 'Pay Installments', 'installment', NULL, 'installment'),
        (1002, 'استلام أقساط', 'Receive Installments', 'installment', NULL, 'installment')
      ''');
    }
    if (oldVersion < 13) {
      await _repairInstallmentCategoryData(db);
    }
    if (oldVersion < 14) {
      await _repairDebtAndInstallmentCategoryData(db);
    }
    if (oldVersion < 15) {
      await _repairDebtAndInstallmentCategoryData(db);
    }
    if (oldVersion < 16) {
      await _ensureInstallmentHistoryRows(db);
    }
  }

  Future<void> _forceReseedCategories(Database db) async {
    // We want to update existing categories with their parent_id and icons
    // and insert new ones. We'll use a batch for efficiency.
    final batch = db.batch();
    
    // The safest way is to clear and re-insert, but that would break transaction foreign keys.
    // Instead, we'll UPSERT based on the ID if possible, or name.
    // Our _sqlInsertCategories uses specific IDs, so we can use those.
    
    // First, ensure all categories from our new list exist or are updated.
    // I'll parse the _sqlInsertCategories string logic or just re-apply the logic manually.
    // Since _sqlInsertCategories is a large string, I'll just execute it with 
    // INSERT OR REPLACE if I change the SQL slightly, but that might change IDs 
    // which are foreign keys in transactions.
    
    // Better: Update if ID exists, insert if not.
    // I will use a simplified version of the list for the upgrade script.
    
    final scripts = _sqlInsertCategories.split(';').where((s) => s.trim().isNotEmpty).toList();
    for (var script in scripts) {
      // Modify INSERT INTO to INSERT OR REPLACE INTO for this force reseed
      final modifiedScript = script.replaceFirst('INSERT INTO categories', 'INSERT OR REPLACE INTO categories');
      batch.execute(modifiedScript);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _repairInstallmentCategoryData(Database db) async {
    await db.execute('ALTER TABLE categories RENAME TO categories_old');
    await db.execute(_sqlCategories);
    await db.execute('''
      INSERT INTO categories (id, name_ar, name_en, image_name, type, parent_id)
      SELECT
        CASE
          WHEN id = 101 AND type = 'installment' THEN 1001
          WHEN id = 102 AND type = 'installment' THEN 1002
          ELSE id
        END,
        name_ar,
        name_en,
        image_name,
        type,
        parent_id
      FROM categories_old
    ''');
    await db.execute('DROP TABLE categories_old');

    await db.execute('''
      UPDATE installments
      SET category_id = CASE
        WHEN type = 'for_you' THEN 1001
        ELSE 1002
      END
    ''');

    await db.execute('''
      UPDATE transactions
      SET category_id = CASE
        WHEN direction = 'plus' THEN 1001
        ELSE 1002
      END
      WHERE type = 'installment'
    ''');

    await _forceReseedCategories(db);
  }

  Future<void> _repairDebtAndInstallmentCategoryData(Database db) async {
    await db.execute('''
      UPDATE debts
      SET category_id = CASE
        WHEN COALESCE(income, 0) > 0 THEN 3
        ELSE 4
      END
    ''');

    await db.execute('''
      UPDATE transactions
      SET category_id = CASE
        WHEN direction = 'plus' THEN 3
        ELSE 4
      END
      WHERE type = 'debt'
    ''');

    await db.execute('''
      UPDATE installments
      SET category_id = CASE
        WHEN type = 'for_you' THEN 1001
        ELSE 1002
      END
    ''');

    await db.execute('''
      UPDATE transactions
      SET category_id = CASE
        WHEN direction = 'plus' THEN 1001
        ELSE 1002
      END
      WHERE type = 'installment'
    ''');
  }

  Future<void> _ensureInstallmentHistoryRows(Database db) async {
    await db.execute('''
      INSERT INTO transactions (
        wallet_id,
        category_id,
        person_id,
        currency_id,
        type,
        direction,
        amount,
        date,
        is_paid,
        person_name,
        notes,
        image_url,
        installment_id,
        is_repeat,
        is_opening
      )
      SELECT
        i.wallet_id,
        i.category_id,
        i.person_id,
        COALESCE((SELECT default_currency_id FROM settings LIMIT 1), 1),
        'installment',
        CASE WHEN i.type = 'for_you' THEN 'plus' ELSE 'min' END,
        COALESCE(i.deposit, 0),
        COALESCE(i.created_at, CURRENT_TIMESTAMP),
        1,
        p.name,
        i.notes,
        i.image_path,
        i.id,
        0,
        1
      FROM installments i
      LEFT JOIN persons p ON p.id = i.person_id
      WHERE NOT EXISTS (
        SELECT 1
        FROM transactions t
        WHERE t.installment_id = i.id
      )
    ''');
  }

  Future<void> _onCreate(Database db, int version) async {
    // Run creation scripts from legacy
    await _executeBatch(db, [
      _sqlAllCurrencies,
      _sqlCategories,
      _sqlPersons,
      _sqlWallets,
      _sqlDebts,
      _sqlInstallments,
      _sqlMonthlyBudgets,
      _sqlRecurringTransactions,
      _sqlReminders,
      _sqlSettings,
      _sqlTransactions,
      _sqlTransfers,
      _sqlInstallmentDetails,
      _sqlScheduledNotifications,
      _sqlInsertCategories,
    ]);
    await syncCurrencyCatalog(database: db);
  }

  Future<void> _executeBatch(Database db, List<String> scripts) async {
    final batch = db.batch();
    for (final script in scripts) {
      if (script.trim().isNotEmpty) {
        batch.execute(script);
      }
    }
    await batch.commit();
  }

  Future<void> syncCurrencyCatalog({Database? database}) async {
    final db = database ?? await this.database;
    final currencies = await CurrencyCatalogService().loadCurrencies();
    final batch = db.batch();

    for (final currency in currencies) {
      batch.rawInsert(
        '''
        INSERT INTO all_currencies (
          id,
          currency_name_ar,
          currency_name_en,
          country_code,
          currency_code,
          currency_symbol,
          rate_to_usd,
          is_default,
          flag
        ) VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?)
        ON CONFLICT(id) DO UPDATE SET
          currency_name_ar = excluded.currency_name_ar,
          currency_name_en = excluded.currency_name_en,
          country_code = excluded.country_code,
          currency_code = excluded.currency_code,
          currency_symbol = excluded.currency_symbol,
          rate_to_usd = excluded.rate_to_usd,
          flag = excluded.flag
        ''',
        [
          currency.id,
          currency.currencyNameAr,
          currency.currencyNameEn,
          currency.countryCode,
          currency.currencyCode,
          currency.currencySymbol,
          currency.rateToUsd,
          currency.flag,
        ],
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> normalizeDebtAndInstallmentStates({Database? database}) async {
    final db = database ?? await this.database;
    await _normalizeAllDebtStates(db);
    await _normalizeAllInstallmentStates(db);
  }

  // --- WALLET METHODS ---

  Future<int> addWallet(Map<String, dynamic> wallet) async {
    final db = await database;
    return await db.insert('wallets', wallet);
  }

  Future<int> updateWallet(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('wallets', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> transferBalance({
    required int fromId,
    required int toId,
    required double amount,
  }) async {
    final db = await database;

    // Guard: check source wallet has sufficient balance
    final fromRows = await db.query('wallets', where: 'id = ?', whereArgs: [fromId], limit: 1);
    if (fromRows.isEmpty) throw Exception('source_wallet_not_found');
    final currentBalance = (fromRows.first['balance'] as num?)?.toDouble() ?? 0.0;
    if (currentBalance < amount) throw Exception('insufficient_balance');

    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE wallets SET balance = balance - ? WHERE id = ?',
        [amount, fromId],
      );
      await txn.rawUpdate(
        'UPDATE wallets SET balance = balance + ? WHERE id = ?',
        [amount, toId],
      );

      // Record the transfer in transfers table
      await txn.insert('transfers', {
        'from_wallet_id': fromId,
        'to_wallet_id': toId,
        'amount': amount,
        'date': DateTime.now().toIso8601String(),
        'notes': 'Wallet Transfer',
      });
    });
  }

  Future<void> transferTransactions({
    required int fromId,
    required int toId,
  }) async {
    final db = await database;
    await db.update(
      'transactions',
      {'wallet_id': toId},
      where: 'wallet_id = ?',
      whereArgs: [fromId],
    );
  }

  Future<void> deleteAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('settings');
      await txn.delete('transfers');
      await txn.delete('recurring_transactions');
      await txn.delete('installment_details');
      await txn.delete('transactions');
      await txn.delete('debts');
      await txn.delete('installments');
      await txn.delete('persons');
      await txn.delete('wallets');
      await txn.delete('reminders');
      await txn.delete('scheduled_notifications');
    });
  }

  Future<void> initializeSetup({
    required String name,
    required int defaultCurrencyId,
    required double cashBalance,
    required double salaryAmount,
    required int salaryDay,
    required bool hasSalary,
    required bool autoAddSalary,
    String cashWalletName = 'Cash',
    String salaryWalletName = 'Salary Account',
    String cashNote = 'Initial Balance',
    String salaryNote = 'Initial Salary',
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      // 1. Clear existing dynamic data (for a fresh setup)
      await txn.delete('settings');
      await txn.delete('transfers');
      await txn.delete('recurring_transactions');
      await txn.delete('installment_details');
      await txn.delete('transactions');
      await txn.delete('debts');
      await txn.delete('installments');
      await txn.delete('persons');
      await txn.delete('wallets');
      // Categories and Currencies stay as they are seed data

      // 2. Set default currency
      await txn.update(
        'all_currencies',
        {'is_default': 0},
        where: 'is_default = ?',
        whereArgs: [1],
      );
      await txn.update(
        'all_currencies',
        {'is_default': 1},
        where: 'id = ?',
        whereArgs: [defaultCurrencyId],
      );

      // 3. Create Cash Wallet
      final cashWalletId = await txn.insert('wallets', {
        'name': cashWalletName,
        'type': 'cash',
        'balance': cashBalance,
        'currency_id': defaultCurrencyId,
        'is_visible': 1,
      });

      // 4. Record Initial Cash Balance Transaction
      if (cashBalance > 0) {
        await txn.insert('transactions', {
          'wallet_id': cashWalletId,
          'category_id': 6, // Add Balance
          'currency_id': defaultCurrencyId,
          'type': 'income',
          'direction': 'plus',
          'amount': cashBalance,
          'date': DateTime.now().toIso8601String(),
          'is_paid': 1,
          'is_opening': 1,
          'notes': cashNote,
        });
      }

      // 5. Handle Salary if enabled
      if (hasSalary && salaryAmount > 0) {
        // Create salary wallet pre-credited with the salary amount
        final salaryWalletId = await txn.insert('wallets', {
          'name': salaryWalletName,
          'type': 'bank',
          'balance': salaryAmount,   // ← credit initial salary immediately
          'currency_id': defaultCurrencyId,
          'is_visible': 1,
        });

        // Opening income transaction (one-time, shows the initial credit)
        await txn.insert('transactions', {
          'wallet_id': salaryWalletId,
          'category_id': 5, // Salary
          'currency_id': defaultCurrencyId,
          'type': 'income',
          'direction': 'plus',
          'amount': salaryAmount,
          'is_paid': 1,
          'is_opening': 1,
          'is_repeat': 0,
          'date': DateTime.now().toIso8601String(),
          'notes': salaryNote,
        });

        // Recurring salary template for future months
        if (autoAddSalary) {
          final recurringId = await txn.insert('transactions', {
            'wallet_id': salaryWalletId,
            'category_id': 5,
            'currency_id': defaultCurrencyId,
            'type': 'income',
            'direction': 'plus',
            'amount': salaryAmount,
            'is_paid': 0,
            'is_repeat': 1,
            'date': DateTime.now().toIso8601String(),
          });
          final nextDate = _calculateNextSalaryDate(salaryDay);
          await txn.insert('recurring_transactions', {
            'transaction_id': recurringId,
            'start_date': DateTime.now().toIso8601String(),
            'next_execution_date': nextDate.toIso8601String(),
            'repeat_type': 'monthly',
            'is_active': 1,
            'auto_add': 1,
          });
        }
      }

      // 6. Update Settings
      await txn.delete('settings');
      await txn.insert('settings', {
        'user_name': name,
        'default_currency_id': defaultCurrencyId,
        'default_wallet_id': cashWalletId,
        'salary_amount': salaryAmount,
        'salary_day': salaryDay,
        'is_first_setup_done': 1,
      });
    });
  }

  Future<Map<String, dynamic>?> getSettings() async {
    final db = await database;
    final results = await db.query('settings', limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  // --- DATA RETRIEVAL METHODS ---

  Future<List<Map<String, dynamic>>> getWallets() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT w.*, c.currency_code, c.currency_symbol, c.currency_name_en, c.rate_to_usd
      FROM wallets w
      LEFT JOIN all_currencies c ON w.currency_id = c.id
      WHERE w.is_visible = 1
    ''');
  }

  Future<Map<String, dynamic>> getDashboardMetrics() async {
    final db = await database;
    await normalizeDebtAndInstallmentStates(database: db);

    // Get total income and expense for the current month
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1).toIso8601String();

    final incomeResult = await db.rawQuery(
      '''
      SELECT SUM(amount) as total FROM transactions 
      WHERE type = 'income' AND is_repeat = 0 AND COALESCE(is_opening, 0) = 0 AND date >= ?
    ''',
      [firstDayOfMonth],
    );

    final expenseResult = await db.rawQuery(
      '''
      SELECT SUM(amount) as total FROM transactions 
      WHERE type = 'expense' AND is_repeat = 0 AND COALESCE(is_opening, 0) = 0 AND date >= ?
    ''',
      [firstDayOfMonth],
    );

    final debtResult = await db.rawQuery('''
      SELECT
        COALESCE(SUM(income), 0) as for_you,
        COALESCE(SUM(expense), 0) as on_you
      FROM debts
    ''');

    final installmentResult = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN type = 'on_you' OR type IS NULL THEN remaining_price ELSE 0 END), 0) as on_you,
        COALESCE(SUM(CASE WHEN type = 'for_you' THEN remaining_price ELSE 0 END), 0) as for_you
      FROM installments
    ''');

    return {
      'monthly_income':
          (incomeResult.first['total'] as num?)?.toDouble() ?? 0.0,
      'monthly_expense':
          (expenseResult.first['total'] as num?)?.toDouble() ?? 0.0,
      'debt_on_you': (debtResult.first['on_you'] as num?)?.toDouble() ?? 0.0,
      'debt_for_you': (debtResult.first['for_you'] as num?)?.toDouble() ?? 0.0,
      'installment_on_you':
          (installmentResult.first['on_you'] as num?)?.toDouble() ?? 0.0,
      'installment_for_you':
          (installmentResult.first['for_you'] as num?)?.toDouble() ?? 0.0,
    };
  }

  Future<List<Map<String, dynamic>>> getRecentTransactions({
    int limit = 5,
  }) async {
    final db = await database;
    final sql = '''
      SELECT
        t.id,
        t.type,
        t.amount,
        t.direction,
        t.date,
        t.notes,
        t.category_id,
        t.wallet_id,
        t.debt_id,
        t.installment_id,
        c.name_ar as category_name_ar,
        c.name_en as category_name_en,
        c.name_en as category_name,
        w.name as wallet_name,
        NULL as to_wallet_name,
        p.name as person_name,
        p.phone as person_phone,
        p.id as person_id
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      LEFT JOIN wallets w ON t.wallet_id = w.id
      LEFT JOIN persons p ON t.person_id = p.id
      WHERE t.is_repeat = 0
      UNION ALL
      SELECT
        tr.id,
        'transfer' as type,
        tr.amount,
        'neutral' as direction,
        tr.date,
        tr.notes,
        NULL as category_id,
        tr.from_wallet_id as wallet_id,
        NULL as debt_id,
        NULL as installment_id,
        'تحويل' as category_name_ar,
        'Transfer' as category_name_en,
        'Transfer' as category_name,
        w1.name as wallet_name,
        w2.name as to_wallet_name,
        NULL as person_name,
        NULL as person_phone,
        NULL as person_id
      FROM transfers tr
      LEFT JOIN wallets w1 ON tr.from_wallet_id = w1.id
      LEFT JOIN wallets w2 ON tr.to_wallet_id = w2.id
      ORDER BY date DESC
      LIMIT ?
    ''';
    return await db.rawQuery(sql, [limit]);
  }


  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    final db = await database;
    final sql = '''
      SELECT
        t.id,
        t.type,
        t.amount,
        t.direction,
        t.date,
        t.notes,
        t.category_id,
        t.wallet_id,
        t.debt_id,
        t.installment_id,
        c.name_ar as category_name_ar,
        c.name_en as category_name_en,
        c.name_en as category_name,
        w.name as wallet_name,
        NULL as to_wallet_name,
        p.name as person_name,
        p.phone as person_phone,
        p.id as person_id
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      LEFT JOIN wallets w ON t.wallet_id = w.id
      LEFT JOIN persons p ON t.person_id = p.id
      WHERE t.is_repeat = 0
      UNION ALL
      SELECT
        tr.id,
        'transfer' as type,
        tr.amount,
        'neutral' as direction,
        tr.date,
        tr.notes,
        NULL as category_id,
        tr.from_wallet_id as wallet_id,
        NULL as debt_id,
        NULL as installment_id,
        'تحويل' as category_name_ar,
        'Transfer' as category_name_en,
        'Transfer' as category_name,
        w1.name as wallet_name,
        w2.name as to_wallet_name,
        NULL as person_name,
        NULL as person_phone,
        NULL as person_id
      FROM transfers tr
      LEFT JOIN wallets w1 ON tr.from_wallet_id = w1.id
      LEFT JOIN wallets w2 ON tr.to_wallet_id = w2.id
      ORDER BY date DESC
    ''';
    return await db.rawQuery(sql);
  }


  /// Returns filtered transactions based on a filter object.
  Future<List<Map<String, dynamic>>> getFilteredTransactions({
    String? type,
    String? direction,
    int? categoryId,
    int? walletId,
    int? personId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    // Fetch all first, then filter in memory (avoids complex UNION ALL WHERE clauses)
    final all = await getAllTransactions();
    return all.where((tx) {
      if (type != null && tx['type'] != type) return false;
      if (direction != null && tx['direction'] != direction) return false;
      if (categoryId != null && tx['category_id'] != categoryId) return false;
      if (walletId != null && tx['wallet_id'] != walletId) return false;
      if (personId != null && tx['person_id'] != personId) return false;
      if (fromDate != null) {
        final txDate = DateTime.tryParse(tx['date'] as String? ?? '');
        if (txDate == null || txDate.isBefore(fromDate)) return false;
      }
      if (toDate != null) {
        final txDate = DateTime.tryParse(tx['date'] as String? ?? '');
        if (txDate == null ||
            txDate.isAfter(toDate.add(const Duration(days: 1)))) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<Map<String, dynamic>?> getMainTransactionForDebt(int debtId) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT t.*, c.name_ar as category_name_ar, c.name_en as category_name_en, c.name_en as category_name, w.name as wallet_name, p.name as person_name
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      LEFT JOIN wallets w ON t.wallet_id = w.id
      LEFT JOIN persons p ON t.person_id = p.id
      WHERE t.debt_id = ?
      ORDER BY t.is_opening DESC, t.id ASC
      LIMIT 1
    ''', [debtId]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getMainTransactionForInstallment(int installmentId) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT t.*, c.name_ar as category_name_ar, c.name_en as category_name_en, c.name_en as category_name, w.name as wallet_name, p.name as person_name
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      LEFT JOIN wallets w ON t.wallet_id = w.id
      LEFT JOIN persons p ON t.person_id = p.id
      WHERE t.installment_id = ?
      ORDER BY t.is_opening DESC, t.id ASC
      LIMIT 1
    ''', [installmentId]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> insertInstallmentDetail(Map<String, dynamic> detail) async {
    final db = await database;
    return await db.insert('installment_details', detail);
  }

  DateTime _calculateNextSalaryDate(int day) {
    final now = DateTime.now();
    var month = now.month;
    var year = now.year;

    if (now.day >= day) {
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }

    // Handle edge cases like 31st of Feb
    try {
      return DateTime(year, month, day);
    } catch (_) {
      // If day 31 doesn't exist, use last day of month
      return DateTime(year, month + 1, 0);
    }
  }

  // --- CATEGORY METHODS ---

  Future<List<Map<String, dynamic>>> getCategoriesByType(String type) async {
    final db = await database;
    final res = await db.query(
      'categories',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'id ASC',
    );
    
    if (res.isEmpty && type == 'installment') {
      try {
        await db.execute('''
          INSERT OR IGNORE INTO categories (id, name_ar, name_en, type, parent_id, image_name) VALUES 
          (1001, 'دفع أقساط', 'Pay Installments', 'installment', NULL, 'installment'),
          (1002, 'استلام أقساط', 'Receive Installments', 'installment', NULL, 'receive_installment')
        ''');
        return await db.query(
          'categories',
          where: 'type = ?',
          whereArgs: [type],
          orderBy: 'id ASC',
        );
      } catch (e) {
        debugPrint('Error inserting default installment categories: $e');
      }
    }
    
    return res;
  }

  Future<int> addCategory({
    required String nameEn,
    required String nameAr,
    required String type,
    String iconKey = 'other',
    int? parentId,
  }) async {
    final db = await database;
    return await db.insert('categories', {
      'name_en': nameEn,
      'name_ar': nameAr,
      'type': type,
      'image_name': iconKey, // store icon key here
      if (parentId != null) 'parent_id': parentId,
    });
  }

  Future<void> updateCategory(
    int id,
    String nameEn,
    String nameAr,
    String type,
    String iconKey, {
    int? parentId,
  }) async {
    final db = await database;
    await db.update(
      'categories',
      {
        'name_en': nameEn,
        'name_ar': nameAr,
        'type': type,
        'image_name': iconKey,
        'parent_id': parentId ?? 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getCategoriesByParent(int? parentId, {String? type}) async {
    final db = await database;
    return await db.query(
      'categories',
      where: 'parent_id = ? ${type != null ? 'AND type = ?' : ''}',
      whereArgs: [parentId ?? 0, if (type != null) type],
      orderBy: 'id ASC',
    );
  }

  Future<void> deleteAnyTransaction(int id, String type) async {
    final db = await database;

    if (type == 'debt') {
      final txRows = await db.query('transactions', where: 'id = ?', whereArgs: [id], limit: 1);
      if (txRows.isNotEmpty) {
        final tx = txRows.first;
        final debtId = tx['debt_id'] as int?;
        if (debtId != null) {
          final openingRows = await db.query(
            'transactions',
            where: 'debt_id = ?',
            whereArgs: [debtId],
            orderBy: 'is_opening DESC, id ASC',
            limit: 1,
          );
          final openingId = openingRows.isNotEmpty ? openingRows.first['id'] as int : null;
          final isOpening = (tx['is_opening'] == 1) || openingId == id;

          if (!isOpening) {
            final walletId = tx['wallet_id'] as int?;
            final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
            final direction = tx['direction'] as String? ?? 'min';

            if (walletId != null && amount > 0) {
              if (direction == 'min') {
                await db.rawUpdate('UPDATE wallets SET balance = balance + ? WHERE id = ?', [amount, walletId]);
              } else {
                await db.rawUpdate('UPDATE wallets SET balance = balance - ? WHERE id = ?', [amount, walletId]);
              }
            }

            await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
            await _recalculateDebtState(db, debtId);
            return;
          }

          // Delete entire debt: reverse all related transactions first
          final allTxRows = await db.query('transactions', where: 'debt_id = ?', whereArgs: [debtId]);
          for (final row in allTxRows) {
            final wId = row['wallet_id'] as int?;
            final amt = (row['amount'] as num?)?.toDouble() ?? 0;
            final dir = row['direction'] as String? ?? 'min';
            if (wId != null && amt > 0) {
              if (dir == 'min') {
                await db.rawUpdate('UPDATE wallets SET balance = balance + ? WHERE id = ?', [amt, wId]);
              } else {
                await db.rawUpdate('UPDATE wallets SET balance = balance - ? WHERE id = ?', [amt, wId]);
              }
            }
          }
          await db.delete('transactions', where: 'debt_id = ?', whereArgs: [debtId]);
          await db.delete('debts', where: 'id = ?', whereArgs: [debtId]);
          return;
        }
      }
    }

    if (type == 'transfer') {
      // Reverse both wallet balances before deleting the transfer record
      final rows = await db.query('transfers', where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isNotEmpty) {
        final transfer = rows.first;
        final fromId  = transfer['from_wallet_id'] as int?;
        final toId    = transfer['to_wallet_id']   as int?;
        final amount  = (transfer['amount'] as num?)?.toDouble() ?? 0;
        if (fromId != null && toId != null && amount > 0) {
          await db.rawUpdate('UPDATE wallets SET balance = balance + ? WHERE id = ?', [amount, fromId]);
          await db.rawUpdate('UPDATE wallets SET balance = balance - ? WHERE id = ?', [amount, toId]);
        }
      }
      await db.delete('transfers', where: 'id = ?', whereArgs: [id]);
      return;
    }

    if (type == 'installment') {
      // Find all transactions associated with this installment and reverse their wallet impact
      final allTxRows = await db.query('transactions', where: 'installment_id = ?', whereArgs: [id]);
      for (final row in allTxRows) {
        final wId = row['wallet_id'] as int?;
        final amt = (row['amount'] as num?)?.toDouble() ?? 0;
        final dir = row['direction'] as String? ?? 'min';
        if (wId != null && amt > 0) {
          if (dir == 'min') {
            await db.rawUpdate('UPDATE wallets SET balance = balance + ? WHERE id = ?', [amt, wId]);
          } else {
            await db.rawUpdate('UPDATE wallets SET balance = balance - ? WHERE id = ?', [amt, wId]);
          }
        }
      }
      await db.delete('installment_details', where: 'installment_id = ?', whereArgs: [id]);
      await db.delete('transactions', where: 'installment_id = ?', whereArgs: [id]);
      await db.delete('installments', where: 'id = ?', whereArgs: [id]);
      return;
    }

    // Default: income / expense transaction — reverse the wallet balance effect
    final txRows = await db.query('transactions', where: 'id = ?', whereArgs: [id], limit: 1);
    if (txRows.isNotEmpty) {
      final tx       = txRows.first;
      final walletId = tx['wallet_id'] as int?;
      final amount   = (tx['amount'] as num?)?.toDouble() ?? 0;
      final dir      = tx['direction'] as String? ?? 'min';
      // Skip reversal for the opening transaction of the salary wallet
      // to avoid double-counting (the wallet's balance was set directly).
      // We still reverse any regular (non-opening) income/expense.
      if (walletId != null && amount > 0) {
        if (dir == 'min') {
          // It was an expense → restore the deducted amount
          await db.rawUpdate('UPDATE wallets SET balance = balance + ? WHERE id = ?', [amount, walletId]);
        } else {
          // It was an income → remove the credited amount
          await db.rawUpdate('UPDATE wallets SET balance = balance - ? WHERE id = ?', [amount, walletId]);
        }
      }
    }
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getDebtTransactions(int debtId) async {
    final db = await database;
    return await db.rawQuery(
      'SELECT * FROM transactions WHERE debt_id = ? ORDER BY date DESC, id DESC',
      [debtId],
    );
  }

  Future<List<Map<String, dynamic>>> getInstallmentDetails(
    int installmentId,
  ) async {
    final db = await database;
    await _ensureInitialInstallmentDetailExists(db, installmentId);
    return await db.rawQuery(
      '''
      SELECT *
      FROM installment_details
      WHERE installment_id = ?
      ORDER BY is_initial DESC, due_date ASC, id ASC
      ''',
      [installmentId],
    );
  }

  // --- PERSON METHODS ---

  Future<List<Map<String, dynamic>>> getPersons() async {
    final db = await database;
    return await db.query('persons', orderBy: 'name ASC');
  }

  Future<int> addPerson(String name, String? phone) async {
    final db = await database;
    return await db.insert('persons', {'name': name, 'phone': phone});
  }

  Future<int> updatePerson(int id, String name, String? phone) async {
    final db = await database;
    return await db.update(
      'persons',
      {'name': name, 'phone': phone},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePerson(int id) async {
    final db = await database;
    return await db.delete('persons', where: 'id = ?', whereArgs: [id]);
  }

  // --- TRANSACTION UPDATE ---

  Future<void> updateTransaction(int id, Map<String, dynamic> updates) async {
    final db = await database;
    await db.update('transactions', updates, where: 'id = ?', whereArgs: [id]);
  }

  // --- REMINDER METHODS ---

  Future<List<Map<String, dynamic>>> getReminders() async {
    final db = await database;
    return await db.query('reminders', orderBy: 'scheduled_date ASC');
  }

  Future<int> addReminder({
    required String title,
    String? body,
    required String repeatType,
    required String scheduledDate,
  }) async {
    final db = await database;
    return await db.insert('reminders', {
      'type': 'custom',
      'title': title,
      'body': body,
      'repeat_type': repeatType,
      'start_date': DateTime.now().toIso8601String(),
      'scheduled_date': scheduledDate,
      'is_active': 1,
    });
  }

  Future<int> deleteReminder(int id) async {
    final db = await database;
    return await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> hasPersonDependencies(int id) async {
    final db = await database;
    final debts = await db.query(
      'debts',
      where: 'person_id = ?',
      whereArgs: [id],
    );
    final installments = await db.query(
      'installments',
      where: 'person_id = ?',
      whereArgs: [id],
    );
    return debts.isNotEmpty || installments.isNotEmpty;
  }

  Future<void> importDeviceContacts(List<Map<String, String>> contacts) async {
    final db = await database;
    final batch = db.batch();
    for (final contact in contacts) {
      batch.insert('persons', {
        'name': contact['name'],
        'phone': contact['phone'],
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> toggleInstallmentDetailPaid(int detailId, int walletId) async {
    final db = await database;
    final detail = await db.query(
      'installment_details',
      where: 'id = ?',
      whereArgs: [detailId],
    );
    if (detail.isEmpty) return;
    final row = detail.first;
    final isPaid = row['is_paid'] == 1;
    final amount = (row['amount'] as num).toDouble();
    final installmentId = row['installment_id'] as int;
    final installmentRows = await db.query(
      'installments',
      columns: ['type'],
      where: 'id = ?',
      whereArgs: [installmentId],
      limit: 1,
    );
    final installmentType = installmentRows.isNotEmpty
        ? installmentRows.first['type'] as String?
        : null;
    final isForYou = installmentType == 'for_you';

    if (isPaid) {
      final paidWalletId = row['wallet_id'] as int?;
      await db.update(
        'installment_details',
        {'is_paid': 0, 'paid_at': null, 'wallet_id': null},
        where: 'id = ?',
        whereArgs: [detailId],
      );
      if (paidWalletId != null && paidWalletId > 0) {
        await db.rawUpdate(
          'UPDATE wallets SET balance = balance ${isForYou ? '-' : '+'} ? WHERE id = ?',
          [amount, paidWalletId],
        );
      }
    } else {
      if (walletId <= 0) return;
      await db.update(
        'installment_details',
        {
          'is_paid': 1,
          'paid_at': DateTime.now().toIso8601String(),
          'wallet_id': walletId,
        },
        where: 'id = ?',
        whereArgs: [detailId],
      );
      await db.rawUpdate(
        'UPDATE wallets SET balance = balance ${isForYou ? '+' : '-'} ? WHERE id = ?',
        [amount, walletId],
      );
    }

    await _recalculateInstallmentState(db, installmentId);
  }

  Future<void> _ensureInitialInstallmentDetailExists(Database db, int installmentId) async {
    final installmentRows = await db.query(
      'installments',
      columns: ['deposit', 'created_at', 'wallet_id'],
      where: 'id = ?',
      whereArgs: [installmentId],
      limit: 1,
    );
    if (installmentRows.isEmpty) return;

    final installment = installmentRows.first;
    final deposit = (installment['deposit'] as num?)?.toDouble() ?? 0.0;
    if (deposit <= 0) return;

    final existingRows = await db.query(
      'installment_details',
      where: 'installment_id = ? AND is_initial = 1',
      whereArgs: [installmentId],
      limit: 1,
    );
    if (existingRows.isNotEmpty) return;

    await db.insert('installment_details', {
      'installment_id': installmentId,
      'due_date': (installment['created_at'] as String?) ?? DateTime.now().toIso8601String(),
      'amount': deposit,
      'is_paid': 1,
      'paid_at': (installment['created_at'] as String?) ?? DateTime.now().toIso8601String(),
      'wallet_id': installment['wallet_id'],
      'is_initial': 1,
    });
  }

  Future<void> addDebtPayment({
    required int debtId,
    required double amount,
    required String direction,
    required int walletId,
    String? notes,
  }) async {
    final db = await database;
    final debt = await db.query('debts', where: 'id = ?', whereArgs: [debtId]);
    if (debt.isEmpty) return;

    final personId = debt.first['person_id'] as int;
    final categoryId = direction == 'plus' ? 3 : 4;

    final settings = await db.query('settings', limit: 1);
    final currencyId =
        settings.isNotEmpty
            ? (settings.first['default_currency_id'] as int?) ?? 1
            : 1;

    await db.insert('transactions', {
      'wallet_id': walletId,
      'category_id': categoryId,
      'person_id': personId,
      'currency_id': currencyId,
      'type': 'debt',
      'direction': direction,
      'amount': amount,
      'date': DateTime.now().toIso8601String(),
      'is_paid': 1,
      'debt_id': debtId,
      'notes': notes,
    });

    if (direction == 'min') {
      await db.rawUpdate(
        'UPDATE wallets SET balance = balance - ? WHERE id = ?',
        [amount, walletId],
      );
    } else {
      await db.rawUpdate(
        'UPDATE wallets SET balance = balance + ? WHERE id = ?',
        [amount, walletId],
      );
    }

    await _recalculateDebtState(db, debtId);
  }

  Future<void> _recalculateInstallmentState(Database db, int installmentId) async {
    await _ensureInitialInstallmentDetailExists(db, installmentId);
    final result = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN is_paid = 0 THEN amount ELSE 0 END), 0) AS remaining_price,
        COALESCE(SUM(CASE WHEN is_initial = 0 AND is_paid = 0 THEN 1 ELSE 0 END), 0) AS remaining_months,
        COALESCE(SUM(CASE WHEN is_initial = 0 THEN 1 ELSE 0 END), 0) AS total_months,
        COALESCE(SUM(CASE WHEN is_initial = 0 AND is_paid = 1 THEN 1 ELSE 0 END), 0) AS paid_regular_months
      FROM installment_details
      WHERE installment_id = ?
      ''',
      [installmentId],
    );

    if (result.isEmpty) return;

    final row = result.first;
    final remainingPrice = (row['remaining_price'] as num?)?.toDouble() ?? 0.0;
    final remainingMonths = (row['remaining_months'] as num?)?.toInt() ?? 0;
    final totalMonths = (row['total_months'] as num?)?.toInt() ?? 0;
    final paidRegularMonths = (row['paid_regular_months'] as num?)?.toInt() ?? 0;

    String status = 'active';
    if (remainingPrice == 0) {
      status = 'paid';
    } else if (paidRegularMonths > 0 && remainingMonths < totalMonths) {
      status = 'partial';
    }

    await db.update(
      'installments',
      {
        'remaining_price': remainingPrice,
        'remaining_months': remainingMonths,
        'status': status,
      },
      where: 'id = ?',
      whereArgs: [installmentId],
    );
  }

  Future<void> _recalculateDebtState(Database db, int debtId) async {
    final txRows = await db.query(
      'transactions',
      where: 'debt_id = ?',
      whereArgs: [debtId],
      orderBy: 'is_opening DESC, id ASC',
    );
    if (txRows.isEmpty) return;

    double totalPlus = 0.0;
    double totalMin = 0.0;

    for (final row in txRows) {
      final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
      if ((row['direction'] as String?) == 'plus') {
        totalPlus += amount;
      } else {
        totalMin += amount;
      }
    }

    final netBalance = totalPlus - totalMin;
    final outstanding = netBalance.abs();

    String status = 'active';
    if (outstanding == 0) {
      status = 'paid';
    } else if (totalPlus > 0 && totalMin > 0) {
      status = 'partial';
    }

    await db.update(
      'debts',
      {
        'income': netBalance > 0 ? outstanding : 0.0,
        'expense': netBalance < 0 ? outstanding : 0.0,
        'status': status,
      },
      where: 'id = ?',
      whereArgs: [debtId],
    );
  }

  Future<void> _normalizeAllInstallmentStates(Database db) async {
    final rows = await db.query('installments', columns: ['id']);
    for (final row in rows) {
      final id = row['id'] as int?;
      if (id != null) {
        await _recalculateInstallmentState(db, id);
      }
    }
  }

  Future<void> _normalizeAllDebtStates(Database db) async {
    final rows = await db.query('debts', columns: ['id']);
    for (final row in rows) {
      final id = row['id'] as int?;
      if (id != null) {
        await _recalculateDebtState(db, id);
      }
    }
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // --- SQL SCRIPTS ---
  static const _sqlAllCurrencies = '''
    CREATE TABLE IF NOT EXISTS all_currencies (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      currency_name_ar TEXT,
      currency_name_en TEXT NOT NULL,
      country_code TEXT NOT NULL,
      currency_code TEXT NOT NULL,
      currency_symbol TEXT,
      rate_to_usd REAL NOT NULL DEFAULT 1.0000,
      is_default INTEGER DEFAULT 0,
      flag TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP
    );
  ''';

  static const _sqlCategories = '''
    CREATE TABLE IF NOT EXISTS categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name_ar TEXT NOT NULL,
      name_en TEXT NOT NULL,
      image_name TEXT,
      type TEXT CHECK(type IN ('income', 'expense', 'debt', 'installment')) NOT NULL,
      parent_id INTEGER,
      FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE SET NULL
    );
  ''';

  static const int _dbVersion = 16;

  static const _sqlPersons = '''
    CREATE TABLE IF NOT EXISTS persons (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      phone TEXT
    );
  ''';

  static const _sqlWallets = '''
    CREATE TABLE IF NOT EXISTS wallets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      type TEXT CHECK(type IN ('cash', 'bank', 'investment', 'other', 'credit_card')) DEFAULT 'cash',
      balance REAL DEFAULT 0,
      currency_id INTEGER,
      hide INTEGER DEFAULT 0, 
      bloc INTEGER DEFAULT 0,
      is_visible INTEGER DEFAULT 1,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (currency_id) REFERENCES all_currencies(id)
    );
  ''';

  static const _sqlDebts = '''
    CREATE TABLE IF NOT EXISTS debts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      person_id INTEGER NOT NULL,
      wallet_id INTEGER NOT NULL,
      category_id INTEGER NOT NULL,
      income REAL NOT NULL,
      expense REAL NOT NULL,
      status TEXT CHECK(status IN ('active', 'partial', 'paid')) DEFAULT 'active',
      due_date TEXT,
      notes TEXT,
      image_path TEXT,
      FOREIGN KEY (person_id) REFERENCES persons(id) ON DELETE CASCADE,
      FOREIGN KEY (wallet_id) REFERENCES wallets(id) ON DELETE CASCADE,
      FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
    );
  ''';

  static const _sqlInstallments = '''
    CREATE TABLE IF NOT EXISTS installments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      person_id INTEGER NOT NULL,
      wallet_id INTEGER NOT NULL,
      category_id INTEGER NOT NULL,
      deposit REAL NOT NULL,
      last_payment REAL NOT NULL DEFAULT 0,
      remaining_price REAL NOT NULL,
      total_months INTEGER NOT NULL,
      remaining_months INTEGER NOT NULL,
      status TEXT CHECK(status IN ('active', 'partial', 'paid')) DEFAULT 'active',
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      notes TEXT,
      type TEXT,
      image_path TEXT,
      FOREIGN KEY (person_id) REFERENCES persons(id) ON DELETE CASCADE,
      FOREIGN KEY (wallet_id) REFERENCES wallets(id) ON DELETE CASCADE,
      FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
    );
  ''';

  static const _sqlMonthlyBudgets = '''
    CREATE TABLE IF NOT EXISTS monthly_budgets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      wallet_id INTEGER,
      category_id INTEGER,
      amount_limit REAL,
      month INTEGER,
      year INTEGER,
      FOREIGN KEY (wallet_id) REFERENCES wallets(id),
      FOREIGN KEY (category_id) REFERENCES categories(id)
    );
  ''';

  static const _sqlRecurringTransactions = '''
    CREATE TABLE IF NOT EXISTS recurring_transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      transaction_id INTEGER NOT NULL,
      start_date TEXT NOT NULL,
      next_execution_date TEXT NOT NULL,
      repeat_type TEXT CHECK(repeat_type IN ('daily', 'weekly', 'monthly', 'yearly')) NOT NULL,
      is_active INTEGER DEFAULT 1,
      auto_add INTEGER NOT NULL DEFAULT 0,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
    );
  ''';

  static const _sqlReminders = '''
    CREATE TABLE IF NOT EXISTS reminders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT CHECK(type IN ('expense', 'debt', 'custom')) NOT NULL DEFAULT 'custom',
      title TEXT,
      body TEXT,
      repeat_type TEXT CHECK(repeat_type IN ('once', 'daily', 'weekly', 'monthly')),
      start_date TEXT,
      scheduled_date TEXT,
      is_active INTEGER DEFAULT 1
    );
  ''';

  static const _sqlSettings = '''
    CREATE TABLE IF NOT EXISTS settings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_name TEXT NOT NULL,
      default_currency_id INTEGER,
      default_wallet_id INTEGER,
      salary_amount REAL,
      salary_day INTEGER,
      salary_date TEXT DEFAULT CURRENT_TIMESTAMP,
      is_first_setup_done INTEGER DEFAULT 0,
      FOREIGN KEY (default_currency_id) REFERENCES all_currencies(id),
      FOREIGN KEY (default_wallet_id) REFERENCES wallets(id)
    );
  ''';

  static const _sqlTransactions = '''
    CREATE TABLE IF NOT EXISTS transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      wallet_id INTEGER NOT NULL,
      category_id INTEGER,
      person_id INTEGER,
      currency_id INTEGER NOT NULL,
      type TEXT CHECK(type IN ('income', 'expense', 'debt', 'installment')) NOT NULL,
      direction TEXT CHECK(direction IN ('plus', 'min')) NOT NULL,
      amount REAL NOT NULL,
      date TEXT DEFAULT CURRENT_TIMESTAMP,
      is_paid INTEGER DEFAULT 1,
      paid_at TEXT,
      due_date TEXT,
      person_name TEXT,
      notes TEXT,
      image_url TEXT,
      debt_id INTEGER,
      installment_id INTEGER,
      recurring_id INTEGER,
      priority INTEGER NOT NULL DEFAULT 1,
      is_repeat INTEGER NOT NULL DEFAULT 0,
      is_opening INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (wallet_id) REFERENCES wallets(id) ON DELETE CASCADE,
      FOREIGN KEY (category_id) REFERENCES categories(id),
      FOREIGN KEY (currency_id) REFERENCES all_currencies(id),
      FOREIGN KEY (person_id) REFERENCES persons(id) ON DELETE CASCADE,
      FOREIGN KEY (debt_id) REFERENCES debts(id) ON DELETE CASCADE,
      FOREIGN KEY (installment_id) REFERENCES installments(id) ON DELETE CASCADE,
      FOREIGN KEY (recurring_id) REFERENCES recurring_transactions(id) ON DELETE SET NULL
    );
  ''';

  static const _sqlInstallmentDetails = '''
    CREATE TABLE IF NOT EXISTS installment_details (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      installment_id INTEGER NOT NULL,
      due_date TEXT NOT NULL,
      amount REAL NOT NULL,
      is_paid INTEGER DEFAULT 0,
      paid_at TEXT,
      wallet_id INTEGER,
      is_initial INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (installment_id) REFERENCES installments(id) ON DELETE CASCADE
    );
  ''';

  static const _sqlTransfers = '''
    CREATE TABLE IF NOT EXISTS transfers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      from_wallet_id INTEGER NOT NULL,
      to_wallet_id INTEGER NOT NULL,
      amount REAL NOT NULL,
      date TEXT DEFAULT CURRENT_TIMESTAMP,
      notes TEXT,
      FOREIGN KEY (from_wallet_id) REFERENCES wallets(id),
      FOREIGN KEY (to_wallet_id) REFERENCES wallets(id)
    );
  ''';

  static const _sqlScheduledNotifications = '''
    CREATE TABLE IF NOT EXISTS scheduled_notifications (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      notification_id INTEGER UNIQUE NOT NULL,
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      payload TEXT,
      scheduled_time TEXT NOT NULL,
      repeat_interval TEXT,
      is_active INTEGER DEFAULT 1,
      transaction_id INTEGER
    );
  ''';

  static const _sqlInsertCategories = '''
    INSERT OR IGNORE INTO categories (id , name_ar, name_en, type, parent_id, image_name) VALUES 
    (1, 'سحب رصيد', 'Withdraw Balance', 'expense', NULL, 'with_draw'),
    (2, 'تحويل رصيد', 'Transfer Balance', 'expense', NULL, 'transfer'),
    
    -- Debts
    (3, 'دفع ديون', 'Pay Debts', 'debt', NULL, 'debt'),
    (4, 'استلام ديون', 'Receive Debts', 'debt', NULL, 'receive_debt'),
    
    -- Installments
    (1001, 'دفع أقساط', 'Pay Installments', 'installment', NULL, 'installment'),
    (1002, 'استلام أقساط', 'Receive Installments', 'installment', NULL, 'installment'),
    
    -- Income
    (5, 'الراتب', 'Salary', 'income', NULL, 'salary'),
    (6, 'علاوة', 'Bonus', 'income', NULL, 'bonus'),
    (7, 'دخل الأعمال', 'Business Income', 'income', NULL, 'business'),
    (8, 'استثمارات', 'Investments', 'income', NULL, 'investment'),
    (9, 'هدايا', 'Gifts', 'income', NULL, 'gift'),
    (10, 'دخل آخر', 'Other Income', 'income', NULL, 'other'),

    -- Expenses - Housing
    (11, 'السكن', 'Housing', 'expense', NULL, 'housing'),
    (12, 'إيجار', 'Rent', 'expense', 11, 'rent'),
    (13, 'قرض عقاري', 'Mortgage', 'expense', 11, 'mortgage'),
    (14, 'خدمات ومرافق', 'Utilities & Bills', 'expense', 11, 'utilities'),
    (15, 'صيانة وإصلاحات', 'Maintenance & Repairs', 'expense', 11, 'maintenance'),
    (16, 'ضريبة عقار', 'Property Tax', 'expense', 11, 'tax'),

    -- Expenses - Utilities & Bills
    (20, 'الفواتير', 'Utilities & Bills', 'expense', NULL, 'bills'),
    (21, 'كهرباء', 'Electricity', 'expense', 20, 'electricity'),
    (22, 'ماء', 'Water', 'expense', 20, 'water'),
    (23, 'إنترنت', 'Internet', 'expense', 20, 'internet'),
    (24, 'هاتف جوال', 'Mobile', 'expense', 20, 'mobile'),

    -- Expenses - Transportation
    (30, 'المواصلات', 'Transportation', 'expense', NULL, 'transport'),
    (31, 'وقود', 'Fuel', 'expense', 30, 'fuel'),
    (32, 'صيانة', 'Maintenance', 'expense', 30, 'maintenance_car'),
    (33, 'تأمين', 'Insurance', 'expense', 30, 'insurance_car'),
    (34, 'مواقف', 'Parking', 'expense', 30, 'parking'),
    (35, 'مواصلات عامة', 'Public Transport', 'expense', 30, 'bus'),
    (36, 'غرامات ومخالفات', 'Fines', 'expense', 30, 'fine'),

    -- Expenses - Food
    (40, 'الطعام', 'Food', 'expense', NULL, 'food'),
    (41, 'بقالة', 'Groceries', 'expense', 40, 'groceries'),
    (42, 'مطاعم', 'Restaurants', 'expense', 40, 'restaurants'),
    (43, 'قهوة ووجبات خفيفة', 'Coffee & Snacks', 'expense', 40, 'coffee'),

    -- Expenses - Health
    (50, 'الصحة', 'Health', 'expense', NULL, 'health'),
    (51, 'فواتير طبية', 'Medical Bills', 'expense', 50, 'hospital'),
    (52, 'صيدلية', 'Pharmacy', 'expense', 50, 'pharmacy'),
    (53, 'تأمين صحي', 'Health Insurance', 'expense', 50, 'health_insurance'),

    -- Expenses - Education
    (60, 'التعليم', 'Education', 'expense', NULL, 'education'),
    (61, 'رسوم دراسية', 'Tuition', 'expense', 60, 'tuition'),
    (62, 'كتب ولوازم', 'Books & Supplies', 'expense', 60, 'books'),
    (63, 'دورات وتدريب', 'Courses & Training', 'expense', 60, 'course'),

    -- Expenses - Personal Care
    (70, 'العناية الشخصية', 'Personal Care', 'expense', NULL, 'personal_care'),
    (71, 'ملابس', 'Clothes', 'expense', 70, 'clothes'),
    (72, 'حلاقة وتجميل', 'Hair & Beauty', 'expense', 70, 'barber'),
    (73, 'مستحضرات تجميل', 'Cosmetics', 'expense', 70, 'cosmetics'),

    -- Expenses - Entertainment
    (80, 'الترفيه', 'Entertainment', 'expense', NULL, 'entertainment'),
    (81, 'اشتراكات', 'Subscriptions', 'expense', 80, 'subscriptions'),
    (82, 'سينما وفعاليات', 'Cinema & Events', 'expense', 80, 'cinema'),
    (83, 'هوايات', 'Hobbies', 'expense', 80, 'hobby'),

    -- Expenses - Family & Kids
    (90, 'الأسرة والأطفال', 'Family & Kids', 'expense', NULL, 'family'),
    (91, 'رعاية أطفال', 'Childcare', 'expense', 90, 'childcare'),
    (92, 'رسوم مدرسية', 'School Fees', 'expense', 90, 'school'),
    (93, 'ألعاب', 'Toys', 'expense', 90, 'toys'),

    -- Expenses - Pets
    (100, 'الحيوانات الأليفة', 'Pets', 'expense', NULL, 'pets'),
    (101, 'طعام ومستلزمات', 'Food & Supplies', 'expense', 100, 'pet_food'),
    (102, 'بيطري', 'Vet', 'expense', 100, 'vet'),

    -- Expenses - Gifts & Donations
    (110, 'الهدايا والتبرعات', 'Gifts & Donations', 'expense', NULL, 'gifts_given'),
    (111, 'هدايا مقدمة', 'Gifts Given', 'expense', 110, 'gift_box'),
    (112, 'صدقات وتبرعات', 'Charity & Donations', 'expense', 110, 'charity'),

    -- Expenses - Savings & Investments
    (120, 'الادخار والاستثمار', 'Savings & Investments', 'expense', NULL, 'savings_invest'),
    (121, 'صندوق طوارئ', 'Emergency Fund', 'expense', 120, 'emergency'),
    (122, 'ادخار تقاعد', 'Retirement', 'expense', 120, 'retirement'),
    (123, 'استثمار أسهم', 'Stocks', 'expense', 120, 'stocks'),

    -- Expenses - Debt & Loans
    (130, 'الديون والقروض', 'Debt & Loans', 'expense', NULL, 'debt_loans'),
    (131, 'أقساط القروض', 'Loan Installments', 'expense', 130, 'loan_payment'),
    (132, 'مدفوعات بطاقة الائتمان', 'Credit Card Payments', 'expense', 130, 'credit_card_pay'),

    -- Expenses - Insurance
    (140, 'التأمين', 'Insurance', 'expense', NULL, 'insurance'),
    (141, 'تأمين صحي', 'Health Insurance', 'expense', 140, 'health_insurance_alt'),
    (142, 'تأمين سيارة', 'Car Insurance', 'expense', 140, 'car_insurance'),
    (143, 'تأمين حياة', 'Life Insurance', 'expense', 140, 'life_insurance'),

    -- Expenses - Miscellaneous
    (150, 'متفرقات', 'Miscellaneous', 'expense', NULL, 'misc'),
    (151, 'مصروفات غير مخططة', 'Unplanned', 'expense', 150, 'unplanned'),
    (152, 'أخرى', 'Other', 'expense', 150, 'other_expense');
  ''';
}
