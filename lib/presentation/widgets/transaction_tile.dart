import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/transaction_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/wallet_provider.dart';
import 'category_icon_widget.dart';

class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isArabic = settings.isArabic;
    final catProvider = context.watch<CategoryProvider>();
    final walletProvider = context.watch<WalletProvider>();

    final category = catProvider.getById(transaction.categoryId);
    final wallet = walletProvider.getById(transaction.walletId);
    final toWallet = transaction.toWalletId != null
        ? walletProvider.getById(transaction.toWalletId!)
        : null;

    final isExpense = transaction.type == TransactionType.expense;
    final isIncome = transaction.type == TransactionType.income;
    final isTransfer = transaction.type == TransactionType.transfer;

    final Color amountColor = isExpense
        ? AppColors.expense
        : isIncome
            ? AppColors.income
            : AppColors.transfer;

    final String sign = isExpense ? '-' : isIncome ? '+' : '⇄ ';

    final title = transaction.title?.isNotEmpty == true
        ? transaction.title!
        : (category?.localizedName(isArabic) ?? (isArabic ? 'معاملة' : 'Transaction'));

    final walletText = isTransfer && toWallet != null
        ? '${wallet?.localizedName(isArabic) ?? ""} → ${toWallet.localizedName(isArabic)}'
        : (wallet?.localizedName(isArabic) ?? '');

    return Dismissible(
      key: Key(transaction.id),
      direction: onDelete != null ? DismissDirection.endToStart : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.expense,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        if (onDelete == null) return false;
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(isArabic ? 'تأكيد الحذف' : 'Confirm Delete'),
                content: Text(isArabic
                    ? 'هل أنت متأكد من رغبتك في حذف هذه المعاملة؟'
                    : 'Are you sure you want to delete this transaction?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(
                      isArabic ? 'حذف' : 'Delete',
                      style: const TextStyle(color: AppColors.expense),
                    ),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => onDelete?.call(),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkBorder
                : AppColors.lightBorder,
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              CategoryIconWidget(
                iconData: category?.iconData ??
                    (isTransfer ? Icons.swap_horiz : Icons.attach_money),
                color: category?.color ?? amountColor,
                size: 46,
                iconSize: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (walletText.isNotEmpty) ...[
                          Text(
                            walletText,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                          const Text(' • ', style: TextStyle(color: Colors.grey)),
                        ],
                        Text(
                          DateFormatter.formatRelative(transaction.dateTime, isArabic: isArabic),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$sign${CurrencyFormatter.format(transaction.amount, currencyCode: transaction.currencyCode, isArabic: isArabic)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: amountColor,
                    ),
                  ),
                  if (transaction.note?.isNotEmpty == true)
                    Text(
                      transaction.note!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
