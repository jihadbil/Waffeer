import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/settings_provider.dart';
import '../categories/categories_screen.dart';
import '../debts/debts_screen.dart';
import '../goals/goals_screen.dart';
import '../wallets/wallets_screen.dart';
import 'currency_picker_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isArabic = settings.isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'الإعدادات والمزيد' : 'Settings & More'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quick Management Tools Card
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              children: [
                _buildTile(
                  context,
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: AppColors.primary,
                  title: isArabic ? 'إدارة المحافظ والحسابات' : 'Manage Wallets & Accounts',
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
                  title: isArabic ? 'إدارة وتخصيص التصنيفات' : 'Manage Categories',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                  ),
                ),
                _buildDivider(context),
                _buildTile(
                  context,
                  icon: Icons.savings_rounded,
                  iconColor: const Color(0xFFF59E0B),
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
                  iconColor: const Color(0xFFEC4899),
                  title: isArabic ? 'سجل الديون والمستحقات' : 'Debts & Loans Tracker',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DebtsScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Preferences & App Config
          Text(
            isArabic ? 'تفضيلات التطبيق' : 'App Preferences',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              children: [
                // Currency Selector
                _buildTile(
                  context,
                  icon: Icons.monetization_on_rounded,
                  iconColor: AppColors.primary,
                  title: isArabic ? 'العملة المختارة' : 'Selected Currency',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(settings.currency.flag, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(
                        '${settings.currency.code} (${settings.currency.symbol})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    ],
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CurrencyPickerScreen()),
                  ),
                ),
                _buildDivider(context),

                // Theme Mode Switch
                _buildTile(
                  context,
                  icon: Icons.dark_mode_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  title: isArabic ? 'المظهر الليلي (Dark Mode)' : 'Dark Theme',
                  trailing: Switch(
                    value: settings.themeMode == ThemeMode.dark ||
                        (settings.themeMode == ThemeMode.system && isDark),
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) {
                      settings.setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
                    },
                  ),
                ),
                _buildDivider(context),

                // Language Switch
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
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    ],
                  ),
                  onTap: () {
                    settings.setLocale(
                      isArabic ? const Locale('en') : const Locale('ar'),
                    );
                  },
                ),
                _buildDivider(context),

                // Biometrics Security
                _buildTile(
                  context,
                  icon: Icons.fingerprint_rounded,
                  iconColor: AppColors.income,
                  title: isArabic ? 'قفل التطبيق بالبصمة' : 'Biometrics / Face ID',
                  trailing: Switch(
                    value: settings.isBiometricsEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) {
                      settings.setBiometricsEnabled(val);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // About Waffeer Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'تطبيق وفير (Waffeer)' : 'Waffeer Finance',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isArabic
                            ? 'إصدار 1.0.0 • رفيقك المالي الذكي لإدارة أموالك وتوفيرها'
                            : 'Version 1.0.0 • Your smart personal finance companion',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildDivider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      indent: 52,
    );
  }
}
