import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../widgets/balance_card.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/quick_action_button.dart';
import '../../widgets/transaction_tile.dart';
import '../budgets/budgets_screen.dart';
import '../transactions/add_edit_transaction_screen.dart';
import '../transactions/transactions_list_screen.dart';
import '../wallets/wallets_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isArabic = settings.isArabic;
    final walletProvider = context.watch<WalletProvider>();
    final txProvider = context.watch<TransactionProvider>();
    final budgetProvider = context.watch<BudgetProvider>();

    final recentTransactions = txProvider.recentTransactions;
    final totalBalance = walletProvider.totalBalance;
    final monthlyExpense = txProvider.monthlyExpense;
    final monthlyIncome = txProvider.monthlyIncome;

    // Check if any budget is exceeded or near limit
    final warningBudgets = budgetProvider.budgets.where((b) {
      return budgetProvider.isExceeded(b, txProvider.transactions) ||
          budgetProvider.isNearLimit(b, txProvider.transactions);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'وفير' : 'Waffeer',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  isArabic ? 'إدارة المصاريف الذكية' : 'Smart Personal Finance',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: isArabic ? 'المحافظ' : 'Wallets',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalletsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await walletProvider.loadWallets(settings.currencyCode);
          await txProvider.loadTransactions();
          await budgetProvider.loadBudgets();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // 1. Hero Balance Card
            BalanceCard(
              totalBalance: totalBalance,
              monthlyIncome: monthlyIncome,
              monthlyExpense: monthlyExpense,
              currencyCode: settings.currencyCode,
              isArabic: isArabic,
              onManageWallets: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WalletsScreen()),
                );
              },
            ),
            const SizedBox(height: 18),

            // 2. Budget Alert Banner (if any)
            if (warningBudgets.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isArabic
                            ? 'تنبيه: اقتربت أو تجاوزت إحدى الميزانيات المحددة لشهرك الحالي!'
                            : 'Alert: You are near or exceeded one of your active budgets!',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BudgetsScreen()),
                        );
                      },
                      child: Text(
                        isArabic ? 'عرض' : 'View',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // 3. Quick Action Shortcuts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                QuickActionButton(
                  icon: Icons.add_circle_outline_rounded,
                  label: isArabic ? 'إضافة مصروف' : 'Add Expense',
                  color: AppColors.expense,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddEditTransactionScreen(
                          initialType: TransactionType.expense,
                        ),
                      ),
                    );
                  },
                ),
                QuickActionButton(
                  icon: Icons.arrow_downward_rounded,
                  label: isArabic ? 'إضافة دخل' : 'Add Income',
                  color: AppColors.income,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddEditTransactionScreen(
                          initialType: TransactionType.income,
                        ),
                      ),
                    );
                  },
                ),
                QuickActionButton(
                  icon: Icons.swap_horiz_rounded,
                  label: isArabic ? 'تحويل مالي' : 'Transfer',
                  color: AppColors.transfer,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddEditTransactionScreen(
                          initialType: TransactionType.transfer,
                        ),
                      ),
                    );
                  },
                ),
                QuickActionButton(
                  icon: Icons.pie_chart_rounded,
                  label: isArabic ? 'الميزانيات' : 'Budgets',
                  color: const Color(0xFF8B5CF6),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BudgetsScreen()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 4. Recent Transactions Header & List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isArabic ? 'آخر المعاملات' : 'Recent Transactions',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TransactionsListScreen()),
                    );
                  },
                  child: Text(
                    isArabic ? 'عرض الكل' : 'View All',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (recentTransactions.isEmpty)
              EmptyStateWidget(
                icon: Icons.receipt_long_outlined,
                title: isArabic ? 'لا توجد حركات مسجلة بعد' : 'No transactions recorded yet',
                subtitle: isArabic
                    ? 'سجل مصاريفك اليومية ومداخيلك لتبدأ في تتبع أموالك'
                    : 'Start adding your daily expenses & income to track your cashflow',
                actionLabel: isArabic ? 'إضافة أول معاملة' : 'Add First Transaction',
                onAction: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddEditTransactionScreen()),
                  );
                },
              )
            else
              ...recentTransactions.map((tx) {
                return TransactionTile(
                  transaction: tx,
                  onDelete: () async {
                    await txProvider.deleteTransaction(tx, walletProvider: walletProvider);
                  },
                );
              }),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
