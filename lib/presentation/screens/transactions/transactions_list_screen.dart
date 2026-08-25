import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/transaction_tile.dart';
import 'add_edit_transaction_screen.dart';

class TransactionsListScreen extends StatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  State<TransactionsListScreen> createState() => _TransactionsListScreenState();
}

class _TransactionsListScreenState extends State<TransactionsListScreen> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isArabic = settings.isArabic;
    final txProvider = context.watch<TransactionProvider>();
    final walletProvider = context.watch<WalletProvider>();

    final transactions = txProvider.filteredTransactions;

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'سجل المعاملات' : 'Transactions History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () => _showFilterDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Month Selector Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(isArabic ? Icons.chevron_right : Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                      txProvider.setSelectedMonth(_currentMonth);
                    });
                  },
                ),
                Text(
                  DateFormatter.formatMonthYear(_currentMonth, isArabic: isArabic),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: Icon(isArabic ? Icons.chevron_left : Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                      txProvider.setSelectedMonth(_currentMonth);
                    });
                  },
                ),
              ],
            ),
          ),

          // Transactions List
          Expanded(
            child: transactions.isEmpty
                ? EmptyStateWidget(
                    icon: Icons.receipt_long_outlined,
                    title: isArabic ? 'لا توجد معاملات في هذا الشهر' : 'No transactions this month',
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: transactions.length,
                    itemBuilder: (ctx, index) {
                      final tx = transactions[index];
                      return TransactionTile(
                        transaction: tx,
                        onDelete: () async {
                          await txProvider.deleteTransaction(tx, walletProvider: walletProvider);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditTransactionScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final isArabic = settings.isArabic;
    final txProvider = context.read<TransactionProvider>();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isArabic ? 'تصفية حسب نوع المعاملة' : 'Filter by Type',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.all_inclusive, color: AppColors.secondary),
                title: Text(isArabic ? 'الكل' : 'All'),
                onTap: () {
                  txProvider.clearFilters();
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_upward, color: AppColors.expense),
                title: Text(isArabic ? 'المصاريف فقط' : 'Expenses only'),
                onTap: () {
                  txProvider.setFilter(type: TransactionType.expense);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_downward, color: AppColors.income),
                title: Text(isArabic ? 'المداخيل فقط' : 'Incomes only'),
                onTap: () {
                  txProvider.setFilter(type: TransactionType.income);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: AppColors.transfer),
                title: Text(isArabic ? 'التحويلات فقط' : 'Transfers only'),
                onTap: () {
                  txProvider.setFilter(type: TransactionType.transfer);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
