import 'package:flutter/material.dart';
import 'app_colors.dart';

class ScreenBackgrounds {
  ScreenBackgrounds._();

  static BoxDecoration dashboard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                AppColors.glowPurple.withOpacity(0.12),
                AppColors.background,
              ]
            : [
                const Color(0xFFE0F2FF),
                AppColors.lightBackground,
              ],
      ),
    );
  }

  static BoxDecoration market(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: isDark
            ? [
                AppColors.glowCyan.withOpacity(0.12),
                AppColors.background,
              ]
            : [
                const Color(0xFFDFFAFE),
                AppColors.lightBackground,
              ],
      ),
    );
  }

  static BoxDecoration ai(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                AppColors.glowPink.withOpacity(0.10),
                AppColors.background,
              ]
            : [
                const Color(0xFFFCE7F3),
                AppColors.lightBackground,
              ],
      ),
    );
  }

  static BoxDecoration orders(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                AppColors.glowBlue.withOpacity(0.08),
                AppColors.background,
              ]
            : [
                const Color(0xFFEFF6FF),
                AppColors.lightBackground,
              ],
      ),
    );
  }

  static BoxDecoration portfolio(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: isDark
            ? [
                AppColors.glowPurple.withOpacity(0.10),
                AppColors.background,
              ]
            : [
                const Color(0xFFEDE9FE),
                AppColors.lightBackground,
              ],
      ),
    );
  }

  static BoxDecoration settings(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                AppColors.glowBlue.withOpacity(0.10),
                AppColors.background,
              ]
            : [
                const Color(0xFFEFF6FF),
                AppColors.lightBackground,
              ],
      ),
    );
  }
}


