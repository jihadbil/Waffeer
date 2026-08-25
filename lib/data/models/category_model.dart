import 'package:flutter/material.dart';

enum CategoryType { expense, income }

class CategoryModel {
  final String id;
  final String nameEn;
  final String nameAr;
  final int iconCodePoint;
  final String? iconFontFamily;
  final int colorValue;
  final CategoryType type;
  final bool isDefault;

  const CategoryModel({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.iconCodePoint,
    this.iconFontFamily,
    required this.colorValue,
    required this.type,
    this.isDefault = false,
  });

  IconData get iconData => IconData(
        iconCodePoint,
        fontFamily: iconFontFamily ?? 'MaterialIcons',
      );

  Color get color => Color(colorValue);

  String localizedName(bool isArabic) => isArabic ? nameAr : nameEn;

  bool get isExpense => type == CategoryType.expense;
  bool get isIncome => type == CategoryType.income;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name_en': nameEn,
      'name_ar': nameAr,
      'icon_code_point': iconCodePoint,
      'icon_font_family': iconFontFamily,
      'color_value': colorValue,
      'type': type.name,
      'is_default': isDefault ? 1 : 0,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      nameEn: map['name_en'] as String,
      nameAr: map['name_ar'] as String,
      iconCodePoint: map['icon_code_point'] as int,
      iconFontFamily: map['icon_font_family'] as String?,
      colorValue: map['color_value'] as int,
      type: map['type'] == 'income' ? CategoryType.income : CategoryType.expense,
      isDefault: (map['is_default'] as int? ?? 0) == 1,
    );
  }

  CategoryModel copyWith({
    String? id,
    String? nameEn,
    String? nameAr,
    int? iconCodePoint,
    String? iconFontFamily,
    int? colorValue,
    CategoryType? type,
    bool? isDefault,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      nameEn: nameEn ?? this.nameEn,
      nameAr: nameAr ?? this.nameAr,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      colorValue: colorValue ?? this.colorValue,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  // Pre-configured default categories
  static List<CategoryModel> get defaultCategories => [
        // Expense Categories
        const CategoryModel(
          id: 'cat_food',
          nameEn: 'Food & Dining',
          nameAr: 'طعام ومطاعم',
          iconCodePoint: 0xe57a, // restaurant
          colorValue: 0xFFEF4444, // Red
          type: CategoryType.expense,
          isDefault: true,
        ),
        const CategoryModel(
          id: 'cat_shopping',
          nameEn: 'Shopping & Groceries',
          nameAr: 'تسوق ومقاضي',
          iconCodePoint: 0xe59c, // shopping_cart
          colorValue: 0xFFF97316, // Orange
          type: CategoryType.expense,
          isDefault: true,
        ),
        const CategoryModel(
          id: 'cat_transport',
          nameEn: 'Transportation',
          nameAr: 'مواصلات وبنزين',
          iconCodePoint: 0xe1d7, // directions_car
          colorValue: 0xFF3B82F6, // Blue
          type: CategoryType.expense,
          isDefault: true,
        ),
        const CategoryModel(
          id: 'cat_housing',
          nameEn: 'Housing & Rent',
          nameAr: 'سكن وإيجار',
          iconCodePoint: 0xe318, // home
          colorValue: 0xFF8B5CF6, // Purple
          type: CategoryType.expense,
          isDefault: true,
        ),
        const CategoryModel(
          id: 'cat_bills',
          nameEn: 'Bills & Utilities',
          nameAr: 'فواتير ومرافق',
          iconCodePoint: 0xe54e, // receipt_long
          colorValue: 0xFF06B6D4, // Cyan
          type: CategoryType.expense,
          isDefault: true,
        ),
        const CategoryModel(
          id: 'cat_entertainment',
          nameEn: 'Entertainment',
          nameAr: 'ترفيه وأنشطة',
          iconCodePoint: 0xe405, // movie
          colorValue: 0xFFEC4899, // Pink
          type: CategoryType.expense,
          isDefault: true,
        ),
        const CategoryModel(
          id: 'cat_health',
          nameEn: 'Health & Medical',
          nameAr: 'صحة وعلاج',
          iconCodePoint: 0xe3be, // local_hospital
          colorValue: 0xFF10B981, // Emerald
          type: CategoryType.expense,
          isDefault: true,
        ),
        const CategoryModel(
          id: 'cat_education',
          nameEn: 'Education',
          nameAr: 'تعليم وتطوير',
          iconCodePoint: 0xe559, // school
          colorValue: 0xFF6366F1, // Indigo
          type: CategoryType.expense,
          isDefault: true,
        ),
        const CategoryModel(
          id: 'cat_other_exp',
          nameEn: 'Other Expense',
          nameAr: 'مصاريف أخرى',
          iconCodePoint: 0xe400, // more_horiz
          colorValue: 0xFF64748B, // Slate
          type: CategoryType.expense,
          isDefault: true,
        ),

        // Income Categories
        const CategoryModel(
          id: 'cat_salary',
          nameEn: 'Salary',
          nameAr: 'راتب شهري',
          iconCodePoint: 0xe040, // account_balance_wallet
          colorValue: 0xFF10B981, // Green
          type: CategoryType.income,
          isDefault: true,
        ),
        const CategoryModel(
          id: 'cat_freelance',
          nameEn: 'Freelance & Projects',
          nameAr: 'عمل حر ومشاريع',
          iconCodePoint: 0xe3ae, // laptop
          colorValue: 0xFF3B82F6, // Blue
          type: CategoryType.income,
          isDefault: true,
        ),
        const CategoryModel(
          id: 'cat_investment',
          nameEn: 'Investment & Profits',
          nameAr: 'استثمار وأرباح',
          iconCodePoint: 0xe661, // trending_up
          colorValue: 0xFF8B5CF6, // Purple
          type: CategoryType.income,
          isDefault: true,
        ),
        const CategoryModel(
          id: 'cat_gift',
          nameEn: 'Gifts & Rewards',
          nameAr: 'هدايا ومكافآت',
          iconCodePoint: 0xe13d, // card_giftcard
          colorValue: 0xFFF59E0B, // Amber
          type: CategoryType.income,
          isDefault: true,
        ),
        const CategoryModel(
          id: 'cat_other_inc',
          nameEn: 'Other Income',
          nameAr: 'مداخيل أخرى',
          iconCodePoint: 0xe047, // add_circle_outline
          colorValue: 0xFF14B8A6, // Teal
          type: CategoryType.income,
          isDefault: true,
        ),
      ];
}
