import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/currencies.dart';

class SettingsProvider with ChangeNotifier {
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyCurrency = 'selected_currency';
  static const String _keyLocale = 'selected_locale';
  static const String _keyBiometrics = 'biometrics_enabled';
  static const String _keyFirstLaunch = 'is_first_launch';

  ThemeMode _themeMode = ThemeMode.system;
  String _currencyCode = 'USD';
  Locale _locale = const Locale('ar');
  bool _isBiometricsEnabled = false;
  bool _isFirstLaunch = true;
  bool _isLoading = true;

  ThemeMode get themeMode => _themeMode;
  String get currencyCode => _currencyCode;
  AppCurrency get currency => Currencies.getByCode(_currencyCode);
  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';
  bool get isBiometricsEnabled => _isBiometricsEnabled;
  bool get isFirstLaunch => _isFirstLaunch;
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

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode == ThemeMode.dark ? 'dark' : (mode == ThemeMode.light ? 'light' : 'system'));
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

  Future<void> completeFirstLaunch(String chosenCurrency) async {
    _currencyCode = chosenCurrency;
    _isFirstLaunch = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrency, chosenCurrency);
    await prefs.setBool(_keyFirstLaunch, false);
  }
}
