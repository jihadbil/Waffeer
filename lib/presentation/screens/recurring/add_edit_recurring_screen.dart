import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/recurring_transaction_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/recurring_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/wallet_provider.dart';

class AddEditRecurringScreen extends StatefulWidget {
  final RecurringTransactionModel? recurring;

  const AddEditRecurringScreen({super.key, this.recurring});

  @override
  State<AddEditRecurringScreen> createState() => _AddEditRecurringScreenState();
}

class _AddEditRecurringScreenState extends State<AddEditRecurringScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _noteController;

  TransactionType _type = TransactionType.expense;
  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;
  String? _selectedCategoryId;
  String? _selectedWalletId;
  DateTime _startDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final rec = widget.recurring;
    _titleController = TextEditingController(text: rec?.title ?? '');
    _amountController = TextEditingController(text: rec != null ? rec.amount.toString() : '');
    _noteController = TextEditingController(text: rec?.note ?? '');
    if (rec != null) {
      _type = rec.type;
      _frequency = rec.frequency;
      _selectedCategoryId = rec.categoryId;
      _selectedWalletId = rec.walletId;
      _startDate = rec.startDate;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isArabic = settings.isArabic;
    final catProvider = context.watch<CategoryProvider>();
    final walletProvider = context.watch<WalletProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final categories = catProvider.categories
        .where((c) => _type == TransactionType.expense ? c.isExpense : c.isIncome)
        .toList();

    if (_selectedCategoryId == null && categories.isNotEmpty) {
      _selectedCategoryId = categories.first.id;
    }
    if (_selectedWalletId == null && walletProvider.wallets.isNotEmpty) {
      _selectedWalletId = walletProvider.wallets.first.id;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.recurring == null
              ? (isArabic ? 'إضافة معاملة متكررة' : 'Add Recurring')
              : (isArabic ? 'تعديل المعاملة المتكررة' : 'Edit Recurring'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            // Type Segmented Toggle
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTypeButton(
                      type: TransactionType.expense,
                      title: isArabic ? 'مصروف دوري' : 'Recurring Expense',
                      color: AppColors.expense,
                    ),
                  ),
                  Expanded(
                    child: _buildTypeButton(
                      type: TransactionType.income,
                      title: isArabic ? 'دخل دوري' : 'Recurring Income',
                      color: AppColors.income,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: isArabic ? 'عنوان المعاملة / الاشتراك *' : 'Title / Subscription *',
                hintText: isArabic ? 'مثال: راتب شهري، إيجار شقة، Netflix' : 'e.g. Salary, Rent, Netflix',
                prefixIcon: const Icon(Icons.title_rounded),
              ),
              validator: (val) => val == null || val.trim().isEmpty
                  ? (isArabic ? 'يرجى إدخال العنوان' : 'Please enter title')
                  : null,
            ),
            const SizedBox(height: 16),

            // Amount
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: isArabic ? 'المبلغ *' : 'Amount *',
                prefixIcon: const Icon(Icons.attach_money_rounded),
                suffixText: settings.currencyCode,
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return isArabic ? 'يرجى إدخال المبلغ' : 'Please enter amount';
                }
                final num = double.tryParse(val.trim());
                if (num == null || num <= 0) {
                  return isArabic ? 'يرجى إدخال مبلغ صالح' : 'Please enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Frequency Picker
            DropdownButtonFormField<RecurrenceFrequency>(
              initialValue: _frequency,
              decoration: InputDecoration(
                labelText: isArabic ? 'تكرار المعاملة *' : 'Frequency *',
                prefixIcon: const Icon(Icons.repeat_rounded),
              ),
              items: RecurrenceFrequency.values.map((f) {
                String label;
                switch (f) {
                  case RecurrenceFrequency.daily:
                    label = isArabic ? 'يومياً (Daily)' : 'Daily';
                    break;
                  case RecurrenceFrequency.weekly:
                    label = isArabic ? 'أسبوعياً (Weekly)' : 'Weekly';
                    break;
                  case RecurrenceFrequency.monthly:
                    label = isArabic ? 'شهرياً (Monthly)' : 'Monthly';
                    break;
                  case RecurrenceFrequency.yearly:
                    label = isArabic ? 'سنوياً (Yearly)' : 'Yearly';
                    break;
                }
                return DropdownMenuItem(value: f, child: Text(label));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _frequency = val);
              },
            ),
            const SizedBox(height: 16),

            // Start Date Picker
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2040),
                );
                if (picked != null) {
                  setState(() => _startDate = picked);
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: isArabic ? 'تاريخ البدء / الاستحقاق الأول *' : 'Start / First Due Date *',
                  prefixIcon: const Icon(Icons.calendar_today_rounded),
                ),
                child: Text(DateFormatter.formatDate(_startDate, isArabic: isArabic)),
              ),
            ),
            const SizedBox(height: 16),

            // Wallet Picker
            DropdownButtonFormField<String>(
              initialValue: _selectedWalletId,
              decoration: InputDecoration(
                labelText: isArabic ? 'المحفظة / الحساب *' : 'Wallet / Account *',
                prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
              ),
              items: walletProvider.wallets.map((w) {
                return DropdownMenuItem(
                  value: w.id,
                  child: Text(w.localizedName(isArabic)),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedWalletId = val),
            ),
            const SizedBox(height: 16),

            // Category Picker
            Text(
              isArabic ? 'اختر التصنيف *' : 'Select Category *',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((cat) {
                final isSelected = _selectedCategoryId == cat.id;
                return ChoiceChip(
                  avatar: Icon(cat.iconData, size: 16, color: isSelected ? Colors.white : cat.color),
                  label: Text(cat.localizedName(isArabic)),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : null,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategoryId = cat.id);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Note
            TextFormField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: isArabic ? 'ملاحظات إضافية (اختياري)' : 'Additional Notes (Optional)',
                prefixIcon: const Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 28),

            // Submit Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saveRecurring,
                child: Text(
                  widget.recurring == null
                      ? (isArabic ? 'حفظ وجدولة المعاملة' : 'Save & Schedule')
                      : (isArabic ? 'تحديث المعاملة' : 'Update Recurring'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton({
    required TransactionType type,
    required String title,
    required Color color,
  }) {
    final isSelected = _type == type;
    return InkWell(
      onTap: () {
        setState(() {
          _type = type;
          _selectedCategoryId = null;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : null,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveRecurring() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null || _selectedWalletId == null) return;

    final amount = double.parse(_amountController.text.trim());
    final title = _titleController.text.trim();
    final note = _noteController.text.trim();
    final settings = context.read<SettingsProvider>();
    final recProvider = context.read<RecurringProvider>();

    if (widget.recurring == null) {
      await recProvider.addRecurring(
        amount: amount,
        type: _type,
        categoryId: _selectedCategoryId!,
        walletId: _selectedWalletId!,
        title: title,
        note: note.isNotEmpty ? note : null,
        frequency: _frequency,
        startDate: _startDate,
        currencyCode: settings.currencyCode,
      );
    } else {
      final updated = widget.recurring!.copyWith(
        amount: amount,
        type: _type,
        categoryId: _selectedCategoryId!,
        walletId: _selectedWalletId!,
        title: title,
        note: note.isNotEmpty ? note : null,
        frequency: _frequency,
        startDate: _startDate,
      );
      await recProvider.updateRecurring(updated);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }
}
