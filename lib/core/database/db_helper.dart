import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../../data/models/category_model.dart';
import '../../data/models/wallet_model.dart';
import '../../data/models/transaction_model.dart';
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
      version: 1,
      onCreate: _createDB,
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
      // 1. Insert Transaction
      final id = await txn.insert('transactions', tx.toMap());

      // 2. Update Wallet Balance
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
        // Deduct from source wallet
        await txn.rawUpdate(
          'UPDATE wallets SET current_balance = current_balance - ? WHERE id = ?',
          [tx.amount, tx.walletId],
        );
        // Add to target wallet
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

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
