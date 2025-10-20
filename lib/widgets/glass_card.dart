import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Glassmorphism Card Widget
///
/// Features:
/// - Backdrop blur effect
/// - Subtle gradient background
/// - Border highlight
/// - Smooth shadows
/// - Performance optimized with const constructor
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final Color? color;
  final bool hasBorder;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.borderRadius,
    this.onTap,
    this.color,
    this.hasBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(AppTheme.radiusLG);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final LinearGradient effectiveGradient = isDark
        ? AppTheme.glassGradient
        : const LinearGradient(
            colors: [Color(0x33000000), Color(0x1A000000)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final Color effectiveFill = color ?? (isDark ? AppTheme.glassWhite : const Color(0x40000000));
    final Color effectiveBorderColor = isDark ? AppTheme.glassBorder : const Color(0x40000000);

    Widget content = ClipRRect(
      borderRadius: effectiveBorderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            gradient: effectiveGradient,
            color: effectiveFill,
            borderRadius: effectiveBorderRadius,
            border: hasBorder
                ? Border.all(
                    color: effectiveBorderColor,
                    width: 1,
                  )
                : null,
            boxShadow: AppTheme.glassShadow,
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: effectiveBorderRadius,
        child: content,
      );
    }

    return content;
  }
}
