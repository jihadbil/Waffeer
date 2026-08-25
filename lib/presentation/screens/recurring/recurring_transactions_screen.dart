import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/recurring_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../widgets/category_icon_widget.dart';
import '../../widgets/empty_state_widget.dart';
import 'add_edit_recurring_screen.dart';

class RecurringTransactionsScreen extends StatelessWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isArabic = settings.isArabic;
    final recProvider = context.watch<RecurringProvider>();
    final catProvider = context.watch<CategoryProvider>();
    final walletProvider = context.watch<WalletProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final list = recProvider.recurringTransactions;

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'المعاملات المتكررة والاشتراكات' : 'Recurring & Subscriptions'),
      ),
      body: list.isEmpty
          ? EmptyStateWidget(
              icon: Icons.repeat_rounded,
              title: isArabic ? 'لا توجد معاملات متكررة مجدولة' : 'No recurring transactions scheduled',
              subtitle: isArabic
                  ? 'أضف الرواتب، الإيجارات، أو الاشتراكات لتتم إضافتها تلقائياً في موعدها'
                  : 'Add salaries, rent, or subscriptions to be added automatically on due dates',
              actionButton: ElevatedButton.icon(
                icon: const Icon(Icons.add, color: Colors.white),
                label: Text(
                  isArabic ? 'إضافة معاملة متكررة' : 'Add Recurring Transaction',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddEditRecurringScreen()),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final item = list[index];
                final cat = catProvider.getById(item.categoryId);
                final wallet = walletProvider.getById(item.walletId);

                return Dismissible(
                  key: Key(item.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.expense,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: isArabic ? Alignment.centerLeft : Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(isArabic ? 'تأكيد الحذف' : 'Confirm Delete'),
                        content: Text(
                          isArabic
                              ? 'هل أنت متأكد من حذف هذه المعاملة المتكررة؟'
                              : 'Are you sure you want to delete this recurring transaction?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(
                              isArabic ? 'حذف' : 'Delete',
                              style: const TextStyle(color: AppColors.expense),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) {
                    recProvider.deleteRecurring(item.id);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        CategoryIconWidget(
                          iconData: cat?.iconData ?? Icons.repeat,
                          color: cat?.color ?? AppColors.primary,
                          size: 46,
                          iconSize: 22,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.localizedFrequency(isArabic),
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    wallet?.localizedName(isArabic) ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).textTheme.bodyMedium?.color,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${isArabic ? "الاستحقاق القادم:" : "Next Due:"} ${DateFormatter.formatDate(item.nextDueDate, isArabic: isArabic)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).textTheme.bodySmall?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${item.type == TransactionType.expense ? "-" : "+"}${CurrencyFormatter.format(item.amount, currencyCode: item.currencyCode, isArabic: isArabic)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: item.type == TransactionType.expense
                                    ? AppColors.expense
                                    : AppColors.income,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Switch(
                              value: item.isActive,
                              activeThumbColor: AppColors.primary,
                              onChanged: (_) {
                                recProvider.toggleActive(item.id);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddEditRecurringScreen()),
        ),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
