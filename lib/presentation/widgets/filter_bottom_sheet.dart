import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/transaction_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/wallet_provider.dart';

class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  TransactionType? _type;
  String? _walletId;
  String? _categoryId;
  DateTimeRange? _dateRange;
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final txProvider = context.read<TransactionProvider>();
    _type = txProvider.selectedType;
    _walletId = txProvider.selectedWalletId;
    _categoryId = txProvider.selectedCategoryId;
    _dateRange = txProvider.customDateRange;
    if (txProvider.minAmount != null) {
      _minAmountController.text = txProvider.minAmount.toString();
    }
    if (txProvider.maxAmount != null) {
      _maxAmountController.text = txProvider.maxAmount.toString();
    }
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isArabic = settings.isArabic;
    final catProvider = context.watch<CategoryProvider>();
    final walletProvider = context.watch<WalletProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'فلترة وتصفية المعاملات' : 'Filter Transactions',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  context.read<TransactionProvider>().clearFilters();
                  Navigator.pop(context);
                },
                child: Text(
                  isArabic ? 'إعادة ضبط' : 'Reset',
                  style: const TextStyle(
                    color: AppColors.expense,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(),

          Expanded(
            child: ListView(
              children: [
                // Transaction Type Chips
                Text(
                  isArabic ? 'نوع المعاملة' : 'Transaction Type',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(isArabic ? 'الكل' : 'All'),
                      selected: _type == null,
                      onSelected: (_) => setState(() => _type = null),
                    ),
                    ChoiceChip(
                      label: Text(isArabic ? 'مصروف' : 'Expense'),
                      selected: _type == TransactionType.expense,
                      selectedColor: AppColors.expense.withValues(alpha: 0.2),
                      onSelected: (_) =>
                          setState(() => _type = TransactionType.expense),
                    ),
                    ChoiceChip(
                      label: Text(isArabic ? 'دخل' : 'Income'),
                      selected: _type == TransactionType.income,
                      selectedColor: AppColors.income.withValues(alpha: 0.2),
                      onSelected: (_) =>
                          setState(() => _type = TransactionType.income),
                    ),
                    ChoiceChip(
                      label: Text(isArabic ? 'تحويل' : 'Transfer'),
                      selected: _type == TransactionType.transfer,
                      selectedColor: AppColors.transfer.withValues(alpha: 0.2),
                      onSelected: (_) =>
                          setState(() => _type = TransactionType.transfer),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Custom Date Range Picker
                Text(
                  isArabic ? 'نطاق التاريخ' : 'Date Range',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                      initialDateRange:
                          _dateRange ??
                          DateTimeRange(
                            start: DateTime.now().subtract(
                              const Duration(days: 30),
                            ),
                            end: DateTime.now(),
                          ),
                    );
                    if (range != null) {
                      setState(() => _dateRange = range);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _dateRange == null
                                  ? (isArabic
                                        ? 'تحديد نطاق مخصص (اختياري)'
                                        : 'Select Custom Range (Optional)')
                                  : '${DateFormatter.formatDate(_dateRange!.start, isArabic: isArabic)}  -  ${DateFormatter.formatDate(_dateRange!.end, isArabic: isArabic)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _dateRange != null
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        if (_dateRange != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _dateRange = null),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Wallets Chips
                Text(
                  isArabic ? 'المحفظة / الحساب' : 'Wallet / Account',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: Text(isArabic ? 'كل المحافظ' : 'All Wallets'),
                      selected: _walletId == null,
                      onSelected: (_) => setState(() => _walletId = null),
                    ),
                    ...walletProvider.wallets.map((w) {
                      return ChoiceChip(
                        label: Text(w.localizedName(isArabic)),
                        selected: _walletId == w.id,
                        onSelected: (_) => setState(() => _walletId = w.id),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 18),

                // Categories Chips
                Text(
                  isArabic ? 'التصنيف' : 'Category',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: Text(isArabic ? 'كل التصنيفات' : 'All Categories'),
                      selected: _categoryId == null,
                      onSelected: (_) => setState(() => _categoryId = null),
                    ),
                    ...catProvider.categories.map((c) {
                      return ChoiceChip(
                        label: Text(c.localizedName(isArabic)),
                        selected: _categoryId == c.id,
                        onSelected: (_) => setState(() => _categoryId = c.id),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 18),

                // Min & Max Amount Fields
                Text(
                  isArabic ? 'نطاق المبلغ' : 'Amount Range',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minAmountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText: isArabic ? 'الحد الأدنى' : 'Min Amount',
                          prefixIcon: const Icon(
                            Icons.remove_circle_outline,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _maxAmountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText: isArabic ? 'الحد الأقصى' : 'Max Amount',
                          prefixIcon: const Icon(
                            Icons.add_circle_outline,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // Apply Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              child: Text(
                isArabic ? 'تطبيق الفلترة' : 'Apply Filters',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              onPressed: () {
                final minVal = double.tryParse(
                  _minAmountController.text.trim(),
                );
                final maxVal = double.tryParse(
                  _maxAmountController.text.trim(),
                );

                context.read<TransactionProvider>().setFilter(
                  type: _type,
                  walletId: _walletId,
                  categoryId: _categoryId,
                  dateRange: _dateRange,
                  minAmount: minVal,
                  maxAmount: maxVal,
                );
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}
