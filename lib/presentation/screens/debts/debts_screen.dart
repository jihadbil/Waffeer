import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/debt_model.dart';
import '../../../providers/debt_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/empty_state_widget.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isArabic = settings.isArabic;
    final debtProvider = context.watch<DebtProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'إدارة الديون والالتزامات' : 'Debts & Loans Tracker'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          tabs: [
            Tab(text: isArabic ? 'مستحقات لي (أقرضتها)' : 'Lent (I am owed)'),
            Tab(text: isArabic ? 'ديون علي (اقترضتها)' : 'Borrowed (I owe)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDebtList(debtProvider.lentDebts, DebtType.lend, isArabic),
          _buildDebtList(debtProvider.borrowedDebts, DebtType.borrow, isArabic),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDebtDialog(context),
        icon: const Icon(Icons.add),
        label: Text(isArabic ? 'إضافة دين / سلفة' : 'Add Debt / Loan'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildDebtList(List<DebtModel> list, DebtType type, bool isArabic) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = type == DebtType.lend ? AppColors.income : AppColors.expense;

    if (list.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.handshake_outlined,
        title: type == DebtType.lend
            ? (isArabic ? 'لا توجد مستحقات مالية لك حالياً' : 'No money lent to anyone')
            : (isArabic ? 'لا توجد ديون مسجلة عليك' : 'No borrowed debts registered'),
        actionLabel: isArabic ? 'إضافة سجل' : 'Add Record',
        onAction: () => _showAddDebtDialog(context),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (ctx, idx) {
        final debt = list[idx];
        final progress = debt.progressPercentage;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: debt.isSettled ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
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
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person_outline_rounded, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          debt.personName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '${isArabic ? "تاريخ الاستحقاق: " : "Due: "}${DateFormatter.formatShort(debt.dueDate, isArabic: isArabic)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (debt.isSettled)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isArabic ? 'مسدد بالكامل ✓' : 'Settled ✓',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: () => _showPaymentDialog(context, debt),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color.withValues(alpha: 0.15),
                        foregroundColor: color,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(isArabic ? 'سداد جزء' : 'Pay part'),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(debt.isSettled ? AppColors.primary : color),
                ),
              ),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${isArabic ? "المتبقي: " : "Remaining: "}${CurrencyFormatter.format(debt.remainingAmount, currencyCode: debt.currencyCode, isArabic: isArabic)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                  Text(
                    '${isArabic ? "الإجمالي: " : "Total: "}${CurrencyFormatter.format(debt.totalAmount, currencyCode: debt.currencyCode, isArabic: isArabic)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddDebtDialog(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final isArabic = settings.isArabic;
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    DebtType selectedType = _tabController.index == 0 ? DebtType.lend : DebtType.borrow;
    DateTime dueDate = DateTime.now().add(const Duration(days: 30));

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
                      isArabic ? 'تسجيل دين أو سلفة' : 'Add Debt / Loan',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: isArabic ? 'اسم الشخص' : 'Person name',
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: isArabic ? 'المبلغ الكلي' : 'Total amount',
                        prefixIcon: const Icon(Icons.attach_money),
                        suffixText: settings.currency.symbol,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        ChoiceChip(
                          label: Text(isArabic ? 'مستحقات لي' : 'Lent (I am owed)'),
                          selected: selectedType == DebtType.lend,
                          onSelected: (val) => setModalState(() => selectedType = DebtType.lend),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(isArabic ? 'ديون علي' : 'Borrowed (I owe)'),
                          selected: selectedType == DebtType.borrow,
                          onSelected: (val) => setModalState(() => selectedType = DebtType.borrow),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          final name = nameController.text.trim();
                          final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                          if (name.isNotEmpty && amount > 0) {
                            context.read<DebtProvider>().addDebt(
                              personName: name,
                              totalAmount: amount,
                              type: selectedType,
                              dueDate: dueDate,
                              currencyCode: settings.currencyCode,
                            );
                            Navigator.pop(ctx);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(isArabic ? 'حفظ السجل ✓' : 'Save Record ✓'),
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

  void _showPaymentDialog(BuildContext context, DebtModel debt) {
    final settings = context.read<SettingsProvider>();
    final isArabic = settings.isArabic;
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'تسجيل دفعة سداد' : 'Record Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${isArabic ? "الشخص: " : "Person: "}${debt.personName}'),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: isArabic ? 'مبلغ الدفعة' : 'Payment amount',
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
                context.read<DebtProvider>().recordPayment(debt.id, amount);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(isArabic ? 'تأكيد السداد' : 'Confirm'),
          ),
        ],
      ),
    );
  }
}
