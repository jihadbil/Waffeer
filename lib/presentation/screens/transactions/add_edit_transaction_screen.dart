import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../widgets/category_icon_widget.dart';

class AddEditTransactionScreen extends StatefulWidget {
  final TransactionType initialType;

  const AddEditTransactionScreen({
    super.key,
    this.initialType = TransactionType.expense,
  });

  @override
  State<AddEditTransactionScreen> createState() => _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState extends State<AddEditTransactionScreen> {
  late TransactionType _selectedType;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String? _selectedCategoryId;
  String? _selectedWalletId;
  String? _selectedToWalletId;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final catProvider = context.read<CategoryProvider>();
      final walletProvider = context.read<WalletProvider>();

      if (_selectedCategoryId == null) {
        if (_selectedType == TransactionType.expense && catProvider.expenseCategories.isNotEmpty) {
          _selectedCategoryId = catProvider.expenseCategories.first.id;
        } else if (_selectedType == TransactionType.income && catProvider.incomeCategories.isNotEmpty) {
          _selectedCategoryId = catProvider.incomeCategories.first.id;
        }
      }

      if (_selectedWalletId == null && walletProvider.wallets.isNotEmpty) {
        _selectedWalletId = walletProvider.defaultWallet?.id ?? walletProvider.wallets.first.id;
        if (walletProvider.wallets.length > 1) {
          _selectedToWalletId = walletProvider.wallets[1].id;
        }
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
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

    final categories = _selectedType == TransactionType.expense
        ? catProvider.expenseCategories
        : catProvider.incomeCategories;

    final Color accentColor = _selectedType == TransactionType.expense
        ? AppColors.expense
        : _selectedType == TransactionType.income
            ? AppColors.income
            : AppColors.transfer;

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'إضافة معاملة جديدة' : 'Add Transaction'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Segmented Type Selector (Expense / Income / Transfer)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _buildTypeTab(
                    type: TransactionType.expense,
                    label: isArabic ? 'مصروف' : 'Expense',
                    icon: Icons.arrow_upward_rounded,
                    activeColor: AppColors.expense,
                  ),
                  _buildTypeTab(
                    type: TransactionType.income,
                    label: isArabic ? 'دخل' : 'Income',
                    icon: Icons.arrow_downward_rounded,
                    activeColor: AppColors.income,
                  ),
                  _buildTypeTab(
                    type: TransactionType.transfer,
                    label: isArabic ? 'تحويل' : 'Transfer',
                    icon: Icons.swap_horiz_rounded,
                    activeColor: AppColors.transfer,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Amount Input Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    isArabic ? 'المبلغ' : 'Amount',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        settings.currency.symbol,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IntrinsicWidth(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white30 : Colors.black26,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Categories Section (For Expense & Income)
            if (_selectedType != TransactionType.transfer) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isArabic ? 'التصنيف' : 'Category',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    '${categories.length} ${isArabic ? "تصنيف" : "categories"}',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 95,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (ctx, idx) {
                    final cat = categories[idx];
                    final isSelected = cat.id == _selectedCategoryId;

                    return InkWell(
                      onTap: () => setState(() => _selectedCategoryId = cat.id),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 78,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cat.color.withValues(alpha: isDark ? 0.25 : 0.15)
                              : Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? cat.color
                                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CategoryIconWidget(
                              iconData: cat.iconData,
                              color: cat.color,
                              size: 40,
                              iconSize: 20,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              cat.localizedName(isArabic),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Wallet Selection
            Text(
              _selectedType == TransactionType.transfer
                  ? (isArabic ? 'من حساب / محفظة' : 'From Wallet')
                  : (isArabic ? 'الحساب / المحفظة' : 'Wallet / Account'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedWalletId,
              items: walletProvider.wallets.map((w) {
                return DropdownMenuItem(
                  value: w.id,
                  child: Row(
                    children: [
                      Icon(w.iconData, color: w.color, size: 20),
                      const SizedBox(width: 10),
                      Text(w.localizedName(isArabic)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedWalletId = val),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),

            // To Wallet (Only if Transfer)
            if (_selectedType == TransactionType.transfer) ...[
              const SizedBox(height: 16),
              Text(
                isArabic ? 'إلى حساب / محفظة' : 'To Wallet',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedToWalletId,
                items: walletProvider.wallets
                    .where((w) => w.id != _selectedWalletId)
                    .map((w) {
                  return DropdownMenuItem(
                    value: w.id,
                    child: Row(
                      children: [
                        Icon(w.iconData, color: w.color, size: 20),
                        const SizedBox(width: 10),
                        Text(w.localizedName(isArabic)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedToWalletId = val),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Date & Time Picker
            Text(
              isArabic ? 'التاريخ والوقت' : 'Date & Time',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (pickedDate != null && context.mounted) {
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_selectedDate),
                  );
                  setState(() {
                    _selectedDate = DateTime(
                      pickedDate.year,
                      pickedDate.month,
                      pickedDate.day,
                      pickedTime?.hour ?? _selectedDate.hour,
                      pickedTime?.minute ?? _selectedDate.minute,
                    );
                  });
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text(
                      '${DateFormatter.formatShort(_selectedDate, isArabic: isArabic)}  •  ${DateFormatter.formatTime(_selectedDate, isArabic: isArabic)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title & Note Input
            Text(
              isArabic ? 'العنوان والملاحظات (اختياري)' : 'Title & Notes (Optional)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: isArabic ? 'عنوان المعاملة (مثل: عشاء في مطعم)' : 'Transaction title...',
                prefixIcon: const Icon(Icons.edit_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: isArabic ? 'ملاحظات إضافية...' : 'Additional notes...',
                prefixIcon: const Icon(Icons.notes_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 28),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saveTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isArabic ? 'حفظ المعاملة ✓' : 'Save Transaction ✓',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeTab({
    required TransactionType type,
    required String label,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
            final catProvider = context.read<CategoryProvider>();
            if (type == TransactionType.expense && catProvider.expenseCategories.isNotEmpty) {
              _selectedCategoryId = catProvider.expenseCategories.first.id;
            } else if (type == TransactionType.income && catProvider.incomeCategories.isNotEmpty) {
              _selectedCategoryId = catProvider.incomeCategories.first.id;
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isSelected ? Colors.white : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveTransaction() async {
    final settings = context.read<SettingsProvider>();
    final isArabic = settings.isArabic;
    final amountText = _amountController.text.trim();

    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'يرجى إدخال مبلغ صحيح' : 'Please enter a valid amount'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    final amount = double.tryParse(amountText.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'يرجى إدخال مبلغ أكبر من الصفر' : 'Amount must be greater than 0'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    if (_selectedWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'يرجى اختيار المحفظة' : 'Please select a wallet'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    if (_selectedType == TransactionType.transfer && _selectedToWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'يرجى اختيار المحفظة المحول إليها' : 'Please select destination wallet'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    final categoryId = _selectedType == TransactionType.transfer
        ? 'cat_transfer'
        : (_selectedCategoryId ?? 'cat_other_exp');

    final walletProvider = context.read<WalletProvider>();
    final txProvider = context.read<TransactionProvider>();

    await txProvider.addTransaction(
      amount: amount,
      type: _selectedType,
      categoryId: categoryId,
      walletId: _selectedWalletId!,
      toWalletId: _selectedType == TransactionType.transfer ? _selectedToWalletId : null,
      dateTime: _selectedDate,
      title: _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : null,
      note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
      currencyCode: settings.currencyCode,
      walletProvider: walletProvider,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'تم حفظ المعاملة بنجاح ✓' : 'Transaction saved successfully ✓'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pop(context);
    }
  }
}
