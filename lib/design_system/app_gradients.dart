import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppGradients {
  AppGradients._();

  static const Alignment topLeft = Alignment(-1, -1);
  static const Alignment bottomRight = Alignment(1, 1);

  static Gradient primaryLinear([double opacity = 1]) => LinearGradient(
        begin: topLeft,
        end: bottomRight,
        colors: [
          AppColors.primary.withOpacity(opacity),
          AppColors.tertiary.withOpacity(opacity),
        ],
      );

  static Gradient successLinear([double opacity = 1]) => LinearGradient(
        begin: topLeft,
        end: bottomRight,
        colors: [
          AppColors.secondary.withOpacity(opacity),
          AppColors.success.withOpacity(opacity),
        ],
      );

  static Gradient warningLinear([double opacity = 1]) => LinearGradient(
        begin: topLeft,
        end: bottomRight,
        colors: [
          AppColors.warning.withOpacity(opacity),
          AppColors.tertiary.withOpacity(opacity * 0.8),
        ],
      );

  static Gradient dangerLinear([double opacity = 1]) => LinearGradient(
        begin: topLeft,
        end: bottomRight,
        colors: [
          AppColors.danger.withOpacity(opacity),
          AppColors.glowPink.withOpacity(opacity * 0.9),
        ],
      );

  static Gradient plasma([double opacity = 1]) => const RadialGradient(
        center: Alignment(0.7, -0.6),
        radius: 1.2,
        colors: [
          Color(0x803B82F6), // semi blue
          Color(0x408B5CF6), // faint purple
          Color(0x4022D3EE), // faint cyan
          Color(0x20131316), // near-transparent surface
        ],
        stops: [0.0, 0.4, 0.7, 1.0],
      );

  static Gradient glassTint = LinearGradient(
    colors: [
      Colors.white.withOpacity(0.10),
      Colors.white.withOpacity(0.05),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}


