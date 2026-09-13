import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/currencies.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/debt_provider.dart';
import '../../../providers/goal_provider.dart';
import '../../../providers/routine_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';

class CurrencyPickerScreen extends StatefulWidget {
  const CurrencyPickerScreen({super.key});

  @override
  State<CurrencyPickerScreen> createState() => _CurrencyPickerScreenState();
}

class _CurrencyPickerScreenState extends State<CurrencyPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<AppCurrency> _filteredCurrencies = Currencies.list;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _filteredCurrencies = Currencies.list;
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 180), () {
      final q = query.trim().toLowerCase();
      if (!mounted) return;
      setState(() {
        if (q.isEmpty) {
          _filteredCurrencies = Currencies.list;
        } else {
          _filteredCurrencies = Currencies.list.where((c) {
            return c.code.toLowerCase().contains(q) ||
                c.nameEn.toLowerCase().contains(q) ||
                c.nameAr.toLowerCase().contains(q) ||
                c.symbol.toLowerCase().contains(q);
          }).toList();
        }
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isArabic = settings.isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredCurrencies = _filteredCurrencies;

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'اختيار العملة' : 'Select Currency'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: isArabic ? 'ابحث عن العملة...' : 'Search currency...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _debounceTimer?.cancel();
                          setState(() {
                            _filteredCurrencies = Currencies.list;
                          });
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: filteredCurrencies.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (ctx, index) {
                  final curr = filteredCurrencies[index];
                  final isSelected = curr.code == settings.currencyCode;

                  return InkWell(
                    onTap: () async {
                      if (curr.code == settings.currencyCode) {
                        Navigator.pop(context);
                        return;
                      }

                      final walletProvider = context.read<WalletProvider>();
                      final hasFinancialData =
                          walletProvider.wallets.any(
                            (wallet) =>
                                wallet.initialBalance != 0 ||
                                wallet.currentBalance != 0,
                          ) ||
                          context
                              .read<TransactionProvider>()
                              .transactions
                              .isNotEmpty ||
                          context.read<BudgetProvider>().budgets.isNotEmpty ||
                          context.read<GoalProvider>().goals.isNotEmpty ||
                          context.read<DebtProvider>().debts.isNotEmpty ||
                          context.read<RoutineProvider>().routines.isNotEmpty;

                      if (hasFinancialData) {
                        await showDialog<void>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            icon: const Icon(
                              Icons.currency_exchange_rounded,
                              color: AppColors.warning,
                            ),
                            title: Text(
                              isArabic
                                  ? 'حماية دقة أرصدتك'
                                  : 'Protecting your balances',
                            ),
                            content: Text(
                              isArabic
                                  ? 'لا يمكن تغيير العملة الرئيسية بعد تسجيل أرصدة أو معاملات، لأن تغيير الرمز لا يحوّل القيم فعليًا. أنشئ محفظة مستقلة للعملة الأخرى بدلًا من ذلك.'
                                  : 'The primary currency cannot be changed after balances or transactions exist because changing a symbol does not convert money. Use a separate wallet for another currency instead.',
                            ),
                            actions: [
                              FilledButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: Text(isArabic ? 'فهمت' : 'Got it'),
                              ),
                            ],
                          ),
                        );
                        return;
                      }

                      await walletProvider.updateCurrencyForEmptyWallets(
                        curr.code,
                      );
                      await settings.setCurrency(curr.code);
                      if (context.mounted) Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(
                                alpha: isDark ? 0.2 : 0.1,
                              )
                            : Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(curr.flag, style: const TextStyle(fontSize: 26)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  curr.code,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  isArabic ? curr.nameAr : curr.nameEn,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              curr.symbol,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.primary,
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
