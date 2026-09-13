import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/security_provider.dart';
import '../../../providers/settings_provider.dart';

enum LockMode { unlock, setupPin }

class LockScreen extends StatefulWidget {
  final LockMode mode;
  final VoidCallback? onUnlocked;

  const LockScreen({super.key, this.mode = LockMode.unlock, this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _enteredPin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String _errorMessage = '';
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    if (widget.mode == LockMode.unlock) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryBiometrics();
        _checkLockout();
      });
    }
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLockout() async {
    final secProvider = context.read<SecurityProvider>();
    final remaining = await secProvider.getRemainingLockoutSeconds();
    if (remaining > 0 && mounted) {
      setState(() {
        _lockoutSeconds = remaining;
        _errorMessage = context.read<SettingsProvider>().isArabic
            ? 'تم حظر المحاولات مؤقتاً. يرجى الانتظار $_lockoutSeconds ثانية.'
            : 'Too many failed attempts. Try again in $_lockoutSeconds s.';
      });
      _startLockoutTimer();
    }
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_lockoutSeconds > 1) {
          _lockoutSeconds--;
          _errorMessage = context.read<SettingsProvider>().isArabic
              ? 'تم حظر المحاولات مؤقتاً. يرجى الانتظار $_lockoutSeconds ثانية.'
              : 'Too many failed attempts. Try again in $_lockoutSeconds s.';
        } else {
          _lockoutSeconds = 0;
          _errorMessage = '';
          timer.cancel();
        }
      });
    });
  }

  Future<void> _tryBiometrics() async {
    final secProvider = context.read<SecurityProvider>();
    final settings = context.read<SettingsProvider>();
    if (secProvider.isBiometricsEnabled) {
      final success = await secProvider.tryUnlockWithBiometrics(
        settings.isArabic,
      );
      if (success && mounted) {
        widget.onUnlocked?.call();
      }
    }
  }

  void _onKeyPress(String val) {
    if (_lockoutSeconds > 0) return;
    if (_enteredPin.length < 4) {
      HapticFeedback.lightImpact();
      setState(() {
        _enteredPin += val;
        _errorMessage = '';
      });

      if (_enteredPin.length == 4) {
        _handlePinComplete();
      }
    }
  }

  void _onBackspace() {
    if (_lockoutSeconds > 0) return;
    if (_enteredPin.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = '';
      });
    }
  }

  Future<void> _handlePinComplete() async {
    // Delay slightly to let the 4th dot complete its fill animation
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    final secProvider = context.read<SecurityProvider>();
    final settings = context.read<SettingsProvider>();
    final isArabic = settings.isArabic;

    if (widget.mode == LockMode.unlock) {
      final success = await secProvider.tryUnlockWithPin(_enteredPin);
      if (success) {
        HapticFeedback.mediumImpact();
        if (mounted) {
          widget.onUnlocked?.call();
        }
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _enteredPin = '';
        });
        await _checkLockout();
        if (_lockoutSeconds == 0 && mounted) {
          setState(() {
            _errorMessage = isArabic ? 'رمز PIN غير صحيح!' : 'Incorrect PIN!';
          });
        }
      }
    } else {
      // Setup PIN mode
      if (!_isConfirming) {
        setState(() {
          _confirmPin = _enteredPin;
          _enteredPin = '';
          _isConfirming = true;
        });
      } else {
        if (_enteredPin == _confirmPin) {
          await secProvider.setPin(_enteredPin);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isArabic ? 'تم تفعيل رمز PIN بنجاح' : 'PIN setup successful',
                ),
                backgroundColor: AppColors.income,
              ),
            );
            Navigator.pop(context);
          }
        } else {
          HapticFeedback.heavyImpact();
          setState(() {
            _errorMessage = isArabic
                ? 'الرمزان غير متطابقين، حاول مجدداً'
                : 'PINs do not match, try again';
            _enteredPin = '';
            _confirmPin = '';
            _isConfirming = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final secProvider = context.watch<SecurityProvider>();
    final isArabic = settings.isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String promptText;
    if (widget.mode == LockMode.unlock) {
      promptText = isArabic
          ? 'أدخل رمز PIN لفتح التطبيق'
          : 'Enter PIN to unlock Waffeer';
    } else {
      promptText = _isConfirming
          ? (isArabic ? 'تأكيد رمز PIN الجديد' : 'Confirm new PIN')
          : (isArabic
                ? 'أدخل رمز PIN جديد (4 أرقام)'
                : 'Enter new 4-digit PIN');
    }

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // App Logo / Lock Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                isArabic ? 'وفير • الحماية والخصوصية' : 'Waffeer • App Lock',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),

              // Prompt
              Text(
                promptText,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 24),

              // 4 Dots Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < _enteredPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isFilled ? AppColors.primary : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isFilled
                            ? AppColors.primary
                            : (isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder),
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 14),

              // Error message
              if (_errorMessage.isNotEmpty)
                Text(
                  _errorMessage,
                  style: const TextStyle(
                    color: AppColors.expense,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                )
              else
                const SizedBox(height: 18),

              const Spacer(flex: 1),

              // Numeric Keypad
              _buildKeypad(context, secProvider, isArabic),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(
    BuildContext context,
    SecurityProvider secProvider,
    bool isArabic,
  ) {
    return Column(
      children: [
        _buildKeyRow(['1', '2', '3']),
        const SizedBox(height: 16),
        _buildKeyRow(['4', '5', '6']),
        const SizedBox(height: 16),
        _buildKeyRow(['7', '8', '9']),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Biometric button (if available) or Cancel
            if (widget.mode == LockMode.unlock &&
                secProvider.isBiometricsEnabled)
              _buildActionButton(
                icon: Icons.fingerprint_rounded,
                onTap: _tryBiometrics,
                color: AppColors.primary,
              )
            else if (widget.mode == LockMode.setupPin)
              _buildActionButton(
                icon: Icons.close_rounded,
                onTap: () => Navigator.pop(context),
              )
            else
              const SizedBox(width: 72, height: 72),

            // Number 0
            _buildNumberButton('0'),

            // Backspace button
            _buildActionButton(
              icon: Icons.backspace_outlined,
              onTap: _onBackspace,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((k) => _buildNumberButton(k)).toList(),
    );
  }

  Widget _buildNumberButton(String number) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => _onKeyPress(number),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(36),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Center(
          child: Icon(
            icon,
            size: 28,
            color: color ?? Theme.of(context).iconTheme.color,
          ),
        ),
      ),
    );
  }
}
