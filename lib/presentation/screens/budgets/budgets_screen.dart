import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../widgets/empty_state_widget.dart';
import 'add_edit_budget_screen.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isArabic = settings.isArabic;
    final budgetProvider = context.watch<BudgetProvider>();
    final catProvider = context.watch<CategoryProvider>();
    final txProvider = context.watch<TransactionProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final budgets = budgetProvider.budgets;
    final transactions = txProvider.transactions;

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'الميزانيات والحدود' : 'Budgets & Limits'),
      ),
      body: budgets.isEmpty
          ? EmptyStateWidget(
              icon: Icons.savings_outlined,
              title: isArabic ? 'لم تقم بضبط أي ميزانية بعد' : 'No budgets configured yet',
              subtitle: isArabic
                  ? 'حدد سقفاً لمصاريفك للتحكم بأموالك وتجنب الإسراف'
                  : 'Set spending limits to take control of your expenses',
              actionLabel: isArabic ? 'إنشاء ميزانية' : 'Create Budget',
              onAction: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddEditBudgetScreen()),
                );
              },
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: budgets.length,
              itemBuilder: (ctx, idx) {
                final budget = budgets[idx];
                final category = budget.categoryId != null
                    ? catProvider.getById(budget.categoryId!)
                    : null;

                final spent = budgetProvider.getSpentAmount(budget, transactions);
                final progress = budgetProvider.getProgress(budget, transactions);
                final remaining = budgetProvider.getRemainingAmount(budget, transactions);
                final isExceeded = budgetProvider.isExceeded(budget, transactions);
                final isNear = budgetProvider.isNearLimit(budget, transactions);

                final Color statusColor = isExceeded
                    ? AppColors.expense
                    : isNear
                        ? AppColors.warning
                        : AppColors.primary;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isExceeded
                          ? AppColors.expense.withValues(alpha: 0.5)
                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      width: isExceeded ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (category?.color ?? AppColors.secondary).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              category?.iconData ?? Icons.pie_chart_rounded,
                              color: category?.color ?? AppColors.secondary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category != null
                                      ? category.localizedName(isArabic)
                                      : (isArabic ? 'الميزانية العامة للمصاريف' : 'Overall Expense Budget'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  isExceeded
                                      ? (isArabic ? '⚠️ تم تجاوز الحد المسموح!' : '⚠️ Budget exceeded!')
                                      : isNear
                                          ? (isArabic ? '⚡ اقتربت من السقف المحدد (80%+)' : '⚡ Near limit (80%+)')
                                          : (isArabic ? '✅ الصرف ضمن النطاق الآمن' : '✅ Within safe limit'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: statusColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                            onPressed: () async {
                              await budgetProvider.deleteBudget(budget.id);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Spent vs Limit Numbers
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${isArabic ? "تم صرف: " : "Spent: "}${CurrencyFormatter.format(spent, currencyCode: budget.currencyCode, isArabic: isArabic)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                          Text(
                            '${isArabic ? "الحد: " : "Limit: "}${CurrencyFormatter.format(budget.limitAmount, currencyCode: budget.currencyCode, isArabic: isArabic)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${isArabic ? "المتبقي: " : "Remaining: "}${CurrencyFormatter.format(remaining, currencyCode: budget.currencyCode, isArabic: isArabic)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditBudgetScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: Text(isArabic ? 'ميزانية جديدة' : 'New Budget'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}
