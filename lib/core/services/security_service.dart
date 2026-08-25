import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static const String _keyPin = 'security_pin_code';
  static const String _keyIsPinEnabled = 'is_pin_enabled';
  static const String _keyIsBiometricsEnabled = 'is_biometrics_enabled';

  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> canCheckBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck || isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics(bool isArabic) async {
    try {
      final canCheck = await canCheckBiometrics();
      if (!canCheck) return false;

      return await _localAuth.authenticate(
        localizedReason: isArabic
            ? 'يرجى المصادقة بالبصمة لفتح تطبيق وفير'
            : 'Please authenticate with biometrics to unlock Waffeer',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> isPinEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsPinEnabled) ?? false;
  }

  Future<void> setPinEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsPinEnabled, enabled);
  }

  Future<bool> isBiometricsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsBiometricsEnabled) ?? false;
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsBiometricsEnabled, enabled);
  }

  Future<String?> getSavedPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPin);
  }

  Future<bool> hasPin() async {
    final pin = await getSavedPin();
    return pin != null && pin.isNotEmpty;
  }

  Future<void> savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPin, pin);
    await prefs.setBool(_keyIsPinEnabled, true);
  }

  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPin);
    await prefs.setBool(_keyIsPinEnabled, false);
  }

  Future<bool> verifyPin(String enteredPin) async {
    final savedPin = await getSavedPin();
    return savedPin != null && savedPin == enteredPin;
  }

  Future<bool> isAppLocked() async {
    final pinEnabled = await isPinEnabled();
    final bioEnabled = await isBiometricsEnabled();
    return pinEnabled || bioEnabled;
  }
}
