import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/db_helper.dart';
import '../../data/models/debt_model.dart';

class DebtProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper;
  DebtProvider({DatabaseHelper? database})
    : _dbHelper = database ?? DatabaseHelper.instance;
  List<DebtModel> _debts = [];
  bool _isLoading = true;

  List<DebtModel> get debts => _debts;
  bool get isLoading => _isLoading;

  List<DebtModel> get lentDebts =>
      _debts.where((d) => d.type == DebtType.lend).toList();
  List<DebtModel> get borrowedDebts =>
      _debts.where((d) => d.type == DebtType.borrow).toList();

  double get totalLentRemaining => lentDebts
      .where((d) => !d.isSettled)
      .fold(0.0, (sum, d) => sum + d.remainingAmount);

  double get totalBorrowedRemaining => borrowedDebts
      .where((d) => !d.isSettled)
      .fold(0.0, (sum, d) => sum + d.remainingAmount);

  Future<void> loadDebts() async {
    _isLoading = true;
    notifyListeners();

    _debts = await _dbHelper.getAllDebts();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addDebt({
    required String personName,
    required double totalAmount,
    double paidAmount = 0.0,
    required DebtType type,
    required DateTime dueDate,
    required String currencyCode,
    String? phoneNumber,
    String? note,
  }) async {
    final newDebt = DebtModel(
      id: const Uuid().v4(),
      personName: personName,
      totalAmount: totalAmount,
      paidAmount: paidAmount,
      type: type,
      dueDate: dueDate,
      createdDate: DateTime.now(),
      currencyCode: currencyCode,
      phoneNumber: phoneNumber,
      note: note,
      isSettled: paidAmount >= totalAmount,
    );

    await _dbHelper.insertDebt(newDebt);
    _debts.add(newDebt);
    _debts.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    notifyListeners();
  }

  Future<void> recordPayment(String debtId, double paymentAmount) async {
    final index = _debts.indexWhere((d) => d.id == debtId);
    if (index != -1) {
      final current = _debts[index];
      final newPaid = current.paidAmount + paymentAmount;
      final updated = current.copyWith(
        paidAmount: newPaid,
        isSettled: newPaid >= current.totalAmount,
      );
      await _dbHelper.updateDebt(updated);
      _debts[index] = updated;
      notifyListeners();
    }
  }

  Future<void> updateDebt(DebtModel debt) async {
    await _dbHelper.updateDebt(debt);
    final index = _debts.indexWhere((d) => d.id == debt.id);
    if (index != -1) {
      _debts[index] = debt;
      notifyListeners();
    }
  }

  Future<void> deleteDebt(String id) async {
    await _dbHelper.deleteDebt(id);
    _debts.removeWhere((d) => d.id == id);
    notifyListeners();
  }
}
