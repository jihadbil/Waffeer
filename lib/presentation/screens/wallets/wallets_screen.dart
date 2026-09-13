import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/wallet_model.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/wallet_provider.dart';
import 'add_edit_wallet_screen.dart';

/// شاشة إدارة المحافظ والحسابات البنكية بتصميم Digital Cards 2.0
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
        title: Text(
          isArabic ? 'المحافظ والحسابات' : 'Wallets & Accounts',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ),
      body: ListView(
        padding:
            const EdgeInsets.only(left: 18, right: 18, top: 12, bottom: 84),
        children: [
          // 1. بطاقة إجمالي الثروة والأرصدة
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: AppColors.luxuryCardGradient,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.2,
              ),
              boxShadow: const [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isArabic ? 'إجمالي الثروة والأرصدة' : 'Total Net Worth',
                      style: const TextStyle(
                        color: Color(0xFFB3C7BD),
                        fontSize: 13,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${walletProvider.wallets.length} ${isArabic ? "حسابات" : "accounts"}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  CurrencyFormatter.format(
                    walletProvider.totalBalance,
                    currencyCode: settings.currencyCode,
                    isArabic: isArabic,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. ترويسة قائمة الحسابات
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'حساباتك وبطاقاتك' : 'Your Accounts & Cards',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              Text(
                '${walletProvider.wallets.length} ${isArabic ? "محفظة" : "wallets"}',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. كروت الحسابات والمحافظ
          ...walletProvider.wallets.map((wallet) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
                boxShadow: const [],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: wallet.color.withValues(
                        alpha: isDark ? 0.22 : 0.14,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: wallet.color.withValues(alpha: 0.3),
                        width: 1,
                      ),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _walletTypeName(wallet.type, isArabic),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color,
                            fontFamily: 'Cairo',
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
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: wallet.currentBalance >= 0
                              ? AppColors.primary
                              : AppColors.expense,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 2),
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AddEditWalletScreen(wallet: wallet),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 14,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isArabic ? 'تعديل' : 'Edit',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: AppColors.primaryGradient,
          boxShadow: const [],
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddEditWalletScreen()),
            );
          },
          icon: const Icon(Icons.add_rounded, size: 22),
          label: Text(
            isArabic ? 'إضافة محفظة' : 'Add Wallet',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
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
        return isArabic ? 'حساب توفير' : 'Savings Account';
      case WalletType.other:
        return isArabic ? 'أخرى' : 'Other';
    }
  }
}
