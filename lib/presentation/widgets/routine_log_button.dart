import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/routine_expense_model.dart';
import '../../providers/routine_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/wallet_provider.dart';

class RoutineLogButton extends StatefulWidget {
  final RoutineExpenseModel item;
  final bool confirmDue;
  final Widget? child;
  const RoutineLogButton({
    super.key,
    required this.item,
    this.confirmDue = false,
    this.child,
  });
  @override
  State<RoutineLogButton> createState() => _RoutineLogButtonState();
}

class _RoutineLogButtonState extends State<RoutineLogButton> {
  bool _busy = false;
  Future<void> _record({bool changeAmount = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ar = context.read<SettingsProvider>().isArabic;
    final provider = context.read<RoutineProvider>();
    final tx = context.read<TransactionProvider>();
    final wallets = context.read<WalletProvider>();
    final messenger = ScaffoldMessenger.of(context);
    double? amount;
    try {
      if (changeAmount) {
        amount = await showDialog<double>(
          context: context,
          builder: (_) => _RoutineAmountDialog(item: widget.item, isArabic: ar),
        );
        if (amount == null) return;
      }
      final id = await provider.quickLogExpense(
        widget.item,
        txProvider: tx,
        walletProvider: wallets,
        customAmount: amount,
        confirmDue: widget.confirmDue,
      );
      await provider.syncReminders(ar);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            id == null
                ? (ar
                      ? 'تم تسجيل هذا الاستحقاق بالفعل'
                      : 'This occurrence is already recorded')
                : (ar
                      ? 'تم تسجيل ${widget.item.title}'
                      : '${widget.item.title} recorded'),
          ),
          action: id == null
              ? null
              : SnackBarAction(
                  label: ar ? 'تراجع' : 'Undo',
                  onPressed: () async {
                    try {
                      await provider.undoQuickLog(
                        id,
                        txProvider: tx,
                        walletProvider: wallets,
                      );
                      await provider.syncReminders(ar);
                    } catch (_) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            ar
                                ? 'تعذر التراجع. حدّث القائمة وحاول مجدداً.'
                                : 'Could not undo. Refresh and try again.',
                          ),
                        ),
                      );
                    }
                  },
                ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ar
                ? 'تعذر إكمال التسجيل. حدّث القائمة وتحقق من المحفظة.'
                : 'Could not finish recording. Refresh and check the wallet.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = context.watch<SettingsProvider>().isArabic;
    if (widget.child != null) {
      return Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _busy ? null : () => _record(),
          onLongPress: _busy ? null : () => _record(changeAmount: true),
          child: Semantics(
            button: true,
            label: ar
                ? 'تسجيل ${widget.item.title}، ضغط مطول لتعديل المبلغ'
                : 'Record ${widget.item.title}, hold to change amount',
            child: Opacity(opacity: _busy ? .5 : 1, child: widget.child),
          ),
        ),
      );
    }
    return FilledButton.tonal(
      onPressed: _busy ? null : () => _record(),
      onLongPress: _busy ? null : () => _record(changeAmount: true),
      child: Text(
        _busy
            ? (ar ? 'جارٍ التسجيل' : 'Recording')
            : widget.confirmDue
            ? (ar ? 'تأكيد التسجيل' : 'Confirm')
            : (ar ? 'تسجيل' : 'Record'),
      ),
    );
  }
}

class _RoutineAmountDialog extends StatefulWidget {
  final RoutineExpenseModel item;
  final bool isArabic;
  const _RoutineAmountDialog({required this.item, required this.isArabic});
  @override
  State<_RoutineAmountDialog> createState() => _RoutineAmountDialogState();
}

class _RoutineAmountDialogState extends State<_RoutineAmountDialog> {
  late final TextEditingController _amount;
  final _form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: widget.item.amount.toString());
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.item.title),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _amount,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: widget.isArabic
              ? 'المبلغ لهذه المرة'
              : 'Amount for this entry',
          suffixText: widget.item.currencyCode,
        ),
        validator: (value) {
          final amount = double.tryParse(value ?? '');
          return amount == null || !amount.isFinite || amount <= 0
              ? (widget.isArabic
                    ? 'أدخل مبلغاً أكبر من صفر'
                    : 'Enter a positive amount')
              : null;
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(widget.isArabic ? 'إلغاء' : 'Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, double.parse(_amount.text));
          }
        },
        child: Text(widget.isArabic ? 'تسجيل' : 'Record'),
      ),
    ],
  );
}
