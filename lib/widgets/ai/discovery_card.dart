import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../design_system/widgets/glass_card.dart';
import '../../design_system/app_colors.dart';
import '../../services/hybrid_strategies_service.dart';

class DiscoveryCard extends StatelessWidget {
  final HybridStrategy strategy;
  final VoidCallback onActivate;
  final List<String> markets; // e.g., ['BTC', 'WLFI', 'TRUMP']

  const DiscoveryCard({super.key, required this.strategy, required this.onActivate, this.markets = const <String>['BTC','WLFI','TRUMP']});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final perf = strategy.getPerformance();
    final double totalReturn = (perf['totalReturn'] as num?)?.toDouble() ?? 0.0;
    final int trades = (perf['tradesCount'] as num?)?.toInt() ?? 0;
    final double winRate = (perf['winRate'] as num?)?.toDouble() ?? 0.0;
    final double risk = _estimateRisk(totalReturn, trades); // 0..1

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strategy.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(strategy.version, style: theme.textTheme.titleMedium?.copyWith(color: AppColors.muted)),
              const SizedBox(height: 8),
              _MarketChips(markets: markets),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: _RiskGauge(value: risk),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: _RoiSparkline(totalReturn: totalReturn),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              _MetricTile(label: 'Return (7D est.)', value: '${totalReturn >= 0 ? '+' : ''}${totalReturn.toStringAsFixed(1)}%', isGain: totalReturn >= 0),
              _MetricTile(label: 'Win rate', value: '${(winRate * 100).toStringAsFixed(0)}%', isGain: true),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(onPressed: () => _openDetails(context, perf, risk), child: const Text('Details')),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(onPressed: onActivate, icon: const Icon(Icons.flash_on), label: const Text('Activate')),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }

  void _openDetails(BuildContext context, Map<String, dynamic> perf, double risk) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              top: 8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strategy.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Version ${strategy.version}', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.muted)),
                const SizedBox(height: 16),
                _RiskGauge(value: risk, compact: false),
                const SizedBox(height: 16),
                _DetailsMetrics(perf: perf),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(onPressed: () { Navigator.pop(context); onActivate(); }, icon: const Icon(Icons.flash_on), label: const Text('Activate strategy')),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  static double _estimateRisk(double totalReturn, int trades) {
    // Heuristic: lower returns and higher trades => higher risk; clamp 0..1
    double base = 0.5;
    base += (-totalReturn / 100.0).clamp(-0.3, 0.3);
    base += (trades > 0 ? (trades / 100.0) : 0.0).clamp(0.0, 0.3);
    return base.clamp(0.05, 0.95);
  }
}

class _MarketChips extends StatelessWidget {
  final List<String> markets;
  const _MarketChips({required this.markets});

  IconData _iconFor(String m) {
    switch (m.toUpperCase()) {
      case 'BTC':
        return Icons.currency_bitcoin;
      case 'WLFI':
        return Icons.token;
      case 'TRUMP':
        return Icons.rocket_launch;
      default:
        return Icons.show_chart;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: markets.map((m) {
        return Chip(
          label: Text(m),
          avatar: Icon(_iconFor(m), size: 16),
          visualDensity: VisualDensity.compact,
        );
      }).toList(growable: false),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final bool isGain;
  const _MetricTile({required this.label, required this.value, required this.isGain});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isGain ? theme.colorScheme.secondary : theme.colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleMedium?.copyWith(color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _RiskGauge extends StatelessWidget {
  final double value; // 0..1
  final bool compact;
  const _RiskGauge({required this.value, this.compact = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color track = theme.brightness == Brightness.dark ? Colors.white12 : Colors.black12;
    final Color fill = Color.lerp(theme.colorScheme.secondary, theme.colorScheme.error, value) ?? theme.colorScheme.secondary;
    final String label = value < 0.33 ? 'Low' : (value < 0.66 ? 'Medium' : 'High');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Risk', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.muted)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Container(height: compact ? 10 : 14, color: track),
              Container(height: compact ? 10 : 14, width: (value.clamp(0.0, 1.0)) * 160, color: fill),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted)),
      ],
    );
  }
}

class _RoiSparkline extends StatelessWidget {
  final double totalReturn;
  const _RoiSparkline({required this.totalReturn});

  List<FlSpot> _series() {
    // Simple synthetic series that ends at totalReturn
    final base = <double>[ -2, 1, -1, 3, -2, 2, 1, 0, 2.5, totalReturn ];
    return List<FlSpot>.generate(base.length, (i) => FlSpot(i.toDouble(), base[i]));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGain = totalReturn >= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ROI', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.muted)),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  isCurved: true,
                  color: isGain ? theme.colorScheme.secondary : theme.colorScheme.error,
                  barWidth: 2,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: (isGain ? theme.colorScheme.secondary : theme.colorScheme.error).withOpacity(0.12)),
                  spots: _series(),
                )
              ],
              minY: -10,
              maxY: 10,
            ),
          ),
        )
      ],
    );
  }
}

class _DetailsMetrics extends StatelessWidget {
  final Map<String, dynamic> perf;
  const _DetailsMetrics({required this.perf});

  @override
  Widget build(BuildContext context) {
    final double totalReturn = (perf['totalReturn'] as num?)?.toDouble() ?? 0.0;
    final int trades = (perf['tradesCount'] as num?)?.toInt() ?? 0;
    final double winRate = (perf['winRate'] as num?)?.toDouble() ?? 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _MetricTile(label: 'Total return', value: '${totalReturn >= 0 ? '+' : ''}${totalReturn.toStringAsFixed(1)}%', isGain: totalReturn >= 0)),
            const SizedBox(width: 16),
            Expanded(child: _MetricTile(label: 'Trades', value: trades.toString(), isGain: true)),
            const SizedBox(width: 16),
            Expanded(child: _MetricTile(label: 'Win rate', value: '${(winRate * 100).toStringAsFixed(0)}%', isGain: true)),
          ],
        ),
      ],
    );
  }
}


