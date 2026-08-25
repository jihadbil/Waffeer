import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/wallet_model.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/wallet_provider.dart';

class AddEditWalletScreen extends StatefulWidget {
  final WalletModel? wallet;

  const AddEditWalletScreen({super.key, this.wallet});

  @override
  State<AddEditWalletScreen> createState() => _AddEditWalletScreenState();
}

class _AddEditWalletScreenState extends State<AddEditWalletScreen> {
  final TextEditingController _nameArController = TextEditingController();
  final TextEditingController _nameEnController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();

  WalletType _selectedType = WalletType.cash;
  int _selectedColor = 0xFF10B981;
  int _selectedIcon = 0xe463; // payments

  final List<int> _colors = [
    0xFF10B981, 0xFF3B82F6, 0xFF6366F1, 0xFF8B5CF6,
    0xFFEC4899, 0xFFEF4444, 0xFFF59E0B, 0xFF14B8A6,
  ];

  final List<int> _icons = [
    0xe463, // payments
    0xe040, // account_balance
    0xe19f, // credit_card
    0xe56c, // savings
    0xe041, // account_balance_wallet
    0xe59c, // shopping_bag
    0xe661, // trending_up
    0xe8e5, // monetization_on
  ];

  @override
  void initState() {
    super.initState();
    if (widget.wallet != null) {
      _nameArController.text = widget.wallet!.nameAr;
      _nameEnController.text = widget.wallet!.nameEn;
      _balanceController.text = widget.wallet!.currentBalance.toString();
      _selectedType = widget.wallet!.type;
      _selectedColor = widget.wallet!.colorValue;
      _selectedIcon = widget.wallet!.iconCodePoint;
    }
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isArabic = settings.isArabic;
    final isEditing = widget.wallet != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing
            ? (isArabic ? 'تعديل المحفظة' : 'Edit Wallet')
            : (isArabic ? 'إضافة محفظة جديدة' : 'Add New Wallet')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name Fields
            Text(
              isArabic ? 'اسم المحفظة بالعربية' : 'Wallet Name (Arabic)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameArController,
              decoration: InputDecoration(
                hintText: isArabic ? 'مثال: محفظة الجيب، حساب الراجحي' : 'e.g., Pocket cash',
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              isArabic ? 'اسم المحفظة بالإنجليزية' : 'Wallet Name (English)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameEnController,
              decoration: InputDecoration(
                hintText: isArabic ? 'مثال: Main Bank, Cash' : 'e.g., Main Bank',
                prefixIcon: const Icon(Icons.language),
              ),
            ),
            const SizedBox(height: 16),

            // Initial Balance (if new)
            if (!isEditing) ...[
              Text(
                isArabic ? 'الرصيد الافتتاحي' : 'Initial Balance',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _balanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixIcon: const Icon(Icons.attach_money),
                  suffixText: settings.currency.symbol,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Wallet Type
            Text(
              isArabic ? 'نوع الحساب' : 'Account Type',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<WalletType>(
              initialValue: _selectedType,
              items: WalletType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_walletTypeName(type, isArabic)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedType = val);
              },
            ),
            const SizedBox(height: 20),

            // Icon Picker
            Text(
              isArabic ? 'اختر الأيقونة' : 'Select Icon',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _icons.map((code) {
                final isSelected = _selectedIcon == code;
                return InkWell(
                  onTap: () => setState(() => _selectedIcon = code),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Color(_selectedColor).withValues(alpha: 0.2)
                          : Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Color(_selectedColor) : Colors.grey.withValues(alpha: 0.3),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      IconData(code, fontFamily: 'MaterialIcons'),
                      color: isSelected ? Color(_selectedColor) : Colors.grey,
                      size: 24,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Color Picker
            Text(
              isArabic ? 'اختر اللون' : 'Select Color',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _colors.map((colorVal) {
                final isSelected = _selectedColor == colorVal;
                return InkWell(
                  onTap: () => setState(() => _selectedColor = colorVal),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Color(colorVal),
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saveWallet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(_selectedColor),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  isArabic ? 'حفظ المحفظة ✓' : 'Save Wallet ✓',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
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
        return isArabic ? 'خزنة مدخرات' : 'Savings Vault';
      case WalletType.other:
        return isArabic ? 'أخرى' : 'Other';
    }
  }

  Future<void> _saveWallet() async {
    final settings = context.read<SettingsProvider>();
    final isArabic = settings.isArabic;
    final nameAr = _nameArController.text.trim();
    final nameEn = _nameEnController.text.trim();

    if (nameAr.isEmpty && nameEn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'يرجى إدخال اسم المحفظة' : 'Please enter wallet name'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    final balance = double.tryParse(_balanceController.text.trim()) ?? 0.0;
    final walletProvider = context.read<WalletProvider>();

    if (widget.wallet != null) {
      // Update
      final updated = widget.wallet!.copyWith(
        nameAr: nameAr.isNotEmpty ? nameAr : nameEn,
        nameEn: nameEn.isNotEmpty ? nameEn : nameAr,
        type: _selectedType,
        colorValue: _selectedColor,
        iconCodePoint: _selectedIcon,
      );
      await walletProvider.updateWallet(updated);
    } else {
      // Create new
      await walletProvider.addWallet(
        nameAr: nameAr.isNotEmpty ? nameAr : nameEn,
        nameEn: nameEn.isNotEmpty ? nameEn : nameAr,
        initialBalance: balance,
        currencyCode: settings.currencyCode,
        iconCodePoint: _selectedIcon,
        colorValue: _selectedColor,
        type: _selectedType,
      );
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }
}
