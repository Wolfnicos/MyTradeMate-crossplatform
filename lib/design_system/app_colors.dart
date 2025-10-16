import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Core dark palette (neobrutalism-friendly)
  static const Color background = Color(0xFF0A0A0C); // Almost black
  static const Color surface = Color(0xFF131316); // Deep charcoal
  static const Color surfaceElevated = Color(0xFF1A1A1E);
  static const Color outline = Color(0xFF2E2E33); // Hard outline

  static const Color onBackground = Color(0xFFF5F5F7);
  static const Color onSurface = Color(0xFFE6E6EA);
  static const Color muted = Color(0xFFA0A0AA);

  // Core light palette (neobrutalism-friendly)
  static const Color lightBackground = Color(0xFFF7F8FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF1F5F9);
  static const Color lightOutline = Color(0xFF1F2937); // Hard dark outline on light
  static const Color lightOnBackground = Color(0xFF111827);
  static const Color lightOnSurface = Color(0xFF1F2937);
  static const Color lightMuted = Color(0xFF6B7280);

  // Accents (neon & premium)
  static const Color primary = Color(0xFF0A84FF); // Electric Blue
  static const Color primaryDeep = Color(0xFF0A3D91);
  static const Color secondary = Color(0xFF30D158); // Neon Green
  static const Color secondaryDeep = Color(0xFF0B5D2B);
  static const Color tertiary = Color(0xFFBF5AF2); // Magenta/Purple
  static const Color tertiaryDeep = Color(0xFF5B1A7C);

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF38BDF8);

  // Neon/glow tints for effects
  static const Color glowBlue = Color(0xFF3B82F6);
  static const Color glowPurple = Color(0xFF8B5CF6);
  static const Color glowPink = Color(0xFFEC4899);
  static const Color glowCyan = Color(0xFF22D3EE);
}


