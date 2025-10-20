import 'package:flutter/material.dart';
import '../design_system/app_colors.dart';

/// A simple, reusable widget for risk disclaimers.
class RiskDisclaimer extends StatelessWidget {
  const RiskDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final Color bg = colors.surfaceVariant.withOpacity(0.7);
    final Color fg = colors.onSurface.withOpacity(0.78);
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Past performance is not indicative of future results. All trading involves risk.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: fg),
      ),
    );
  }
}

