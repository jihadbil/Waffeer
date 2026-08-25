import 'package:intl/intl.dart';
import '../constants/currencies.dart';

class CurrencyFormatter {
  static String format(
    double amount, {
    required String currencyCode,
    bool showSymbol = true,
    int decimalDigits = 2,
    bool isArabic = false,
  }) {
    final currency = Currencies.getByCode(currencyCode);
    final formatter = NumberFormat.currency(
      locale: isArabic ? 'ar' : 'en_US',
      symbol: showSymbol ? currency.symbol : '',
      decimalDigits: amount % 1 == 0 ? 0 : decimalDigits,
    );

    final formatted = formatter.format(amount).trim();
    return formatted;
  }

  static String formatCompact(
    double amount, {
    required String currencyCode,
    bool isArabic = false,
  }) {
    final currency = Currencies.getByCode(currencyCode);
    final compact = NumberFormat.compact(locale: isArabic ? 'ar' : 'en_US').format(amount);
    return isArabic ? '$compact ${currency.symbol}' : '${currency.symbol} $compact';
  }
}
