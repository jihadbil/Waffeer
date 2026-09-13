import 'package:flutter/material.dart';

import '../../core/utils/currency_formatter.dart';

class BalanceCard extends StatefulWidget {
  final double totalBalance, monthlyIncome, monthlyExpense;
  final String currencyCode;
  final bool isArabic;
  final VoidCallback? onManageWallets;
  const BalanceCard({
    super.key,
    required this.totalBalance,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.currencyCode,
    required this.isArabic,
    this.onManageWallets,
  });
  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  bool _visible = true;
  String money(double n) => _visible
      ? CurrencyFormatter.format(
          n,
          currencyCode: widget.currencyCode,
          isArabic: widget.isArabic,
        )
      : '••••';
  @override
  Widget build(BuildContext context) {
    final ar = widget.isArabic;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1D4936)
            : const Color(0xFF154D39),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.bodyMedium!
            .copyWith(color: const Color(0xFFF1FFF6)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ar ? 'إجمالي رصيد المحافظ' : 'Total wallet balance',
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _visible = !_visible),
                  tooltip: ar
                      ? 'إظهار أو إخفاء الرصيد'
                      : 'Show or hide balance',
                  icon: Icon(
                    _visible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: const Color(0xFFF1FFF6),
                    size: 20,
                  ),
                ),
              ],
            ),
            Text(
              money(widget.totalBalance),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 28,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ar ? 'دخل الشهر' : 'Monthly income'),
                    Text(money(widget.monthlyIncome)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ar ? 'مصروف الشهر' : 'Monthly expenses'),
                    Text(money(widget.monthlyExpense)),
                  ],
                ),
              ],
            ),
            if (widget.onManageWallets != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: widget.onManageWallets,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFF1FFF6),
                  ),
                  child: Text(ar ? 'إدارة المحافظ' : 'Manage wallets'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
