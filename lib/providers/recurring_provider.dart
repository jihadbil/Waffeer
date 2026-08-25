import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/database/db_helper.dart';
import '../data/models/recurring_transaction_model.dart';
import '../data/models/transaction_model.dart';
import 'transaction_provider.dart';

class RecurringProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<RecurringTransactionModel> _recurringTransactions = [];
  bool _isLoading = false;

  List<RecurringTransactionModel> get recurringTransactions => _recurringTransactions;
  List<RecurringTransactionModel> get activeRecurring => _recurringTransactions.where((t) => t.isActive).toList();
  bool get isLoading => _isLoading;

  Future<void> loadRecurring() async {
    _isLoading = true;
    notifyListeners();

    _recurringTransactions = await _dbHelper.getAllRecurring();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addRecurring({
    required double amount,
    required TransactionType type,
    required String categoryId,
    required String walletId,
    String? toWalletId,
    required String title,
    String? note,
    required RecurrenceFrequency frequency,
    required DateTime startDate,
    required String currencyCode,
  }) async {
    final newRecurring = RecurringTransactionModel(
      id: const Uuid().v4(),
      amount: amount,
      type: type,
      categoryId: categoryId,
      walletId: walletId,
      toWalletId: toWalletId,
      title: title,
      note: note,
      frequency: frequency,
      startDate: startDate,
      nextDueDate: startDate,
      currencyCode: currencyCode,
      isActive: true,
    );

    await _dbHelper.insertRecurring(newRecurring);
    _recurringTransactions.add(newRecurring);
    _recurringTransactions.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
    notifyListeners();
  }

  Future<void> updateRecurring(RecurringTransactionModel rec) async {
    await _dbHelper.updateRecurring(rec);
    final index = _recurringTransactions.indexWhere((t) => t.id == rec.id);
    if (index != -1) {
      _recurringTransactions[index] = rec;
      _recurringTransactions.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
      notifyListeners();
    }
  }

  Future<void> toggleActive(String id) async {
    final index = _recurringTransactions.indexWhere((t) => t.id == id);
    if (index != -1) {
      final updated = _recurringTransactions[index].copyWith(
        isActive: !_recurringTransactions[index].isActive,
      );
      await updateRecurring(updated);
    }
  }

  Future<void> deleteRecurring(String id) async {
    await _dbHelper.deleteRecurring(id);
    _recurringTransactions.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  /// Automatically checks and creates real transactions for any due recurring records
  Future<int> processDueTransactions(TransactionProvider txProvider) async {
    final now = DateTime.now();
    int processedCount = 0;

    for (final rec in _recurringTransactions.where((t) => t.isActive)) {
      DateTime currentDue = rec.nextDueDate;
      bool wasExecuted = false;

      while (currentDue.isBefore(now) || currentDue.isAtSameMomentAs(now)) {
        // Create actual transaction
        await txProvider.addTransaction(
          amount: rec.amount,
          type: rec.type,
          categoryId: rec.categoryId,
          walletId: rec.walletId,
          toWalletId: rec.toWalletId,
          dateTime: currentDue,
          title: rec.title,
          note: rec.note,
          currencyCode: rec.currencyCode,
          isRecurring: true,
        );

        wasExecuted = true;
        processedCount++;
        currentDue = rec.calculateNextDate(currentDue);
      }

      if (wasExecuted) {
        final updatedRec = rec.copyWith(
          nextDueDate: currentDue,
          lastExecutedDate: now,
        );
        await _dbHelper.updateRecurring(updatedRec);
        final index = _recurringTransactions.indexWhere((t) => t.id == rec.id);
        if (index != -1) {
          _recurringTransactions[index] = updatedRec;
        }
      }
    }

    if (processedCount > 0) {
      _recurringTransactions.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
      notifyListeners();
    }

    return processedCount;
  }
}
