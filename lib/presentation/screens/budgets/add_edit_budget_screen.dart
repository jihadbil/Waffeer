import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/budget_model.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/settings_provider.dart';

class AddEditBudgetScreen extends StatefulWidget {
  const AddEditBudgetScreen({super.key});

  @override
  State<AddEditBudgetScreen> createState() => _AddEditBudgetScreenState();
}

class _AddEditBudgetScreenState extends State<AddEditBudgetScreen> {
  final TextEditingController _amountController = TextEditingController();
  String? _selectedCategoryId; // null = overall
  BudgetPeriod _selectedPeriod = BudgetPeriod.monthly;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isArabic = settings.isArabic;
    final catProvider = context.watch<CategoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'إنشاء ميزانية جديدة' : 'Create New Budget'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount Limit
            Text(
              isArabic ? 'مبلغ الميزانية الأقصى' : 'Budget Limit Amount',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '0.00',
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                suffixText: settings.currency.symbol,
              ),
            ),
            const SizedBox(height: 20),

            // Category Selection (Optional for overall)
            Text(
              isArabic ? 'التصنيف المخصص' : 'Target Category',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: _selectedCategoryId,
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(isArabic ? '📊 ميزانية إجمالية لكل المصاريف' : '📊 Overall Total Expenses'),
                ),
                ...catProvider.expenseCategories.map((c) {
                  return DropdownMenuItem<String?>(
                    value: c.id,
                    child: Row(
                      children: [
                        Icon(c.iconData, color: c.color, size: 20),
                        const SizedBox(width: 10),
                        Text(c.localizedName(isArabic)),
                      ],
                    ),
                  );
                }),
              ],
              onChanged: (val) => setState(() => _selectedCategoryId = val),
            ),
            const SizedBox(height: 20),

            // Period
            Text(
              isArabic ? 'فترة الميزانية' : 'Budget Period',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<BudgetPeriod>(
              value: _selectedPeriod,
              items: [
                DropdownMenuItem(
                  value: BudgetPeriod.monthly,
                  child: Text(isArabic ? 'شهرياً' : 'Monthly'),
                ),
                DropdownMenuItem(
                  value: BudgetPeriod.weekly,
                  child: Text(isArabic ? 'أسبوعياً' : 'Weekly'),
                ),
                DropdownMenuItem(
                  value: BudgetPeriod.yearly,
                  child: Text(isArabic ? 'سنوياً' : 'Yearly'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedPeriod = val);
              },
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saveBudget,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  isArabic ? 'حفظ وتفعيل الميزانية ✓' : 'Save & Activate Budget ✓',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveBudget() async {
    final settings = context.read<SettingsProvider>();
    final isArabic = settings.isArabic;
    final amountText = _amountController.text.trim();

    final limit = double.tryParse(amountText.replaceAll(',', ''));
    if (limit == null || limit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'يرجى إدخال مبلغ صحيح للميزانية' : 'Please enter a valid budget amount'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    if (_selectedPeriod == BudgetPeriod.weekly) {
      startDate = now.subtract(Duration(days: now.weekday - 1));
      endDate = startDate.add(const Duration(days: 6, hours: 23, minutes: 59));
    } else if (_selectedPeriod == BudgetPeriod.yearly) {
      startDate = DateTime(now.year, 1, 1);
      endDate = DateTime(now.year, 12, 31, 23, 59, 59);
    } else {
      // Monthly
      startDate = DateTime(now.year, now.month, 1);
      final lastDay = DateTime(now.year, now.month + 1, 0).day;
      endDate = DateTime(now.year, now.month, lastDay, 23, 59, 59);
    }

    await context.read<BudgetProvider>().addBudget(
      categoryId: _selectedCategoryId,
      limitAmount: limit,
      period: _selectedPeriod,
      startDate: startDate,
      endDate: endDate,
      currencyCode: settings.currencyCode,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'تم تفعيل الميزانية بنجاح' : 'Budget activated successfully'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pop(context);
    }
  }
}
