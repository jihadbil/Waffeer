import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/db_helper.dart';
import '../../data/models/category_model.dart';

class CategoryProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<CategoryModel> _categories = [];
  bool _isLoading = true;

  List<CategoryModel> get categories => _categories;
  List<CategoryModel> get expenseCategories =>
      _categories.where((c) => c.type == CategoryType.expense).toList();
  List<CategoryModel> get incomeCategories =>
      _categories.where((c) => c.type == CategoryType.income).toList();
  bool get isLoading => _isLoading;

  Future<void> loadCategories() async {
    _isLoading = true;
    notifyListeners();

    _categories = await _dbHelper.getAllCategories();
    _isLoading = false;
    notifyListeners();
  }

  CategoryModel? getById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addCategory({
    required String nameEn,
    required String nameAr,
    required int iconCodePoint,
    String? iconFontFamily,
    required int colorValue,
    required CategoryType type,
  }) async {
    final newCategory = CategoryModel(
      id: const Uuid().v4(),
      nameEn: nameEn,
      nameAr: nameAr,
      iconCodePoint: iconCodePoint,
      iconFontFamily: iconFontFamily,
      colorValue: colorValue,
      type: type,
      isDefault: false,
    );

    await _dbHelper.insertCategory(newCategory);
    _categories.add(newCategory);
    notifyListeners();
  }

  Future<void> updateCategory(CategoryModel category) async {
    await _dbHelper.updateCategory(category);
    final index = _categories.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      _categories[index] = category;
      notifyListeners();
    }
  }

  Future<void> deleteCategory(String id) async {
    await _dbHelper.deleteCategory(id);
    _categories.removeWhere((c) => c.id == id);
    notifyListeners();
  }
}
