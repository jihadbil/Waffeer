import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/wallet_model.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/wallet_provider.dart';
import 'add_edit_wallet_screen.dart';

class WalletsScreen extends StatelessWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isArabic = settings.isArabic;
    final walletProvider = context.watch<WalletProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'المحافظ والحسابات' : 'Wallets & Accounts'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Total Wealth Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'إجمالي الثروة والأرصدة' : 'Total Net Balance',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  CurrencyFormatter.format(
                    walletProvider.totalBalance,
                    currencyCode: settings.currencyCode,
                    isArabic: isArabic,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Wallets List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'حساباتك المالية' : 'Your Accounts',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '${walletProvider.wallets.length} ${isArabic ? "محفظة" : "wallets"}',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ...walletProvider.wallets.map((wallet) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: wallet.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(wallet.iconData, color: wallet.color, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wallet.localizedName(isArabic),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _walletTypeName(wallet.type, isArabic),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format(
                          wallet.currentBalance,
                          currencyCode: wallet.currencyCode,
                          isArabic: isArabic,
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: wallet.currentBalance >= 0 ? AppColors.primary : AppColors.expense,
                        ),
                      ),
                      const SizedBox(height: 4),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddEditWalletScreen(wallet: wallet),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditWalletScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: Text(isArabic ? 'إضافة محفظة' : 'Add Wallet'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  String _walletTypeName(WalletType type, bool isArabic) {
    switch (type) {
      case WalletType.cash:
        return isArabic ? 'نقدي / كاش' : 'Cash';
      case WalletType.bank:
        return isArabic ? 'حساب بنكي' : 'Bank Account';
      case WalletType.creditCard:
        return isArabic ? 'بطاقة ائتمان' : 'Credit Card';
      case WalletType.digitalWallet:
        return isArabic ? 'محفظة رقمية' : 'Digital Wallet';
      case WalletType.savings:
        return isArabic ? 'خزنة مدخرات' : 'Savings Vault';
      case WalletType.other:
        return isArabic ? 'أخرى' : 'Other';
    }
  }
}
