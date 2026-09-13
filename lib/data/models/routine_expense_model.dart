import 'package:flutter/material.dart';

import '../../core/utils/material_icon_resolver.dart';
import 'transaction_model.dart';

enum RoutineFrequency { manual, daily, everyXDays, weekly, monthly, yearly }

enum RecordingMode { manual, reminder, automatic }

const _unchanged = Object();

class RoutineExpenseModel {
  final String id, title, categoryId, walletId, currencyCode;
  final double amount;
  final String? note, toWalletId;
  final int? iconCodePoint, colorValue, anchorDay, anchorMonth;
  final RecordingMode mode;
  final TransactionType type;
  final RoutineFrequency frequency;
  final int intervalDays, usageCount, scheduleVersion;
  final DateTime? nextDueDate, lastExecutedDate;
  final bool isActive;

  const RoutineExpenseModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.categoryId,
    required this.walletId,
    required this.currencyCode,
    this.note,
    this.toWalletId,
    this.iconCodePoint,
    this.colorValue,
    RecordingMode? mode,
    bool isAutoRecurring = false,
    this.type = TransactionType.expense,
    this.frequency = RoutineFrequency.manual,
    this.intervalDays = 2,
    this.nextDueDate,
    this.lastExecutedDate,
    this.usageCount = 0,
    this.isActive = true,
    this.anchorDay,
    this.anchorMonth,
    this.scheduleVersion = 0,
  }) : mode =
           mode ??
           (isAutoRecurring ? RecordingMode.automatic : RecordingMode.manual);

  bool get isAutoRecurring => mode == RecordingMode.automatic;
  bool get isScheduled => mode != RecordingMode.manual;
  IconData? get iconData => iconCodePoint == null
      ? null
      : MaterialIconResolver.resolve(iconCodePoint!);
  Color? get color => colorValue == null ? null : Color(colorValue!);

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'amount': amount,
    'category_id': categoryId,
    'wallet_id': walletId,
    'currency_code': currencyCode,
    'note': note,
    'to_wallet_id': toWalletId,
    'type': type.name,
    'icon_code_point': iconCodePoint,
    'color_value': colorValue,
    'recording_mode': mode.name,
    'is_auto_recurring': isAutoRecurring ? 1 : 0,
    'frequency': frequency.name,
    'interval_days': intervalDays,
    'next_due_date': nextDueDate?.toIso8601String(),
    'last_executed_date': lastExecutedDate?.toIso8601String(),
    'usage_count': usageCount,
    'is_active': isActive ? 1 : 0,
    'anchor_day': anchorDay ?? nextDueDate?.day,
    'anchor_month': anchorMonth ?? nextDueDate?.month,
    'schedule_version': scheduleVersion,
  };

  factory RoutineExpenseModel.fromMap(Map<String, dynamic> map) =>
      RoutineExpenseModel(
        id: map['id'] as String,
        title: map['title'] as String,
        amount: (map['amount'] as num).toDouble(),
        categoryId: map['category_id'] as String,
        walletId: map['wallet_id'] as String,
        currencyCode: map['currency_code'] as String,
        note: map['note'] as String?,
        toWalletId: map['to_wallet_id'] as String?,
        type: TransactionType.values.byName(
          map['type'] as String? ?? 'expense',
        ),
        mode: RecordingMode.values.byName(
          map['recording_mode'] as String? ??
              (map['is_auto_recurring'] == 1 ? 'automatic' : 'manual'),
        ),
        iconCodePoint: map['icon_code_point'] as int?,
        colorValue: map['color_value'] as int?,
        frequency: RoutineFrequency.values.byName(
          map['frequency'] as String? ?? 'manual',
        ),
        intervalDays: map['interval_days'] as int? ?? 2,
        nextDueDate: DateTime.tryParse(map['next_due_date'] as String? ?? ''),
        lastExecutedDate: DateTime.tryParse(
          map['last_executed_date'] as String? ?? '',
        ),
        usageCount: map['usage_count'] as int? ?? 0,
        isActive: map['is_active'] != 0,
        anchorDay: map['anchor_day'] as int?,
        anchorMonth: map['anchor_month'] as int?,
        scheduleVersion: map['schedule_version'] as int? ?? 0,
      );

  /// Old schedules required confirmation; migrating must never enable automatic recording.
  factory RoutineExpenseModel.fromLegacy(Map<String, dynamic> map) =>
      RoutineExpenseModel.fromMap({
        ...map,
        'id': 'legacy:${map['id']}',
        'recording_mode': 'reminder',
        'anchor_day': DateTime.tryParse(map['start_date'] as String? ?? '')
            ?.day,
        'anchor_month': DateTime.tryParse(map['start_date'] as String? ?? '')
            ?.month,
      });

  RoutineExpenseModel copyWith({
    String? id,
    String? title,
    double? amount,
    String? categoryId,
    String? walletId,
    String? currencyCode,
    Object? note = _unchanged,
    Object? toWalletId = _unchanged,
    int? iconCodePoint,
    int? colorValue,
    RecordingMode? mode,
    bool? isAutoRecurring,
    TransactionType? type,
    RoutineFrequency? frequency,
    int? intervalDays,
    Object? nextDueDate = _unchanged,
    Object? lastExecutedDate = _unchanged,
    int? usageCount,
    bool? isActive,
    int? anchorDay,
    int? anchorMonth,
    int? scheduleVersion,
  }) => RoutineExpenseModel(
    id: id ?? this.id,
    title: title ?? this.title,
    amount: amount ?? this.amount,
    categoryId: categoryId ?? this.categoryId,
    walletId: walletId ?? this.walletId,
    currencyCode: currencyCode ?? this.currencyCode,
    note: identical(note, _unchanged) ? this.note : note as String?,
    toWalletId: identical(toWalletId, _unchanged)
        ? this.toWalletId
        : toWalletId as String?,
    iconCodePoint: iconCodePoint ?? this.iconCodePoint,
    colorValue: colorValue ?? this.colorValue,
    mode:
        mode ??
        (isAutoRecurring == null
            ? this.mode
            : isAutoRecurring
            ? RecordingMode.automatic
            : RecordingMode.manual),
    type: type ?? this.type,
    frequency: frequency ?? this.frequency,
    intervalDays: intervalDays ?? this.intervalDays,
    nextDueDate: identical(nextDueDate, _unchanged)
        ? this.nextDueDate
        : nextDueDate as DateTime?,
    lastExecutedDate: identical(lastExecutedDate, _unchanged)
        ? this.lastExecutedDate
        : lastExecutedDate as DateTime?,
    usageCount: usageCount ?? this.usageCount,
    isActive: isActive ?? this.isActive,
    anchorDay: anchorDay ?? this.anchorDay,
    anchorMonth: anchorMonth ?? this.anchorMonth,
    scheduleVersion: scheduleVersion ?? this.scheduleVersion,
  );

  DateTime calculateNextDate(DateTime from) {
    switch (frequency) {
      case RoutineFrequency.manual:
        throw StateError('Manual entries have no schedule.');
      case RoutineFrequency.daily:
        return DateTime(
          from.year,
          from.month,
          from.day + 1,
          from.hour,
          from.minute,
        );
      case RoutineFrequency.everyXDays:
        if (intervalDays <= 0) throw StateError('Interval must be positive.');
        return DateTime(
          from.year,
          from.month,
          from.day + intervalDays,
          from.hour,
          from.minute,
        );
      case RoutineFrequency.weekly:
        return DateTime(
          from.year,
          from.month,
          from.day + 7,
          from.hour,
          from.minute,
        );
      case RoutineFrequency.monthly:
      case RoutineFrequency.yearly:
        final target = frequency == RoutineFrequency.monthly
            ? DateTime(from.year, from.month + 1)
            : DateTime(
                from.year + 1,
                anchorMonth ?? nextDueDate?.month ?? from.month,
              );
        final day = (anchorDay ?? nextDueDate?.day ?? from.day).clamp(
          1,
          DateTime(target.year, target.month + 1, 0).day,
        );
        return DateTime(target.year, target.month, day, from.hour, from.minute);
    }
  }

  String frequencyLabel(bool ar) => switch (frequency) {
    RoutineFrequency.manual => ar ? 'عند الطلب' : 'On demand',
    RoutineFrequency.daily => ar ? 'يومياً' : 'Daily',
    RoutineFrequency.everyXDays =>
      ar ? 'كل $intervalDays أيام' : 'Every $intervalDays days',
    RoutineFrequency.weekly => ar ? 'أسبوعياً' : 'Weekly',
    RoutineFrequency.monthly => ar ? 'شهرياً' : 'Monthly',
    RoutineFrequency.yearly => ar ? 'سنوياً' : 'Yearly',
  };

  String localizedFrequency(bool ar) {
    if (mode == RecordingMode.manual) {
      return ar ? 'نقرة واحدة (عند الطلب)' : '1-Tap (On-Demand)';
    }
    if (mode == RecordingMode.reminder) {
      return '${ar ? 'تذكير' : 'Reminder'} · ${frequencyLabel(ar)}';
    }
    if (!ar) {
      return frequency == RoutineFrequency.everyXDays
          ? 'Auto every $intervalDays days'
          : 'Auto ${frequencyLabel(ar)}';
    }
    return 'تلقائي ${frequencyLabel(ar)}';
  }
}
