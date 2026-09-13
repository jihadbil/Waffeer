import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF126044);
  static const Color primaryDark = Color(0xFF154D39);
  static const Color primaryLight = Color(0xFFE4F3EB);
  static const Color primaryGlow = Color(0x33047857);

  static const Color secondary = Color(0xFF427563);
  static const Color secondaryDark = Color(0xFF315C4C);
  static const Color secondaryLight = Color(0xFFEAF1ED);

  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentCyan = Color(0xFF06B6D4);

  static const Color income = Color(0xFF126044);
  static const Color incomeLight = Color(0xFFDCFCE7);

  static const Color expense = Color(0xFFBE123C);
  static const Color expenseDark = Color(0xFF9F1239);
  static const Color expenseLight = Color(0xFFFFE4E6);

  static const Color transfer = Color(0xFF3B82F6);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color info = Color(0xFF06B6D4);

  static const Color darkBackground = Color(0xFF10221E);
  static const Color darkSurface = Color(0xFF1A302A);
  static const Color darkCard = Color(0xFF1A302A);
  static const Color darkCardElevated = Color(0xFF244B3B);
  static const Color darkBorder = Color(0xFF355045);
  static const Color darkBorderSubtle = Color(0xFF2B4438);

  static const Color lightBackground = Color(0xFFF5F8F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardElevated = Color(0xFFEAF1ED);
  static const Color lightBorder = Color(0xFFDCE7E1);
  static const Color lightBorderSubtle = Color(0xFFE8EFEA);

  static const Color textDarkPrimary = Color(0xFFF5F8F7);
  static const Color textDarkSecondary = Color(0xFFB3C7BD);
  static const Color textDarkMuted = Color(0xFF71877B);

  static const Color textLightPrimary = Color(0xFF163C30);
  static const Color textLightSecondary = Color(0xFF596D65);
  static const Color textLightMuted = Color(0xFF71877B);

  static const LinearGradient luxuryCardGradient = LinearGradient(
    colors: [Color(0xFF154D39), Color(0xFF154D39), Color(0xFF154D39)],
    stops: [0.0, 0.6, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [primary, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient expenseGradient = LinearGradient(
    colors: [expense, expense],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassCardGradient = LinearGradient(
    colors: [Color(0x20FFFFFF), Color(0x08FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient walletGradient1 = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF427563)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient walletGradient2 = LinearGradient(
    colors: [Color(0xFFEC4899), Color(0xFFD946EF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient walletGradient3 = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient walletGradient4 = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF0284C7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = emeraldGradient;
  static const LinearGradient cardGradient = luxuryCardGradient;
}
