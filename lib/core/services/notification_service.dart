import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/routine_expense_model.dart';

class NotificationService {
  static const int dailyReminderId = 101;
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  NotificationService._init();

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    try {
      timezone_data.initializeTimeZones();
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {},
      );
      _isInitialized = true;
    } catch (_) {
      // Graceful fallback on platforms without notification support
    }
  }

  Future<bool> requestPermissions() async {
    try {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImplementation != null) {
        return await androidImplementation.requestNotificationsPermission() ??
            false;
      }

      final iosImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (iosImplementation != null) {
        return await iosImplementation.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'waffeer_general_channel',
        'تنبيهات وفير العامة',
        channelDescription: 'قناة إشعارات وتنبيهات تطبيق وفير',
        importance: Importance.high,
        priority: Priority.high,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _notificationsPlugin.show(id, title, body, notificationDetails);
    } catch (_) {}
  }

  Future<bool> scheduleDailyReminder({
    required int hour,
    required int minute,
    required bool isArabic,
    bool requestPermission = true,
  }) async {
    if (requestPermission && !await requestPermissions()) return false;

    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (!scheduledDate.isAfter(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        'waffeer_daily_reminder',
        'تذكيرات تسجيل المصاريف',
        channelDescription: 'تذكير يومي اختياري لتسجيل الحركات المالية',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
      const darwinDetails = DarwinNotificationDetails();

      await _notificationsPlugin.cancel(dailyReminderId);
      await _notificationsPlugin.zonedSchedule(
        dailyReminderId,
        isArabic ? 'راجع يومك المالي' : 'Review your money today',
        isArabic
            ? 'سجّل أي مصروف فاتك لتبقى ميزانيتك دقيقة.'
            : 'Log any missing expense to keep your budget accurate.',
        scheduledDate,
        const NotificationDetails(
          android: androidDetails,
          iOS: darwinDetails,
          macOS: darwinDetails,
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return true;
    } catch (error) {
      if (kDebugMode) debugPrint('Daily reminder scheduling failed: $error');
      return false;
    }
  }

  Future<void> cancelDailyReminder() async {
    try {
      await _notificationsPlugin.cancel(dailyReminderId);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (_) {}
  }

  Future<void> syncRoutineReminders(
    List<RoutineExpenseModel> routines, {
    required bool isArabic,
  }) async {
    try {
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      for (final notification in pending.where(
        (n) => n.payload?.startsWith('routine:') ?? false,
      )) {
        await _notificationsPlugin.cancel(notification.id);
      }
      final future =
          routines
              .where(
                (r) =>
                    r.isActive &&
                    r.mode == RecordingMode.reminder &&
                    r.nextDueDate != null &&
                    r.nextDueDate!.isAfter(DateTime.now()),
              )
              .toList()
            ..sort((a, b) => a.nextDueDate!.compareTo(b.nextDueDate!));
      // Keep room for other notifications on platforms with a pending-request limit.
      for (var index = 0; index < future.length && index < 48; index++) {
        final item = future[index];
        await _notificationsPlugin.zonedSchedule(
          2000 + index,
          item.title,
          isArabic
              ? 'حان الموعد. افتح وفير لتأكيد التسجيل.'
              : 'Due now. Open Waffeer to confirm recording.',
          tz.TZDateTime.from(item.nextDueDate!.toUtc(), tz.UTC),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'waffeer_routines',
              'المعاملات المتكررة',
              importance: Importance.defaultImportance,
            ),
            iOS: DarwinNotificationDetails(),
            macOS: DarwinNotificationDetails(),
          ),
          payload: 'routine:${item.id}',
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.wallClockTime,
        );
      }
    } catch (error) {
      if (kDebugMode) debugPrint('Routine reminders unavailable: $error');
    }
  }
}
