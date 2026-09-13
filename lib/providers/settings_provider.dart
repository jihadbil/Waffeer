import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/currencies.dart';
import '../core/services/notification_service.dart';

class SettingsProvider with ChangeNotifier {
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyCurrency = 'selected_currency';
  static const String _keyLocale = 'selected_locale';
  static const String _keyBiometrics = 'biometrics_enabled';
  static const String _keyFirstLaunch = 'is_first_launch';
  static const String _keyReminderEnabled = 'reminder_enabled';
  static const String _keyReminderHour = 'reminder_hour';
  static const String _keyReminderMinute = 'reminder_minute';
  static const String _keyAiApiKey = 'gemini_api_key';
  static const String _keyAiEnabled = 'ai_features_enabled';
  static const String defaultAiApiKey = '';

  ThemeMode _themeMode = ThemeMode.system;
  String _currencyCode = 'USD';
  Locale _locale = const Locale('ar');
  bool _isBiometricsEnabled = false;
  bool _isFirstLaunch = true;
  bool _isDailyReminderEnabled = false;
  int _reminderHour = 20; // 8:00 PM
  int _reminderMinute = 0;
  String _aiApiKey = defaultAiApiKey;
  bool _isAiEnabled = true;
  bool _isLoading = true;

  ThemeMode get themeMode => _themeMode;
  String get currencyCode => _currencyCode;
  AppCurrency get currency => Currencies.getByCode(_currencyCode);
  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';
  bool get isBiometricsEnabled => _isBiometricsEnabled;
  bool get isFirstLaunch => _isFirstLaunch;
  bool get isDailyReminderEnabled => _isDailyReminderEnabled;
  int get reminderHour => _reminderHour;
  int get reminderMinute => _reminderMinute;
  String get aiApiKey => _aiApiKey;
  bool get isAiEnabled => _isAiEnabled;
  bool get isLoading => _isLoading;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Theme
    final themeStr = prefs.getString(_keyThemeMode);
    if (themeStr == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (themeStr == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.system;
    }

    // Currency
    _currencyCode = prefs.getString(_keyCurrency) ?? 'USD';

    // Locale
    final langCode = prefs.getString(_keyLocale) ?? 'ar';
    _locale = Locale(langCode);

    // Biometrics
    _isBiometricsEnabled = prefs.getBool(_keyBiometrics) ?? false;

    // First Launch
    _isFirstLaunch = prefs.getBool(_keyFirstLaunch) ?? true;

    // Daily Reminder
    _isDailyReminderEnabled = prefs.getBool(_keyReminderEnabled) ?? false;
    _reminderHour = prefs.getInt(_keyReminderHour) ?? 20;
    _reminderMinute = prefs.getInt(_keyReminderMinute) ?? 0;

    // Refresh the next occurrence whenever the app starts. This keeps an
    // already-approved reminder aligned with the device's current wall time
    // without prompting for permission again.
    if (_isDailyReminderEnabled) {
      await NotificationService.instance.scheduleDailyReminder(
        hour: _reminderHour,
        minute: _reminderMinute,
        isArabic: isArabic,
        requestPermission: false,
      );
    }

    // AI Settings
    _aiApiKey = prefs.getString(_keyAiApiKey) ?? defaultAiApiKey;
    _isAiEnabled = prefs.getBool(_keyAiEnabled) ?? true;

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyThemeMode,
      mode == ThemeMode.dark
          ? 'dark'
          : (mode == ThemeMode.light ? 'light' : 'system'),
    );
  }

  Future<void> setCurrency(String code) async {
    _currencyCode = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrency, code);
  }

  Future<void> setLocale(Locale loc) async {
    _locale = loc;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, loc.languageCode);
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    _isBiometricsEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometrics, enabled);
  }

  Future<bool> setDailyReminderEnabled(bool enabled) async {
    if (enabled) {
      final scheduled = await NotificationService.instance
          .scheduleDailyReminder(
            hour: _reminderHour,
            minute: _reminderMinute,
            isArabic: isArabic,
          );
      if (!scheduled) return false;
    } else {
      await NotificationService.instance.cancelDailyReminder();
    }

    _isDailyReminderEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyReminderEnabled, enabled);
    return true;
  }

  Future<void> setReminderTime(int hour, int minute) async {
    _reminderHour = hour;
    _reminderMinute = minute;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReminderHour, hour);
    await prefs.setInt(_keyReminderMinute, minute);

    if (_isDailyReminderEnabled) {
      await NotificationService.instance.scheduleDailyReminder(
        hour: hour,
        minute: minute,
        isArabic: isArabic,
      );
    }
  }

  Future<void> completeFirstLaunch(String chosenCurrency) async {
    _currencyCode = chosenCurrency;
    _isFirstLaunch = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrency, chosenCurrency);
    await prefs.setBool(_keyFirstLaunch, false);
  }

  Future<void> setAiApiKey(String key) async {
    _aiApiKey = key.trim();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAiApiKey, _aiApiKey);
  }

  Future<void> setAiEnabled(bool enabled) async {
    _isAiEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAiEnabled, enabled);
  }
}
