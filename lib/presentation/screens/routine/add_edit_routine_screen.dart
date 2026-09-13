import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';

import '../../../core/services/notification_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/routine_expense_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/routine_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';

class AddEditRoutineScreen extends StatefulWidget {
  final RoutineExpenseModel? routine;
  final RoutineTemplate? initialTemplate;
  const AddEditRoutineScreen({super.key, this.routine, this.initialTemplate});
  @override
  State<AddEditRoutineScreen> createState() => _AddEditRoutineScreenState();
}

class _AddEditRoutineScreenState extends State<AddEditRoutineScreen> {
  final _form = GlobalKey<FormState>();
  final _newRoutineId = const Uuid().v4();
  final _title = TextEditingController(),
      _amount = TextEditingController(),
      _note = TextEditingController(),
      _interval = TextEditingController(text: '3');
  String? _wallet, _category, _destination;
  TransactionType _type = TransactionType.expense;
  RecordingMode _mode = RecordingMode.manual;
  RoutineFrequency _frequency = RoutineFrequency.monthly;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  bool _initialized = false, _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final ar = context.read<SettingsProvider>().isArabic;
    final item = widget.routine;
    final preset = widget.initialTemplate;
    _title.text = item?.title ?? preset?.localizedTitle(ar) ?? '';
    _amount.text = (item?.amount ?? preset?.defaultAmount)?.toString() ?? '';
    _note.text = item?.note ?? '';
    _interval.text = (item?.intervalDays ?? preset?.suggestedIntervalDays ?? 3)
        .toString();
    _wallet =
        item?.walletId ?? context.read<WalletProvider>().defaultWallet?.id;
    _category = item?.categoryId ?? preset?.defaultCategoryId;
    _destination = item?.toWalletId;
    _type = item?.type ?? TransactionType.expense;
    _mode =
        item?.mode ??
        RecordingMode.manual; // All presets are opt-in, never automatic.
    _frequency = item != null && item.frequency != RoutineFrequency.manual
        ? item.frequency
        : preset != null && preset.suggestedFrequency != RoutineFrequency.manual
        ? preset.suggestedFrequency
        : RoutineFrequency.monthly;
    _date = item?.nextDueDate ?? _date;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    _interval.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ar = context.watch<SettingsProvider>().isArabic;
    final wallets = context.watch<WalletProvider>().wallets;
    final categories = context.watch<CategoryProvider>();
    final choices = _type == TransactionType.income
        ? categories.incomeCategories
        : categories.expenseCategories;
    final validCategory = choices.any((c) => c.id == _category)
        ? _category
        : null;
    final validWallet = wallets.any((w) => w.id == _wallet) ? _wallet : null;
    final selectedWallet = context.read<WalletProvider>().getById(
      validWallet ?? '',
    );
    final destinations = wallets
        .where(
          (w) =>
              w.id != _wallet && w.currencyCode == selectedWallet?.currencyCode,
        )
        .toList();
    final color = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.routine == null
              ? (ar ? 'معاملة متكررة جديدة' : 'New recurring entry')
              : (ar ? 'إعداد المعاملة' : 'Entry settings'),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SegmentedButton<TransactionType>(
              segments: [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text(ar ? 'مصروف' : 'Expense'),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text(ar ? 'دخل' : 'Income'),
                ),
                if (_type == TransactionType.transfer)
                  ButtonSegment(
                    value: TransactionType.transfer,
                    label: Text(ar ? 'تحويل' : 'Transfer'),
                  ),
              ],
              selected: {_type},
              onSelectionChanged: _saving
                  ? null
                  : (value) => setState(() {
                      _type = value.first;
                      _category = null;
                    }),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _title,
              decoration: InputDecoration(labelText: ar ? 'الاسم' : 'Name'),
              validator: (v) => v == null || v.trim().isEmpty
                  ? (ar ? 'أدخل الاسم' : 'Enter a name')
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: ar ? 'المبلغ' : 'Amount',
                suffixText: selectedWallet?.currencyCode,
              ),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                return n == null || !n.isFinite || n <= 0
                    ? (ar
                          ? 'أدخل مبلغاً أكبر من صفر'
                          : 'Enter a positive amount')
                    : null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('wallet-$validWallet'),
              initialValue: validWallet,
              isExpanded: true,
              decoration: InputDecoration(labelText: ar ? 'المحفظة' : 'Wallet'),
              items: wallets
                  .map(
                    (w) => DropdownMenuItem(
                      value: w.id,
                      child: Text('${w.localizedName(ar)} · ${w.currencyCode}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() {
                _wallet = v;
                _destination = null;
              }),
              validator: (v) =>
                  v == null ? (ar ? 'اختر محفظة' : 'Select a wallet') : null,
            ),
            if (_type == TransactionType.transfer) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey('to-$_wallet'),
                initialValue: destinations.any((w) => w.id == _destination)
                    ? _destination
                    : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: ar ? 'المحفظة المستلمة' : 'Destination wallet',
                ),
                items: destinations
                    .map(
                      (w) => DropdownMenuItem(
                        value: w.id,
                        child: Text(w.localizedName(ar)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => _destination = v,
                validator: (v) => v == null
                    ? (ar ? 'اختر المحفظة' : 'Select a wallet')
                    : null,
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('category-${_type.name}-$validCategory'),
              initialValue: validCategory,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: ar ? 'التصنيف' : 'Category',
              ),
              items: choices
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.localizedName(ar)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _category = v),
              validator: (v) => v == null
                  ? (ar ? 'اختر تصنيفاً' : 'Select a category')
                  : null,
            ),
            const SizedBox(height: 24),
            Text(
              ar ? 'طريقة التسجيل' : 'Recording method',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            RadioGroup<RecordingMode>(
              groupValue: _mode,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    if (_mode == RecordingMode.manual) {
                      _date = DateUtils.dateOnly(DateTime.now());
                    }
                    _mode = value;
                  });
                }
              },
              child: Column(
                children: [
                  _modeTile(
                    RecordingMode.manual,
                    ar ? 'عند الضغط' : 'On tap',
                    ar
                        ? 'تسجيل مستقل كل مرة · الخيار الافتراضي'
                        : 'A separate entry each time · Default',
                    color,
                  ),
                  _modeTile(
                    RecordingMode.reminder,
                    ar ? 'تذكير فقط' : 'Reminder only',
                    ar
                        ? 'لا يتغير الرصيد حتى تؤكد التسجيل'
                        : 'Balance changes only after confirmation',
                    color,
                  ),
                  _modeTile(
                    RecordingMode.automatic,
                    ar ? 'تسجيل تلقائي' : 'Automatic recording',
                    ar
                        ? 'يسجّل المستحقات عند فتح التطبيق أو أثناء استخدامه'
                        : 'Records due entries when opening or using the app',
                    color,
                  ),
                ],
              ),
            ),
            if (_mode != RecordingMode.manual) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<RoutineFrequency>(
                initialValue: _frequency,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: ar ? 'التكرار' : 'Frequency',
                ),
                items: RoutineFrequency.values
                    .where((f) => f != RoutineFrequency.manual)
                    .map(
                      (f) => DropdownMenuItem(
                        value: f,
                        child: Text(switch (f) {
                          RoutineFrequency.daily => ar ? 'يومياً' : 'Daily',
                          RoutineFrequency.weekly => ar ? 'أسبوعياً' : 'Weekly',
                          RoutineFrequency.monthly => ar ? 'شهرياً' : 'Monthly',
                          RoutineFrequency.yearly => ar ? 'سنوياً' : 'Yearly',
                          _ => ar ? 'كل عدد من الأيام' : 'Every few days',
                        }),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _frequency = v!),
              ),
              if (_frequency == RoutineFrequency.everyXDays) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _interval,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: ar ? 'كل كم يوم؟' : 'How many days?',
                  ),
                  validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1
                      ? (ar
                            ? 'أدخل عدداً أكبر من صفر'
                            : 'Enter a positive number')
                      : null,
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null && mounted) setState(() => _date = picked);
                },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  '${ar ? 'الاستحقاق القادم' : 'Next due'}: ${DateFormatter.formatDate(_date, isArabic: ar)}',
                ),
              ),
              if (_mode == RecordingMode.automatic)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    ar
                        ? 'تُحتسب جميع المواعيد الفائتة منذ الاستحقاق القادم. الإيقاف المؤقت لا يحتسب فترة التوقف.'
                        : 'All missed occurrences since the next due date are recorded. Pausing skips the paused period.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: ar ? 'ملاحظة اختيارية' : 'Optional note',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving
                  ? null
                  : () => _save(validWallet, validCategory),
              child: Text(
                _saving
                    ? (ar ? 'جارٍ الحفظ' : 'Saving')
                    : (ar ? 'حفظ الإعدادات' : 'Save settings'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _modeTile(
    RecordingMode value,
    String title,
    String subtitle,
    ColorScheme colors,
  ) => Container(
    margin: const EdgeInsets.only(top: 8),
    decoration: BoxDecoration(
      color: _mode == value ? colors.primaryContainer : colors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: _mode == value ? colors.primary : colors.outlineVariant,
      ),
    ),
    child: Material(
      color: Colors.transparent,
      child: RadioListTile<RecordingMode>(
        value: value,
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    ),
  );

  Future<void> _save(String? walletId, String? categoryId) async {
    if (!_form.currentState!.validate() ||
        walletId == null ||
        categoryId == null ||
        _saving) {
      return;
    }
    setState(() => _saving = true);
    final ar = context.read<SettingsProvider>().isArabic;
    final provider = context.read<RoutineProvider>(),
        tx = context.read<TransactionProvider>();
    final wallets = context.read<WalletProvider>();
    final currency = wallets.getById(walletId)!.currencyCode;
    final amount = double.parse(_amount.text);
    final interval = int.tryParse(_interval.text) ?? 3;
    try {
      if (widget.routine == null) {
        await provider.addRoutine(
          id: _newRoutineId,
          title: _title.text.trim(),
          amount: amount,
          categoryId: categoryId,
          walletId: walletId,
          currencyCode: currency,
          type: _type,
          toWalletId: _destination,
          mode: _mode,
          frequency: _frequency,
          nextDueDate: _date,
          intervalDays: interval,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          iconCodePoint: widget.initialTemplate?.iconCodePoint,
          colorValue: widget.initialTemplate?.colorValue,
        );
      } else {
        final old = widget.routine!;
        final changedSchedule =
            old.nextDueDate != _date || old.frequency != _frequency;
        await provider.updateRoutine(
          old.copyWith(
            title: _title.text.trim(),
            amount: amount,
            categoryId: categoryId,
            walletId: walletId,
            currencyCode: currency,
            type: _type,
            toWalletId: _destination,
            mode: _mode,
            frequency: _frequency,
            nextDueDate: _mode == RecordingMode.manual ? null : _date,
            intervalDays: interval,
            anchorDay: changedSchedule ? _date.day : old.anchorDay,
            anchorMonth: changedSchedule ? _date.month : old.anchorMonth,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          ),
          previous: old,
        );
      }
      if (_mode == RecordingMode.reminder) {
        await NotificationService.instance.requestPermissions();
      }
      await provider.syncReminders(ar);
      await provider.processAutoRecurringDue(
        txProvider: tx,
        walletProvider: wallets,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ar ? 'تعذر إكمال الحفظ. حدّث القائمة وتحقق من المحفظة والموعد.' : 'Could not finish saving. Refresh and check the wallet and date.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
