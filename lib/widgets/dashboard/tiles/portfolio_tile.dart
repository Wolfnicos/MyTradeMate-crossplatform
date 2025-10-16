import 'package:flutter/material.dart';
import '../../../design_system/widgets/glass_card.dart';
import '../../charts/portfolio_donut_chart.dart';

class PortfolioTile extends StatelessWidget {
  const PortfolioTile({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slices = <PortfolioSlice>[
      PortfolioSlice(label: 'BTC', value: 50, color: theme.colorScheme.primary),
      PortfolioSlice(label: 'ETH', value: 25, color: theme.colorScheme.secondary),
      PortfolioSlice(label: 'BNB', value: 15, color: theme.colorScheme.tertiary),
      PortfolioSlice(label: 'SOL', value: 10, color: Colors.purpleAccent),
    ];

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Portfolio', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Center(child: PortfolioDonutChart(slices: slices, size: 160)),
        ],
      ),
    );
  }
}


