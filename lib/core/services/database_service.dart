import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'expensia.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
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
      _sqlInsertCurrencies,
      _sqlInsertCategories,
    ]);
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

  Future<void> initializeSetup({
    required String name,
    required int defaultCurrencyId,
    required double cashBalance,
    required double salaryAmount,
    required int salaryDay,
    required bool hasSalary,
    required bool autoAddSalary,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      // 1. Clear existing dynamic data (for a fresh setup)
      await txn.delete('recurring_transactions');
      await txn.delete('wallets');
      await txn.delete('transactions');
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
        'name': 'Cash',
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
          'notes': 'Initial Balance',
        });
      }

      // 5. Handle Salary if enabled
      if (hasSalary && salaryAmount > 0) {
        final salaryWalletId = await txn.insert('wallets', {
          'name': 'Salary Account',
          'type': 'bank',
          'balance': 0.0,
          'currency_id': defaultCurrencyId,
          'is_visible': 1,
        });

        // Add Recurring Salary
        final transactionId = await txn.insert('transactions', {
          'wallet_id': salaryWalletId,
          'category_id': 5, // Salary
          'currency_id': defaultCurrencyId,
          'type': 'income',
          'direction': 'plus',
          'amount': salaryAmount,
          'is_repeat': 1,
          'date': DateTime.now().toIso8601String(),
        });

        if (autoAddSalary) {
          final nextDate = _calculateNextSalaryDate(salaryDay);
          await txn.insert('recurring_transactions', {
            'transaction_id': transactionId,
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
      type TEXT CHECK(type IN ('income', 'expense', 'debt')) NOT NULL,
      parent_id INTEGER,
      FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE SET NULL
    );
  ''';

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
      type TEXT CHECK(type IN ('cash', 'bank', 'other','credit_card')) DEFAULT 'cash',
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
      type TEXT CHECK(type IN ('expense', 'debt')) NOT NULL,
      title TEXT,
      repeat_type TEXT CHECK(repeat_type IN ('daily', 'weekly', 'monthly')),
      start_date TEXT,
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

  static const _sqlInsertCurrencies = '''
    INSERT OR IGNORE INTO all_currencies (id, currency_name_ar, currency_name_en, country_code, currency_code, currency_symbol, rate_to_usd, is_default, flag) VALUES
    (1, 'الريال السعودي', 'Saudi Riyal', 'SA', 'SAR', '﷼', 0.2666, 1, 'sa.svg'),
    (2, 'الجنيه المصري', 'Egyptian Pound', 'EG', 'EGP', '£', 0.0205, 0, 'eg.svg'),
    (3, 'الدرهم الإماراتي', 'UAE Dirham', 'AE', 'AED', 'د.إ', 0.2723, 0, 'ae.svg'),
    (4, 'الدينار الكويتي', 'Kuwaiti Dinar', 'KW', 'KWD', 'د.ك', 3.25, 0, 'kw.svg'),
    (5, 'الدرهم المغربي', 'Moroccan Dirham', 'MA', 'MAD', 'د.م.', 0.099, 0, 'ma.svg'),
    (6, 'الدينار الجزائري', 'Algerian Dinar', 'DZ', 'DZD', 'د.ج', 0.0074, 0, 'dz.svg'),
    (7, 'الليرة اللبنانية', 'Lebanese Pound', 'LB', 'LBP', 'ل.ل', 0.000011, 0, 'lb.svg'),
    (8, 'الليرة السورية', 'Syrian Pound', 'SY', 'SYP', '£', 0.00008, 0, 'sy.svg'),
    (9, 'الدينار التونسي', 'Tunisian Dinar', 'TN', 'TND', 'د.ت', 0.32, 0, 'tn.svg'),
    (10, 'الريال اليمني', 'Yemeni Rial', 'YE', 'YER', '﷼', 0.004, 0, 'ye.svg'),
    (11, 'الدولار الأمريكي', 'US Dollar', 'US', 'USD', '\$', 1.0, 0, 'us.svg'),
    (12, 'اليورو', 'Euro', 'EU', 'EUR', '€', 1.07, 0, 'eu.svg'),
    (13, 'الين الياباني', 'Japanese Yen', 'JP', 'JPY', '¥', 0.0064, 0, 'jp.svg'),
    (14, 'الجنيه الإسترليني', 'British Pound', 'GB', 'GBP', '£', 1.27, 0, 'gb.svg'),
    (15, 'اليوان الصيني', 'Chinese Yuan', 'CN', 'CNY', '¥', 0.14, 0, 'cn.svg'),
    (16, 'الروبية الهندية', 'Indian Rupee', 'IN', 'INR', '₹', 0.012, 0, 'in.svg'),
    (17, 'الدولار الكندي', 'Canadian Dollar', 'CA', 'CAD', '\$', 0.73, 0, 'ca.svg'),
    (18, 'الفرنك السويسري', 'Swiss Franc', 'CH', 'CHF', 'Fr', 1.12, 0, 'ch.svg'),
    (19, 'الدولار الأسترالي', 'Australian Dollar', 'AU', 'AUD', '\$', 0.66, 0, 'au.svg'),
    (20, 'الريال القطري', 'Qatari Riyal', 'QA', 'QAR', 'ر.ق', 0.2747, 0, 'qa.svg');
  ''';

  static const _sqlInsertCategories = '''
    INSERT OR IGNORE INTO categories (id , name_ar, name_en, type, parent_id, image_name) VALUES 
    (1, 'سحب رصيد', 'Withdraw Balance', 'expense', NULL, 'assets/images/category_png/with_draw.png'),
    (2, 'تحويل رصيد', 'Transfer Balance', 'expense', NULL, 'assets/images/category_png/with_draw.png'),
    (3, 'دفع ديون وأقساط', 'Pay Debts & Installments', 'debt', NULL, 'assets/images/category_png/with_draw.png'),
    (4, 'استلام ديون وأقساط', 'Receive Debts & Installments', 'debt', NULL, 'assets/images/category_png/with_draw.png'),
    (5, 'الراتب', 'Salary', 'income', NULL, 'assets/images/category_png/with_draw.png'),
    (6, 'إضافة رصيد', 'Add Balance', 'income', NULL, 'assets/images/category_png/with_draw.png'),
    (7, 'السكن', 'Housing', 'expense', NULL, 'assets/images/category_png/1.png'),
    (8, 'إيجار', 'Rent', 'expense', 7, 'assets/images/category_png/2.png'),
    (25, 'الطعام', 'Food', 'expense', NULL, 'assets/images/category_png/19.png'),
    (26, 'بقالة', 'Groceries', 'expense', 25, 'assets/images/category_png/20.png'),
    (27, 'مطاعم', 'Restaurants', 'expense', 25, 'assets/images/category_png/21.png');
  ''';
}
