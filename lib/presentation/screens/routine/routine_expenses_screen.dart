import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/routine_expense_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/routine_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../widgets/routine_expenses_carousel.dart';
import '../../widgets/routine_log_button.dart';
import 'add_edit_routine_screen.dart';

class RoutineExpensesScreen extends StatefulWidget {
  const RoutineExpensesScreen({super.key});
  @override
  State<RoutineExpensesScreen> createState() => _RoutineExpensesScreenState();
}

class _RoutineExpensesScreenState extends State<RoutineExpensesScreen> {
  bool _manage = false, _busy = false;
  Future<void> _action(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ar = context.read<SettingsProvider>().isArabic;
    final provider = context.read<RoutineProvider>();
    try {
      await action();
      await provider.syncReminders(ar);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ar
                  ? 'تعذر إكمال العملية. حدّث القائمة وحاول مجدداً.'
                  : 'Could not complete the action. Refresh and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = context.watch<SettingsProvider>().isArabic;
    final provider = context.watch<RoutineProvider>();
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(ar ? 'المعاملات المتكررة' : 'Recurring entries'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.loadRoutines();
          if (!context.mounted) return;
          await provider.processAutoRecurringDue(
            txProvider: context.read<TransactionProvider>(),
            walletProvider: context.read<WalletProvider>(),
          );
          await provider.syncReminders(ar);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(ar ? 'تسجيل سريع' : 'Quick recording'),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(ar ? 'إدارة المتكررة' : 'Manage'),
                ),
              ],
              selected: {_manage},
              onSelectionChanged: (v) => setState(() => _manage = v.first),
            ),
            const SizedBox(height: 20),
            if (!_manage) const RoutineExpensesCarousel(showManage: false),
            if (_manage) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ar ? 'المصاريف والدخل المتكرر' : 'Expenses & income',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddEditRoutineScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(ar ? 'إضافة' : 'Add'),
                  ),
                ],
              ),
              if (provider.routines.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    ar
                        ? 'أضف أول معاملة متكررة.'
                        : 'Add your first recurring entry.',
                  ),
                ),
              ...provider.routines.map(
                (item) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: colors.outlineVariant),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            item.type == TransactionType.income
                                ? Icons.south_west
                                : item.iconData ?? Icons.receipt_long_outlined,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.title,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          PopupMenuButton<String>(
                            enabled: !_busy,
                            onSelected: (value) async {
                              if (value == 'edit') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AddEditRoutineScreen(routine: item),
                                  ),
                                );
                                return;
                              }
                              if (value == 'pause') {
                                await _action(
                                  () => provider.toggleActive(item.id),
                                );
                                return;
                              }
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(
                                    ar
                                        ? 'حذف المعاملة المتكررة؟'
                                        : 'Delete recurring entry?',
                                  ),
                                  content: Text(
                                    ar
                                        ? 'تبقى العمليات المسجلة سابقاً في السجل.'
                                        : 'Previously recorded transactions remain in your history.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: Text(ar ? 'إلغاء' : 'Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text(ar ? 'حذف' : 'Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true && mounted) {
                                await _action(
                                  () => provider.deleteRoutine(item.id),
                                );
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text(ar ? 'تعديل' : 'Edit'),
                              ),
                              PopupMenuItem(
                                value: 'pause',
                                child: Text(
                                  item.isActive
                                      ? (ar ? 'إيقاف مؤقت' : 'Pause')
                                      : (ar
                                            ? 'استئناف من الموعد القادم'
                                            : 'Resume from next date'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(ar ? 'حذف' : 'Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        CurrencyFormatter.format(
                          item.amount,
                          currencyCode: item.currencyCode,
                          isArabic: ar,
                        ),
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.isActive
                            ? item.localizedFrequency(ar)
                            : (ar ? 'متوقفة مؤقتاً' : 'Paused'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (item.isScheduled && item.nextDueDate != null)
                        Text(
                          '${ar ? 'الاستحقاق القادم' : 'Next due'}: ${DateFormatter.formatDate(item.nextDueDate!, isArabic: ar)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (item.isActive && item.mode == RecordingMode.manual)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: RoutineLogButton(item: item),
                        ),
                      if (item.isActive &&
                          item.mode == RecordingMode.reminder &&
                          item.nextDueDate != null &&
                          !item.nextDueDate!.isAfter(DateTime.now()))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: RoutineLogButton(
                            key: ValueKey('${item.id}-${item.nextDueDate}'),
                            item: item,
                            confirmDue: true,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              ar ? 'ابدأ بقالب' : 'Start with a preset',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: RoutineProvider.presetTemplates
                  .map(
                    (preset) => ActionChip(
                      label: Text(preset.localizedTitle(ar)),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AddEditRoutineScreen(initialTemplate: preset),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
