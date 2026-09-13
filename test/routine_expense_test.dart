import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:waffeer/data/models/routine_expense_model.dart';
import 'package:waffeer/providers/routine_provider.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar', null);
    await initializeDateFormatting('en', null);
  });

  group('RoutineExpenseModel Tests', () {
    test('Calculates next date correctly for daily frequency', () {
      final base = DateTime(2026, 5, 10, 8, 30);
      const routine = RoutineExpenseModel(
        id: 'r_coffee',
        title: 'قهوة الصباح',
        amount: 15.0,
        categoryId: 'cat_food',
        walletId: 'w_cash',
        isAutoRecurring: true,
        frequency: RoutineFrequency.daily,
        currencyCode: 'SAR',
      );

      final next = routine.calculateNextDate(base);
      expect(next, DateTime(2026, 5, 11, 8, 30));
    });

    test('Calculates next date for everyXDays frequency (repeating multiple times a month)', () {
      final base = DateTime(2026, 5, 10, 10, 0);
      const routine = RoutineExpenseModel(
        id: 'r_groceries',
        title: 'بقالة كل يومين',
        amount: 30.0,
        categoryId: 'cat_shopping',
        walletId: 'w_card',
        isAutoRecurring: true,
        frequency: RoutineFrequency.everyXDays,
        intervalDays: 2,
        currencyCode: 'SAR',
      );

      final next = routine.calculateNextDate(base);
      expect(next, DateTime(2026, 5, 12, 10, 0));

      // With interval 3 days
      final routine3 = routine.copyWith(intervalDays: 3);
      final next3 = routine3.calculateNextDate(base);
      expect(next3, DateTime(2026, 5, 13, 10, 0));
    });

    test('Calculates next date for weekly and monthly frequency', () {
      final base = DateTime(2026, 5, 1, 12, 0);
      const weeklyRoutine = RoutineExpenseModel(
        id: 'r_fuel',
        title: 'بنزين أسبوعي',
        amount: 80.0,
        categoryId: 'cat_transport',
        walletId: 'w_card',
        isAutoRecurring: true,
        frequency: RoutineFrequency.weekly,
        currencyCode: 'SAR',
      );

      final nextWeekly = weeklyRoutine.calculateNextDate(base);
      expect(nextWeekly, DateTime(2026, 5, 8, 12, 0));

      const monthlyRoutine = RoutineExpenseModel(
        id: 'r_clean',
        title: 'تنظيف شهري',
        amount: 150.0,
        categoryId: 'cat_housing',
        walletId: 'w_card',
        isAutoRecurring: true,
        frequency: RoutineFrequency.monthly,
        currencyCode: 'SAR',
      );

      final nextMonthly = monthlyRoutine.calculateNextDate(base);
      expect(nextMonthly, DateTime(2026, 6, 1, 12, 0));
    });

    test('Localized frequency text in Arabic and English', () {
      const manual = RoutineExpenseModel(
        id: 'r_manual',
        title: 'قهوة',
        amount: 15,
        categoryId: 'c1',
        walletId: 'w1',
        isAutoRecurring: false,
        frequency: RoutineFrequency.manual,
        currencyCode: 'SAR',
      );
      expect(manual.localizedFrequency(true), 'نقرة واحدة (عند الطلب)');
      expect(manual.localizedFrequency(false), '1-Tap (On-Demand)');

      const auto2Days = RoutineExpenseModel(
        id: 'r_auto',
        title: 'مواصلات',
        amount: 25,
        categoryId: 'c1',
        walletId: 'w1',
        isAutoRecurring: true,
        frequency: RoutineFrequency.everyXDays,
        intervalDays: 2,
        currencyCode: 'SAR',
      );
      expect(auto2Days.localizedFrequency(true), 'تلقائي كل 2 أيام');
      expect(auto2Days.localizedFrequency(false), 'Auto every 2 days');

      const autoDaily = RoutineExpenseModel(
        id: 'r_daily',
        title: 'فطور',
        amount: 20,
        categoryId: 'c1',
        walletId: 'w1',
        isAutoRecurring: true,
        frequency: RoutineFrequency.daily,
        currencyCode: 'SAR',
      );
      expect(autoDaily.localizedFrequency(true), 'تلقائي يومياً');
      expect(autoDaily.localizedFrequency(false), 'Auto Daily');
    });

    test('Serializes to and from Map accurately', () {
      final now = DateTime(2026, 5, 10, 14, 0);
      final model = RoutineExpenseModel(
        id: 'r_test_1',
        title: 'تاكسي',
        amount: 25.5,
        categoryId: 'cat_transport',
        walletId: 'w_cash',
        note: 'مشوار الدوام',
        iconCodePoint: 0xe354,
        colorValue: 0xFF2563EB,
        isAutoRecurring: true,
        frequency: RoutineFrequency.everyXDays,
        intervalDays: 3,
        nextDueDate: now,
        lastExecutedDate: now.subtract(const Duration(days: 3)),
        usageCount: 7,
        currencyCode: 'SAR',
        isActive: true,
      );

      final map = model.toMap();
      final fromMap = RoutineExpenseModel.fromMap(map);

      expect(fromMap.id, model.id);
      expect(fromMap.title, model.title);
      expect(fromMap.amount, model.amount);
      expect(fromMap.categoryId, model.categoryId);
      expect(fromMap.walletId, model.walletId);
      expect(fromMap.note, model.note);
      expect(fromMap.isAutoRecurring, true);
      expect(fromMap.frequency, RoutineFrequency.everyXDays);
      expect(fromMap.intervalDays, 3);
      expect(fromMap.usageCount, 7);
      expect(fromMap.currencyCode, 'SAR');
      expect(fromMap.isActive, true);
    });

    test('Preset templates contain essential routine categories', () {
      final presets = RoutineProvider.presetTemplates;
      expect(presets.isNotEmpty, true);

      final titlesAr = presets.map((p) => p.titleAr).toList();
      expect(titlesAr, contains('قهوة الصباح'));
      expect(titlesAr, contains('مواصلات وتاكسي'));
      expect(titlesAr, contains('وجبة غداء عمل'));
      expect(titlesAr, contains('بنزين ووقود'));
      expect(titlesAr, contains('خبز وبقالة يومية'));
    });
  });
}
