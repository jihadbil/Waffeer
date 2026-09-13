import 'package:uuid/uuid.dart';

/// أنواع الإجراءات التي يمكن للمستشار الذكي تنفيذها
enum AiActionType {
  addExpense,
  addIncome,
  addCategory,
  changeTheme,
  changeCurrency,
  addBudget,
  unknown,
}

/// نموذج يمثل الإجراء التنفيذي الذي قام به المستشار الذكي
class AiAction {
  final String id;
  final AiActionType type;
  final String title;
  final String details;
  final Map<String, dynamic> data;
  bool isExecuted;
  bool isUndone;
  String? executedEntityId;

  AiAction({
    String? id,
    required this.type,
    required this.title,
    required this.details,
    required this.data,
    this.isExecuted = true,
    this.isUndone = false,
    this.executedEntityId,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'details': details,
      'data': data,
      'is_executed': isExecuted ? 1 : 0,
      'is_undone': isUndone ? 1 : 0,
      'executed_entity_id': executedEntityId,
    };
  }

  factory AiAction.fromMap(Map<String, dynamic> map) {
    return AiAction(
      id: map['id'] as String?,
      type: AiActionType.values.firstWhere(
        (t) => t.name == (map['type'] as String?),
        orElse: () => AiActionType.unknown,
      ),
      title: map['title'] as String? ?? '',
      details: map['details'] as String? ?? '',
      data: (map['data'] as Map<String, dynamic>?) ?? {},
      isExecuted: (map['is_executed'] as int?) == 1,
      isUndone: (map['is_undone'] as int?) == 1,
      executedEntityId: map['executed_entity_id'] as String?,
    );
  }
}
