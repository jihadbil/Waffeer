import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../widgets/empty_state_widget.dart';
import 'add_edit_budget_screen.dart';

/// شاشة إدارة الميزانيات والحدود المالية بتصميم Fintech Luxury 2.0
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
        title: Text(
          isArabic ? 'الميزانيات والحدود' : 'Budgets & Limits',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ),
      body: budgets.isEmpty
          ? EmptyStateWidget(
              icon: Icons.savings_outlined,
              title: isArabic
                  ? 'لم تقم بضبط أي ميزانية بعد'
                  : 'No budgets configured yet',
              subtitle: isArabic
                  ? 'حدد سقفاً لمصاريفك للتحكم بأموالك وتجنب الإسراف'
                  : 'Set spending limits to take control of your expenses',
              actionLabel: isArabic ? 'إنشاء ميزانية' : 'Create Budget',
              onAction: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddEditBudgetScreen(),
                  ),
                );
              },
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              itemCount: budgets.length,
              itemBuilder: (ctx, idx) {
                final budget = budgets[idx];
                final category = budget.categoryId != null
                    ? catProvider.getById(budget.categoryId!)
                    : null;

                final spent = budgetProvider.getSpentAmount(
                  budget,
                  transactions,
                );
                final progress = budgetProvider.getProgress(
                  budget,
                  transactions,
                );
                final remaining = budgetProvider.getRemainingAmount(
                  budget,
                  transactions,
                );
                final isExceeded = budgetProvider.isExceeded(
                  budget,
                  transactions,
                );
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
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isExceeded
                          ? AppColors.expense.withValues(alpha: 0.5)
                          : isNear
                          ? AppColors.warning.withValues(alpha: 0.4)
                          : (isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder),
                      width: isExceeded ? 1.5 : 1,
                    ),
                    boxShadow: const [],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // الترويسة
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: (category?.color ?? AppColors.secondary)
                                  .withValues(alpha: isDark ? 0.22 : 0.15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: (category?.color ?? AppColors.secondary)
                                    .withValues(alpha: 0.3),
                                width: 1,
                              ),
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
                                      : (isArabic
                                            ? 'الميزانية العامة للمصاريف'
                                            : 'Overall Expense Budget'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15.5,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isExceeded
                                      ? (isArabic
                                            ? '⚠️ تم تجاوز الحد المسموح!'
                                            : '⚠️ Budget exceeded!')
                                      : isNear
                                      ? (isArabic
                                            ? '⚡ اقتربت من السقف (80%+)'
                                            : '⚡ Near limit (80%+)')
                                      : (isArabic
                                            ? '✅ الصرف ضمن النطاق الآمن'
                                            : '✅ Within safe limit'),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: statusColor,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.grey,
                              size: 20,
                            ),
                            onPressed: () async {
                              HapticFeedback.mediumImpact();
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: Text(
                                    isArabic
                                        ? 'حذف الميزانية'
                                        : 'Delete Budget',
                                  ),
                                  content: Text(
                                    isArabic
                                        ? 'هل أنت متأكد من حذف هذه الميزانية؟'
                                        : 'Are you sure you want to delete this budget?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: Text(
                                        isArabic ? 'إلغاء' : 'Cancel',
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.expense,
                                      ),
                                      onPressed: () => Navigator.pop(c, true),
                                      child: Text(isArabic ? 'حذف' : 'Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await budgetProvider.deleteBudget(budget.id);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // شريط التقدم ثلاثي الأبعاد
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // الأرقام المالية (المنصرف، الحد، المتبقي)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${isArabic ? "تم صرف: " : "Spent: "}${CurrencyFormatter.format(spent, currencyCode: budget.currencyCode, isArabic: isArabic)}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          Text(
                            '${isArabic ? "الحد: " : "Limit: "}${CurrencyFormatter.format(budget.limitAmount, currencyCode: budget.currencyCode, isArabic: isArabic)}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${isArabic ? "المتبقي: " : "Remaining: "}${CurrencyFormatter.format(remaining, currencyCode: budget.currencyCode, isArabic: isArabic)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: remaining < 0
                              ? AppColors.expense
                              : AppColors.primary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: AppColors.primaryGradient,
          boxShadow: const [],
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddEditBudgetScreen()),
            );
          },
          icon: const Icon(Icons.add_rounded, size: 22),
          label: Text(
            isArabic ? 'إنشاء ميزانية' : 'Create Budget',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
    );
  }
}
