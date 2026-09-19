import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/debt_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/debt_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../widgets/empty_state_widget.dart';

/// شاشة إدارة الديون والالتزامات المالية بتصميم Fintech Luxury 2.0
class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen>
    with SingleTickerProviderStateMixin {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isArabic ? 'إدارة الديون والالتزامات' : 'Debts & Loans Tracker',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark
              ? AppColors.textDarkMuted
              : AppColors.textLightMuted,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
            fontSize: 13.5,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontFamily: 'Cairo',
            fontSize: 13,
          ),
          onTap: (_) => HapticFeedback.selectionClick(),
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
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: AppColors.primaryGradient,
          boxShadow: const [],
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            HapticFeedback.lightImpact();
            _showAddDebtDialog(context);
          },
          icon: const Icon(Icons.add_rounded, size: 22),
          label: Text(
            isArabic ? 'إضافة دين / سلفة' : 'Add Debt / Loan',
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

  Widget _buildDebtList(List<DebtModel> list, DebtType type, bool isArabic) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = type == DebtType.lend ? AppColors.income : AppColors.expense;

    if (list.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.handshake_outlined,
        title: type == DebtType.lend
            ? (isArabic
                  ? 'لا توجد مستحقات مالية لك حالياً'
                  : 'No money lent to anyone')
            : (isArabic
                  ? 'لا توجد ديون مسجلة عليك'
                  : 'No borrowed debts registered'),
        actionLabel: isArabic ? 'إضافة سجل' : 'Add Record',
        onAction: () => _showAddDebtDialog(context),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      itemCount: list.length,
      itemBuilder: (ctx, idx) {
        final debt = list[idx];
        final progress = debt.progressPercentage;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: debt.isSettled
                  ? AppColors.primary
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: debt.isSettled ? 1.5 : 1,
            ),
            boxShadow: const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isDark ? 0.22 : 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.person_rounded, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          debt.personName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.5,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${isArabic ? "تاريخ الاستحقاق: " : "Due: "}${DateFormatter.formatShort(debt.dueDate, isArabic: isArabic)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (debt.isSettled)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isArabic ? 'مسدد بالكامل ✓' : 'Settled ✓',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _showPaymentDialog(context, debt);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color.withValues(
                          alpha: isDark ? 0.22 : 0.12,
                        ),
                        foregroundColor: color,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isArabic ? 'سداد جزء' : 'Pay part',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 7,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    debt.isSettled ? AppColors.primary : color,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${isArabic ? "المسدد: " : "Paid: "}${CurrencyFormatter.format(debt.paidAmount, currencyCode: debt.currencyCode, isArabic: isArabic)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: debt.isSettled ? AppColors.primary : color,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  Text(
                    '${isArabic ? "الإجمالي: " : "Total: "}${CurrencyFormatter.format(debt.totalAmount, currencyCode: debt.currencyCode, isArabic: isArabic)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontFamily: 'Cairo',
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
    final walletProvider = context.read<WalletProvider>();
    final isArabic = settings.isArabic;
    final nameController = TextEditingController();
    final totalController = TextEditingController();
    final phoneController = TextEditingController();
    final noteController = TextEditingController();
    DebtType selectedType = _tabController.index == 1
        ? DebtType.borrow
        : DebtType.lend;
    DateTime dueDate = DateTime.now().add(const Duration(days: 30));
    String? selectedWalletId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: Theme.of(ctx).cardTheme.color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isArabic ? 'تسجيل دين أو سلفة جديدة' : 'Add Debt / Loan',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Text(
                            isArabic ? 'مستحقات لي' : 'Lent (Owed)',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          selected: selectedType == DebtType.lend,
                          selectedColor: AppColors.income.withValues(
                            alpha: 0.2,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setSheetState(() => selectedType = DebtType.lend);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: Text(
                            isArabic ? 'ديون علي' : 'Borrowed (I owe)',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          selected: selectedType == DebtType.borrow,
                          selectedColor: AppColors.expense.withValues(
                            alpha: 0.2,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setSheetState(
                                () => selectedType = DebtType.borrow,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: isArabic ? 'اسم الشخص' : 'Person Name',
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: totalController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      hintText: isArabic ? 'المبلغ الإجمالي' : 'Total Amount',
                      prefixText: '${settings.currency.symbol} ',
                      prefixIcon: const Icon(Icons.attach_money, size: 20),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: isArabic
                          ? 'رقم الهاتف (اختياري)'
                          : 'Phone (Optional)',
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: dueDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365 * 5),
                        ),
                      );
                      if (picked != null) {
                        setSheetState(() => dueDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${isArabic ? "موعد السداد: " : "Due Date: "}${DateFormatter.formatDate(dueDate, isArabic: isArabic)}',
                            style: const TextStyle(fontFamily: 'Cairo'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedWalletId,
                    decoration: InputDecoration(
                      labelText: selectedType == DebtType.lend
                          ? (isArabic
                              ? 'خصم المبلغ من محفظة (اختياري)'
                              : 'Deduct from wallet (Optional)')
                          : (isArabic
                              ? 'إيداع المبلغ في محفظة (اختياري)'
                              : 'Deposit to wallet (Optional)'),
                      prefixIcon: const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 20,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          isArabic
                              ? 'بدون ربط بمحفظة (تسجيل فقط)'
                              : 'No wallet linked (record only)',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(ctx).textTheme.bodySmall?.color,
                          ),
                        ),
                      ),
                      ...walletProvider.wallets
                          .map((w) => DropdownMenuItem<String?>(
                                value: w.id,
                                child: Text(
                                  '${w.localizedName(isArabic)} (${CurrencyFormatter.format(w.currentBalance, currencyCode: w.currencyCode, isArabic: isArabic)})',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              )),
                    ],
                    onChanged: (val) =>
                        setSheetState(() => selectedWalletId = val),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        final total =
                            double.tryParse(totalController.text.trim()) ?? 0;

                        if (name.isEmpty || total <= 0) return;

                        final debtProv = ctx.read<DebtProvider>();
                        final walletProv = ctx.read<WalletProvider>();
                        final txProv = ctx.read<TransactionProvider>();

                        HapticFeedback.mediumImpact();
                        await debtProv.addDebt(
                          personName: name,
                          phoneNumber: phoneController.text.trim().isNotEmpty
                              ? phoneController.text.trim()
                              : null,
                          totalAmount: total,
                          type: selectedType,
                          dueDate: dueDate,
                          currencyCode: settings.currencyCode,
                          note: noteController.text.trim().isNotEmpty
                              ? noteController.text.trim()
                              : null,
                        );

                        if (selectedWalletId != null) {
                          final isLend = selectedType == DebtType.lend;
                          await txProv.addTransaction(
                            amount: total,
                            type: isLend
                                ? TransactionType.expense
                                : TransactionType.income,
                            categoryId:
                                isLend ? 'cat_other_exp' : 'cat_other_inc',
                            walletId: selectedWalletId!,
                            dateTime: DateTime.now(),
                            title: isLend
                                ? (isArabic
                                    ? 'سلفة / إقراض: $name'
                                    : 'Loan to: $name')
                                : (isArabic
                                    ? 'استدانة / اقتراض من: $name'
                                    : 'Borrowed from: $name'),
                            currencyCode: settings.currencyCode,
                            walletProvider: walletProv,
                          );
                        }

                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        isArabic ? 'حفظ السجل ✓' : 'Save Record ✓',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
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
    final walletProvider = context.read<WalletProvider>();
    final isArabic = settings.isArabic;
    final amountController = TextEditingController();
    String? selectedWalletId = walletProvider.defaultWallet?.id;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            isArabic ? 'تسجيل سداد' : 'Record Payment',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${isArabic ? "سداد جزء من دين: " : "Payment for: "}${debt.personName}',
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autofocus: true,
                decoration: InputDecoration(
                  hintText: isArabic ? 'المبلغ المسدد' : 'Payment Amount',
                  prefixText: '${settings.currency.symbol} ',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: selectedWalletId,
                decoration: InputDecoration(
                  labelText: debt.type == DebtType.lend
                      ? (isArabic
                          ? 'إيداع في محفظة (اختياري)'
                          : 'Deposit into wallet (Optional)')
                      : (isArabic
                          ? 'خصم من محفظة (اختياري)'
                          : 'Deduct from wallet (Optional)'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      isArabic ? 'بدون ربط بمحفظة' : 'No wallet linked',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(ctx).textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                  ...walletProvider.wallets.map((w) => DropdownMenuItem<String?>(
                        value: w.id,
                        child: Text(
                          '${w.localizedName(isArabic)} (${CurrencyFormatter.format(w.currentBalance, currencyCode: w.currencyCode, isArabic: isArabic)})',
                          style: const TextStyle(fontSize: 13),
                        ),
                      )),
                ],
                onChanged: (val) =>
                    setDialogState(() => selectedWalletId = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                isArabic ? 'إلغاء' : 'Cancel',
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final val = double.tryParse(amountController.text.trim()) ?? 0;
                if (val > 0) {
                  final debtProv = context.read<DebtProvider>();
                  final walletProv = context.read<WalletProvider>();
                  final txProv = context.read<TransactionProvider>();
                  final isLend = debt.type == DebtType.lend;
                  final transactionTitle = isLend
                      ? (isArabic
                          ? 'استرداد دين من: ${debt.personName}'
                          : 'Debt repayment from: ${debt.personName}')
                      : (isArabic
                          ? 'سداد دين لـ: ${debt.personName}'
                          : 'Debt payment to: ${debt.personName}');

                  HapticFeedback.mediumImpact();
                  try {
                    await debtProv.recordPayment(
                      debt.id,
                      val,
                      walletId: selectedWalletId,
                      paidAt: DateTime.now(),
                      transactionTitle: transactionTitle,
                    );
                    if (selectedWalletId != null) {
                      await txProv.loadTransactions();
                      await walletProv.loadWallets(debt.currencyCode);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  } on StateError {
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(
                          isArabic
                              ? 'المبلغ أكبر من المتبقي على الدين.'
                              : 'The payment exceeds the remaining debt.',
                        ),
                        backgroundColor: AppColors.expense,
                      ),
                    );
                  }
                }
              },
              child: Text(
                isArabic ? 'تسجيل' : 'Record',
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
