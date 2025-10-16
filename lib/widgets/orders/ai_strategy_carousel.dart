import 'package:flutter/material.dart';
import '../../design_system/widgets/glass_card.dart';
import '../../services/hybrid_strategies_service.dart';
import '../../design_system/app_colors.dart';

class AiStrategyCarousel extends StatelessWidget {
  final List<HybridStrategy> strategies;
  final void Function(HybridStrategy) onSelect;
  const AiStrategyCarousel({super.key, required this.strategies, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: strategies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final s = strategies[i];
          return SizedBox(
            width: 180,
            child: InkWell(
              onTap: () => onSelect(s),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(s.version, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.muted)),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(s.totalReturn >= 0 ? Icons.arrow_upward : Icons.arrow_downward, size: 16, color: s.totalReturn >= 0 ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.error),
                        const SizedBox(width: 6),
                        Expanded(child: Text((s.totalReturn >= 0 ? '+' : '') + s.totalReturn.toStringAsFixed(1) + '%', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                        const Spacer(),
                        Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
                      ],
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}


