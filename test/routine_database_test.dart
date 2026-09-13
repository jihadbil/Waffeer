import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:waffeer/core/database/db_helper.dart';
import 'package:waffeer/data/models/routine_expense_model.dart';
import 'package:waffeer/data/models/transaction_model.dart';
import 'package:waffeer/providers/routine_provider.dart';

void main() {
  sqfliteFfiInit();
  late DatabaseHelper helper;
  late String walletId;
  setUp(() async {
    helper = await DatabaseHelper.openAt(
      databaseFactoryFfi,
      inMemoryDatabasePath,
    );
    await helper.seedDefaultWalletsIfEmpty('USD');
    final wallet = (await helper.getAllWallets()).first;
    walletId = wallet.id;
    await helper.updateWallet(
      wallet.copyWith(initialBalance: 1000, currentBalance: 1000),
    );
  });
  tearDown(() => helper.close());
  RoutineExpenseModel item({
    RecordingMode mode = RecordingMode.manual,
    DateTime? due,
    RoutineFrequency frequency = RoutineFrequency.daily,
    TransactionType type = TransactionType.expense,
  }) => RoutineExpenseModel(
    id: 'coffee',
    title: 'Coffee',
    amount: 10,
    categoryId: 'cat_food',
    walletId: walletId,
    currencyCode: 'USD',
    mode: mode,
    frequency: frequency,
    nextDueDate: due,
    type: type,
  );
  Future<double> balance() async => (await helper.getAllWallets())
      .firstWhere((w) => w.id == walletId)
      .currentBalance;

  test(
    'manual taps are independent and undo targets an exact transaction once',
    () async {
      await helper.saveRoutine(item());
      final first = await helper.recordRoutine('coffee');
      final second = await helper.recordRoutine('coffee');
      expect(first, isNot(second));
      expect(await balance(), 980);
      expect(await helper.undoRoutineTransaction(first!), isTrue);
      expect(await helper.undoRoutineTransaction(first), isFalse);
      expect(await balance(), 990);
      expect((await helper.getAllTransactions()).single.id, second);
      expect((await helper.getAllRoutineExpenses()).single.usageCount, 1);
      await helper.undoRoutineTransaction(second!);
      expect(
        (await helper.getAllRoutineExpenses()).single.lastExecutedDate,
        isNull,
      );
    },
  );

  test(
    'concurrent due confirmations and processors cannot charge twice',
    () async {
      final due = DateTime(2026, 1, 1);
      await helper.saveRoutine(item(mode: RecordingMode.automatic, due: due));
      final counts = await Future.wait([
        helper.processRoutineDue(now: DateTime(2026, 1, 3, 12)),
        helper.processRoutineDue(now: DateTime(2026, 1, 3, 12)),
      ]);
      expect(counts.reduce((a, b) => a + b), 3);
      expect(await balance(), 970);
      expect(
        (await helper.getAllRoutineExpenses()).single.nextDueDate,
        DateTime(2026, 1, 4),
      );
      expect(await helper.processRoutineDue(now: DateTime(2026, 1, 3, 12)), 0);
    },
  );

  test('reminder requires confirmation and undo makes it due again', () async {
    final due = DateTime(2026, 1, 1);
    await helper.saveRoutine(item(mode: RecordingMode.reminder, due: due));
    expect(await helper.processRoutineDue(now: due), 0);
    final ids = await Future.wait([
      helper.recordRoutine('coffee', dueDate: due, now: due),
      helper.recordRoutine('coffee', dueDate: due, now: due),
    ]);
    expect(ids.whereType<String>().length, 1);
    await helper.undoRoutineTransaction(ids.whereType<String>().single);
    expect(await balance(), 1000);
    expect((await helper.getAllRoutineExpenses()).single.nextDueDate, due);
    expect(
      await helper.recordRoutine('coffee', dueDate: due, now: due),
      isNotNull,
    );
  });

  test(
    'undoing automatic entry survives reconciliation and backup restore',
    () async {
      final due = DateTime(2026, 1, 1);
      await helper.saveRoutine(item(mode: RecordingMode.automatic, due: due));
      await helper.processRoutineDue(now: due);
      await helper.undoRoutineTransaction(
        (await helper.getAllTransactions()).single.id,
      );
      final backup = await helper.exportFullDatabase();
      await helper.importFullDatabase(backup);
      expect(await helper.processRoutineDue(now: due), 0);
      expect(await balance(), 1000);
      expect(await helper.getAllTransactions(), isEmpty);
    },
  );

  test('schedule update failure rolls back transaction and balance', () async {
    await helper.saveRoutine(
      item(mode: RecordingMode.automatic, due: DateTime(2026, 1, 1)),
    );
    final db = await helper.database;
    await db.execute(
      "CREATE TRIGGER fail_schedule BEFORE UPDATE ON routine_expenses BEGIN SELECT RAISE(ABORT, 'disk failure'); END",
    );
    await expectLater(
      helper.processRoutineDue(now: DateTime(2026, 1, 1)),
      throwsA(isA<DatabaseException>()),
    );
    expect(await balance(), 1000);
    expect(await helper.getAllTransactions(), isEmpty);
    expect(await db.query('routine_executions'), isEmpty);
    await db.execute('DROP TRIGGER fail_schedule');
    expect(await helper.processRoutineDue(now: DateTime(2026, 1, 1)), 1);
  });

  test('monthly anchor and leap day recover after short months', () async {
    await helper.saveRoutine(
      item(
        mode: RecordingMode.automatic,
        due: DateTime(2026, 1, 31),
        frequency: RoutineFrequency.monthly,
      ),
    );
    expect(await helper.processRoutineDue(now: DateTime(2026, 3, 31)), 3);
    expect(
      (await helper.getAllRoutineExpenses()).single.nextDueDate,
      DateTime(2026, 4, 30),
    );
    final yearly = item(
      mode: RecordingMode.automatic,
      due: DateTime(2024, 2, 29),
      frequency: RoutineFrequency.yearly,
    );
    var date = yearly.nextDueDate!;
    for (var i = 0; i < 4; i++) {
      date = yearly.calculateNextDate(date);
    }
    expect(date, DateTime(2028, 2, 29));
  });

  test('pause skips the paused period on resume', () async {
    await helper.saveRoutine(
      item(
        mode: RecordingMode.automatic,
        due: DateTime.now().subtract(const Duration(days: 30)),
      ),
    );
    final provider = RoutineProvider(database: helper);
    await provider.loadRoutines();
    await provider.toggleActive('coffee');
    expect(await helper.processRoutineDue(), 0);
    await provider.toggleActive('coffee');
    expect(
      provider.routines.single.nextDueDate!.isAfter(DateTime.now()),
      isTrue,
    );
    expect(await helper.processRoutineDue(), 0);
    provider.dispose();
  });

  test(
    'null clears schedule and note; invalid auto/manual is rejected',
    () async {
      final routine = item(
        mode: RecordingMode.automatic,
        due: DateTime(2026, 1, 1),
      ).copyWith(note: 'old');
      final cleared = routine.copyWith(
        mode: RecordingMode.manual,
        nextDueDate: null,
        note: null,
      );
      expect(cleared.nextDueDate, isNull);
      expect(cleared.note, isNull);
      await expectLater(
        helper.saveRoutine(
          item(
            mode: RecordingMode.automatic,
            due: DateTime(2026, 1, 1),
            frequency: RoutineFrequency.manual,
          ),
        ),
        throwsArgumentError,
      );
      await expectLater(
        helper.saveRoutine(item().copyWith(currencyCode: 'EUR')),
        throwsStateError,
      );
    },
  );

  test('backup replaces routines and imports legacy income without opting into auto', () async {
    await helper.saveRoutine(item());
    final backup = await helper.exportFullDatabase();
    final data = backup['data'] as Map<String, dynamic>;
    data.remove('routine_expenses');
    data.remove('routine_executions');
    backup['schema_version'] = 2;
    data['recurring_transactions'] = [
      {
        'id': 'salary',
        'title': 'Salary',
        'amount': 100,
        'type': 'income',
        'category_id': 'cat_salary',
        'wallet_id': walletId,
        'currency_code': 'USD',
        'frequency': 'yearly',
        'start_date': '2026-01-01T00:00:00.000',
        'next_due_date': '2026-01-01T00:00:00.000',
        'is_active': 1,
      },
    ];
    expect(await helper.importFullDatabase(backup), isTrue);
    final migrated = (await helper.getAllRoutineExpenses()).single;
    expect(migrated.id, 'legacy:salary');
    expect(migrated.mode, RecordingMode.reminder);
    expect(migrated.type, TransactionType.income);
    expect(migrated.frequency, RoutineFrequency.yearly);
    await helper.recordRoutine(
      migrated.id,
      dueDate: migrated.nextDueDate,
      now: DateTime(2026, 1, 1),
    );
    expect(await balance(), 1100);
  });

  test(
    'saving a transaction and quick preset is atomic and safe to retry',
    () async {
      final tx = TransactionModel(
        id: 'stable-id',
        amount: 25,
        type: TransactionType.expense,
        categoryId: 'cat_food',
        walletId: walletId,
        currencyCode: 'USD',
        dateTime: DateTime.now(),
        title: 'Lunch',
      );
      final sql = await helper.database;
      await sql.execute(
        "CREATE TRIGGER fail_preset BEFORE INSERT ON routine_expenses BEGIN SELECT RAISE(ABORT, 'failure'); END",
      );
      await expectLater(
        helper.insertTransactionWithRoutine(tx, saveAsRoutine: true),
        throwsA(isA<DatabaseException>()),
      );
      expect(await balance(), 1000);
      expect(await helper.getAllTransactions(), isEmpty);
      await sql.execute('DROP TRIGGER fail_preset');
      await helper.insertTransactionWithRoutine(tx, saveAsRoutine: true);
      await helper.insertTransactionWithRoutine(tx, saveAsRoutine: true);
      expect(await balance(), 975);
      expect((await helper.getAllRoutineExpenses()).length, 1);
      expect(
        (await helper.getAllRoutineExpenses()).single.mode,
        RecordingMode.manual,
      );
    },
  );

  test('editing deleting and restoring a scheduled transaction preserve the ledger', () async {
    final due = DateTime(2026, 1, 1);
    await helper.saveRoutine(item(mode: RecordingMode.reminder, due: due));
    await helper.recordRoutine('coffee', dueDate: due, now: due);
    final tx = (await helper.getAllTransactions()).single.copyWith(amount: 25);
    await helper.updateTransactionAtomically(tx);
    expect(await balance(), 975);
    await helper.deleteTransaction(tx);
    expect(await balance(), 1000);
    expect((await helper.getAllRoutineExpenses()).single.nextDueDate, due);
    await helper.insertTransaction(tx);
    await helper.insertTransaction(tx);
    expect(await balance(), 975);
    expect((await helper.getAllRoutineExpenses()).single.usageCount, 1);
    expect(
      (await helper.getAllRoutineExpenses()).single.nextDueDate,
      DateTime(2026, 1, 2),
    );
  });

  test(
    'deleting a linked wallet pauses schedules instead of breaking startup',
    () async {
      await helper.saveRoutine(
        item(mode: RecordingMode.automatic, due: DateTime(2026, 1, 1)),
      );
      await helper.deleteWallet(walletId);
      expect((await helper.getAllRoutineExpenses()).single.isActive, isFalse);
      expect(await helper.processRoutineDue(), 0);
    },
  );

  test('schema v3 migrates once without changing existing balances', () async {
    final directory = await Directory.systemTemp.createTemp(
      'waffeer-migration-',
    );
    final path = '${directory.path}/migration.db';
    var legacy = await DatabaseHelper.openAt(databaseFactoryFfi, path);
    final db = await legacy.database;
    await db.execute('DROP TABLE routine_executions');
    for (final column in [
      'recording_mode',
      'type',
      'to_wallet_id',
      'anchor_day',
      'anchor_month',
      'schedule_version',
    ]) {
      await db.execute('ALTER TABLE routine_expenses DROP COLUMN $column');
    }
    await db.insert('recurring_transactions', {
      'id': 'rent',
      'title': 'Rent',
      'amount': 90,
      'type': 'expense',
      'category_id': 'cat_housing',
      'wallet_id': 'legacy-wallet',
      'currency_code': 'USD',
      'frequency': 'monthly',
      'start_date': '2026-01-01T00:00:00.000',
      'next_due_date': '2026-02-01T00:00:00.000',
      'is_active': 1,
    });
    await db.setVersion(3);
    await legacy.close();
    legacy = await DatabaseHelper.openAt(databaseFactoryFfi, path);
    expect((await legacy.getAllRoutineExpenses()).single.id, 'legacy:rent');
    expect(await legacy.getAllTransactions(), isEmpty);
    await legacy.close();
    legacy = await DatabaseHelper.openAt(databaseFactoryFfi, path);
    expect((await legacy.getAllRoutineExpenses()).length, 1);
    await legacy.close();
    expect(
      directory.absolute.path.startsWith(
        '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}waffeer-migration-',
      ),
      isTrue,
    );
    await directory.delete(recursive: true);
  });
}
