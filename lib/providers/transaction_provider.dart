import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/db_helper.dart';
import '../../data/models/transaction_model.dart';
import 'wallet_provider.dart';

class MonthlyTrend {
  final DateTime month;
  final double income;
  final double expense;

  const MonthlyTrend({
    required this.month,
    required this.income,
    required this.expense,
  });
}

class TransactionProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper;
  TransactionProvider({DatabaseHelper? database})
    : _dbHelper = database ?? DatabaseHelper.instance;
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;

  List<TransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;

  // Filter properties
  String? _selectedWalletId;
  String? _selectedCategoryId;
  TransactionType? _selectedType;
  DateTimeRange? _customDateRange;
  String _searchQuery = '';
  double? _minAmount;
  double? _maxAmount;

  String? get selectedWalletId => _selectedWalletId;
  String? get selectedCategoryId => _selectedCategoryId;
  TransactionType? get selectedType => _selectedType;
  DateTimeRange? get customDateRange => _customDateRange;
  String get searchQuery => _searchQuery;
  double? get minAmount => _minAmount;
  double? get maxAmount => _maxAmount;

  bool get hasActiveFilters =>
      _selectedWalletId != null ||
      _selectedCategoryId != null ||
      _selectedType != null ||
      _customDateRange != null ||
      _searchQuery.isNotEmpty ||
      _minAmount != null ||
      _maxAmount != null;

  Future<void> loadTransactions() async {
    _isLoading = true;
    notifyListeners();

    _transactions = await _dbHelper.getAllTransactions();
    _isLoading = false;
    notifyListeners();
  }

  @visibleForTesting
  void replaceTransactionsForTesting(List<TransactionModel> transactions) {
    _transactions = List<TransactionModel>.of(transactions);
    _isLoading = false;
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  void setFilter({
    String? walletId,
    String? categoryId,
    TransactionType? type,
    DateTimeRange? dateRange,
    double? minAmount,
    double? maxAmount,
  }) {
    _selectedWalletId = walletId;
    _selectedCategoryId = categoryId;
    _selectedType = type;
    _customDateRange = dateRange;
    _minAmount = minAmount;
    _maxAmount = maxAmount;
    notifyListeners();
  }

  void clearFilters() {
    _selectedWalletId = null;
    _selectedCategoryId = null;
    _selectedType = null;
    _customDateRange = null;
    _searchQuery = '';
    _minAmount = null;
    _maxAmount = null;
    notifyListeners();
  }

  List<TransactionModel> get filteredTransactions {
    return _transactions.where((tx) {
      // Custom Date Range filter
      if (_customDateRange != null) {
        final start = DateTime(
          _customDateRange!.start.year,
          _customDateRange!.start.month,
          _customDateRange!.start.day,
        );
        final end = DateTime(
          _customDateRange!.end.year,
          _customDateRange!.end.month,
          _customDateRange!.end.day,
          23,
          59,
          59,
        );
        if (tx.dateTime.isBefore(start) || tx.dateTime.isAfter(end)) {
          return false;
        }
      }

      // Search Query filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = tx.title?.toLowerCase().contains(q) ?? false;
        final matchNote = tx.note?.toLowerCase().contains(q) ?? false;
        final matchTag = tx.tag?.toLowerCase().contains(q) ?? false;
        final matchAmount = tx.amount.toString().contains(q);
        if (!matchTitle && !matchNote && !matchTag && !matchAmount) {
          return false;
        }
      }

      // Wallet filter
      if (_selectedWalletId != null) {
        if (tx.walletId != _selectedWalletId &&
            tx.toWalletId != _selectedWalletId) {
          return false;
        }
      }

      // Category filter
      if (_selectedCategoryId != null && tx.categoryId != _selectedCategoryId) {
        return false;
      }

      // Type filter
      if (_selectedType != null && tx.type != _selectedType) {
        return false;
      }

      // Min / Max Amount filter
      if (_minAmount != null && tx.amount < _minAmount!) {
        return false;
      }
      if (_maxAmount != null && tx.amount > _maxAmount!) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Applies the user-selected advanced filters while keeping the visible
  /// month local to the screen that owns it. This prevents browsing an old
  /// month in Analytics from silently changing the Dashboard totals.
  List<TransactionModel> filteredTransactionsForMonth(DateTime month) {
    return filteredTransactions.where((tx) {
      if (_customDateRange != null) return true;
      return tx.dateTime.year == month.year && tx.dateTime.month == month.month;
    }).toList();
  }

  // Monthly Metrics
  double expenseForMonth(DateTime month) {
    return _transactions
        .where(
          (tx) =>
              tx.type == TransactionType.expense &&
              tx.dateTime.year == month.year &&
              tx.dateTime.month == month.month,
        )
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

  double incomeForMonth(DateTime month) {
    return _transactions
        .where(
          (tx) =>
              tx.type == TransactionType.income &&
              tx.dateTime.year == month.year &&
              tx.dateTime.month == month.month,
        )
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

  double savingsRateForMonth(DateTime month) {
    final income = incomeForMonth(month);
    if (income <= 0) return 0.0;
    final rate = (income - expenseForMonth(month)) / income;
    return (rate * 100).clamp(0.0, 100.0);
  }

  double get monthlyExpense => expenseForMonth(DateTime.now());

  double get monthlyIncome => incomeForMonth(DateTime.now());

  double get monthlyNetCashFlow => monthlyIncome - monthlyExpense;

  double get monthlySavingsRate {
    if (monthlyIncome <= 0) return 0.0;
    final rate = (monthlyIncome - monthlyExpense) / monthlyIncome;
    return (rate * 100).clamp(0.0, 100.0);
  }

  List<TransactionModel> get recentTransactions {
    return _transactions.take(8).toList();
  }

  // Category breakdown for charts
  Map<String, double> categoryExpenseBreakdownForMonth(DateTime month) {
    final map = <String, double>{};
    for (final tx in _transactions) {
      if (tx.type == TransactionType.expense &&
          tx.dateTime.year == month.year &&
          tx.dateTime.month == month.month) {
        map[tx.categoryId] = (map[tx.categoryId] ?? 0.0) + tx.amount;
      }
    }
    return map;
  }

  Map<String, double> get categoryExpenseBreakdown =>
      categoryExpenseBreakdownForMonth(DateTime.now());

  /// Calculates Monthly trends for the past N months
  List<MonthlyTrend> getMonthlyTrends([int count = 6]) {
    final List<MonthlyTrend> trends = [];
    final now = DateTime.now();

    for (int i = count - 1; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final monthTxs = _transactions.where(
        (tx) =>
            tx.dateTime.year == monthDate.year &&
            tx.dateTime.month == monthDate.month,
      );

      final inc = monthTxs
          .where((tx) => tx.type == TransactionType.income)
          .fold(0.0, (sum, tx) => sum + tx.amount);

      final exp = monthTxs
          .where((tx) => tx.type == TransactionType.expense)
          .fold(0.0, (sum, tx) => sum + tx.amount);

      trends.add(MonthlyTrend(month: monthDate, income: inc, expense: exp));
    }

    return trends;
  }

  Future<void> addTransaction({
    String? transactionId,
    bool saveAsRoutine = false,
    required double amount,
    required TransactionType type,
    required String categoryId,
    required String walletId,
    String? toWalletId,
    required DateTime dateTime,
    String? title,
    String? note,
    String? receiptImagePath,
    required String currencyCode,
    bool isRecurring = false,
    String? tag,
    WalletProvider? walletProvider,
  }) async {
    final newTx = TransactionModel(
      id: transactionId ?? const Uuid().v4(),
      amount: amount,
      type: type,
      categoryId: categoryId,
      walletId: walletId,
      toWalletId: toWalletId,
      dateTime: dateTime,
      title: title,
      note: note,
      receiptImagePath: receiptImagePath,
      currencyCode: currencyCode,
      isRecurring: isRecurring,
      tag: tag,
    );

    await _dbHelper.insertTransactionWithRoutine(
      newTx,
      saveAsRoutine: saveAsRoutine,
    );
    await loadTransactions();

    // Refresh wallets if provider is passed
    if (walletProvider != null) {
      await walletProvider.loadWallets(currencyCode);
    }
    notifyListeners();
  }

  Future<void> updateTransaction(
    TransactionModel updatedTx, {
    required TransactionModel oldTx,
    required WalletProvider walletProvider,
  }) async {
    await _dbHelper.updateTransactionAtomically(updatedTx);

    final index = _transactions.indexWhere((t) => t.id == oldTx.id);
    if (index != -1) {
      _transactions[index] = updatedTx;
      _transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    }

    await walletProvider.loadWallets(updatedTx.currencyCode);
    notifyListeners();
  }

  Future<void> deleteTransaction(
    TransactionModel tx, {
    required WalletProvider walletProvider,
  }) async {
    await _dbHelper.deleteTransaction(tx);
    _transactions.removeWhere((item) => item.id == tx.id);

    // Refresh wallets
    await walletProvider.loadWallets(tx.currencyCode);
    notifyListeners();
  }

  Future<void> restoreTransaction(
    TransactionModel transaction, {
    required WalletProvider walletProvider,
  }) async {
    await _dbHelper.insertTransaction(transaction);
    _transactions.removeWhere((item) => item.id == transaction.id);
    _transactions.add(transaction);
    _transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    await walletProvider.loadWallets(transaction.currencyCode);
    notifyListeners();
  }
}
