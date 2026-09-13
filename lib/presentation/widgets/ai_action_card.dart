import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/ai_action.dart';
import '../../providers/ai_provider.dart';
import '../../providers/settings_provider.dart';

/// بطاقة تفاعلية تعرض تفاصيل الإجراء الذي نفذه المستشار مع إمكانية التراجع الفوري
class AiActionCard extends StatefulWidget {
  final AiAction action;

  const AiActionCard({super.key, required this.action});

  @override
  State<AiActionCard> createState() => _AiActionCardState();
}

class _AiActionCardState extends State<AiActionCard> {
  bool _isUndoing = false;

  Future<void> _handleUndo() async {
    HapticFeedback.mediumImpact();
    setState(() => _isUndoing = true);

    final ai = context.read<AiProvider>();
    final isArabic = context.read<SettingsProvider>().isArabic;

    final success = await ai.undoAction(widget.action, context);

    if (!mounted) return;
    setState(() => _isUndoing = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تم التراجع عن "${widget.action.title}" بنجاح ↩️'
                : 'Undid "${widget.action.title}" successfully ↩️',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: Colors.blueGrey,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final isArabic = context.watch<SettingsProvider>().isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color badgeColor;
    IconData badgeIcon;
    String badgeText;

    switch (action.type) {
      case AiActionType.addExpense:
        badgeColor = AppColors.expense;
        badgeIcon = Icons.arrow_upward_rounded;
        badgeText = isArabic ? 'تسجيل مصروف' : 'Recorded Expense';
        break;
      case AiActionType.addIncome:
        badgeColor = AppColors.income;
        badgeIcon = Icons.arrow_downward_rounded;
        badgeText = isArabic ? 'تسجيل دخل' : 'Recorded Income';
        break;
      case AiActionType.addCategory:
        badgeColor = AppColors.secondary;
        badgeIcon = Icons.category_rounded;
        badgeText = isArabic ? 'إنشاء تصنيف' : 'Created Category';
        break;
      case AiActionType.addBudget:
        badgeColor = Colors.amber.shade700;
        badgeIcon = Icons.track_changes_rounded;
        badgeText = isArabic ? 'إنشاء ميزانية' : 'Created Budget';
        break;
      case AiActionType.changeTheme:
      case AiActionType.changeCurrency:
        badgeColor = Colors.blueAccent;
        badgeIcon = Icons.tune_rounded;
        badgeText = isArabic ? 'تعديل إعدادات' : 'Updated Settings';
        break;
      default:
        badgeColor = AppColors.primary;
        badgeIcon = Icons.auto_awesome;
        badgeText = isArabic ? 'إجراء مكتمل' : 'Completed Action';
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: action.isUndone
            ? (isDark ? Colors.grey.shade900 : Colors.grey.shade100)
            : (isDark ? AppColors.darkBackground : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: action.isUndone
              ? Colors.grey.withValues(alpha: 0.3)
              : badgeColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          if (!action.isUndone)
            BoxShadow(
              color: badgeColor.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (action.isUndone ? Colors.grey : badgeColor).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  badgeIcon,
                  size: 15,
                  color: action.isUndone ? Colors.grey : badgeColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: action.isUndone ? Colors.grey : badgeColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (action.isUndone ? Colors.grey : Colors.green).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      action.isUndone ? Icons.undo_rounded : Icons.check_circle_rounded,
                      size: 12,
                      color: action.isUndone ? Colors.grey : Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      action.isUndone
                          ? (isArabic ? 'تم التراجع' : 'Undone')
                          : (isArabic ? 'تم التطبيق' : 'Applied'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: action.isUndone ? Colors.grey : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Title & Details
          Text(
            action.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              decoration: action.isUndone ? TextDecoration.lineThrough : null,
              color: action.isUndone ? Colors.grey : (isDark ? Colors.white : Colors.black87),
            ),
          ),
          if (action.details.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              action.details,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],

          // Undo Button
          if (!action.isUndone) ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: SizedBox(
                height: 28,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    foregroundColor: Colors.redAccent,
                    backgroundColor: Colors.red.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isUndoing ? null : _handleUndo,
                  icon: _isUndoing
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.redAccent),
                        )
                      : const Icon(Icons.undo_rounded, size: 14),
                  label: Text(
                    isArabic ? 'تراجع عن الإجراء' : 'Undo action',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
