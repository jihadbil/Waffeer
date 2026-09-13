import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/currencies.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/goal_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../main_navigation_screen.dart';

class FinancialSetupScreen extends StatefulWidget {
  final String currencyCode;

  const FinancialSetupScreen({super.key, required this.currencyCode});

  @override
  State<FinancialSetupScreen> createState() => _FinancialSetupScreenState();
}

class _FinancialSetupScreenState extends State<FinancialSetupScreen> {
  final _balanceController = TextEditingController();
  final _incomeController = TextEditingController();
  final _goalController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _balanceController.dispose();
    _incomeController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  double _amountOf(TextEditingController controller) {
    return double.tryParse(controller.text.trim().replaceAll(',', '')) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isArabic = settings.isArabic;
    final currency = Currencies.getByCode(widget.currencyCode);

    return Scaffold(
      appBar: AppBar(title: Text(isArabic ? 'إعداد خطتك' : 'Set up your plan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.auto_graph_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic
                            ? 'لنبدأ بصورة مالية مفيدة'
                            : 'Start with a useful money picture',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isArabic ? 'كل الحقول اختيارية ويمكن تعديلها لاحقًا.' : 'Every field is optional and can be changed later.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SetupField(
              label: isArabic ? 'رصيدك النقدي الحالي' : 'Current cash balance',
              helper: isArabic ? 'يُستخدم كبداية دقيقة لحساب المتاح للإنفاق.' : 'Used as an accurate starting point for available spending.',
              controller: _balanceController,
              currencySymbol: currency.symbol,
              icon: Icons.account_balance_wallet_outlined,
            ),
            const SizedBox(height: 18),
            _SetupField(
              label: isArabic ? 'دخل هذا الشهر' : 'Income received this month',
              helper: isArabic
                  ? 'يساعد وفير على تقدير المتاح يوميًا حتى نهاية الشهر.'
                  : 'Helps Waffeer estimate what is available each day.',
              controller: _incomeController,
              currencySymbol: currency.symbol,
              icon: Icons.payments_outlined,
            ),
            const SizedBox(height: 18),
            _SetupField(
              label: isArabic ? 'هدف الادخار الأول' : 'First savings target',
              helper: isArabic ? 'سننشئ هدفًا لمدة سنة ويمكنك تخصيصه لاحقًا.' : 'We will create a one-year goal that you can customize later.',
              controller: _goalController,
              currencySymbol: currency.symbol,
              icon: Icons.savings_outlined,
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'بياناتك المالية محفوظة محليًا على جهازك ولا تحتاج إلى إنشاء حساب.'
                          : 'Your financial data stays locally on your device and no account is required.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : _finishSetup,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(
                isArabic ? 'ابدأ استخدام وفير' : 'Start using Waffeer',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _finishSetup() async {
    final settings = context.read<SettingsProvider>();
    final isArabic = settings.isArabic;
    final walletProvider = context.read<WalletProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final transactionProvider = context.read<TransactionProvider>();
    final goalProvider = context.read<GoalProvider>();
    final navigator = Navigator.of(context);

    setState(() => _isSubmitting = true);
    try {
      await walletProvider.loadWallets(widget.currencyCode);
      await categoryProvider.loadCategories();
      await transactionProvider.loadTransactions();
      await goalProvider.loadGoals();

      final balance = _amountOf(_balanceController);
      final income = _amountOf(_incomeController);
      final defaultWallet = walletProvider.defaultWallet;

      if (defaultWallet != null) {
        if (income > 0 && categoryProvider.incomeCategories.isNotEmpty) {
          final salaryCategory = categoryProvider.incomeCategories.firstWhere(
            (category) => category.id == 'cat_salary',
            orElse: () => categoryProvider.incomeCategories.first,
          );

          if (balance >= income) {
            final baseBalance = balance - income;
            await walletProvider.updateWallet(
              defaultWallet.copyWith(
                initialBalance: baseBalance,
                currentBalance: baseBalance,
              ),
            );
            await transactionProvider.addTransaction(
              amount: income,
              type: TransactionType.income,
              categoryId: salaryCategory.id,
              walletId: defaultWallet.id,
              dateTime: DateTime.now(),
              title: isArabic ? 'دخل هذا الشهر' : 'This month income',
              currencyCode: widget.currencyCode,
              walletProvider: walletProvider,
            );
          } else {
            // Balance is less than income (user spent some portion already)
            await walletProvider.updateWallet(
              defaultWallet.copyWith(
                initialBalance: 0,
                currentBalance: 0,
              ),
            );
            await transactionProvider.addTransaction(
              amount: income,
              type: TransactionType.income,
              categoryId: salaryCategory.id,
              walletId: defaultWallet.id,
              dateTime: DateTime.now(),
              title: isArabic ? 'دخل هذا الشهر' : 'This month income',
              currencyCode: widget.currencyCode,
              walletProvider: walletProvider,
            );
            final priorSpent = income - balance;
            if (priorSpent > 0 && categoryProvider.expenseCategories.isNotEmpty) {
              final otherCategory = categoryProvider.expenseCategories.firstWhere(
                (category) => category.id == 'cat_other',
                orElse: () => categoryProvider.expenseCategories.first,
              );
              await transactionProvider.addTransaction(
                amount: priorSpent,
                type: TransactionType.expense,
                categoryId: otherCategory.id,
                walletId: defaultWallet.id,
                dateTime: DateTime.now(),
                title: isArabic ? 'مصاريف سابقة هذا الشهر' : 'Prior expenses this month',
                currencyCode: widget.currencyCode,
                walletProvider: walletProvider,
              );
            }
          }
        } else if (balance > 0) {
          await walletProvider.updateWallet(
            defaultWallet.copyWith(
              initialBalance: balance,
              currentBalance: balance,
            ),
          );
        }
      }

      final goal = _amountOf(_goalController);
      if (goal > 0) {
        await goalProvider.addGoal(
          title: isArabic ? 'هدف الادخار الأول' : 'First savings goal',
          targetAmount: goal,
          targetDate: DateTime.now().add(const Duration(days: 365)),
          currencyCode: widget.currencyCode,
          iconCodePoint: Icons.savings_rounded.codePoint,
          iconFontFamily: Icons.savings_rounded.fontFamily,
          colorValue: AppColors.warning.toARGB32(),
        );
      }

      await settings.completeFirstLaunch(widget.currencyCode);
      if (!mounted) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تعذر إعداد بياناتك بأمان. لم نُنهِ الإعداد ويمكنك المحاولة مجددًا.'
                : 'Setup could not finish safely. Nothing was finalized; please try again.',
          ),
          backgroundColor: AppColors.expense,
        ),
      );
    }
  }
}

class _SetupField extends StatelessWidget {
  final String label;
  final String helper;
  final TextEditingController controller;
  final String currencySymbol;
  final IconData icon;

  const _SetupField({
    required this.label,
    required this.helper,
    required this.controller,
    required this.currencySymbol,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
        ),
        const SizedBox(height: 4),
        Text(helper, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 9),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: InputDecoration(
            hintText: '0.00',
            prefixIcon: Icon(icon),
            suffixText: currencySymbol,
          ),
        ),
      ],
    );
  }
}
