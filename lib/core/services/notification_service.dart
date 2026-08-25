import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  NotificationService._init();

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open notification');

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {},
      );
      _isInitialized = true;
    } catch (_) {
      // Graceful fallback on platforms without notification support
    }
  }

  Future<void> requestPermissions() async {
    try {
      final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
    } catch (_) {}
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

  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required bool isArabic,
  }) async {
    // Show sample reminder or schedule
    await showNotification(
      id: 101,
      title: isArabic ? 'تذكير وفير اليومي 📝' : 'Waffeer Daily Reminder 📝',
      body: isArabic
          ? 'لا تنسَ تسجيل مصاريفك ومعاملاتك اليوم لتتبع ميزانيتك بدقة!'
          : "Don't forget to record your expenses today to keep track of your budget!",
    );
  }

  Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (_) {}
  }
}
