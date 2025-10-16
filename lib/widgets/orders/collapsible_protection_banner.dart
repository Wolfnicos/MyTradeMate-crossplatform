import 'package:flutter/material.dart';
import '../../design_system/widgets/glass_card.dart';
import '../../design_system/app_colors.dart';

class CollapsibleProtectionBanner extends StatefulWidget {
  final bool enabled;
  final double stopLossPct;
  final double takeProfitPct;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<double> onStopLossChanged;
  final ValueChanged<double> onTakeProfitChanged;

  const CollapsibleProtectionBanner({
    super.key,
    required this.enabled,
    required this.stopLossPct,
    required this.takeProfitPct,
    required this.onEnabledChanged,
    required this.onStopLossChanged,
    required this.onTakeProfitChanged,
  });

  @override
  State<CollapsibleProtectionBanner> createState() => _CollapsibleProtectionBannerState();
}

class _CollapsibleProtectionBannerState extends State<CollapsibleProtectionBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('Protection (OCO)', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Row(children: [Text(_expanded ? 'Hide' : 'Show'), const SizedBox(width: 4), Icon(_expanded ? Icons.expand_less : Icons.expand_more)]),
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable OCO protection'),
                  subtitle: Text('Place take-profit + stop-loss automatically', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.muted)),
                  value: widget.enabled,
                  onChanged: widget.onEnabledChanged,
                ),
                const SizedBox(height: 8),
                Text('Stop loss (%)', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.muted)),
                Slider(
                  value: widget.stopLossPct,
                  min: 0.5,
                  max: 20,
                  divisions: 39,
                  label: widget.stopLossPct.toStringAsFixed(1) + '%',
                  onChanged: widget.onStopLossChanged,
                ),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Text('0.5%'), Text('20%')]),
                const SizedBox(height: 8),
                Text('Take profit (%)', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.muted)),
                Slider(
                  value: widget.takeProfitPct,
                  min: 1,
                  max: 50,
                  divisions: 49,
                  label: widget.takeProfitPct.toStringAsFixed(0) + '%',
                  onChanged: widget.onTakeProfitChanged,
                ),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Text('1%'), Text('50%')]),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}


