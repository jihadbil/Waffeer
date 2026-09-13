import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/db_helper.dart';
import '../../data/models/budget_model.dart';
import '../../data/models/transaction_model.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/notification_service.dart';

class BudgetProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper;
  BudgetProvider({DatabaseHelper? database})
    : _dbHelper = database ?? DatabaseHelper.instance;
  List<BudgetModel> _budgets = [];
  bool _isLoading = true;

  List<BudgetModel> get budgets => _budgets;
  bool get isLoading => _isLoading;

  Future<void> loadBudgets() async {
    _isLoading = true;
    notifyListeners();

    _budgets = await _dbHelper.getAllBudgets();
    _isLoading = false;
    notifyListeners();
  }

  // Calculate spent amount for a specific budget
  double getSpentAmount(
    BudgetModel budget,
    List<TransactionModel> transactions,
  ) {
    return transactions
        .where((tx) {
          if (tx.type != TransactionType.expense) return false;
          // Date range check
          if (tx.dateTime.isBefore(budget.startDate) ||
              tx.dateTime.isAfter(budget.endDate)) {
            return false;
          }
          // Category check (if categoryId is null, it's an overall budget)
          if (budget.categoryId != null && tx.categoryId != budget.categoryId) {
            return false;
          }
          return true;
        })
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

  double getProgress(BudgetModel budget, List<TransactionModel> transactions) {
    if (budget.limitAmount <= 0) return 0.0;
    final spent = getSpentAmount(budget, transactions);
    return (spent / budget.limitAmount).clamp(0.0, 1.0);
  }

  double getRemainingAmount(
    BudgetModel budget,
    List<TransactionModel> transactions,
  ) {
    final spent = getSpentAmount(budget, transactions);
    final diff = budget.limitAmount - spent;
    return diff > 0 ? diff : 0.0;
  }

  bool isExceeded(BudgetModel budget, List<TransactionModel> transactions) {
    final spent = getSpentAmount(budget, transactions);
    return spent > budget.limitAmount;
  }

  bool isNearLimit(BudgetModel budget, List<TransactionModel> transactions) {
    final spent = getSpentAmount(budget, transactions);
    return spent >= (budget.limitAmount * 0.8) && spent <= budget.limitAmount;
  }

  Future<void> checkAndNotify(
    List<TransactionModel> transactions, {
    required bool isArabic,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    for (final budget in _budgets) {
      final spent = getSpentAmount(budget, transactions);
      final level = spent > budget.limitAmount && budget.notifyOnExceed
          ? 2
          : spent >= budget.limitAmount * 0.8 && budget.notifyOn80Percent
          ? 1
          : 0;
      if (level == 0) continue;

      final key =
          'budget_alert_${budget.id}_${budget.endDate.toIso8601String()}';
      final lastLevel = prefs.getInt(key) ?? 0;
      if (level <= lastLevel) continue;

      await NotificationService.instance.showNotification(
        id: 2000 + (budget.id.hashCode.abs() % 100000),
        title: level == 2
            ? (isArabic ? 'تجاوزت حد الميزانية' : 'Budget limit exceeded')
            : (isArabic
                  ? 'اقتربت من حد الميزانية'
                  : 'Budget is nearly reached'),
        body: level == 2
            ? (isArabic
                  ? 'راجع مصاريفك الآن وحدد ما يمكن تأجيله.'
                  : 'Review your spending and decide what can be postponed.')
            : (isArabic
                  ? 'استخدمت 80% أو أكثر من ميزانيتك الحالية.'
                  : 'You have used at least 80% of your current budget.'),
      );
      await prefs.setInt(key, level);
    }
  }

  Future<void> addBudget({
    String? categoryId,
    required double limitAmount,
    required BudgetPeriod period,
    required DateTime startDate,
    required DateTime endDate,
    required String currencyCode,
    bool notify80 = true,
    bool notifyExceed = true,
  }) async {
    final newBudget = BudgetModel(
      id: const Uuid().v4(),
      categoryId: categoryId,
      limitAmount: limitAmount,
      period: period,
      startDate: startDate,
      endDate: endDate,
      currencyCode: currencyCode,
      notifyOn80Percent: notify80,
      notifyOnExceed: notifyExceed,
    );

    await _dbHelper.insertBudget(newBudget);
    _budgets.add(newBudget);
    notifyListeners();
  }

  Future<void> updateBudget(BudgetModel budget) async {
    await _dbHelper.updateBudget(budget);
    final index = _budgets.indexWhere((b) => b.id == budget.id);
    if (index != -1) {
      _budgets[index] = budget;
      notifyListeners();
    }
  }

  Future<void> deleteBudget(String id) async {
    await _dbHelper.deleteBudget(id);
    _budgets.removeWhere((b) => b.id == id);
    notifyListeners();
  }
}
