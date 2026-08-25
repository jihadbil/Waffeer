import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../../data/models/category_model.dart';
import '../../data/models/wallet_model.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/recurring_transaction_model.dart';
import '../../data/models/budget_model.dart';
import '../../data/models/goal_model.dart';
import '../../data/models/debt_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('waffeer.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Categories Table
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name_en TEXT NOT NULL,
        name_ar TEXT NOT NULL,
        icon_code_point INTEGER NOT NULL,
        icon_font_family TEXT,
        color_value INTEGER NOT NULL,
        type TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Wallets Table
    await db.execute('''
      CREATE TABLE wallets (
        id TEXT PRIMARY KEY,
        name_en TEXT NOT NULL,
        name_ar TEXT NOT NULL,
        initial_balance REAL NOT NULL DEFAULT 0.0,
        current_balance REAL NOT NULL DEFAULT 0.0,
        currency_code TEXT NOT NULL,
        icon_code_point INTEGER NOT NULL,
        icon_font_family TEXT,
        color_value INTEGER NOT NULL,
        type TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Transactions Table
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category_id TEXT NOT NULL,
        wallet_id TEXT NOT NULL,
        to_wallet_id TEXT,
        date_time TEXT NOT NULL,
        title TEXT,
        note TEXT,
        receipt_image_path TEXT,
        currency_code TEXT NOT NULL,
        is_recurring INTEGER NOT NULL DEFAULT 0,
        tag TEXT,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE,
        FOREIGN KEY (wallet_id) REFERENCES wallets (id) ON DELETE CASCADE
      )
    ''');

    // Recurring Transactions Table
    await db.execute('''
      CREATE TABLE recurring_transactions (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category_id TEXT NOT NULL,
        wallet_id TEXT NOT NULL,
        to_wallet_id TEXT,
        title TEXT NOT NULL,
        note TEXT,
        frequency TEXT NOT NULL,
        start_date TEXT NOT NULL,
        next_due_date TEXT NOT NULL,
        last_executed_date TEXT,
        currency_code TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Budgets Table
    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        category_id TEXT,
        limit_amount REAL NOT NULL,
        period TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        currency_code TEXT NOT NULL,
        notify_80 INTEGER NOT NULL DEFAULT 1,
        notify_exceed INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Goals Table
    await db.execute('''
      CREATE TABLE goals (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        target_amount REAL NOT NULL,
        saved_amount REAL NOT NULL DEFAULT 0.0,
        target_date TEXT NOT NULL,
        currency_code TEXT NOT NULL,
        icon_code_point INTEGER NOT NULL,
        icon_font_family TEXT,
        color_value INTEGER NOT NULL,
        note TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Debts Table
    await db.execute('''
      CREATE TABLE debts (
        id TEXT PRIMARY KEY,
        person_name TEXT NOT NULL,
        total_amount REAL NOT NULL,
        paid_amount REAL NOT NULL DEFAULT 0.0,
        type TEXT NOT NULL,
        due_date TEXT NOT NULL,
        created_date TEXT NOT NULL,
        currency_code TEXT NOT NULL,
        phone_number TEXT,
        note TEXT,
        is_settled INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Seed default categories
    for (final cat in CategoryModel.defaultCategories) {
      await db.insert('categories', cat.toMap());
    }
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS recurring_transactions (
          id TEXT PRIMARY KEY,
          amount REAL NOT NULL,
          type TEXT NOT NULL,
          category_id TEXT NOT NULL,
          wallet_id TEXT NOT NULL,
          to_wallet_id TEXT,
          title TEXT NOT NULL,
          note TEXT,
          frequency TEXT NOT NULL,
          start_date TEXT NOT NULL,
          next_due_date TEXT NOT NULL,
          last_executed_date TEXT,
          currency_code TEXT NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1
        )
      ''');
    }
  }

  // Seed default wallets when currency is set by user
  Future<void> seedDefaultWalletsIfEmpty(String currencyCode) async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM wallets')) ?? 0;
    if (count == 0) {
      for (final wallet in WalletModel.defaultWallets(currencyCode)) {
        await db.insert('wallets', wallet.toMap());
      }
    }
  }

  // ---------------- CATEGORIES CRUD ----------------
  Future<List<CategoryModel>> getAllCategories() async {
    final db = await instance.database;
    final result = await db.query('categories');
    return result.map((json) => CategoryModel.fromMap(json)).toList();
  }

  Future<int> insertCategory(CategoryModel category) async {
    final db = await instance.database;
    return await db.insert('categories', category.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateCategory(CategoryModel category) async {
    final db = await instance.database;
    return await db.update('categories', category.toMap(), where: 'id = ?', whereArgs: [category.id]);
  }

  Future<int> deleteCategory(String id) async {
    final db = await instance.database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- WALLETS CRUD ----------------
  Future<List<WalletModel>> getAllWallets() async {
    final db = await instance.database;
    final result = await db.query('wallets');
    return result.map((json) => WalletModel.fromMap(json)).toList();
  }

  Future<int> insertWallet(WalletModel wallet) async {
    final db = await instance.database;
    return await db.insert('wallets', wallet.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateWallet(WalletModel wallet) async {
    final db = await instance.database;
    return await db.update('wallets', wallet.toMap(), where: 'id = ?', whereArgs: [wallet.id]);
  }

  Future<int> deleteWallet(String id) async {
    final db = await instance.database;
    return await db.delete('wallets', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- TRANSACTIONS CRUD ----------------
  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await instance.database;
    final result = await db.query('transactions', orderBy: 'date_time DESC');
    return result.map((json) => TransactionModel.fromMap(json)).toList();
  }

  Future<int> insertTransaction(TransactionModel tx) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final id = await txn.insert('transactions', tx.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      // Update Wallet Balance
      if (tx.type == TransactionType.expense) {
        await txn.rawUpdate(
          'UPDATE wallets SET current_balance = current_balance - ? WHERE id = ?',
          [tx.amount, tx.walletId],
        );
      } else if (tx.type == TransactionType.income) {
        await txn.rawUpdate(
          'UPDATE wallets SET current_balance = current_balance + ? WHERE id = ?',
          [tx.amount, tx.walletId],
        );
      } else if (tx.type == TransactionType.transfer && tx.toWalletId != null) {
        await txn.rawUpdate(
          'UPDATE wallets SET current_balance = current_balance - ? WHERE id = ?',
          [tx.amount, tx.walletId],
        );
        await txn.rawUpdate(
          'UPDATE wallets SET current_balance = current_balance + ? WHERE id = ?',
          [tx.amount, tx.toWalletId],
        );
      }
      return id;
    });
  }

  Future<int> deleteTransaction(TransactionModel tx) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      // Revert wallet balance changes
      if (tx.type == TransactionType.expense) {
        await txn.rawUpdate(
          'UPDATE wallets SET current_balance = current_balance + ? WHERE id = ?',
          [tx.amount, tx.walletId],
        );
      } else if (tx.type == TransactionType.income) {
        await txn.rawUpdate(
          'UPDATE wallets SET current_balance = current_balance - ? WHERE id = ?',
          [tx.amount, tx.walletId],
        );
      } else if (tx.type == TransactionType.transfer && tx.toWalletId != null) {
        await txn.rawUpdate(
          'UPDATE wallets SET current_balance = current_balance + ? WHERE id = ?',
          [tx.amount, tx.walletId],
        );
        await txn.rawUpdate(
          'UPDATE wallets SET current_balance = current_balance - ? WHERE id = ?',
          [tx.amount, tx.toWalletId],
        );
      }

      return await txn.delete('transactions', where: 'id = ?', whereArgs: [tx.id]);
    });
  }

  // ---------------- RECURRING TRANSACTIONS CRUD ----------------
  Future<List<RecurringTransactionModel>> getAllRecurring() async {
    final db = await instance.database;
    final result = await db.query('recurring_transactions', orderBy: 'next_due_date ASC');
    return result.map((json) => RecurringTransactionModel.fromMap(json)).toList();
  }

  Future<int> insertRecurring(RecurringTransactionModel rec) async {
    final db = await instance.database;
    return await db.insert('recurring_transactions', rec.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateRecurring(RecurringTransactionModel rec) async {
    final db = await instance.database;
    return await db.update('recurring_transactions', rec.toMap(), where: 'id = ?', whereArgs: [rec.id]);
  }

  Future<int> deleteRecurring(String id) async {
    final db = await instance.database;
    return await db.delete('recurring_transactions', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- BUDGETS CRUD ----------------
  Future<List<BudgetModel>> getAllBudgets() async {
    final db = await instance.database;
    final result = await db.query('budgets');
    return result.map((json) => BudgetModel.fromMap(json)).toList();
  }

  Future<int> insertBudget(BudgetModel budget) async {
    final db = await instance.database;
    return await db.insert('budgets', budget.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateBudget(BudgetModel budget) async {
    final db = await instance.database;
    return await db.update('budgets', budget.toMap(), where: 'id = ?', whereArgs: [budget.id]);
  }

  Future<int> deleteBudget(String id) async {
    final db = await instance.database;
    return await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- GOALS CRUD ----------------
  Future<List<GoalModel>> getAllGoals() async {
    final db = await instance.database;
    final result = await db.query('goals');
    return result.map((json) => GoalModel.fromMap(json)).toList();
  }

  Future<int> insertGoal(GoalModel goal) async {
    final db = await instance.database;
    return await db.insert('goals', goal.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateGoal(GoalModel goal) async {
    final db = await instance.database;
    return await db.update('goals', goal.toMap(), where: 'id = ?', whereArgs: [goal.id]);
  }

  Future<int> deleteGoal(String id) async {
    final db = await instance.database;
    return await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- DEBTS CRUD ----------------
  Future<List<DebtModel>> getAllDebts() async {
    final db = await instance.database;
    final result = await db.query('debts', orderBy: 'due_date ASC');
    return result.map((json) => DebtModel.fromMap(json)).toList();
  }

  Future<int> insertDebt(DebtModel debt) async {
    final db = await instance.database;
    return await db.insert('debts', debt.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateDebt(DebtModel debt) async {
    final db = await instance.database;
    return await db.update('debts', debt.toMap(), where: 'id = ?', whereArgs: [debt.id]);
  }

  Future<int> deleteDebt(String id) async {
    final db = await instance.database;
    return await db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- FULL BACKUP & RESTORE ----------------
  Future<Map<String, dynamic>> exportFullDatabase() async {
    final db = await instance.database;

    final categories = await db.query('categories');
    final wallets = await db.query('wallets');
    final transactions = await db.query('transactions');
    final recurring = await db.query('recurring_transactions');
    final budgets = await db.query('budgets');
    final goals = await db.query('goals');
    final debts = await db.query('debts');

    return {
      'app': 'Waffeer',
      'version': '1.0.0',
      'schema_version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'data': {
        'categories': categories,
        'wallets': wallets,
        'transactions': transactions,
        'recurring_transactions': recurring,
        'budgets': budgets,
        'goals': goals,
        'debts': debts,
      }
    };
  }

  Future<bool> importFullDatabase(Map<String, dynamic> backupData) async {
    final db = await instance.database;
    final data = backupData['data'] as Map<String, dynamic>?;
    if (data == null) return false;

    return await db.transaction((txn) async {
      // 1. Clear existing tables
      await txn.delete('transactions');
      await txn.delete('recurring_transactions');
      await txn.delete('budgets');
      await txn.delete('goals');
      await txn.delete('debts');
      await txn.delete('wallets');
      await txn.delete('categories');

      // 2. Import categories
      final categories = (data['categories'] as List<dynamic>?) ?? [];
      for (final item in categories) {
        await txn.insert('categories', Map<String, dynamic>.from(item as Map));
      }

      // 3. Import wallets
      final wallets = (data['wallets'] as List<dynamic>?) ?? [];
      for (final item in wallets) {
        await txn.insert('wallets', Map<String, dynamic>.from(item as Map));
      }

      // 4. Import transactions
      final transactions = (data['transactions'] as List<dynamic>?) ?? [];
      for (final item in transactions) {
        await txn.insert('transactions', Map<String, dynamic>.from(item as Map));
      }

      // 5. Import recurring
      final recurring = (data['recurring_transactions'] as List<dynamic>?) ?? [];
      for (final item in recurring) {
        await txn.insert('recurring_transactions', Map<String, dynamic>.from(item as Map));
      }

      // 6. Import budgets
      final budgets = (data['budgets'] as List<dynamic>?) ?? [];
      for (final item in budgets) {
        await txn.insert('budgets', Map<String, dynamic>.from(item as Map));
      }

      // 7. Import goals
      final goals = (data['goals'] as List<dynamic>?) ?? [];
      for (final item in goals) {
        await txn.insert('goals', Map<String, dynamic>.from(item as Map));
      }

      // 8. Import debts
      final debts = (data['debts'] as List<dynamic>?) ?? [];
      for (final item in debts) {
        await txn.insert('debts', Map<String, dynamic>.from(item as Map));
      }

      return true;
    });
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
