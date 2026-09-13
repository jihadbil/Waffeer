import 'transaction_model.dart';

enum RecurrenceFrequency { daily, weekly, monthly, yearly }

class RecurringTransactionModel {
  final String id;
  final double amount;
  final TransactionType type;
  final String categoryId;
  final String walletId;
  final String? toWalletId;
  final String title;
  final String? note;
  final RecurrenceFrequency frequency;
  final DateTime startDate;
  final DateTime nextDueDate;
  final DateTime? lastExecutedDate;
  final String currencyCode;
  final bool isActive;

  const RecurringTransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.walletId,
    this.toWalletId,
    required this.title,
    this.note,
    required this.frequency,
    required this.startDate,
    required this.nextDueDate,
    this.lastExecutedDate,
    required this.currencyCode,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'type': type.name,
      'category_id': categoryId,
      'wallet_id': walletId,
      'to_wallet_id': toWalletId,
      'title': title,
      'note': note,
      'frequency': frequency.name,
      'start_date': startDate.toIso8601String(),
      'next_due_date': nextDueDate.toIso8601String(),
      'last_executed_date': lastExecutedDate?.toIso8601String(),
      'currency_code': currencyCode,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory RecurringTransactionModel.fromMap(Map<String, dynamic> map) {
    return RecurringTransactionModel(
      id: map['id'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.expense,
      ),
      categoryId: map['category_id'] as String,
      walletId: map['wallet_id'] as String,
      toWalletId: map['to_wallet_id'] as String?,
      title: map['title'] as String,
      note: map['note'] as String?,
      frequency: RecurrenceFrequency.values.firstWhere(
        (e) => e.name == map['frequency'],
        orElse: () => RecurrenceFrequency.monthly,
      ),
      startDate: DateTime.parse(map['start_date'] as String),
      nextDueDate: DateTime.parse(map['next_due_date'] as String),
      lastExecutedDate: map['last_executed_date'] != null
          ? DateTime.parse(map['last_executed_date'] as String)
          : null,
      currencyCode: map['currency_code'] as String,
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }

  RecurringTransactionModel copyWith({
    String? id,
    double? amount,
    TransactionType? type,
    String? categoryId,
    String? walletId,
    String? toWalletId,
    String? title,
    String? note,
    RecurrenceFrequency? frequency,
    DateTime? startDate,
    DateTime? nextDueDate,
    DateTime? lastExecutedDate,
    String? currencyCode,
    bool? isActive,
  }) {
    return RecurringTransactionModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      walletId: walletId ?? this.walletId,
      toWalletId: toWalletId ?? this.toWalletId,
      title: title ?? this.title,
      note: note ?? this.note,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      lastExecutedDate: lastExecutedDate ?? this.lastExecutedDate,
      currencyCode: currencyCode ?? this.currencyCode,
      isActive: isActive ?? this.isActive,
    );
  }

  DateTime calculateNextDate(DateTime fromDate) {
    switch (frequency) {
      case RecurrenceFrequency.daily:
        return fromDate.add(const Duration(days: 1));
      case RecurrenceFrequency.weekly:
        return fromDate.add(const Duration(days: 7));
      case RecurrenceFrequency.monthly:
        int newYear = fromDate.year;
        int newMonth = fromDate.month + 1;
        if (newMonth > 12) {
          newYear++;
          newMonth = 1;
        }
        int newDay = fromDate.day;
        int maxDaysInNewMonth = DateTime(newYear, newMonth + 1, 0).day;
        if (newDay > maxDaysInNewMonth) newDay = maxDaysInNewMonth;
        return DateTime(
          newYear,
          newMonth,
          newDay,
          fromDate.hour,
          fromDate.minute,
        );
      case RecurrenceFrequency.yearly:
        return DateTime(
          fromDate.year + 1,
          fromDate.month,
          fromDate.day,
          fromDate.hour,
          fromDate.minute,
        );
    }
  }

  String localizedFrequency(bool isArabic) {
    switch (frequency) {
      case RecurrenceFrequency.daily:
        return isArabic ? 'يومياً' : 'Daily';
      case RecurrenceFrequency.weekly:
        return isArabic ? 'أسبوعياً' : 'Weekly';
      case RecurrenceFrequency.monthly:
        return isArabic ? 'شهرياً' : 'Monthly';
      case RecurrenceFrequency.yearly:
        return isArabic ? 'سنوياً' : 'Yearly';
    }
  }
}
