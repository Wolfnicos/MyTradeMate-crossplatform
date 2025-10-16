import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static TextTheme darkTextTheme(BuildContext context) {
    final base = Theme.of(context).textTheme;
    final inter = GoogleFonts.interTextTheme(base);

    return inter.copyWith(
      displayLarge: inter.displayLarge?.copyWith(
        fontSize: 36,
        height: 1.1,
        fontWeight: FontWeight.w800,
        color: AppColors.onBackground,
        letterSpacing: -0.8,
        fontFamilyFallback: const ['Monument Extended'],
      ),
      displayMedium: inter.displayMedium?.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: AppColors.onBackground,
        letterSpacing: -0.6,
        fontFamilyFallback: const ['Monument Extended'],
      ),
      headlineLarge: inter.headlineLarge?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.onBackground,
        letterSpacing: -0.2,
      ),
      headlineMedium: inter.headlineMedium?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.onBackground,
      ),
      titleLarge: inter.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.onBackground,
      ),
      titleMedium: inter.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.muted,
      ),
      bodyLarge: inter.bodyLarge?.copyWith(
        fontSize: 16,
        color: AppColors.onSurface,
      ),
      bodyMedium: inter.bodyMedium?.copyWith(
        fontSize: 14,
        color: AppColors.muted,
      ),
      labelLarge: inter.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.onBackground,
        letterSpacing: 0.2,
      ),
    );
  }
}


