import 'package:flutter/material.dart';

import '../../core/utils/material_icon_resolver.dart';

class GoalModel {
  final String id;
  final String title;
  final double targetAmount;
  final double savedAmount;
  final DateTime targetDate;
  final String currencyCode;
  final int iconCodePoint;
  final String? iconFontFamily;
  final int colorValue;
  final String? note;
  final bool isCompleted;

  const GoalModel({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.savedAmount,
    required this.targetDate,
    required this.currencyCode,
    required this.iconCodePoint,
    this.iconFontFamily,
    required this.colorValue,
    this.note,
    this.isCompleted = false,
  });

  double get progressPercentage {
    if (targetAmount <= 0) return 0.0;
    final p = savedAmount / targetAmount;
    return p.clamp(0.0, 1.0);
  }

  double get remainingAmount {
    final diff = targetAmount - savedAmount;
    return diff > 0 ? diff : 0;
  }

  IconData get iconData => MaterialIconResolver.resolve(
    iconCodePoint,
    fallback: Icons.track_changes_rounded,
  );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'target_amount': targetAmount,
      'saved_amount': savedAmount,
      'target_date': targetDate.toIso8601String(),
      'currency_code': currencyCode,
      'icon_code_point': iconCodePoint,
      'icon_font_family': iconFontFamily,
      'color_value': colorValue,
      'note': note,
      'is_completed': isCompleted ? 1 : 0,
    };
  }

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    return GoalModel(
      id: map['id'] as String,
      title: map['title'] as String,
      targetAmount: (map['target_amount'] as num).toDouble(),
      savedAmount: (map['saved_amount'] as num).toDouble(),
      targetDate: DateTime.parse(map['target_date'] as String),
      currencyCode: map['currency_code'] as String,
      iconCodePoint: map['icon_code_point'] as int,
      iconFontFamily: map['icon_font_family'] as String?,
      colorValue: map['color_value'] as int,
      note: map['note'] as String?,
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
    );
  }

  GoalModel copyWith({
    String? id,
    String? title,
    double? targetAmount,
    double? savedAmount,
    DateTime? targetDate,
    String? currencyCode,
    int? iconCodePoint,
    String? iconFontFamily,
    int? colorValue,
    String? note,
    bool? isCompleted,
  }) {
    return GoalModel(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      targetDate: targetDate ?? this.targetDate,
      currencyCode: currencyCode ?? this.currencyCode,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      colorValue: colorValue ?? this.colorValue,
      note: note ?? this.note,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
