import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/debt_provider.dart';
import '../../../providers/goal_provider.dart';
import '../../../providers/routine_provider.dart';
import '../../../providers/settings_provider.dart';
import '../budgets/budgets_screen.dart';
import '../debts/debts_screen.dart';
import '../goals/goals_screen.dart';
import '../routine/routine_expenses_screen.dart';
import '../settings/settings_screen.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isArabic = settings.isArabic;
    final budgets = context.watch<BudgetProvider>().budgets;
    final goals = context.watch<GoalProvider>().goals;
    final routineProvider = context.watch<RoutineProvider>();
    final debts = context.watch<DebtProvider>().debts;

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'خطتك المالية' : 'Your Money Plan'),
        actions: [
          IconButton(
            tooltip: isArabic ? 'الإعدادات' : 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.luxuryCardGradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic
                      ? 'نظرة واحدة على التزاماتك'
                      : 'Your commitments at a glance',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _PlanStat(
                      label: isArabic ? 'ميزانيات' : 'Budgets',
                      value: '${budgets.length}',
                    ),
                    _PlanStat(
                      label: isArabic ? 'أهداف' : 'Goals',
                      value: '${goals.length}',
                    ),
                    _PlanStat(
                      label: isArabic ? 'مستحق الآن' : 'Due now',
                      value: '${routineProvider.dueReminders.length}',
                    ),
                    _PlanStat(
                      label: isArabic ? 'ديون مفتوحة' : 'Open debts',
                      value: '${debts.where((debt) => !debt.isSettled).length}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            isArabic ? 'خطط وتابع تقدمك' : 'Plan and track progress',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          _PlanTile(
            icon: Icons.pie_chart_rounded,
            color: AppColors.secondary,
            title: isArabic ? 'الميزانيات' : 'Budgets',
            subtitle: isArabic
                ? 'حدد سقفًا للصرف واحصل على تنبيه قبل تجاوزه.'
                : 'Set spending limits and get warned before exceeding them.',
            badge: budgets.isEmpty ? null : '${budgets.length}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BudgetsScreen()),
            ),
          ),
          _PlanTile(
            icon: Icons.savings_rounded,
            color: AppColors.warning,
            title: isArabic ? 'أهداف الادخار' : 'Savings Goals',
            subtitle: isArabic
                ? 'حوّل هدفك إلى تقدم واضح وقابل للقياس.'
                : 'Turn a target into visible, measurable progress.',
            badge: goals.isEmpty ? null : '${goals.length}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GoalsScreen()),
            ),
          ),
          _PlanTile(
            icon: Icons.touch_app_rounded,
            color: const Color(0xFF0D9488),
            title: isArabic ? 'المعاملات المتكررة' : 'Recurring entries',
            subtitle: isArabic
                ? 'مصروف أو دخل: تسجيل سريع، تذكير، أو تكرار تلقائي.'
                : 'Log frequent expenses in one tap or schedule them automatically.',
            badge: routineProvider.routines.isEmpty
                ? null
                : '${routineProvider.routines.length}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RoutineExpensesScreen()),
            ),
          ),
          _PlanTile(
            icon: Icons.handshake_rounded,
            color: AppColors.expense,
            title: isArabic ? 'الديون والمستحقات' : 'Debts & Loans',
            subtitle: isArabic
                ? 'تابع ما لك وما عليك ومواعيد السداد.'
                : 'Track what you owe, what is owed to you, and due dates.',
            badge: debts.isEmpty
                ? null
                : '${debts.where((debt) => !debt.isSettled).length}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DebtsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanStat extends StatelessWidget {
  final String label;
  final String value;

  const _PlanStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFD5EADF), fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _PlanTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
