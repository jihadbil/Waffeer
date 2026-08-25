import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/db_helper.dart';
import '../../data/models/transaction_model.dart';
import 'wallet_provider.dart';

class TransactionProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;

  List<TransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;

  // Filter properties
  DateTime? _selectedMonth;
  String? _selectedWalletId;
  String? _selectedCategoryId;
  TransactionType? _selectedType;

  DateTime get selectedMonth => _selectedMonth ?? DateTime.now();
  String? get selectedWalletId => _selectedWalletId;
  String? get selectedCategoryId => _selectedCategoryId;
  TransactionType? get selectedType => _selectedType;

  Future<void> loadTransactions() async {
    _isLoading = true;
    notifyListeners();

    _transactions = await _dbHelper.getAllTransactions();
    _isLoading = false;
    notifyListeners();
  }

  void setSelectedMonth(DateTime month) {
    _selectedMonth = month;
    notifyListeners();
  }

  void setFilter({
    String? walletId,
    String? categoryId,
    TransactionType? type,
  }) {
    _selectedWalletId = walletId;
    _selectedCategoryId = categoryId;
    _selectedType = type;
    notifyListeners();
  }

  void clearFilters() {
    _selectedWalletId = null;
    _selectedCategoryId = null;
    _selectedType = null;
    notifyListeners();
  }

  List<TransactionModel> get filteredTransactions {
    return _transactions.where((tx) {
      // Month filter
      if (_selectedMonth != null) {
        if (tx.dateTime.year != _selectedMonth!.year ||
            tx.dateTime.month != _selectedMonth!.month) {
          return false;
        }
      }

      // Wallet filter
      if (_selectedWalletId != null) {
        if (tx.walletId != _selectedWalletId && tx.toWalletId != _selectedWalletId) {
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

      return true;
    }).toList();
  }

  // Monthly Metrics
  double get monthlyExpense {
    final now = _selectedMonth ?? DateTime.now();
    return _transactions
        .where((tx) =>
            tx.type == TransactionType.expense &&
            tx.dateTime.year == now.year &&
            tx.dateTime.month == now.month)
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

  double get monthlyIncome {
    final now = _selectedMonth ?? DateTime.now();
    return _transactions
        .where((tx) =>
            tx.type == TransactionType.income &&
            tx.dateTime.year == now.year &&
            tx.dateTime.month == now.month)
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

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
  Map<String, double> get categoryExpenseBreakdown {
    final now = _selectedMonth ?? DateTime.now();
    final map = <String, double>{};
    for (final tx in _transactions) {
      if (tx.type == TransactionType.expense &&
          tx.dateTime.year == now.year &&
          tx.dateTime.month == now.month) {
        map[tx.categoryId] = (map[tx.categoryId] ?? 0.0) + tx.amount;
      }
    }
    return map;
  }

  Future<void> addTransaction({
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
    required WalletProvider walletProvider,
  }) async {
    final newTx = TransactionModel(
      id: const Uuid().v4(),
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

    await _dbHelper.insertTransaction(newTx);
    _transactions.insert(0, newTx);
    _transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    
    // Refresh wallets
    await walletProvider.loadWallets(currencyCode);
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
}
