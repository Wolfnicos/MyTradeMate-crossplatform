import 'package:flutter/material.dart';

/// Premium gradient card widget with glassmorphism effect
class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final List<Color>? gradientColors;
  final bool useGradient;
  final double borderRadius;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding,
    this.gradientColors,
    this.useGradient = false,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: useGradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors ??
                    (isDark
                        ? [
                            const Color(0xFF1C1C1E),
                            const Color(0xFF2C2C2E),
                          ]
                        : [
                            Colors.white,
                            const Color(0xFFF8F9FA),
                          ]),
              )
            : null,
        color: useGradient ? null : theme.cardColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.white.withOpacity(0.03)
                : Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(20),
        child: child,
      ),
    );
  }
}

/// Animated gradient button with shimmer effect
class GradientButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;
  final List<Color>? gradientColors;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.gradientColors,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: 1 - (_controller.value * 0.05),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.gradientColors ??
                      (isDark
                          ? [
                              const Color(0xFF0A84FF),
                              const Color(0xFF0066CC),
                            ]
                          : [
                              const Color(0xFF0066FF),
                              const Color(0xFF0052CC),
                            ]),
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (widget.gradientColors?.first ?? const Color(0xFF0066FF))
                        .withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: widget.isLoading ? null : widget.onPressed,
                  child: Center(
                    child: widget.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.icon != null) ...[
                                Icon(widget.icon, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                widget.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Signal indicator with animated glow effect
class SignalIndicator extends StatefulWidget {
  final String signal;
  final double confidence;

  const SignalIndicator({
    super.key,
    required this.signal,
    required this.confidence,
  });

  @override
  State<SignalIndicator> createState() => _SignalIndicatorState();
}

class _SignalIndicatorState extends State<SignalIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getSignalColor() {
    switch (widget.signal.toUpperCase()) {
      case 'BUY':
        return const Color(0xFF00C853);
      case 'SELL':
        return const Color(0xFFFF3B30);
      default:
        return const Color(0xFFFF9500);
    }
  }

  IconData _getSignalIcon() {
    switch (widget.signal.toUpperCase()) {
      case 'BUY':
        return Icons.trending_up_rounded;
      case 'SELL':
        return Icons.trending_down_rounded;
      default:
        return Icons.trending_flat_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final signalColor = _getSignalColor();

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 48),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                signalColor.withOpacity(0.1),
                signalColor.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: signalColor.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: signalColor.withOpacity(0.3 * _animation.value),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                _getSignalIcon(),
                size: 64,
                color: signalColor,
              ),
              const SizedBox(height: 16),
              Text(
                widget.signal.toUpperCase(),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: signalColor,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(widget.confidence * 100).toStringAsFixed(1)}% Confidence',
                style: TextStyle(
                  fontSize: 14,
                  color: signalColor.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
