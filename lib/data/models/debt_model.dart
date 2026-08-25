enum DebtType {
  lend, // You lent money (I am owed money - دين لي)
  borrow, // You borrowed money (I owe money - دين علي)
}

class DebtModel {
  final String id;
  final String personName;
  final double totalAmount;
  final double paidAmount;
  final DebtType type;
  final DateTime dueDate;
  final DateTime createdDate;
  final String currencyCode;
  final String? phoneNumber;
  final String? note;
  final bool isSettled;

  const DebtModel({
    required this.id,
    required this.personName,
    required this.totalAmount,
    required this.paidAmount,
    required this.type,
    required this.dueDate,
    required this.createdDate,
    required this.currencyCode,
    this.phoneNumber,
    this.note,
    this.isSettled = false,
  });

  double get remainingAmount {
    final diff = totalAmount - paidAmount;
    return diff > 0 ? diff : 0;
  }

  double get progressPercentage {
    if (totalAmount <= 0) return 0.0;
    return (paidAmount / totalAmount).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'person_name': personName,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'type': type.name,
      'due_date': dueDate.toIso8601String(),
      'created_date': createdDate.toIso8601String(),
      'currency_code': currencyCode,
      'phone_number': phoneNumber,
      'note': note,
      'is_settled': isSettled ? 1 : 0,
    };
  }

  factory DebtModel.fromMap(Map<String, dynamic> map) {
    return DebtModel(
      id: map['id'] as String,
      personName: map['person_name'] as String,
      totalAmount: (map['total_amount'] as num).toDouble(),
      paidAmount: (map['paid_amount'] as num).toDouble(),
      type: map['type'] == 'lend' ? DebtType.lend : DebtType.borrow,
      dueDate: DateTime.parse(map['due_date'] as String),
      createdDate: DateTime.parse(map['created_date'] as String),
      currencyCode: map['currency_code'] as String,
      phoneNumber: map['phone_number'] as String?,
      note: map['note'] as String?,
      isSettled: (map['is_settled'] as int? ?? 0) == 1,
    );
  }

  DebtModel copyWith({
    String? id,
    String? personName,
    double? totalAmount,
    double? paidAmount,
    DebtType? type,
    DateTime? dueDate,
    DateTime? createdDate,
    String? currencyCode,
    String? phoneNumber,
    String? note,
    bool? isSettled,
  }) {
    return DebtModel(
      id: id ?? this.id,
      personName: personName ?? this.personName,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      type: type ?? this.type,
      dueDate: dueDate ?? this.dueDate,
      createdDate: createdDate ?? this.createdDate,
      currencyCode: currencyCode ?? this.currencyCode,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      note: note ?? this.note,
      isSettled: isSettled ?? this.isSettled,
    );
  }
}
