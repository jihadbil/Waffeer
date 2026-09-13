import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/currencies.dart';
import '../../../providers/settings_provider.dart';
import 'financial_setup_screen.dart';

class CurrencySetupScreen extends StatefulWidget {
  const CurrencySetupScreen({super.key});

  @override
  State<CurrencySetupScreen> createState() => _CurrencySetupScreenState();
}

class _CurrencySetupScreenState extends State<CurrencySetupScreen> {
  String _selectedCode = 'USD';
  final TextEditingController _searchController = TextEditingController();
  List<AppCurrency> _filteredCurrencies = Currencies.list;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _filteredCurrencies = Currencies.list;
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 180), () {
      final q = query.trim().toLowerCase();
      if (!mounted) return;
      setState(() {
        if (q.isEmpty) {
          _filteredCurrencies = Currencies.list;
        } else {
          _filteredCurrencies = Currencies.list.where((c) {
            return c.code.toLowerCase().contains(q) ||
                c.nameEn.toLowerCase().contains(q) ||
                c.nameAr.toLowerCase().contains(q) ||
                c.symbol.toLowerCase().contains(q);
          }).toList();
        }
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isArabic = settings.isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredCurrencies = _filteredCurrencies;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // Language Switch & Logo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isArabic ? 'وفير' : 'Waffeer',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  // Lang toggle
                  TextButton.icon(
                    onPressed: () {
                      settings.setLocale(
                        isArabic ? const Locale('en') : const Locale('ar'),
                      );
                    },
                    icon: const Icon(Icons.language, size: 18),
                    label: Text(isArabic ? 'English' : 'العربية'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Title & Subtitle
              Text(
                isArabic ? 'مرحباً بك في وفير 👋' : 'Welcome to Waffeer 👋',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isArabic
                    ? 'اختر عملتك الرئيسية لبدء إدارة وتتبع أموالك ومصاريفك بكل دقة:'
                    : 'Choose your primary currency to start managing your expenses accurately:',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 16),

              // Search Box
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: isArabic
                      ? 'ابحث عن العملة أو الدولة...'
                      : 'Search currency or country...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _debounceTimer?.cancel();
                            setState(() {
                              _filteredCurrencies = Currencies.list;
                            });
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              // Currencies List
              Expanded(
                child: ListView.separated(
                  itemCount: filteredCurrencies.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, index) {
                    final curr = filteredCurrencies[index];
                    final isSelected = curr.code == _selectedCode;

                    return InkWell(
                      onTap: () => setState(() => _selectedCode = curr.code),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(
                                  alpha: isDark ? 0.2 : 0.1,
                                )
                              : Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : (isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              curr.flag,
                              style: const TextStyle(fontSize: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    curr.code,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    isArabic ? curr.nameAr : curr.nameEn,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                curr.symbol,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: AppColors.primary,
                                size: 22,
                              )
                            else
                              Icon(
                                Icons.radio_button_unchecked,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withValues(alpha: 0.4),
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),
              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            FinancialSetupScreen(currencyCode: _selectedCode),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isArabic ? 'التالي: إعداد خطتك' : 'Next: Set up your plan',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
