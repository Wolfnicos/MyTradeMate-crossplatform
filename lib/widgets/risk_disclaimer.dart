import 'package:flutter/material.dart';

/// A simple, reusable widget for risk disclaimers.
class RiskDisclaimer extends StatelessWidget {
  const RiskDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    final Color bg = Theme.of(context).colorScheme.onSurface.withOpacity(0.05);
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Past performance is not indicative of future results. All trading involves risk.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }
}

