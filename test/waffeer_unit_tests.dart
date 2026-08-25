import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:waffeer/core/utils/currency_formatter.dart';
import 'package:waffeer/core/utils/date_formatter.dart';
import 'package:waffeer/data/models/category_model.dart';
import 'package:waffeer/data/models/recurring_transaction_model.dart';
import 'package:waffeer/data/models/transaction_model.dart';
import 'package:waffeer/data/models/wallet_model.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar', null);
    await initializeDateFormatting('en', null);
  });

  group('Currency Formatter Tests', () {
    test('Formats amounts correctly with USD', () {
      final formatted = CurrencyFormatter.format(1500.50, currencyCode: 'USD', isArabic: false);
      expect(formatted, contains('1,500.50'));
    });

    test('Formats zero amounts properly', () {
      final formattedZero = CurrencyFormatter.format(0, currencyCode: 'USD', isArabic: false);
      expect(formattedZero, contains('0'));
    });
  });

  group('Date Formatter Tests', () {
    test('Formats Relative Today correctly', () {
      final now = DateTime.now();
      expect(DateFormatter.formatRelative(now, isArabic: true), 'اليوم');
      expect(DateFormatter.formatRelative(now, isArabic: false), 'Today');
    });

    test('Formats Relative Yesterday correctly', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(DateFormatter.formatRelative(yesterday, isArabic: true), 'أمس');
      expect(DateFormatter.formatRelative(yesterday, isArabic: false), 'Yesterday');
    });

    test('Formats Short and Time accurately', () {
      final date = DateTime(2026, 8, 25, 14, 30);
      final short = DateFormatter.formatShort(date, isArabic: false);
      expect(short, contains('2026'));
      expect(short, contains('Aug'));
    });
  });

  group('Recurring Transactions Tests', () {
    test('Calculates next daily date correctly', () {
      final start = DateTime(2026, 1, 1);
      final rec = RecurringTransactionModel(
        id: '1',
        amount: 100,
        type: TransactionType.expense,
        categoryId: 'cat_food',
        walletId: 'w_cash',
        title: 'Daily Lunch',
        frequency: RecurrenceFrequency.daily,
        startDate: start,
        nextDueDate: start,
        currencyCode: 'USD',
      );

      final next = rec.calculateNextDate(start);
      expect(next, DateTime(2026, 1, 2));
    });

    test('Calculates next weekly date correctly', () {
      final start = DateTime(2026, 1, 1);
      final rec = RecurringTransactionModel(
        id: '1',
        amount: 500,
        type: TransactionType.expense,
        categoryId: 'cat_shopping',
        walletId: 'w_cash',
        title: 'Weekly Groceries',
        frequency: RecurrenceFrequency.weekly,
        startDate: start,
        nextDueDate: start,
        currencyCode: 'USD',
      );

      final next = rec.calculateNextDate(start);
      expect(next, DateTime(2026, 1, 8));
    });

    test('Calculates next monthly date correctly', () {
      final start = DateTime(2026, 1, 31);
      final rec = RecurringTransactionModel(
        id: '1',
        amount: 3000,
        type: TransactionType.income,
        categoryId: 'cat_salary',
        walletId: 'w_bank',
        title: 'Monthly Salary',
        frequency: RecurrenceFrequency.monthly,
        startDate: start,
        nextDueDate: start,
        currencyCode: 'USD',
      );

      final next = rec.calculateNextDate(start);
      // Feb has 28 days in 2026
      expect(next.month, 2);
      expect(next.day, 28);
    });
  });

  group('Model Serialization Tests', () {
    test('TransactionModel toMap and fromMap works symmetrically', () {
      final date = DateTime(2026, 5, 10, 12, 0);
      final tx = TransactionModel(
        id: 'tx_123',
        amount: 250.75,
        type: TransactionType.expense,
        categoryId: 'cat_food',
        walletId: 'w_cash',
        dateTime: date,
        title: 'Dinner with friends',
        note: 'Pizza place',
        receiptImagePath: '/path/to/receipt.jpg',
        currencyCode: 'EUR',
        isRecurring: true,
        tag: 'Social',
      );

      final map = tx.toMap();
      final reconstructed = TransactionModel.fromMap(map);

      expect(reconstructed.id, tx.id);
      expect(reconstructed.amount, tx.amount);
      expect(reconstructed.type, tx.type);
      expect(reconstructed.receiptImagePath, tx.receiptImagePath);
      expect(reconstructed.isRecurring, tx.isRecurring);
      expect(reconstructed.tag, tx.tag);
    });

    test('CategoryModel default list is populated and valid', () {
      final categories = CategoryModel.defaultCategories;
      expect(categories.isNotEmpty, true);
      expect(categories.any((c) => c.isExpense), true);
      expect(categories.any((c) => c.isIncome), true);
    });

    test('WalletModel defaults are created properly', () {
      final wallets = WalletModel.defaultWallets('SAR');
      expect(wallets.length, 3);
      expect(wallets.first.currencyCode, 'SAR');
    });
  });
}
