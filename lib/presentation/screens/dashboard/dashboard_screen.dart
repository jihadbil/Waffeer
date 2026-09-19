import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/receipt_scanner_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/routine_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../widgets/balance_card.dart';
import '../../widgets/routine_expenses_carousel.dart';
import '../../widgets/smart_expense_sheet.dart';
import '../../widgets/transaction_tile.dart';
import '../budgets/budgets_screen.dart';
import '../settings/settings_screen.dart';
import '../transactions/add_edit_transaction_screen.dart';
import '../transactions/receipt_scanner_screen.dart';
import '../transactions/transactions_list_screen.dart';
import '../wallets/wallets_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  void _open(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final ar = settings.isArabic;
    final wallets = context.watch<WalletProvider>();
    final tx = context.watch<TransactionProvider>();
    final budgets = context.watch<BudgetProvider>();
    final colors = Theme.of(context).colorScheme;
    final warnings = budgets.budgets
        .where(
          (b) =>
              budgets.isExceeded(b, tx.transactions) ||
              budgets.isNearLimit(b, tx.transactions),
        )
        .length;
    final now = DateTime.now();
    final remaining = DateTime(now.year, now.month + 1, 0).day - now.day + 1;
    final available =
        (tx.monthlyIncome > 0
                ? tx.monthlyIncome - tx.monthlyExpense
                : wallets.totalBalance)
            .clamp(0.0, double.infinity) /
        remaining;
    return Scaffold(
      appBar: AppBar(
        title: Text(ar ? 'وفير' : 'Waffeer'),
        actions: [
          IconButton(
            tooltip: ar ? 'الإعدادات' : 'Settings',
            onPressed: () => _open(context, const SettingsScreen()),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final routine = context.read<RoutineProvider>();
          try {
            await budgets.loadBudgets();
            await routine.processAutoRecurringDue(
              txProvider: tx,
              walletProvider: wallets,
            );
            await routine.syncReminders(ar);
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ar
                        ? 'تعذر التحديث. حاول مجدداً.'
                        : 'Refresh failed. Try again.',
                  ),
                ),
              );
            }
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            BalanceCard(
              totalBalance: wallets.totalBalance,
              monthlyIncome: tx.monthlyIncome,
              monthlyExpense: tx.monthlyExpense,
              currencyCode: settings.currencyCode,
              isArabic: ar,
              onManageWallets: () => _open(context, const WalletsScreen()),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.today_outlined, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ar
                          ? 'المتاح اليوم حتى نهاية الشهر'
                          : 'Available today through month end',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(
                      available,
                      currencyCode: settings.currencyCode,
                      isArabic: ar,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => SmartExpenseSheet.show(context),
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: Text(ar ? 'تسجيل ذكي ✨' : 'Smart Add ✨'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _open(
                      context,
                      const AddEditTransactionScreen(
                        initialType: TransactionType.expense,
                      ),
                    ),
                    icon: const Icon(Icons.remove),
                    label: Text(ar ? 'مصروف' : 'Expense'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _open(
                      context,
                      const AddEditTransactionScreen(
                        initialType: TransactionType.income,
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(ar ? 'دخل' : 'Income'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _open(
                      context,
                      const AddEditTransactionScreen(
                        initialType: TransactionType.transfer,
                      ),
                    ),
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(ar ? 'تحويل' : 'Transfer'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _open(context, const ReceiptScannerScreen()),
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: Text(ar ? 'مسح فاتورة' : 'Scan receipt'),
                  ),
                ],
              ),
            if (warnings > 0)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: ListTile(
                  leading: Icon(Icons.info_outline, color: colors.error),
                  title: Text(
                    ar
                        ? '$warnings ميزانيات تحتاج مراجعة'
                        : '$warnings budgets need attention',
                  ),
                  onTap: () => _open(context, const BudgetsScreen()),
                ),
              ),
            const SizedBox(height: 20),
            const RoutineExpensesCarousel(),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    ar ? 'آخر التسجيلات' : 'Recent entries',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      _open(context, const TransactionsListScreen()),
                  child: Text(ar ? 'عرض الكل' : 'View all'),
                ),
              ],
            ),
            if (tx.recentTransactions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  ar
                      ? 'سجّل أول معاملة لتبدأ متابعة أموالك.'
                      : 'Record your first entry to start tracking your money.',
                ),
              ),
            ...tx.recentTransactions.map(
              (item) => TransactionTile(
                transaction: item,
                onTap: () =>
                    _open(context, AddEditTransactionScreen(transaction: item)),
                onDelete: () async {
                  final routine = context.read<RoutineProvider>();
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await tx.deleteTransaction(item, walletProvider: wallets);
                    await routine.loadRoutines();
                    await routine.syncReminders(ar);
                    var restoreRequested = false;
                    final controller = messenger.showSnackBar(
                      SnackBar(
                        content: Text(ar ? 'تم حذف المعاملة' : 'Entry deleted'),
                        action: SnackBarAction(
                          label: ar ? 'تراجع' : 'Undo',
                          onPressed: () async {
                            restoreRequested = true;
                            try {
                              await tx.restoreTransaction(
                                item,
                                walletProvider: wallets,
                              );
                              await routine.loadRoutines();
                              await routine.syncReminders(ar);
                            } catch (_) {
                              restoreRequested = false;
                              await ReceiptScannerService.deleteManagedReceipt(
                                item.receiptImagePath,
                              );
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ar
                                        ? 'تعذر استعادة المعاملة'
                                        : 'Could not restore entry',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    );
                    await controller.closed;
                    if (!restoreRequested) {
                      await ReceiptScannerService.deleteManagedReceipt(
                        item.receiptImagePath,
                      );
                    }
                  } catch (_) {
                    await tx.loadTransactions();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          ar ? 'تعذر حذف المعاملة' : 'Could not delete entry',
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
