import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../data/models/category_model.dart';
import '../../data/models/wallet_model.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/budget_model.dart';
import '../../data/models/goal_model.dart';
import '../../data/models/debt_model.dart';
import '../../data/models/routine_expense_model.dart';

part 'routine_database.dart';

class DatabaseHelper {
  static const int schemaVersion = 6;
  static final DatabaseHelper instance = DatabaseHelper._init();
  Database? _database;

  DatabaseHelper._init();

  /// Isolated database connection for integration tests and desktop tooling.
  static Future<DatabaseHelper> openAt(
    DatabaseFactory factory,
    String path,
  ) async {
    final helper = DatabaseHelper._init();
    helper._database = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: helper._configureDB,
        onCreate: helper._createDB,
        onUpgrade: helper._upgradeDB,
      ),
    );
    return helper;
  }

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
      version: schemaVersion,
      onConfigure: _configureDB,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _configureDB(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _createTransactionsTable(
    DatabaseExecutor db, {
    String tableName = 'transactions',
  }) async {
    await db.execute('''
      CREATE TABLE $tableName (
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
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE RESTRICT,
        FOREIGN KEY (wallet_id) REFERENCES wallets (id) ON DELETE RESTRICT,
        FOREIGN KEY (to_wallet_id) REFERENCES wallets (id) ON DELETE RESTRICT
      )
    ''');
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
    await _createTransactionsTable(db);

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

    await db.execute('''
      CREATE TABLE app_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Routine Expenses Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS routine_expenses (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        category_id TEXT NOT NULL,
        wallet_id TEXT NOT NULL,
        note TEXT,
        icon_code_point INTEGER,
        color_value INTEGER,
        is_auto_recurring INTEGER NOT NULL DEFAULT 0,
        frequency TEXT NOT NULL DEFAULT 'manual',
        interval_days INTEGER NOT NULL DEFAULT 2,
        next_due_date TEXT,
        last_executed_date TEXT,
        usage_count INTEGER NOT NULL DEFAULT 0,
        currency_code TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await _upgradeRoutineSchema(db);

    // Performance Indexes
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_datetime ON transactions(date_time DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_wallet ON transactions(wallet_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_budgets_category ON budgets(category_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_debts_due_date ON debts(due_date)',
    );

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
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS routine_expenses (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          amount REAL NOT NULL,
          category_id TEXT NOT NULL,
          wallet_id TEXT NOT NULL,
          note TEXT,
          icon_code_point INTEGER,
          color_value INTEGER,
          is_auto_recurring INTEGER NOT NULL DEFAULT 0,
          frequency TEXT NOT NULL DEFAULT 'manual',
          interval_days INTEGER NOT NULL DEFAULT 2,
          next_due_date TEXT,
          last_executed_date TEXT,
          usage_count INTEGER NOT NULL DEFAULT 0,
          currency_code TEXT NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1
        )
      ''');
    }
    if (oldVersion < 4) await _upgradeRoutineSchema(db);
    if (oldVersion < 5) {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transactions_datetime ON transactions(date_time DESC)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transactions_wallet ON transactions(wallet_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_budgets_category ON budgets(category_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_debts_due_date ON debts(due_date)',
      );
    }
    if (oldVersion < 6) {
      await _upgradeToV6(db);
    }
  }

  Future<void> _upgradeToV6(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    for (final category in CategoryModel.defaultCategories) {
      await db.insert(
        'categories',
        category.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    final orphanCategories = await db.rawQuery('''
      SELECT DISTINCT t.category_id, t.type
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      WHERE c.id IS NULL
    ''');
    for (final row in orphanCategories) {
      final type = row['type'] as String?;
      final fallback = type == TransactionType.income.name
          ? 'cat_other_inc'
          : type == TransactionType.transfer.name
          ? 'cat_transfer'
          : 'cat_other_exp';
      await db.update(
        'transactions',
        {'category_id': fallback},
        where: 'category_id = ? AND type = ?',
        whereArgs: [row['category_id'], type],
      );
    }

    final referencedWallets = await db.rawQuery('''
      SELECT wallet_id AS id, currency_code FROM transactions
      UNION
      SELECT to_wallet_id AS id, currency_code FROM transactions
      WHERE to_wallet_id IS NOT NULL
    ''');
    for (final row in referencedWallets) {
      final id = row['id'] as String;
      final exists =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM wallets WHERE id = ?', [
              id,
            ]),
          ) !=
          0;
      if (exists) continue;
      await db.insert('wallets', {
        'id': id,
        'name_en': 'Recovered wallet',
        'name_ar': 'محفظة مستعادة',
        'initial_balance': 0.0,
        'current_balance': 0.0,
        'currency_code': row['currency_code'] as String,
        'icon_code_point': 0xe040,
        'icon_font_family': null,
        'color_value': 0xFF64748B,
        'type': WalletType.other.name,
        'is_default': 0,
      });
    }

    await db.execute('ALTER TABLE transactions RENAME TO transactions_v5');
    await _createTransactionsTable(db);
    await db.execute('''
      INSERT INTO transactions (
        id, amount, type, category_id, wallet_id, to_wallet_id, date_time,
        title, note, receipt_image_path, currency_code, is_recurring, tag
      )
      SELECT
        id, amount, type, category_id, wallet_id, to_wallet_id, date_time,
        title, note, receipt_image_path, currency_code, is_recurring, tag
      FROM transactions_v5
    ''');
    await db.execute('DROP TABLE transactions_v5');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_datetime ON transactions(date_time DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_wallet ON transactions(wallet_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category_id)',
    );

    final violations = await db.rawQuery('PRAGMA foreign_key_check');
    if (violations.isNotEmpty) {
      throw StateError('Database relationships could not be repaired');
    }
  }

  // Seed default wallets when currency is set by user
  Future<void> seedDefaultWalletsIfEmpty(String currencyCode) async {
    final db = await database;
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM wallets'),
        ) ??
        0;
    if (count == 0) {
      for (final wallet in WalletModel.defaultWallets(currencyCode)) {
        await db.insert('wallets', wallet.toMap());
      }
    }
  }

  // ---------------- CATEGORIES CRUD ----------------
  Future<List<CategoryModel>> getAllCategories() async {
    final db = await database;
    final result = await db.query('categories');
    return result.map((json) => CategoryModel.fromMap(json)).toList();
  }

  Future<int> insertCategory(CategoryModel category) async {
    final db = await database;
    return await db.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> updateCategory(CategoryModel category) async {
    final db = await database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(String id) async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'categories',
        columns: ['is_default'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return 0;
      if ((rows.first['is_default'] as int? ?? 0) == 1) {
        throw StateError('Default categories cannot be deleted');
      }
      for (final reference in <(String, String)>[
        ('transactions', 'category_id'),
        ('routine_expenses', 'category_id'),
        ('recurring_transactions', 'category_id'),
        ('budgets', 'category_id'),
      ]) {
        final count =
            Sqflite.firstIntValue(
              await txn.rawQuery(
                'SELECT COUNT(*) FROM ${reference.$1} WHERE ${reference.$2} = ?',
                [id],
              ),
            ) ??
            0;
        if (count > 0) {
          throw StateError('Category is in use and cannot be deleted');
        }
      }
      return txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ---------------- WALLETS CRUD ----------------
  Future<List<WalletModel>> getAllWallets() async {
    final db = await database;
    final result = await db.query('wallets');
    return result.map((json) => WalletModel.fromMap(json)).toList();
  }

  Future<int> insertWallet(WalletModel wallet) async {
    final db = await database;
    return await db.insert(
      'wallets',
      wallet.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> updateWallet(WalletModel wallet) async {
    final db = await database;
    return await db.update(
      'wallets',
      wallet.toMap(),
      where: 'id = ?',
      whereArgs: [wallet.id],
    );
  }

  Future<int> deleteWallet(String id) async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'wallets',
        columns: ['is_default'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return 0;
      if ((rows.first['is_default'] as int? ?? 0) == 1) {
        throw StateError('Default wallet cannot be deleted');
      }
      for (final check in <(String, List<Object?>)>[
        (
          'SELECT COUNT(*) FROM transactions WHERE wallet_id = ? OR to_wallet_id = ?',
          [id, id],
        ),
        (
          'SELECT COUNT(*) FROM routine_expenses WHERE wallet_id = ? OR to_wallet_id = ?',
          [id, id],
        ),
        (
          'SELECT COUNT(*) FROM recurring_transactions WHERE wallet_id = ? OR to_wallet_id = ?',
          [id, id],
        ),
      ]) {
        final count =
            Sqflite.firstIntValue(await txn.rawQuery(check.$1, check.$2)) ?? 0;
        if (count > 0) {
          throw StateError('Wallet is in use and cannot be deleted');
        }
      }
      return txn.delete('wallets', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Commits the whole onboarding ledger as one idempotent database unit.
  Future<bool> completeInitialFinancialSetup({
    required String currencyCode,
    required double balance,
    required double monthlyIncome,
    required double savingsGoal,
    required DateTime recordedAt,
    required DateTime goalTargetDate,
    required String incomeTitle,
    required String priorExpensesTitle,
    required String goalTitle,
    required int goalIconCodePoint,
    String? goalIconFontFamily,
    required int goalColorValue,
  }) async {
    if (currencyCode.trim().isEmpty ||
        !balance.isFinite ||
        balance < 0 ||
        !monthlyIncome.isFinite ||
        monthlyIncome < 0 ||
        !savingsGoal.isFinite ||
        savingsGoal < 0) {
      throw ArgumentError('Invalid initial financial setup');
    }

    final db = await database;
    return db.transaction((txn) async {
      const markerKey = 'initial_financial_setup_v1';
      final existing = await txn.query(
        'app_metadata',
        columns: ['key'],
        where: 'key = ?',
        whereArgs: [markerKey],
        limit: 1,
      );
      if (existing.isNotEmpty) return false;

      final wallets = await txn.query(
        'wallets',
        orderBy: 'is_default DESC, rowid ASC',
        limit: 1,
      );
      if (wallets.isEmpty) throw StateError('No wallet is available');
      final wallet = WalletModel.fromMap(wallets.first);
      if (wallet.currencyCode != currencyCode) {
        throw StateError('Wallet currency does not match setup currency');
      }

      Future<String> categoryId(String preferred, CategoryType type) async {
        final preferredRows = await txn.query(
          'categories',
          columns: ['id'],
          where: 'id = ? AND type = ?',
          whereArgs: [preferred, type.name],
          limit: 1,
        );
        if (preferredRows.isNotEmpty) {
          return preferredRows.first['id'] as String;
        }
        final fallback = await txn.query(
          'categories',
          columns: ['id'],
          where: 'type = ?',
          whereArgs: [type.name],
          limit: 1,
        );
        if (fallback.isEmpty) throw StateError('Required category is missing');
        return fallback.first['id'] as String;
      }

      final baseBalance = monthlyIncome > 0
          ? (balance >= monthlyIncome ? balance - monthlyIncome : 0.0)
          : balance;
      await txn.update(
        'wallets',
        {'initial_balance': baseBalance, 'current_balance': baseBalance},
        where: 'id = ?',
        whereArgs: [wallet.id],
      );

      if (monthlyIncome > 0) {
        await _insertMoney(
          txn,
          TransactionModel(
            id: 'onboarding_income_v1',
            amount: monthlyIncome,
            type: TransactionType.income,
            categoryId: await categoryId('cat_salary', CategoryType.income),
            walletId: wallet.id,
            dateTime: recordedAt,
            title: incomeTitle,
            currencyCode: currencyCode,
            tag: 'onboarding',
          ),
        );
        final priorSpent = monthlyIncome - balance;
        if (priorSpent > 0) {
          await _insertMoney(
            txn,
            TransactionModel(
              id: 'onboarding_prior_expenses_v1',
              amount: priorSpent,
              type: TransactionType.expense,
              categoryId: await categoryId(
                'cat_other_exp',
                CategoryType.expense,
              ),
              walletId: wallet.id,
              dateTime: recordedAt,
              title: priorExpensesTitle,
              currencyCode: currencyCode,
              tag: 'onboarding',
            ),
          );
        }
      }

      if (savingsGoal > 0) {
        await txn.insert(
          'goals',
          GoalModel(
            id: 'onboarding_goal_v1',
            title: goalTitle,
            targetAmount: savingsGoal,
            savedAmount: 0,
            targetDate: goalTargetDate,
            currencyCode: currencyCode,
            iconCodePoint: goalIconCodePoint,
            iconFontFamily: goalIconFontFamily,
            colorValue: goalColorValue,
          ).toMap(),
        );
      }

      await txn.insert('app_metadata', {
        'key': markerKey,
        'value': recordedAt.toIso8601String(),
      });
      return true;
    });
  }

  // ---------------- TRANSACTIONS CRUD ----------------
  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await database;
    final result = await db.query('transactions', orderBy: 'date_time DESC');
    return result.map((json) => TransactionModel.fromMap(json)).toList();
  }

  Future<int> insertTransaction(TransactionModel tx) async {
    final db = await database;
    return db.transaction((txn) async {
      final inserted = await _insertMoney(txn, tx);
      if (inserted != 0) await _restoreRoutineExecution(txn, tx.id);
      return inserted;
    });
  }

  Future<int> deleteTransaction(TransactionModel tx) async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [tx.id],
      );
      if (rows.isEmpty) return 0;
      await _applyMoney(txn, TransactionModel.fromMap(rows.first), -1);
      await _reverseRoutineExecution(txn, tx.id);
      return txn.delete('transactions', where: 'id = ?', whereArgs: [tx.id]);
    });
  }

  // ---------------- ROUTINE EXPENSES CRUD ----------------
  Future<List<RoutineExpenseModel>> getAllRoutineExpenses() async {
    final db = await database;
    final result = await db.query(
      'routine_expenses',
      orderBy: 'usage_count DESC, title ASC',
    );
    return result.map((json) => RoutineExpenseModel.fromMap(json)).toList();
  }

  Future<int> deleteRoutineExpense(String id) async {
    final db = await database;
    return await db.delete(
      'routine_expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------- BUDGETS CRUD ----------------
  Future<List<BudgetModel>> getAllBudgets() async {
    final db = await database;
    final result = await db.query('budgets');
    return result.map((json) => BudgetModel.fromMap(json)).toList();
  }

  Future<int> insertBudget(BudgetModel budget) async {
    final db = await database;
    return await db.insert(
      'budgets',
      budget.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateBudget(BudgetModel budget) async {
    final db = await database;
    return await db.update(
      'budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  Future<int> deleteBudget(String id) async {
    final db = await database;
    return await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- GOALS CRUD ----------------
  Future<List<GoalModel>> getAllGoals() async {
    final db = await database;
    final result = await db.query('goals');
    return result.map((json) => GoalModel.fromMap(json)).toList();
  }

  Future<int> insertGoal(GoalModel goal) async {
    final db = await database;
    return await db.insert(
      'goals',
      goal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateGoal(GoalModel goal) async {
    final db = await database;
    return await db.update(
      'goals',
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  Future<int> deleteGoal(String id) async {
    final db = await database;
    return await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- DEBTS CRUD ----------------
  Future<List<DebtModel>> getAllDebts() async {
    final db = await database;
    final result = await db.query('debts', orderBy: 'due_date ASC');
    return result.map((json) => DebtModel.fromMap(json)).toList();
  }

  Future<int> insertDebt(DebtModel debt) async {
    final db = await database;
    return await db.insert(
      'debts',
      debt.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateDebt(DebtModel debt) async {
    final db = await database;
    return await db.update(
      'debts',
      debt.toMap(),
      where: 'id = ?',
      whereArgs: [debt.id],
    );
  }

  Future<int> deleteDebt(String id) async {
    final db = await database;
    return await db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  /// Records a debt payment and its optional wallet transaction together.
  Future<TransactionModel?> recordDebtPaymentAtomically({
    required String debtId,
    required double paymentAmount,
    String? walletId,
    required DateTime paidAt,
    required String transactionTitle,
  }) async {
    if (!paymentAmount.isFinite || paymentAmount <= 0) {
      throw ArgumentError('Payment must be a positive finite amount');
    }
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'debts',
        where: 'id = ?',
        whereArgs: [debtId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Debt does not exist');
      final debt = DebtModel.fromMap(rows.first);
      final remaining = debt.remainingAmount;
      if (remaining <= 0 || paymentAmount - remaining > 0.000001) {
        throw StateError('Payment exceeds the remaining debt');
      }

      final newPaid = (debt.paidAmount + paymentAmount).clamp(
        0.0,
        debt.totalAmount,
      );
      await txn.update(
        'debts',
        debt
            .copyWith(
              paidAmount: newPaid,
              isSettled: newPaid >= debt.totalAmount,
            )
            .toMap(),
        where: 'id = ?',
        whereArgs: [debtId],
      );

      if (walletId == null) return null;
      final isRepaymentReceived = debt.type == DebtType.lend;
      final transaction = TransactionModel(
        id: const Uuid().v4(),
        amount: paymentAmount,
        type: isRepaymentReceived
            ? TransactionType.income
            : TransactionType.expense,
        categoryId: isRepaymentReceived ? 'cat_other_inc' : 'cat_other_exp',
        walletId: walletId,
        dateTime: paidAt,
        title: transactionTitle,
        currencyCode: debt.currencyCode,
        tag: 'debt_payment:$debtId',
      );
      await _insertMoney(txn, transaction);
      return transaction;
    });
  }

  // ---------------- FULL BACKUP & RESTORE ----------------
  Future<Map<String, dynamic>> exportFullDatabase() async {
    final db = await database;
    return db.transaction((txn) async {
      final data = <String, dynamic>{};
      for (final table in [
        'categories',
        'wallets',
        'transactions',
        'routine_expenses',
        'routine_executions',
        'budgets',
        'goals',
        'debts',
        'app_metadata',
      ]) {
        data[table] = await txn.query(table);
      }
      return {
        'app': 'Waffeer',
        'version': '2.0.0',
        'schema_version': schemaVersion,
        'exported_at': DateTime.now().toIso8601String(),
        'data': data,
      };
    });
  }

  Future<bool> importFullDatabase(Map<String, dynamic> backupData) async {
    final db = await database;
    if (backupData['app'] != 'Waffeer' ||
        (backupData['schema_version'] as int? ?? 1) > schemaVersion) {
      throw const FormatException('Unsupported backup');
    }
    final data = backupData['data'] as Map<String, dynamic>?;
    if (data == null) return false;
    return db.transaction((txn) async {
      for (final table in [
        'routine_executions',
        'routine_expenses',
        'transactions',
        'recurring_transactions',
        'budgets',
        'goals',
        'debts',
        'wallets',
        'categories',
        'app_metadata',
      ]) {
        await txn.delete(table);
      }

      for (final item in (data['categories'] as List<dynamic>? ?? [])) {
        await txn.insert('categories', Map<String, dynamic>.from(item as Map));
      }
      for (final category in CategoryModel.defaultCategories) {
        await txn.insert(
          'categories',
          category.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      for (final item in (data['wallets'] as List<dynamic>? ?? [])) {
        await txn.insert('wallets', Map<String, dynamic>.from(item as Map));
      }

      for (final table in [
        'transactions',
        'budgets',
        'goals',
        'debts',
        'routine_expenses',
        'routine_executions',
        'recurring_transactions',
        'app_metadata',
      ]) {
        for (final item in (data[table] as List<dynamic>? ?? [])) {
          var row = Map<String, dynamic>.from(item as Map);
          if (table == 'routine_expenses') {
            row = RoutineExpenseModel.fromMap(row).toMap();
          }
          await txn.insert(table, row);
        }
      }
      await _migrateLegacySchedules(txn);
      return true;
    });
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
