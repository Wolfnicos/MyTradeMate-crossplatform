import 'package:flutter/material.dart';
import '../../design_system/widgets/glass_card.dart';
import '../../design_system/app_colors.dart';

class RiskSlidersCard extends StatefulWidget {
  final void Function(double positionPct, double stopLossPct)? onChanged;
  const RiskSlidersCard({super.key, this.onChanged});

  @override
  State<RiskSlidersCard> createState() => _RiskSlidersCardState();
}

class _RiskSlidersCardState extends State<RiskSlidersCard> {
  double _position = 10; // % of portfolio
  double _stop = 3; // % stop loss

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Risk', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('Position size', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.muted)),
          Slider(
            value: _position,
            min: 1,
            max: 50,
            divisions: 49,
            label: _position.toStringAsFixed(0) + '%',
            onChanged: (v) {
              setState(() => _position = v);
              widget.onChanged?.call(_position, _stop);
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1%'),
              Text('50%'),
            ],
          ),
          const SizedBox(height: 12),
          Text('Stop loss', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.muted)),
          Slider(
            value: _stop,
            min: 1,
            max: 20,
            divisions: 19,
            label: _stop.toStringAsFixed(0) + '%',
            onChanged: (v) {
              setState(() => _stop = v);
              widget.onChanged?.call(_position, _stop);
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1%'),
              Text('20%'),
            ],
          ),
        ],
      ),
    );
  }
}


