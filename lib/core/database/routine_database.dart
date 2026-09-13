part of 'db_helper.dart';

Future<void> _upgradeRoutineSchema(DatabaseExecutor db) async {
  for (final column in [
    "recording_mode TEXT NOT NULL DEFAULT 'manual'",
    "type TEXT NOT NULL DEFAULT 'expense'",
    'to_wallet_id TEXT',
    'anchor_day INTEGER',
    'anchor_month INTEGER',
    'schedule_version INTEGER NOT NULL DEFAULT 0',
  ]) {
    await db.execute('ALTER TABLE routine_expenses ADD COLUMN $column');
  }
  await db.execute(
    "UPDATE routine_expenses SET recording_mode = 'automatic' WHERE is_auto_recurring = 1",
  );
  // Invalid old combinations must never enter a non-advancing automatic loop.
  await db.execute(
    "UPDATE routine_expenses SET recording_mode = 'manual', is_auto_recurring = 0, next_due_date = NULL WHERE frequency = 'manual'",
  );
  await db.execute('''CREATE TABLE routine_executions (
    id TEXT PRIMARY KEY, routine_id TEXT NOT NULL, due_date TEXT,
    executed_at TEXT NOT NULL, previous_next_due TEXT, previous_last_executed TEXT,
    schedule_version INTEGER NOT NULL, mode TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'recorded'
  )''');
  await db.execute('''CREATE UNIQUE INDEX routine_occurrence_unique
    ON routine_executions(routine_id, due_date) WHERE status != 'reversed' ''');
  final routines = await db.query('routine_expenses');
  for (final map in routines) {
    final model = RoutineExpenseModel.fromMap(map);
    await db.update(
      'routine_expenses',
      model.toMap(),
      where: 'id = ?',
      whereArgs: [model.id],
    );
  }
  await _migrateLegacySchedules(db);
}

