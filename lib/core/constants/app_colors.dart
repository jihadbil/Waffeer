import 'package:flutter/material.dart';

class AppColors {
  // Brand & Accent Colors
  static const Color primary = Color(0xFF10B981); // Emerald Green
  static const Color primaryDark = Color(0xFF059669);
  static const Color primaryLight = Color(0xFFD1FAE5);

  static const Color secondary = Color(0xFF6366F1); // Indigo
  static const Color secondaryLight = Color(0xFFEEF2FF);

  // Financial Semantics
  static const Color income = Color(0xFF10B981); // Positive / Inflow
  static const Color expense = Color(0xFFEF4444); // Negative / Outflow
  static const Color transfer = Color(0xFF3B82F6); // Neutral / Transfer
  static const Color warning = Color(0xFFF59E0B); // Budget Alert / Warning
  static const Color info = Color(0xFF06B6D4);

  // Dark Theme Backgrounds & Surfaces
  static const Color darkBackground = Color(0xFF0F172A); // Slate 900
  static const Color darkSurface = Color(0xFF1E293B); // Slate 800
  static const Color darkCard = Color(0xFF24334A);
  static const Color darkBorder = Color(0xFF334155);

  // Light Theme Backgrounds & Surfaces
  static const Color lightBackground = Color(0xFFF8FAFC); // Slate 50
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient walletGradient1 = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
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
}
