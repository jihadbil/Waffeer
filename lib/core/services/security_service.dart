import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static const String _keyPin = 'security_pin_code';
  static const String _keyIsPinEnabled = 'is_pin_enabled';
  static const String _keyIsBiometricsEnabled = 'is_biometrics_enabled';
  static const String _keyFailedAttempts = 'security_failed_pin_attempts';
  static const String _keyLockoutUntil = 'security_lockout_until_timestamp';
  static const String _salt = 'waffeer_security_salt_v2_';

  static const int maxFailedAttempts = 5;
  static const int lockoutDurationSeconds = 30;

  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Hashes a PIN with a static salt using SHA-256
  static String hashPin(String pin) {
    final bytes = utf8.encode('$_salt$pin');
    return sha256.convert(bytes).toString();
  }

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
    // Save hashed PIN instead of plaintext
    await prefs.setString(_keyPin, hashPin(pin));
    await prefs.setBool(_keyIsPinEnabled, true);
    await resetFailedAttempts();
  }

  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPin);
    await prefs.setBool(_keyIsPinEnabled, false);
    await resetFailedAttempts();
  }

  Future<bool> verifyPin(String enteredPin) async {
    if (await isLockedOut()) return false;

    final savedPin = await getSavedPin();
    if (savedPin == null) return false;

    // Check hashed PIN
    if (savedPin == hashPin(enteredPin)) {
      await resetFailedAttempts();
      return true;
    }

    // Migration fallback for existing plaintext PIN
    if (savedPin == enteredPin) {
      // Auto-migrate to secure hash
      await savePin(enteredPin);
      await resetFailedAttempts();
      return true;
    }

    await recordFailedAttempt();
    return false;
  }

  Future<int> getRemainingLockoutSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final untilMs = prefs.getInt(_keyLockoutUntil) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (untilMs > nowMs) {
      return ((untilMs - nowMs) / 1000).ceil();
    }
    return 0;
  }

  Future<bool> isLockedOut() async {
    return (await getRemainingLockoutSeconds()) > 0;
  }

  Future<void> recordFailedAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    final attempts = (prefs.getInt(_keyFailedAttempts) ?? 0) + 1;
    await prefs.setInt(_keyFailedAttempts, attempts);
    if (attempts >= maxFailedAttempts) {
      final lockoutUntil =
          DateTime.now().millisecondsSinceEpoch + (lockoutDurationSeconds * 1000);
      await prefs.setInt(_keyLockoutUntil, lockoutUntil);
    }
  }

  Future<void> resetFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFailedAttempts);
    await prefs.remove(_keyLockoutUntil);
  }

  Future<bool> isAppLocked() async {
    final pinEnabled = await isPinEnabled();
    final bioEnabled = await isBiometricsEnabled();
    return pinEnabled || bioEnabled;
  }
}
