import 'package:flutter/material.dart';

/// Centralized color palette for MyAppliance application.
/// Visual style inspired by modern premium mobile apps (clean, light, blue primary).
class AppColors {
  // Primary brand colors
  static const Color primaryBlue = Color(0xFF246BFD);
  static const Color primaryBlueLight = Color(0xFFEFF4FF);
  static const Color primaryBlueDark = Color(0xFF1952C8);

  // Background and surface colors
  static const Color background = Color(0xFFF8F9FE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardColor = Color(0xFFFFFFFF);

  // Text colors
  static const Color darkText = Color(0xFF111827);
  static const Color secondaryText = Color(0xFF64748B);
  static const Color mutedText = Color(0xFF94A3B8);

  // Supporting accent colors
  static const Color lightBlue = Color(0xFFEBF2FE);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color inputBackground = Color(0xFFFAFAFC);
  static const Color dividerColor = Color(0xFFF1F5F9);

  // Status colors
  static const Color error = Color(0xFFF04438);
  static const Color success = Color(0xFF12B76A);
  static const Color warning = Color(0xFFF79009);

  // Shadow colors
  static Color shadowColor = const Color(0xFF0F172A).withValues(alpha: 0.06);
}
