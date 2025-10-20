import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../design_system/widgets/glass_card.dart';
import '../../design_system/app_colors.dart';
import '../../services/binance_service.dart';
import '../../models/candle.dart';

class TradingViewCard extends StatefulWidget {
  final String symbol; // e.g., BTCEUR
  const TradingViewCard({super.key, required this.symbol});

  @override
  State<TradingViewCard> createState() => _TradingViewCardState();
}

class _TradingViewCardState extends State<TradingViewCard> {
  final BinanceService _binance = BinanceService();
  List<Candle> _klines = const <Candle>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TradingViewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _binance.fetchCustomKlines(widget.symbol, '15m', limit: 60);
      if (!mounted) return;
      setState(() {
        _klines = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String tvSym = 'BINANCE:${widget.symbol.toUpperCase()}';
    final String url = 'https://www.tradingview.com/chart/?symbol=$tvSym';

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Price chart', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
              TextButton.icon(onPressed: () async { if (await canLaunchUrlString(url)) await launchUrlString(url, mode: LaunchMode.externalApplication); }, icon: const Icon(Icons.open_in_new), label: const Text('TradingView')),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _klines.isEmpty
                    ? Center(child: Text('No data', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)))
                    : LineChart(
                        LineChartData(
                          gridData: FlGridData(show: false),
                          titlesData: FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              isCurved: true,
                              color: theme.colorScheme.secondary,
                              barWidth: 2,
                              dotData: FlDotData(show: false),
                              belowBarData: BarAreaData(show: true, color: theme.colorScheme.secondary.withOpacity(0.12)),
                              spots: List<FlSpot>.generate(_klines.length, (i) => FlSpot(i.toDouble(), _klines[i].close)),
                            )
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}


