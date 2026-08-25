import 'package:flutter/material.dart';

enum WalletType { cash, bank, creditCard, digitalWallet, savings, other }

class WalletModel {
  final String id;
  final String nameEn;
  final String nameAr;
  final double initialBalance;
  final double currentBalance;
  final String currencyCode;
  final int iconCodePoint;
  final String? iconFontFamily;
  final int colorValue;
  final WalletType type;
  final bool isDefault;

  const WalletModel({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.initialBalance,
    required this.currentBalance,
    required this.currencyCode,
    required this.iconCodePoint,
    this.iconFontFamily,
    required this.colorValue,
    required this.type,
    this.isDefault = false,
  });

  IconData get iconData => IconData(
        iconCodePoint,
        fontFamily: iconFontFamily ?? 'MaterialIcons',
      );

  Color get color => Color(colorValue);

  String localizedName(bool isArabic) => isArabic ? nameAr : nameEn;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name_en': nameEn,
      'name_ar': nameAr,
      'initial_balance': initialBalance,
      'current_balance': currentBalance,
      'currency_code': currencyCode,
      'icon_code_point': iconCodePoint,
      'icon_font_family': iconFontFamily,
      'color_value': colorValue,
      'type': type.name,
      'is_default': isDefault ? 1 : 0,
    };
  }

  factory WalletModel.fromMap(Map<String, dynamic> map) {
    return WalletModel(
      id: map['id'] as String,
      nameEn: map['name_en'] as String,
      nameAr: map['name_ar'] as String,
      initialBalance: (map['initial_balance'] as num).toDouble(),
      currentBalance: (map['current_balance'] as num).toDouble(),
      currencyCode: map['currency_code'] as String,
      iconCodePoint: map['icon_code_point'] as int,
      iconFontFamily: map['icon_font_family'] as String?,
      colorValue: map['color_value'] as int,
      type: WalletType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => WalletType.cash,
      ),
      isDefault: (map['is_default'] as int? ?? 0) == 1,
    );
  }

  WalletModel copyWith({
    String? id,
    String? nameEn,
    String? nameAr,
    double? initialBalance,
    double? currentBalance,
    String? currencyCode,
    int? iconCodePoint,
    String? iconFontFamily,
    int? colorValue,
    WalletType? type,
    bool? isDefault,
  }) {
    return WalletModel(
      id: id ?? this.id,
      nameEn: nameEn ?? this.nameEn,
      nameAr: nameAr ?? this.nameAr,
      initialBalance: initialBalance ?? this.initialBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      currencyCode: currencyCode ?? this.currencyCode,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      colorValue: colorValue ?? this.colorValue,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  static List<WalletModel> defaultWallets(String currencyCode) => [
        WalletModel(
          id: 'wallet_cash',
          nameEn: 'Cash / Pocket',
          nameAr: 'نقدي / كاش',
          initialBalance: 0.0,
          currentBalance: 0.0,
          currencyCode: currencyCode,
          iconCodePoint: 0xe463, // payments
          colorValue: 0xFF10B981,
          type: WalletType.cash,
          isDefault: true,
        ),
        WalletModel(
          id: 'wallet_bank',
          nameEn: 'Main Bank Account',
          nameAr: 'حساب بنكي رئيسي',
          initialBalance: 0.0,
          currentBalance: 0.0,
          currencyCode: currencyCode,
          iconCodePoint: 0xe040, // account_balance
          colorValue: 0xFF3B82F6,
          type: WalletType.bank,
          isDefault: false,
        ),
        WalletModel(
          id: 'wallet_savings',
          nameEn: 'Savings Vault',
          nameAr: 'خزنة المدخرات',
          initialBalance: 0.0,
          currentBalance: 0.0,
          currencyCode: currencyCode,
          iconCodePoint: 0xe56c, // savings
          colorValue: 0xFF8B5CF6,
          type: WalletType.savings,
          isDefault: false,
        ),
      ];
}
