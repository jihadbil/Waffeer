import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import 'ai/ai_advisor_screen.dart';
import 'analytics/analytics_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'plan/plan_screen.dart';
import 'transactions/add_edit_transaction_screen.dart';
import 'transactions/transactions_list_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    final ar = context.watch<SettingsProvider>().isArabic;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          DashboardScreen(),
          TransactionsListScreen(),
          AiAdvisorScreen(),
          PlanScreen(),
          AnalyticsScreen(),
        ],
      ),
      floatingActionButton: _index == 2
          ? null
          : FloatingActionButton(
              tooltip: ar ? 'إضافة معاملة' : 'Add transaction',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddEditTransactionScreen(),
                ),
              ),
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: ar ? 'الرئيسية' : 'Home',
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: ar ? 'المعاملات' : 'Records',
          ),
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            selectedIcon: const Icon(Icons.auto_awesome),
            label: ar ? 'المستشار' : 'Advisor',
            tooltip: ar ? 'المستشار المالي الذكي' : 'AI Financial Advisor',
          ),
          NavigationDestination(
            icon: const Icon(Icons.track_changes_outlined),
            selectedIcon: const Icon(Icons.track_changes),
            label: ar ? 'الخطة' : 'Plan',
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: ar ? 'التحليلات' : 'Analytics',
          ),
        ],
      ),
    );
  }
}
