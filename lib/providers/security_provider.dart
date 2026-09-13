import 'package:flutter/foundation.dart';
import '../core/services/security_service.dart';

class SecurityProvider extends ChangeNotifier {
  final SecurityService _securityService = SecurityService();

  bool _isLocked = false;
  bool _isBiometricsEnabled = false;
  bool _isPinEnabled = false;
  bool _hasPin = false;
  bool _isInitialized = false;

  bool get isLocked => _isLocked;
  bool get isBiometricsEnabled => _isBiometricsEnabled;
  bool get isPinEnabled => _isPinEnabled;
  bool get hasPin => _hasPin;
  bool get isInitialized => _isInitialized;
  bool get isSecurityActive => _isPinEnabled || _isBiometricsEnabled;

  Future<void> initSecurity() async {
    _isPinEnabled = await _securityService.isPinEnabled();
    _isBiometricsEnabled = await _securityService.isBiometricsEnabled();
    _hasPin = await _securityService.hasPin();

    // Prevent lockout: biometrics requires a valid PIN as fallback
    if (_isBiometricsEnabled && !_hasPin) {
      _isBiometricsEnabled = false;
      await _securityService.setBiometricsEnabled(false);
    }

    if (isSecurityActive) {
      _isLocked = true;
    } else {
      _isLocked = false;
    }

    _isInitialized = true;
    notifyListeners();
  }

  void lockApp() {
    if (isSecurityActive) {
      _isLocked = true;
      notifyListeners();
    }
  }

  void unlock() {
    _isLocked = false;
    notifyListeners();
  }

  Future<bool> tryUnlockWithBiometrics(bool isArabic) async {
    if (!_isBiometricsEnabled) return false;
    final success = await _securityService.authenticateWithBiometrics(isArabic);
    if (success) {
      _isLocked = false;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> tryUnlockWithPin(String pin) async {
    final valid = await _securityService.verifyPin(pin);
    if (valid) {
      _isLocked = false;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> isLockedOut() => _securityService.isLockedOut();

  Future<int> getRemainingLockoutSeconds() =>
      _securityService.getRemainingLockoutSeconds();

  Future<void> setPin(String pin) async {
    await _securityService.savePin(pin);
    _hasPin = true;
    _isPinEnabled = true;
    notifyListeners();
  }

  Future<void> removePin() async {
    await _securityService.removePin();
    _hasPin = false;
    _isPinEnabled = false;
    if (_isBiometricsEnabled) {
      await _securityService.setBiometricsEnabled(false);
      _isBiometricsEnabled = false;
    }
    notifyListeners();
  }

  Future<bool> setBiometricsEnabled(bool enabled) async {
    if (enabled && !_hasPin) {
      return false;
    }
    await _securityService.setBiometricsEnabled(enabled);
    _isBiometricsEnabled = enabled;
    notifyListeners();
    return true;
  }

  Future<void> setPinEnabled(bool enabled) async {
    await _securityService.setPinEnabled(enabled);
    _isPinEnabled = enabled;
    notifyListeners();
  }
}
