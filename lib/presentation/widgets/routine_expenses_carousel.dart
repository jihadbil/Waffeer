import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/currency_formatter.dart';
import '../../providers/routine_provider.dart';
import '../../providers/settings_provider.dart';
import '../screens/routine/add_edit_routine_screen.dart';
import '../screens/routine/routine_expenses_screen.dart';
import 'routine_log_button.dart';

/// Shared quick-entry section used on the home and recurring screens.
class RoutineExpensesCarousel extends StatelessWidget {
  final bool showManage;
  const RoutineExpensesCarousel({super.key, this.showManage = true});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RoutineProvider>();
    final ar = context.watch<SettingsProvider>().isArabic;
    final colors = Theme.of(context).colorScheme;
    final routines = provider.quickRoutines;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                ar ? 'تسجيل سريع' : 'Quick recording',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (showManage)
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RoutineExpensesScreen(),
                  ),
                ),
                child: Text(ar ? 'إدارة المتكررة' : 'Manage recurring'),
              ),
          ],
        ),
        if (routines.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ar
                        ? 'أضف مصروفك المعتاد لتسجيله بضغطة واحدة.'
                        : 'Add an everyday expense to record it with one tap.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddEditRoutineScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(ar ? 'إضافة مصروف' : 'Add expense'),
                  ),
                ],
              ),
            ),
          ),
        if (routines.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 600 ? 3 : 2;
              final width =
                  (constraints.maxWidth - 10 * (columns - 1)) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: routines
                    .map(
                      (item) => SizedBox(
                        width: width,
                        child: RoutineLogButton(
                          key: ValueKey(item.id),
                          item: item,
                          child: Padding(
                            padding: const EdgeInsets.all(15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colors.primaryContainer,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    item.iconData ??
                                        Icons.receipt_long_outlined,
                                    color: colors.onPrimaryContainer,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  item.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
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
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        if (provider.dueReminders.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            ar ? 'بانتظار تأكيد التسجيل' : 'Awaiting confirmation',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ...provider.dueReminders
              .take(3)
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title),
                            Text(
                              CurrencyFormatter.format(
                                item.amount,
                                currencyCode: item.currencyCode,
                                isArabic: ar,
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      RoutineLogButton(
                        key: ValueKey('due-${item.id}-${item.nextDueDate}'),
                        item: item,
                        confirmDue: true,
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ],
    );
  }
}
