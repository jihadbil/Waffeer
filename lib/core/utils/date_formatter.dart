import 'package:intl/intl.dart';

class DateFormatter {
  static String formatShort(DateTime date, {bool isArabic = false}) {
    return DateFormat('d MMM yyyy', isArabic ? 'ar' : 'en').format(date);
  }

  static String formatMonthYear(DateTime date, {bool isArabic = false}) {
    return DateFormat('MMMM yyyy', isArabic ? 'ar' : 'en').format(date);
  }

  static String formatRelative(DateTime date, {bool isArabic = false}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(itemDate).inDays;

    if (diff == 0) {
      return isArabic ? 'اليوم' : 'Today';
    } else if (diff == 1) {
      return isArabic ? 'أمس' : 'Yesterday';
    } else if (diff == -1) {
      return isArabic ? 'غداً' : 'Tomorrow';
    } else {
      return formatShort(date, isArabic: isArabic);
    }
  }

  static String formatTime(DateTime date, {bool isArabic = false}) {
    return DateFormat('hh:mm a', isArabic ? 'ar' : 'en').format(date);
  }
}
