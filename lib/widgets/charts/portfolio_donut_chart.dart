import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class PortfolioSlice {
  final String label;
  final double value;
  final Color color;
  const PortfolioSlice({required this.label, required this.value, required this.color});
}

class PortfolioDonutChart extends StatelessWidget {
  final List<PortfolioSlice> slices;
  final double size;
  final Duration animationDuration;

  const PortfolioDonutChart({super.key, required this.slices, this.size = 180, this.animationDuration = const Duration(milliseconds: 900)});

  @override
  Widget build(BuildContext context) {
    final double total = slices.fold(0.0, (double a, PortfolioSlice b) => a + b.value);
    final List<PieChartSectionData> sections = slices.map((PortfolioSlice s) {
      final double pct = total <= 0 ? 0 : (s.value / total * 100);
      return PieChartSectionData(
        color: s.color,
        value: s.value,
        radius: size * 0.28,
        showTitle: false,
        badgeWidget: _Dot(color: s.color),
        badgePositionPercentageOffset: 1.25,
        title: pct >= 8 ? (pct.toStringAsFixed(0) + '%') : '',
        titleStyle: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
      );
    }).toList(growable: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: size * 0.36,
              sectionsSpace: 2,
              startDegreeOffset: -90,
              borderData: FlBorderData(show: false),
              pieTouchData: PieTouchData(enabled: false),
            ),
            swapAnimationDuration: animationDuration,
            swapAnimationCurve: Curves.easeOutCubic,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: slices.map((PortfolioSlice s) {
            final double pct = total <= 0 ? 0 : (s.value / total * 100);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(color: s.color),
                const SizedBox(width: 6),
                Text(s.label + ' ' + pct.toStringAsFixed(0) + '%', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            );
          }).toList(growable: false),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}