Future<void> _migrateLegacySchedules(DatabaseExecutor db) async {
  for (final row in await db.query('recurring_transactions')) {
    final routine = RoutineExpenseModel.fromLegacy(row);
    await db.insert(
      'routine_expenses',
      routine.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
  await db.delete('recurring_transactions');
}

Future<void> _applyMoney(
  DatabaseExecutor db,
  TransactionModel tx,
  double direction,
) async {
  if (!tx.amount.isFinite || tx.amount <= 0) {
    throw ArgumentError('Invalid amount');
  }
  Future<void> apply(String id, double delta) async {
    final rows = await db.query('wallets', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty || rows.first['currency_code'] != tx.currencyCode) {
      throw StateError('Wallet missing or currency does not match');
    }
    await db.rawUpdate(
      'UPDATE wallets SET current_balance = current_balance + ? WHERE id = ?',
      [delta * direction, id],
    );
  }

  await apply(
    tx.walletId,
    tx.type == TransactionType.income ? tx.amount : -tx.amount,
  );
  if (tx.type == TransactionType.transfer) {
    if (tx.toWalletId == null || tx.toWalletId == tx.walletId) {
      throw StateError('Invalid destination');
    }
    await apply(tx.toWalletId!, tx.amount);
  }
}

Future<int> _insertMoney(DatabaseExecutor db, TransactionModel tx) async {
  if ((await db.query(
    'transactions',
    columns: ['id'],
    where: 'id = ?',
    whereArgs: [tx.id],
  )).isNotEmpty) {
    return 0;
  }
  await _applyMoney(db, tx, 1);
  return db.insert('transactions', tx.toMap());
}

Future<void> _reverseRoutineExecution(DatabaseExecutor db, String txId) async {
  final logs = await db.query(
    'routine_executions',
    where: 'id = ? AND status = ?',
    whereArgs: [txId, 'recorded'],
  );
  if (logs.isEmpty) return;
  final log = logs.first;
  await db.update(
    'routine_executions',
    {
      // Keep an automatic cancellation as a tombstone so reopening cannot recreate it.
      'status': log['mode'] == 'automatic' ? 'cancelled' : 'reversed',
    },
    where: 'id = ?',
    whereArgs: [txId],
  );
  final rows = await db.query(
    'routine_expenses',
    where: 'id = ?',
    whereArgs: [log['routine_id']],
  );
  if (rows.isEmpty) return;
  final routine = RoutineExpenseModel.fromMap(rows.first);
  final remaining = await db.query(
    'routine_executions',
    where: 'routine_id = ? AND status = ?',
    whereArgs: [routine.id, 'recorded'],
    orderBy: 'executed_at DESC',
    limit: 1,
  );
  final first = await db.query(
    'routine_executions',
    where: 'routine_id = ?',
    whereArgs: [routine.id],
    orderBy: 'rowid ASC',
    limit: 1,
  );
  final last = remaining.isEmpty
      ? first.first['previous_last_executed'] as String?
      : remaining.first['executed_at'] as String;
  DateTime? next = routine.nextDueDate;
  final due = DateTime.tryParse(log['due_date'] as String? ?? '');
  if (due != null &&
      routine.isScheduled &&
      routine.scheduleVersion == log['schedule_version'] &&
      (next == null || due.isBefore(next))) {
    next = due;
  }
  await db.update(
    'routine_expenses',
    routine
        .copyWith(
          usageCount: (routine.usageCount - 1).clamp(0, 2147483647),
          lastExecutedDate: DateTime.tryParse(last ?? ''),
          nextDueDate: next,
        )
        .toMap(),
    where: 'id = ?',
    whereArgs: [routine.id],
  );
}

Future<void> _restoreRoutineExecution(DatabaseExecutor db, String id) async {
  final logs = await db.query(
    'routine_executions',
    where: 'id = ? AND status != ?',
    whereArgs: [id, 'recorded'],
  );
  if (logs.isEmpty) return;
  final log = logs.first;
  await db.update(
    'routine_executions',
    {'status': 'recorded'},
    where: 'id = ?',
    whereArgs: [id],
  );
  final rows = await db.query(
    'routine_expenses',
    where: 'id = ?',
    whereArgs: [log['routine_id']],
  );
  if (rows.isEmpty) return;
  final item = RoutineExpenseModel.fromMap(rows.first);
  final due = DateTime.tryParse(log['due_date'] as String? ?? '');
  var next = item.nextDueDate;
  if (due != null &&
      item.isScheduled &&
      item.scheduleVersion == log['schedule_version'] &&
      next != null &&
      !next.isAfter(due)) {
    next = item.calculateNextDate(due);
  }
  final executed = DateTime.parse(log['executed_at'] as String);
  await db.update(
    'routine_expenses',
    item
        .copyWith(
          usageCount: item.usageCount + 1,
          nextDueDate: next,
          lastExecutedDate:
              item.lastExecutedDate == null ||
                  executed.isAfter(item.lastExecutedDate!)
              ? executed
              : item.lastExecutedDate,
        )
        .toMap(),
    where: 'id = ?',
    whereArgs: [item.id],
  );
}

extension RoutineDatabase on DatabaseHelper {
  Future<void> insertTransactionWithRoutine(
    TransactionModel tx, {
    bool saveAsRoutine = false,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final inserted = await _insertMoney(txn, tx);
      if (inserted == 0 || !saveAsRoutine) return;
      final item = RoutineExpenseModel(
        id: const Uuid().v4(),
        title: tx.title ?? 'مصروف متكرر',
        amount: tx.amount,
        type: tx.type,
        categoryId: tx.categoryId,
        walletId: tx.walletId,
        toWalletId: tx.toWalletId,
        currencyCode: tx.currencyCode,
        note: tx.note,
      );
      await _validateRoutine(txn, item);
      await txn.insert('routine_expenses', item.toMap());
    });
  }

  Future<RoutineExpenseModel?> _routine(DatabaseExecutor db, String id) async {
    final rows = await db.query(
      'routine_expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : RoutineExpenseModel.fromMap(rows.first);
  }

  Future<void> _validateRoutine(
    DatabaseExecutor db,
    RoutineExpenseModel item,
  ) async {
    if (item.title.trim().isEmpty ||
        !item.amount.isFinite ||
        item.amount <= 0) {
      throw ArgumentError('Invalid routine');
    }
    if (item.isScheduled &&
        (item.nextDueDate == null ||
            item.frequency == RoutineFrequency.manual ||
            item.intervalDays < 1)) {
      throw ArgumentError('Invalid schedule');
    }
    final wallet = await db.query(
      'wallets',
      where: 'id = ?',
      whereArgs: [item.walletId],
    );
    final category = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [item.categoryId],
    );
    if (wallet.isEmpty ||
        category.isEmpty ||
        wallet.first['currency_code'] != item.currencyCode) {
      throw StateError(
        'Select an existing category and a wallet with matching currency',
      );
    }
    if (item.type == TransactionType.transfer) {
      final destination = await db.query(
        'wallets',
        where: 'id = ?',
        whereArgs: [item.toWalletId],
      );
      if (destination.isEmpty ||
          item.toWalletId == item.walletId ||
          destination.first['currency_code'] != item.currencyCode) {
        throw StateError('Invalid transfer destination');
      }
    }
  }

  Future<void> saveRoutine(
    RoutineExpenseModel item, {
    RoutineExpenseModel? expected,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await _validateRoutine(txn, item);
      final old = await _routine(txn, item.id);
      if (expected != null && old?.nextDueDate != expected.nextDueDate) {
        throw StateError('Schedule advanced. Reopen the editor.');
      }
      if (old != null && old.scheduleVersion != item.scheduleVersion) {
        throw StateError('Routine changed. Reopen the editor.');
      }
      final next = item.copyWith(
        scheduleVersion: (old?.scheduleVersion ?? -1) + 1,
        usageCount: old?.usageCount ?? 0,
        lastExecutedDate: old?.lastExecutedDate,
        nextDueDate: item.isScheduled ? item.nextDueDate : null,
      );
      await txn.insert(
        'routine_expenses',
        next.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Snapshot, money movement, occurrence claim and schedule advance share one SQL transaction.
  Future<String?> recordRoutine(
    String id, {
    double? amount,
    String? note,
    DateTime? dueDate,
    DateTime? now,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final item = await _routine(txn, id);
      if (item == null || !item.isActive) {
        throw StateError('Routine no longer active');
      }
      await _validateRoutine(txn, item);
      final executionTime = now ?? DateTime.now();
      if (dueDate != null) {
        if (!item.isScheduled || dueDate.isAfter(executionTime)) {
          throw StateError('Not due');
        }
        final existing = await txn.query(
          'routine_executions',
          where: "routine_id = ? AND due_date = ? AND status != 'reversed'",
          whereArgs: [id, dueDate.toIso8601String()],
        );
        if (existing.isNotEmpty) return null;
        if (item.nextDueDate != dueDate) {
          return null; // stale button or competing processor
        }
      }
      final tx = TransactionModel(
        id: const Uuid().v4(),
        amount: amount ?? item.amount,
        type: item.type,
        categoryId: item.categoryId,
        walletId: item.walletId,
        toWalletId: item.toWalletId,
        currencyCode: item.currencyCode,
        dateTime: dueDate ?? executionTime,
        title: item.title,
        note: note ?? item.note,
        isRecurring: dueDate != null,
        tag: 'routine',
      );
      await _insertMoney(txn, tx);
      await txn.insert('routine_executions', {
        'id': tx.id,
        'routine_id': id,
        'due_date': dueDate?.toIso8601String(),
        'executed_at': executionTime.toIso8601String(),
        'previous_next_due': item.nextDueDate?.toIso8601String(),
        'previous_last_executed': item.lastExecutedDate?.toIso8601String(),
        'schedule_version': item.scheduleVersion,
        'mode': item.mode.name,
        'status': 'recorded',
      });
      await txn.update(
        'routine_expenses',
        item
            .copyWith(
              usageCount: item.usageCount + 1,
              lastExecutedDate: executionTime,
              nextDueDate: dueDate == null
                  ? item.nextDueDate
                  : item.calculateNextDate(dueDate),
            )
            .toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
      return tx.id;
    });
  }

  Future<int> processRoutineDue({DateTime? now}) async {
    final cutoff = now ?? DateTime.now();
    int count = 0;
    // Each occurrence commits independently; interruptions can safely resume.
    for (final initial in await getAllRoutineExpenses()) {
      if (!initial.isActive || !initial.isAutoRecurring) continue;
      while (true) {
        final db = await database;
        final item = await _routine(db, initial.id);
        if (item == null ||
            !item.isActive ||
            !item.isAutoRecurring ||
            item.nextDueDate == null ||
            item.nextDueDate!.isAfter(cutoff)) {
          break;
        }
        final due = item.nextDueDate!;
        final result = await recordRoutine(item.id, dueDate: due, now: cutoff);
        if (result != null) {
          count++;
          continue;
        }
        // A cancellation consumes this occurrence without moving money again.
        await db.transaction((txn) async {
          final current = await _routine(txn, item.id);
          if (current == null ||
              current.nextDueDate != due ||
              !current.isAutoRecurring ||
              !current.isActive) {
            return;
          }
          await txn.update(
            'routine_expenses',
            current
                .copyWith(nextDueDate: current.calculateNextDate(due))
                .toMap(),
            where: 'id = ?',
            whereArgs: [current.id],
          );
        });
      }
    }
    return count;
  }

  Future<bool> undoRoutineTransaction(String txId) async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [txId],
      );
      if (rows.isEmpty) return false;
      final linked = await txn.query(
        'routine_executions',
        where: 'id = ? AND status = ?',
        whereArgs: [txId, 'recorded'],
      );
      if (linked.isEmpty) return false;
      await _applyMoney(txn, TransactionModel.fromMap(rows.first), -1);
      await txn.delete('transactions', where: 'id = ?', whereArgs: [txId]);
      await _reverseRoutineExecution(txn, txId);
      return true;
    });
  }

  Future<void> updateTransactionAtomically(TransactionModel tx) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [tx.id],
      );
      if (rows.isEmpty) throw StateError('Transaction no longer exists');
      await _applyMoney(txn, TransactionModel.fromMap(rows.first), -1);
      await _applyMoney(txn, tx, 1);
      await txn.update(
        'transactions',
        tx.toMap(),
        where: 'id = ?',
        whereArgs: [tx.id],
      );
    });
  }
}
