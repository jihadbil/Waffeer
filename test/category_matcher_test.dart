import 'package:flutter_test/flutter_test.dart';
import 'package:waffeer/core/services/ai_service.dart';
import 'package:waffeer/core/utils/category_matcher.dart';
import 'package:waffeer/data/models/ai_action.dart';
import 'package:waffeer/data/models/category_model.dart';

void main() {
  group('CategoryMatcher & Arabic Normalization Tests', () {
    test('normalizeArabic properly normalizes Arabic variations and diacritics', () {
      expect(CategoryMatcher.normalizeArabic('هَدِيَّةٌ'), 'هديه');
      expect(CategoryMatcher.normalizeArabic('أرباح وإيداعات'), 'ارباح وايداعات');
      expect(CategoryMatcher.normalizeArabic('مُكَافَأَة'), 'مكافاه');
      expect(CategoryMatcher.normalizeArabic('مقهى وكافيه'), 'مقهي وكافيه');
      expect(CategoryMatcher.normalizeArabic('  تسوق ، ملابس  '), 'تسوق ملابس');
    });

    final defaultCategories = CategoryModel.defaultCategories;

    test('matches "هدية" and synonyms to "هدايا ومكافآت" (cat_gift) for income', () {
      final matchedGift = CategoryMatcher.findBestCategory(
        categories: defaultCategories,
        targetType: CategoryType.income,
        categoryName: 'هدية',
      );
      expect(matchedGift.id, 'cat_gift');
      expect(matchedGift.nameAr, 'هدايا ومكافآت');

      final matchedBonus = CategoryMatcher.findBestCategory(
        categories: defaultCategories,
        targetType: CategoryType.income,
        categoryName: 'مكافأة',
      );
      expect(matchedBonus.id, 'cat_gift');

      final matchedEid = CategoryMatcher.findBestCategory(
        categories: defaultCategories,
        targetType: CategoryType.income,
        categoryName: 'عيدية العيد',
      );
      expect(matchedEid.id, 'cat_gift');
    });

    test('matches salary and investment synonyms accurately', () {
      final matchedSalary = CategoryMatcher.findBestCategory(
        categories: defaultCategories,
        targetType: CategoryType.income,
        categoryName: 'راتب هذا الشهر',
      );
      expect(matchedSalary.id, 'cat_salary');

      final matchedPension = CategoryMatcher.findBestCategory(
        categories: defaultCategories,
        targetType: CategoryType.income,
        categoryName: 'معاش تقاعدي',
      );
      expect(matchedPension.id, 'cat_salary');

      final matchedStocks = CategoryMatcher.findBestCategory(
        categories: defaultCategories,
        targetType: CategoryType.income,
        categoryName: 'أرباح أسهم',
      );
      expect(matchedStocks.id, 'cat_investment');
    });

    test('matches expense synonyms like coffee, food, gas, uber accurately', () {
      final matchedCoffee = CategoryMatcher.findBestCategory(
        categories: defaultCategories,
        targetType: CategoryType.expense,
        categoryName: 'قهوة',
      );
      expect(matchedCoffee.id, 'cat_food');

      final matchedGas = CategoryMatcher.findBestCategory(
        categories: defaultCategories,
        targetType: CategoryType.expense,
        categoryName: 'بنزين 95',
      );
      expect(matchedGas.id, 'cat_transport');

      final matchedUber = CategoryMatcher.findBestCategory(
        categories: defaultCategories,
        targetType: CategoryType.expense,
        categoryName: 'مشوار اوبر',
      );
      expect(matchedUber.id, 'cat_transport');

      final matchedElectricity = CategoryMatcher.findBestCategory(
        categories: defaultCategories,
        targetType: CategoryType.expense,
        categoryName: 'فاتورة الكهرباء',
      );
      expect(matchedElectricity.id, 'cat_bills');
    });

    test('prefers direct category_id match when provided and valid', () {
      final matched = CategoryMatcher.findBestCategory(
        categories: defaultCategories,
        targetType: CategoryType.income,
        categoryId: 'cat_gift',
        categoryName: 'شيء عشوائي',
      );
      expect(matched.id, 'cat_gift');
    });

    test('safe fallback uses cat_other_inc / cat_other_exp when no match found', () {
      final fallbackIncome = CategoryMatcher.findBestCategory(
        categories: defaultCategories,
        targetType: CategoryType.income,
        categoryName: 'كلمة غير معروفة نهائياً 123',
      );
      expect(fallbackIncome.id, 'cat_other_inc');

      final fallbackExpense = CategoryMatcher.findBestCategory(
        categories: defaultCategories,
        targetType: CategoryType.expense,
        categoryName: 'مجهول تماماً xyz',
      );
      expect(fallbackExpense.id, 'cat_other_exp');
    });
  });

  group('Action Deduplication in AiService', () {
    test('extractActionFromResponse deduplicates identical consecutive actions', () {
      const duplicateAiResponse = '''
تم تسجيل الدخل بنجاح!
```action
[
  {"action": "add_income", "amount": 400.0, "title": "هدية", "category_id": "cat_gift", "category_name": "هدايا ومكافآت"},
  {"action": "add_income", "amount": 400.0, "title": "هدية", "category_id": "cat_gift", "category_name": "هدايا ومكافآت"}
]
```
''';

      final result = AiService.extractActionFromResponse(duplicateAiResponse, true);

      // Should be deduplicated into exactly 1 action
      expect(result.actions.length, 1);
      expect(result.actions.first.type, AiActionType.addIncome);
      expect(result.actions.first.data['amount'], 400.0);
      expect(result.actions.first.data['title'], 'هدية');
    });

    test('extractActionFromResponse preserves distinct actions', () {
      const distinctAiResponse = '''
تم تسجيل العمليتين!
```action
[
  {"action": "add_income", "amount": 400.0, "title": "هدية", "category_id": "cat_gift"},
  {"action": "add_expense", "amount": 50.0, "title": "قهوة", "category_id": "cat_food"}
]
```
''';

      final result = AiService.extractActionFromResponse(distinctAiResponse, true);
      expect(result.actions.length, 2);
    });
  });
}
