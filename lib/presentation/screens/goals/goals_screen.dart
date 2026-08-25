import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/goal_model.dart';
import '../../../providers/goal_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/empty_state_widget.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isArabic = settings.isArabic;
    final goalProvider = context.watch<GoalProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final goals = goalProvider.goals;

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'أهداف الادخار والتوفير' : 'Savings Goals'),
      ),
      body: goals.isEmpty
          ? EmptyStateWidget(
              icon: Icons.savings_outlined,
              title: isArabic ? 'لم تحدد أي هدف ادخار بعد' : 'No savings goals set yet',
              subtitle: isArabic
                  ? 'ضع أهدافك المالية (شراء سيارة، صندوق طوارئ، عطلة) وتابع تقدمك خطوة بخطوة'
                  : 'Set your financial goals (emergency fund, travel, car) and track your progress',
              actionLabel: isArabic ? 'إنشاء هدف ادخار' : 'Create Savings Goal',
              onAction: () => _showAddGoalDialog(context),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: goals.length,
              itemBuilder: (ctx, idx) {
                final goal = goals[idx];
                final progress = goal.progressPercentage;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: goal.isCompleted
                          ? AppColors.primary
                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      width: goal.isCompleted ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Color(goal.colorValue).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              IconData(goal.iconCodePoint, fontFamily: 'MaterialIcons'),
                              color: Color(goal.colorValue),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  goal.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  '${isArabic ? "الموعد المستهدف: " : "Target: "}${DateFormatter.formatShort(goal.targetDate, isArabic: isArabic)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (goal.isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isArabic ? 'مكتمل 🎉' : 'Done 🎉',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                              onPressed: () => _showAddFundsDialog(context, goal),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            goal.isCompleted ? AppColors.primary : Color(goal.colorValue),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${isArabic ? "تم توفير: " : "Saved: "}${CurrencyFormatter.format(goal.savedAmount, currencyCode: goal.currencyCode, isArabic: isArabic)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            '${isArabic ? "الهدف: " : "Target: "}${CurrencyFormatter.format(goal.targetAmount, currencyCode: goal.currencyCode, isArabic: isArabic)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGoalDialog(context),
        icon: const Icon(Icons.add),
        label: Text(isArabic ? 'هدف جديد' : 'New Goal'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showAddGoalDialog(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final isArabic = settings.isArabic;
    final titleController = TextEditingController();
    final targetController = TextEditingController();
    final savedController = TextEditingController();
    DateTime targetDate = DateTime.now().add(const Duration(days: 90));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'إنشاء هدف ادخار جديد' : 'Create Savings Goal',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        hintText: isArabic ? 'اسم الهدف (مثل: سيارة جديدة)' : 'Goal title',
                        prefixIcon: const Icon(Icons.flag_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: targetController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: isArabic ? 'المبلغ المستهدف' : 'Target Amount',
                        prefixIcon: const Icon(Icons.attach_money),
                        suffixText: settings.currency.symbol,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: savedController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: isArabic ? 'المبلغ الموفر حالياً (إن وجد)' : 'Initial Saved Amount',
                        prefixIcon: const Icon(Icons.savings_outlined),
                        suffixText: settings.currency.symbol,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          final title = titleController.text.trim();
                          final target = double.tryParse(targetController.text.trim()) ?? 0.0;
                          final saved = double.tryParse(savedController.text.trim()) ?? 0.0;

                          if (title.isNotEmpty && target > 0) {
                            context.read<GoalProvider>().addGoal(
                              title: title,
                              targetAmount: target,
                              savedAmount: saved,
                              targetDate: targetDate,
                              currencyCode: settings.currencyCode,
                              iconCodePoint: 0xe56c, // savings
                              colorValue: 0xFF10B981,
                            );
                            Navigator.pop(ctx);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(isArabic ? 'حفظ الهدف ✓' : 'Save Goal ✓'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddFundsDialog(BuildContext context, GoalModel goal) {
    final settings = context.read<SettingsProvider>();
    final isArabic = settings.isArabic;
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'إيداع في الهدف' : 'Add to Goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${isArabic ? "الهدف: " : "Goal: "}${goal.title}'),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '0.00',
                suffixText: settings.currency.symbol,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
              if (amount > 0) {
                context.read<GoalProvider>().addSavingsToGoal(goal.id, amount);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(isArabic ? 'إيداع' : 'Deposit'),
          ),
        ],
      ),
    );
  }
}
