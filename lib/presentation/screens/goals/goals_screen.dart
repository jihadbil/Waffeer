import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/goal_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/goal_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../widgets/empty_state_widget.dart';

/// شاشة أهداف الادخار والتوفير بتصميم Fintech Luxury 2.0
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
        title: Text(
          isArabic ? 'أهداف الادخار والتوفير' : 'Savings Goals',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ),
      body: goals.isEmpty
          ? EmptyStateWidget(
              icon: Icons.savings_outlined,
              title: isArabic
                  ? 'لم تحدد أي هدف ادخار بعد'
                  : 'No savings goals set yet',
              subtitle: isArabic
                  ? 'ضع أهدافك المالية (شراء سيارة، صندوق طوارئ، عطلة) وتابع تقدمك خطوة بخطوة'
                  : 'Set your financial goals (emergency fund, travel, car) and track your progress',
              actionLabel: isArabic ? 'إنشاء هدف ادخار' : 'Create Savings Goal',
              onAction: () => _showAddGoalDialog(context),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              itemCount: goals.length,
              itemBuilder: (ctx, idx) {
                final goal = goals[idx];
                final progress = goal.progressPercentage;
                final goalColor = Color(goal.colorValue);

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: goal.isCompleted
                          ? AppColors.primary
                          : (isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder),
                      width: goal.isCompleted ? 1.5 : 1,
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
                              color: goalColor.withValues(
                                alpha: isDark ? 0.25 : 0.15,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: goalColor.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              goal.iconData,
                              color: goalColor,
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15.5,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${isArabic ? "الموعد المستهدف: " : "Target: "}${DateFormatter.formatShort(goal.targetDate, isArabic: isArabic)}',
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
                          if (goal.isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isArabic ? 'مكتمل 🎉' : 'Done 🎉',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            )
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                            children: [
                              if (goal.savedAmount > 0)
                                IconButton(
                                  tooltip: isArabic
                                      ? 'سحب من الهدف'
                                      : 'Withdraw funds',
                                  icon: const Icon(
                                    Icons.remove_circle_outline_rounded,
                                    color: AppColors.expense,
                                    size: 24,
                                  ),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    _showWithdrawFundsDialog(context, goal);
                                  },
                                ),
                              IconButton(
                                tooltip:
                                    isArabic ? 'إيداع في الهدف' : 'Add funds',
                                icon: const Icon(
                                  Icons.add_circle_outline_rounded,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  _showAddFundsDialog(context, goal);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            goal.isCompleted ? AppColors.primary : goalColor,
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
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          Text(
                            '${isArabic ? "الهدف: " : "Target: "}${CurrencyFormatter.format(goal.targetAmount, currencyCode: goal.currencyCode, isArabic: isArabic)} (${(progress * 100).toInt()}%)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
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
            _showAddGoalDialog(context);
          },
          icon: const Icon(Icons.add_rounded, size: 22),
          label: Text(
            isArabic ? 'هدف جديد' : 'New Goal',
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
                    isArabic ? 'إنشاء هدف ادخار جديد' : 'New Savings Goal',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      hintText: isArabic
                          ? 'اسم الهدف (مثال: صندوق الطوارئ)'
                          : 'Goal title (e.g. Vacation)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: targetController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      hintText: isArabic ? 'المبلغ المستهدف' : 'Target Amount',
                      prefixText: '${settings.currency.symbol} ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: savedController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      hintText: isArabic
                          ? 'المبلغ الموفر حالياً (اختياري)'
                          : 'Already Saved (Optional)',
                      prefixText: '${settings.currency.symbol} ',
                    ),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: targetDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365 * 5),
                        ),
                      );
                      if (picked != null) {
                        setSheetState(() => targetDate = picked);
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
                            '${isArabic ? "الموعد المستهدف: " : "Target Date: "}${DateFormatter.formatDate(targetDate, isArabic: isArabic)}',
                            style: const TextStyle(fontFamily: 'Cairo'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        final title = titleController.text.trim();
                        final target =
                            double.tryParse(targetController.text.trim()) ?? 0;
                        final saved =
                            double.tryParse(savedController.text.trim()) ?? 0;

                        if (title.isEmpty || target <= 0) return;

                        HapticFeedback.mediumImpact();
                        await ctx.read<GoalProvider>().addGoal(
                          title: title,
                          targetAmount: target,
                          savedAmount: saved,
                          targetDate: targetDate,
                          currencyCode: settings.currencyCode,
                          iconCodePoint: Icons.track_changes_rounded.codePoint,
                          iconFontFamily:
                              Icons.track_changes_rounded.fontFamily,
                          colorValue: 0xFF10B981,
                        );

                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        isArabic ? 'إنشاء الهدف ✓' : 'Create Goal ✓',
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

  void _showAddFundsDialog(BuildContext context, GoalModel goal) {
    final settings = context.read<SettingsProvider>();
    final isArabic = settings.isArabic;
    final walletProvider = context.read<WalletProvider>();
    final amountController = TextEditingController();
    String? selectedWalletId = walletProvider.defaultWallet?.id;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            isArabic ? 'إضافة رصيد للهدف' : 'Add to Savings',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${isArabic ? "إضافة مبلغ إلى: " : "Add funds to "}${goal.title}',
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
                  hintText: isArabic ? 'المبلغ المودع' : 'Deposit Amount',
                  prefixText: '${settings.currency.symbol} ',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: selectedWalletId,
                decoration: InputDecoration(
                  labelText: isArabic
                      ? 'خصم من محفظة (اختياري)'
                      : 'Deduct from wallet (Optional)',
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
                  final goalProv = context.read<GoalProvider>();
                  final txProv = context.read<TransactionProvider>();
                  final walletProv = context.read<WalletProvider>();

                  HapticFeedback.mediumImpact();
                  await goalProv.addSavingsToGoal(
                    goal.id,
                    val,
                  );
                  if (selectedWalletId != null) {
                    await txProv.addTransaction(
                      amount: val,
                      type: TransactionType.expense,
                      categoryId: 'cat_other_exp',
                      walletId: selectedWalletId!,
                      dateTime: DateTime.now(),
                      title: isArabic
                          ? 'إيداع في هدف: ${goal.title}'
                          : 'Savings for goal: ${goal.title}',
                      currencyCode: goal.currencyCode,
                      walletProvider: walletProv,
                    );
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: Text(
                isArabic ? 'إضافة' : 'Deposit',
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWithdrawFundsDialog(BuildContext context, GoalModel goal) {
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
            isArabic ? 'سحب رصيد من الهدف' : 'Withdraw from Savings',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${isArabic ? "سحب مبلغ من: " : "Withdraw funds from "}${goal.title}',
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 6),
              Text(
                '${isArabic ? "الرصيد المتاح للهدف: " : "Available in goal: "}${CurrencyFormatter.format(goal.savedAmount, currencyCode: goal.currencyCode, isArabic: isArabic)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autofocus: true,
                decoration: InputDecoration(
                  hintText: isArabic ? 'المبلغ المسحوب' : 'Withdraw Amount',
                  prefixText: '${settings.currency.symbol} ',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: selectedWalletId,
                decoration: InputDecoration(
                  labelText: isArabic
                      ? 'إيداع في محفظة (اختياري)'
                      : 'Deposit into wallet (Optional)',
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.expense,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final val = double.tryParse(amountController.text.trim()) ?? 0;
                if (val > 0) {
                  if (val > goal.savedAmount) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isArabic
                              ? 'المبلغ المطلوب سحبه أكبر من الرصيد المتوفر في الهدف'
                              : 'Requested amount exceeds available savings in goal',
                        ),
                        backgroundColor: AppColors.expense,
                      ),
                    );
                    return;
                  }
                  final goalProv = context.read<GoalProvider>();
                  final txProv = context.read<TransactionProvider>();
                  final walletProv = context.read<WalletProvider>();

                  HapticFeedback.mediumImpact();
                  await goalProv.withdrawSavingsFromGoal(
                    goal.id,
                    val,
                  );
                  if (selectedWalletId != null) {
                    await txProv.addTransaction(
                      amount: val,
                      type: TransactionType.income,
                      categoryId: 'cat_other_inc',
                      walletId: selectedWalletId!,
                      dateTime: DateTime.now(),
                      title: isArabic
                          ? 'سحب من هدف: ${goal.title}'
                          : 'Withdrawal from goal: ${goal.title}',
                      currencyCode: goal.currencyCode,
                      walletProvider: walletProv,
                    );
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: Text(
                isArabic ? 'سحب' : 'Withdraw',
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
