import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// AI Indicator Widget
///
/// Pulsating indicator showing AI model status and activity.
/// Features:
/// - Smooth pulsating animation
/// - Color-coded status (green = active, amber = loading, red = error)
/// - Lightweight (uses AnimatedContainer)
class AIIndicator extends StatefulWidget {
  final bool isActive;
  final bool isLoading;
  final String? label;
  final double size;

  const AIIndicator({
    super.key,
    this.isActive = false,
    this.isLoading = false,
    this.label,
    this.size = 12.0,
  });

  @override
  State<AIIndicator> createState() => _AIIndicatorState();
}

class _AIIndicatorState extends State<AIIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppTheme.animationSlow,
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Start pulsating animation if active or loading
    if (widget.isActive || widget.isLoading) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AIIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update animation based on status
    if ((widget.isActive || widget.isLoading) && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && !widget.isLoading && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _indicatorColor {
    if (widget.isLoading) return AppTheme.warning;
    if (widget.isActive) return AppTheme.success;
    return AppTheme.textDisabled;
  }

  @override
  Widget build(BuildContext context) {
    Widget indicator = AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _indicatorColor,
            boxShadow: (widget.isActive || widget.isLoading)
                ? [
                    BoxShadow(
                      color: _indicatorColor.withOpacity(_animation.value * 0.6),
                      blurRadius: widget.size * 0.8,
                      spreadRadius: widget.size * 0.2,
                    ),
                  ]
                : null,
          ),
        );
      },
    );

    // If label provided, show indicator with text
    if (widget.label != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          const SizedBox(width: AppTheme.spacing8),
          Text(
            widget.label!,
            style: AppTheme.bodySmall.copyWith(
              color: _indicatorColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return indicator;
  }
}

/// AI Status Badge
///
/// Shows AI model status with icon and text in a compact badge.
class AIStatusBadge extends StatelessWidget {
  final bool isActive;
  final String modelName;
  final double? confidence;

  const AIStatusBadge({
    super.key,
    required this.isActive,
    required this.modelName,
    this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing8,
      ),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.success.withOpacity(0.15)
            : AppTheme.textDisabled.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(
          color: isActive ? AppTheme.success : AppTheme.textDisabled,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AIIndicator(
            isActive: isActive,
            size: 10,
          ),
          const SizedBox(width: AppTheme.spacing8),
          Text(
            modelName,
            style: AppTheme.labelSmall.copyWith(
              color: isActive ? AppTheme.success : AppTheme.textDisabled,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (confidence != null && isActive) ...[
            const SizedBox(width: AppTheme.spacing4),
            Text(
              '${(confidence! * 100).toStringAsFixed(0)}%',
              style: AppTheme.labelSmall.copyWith(
                color: AppTheme.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
