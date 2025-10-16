import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppShadows {
  AppShadows._();

  // Neobrutal: hard offset, minimal blur
  static List<BoxShadow> neobrutal = const [
    BoxShadow(
      color: Color(0xFF0A0A0C),
      offset: Offset(6, 6),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> glowBlue = [
    BoxShadow(
      color: AppColors.glowBlue.withOpacity(0.45),
      blurRadius: 24,
      spreadRadius: 2,
    ),
  ];

  static List<BoxShadow> subtle = [
    BoxShadow(
      color: Colors.black.withOpacity(0.25),
      blurRadius: 12,
      offset: const Offset(0, 6),
    ),
  ];
}


