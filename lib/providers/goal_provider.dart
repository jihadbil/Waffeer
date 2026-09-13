import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/db_helper.dart';
import '../../data/models/goal_model.dart';

class GoalProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper;
  GoalProvider({DatabaseHelper? database})
    : _dbHelper = database ?? DatabaseHelper.instance;
  List<GoalModel> _goals = [];
  bool _isLoading = true;

  List<GoalModel> get goals => _goals;
  bool get isLoading => _isLoading;

  double get totalSavedInGoals =>
      _goals.fold(0.0, (sum, g) => sum + g.savedAmount);
  double get totalTargetGoals =>
      _goals.fold(0.0, (sum, g) => sum + g.targetAmount);

  Future<void> loadGoals() async {
    _isLoading = true;
    notifyListeners();

    _goals = await _dbHelper.getAllGoals();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addGoal({
    required String title,
    required double targetAmount,
    double savedAmount = 0.0,
    required DateTime targetDate,
    required String currencyCode,
    required int iconCodePoint,
    String? iconFontFamily,
    required int colorValue,
    String? note,
  }) async {
    final newGoal = GoalModel(
      id: const Uuid().v4(),
      title: title,
      targetAmount: targetAmount,
      savedAmount: savedAmount,
      targetDate: targetDate,
      currencyCode: currencyCode,
      iconCodePoint: iconCodePoint,
      iconFontFamily: iconFontFamily,
      colorValue: colorValue,
      note: note,
      isCompleted: savedAmount >= targetAmount,
    );

    await _dbHelper.insertGoal(newGoal);
    _goals.add(newGoal);
    notifyListeners();
  }

  Future<void> addSavingsToGoal(String goalId, double amount) async {
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index != -1) {
      final current = _goals[index];
      final newSaved = current.savedAmount + amount;
      final updated = current.copyWith(
        savedAmount: newSaved,
        isCompleted: newSaved >= current.targetAmount,
      );
      await _dbHelper.updateGoal(updated);
      _goals[index] = updated;
      notifyListeners();
    }
  }

  Future<void> withdrawSavingsFromGoal(String goalId, double amount) async {
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index != -1) {
      final current = _goals[index];
      final newSaved =
          (current.savedAmount - amount).clamp(0.0, double.infinity);
      final updated = current.copyWith(
        savedAmount: newSaved,
        isCompleted: newSaved >= current.targetAmount,
      );
      await _dbHelper.updateGoal(updated);
      _goals[index] = updated;
      notifyListeners();
    }
  }

  Future<void> updateGoal(GoalModel goal) async {
    await _dbHelper.updateGoal(goal);
    final index = _goals.indexWhere((g) => g.id == goal.id);
    if (index != -1) {
      _goals[index] = goal;
      notifyListeners();
    }
  }

  Future<void> deleteGoal(String id) async {
    await _dbHelper.deleteGoal(id);
    _goals.removeWhere((g) => g.id == id);
    notifyListeners();
  }
}
