import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/routine_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/filter_bottom_sheet.dart';
import '../../widgets/transaction_tile.dart';
import 'add_edit_transaction_screen.dart';
import 'receipt_scanner_screen.dart';

/// شاشة سجل وتصفية المعاملات المالية بتصميم Fintech Luxury 2.0
class TransactionsListScreen extends StatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  State<TransactionsListScreen> createState() => _TransactionsListScreenState();
}

class _TransactionsListScreenState extends State<TransactionsListScreen> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isArabic = settings.isArabic;
    final txProvider = context.watch<TransactionProvider>();
    final walletProvider = context.watch<WalletProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final transactions = txProvider.filteredTransactionsForMonth(_currentMonth);
    final hasFilters = txProvider.hasActiveFilters;
    final now = DateTime.now();
    final isCurrentMonth =
        _currentMonth.year == now.year && _currentMonth.month == now.month;
    final monthIncome = txProvider.incomeForMonth(_currentMonth);
    final monthExpense = txProvider.expenseForMonth(_currentMonth);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 16, fontFamily: 'Cairo'),
                decoration: InputDecoration(
                  hintText: isArabic
                      ? 'بحث في المعاملات...'
                      : 'Search transactions...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (val) {
                  txProvider.setSearchQuery(val);
                },
              )
            : Text(
                isArabic ? 'سجل المعاملات' : 'Transactions History',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined, size: 22),
            tooltip: isArabic ? 'مسح فاتورة' : 'Scan Receipt',
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReceiptScannerScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
              size: 22,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  txProvider.setSearchQuery('');
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list_rounded, size: 22),
                tooltip: isArabic ? 'تصفية وبحث متقدم' : 'Filter',
                onPressed: () => _openFilterModal(context),
              ),
              if (hasFilters)
                Positioned(
                  top: 10,
                  right: isArabic ? null : 10,
                  left: isArabic ? 10 : null,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // 1. شريط التنقل بين الأشهر وملخص الشهر المالي
          if (txProvider.customDateRange == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(
                          isArabic
                              ? Icons.chevron_right_rounded
                              : Icons.chevron_left_rounded,
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _currentMonth = DateTime(
                              _currentMonth.year,
                              _currentMonth.month - 1,
                            );
                          });
                        },
                      ),
                      Text(
                        DateFormatter.formatMonthYear(
                          _currentMonth,
                          isArabic: isArabic,
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isArabic
                              ? Icons.chevron_left_rounded
                              : Icons.chevron_right_rounded,
                        ),
                        onPressed: isCurrentMonth
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _currentMonth = DateTime(
                                    _currentMonth.year,
                                    _currentMonth.month + 1,
                                  );
                                });
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // كبسولات ملخص الشهر السريعة
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.income.withValues(
                            alpha: isDark ? 0.15 : 0.10,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.arrow_downward_rounded,
                              color: AppColors.income,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              CurrencyFormatter.format(
                                monthIncome,
                                currencyCode: settings.currencyCode,
                                isArabic: isArabic,
                              ),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.income,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.expense.withValues(
                            alpha: isDark ? 0.15 : 0.10,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.arrow_upward_rounded,
                              color: AppColors.expense,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              CurrencyFormatter.format(
                                monthExpense,
                                currencyCode: settings.currencyCode,
                                isArabic: isArabic,
                              ),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.expense,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // 2. شريط الفلاتر النشطة (في حال وجود فلترة نشطة)
          if (hasFilters)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
              child: Row(
                children: [
                  const Icon(
                    Icons.filter_alt_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'يتم تطبيق فلاتر تصفية مخصصة'
                          : 'Custom filters applied',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      txProvider.clearFilters();
                    },
                    child: Text(
                      isArabic ? 'مسح الفلترة' : 'Clear',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.expense,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 3. قائمة المعاملات المنسدلة
          Expanded(
            child: transactions.isEmpty
                ? EmptyStateWidget(
                    icon: Icons.receipt_long_outlined,
                    title: hasFilters
                        ? (isArabic
                              ? 'لا توجد نتائج مطابقة للفلترة'
                              : 'No transactions match filters')
                        : (isArabic
                              ? 'لا توجد معاملات في هذا الشهر'
                              : 'No transactions this month'),
                    subtitle: isArabic
                        ? 'اضغط على زر الإضافة لتسجيل أول حركة مالية'
                        : 'Tap the add button to record your first transaction',
                    actionLabel: isArabic ? 'إضافة معاملة' : 'Add Transaction',
                    onAction: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddEditTransactionScreen(),
                        ),
                      );
                    },
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: transactions.length,
                    itemBuilder: (ctx, index) {
                      final tx = transactions[index];
                      return TransactionTile(
                        transaction: tx,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AddEditTransactionScreen(transaction: tx),
                            ),
                          );
                        },
                        onDelete: () => _deleteWithUndo(
                          tx,
                          txProvider: txProvider,
                          walletProvider: walletProvider,
                          isArabic: isArabic,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
          boxShadow: const [],
        ),
        child: FloatingActionButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AddEditTransactionScreen(),
              ),
            );
          },
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          child: const Icon(Icons.add_rounded, size: 30),
        ),
      ),
    );
  }

  void _openFilterModal(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FilterBottomSheet(),
    );
  }

  Future<void> _deleteWithUndo(
    TransactionModel transaction, {
    required TransactionProvider txProvider,
    required WalletProvider walletProvider,
    required bool isArabic,
  }) async {
    final routine = context.read<RoutineProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await txProvider.deleteTransaction(
        transaction,
        walletProvider: walletProvider,
      );
      await routine.loadRoutines();
      await routine.syncReminders(isArabic);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'تم حذف المعاملة' : 'Transaction deleted'),
          action: SnackBarAction(
            label: isArabic ? 'تراجع' : 'Undo',
            onPressed: () async {
              try {
                await txProvider.restoreTransaction(
                  transaction,
                  walletProvider: walletProvider,
                );
                await routine.loadRoutines();
                await routine.syncReminders(isArabic);
              } catch (_) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      isArabic
                          ? 'تعذر استعادة المعاملة'
                          : 'Could not restore entry',
                    ),
                  ),
                );
              }
            },
          ),
        ),
      );
    } catch (_) {
      await txProvider.loadTransactions();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isArabic ? 'تعذر حذف المعاملة' : 'Could not delete entry',
          ),
        ),
      );
    }
  }
}
