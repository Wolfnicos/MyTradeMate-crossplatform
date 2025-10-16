import 'dart:ui';
import 'package:flutter/material.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/app_gradients.dart';
import '../../design_system/app_shadows.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool showNeobrutalShadow;
  final bool showGlow;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 20,
    this.showNeobrutalShadow = true,
    this.showGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shadows = <BoxShadow>[];
    if (showNeobrutalShadow) {
      shadows.add(
        BoxShadow(
          color: isDark ? const Color(0xFF0A0A0C) : Colors.black.withOpacity(0.12),
          offset: const Offset(6, 6),
          blurRadius: 0,
          spreadRadius: 0,
        ),
      );
    }
    if (showGlow) shadows.addAll(AppShadows.glowBlue);

    return Stack(
      children: [
        // Background glow/plasma
        if (isDark)
          Container(
            decoration: BoxDecoration(
              gradient: AppGradients.plasma(),
              borderRadius: BorderRadius.circular(borderRadius + 8),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                gradient: isDark
                    ? AppGradients.glassTint
                    : LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.85),
                          Colors.white.withOpacity(0.75),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.10),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(borderRadius),
                boxShadow: shadows,
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: isDark
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.06),
                            AppColors.surface.withOpacity(0.80),
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.95),
                            Colors.white.withOpacity(0.80),
                          ],
                        ),
                ),
                child: Padding(
                  padding: padding,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


