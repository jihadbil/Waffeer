import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/backup_service.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/debt_provider.dart';
import '../../../providers/goal_provider.dart';
import '../../../providers/routine_provider.dart';
import '../../../providers/security_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../widgets/export_bottom_sheet.dart';
import '../categories/categories_screen.dart';
import '../debts/debts_screen.dart';
import '../goals/goals_screen.dart';
import '../routine/routine_expenses_screen.dart';
import '../security/lock_screen.dart';
import '../wallets/wallets_screen.dart';
import 'ai_settings_screen.dart';
import 'currency_picker_screen.dart';

/// شاشة الإعدادات والخدمات بتصميم Fintech Luxury 2.0
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final secProvider = context.watch<SecurityProvider>();
    final isArabic = settings.isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isArabic ? 'الإعدادات والخدمات' : 'Settings & Services',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        children: [
          // 1. إدارة البيانات والأقسام
          _buildSectionHeader(
            isArabic ? 'إدارة البيانات والأقسام' : 'Data & Management',
            isArabic,
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
              boxShadow: const [],
            ),
            child: Column(
              children: [
                _buildTile(
                  context,
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: AppColors.primary,
                  title: isArabic
                      ? 'إدارة المحافظ والحسابات'
                      : 'Manage Wallets & Accounts',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WalletsScreen()),
                  ),
                ),
                _buildDivider(context),
                _buildTile(
                  context,
                  icon: Icons.category_rounded,
                  iconColor: AppColors.secondary,
                  title: isArabic
                      ? 'إدارة وتخصيص التصنيفات'
                      : 'Manage Categories',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                  ),
                ),
                _buildDivider(context),
                _buildTile(
                  context,
                  icon: Icons.repeat_rounded,
                  iconColor: Theme.of(context).colorScheme.primary,
                  title: isArabic ? 'المعاملات المتكررة' : 'Recurring entries',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RoutineExpensesScreen(),
                    ),
                  ),
                ),
                _buildDivider(context),
                _buildTile(
                  context,
                  icon: Icons.savings_rounded,
                  iconColor: Theme.of(context).colorScheme.primary,
                  title: isArabic ? 'أهداف التوفير والادخار' : 'Savings Goals',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GoalsScreen()),
                  ),
                ),
                _buildDivider(context),
                _buildTile(
                  context,
                  icon: Icons.handshake_rounded,
                  iconColor: Theme.of(context).colorScheme.primary,
                  title: isArabic
                      ? 'سجل الديون والمستحقات'
                      : 'Debts & Loans Tracker',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DebtsScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // الذكاء الاصطناعي (Gemini AI)
          _buildSectionHeader(
            isArabic ? 'الذكاء الاصطناعي (Gemini AI)' : 'Artificial Intelligence (Gemini)',
            isArabic,
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
              boxShadow: const [],
            ),
            child: Column(
              children: [
                _buildTile(
                  context,
                  icon: Icons.auto_awesome,
                  iconColor: Colors.amber.shade700,
                  title: isArabic
                      ? 'إعدادات ومفتاح الذكاء الاصطناعي'
                      : 'AI Settings & API Key',
                  subtitle: isArabic
                      ? 'تخصيص المفتاح، المستشار الذكي، ومسح الفواتير'
                      : 'Manage API Key, Advisor & Vision OCR',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // 2. التقارير والنسخ الاحتياطي
          _buildSectionHeader(
            isArabic ? 'التقارير والنسخ الاحتياطي' : 'Reports & Backup',
            isArabic,
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
              boxShadow: const [],
            ),
            child: Column(
              children: [
                _buildTile(
                  context,
                  icon: Icons.picture_as_pdf_rounded,
                  iconColor: Colors.redAccent,
                  title: isArabic
                      ? 'تصدير التقارير (PDF / Excel)'
                      : 'Export Reports (PDF / Excel)',
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const ExportBottomSheet(),
                    );
                  },
                ),
                _buildDivider(context),
                _buildTile(
                  context,
                  icon: Icons.cloud_upload_rounded,
                  iconColor: AppColors.income,
                  title: isArabic
                      ? 'إنشاء نسخة احتياطية من البيانات'
                      : 'Backup Database',
                  subtitle: isArabic
                      ? 'حفظ وتصدير كافة بيانات التطبيق'
                      : 'Save and export all data',
                  onTap: () => _handleCreateBackup(context, isArabic),
                ),
                _buildDivider(context),
                _buildTile(
                  context,
                  icon: Icons.cloud_download_rounded,
                  iconColor: AppColors.primary,
                  title: isArabic
                      ? 'استعادة البيانات من نسخة احتياطية'
                      : 'Restore from Backup',
                  subtitle: isArabic
                      ? 'استرجاع المحافظ والمعاملات'
                      : 'Restore wallets & transactions',
                  onTap: () => _handleRestoreBackup(context, isArabic),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // 3. الأمان وقفل التطبيق
          _buildSectionHeader(
            isArabic ? 'الأمان وقفل التطبيق' : 'Security & App Lock',
            isArabic,
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
              boxShadow: const [],
            ),
            child: Column(
              children: [
                _buildTile(
                  context,
                  icon: Icons.fingerprint_rounded,
                  iconColor: AppColors.income,
                  title: isArabic
                      ? 'القفل بالبصمة (Biometrics / Face ID)'
                      : 'Biometrics / Face ID',
                  subtitle: !secProvider.hasPin
                      ? (isArabic
                          ? 'يتطلب تعيين رمز PIN أولاً كإجراء أمان احتياطي'
                          : 'Requires setting a PIN code first as fallback')
                      : null,
                  trailing: Switch(
                    value: secProvider.isBiometricsEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) async {
                      HapticFeedback.lightImpact();
                      if (val && !secProvider.hasPin) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isArabic
                                  ? 'يرجى إعداد رمز PIN أولاً لتفعيل القفل بالبصمة'
                                  : 'Please set up a PIN code first before enabling biometrics',
                            ),
                            action: SnackBarAction(
                              label: isArabic ? 'إعداد الآن' : 'Set up now',
                              textColor: AppColors.primary,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LockScreen(
                                      mode: LockMode.setupPin,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                        return;
                      }
                      await secProvider.setBiometricsEnabled(val);
                    },
                  ),
                ),
                _buildDivider(context),
                _buildTile(
                  context,
                  icon: Icons.pin_rounded,
                  iconColor: Theme.of(context).colorScheme.primary,
                  title: secProvider.hasPin
                      ? (isArabic ? 'رمز PIN (مفعّل)' : 'PIN Code (Enabled)')
                      : (isArabic
                            ? 'إعداد رمز PIN للتطبيق'
                            : 'Set up PIN Code'),
                  subtitle: secProvider.hasPin
                      ? (isArabic
                            ? 'اضغط لتغيير أو إزالة رمز PIN'
                            : 'Tap to change or remove PIN')
                      : null,
                  trailing: secProvider.hasPin
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.expense,
                                size: 20,
                              ),
                              tooltip: isArabic ? 'إزالة الرمز' : 'Remove PIN',
                              onPressed: () async {
                                HapticFeedback.mediumImpact();
                                await secProvider.removePin();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isArabic
                                            ? 'تمت إزالة رمز PIN'
                                            : 'PIN removed',
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                            Icon(
                              isArabic
                                  ? Icons.arrow_back_ios_rounded
                                  : Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: Colors.grey,
                            ),
                          ],
                        )
                      : Icon(
                          isArabic
                              ? Icons.arrow_back_ios_rounded
                              : Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Colors.grey,
                        ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const LockScreen(mode: LockMode.setupPin),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // 4. التنبيهات والتذكيرات
          _buildSectionHeader(
            isArabic ? 'التنبيهات والتذكيرات' : 'Notifications & Reminders',
            isArabic,
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
              boxShadow: const [],
            ),
            child: Column(
              children: [
                _buildTile(
                  context,
                  icon: Icons.notifications_active_rounded,
                  iconColor: Theme.of(context).colorScheme.primary,
                  title: isArabic
                      ? 'التذكير اليومي بتسجيل المصاريف'
                      : 'Daily Expense Reminder',
                  trailing: Switch(
                    value: settings.isDailyReminderEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) async {
                      HapticFeedback.lightImpact();
                      final success = await settings.setDailyReminderEnabled(
                        val,
                      );
                      if (!success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isArabic
                                  ? 'يلزم السماح بالإشعارات لتفعيل التذكير.'
                                  : 'Notification permission is required to enable reminders.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
                if (settings.isDailyReminderEnabled) ...[
                  _buildDivider(context),
                  _buildTile(
                    context,
                    icon: Icons.access_time_rounded,
                    iconColor: AppColors.info,
                    title: isArabic ? 'وقت التذكير' : 'Reminder Time',
                    trailing: Text(
                      '${settings.reminderHour.toString().padLeft(2, '0')}:${settings.reminderMinute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: settings.reminderHour,
                          minute: settings.reminderMinute,
                        ),
                      );
                      if (time != null) {
                        await settings.setReminderTime(time.hour, time.minute);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),

          // 5. تفضيلات التطبيق
          _buildSectionHeader(
            isArabic ? 'تفضيلات التطبيق' : 'App Preferences',
            isArabic,
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
              boxShadow: const [],
            ),
            child: Column(
              children: [
                _buildTile(
                  context,
                  icon: Icons.monetization_on_rounded,
                  iconColor: AppColors.primary,
                  title: isArabic ? 'العملة المختارة' : 'Selected Currency',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        settings.currency.flag,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${settings.currency.code} (${settings.currency.symbol})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isArabic
                            ? Icons.arrow_back_ios_rounded
                            : Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CurrencyPickerScreen(),
                    ),
                  ),
                ),
                _buildDivider(context),
                _buildTile(
                  context,
                  icon: Icons.dark_mode_rounded,
                  iconColor: Theme.of(context).colorScheme.primary,
                  title: isArabic ? 'المظهر الليلي (Dark Mode)' : 'Dark Theme',
                  trailing: Switch(
                    value:
                        settings.themeMode == ThemeMode.dark ||
                        (settings.themeMode == ThemeMode.system && isDark),
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      settings.setThemeMode(
                        val ? ThemeMode.dark : ThemeMode.light,
                      );
                    },
                  ),
                ),
                _buildDivider(context),
                _buildTile(
                  context,
                  icon: Icons.language_rounded,
                  iconColor: AppColors.info,
                  title: isArabic ? 'لغة التطبيق' : 'App Language',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isArabic ? 'العربية' : 'English',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isArabic
                            ? Icons.arrow_back_ios_rounded
                            : Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    settings.setLocale(
                      isArabic ? const Locale('en') : const Locale('ar'),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // 6. بطاقة معلومات التطبيق
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1A302A), const Color(0xFF1A302A)]
                    : [
                        AppColors.primary.withValues(alpha: 0.08),
                        const Color(0xFFF5F8F7),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'تطبيق وفير (Waffeer)' : 'Waffeer Finance',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isArabic
                            ? 'إصدار 2.0.0 • رفيقك المالي الذكي لإدارة أموالك وتوفيرها'
                            : 'Version 2.0.0 • Your smart personal finance companion',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isArabic) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4, right: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final isArabic = context.read<SettingsProvider>().isArabic;
    final tileColor = Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.primary
        : iconColor;
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: tileColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: tileColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontFamily: 'Cairo',
                ),
              )
            : null,
        trailing:
            trailing ??
            Icon(
              isArabic
                  ? Icons.arrow_back_ios_rounded
                  : Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.grey,
            ),
        onTap: () {
          if (onTap != null) {
            HapticFeedback.lightImpact();
            onTap();
          }
        },
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      indent: 56,
    );
  }

  Future<void> _handleCreateBackup(BuildContext context, bool isArabic) async {
    HapticFeedback.mediumImpact();
    final result = await BackupService.createAndShareBackup(isArabic);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success
              ? AppColors.income
              : AppColors.expense,
        ),
      );
    }
  }

  Future<void> _handleRestoreBackup(BuildContext context, bool isArabic) async {
    HapticFeedback.mediumImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isArabic ? 'تأكيد استعادة البيانات' : 'Confirm Restore',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        content: Text(
          isArabic
              ? 'تنبيه: سيتم استبدال البيانات الحالية بالبيانات الموجودة في ملف النسخة الاحتياطية. هل تود المتابعة؟'
              : 'Warning: Current data will be replaced with the data from the backup file. Do you want to proceed?',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              isArabic ? 'إلغاء' : 'Cancel',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(
              isArabic ? 'استعادة' : 'Restore',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final catProvider = context.read<CategoryProvider>();
      final walletProvider = context.read<WalletProvider>();
      final txProvider = context.read<TransactionProvider>();
      final recProvider = context.read<RoutineProvider>();
      final budgetProvider = context.read<BudgetProvider>();
      final goalProvider = context.read<GoalProvider>();
      final debtProvider = context.read<DebtProvider>();
      final settings = context.read<SettingsProvider>();
      final messenger = ScaffoldMessenger.of(context);

      final result = await BackupService.restoreFromBackupFile(isArabic);
      if (result.success) {
        await catProvider.loadCategories();
        await walletProvider.loadWallets(settings.currencyCode);
        await txProvider.loadTransactions();
        await recProvider.loadRoutines();
        await recProvider.syncReminders(isArabic);
        await budgetProvider.loadBudgets();
        await goalProvider.loadGoals();
        await debtProvider.loadDebts();

        messenger.showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppColors.income,
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }
}
