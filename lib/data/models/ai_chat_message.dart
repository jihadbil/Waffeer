import 'package:uuid/uuid.dart';

import 'ai_action.dart';

/// نموذج رسائل المحادثة مع مستشار وفير المالي الذكي
class AiChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;
  final List<String> suggestedFollowUps;
  final List<AiAction> actions;

  /// خاصية توافقية للإجراء الأول في حال وجوده
  AiAction? get action => actions.isNotEmpty ? actions.first : null;

  AiChatMessage({
    String? id,
    required this.content,
    required this.isUser,
    DateTime? timestamp,
    this.isError = false,
    this.suggestedFollowUps = const [],
    List<AiAction>? actions,
    AiAction? action,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now(),
        actions = actions ?? (action != null ? [action] : const []);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'is_user': isUser ? 1 : 0,
      'timestamp': timestamp.toIso8601String(),
      'is_error': isError ? 1 : 0,
      'suggested_follow_ups': suggestedFollowUps,
      'actions': actions.map((a) => a.toMap()).toList(),
      'action': action?.toMap(),
    };
  }

  factory AiChatMessage.fromMap(Map<String, dynamic> map) {
    List<AiAction> parsedActions = [];
    if (map['actions'] != null && map['actions'] is List) {
      parsedActions = (map['actions'] as List<dynamic>)
          .map((e) => AiAction.fromMap(e as Map<String, dynamic>))
          .toList();
    } else if (map['action'] != null) {
      parsedActions = [AiAction.fromMap(map['action'] as Map<String, dynamic>)];
    }

    return AiChatMessage(
      id: map['id'] as String?,
      content: map['content'] as String,
      isUser: (map['is_user'] as int?) == 1,
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      isError: (map['is_error'] as int?) == 1,
      suggestedFollowUps: (map['suggested_follow_ups'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      actions: parsedActions,
    );
  }
}
