enum BudgetPeriod { weekly, monthly, yearly }

class BudgetModel {
  final String id;
  final String? categoryId; // null means overall total budget
  final double limitAmount;
  final BudgetPeriod period;
  final DateTime startDate;
  final DateTime endDate;
  final String currencyCode;
  final bool notifyOn80Percent;
  final bool notifyOnExceed;

  const BudgetModel({
    required this.id,
    this.categoryId,
    required this.limitAmount,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.currencyCode,
    this.notifyOn80Percent = true,
    this.notifyOnExceed = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'limit_amount': limitAmount,
      'period': period.name,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'currency_code': currencyCode,
      'notify_80': notifyOn80Percent ? 1 : 0,
      'notify_exceed': notifyOnExceed ? 1 : 0,
    };
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id'] as String,
      categoryId: map['category_id'] as String?,
      limitAmount: (map['limit_amount'] as num).toDouble(),
      period: BudgetPeriod.values.firstWhere(
        (e) => e.name == map['period'],
        orElse: () => BudgetPeriod.monthly,
      ),
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      currencyCode: map['currency_code'] as String,
      notifyOn80Percent: (map['notify_80'] as int? ?? 1) == 1,
      notifyOnExceed: (map['notify_exceed'] as int? ?? 1) == 1,
    );
  }

  BudgetModel copyWith({
    String? id,
    String? categoryId,
    double? limitAmount,
    BudgetPeriod? period,
    DateTime? startDate,
    DateTime? endDate,
    String? currencyCode,
    bool? notifyOn80Percent,
    bool? notifyOnExceed,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      limitAmount: limitAmount ?? this.limitAmount,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      currencyCode: currencyCode ?? this.currencyCode,
      notifyOn80Percent: notifyOn80Percent ?? this.notifyOn80Percent,
      notifyOnExceed: notifyOnExceed ?? this.notifyOnExceed,
    );
  }
}
