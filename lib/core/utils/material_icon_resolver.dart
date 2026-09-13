import 'package:flutter/material.dart';

/// Resolves persisted Material icon code points to compile-time constants.
///
/// Older Waffeer versions stored code points from a previous Flutter icon
/// font. Keeping the legacy aliases prevents existing wallets and categories
/// from changing appearance after an SDK upgrade, while avoiding dynamic
/// [IconData] instances that break icon tree-shaking in release builds.
class MaterialIconResolver {
  MaterialIconResolver._();

  static final Map<int, IconData> _supportedIcons = {
    for (final icon in _currentIcons) icon.codePoint: icon,

    // Legacy category aliases.
    0xe57a: Icons.restaurant,
    0xe59c: Icons.shopping_cart,
    0xe1d7: Icons.directions_car,
    0xe318: Icons.home,
    0xe54e: Icons.receipt_long,
    0xe405: Icons.movie,
    0xe3be: Icons.local_hospital,
    0xe559: Icons.school,
    0xe400: Icons.more_horiz,
    0xe3ae: Icons.laptop,
    0xe661: Icons.trending_up,
    0xe13d: Icons.card_giftcard,
    0xe047: Icons.add_circle_outline,

    // Legacy wallet aliases.
    0xe463: Icons.payments,
    0xe040: Icons.account_balance,
    0xe19f: Icons.credit_card,
    0xe56c: Icons.savings,
    0xe041: Icons.account_balance_wallet,
    0xe8e5: Icons.monetization_on,

    // Legacy goal alias.
    0xe57f: Icons.track_changes_rounded,
  };

  static const List<IconData> _currentIcons = [
    Icons.restaurant,
    Icons.shopping_cart,
    Icons.directions_car,
    Icons.home,
    Icons.receipt_long,
    Icons.movie,
    Icons.local_hospital,
    Icons.school,
    Icons.more_horiz,
    Icons.account_balance_wallet,
    Icons.account_balance,
    Icons.laptop,
    Icons.trending_up,
    Icons.card_giftcard,
    Icons.add_circle_outline,
    Icons.payments,
    Icons.credit_card,
    Icons.savings,
    Icons.shopping_bag,
    Icons.monetization_on,
    Icons.track_changes_rounded,
    Icons.savings_rounded,
  ];

  static IconData resolve(
    int codePoint, {
    IconData fallback = Icons.category_rounded,
  }) {
    return _supportedIcons[codePoint] ?? fallback;
  }
}
