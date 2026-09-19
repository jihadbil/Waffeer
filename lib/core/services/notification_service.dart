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
  bool _initializationAttempted = false;

  NotificationService._init();

  Future<void> initialize() async {
    if (_isInitialized || _initializationAttempted) return;
    _initializationAttempted = true;

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
      _configureLocalTimezone();
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {},
      );
      _isInitialized = true;
    } catch (_) {
      // Graceful fallback on platforms without notification support
    }
  }

  void _configureLocalTimezone() {
    final nativeNow = DateTime.now();
    final direct = tz.timeZoneDatabase.locations[nativeNow.timeZoneName];
    if (direct != null) {
      tz.setLocalLocation(direct);
      return;
    }

    // Match the device's native offsets across the year. Several IANA zones
    // can share the same rules; any exact rule match schedules the same local
    // wall time, including daylight-saving transitions.
    final samples = <DateTime>[
      for (var month = 1; month <= 12; month++)
        DateTime(nativeNow.year, month, 15, 12),
    ];
    tz.Location? offsetMatch;
    for (final location in tz.timeZoneDatabase.locations.values) {
      final matches = samples.every(
        (sample) =>
            tz.TZDateTime(
              location,
              sample.year,
              sample.month,
              sample.day,
              sample.hour,
            ).timeZoneOffset ==
            sample.timeZoneOffset,
      );
      if (!matches) continue;
      offsetMatch ??= location;
      final abbreviation = tz.TZDateTime.from(
        nativeNow.toUtc(),
        location,
      ).timeZoneName;
      if (abbreviation == nativeNow.timeZoneName) {
        tz.setLocalLocation(location);
        return;
      }
    }
    if (offsetMatch != null) tz.setLocalLocation(offsetMatch);
  }

  Future<bool> requestPermissions() async {
    await initialize();
    if (!_isInitialized) return false;
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

  Future<bool> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize();
    if (!_isInitialized) return false;
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
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> scheduleDailyReminder({
    required int hour,
    required int minute,
    required bool isArabic,
    bool requestPermission = true,
  }) async {
    await initialize();
    if (!_isInitialized) return false;
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
    await initialize();
    if (!_isInitialized) return;
    try {
      await _notificationsPlugin.cancel(dailyReminderId);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    await initialize();
    if (!_isInitialized) return;
    try {
      await _notificationsPlugin.cancelAll();
    } catch (_) {}
  }

  Future<void> syncRoutineReminders(
    List<RoutineExpenseModel> routines, {
    required bool isArabic,
  }) async {
    await initialize();
    if (!_isInitialized) return;
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
          tz.TZDateTime.from(item.nextDueDate!, tz.local),
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
