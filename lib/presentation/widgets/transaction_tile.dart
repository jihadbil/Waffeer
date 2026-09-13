import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/transaction_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/wallet_provider.dart';
import 'category_icon_widget.dart';

/// عنصر عرض المعاملة المالية في القائمة بتصميم بطاقة عصرية
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final category = catProvider.getById(transaction.categoryId);
    final wallet = walletProvider.getById(transaction.walletId);
    final toWallet = transaction.toWalletId != null
        ? walletProvider.getById(transaction.toWalletId!)
        : null;

    final isExpense = transaction.type == TransactionType.expense;
    final isIncome = transaction.type == TransactionType.income;
    final isTransfer = transaction.type == TransactionType.transfer;

    final Color amountColor = isExpense
        ? Theme.of(context).colorScheme.error
        : isIncome
        ? Theme.of(context).colorScheme.primary
        : AppColors.transfer;

    final String sign = isExpense
        ? '-'
        : isIncome
        ? '+'
        : '⇄ ';

    final title = transaction.title?.isNotEmpty == true
        ? transaction.title!
        : (category?.localizedName(isArabic) ??
              (isArabic ? 'معاملة' : 'Transaction'));

    final walletText = isTransfer && toWallet != null
        ? '${wallet?.localizedName(isArabic) ?? ""} → ${toWallet.localizedName(isArabic)}'
        : (wallet?.localizedName(isArabic) ?? '');

    return Dismissible(
      key: Key(transaction.id),
      direction: onDelete != null
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        alignment: isArabic ? Alignment.centerLeft : Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.expense,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
      confirmDismiss: (direction) async {
        HapticFeedback.mediumImpact();
        if (onDelete == null) return false;
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(isArabic ? 'تأكيد الحذف' : 'Confirm Delete'),
                content: Text(
                  isArabic
                      ? 'هل أنت متأكد من رغبتك في حذف هذه المعاملة؟'
                      : 'Are you sure you want to delete this transaction?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.expense,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(isArabic ? 'حذف' : 'Delete'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => onDelete?.call(),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
          boxShadow: const [],
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap?.call();
          },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // أيقونة التصنيف
                CategoryIconWidget(
                  iconData:
                      category?.iconData ??
                      (isTransfer
                          ? Icons.swap_horiz_rounded
                          : Icons.attach_money_rounded),
                  color: category?.color ?? amountColor,
                  size: 48,
                  iconSize: 22,
                ),
                const SizedBox(width: 12),

                // تفاصيل المعاملة (العنوان، المحفظة، التاريخ، وشارات الفاتورة والتكرار)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                fontFamily: 'Cairo',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // شارة الفاتورة المرفقة
                          if (transaction.receiptImagePath != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.receipt_rounded,
                                size: 12,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                          // شارة المعاملة المتكررة
                          if (transaction.isRecurring) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.repeat_rounded,
                                size: 12,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (walletText.isNotEmpty) ...[
                            Text(
                              walletText,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Text(
                              ' • ',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          Text(
                            DateFormatter.formatRelative(
                              transaction.dateTime,
                              isArabic: isArabic,
                            ),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // المبلغ المالي بتنسيق بارز
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: amountColor.withValues(
                          alpha: isDark ? 0.15 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$sign${CurrencyFormatter.format(transaction.amount, currencyCode: transaction.currencyCode, isArabic: isArabic)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: amountColor,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                    if (transaction.note?.isNotEmpty == true) ...[
                      const SizedBox(height: 3),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 90),
                        child: Text(
                          transaction.note!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
