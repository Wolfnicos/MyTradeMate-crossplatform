import 'package:flutter/material.dart';
import '../../design_system/app_gradients.dart';

class PremiumButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final double borderRadius;

  const PremiumButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.height = 56,
    this.borderRadius = 16,
  });

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shineController;

  @override
  void initState() {
    super.initState();
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppGradients.primaryLinear(),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.5),
          boxShadow: const [
            BoxShadow(color: Color(0x660A84FF), blurRadius: 18, offset: Offset(0, 8)),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            onTap: widget.isLoading ? null : widget.onPressed,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
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
                              const SizedBox(width: 10),
                            ],
                            Text(
                              widget.label,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Colors.white,
                                  ),
                            ),
                          ],
                        ),
                ),
                AnimatedBuilder(
                  animation: _shineController,
                  builder: (context, child) {
                    final t = _shineController.value;
                    return Transform.translate(
                      offset: Offset(-200 + 400 * t, 0),
                      child: Transform.rotate(
                        angle: 0.35,
                        child: Container(
                          width: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withOpacity(0.0),
                                Colors.white.withOpacity(0.35),
                                Colors.white.withOpacity(0.0),
                              ],
                              stops: const [0.25, 0.5, 0.75],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


