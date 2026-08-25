enum TransactionType { expense, income, transfer }

class TransactionModel {
  final String id;
  final double amount;
  final TransactionType type;
  final String categoryId;
  final String walletId;
  final String? toWalletId; // Used for transfer transactions
  final DateTime dateTime;
  final String? title;
  final String? note;
  final String? receiptImagePath;
  final String currencyCode;
  final bool isRecurring;
  final String? tag;

  const TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.walletId,
    this.toWalletId,
    required this.dateTime,
    this.title,
    this.note,
    this.receiptImagePath,
    required this.currencyCode,
    this.isRecurring = false,
    this.tag,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'type': type.name,
      'category_id': categoryId,
      'wallet_id': walletId,
      'to_wallet_id': toWalletId,
      'date_time': dateTime.toIso8601String(),
      'title': title,
      'note': note,
      'receipt_image_path': receiptImagePath,
      'currency_code': currencyCode,
      'is_recurring': isRecurring ? 1 : 0,
      'tag': tag,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.expense,
      ),
      categoryId: map['category_id'] as String,
      walletId: map['wallet_id'] as String,
      toWalletId: map['to_wallet_id'] as String?,
      dateTime: DateTime.parse(map['date_time'] as String),
      title: map['title'] as String?,
      note: map['note'] as String?,
      receiptImagePath: map['receipt_image_path'] as String?,
      currencyCode: map['currency_code'] as String,
      isRecurring: (map['is_recurring'] as int? ?? 0) == 1,
      tag: map['tag'] as String?,
    );
  }

  TransactionModel copyWith({
    String? id,
    double? amount,
    TransactionType? type,
    String? categoryId,
    String? walletId,
    String? toWalletId,
    DateTime? dateTime,
    String? title,
    String? note,
    String? receiptImagePath,
    String? currencyCode,
    bool? isRecurring,
    String? tag,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      walletId: walletId ?? this.walletId,
      toWalletId: toWalletId ?? this.toWalletId,
      dateTime: dateTime ?? this.dateTime,
      title: title ?? this.title,
      note: note ?? this.note,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
      currencyCode: currencyCode ?? this.currencyCode,
      isRecurring: isRecurring ?? this.isRecurring,
      tag: tag ?? this.tag,
    );
  }
}
