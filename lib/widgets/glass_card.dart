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

    Widget content = ClipRRect(
      borderRadius: effectiveBorderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            gradient: AppTheme.glassGradient,
            color: color ?? AppTheme.glassWhite,
            borderRadius: effectiveBorderRadius,
            border: hasBorder
                ? Border.all(
                    color: AppTheme.glassBorder,
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
