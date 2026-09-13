import 'package:flutter_test/flutter_test.dart';
import 'package:waffeer/data/models/transaction_model.dart';
import 'package:waffeer/providers/transaction_provider.dart';

void main() {
  test('monthly totals stay isolated to the requested month', () {
    final provider = TransactionProvider();
    provider.replaceTransactionsForTesting([
      TransactionModel(
        id: 'july-income',
        amount: 1000,
        type: TransactionType.income,
        categoryId: 'cat_salary',
        walletId: 'w_cash',
        dateTime: DateTime(2026, 7, 1),
        currencyCode: 'USD',
      ),
      TransactionModel(
        id: 'july-expense',
        amount: 250,
        type: TransactionType.expense,
        categoryId: 'cat_food',
        walletId: 'w_cash',
        dateTime: DateTime(2026, 7, 15),
        currencyCode: 'USD',
      ),
      TransactionModel(
        id: 'august-expense',
        amount: 900,
        type: TransactionType.expense,
        categoryId: 'cat_rent',
        walletId: 'w_cash',
        dateTime: DateTime(2026, 8, 1),
        currencyCode: 'USD',
      ),
    ]);

    expect(provider.incomeForMonth(DateTime(2026, 7)), 1000);
    expect(provider.expenseForMonth(DateTime(2026, 7)), 250);
    expect(provider.expenseForMonth(DateTime(2026, 8)), 900);
    expect(provider.savingsRateForMonth(DateTime(2026, 7)), 75);
    expect(provider.filteredTransactionsForMonth(DateTime(2026, 7)).length, 2);
  });
}
