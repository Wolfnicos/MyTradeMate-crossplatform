import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/candle.dart';

import '../services/binance_service.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final BinanceService _binance = BinanceService();
  final Map<String, Map<String, double>> _tickers = {};
  String _interval = '15m';
  String _selectedSymbol = 'BTCUSDT';
  List<CandleData> _candles = <CandleData>[];
  bool _loadingChart = true;
  String _chartError = '';

  final List<List<String>> _symbols = const [
    ['BTCUSDT'],
    ['ETHUSDT'],
    ['BNBUSDT'],
    ['SOLUSDT'],
    // WLFI may be WIF on Binance (Dogwifhat)
    ['WIFUSDT', 'WIFUSDC', 'WIFBUSD'],
    // TRUMP tokens have variants; try common future/spot proxies
    ['1000TRUMPUSDT', 'TRUMPUSDT', 'DJTUSDT'],
  ];

  @override
  void initState() {
    super.initState();
    _refreshTickers();
    _loadChart();
  }

  Future<void> _refreshTickers() async {
    for (final List<String> s in _symbols) {
      try {
        final Map<String, double> t = await _binance.fetchTicker24hWithFallback(s);
        setState(() => _tickers[s.first] = t);
      } catch (_) {}
    }
  }

  Future<void> _loadChart() async {
    setState(() {
      _loadingChart = true;
      _chartError = '';
    });
    try {
      final List<Candle> klines = await _binance.fetchCustomKlines(_selectedSymbol, _interval, limit: 60);
      final List<CandleData> data = <CandleData>[];
      for (int i = 0; i < klines.length; i++) {
        final Candle c = klines[i];
        data.add(CandleData(
          x: i.toDouble(),
          open: c.open,
          high: c.high,
          low: c.low,
          close: c.close,
        ));
      }
      setState(() {
        _candles = data;
        _loadingChart = false;
      });
    } catch (e) {
      setState(() {
        _chartError = 'Failed to load chart: ' + e.toString();
        _loadingChart = false;
      });
    }
  }

  String _labelForSymbol(String symbol) {
    if (symbol.endsWith('USDT')) {
      return symbol.replaceAll('USDT', '/USDT');
    }
    return symbol;
  }

  // Placeholder to show where interval would feed chart data
  // In a next step, fetch klines via _binance.fetchCustomKlines(selectedSymbol, _interval)

  @override
  Widget build(BuildContext context) {
    final double rawCarouselHeight = MediaQuery.of(context).size.height * 0.16;
    final double carouselHeight = rawCarouselHeight < 110 ? 110 : rawCarouselHeight;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: SafeArea(
          child: Column(
          children: [
            // Header with title and search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Market', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {},
                    tooltip: 'Search markets',
                  ),
                ],
              ),
            ),
            // Carousel de monede (selectează simbolul pentru grafic)
            SizedBox(
              height: carouselHeight,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _buildTickerCards(),
              ),
            ),
            const SizedBox(height: 16),
            // Graficul Candlestick cu date reale
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withOpacity(0.2))
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _labelForSymbol(_selectedSymbol),
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _candles.isNotEmpty ? '\$' + (_candles.last.close >= 100 ? _candles.last.close.toStringAsFixed(0) : _candles.last.close.toStringAsFixed(4)) : '—',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _candles.isNotEmpty && _candles.last.close > _candles.last.open
                                    ? Theme.of(context).colorScheme.secondary
                                    : Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _loadingChart
                              ? const Center(child: CircularProgressIndicator())
                              : _chartError.isNotEmpty
                                  ? Center(child: Text(_chartError))
                                  : CandlestickChart(
                                      data: _candles,
                                      bullColor: Theme.of(context).colorScheme.secondary,
                                      bearColor: Theme.of(context).colorScheme.error,
                                      isDark: Theme.of(context).brightness == Brightness.dark,
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Placeholder pentru intervalele de timp ale graficului
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  {'label': '15m', 'value': '15m'},
                  {'label': '1H', 'value': '1h'},
                  {'label': '4H', 'value': '4h'},
                ].map((item) {
                  final bool selected = _interval == item['value'];
                  return ChoiceChip(
                    label: Text(item['label'] as String),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _interval = item['value'] as String);
                      _loadChart();
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class CoinCard extends StatelessWidget {
  final String pair;
  final String price;
  final String change;
  final bool isGain;

  const CoinCard({
    super.key,
    required this.pair,
    required this.price,
    required this.change,
    required this.isGain,
  });

  @override
  Widget build(BuildContext context) {
    final color = isGain ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.error;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(pair, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(price, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(change, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

extension on _MarketScreenState {
  List<Widget> _buildTickerCards() {
    Widget buildCard(String label, Map<String, double>? t) {
      final double price = t?['lastPrice'] ?? 0.0;
      final double chg = t?['priceChangePercent'] ?? 0.0;
      final bool isGain = chg >= 0;
      return GestureDetector(
        onTap: () {
          setState(() {
            _selectedSymbol = label.replaceAll('/USDT', 'USDT');
          });
          _loadChart();
        },
        child: CoinCard(
          pair: label,
          price: price > 0 ? '\$' + (price >= 100 ? price.toStringAsFixed(0) : price.toStringAsFixed(4)) : '—',
          change: (isGain ? '+' : '') + chg.toStringAsFixed(2) + '%',
          isGain: isGain,
        ),
      );
    }

    return [
      buildCard('BTC/USDT', _tickers['BTCUSDT']),
      buildCard('ETH/USDT', _tickers['ETHUSDT']),
      buildCard('BNB/USDT', _tickers['BNBUSDT']),
      buildCard('SOL/USDT', _tickers['SOLUSDT']),
      buildCard('WIF/USDT', _tickers['WIFUSDT']),
      buildCard('TRUMP', _tickers['1000TRUMPUSDT'] ?? _tickers['TRUMPUSDT'] ?? _tickers['DJTUSDT']),
    ];
  }
}

class _ChartPlaceholder extends StatefulWidget {
  const _ChartPlaceholder();

  @override
  State<_ChartPlaceholder> createState() => _ChartPlaceholderState();
}

class _ChartPlaceholderState extends State<_ChartPlaceholder> {
  List<CandleData> _generateSampleData() {
    // Generate sample candlestick data for demonstration
    final data = <CandleData>[];
    double price = 34500;

    for (int i = 0; i < 50; i++) {
      final open = price;
      final close = price + (i % 3 == 0 ? -200 : 150) + (i % 5 * 10);
      final high = [open, close].reduce((a, b) => a > b ? a : b) + 100;
      final low = [open, close].reduce((a, b) => a < b ? a : b) - 100;

      data.add(CandleData(
        x: i.toDouble(),
        open: open,
        high: high,
        low: low,
        close: close,
      ));

      price = close;
    }

    return data;
  }

  @override
  Widget build(BuildContext context) {
    final candleData = _generateSampleData();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'BTC/USDT',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '\$${candleData.last.close.toStringAsFixed(0)}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: candleData.last.close > candleData.last.open
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: CandlestickChart(
              data: candleData,
              bullColor: theme.colorScheme.secondary,
              bearColor: theme.colorScheme.error,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

class CandleData {
  final double x;
  final double open;
  final double high;
  final double low;
  final double close;

  CandleData({
    required this.x,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  bool get isBullish => close > open;
}

class CandlestickChart extends StatelessWidget {
  final List<CandleData> data;
  final Color bullColor;
  final Color bearColor;
  final bool isDark;

  const CandlestickChart({
    super.key,
    required this.data,
    required this.bullColor,
    required this.bearColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: data.map((e) => e.high).reduce((a, b) => a > b ? a : b) * 1.02,
        minY: data.map((e) => e.low).reduce((a, b) => a < b ? a : b) * 0.98,
        groupsSpace: 8,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => isDark ? Colors.grey[800]! : Colors.grey[200]!,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final candle = data[group.x.toInt()];
              return BarTooltipItem(
                'O: ${candle.open.toStringAsFixed(0)}\n'
                'H: ${candle.high.toStringAsFixed(0)}\n'
                'L: ${candle.low.toStringAsFixed(0)}\n'
                'C: ${candle.close.toStringAsFixed(0)}',
                TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                return Text(
                  '\$${(value ~/ 100 * 100).toString()}',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() % 10 == 0) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 10,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 500,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
              strokeWidth: 0.5,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: data.asMap().entries.map((entry) {
          final candle = entry.value;
          final isBullish = candle.isBullish;
          final color = isBullish ? bullColor : bearColor;

          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                fromY: candle.low,
                toY: candle.high,
                width: 1,
                color: color,
                rodStackItems: [
                  BarChartRodStackItem(
                    candle.low,
                    candle.open < candle.close ? candle.open : candle.close,
                    color.withOpacity(0.3),
                  ),
                  BarChartRodStackItem(
                    candle.open < candle.close ? candle.open : candle.close,
                    candle.open > candle.close ? candle.open : candle.close,
                    color,
                  ),
                  BarChartRodStackItem(
                    candle.open > candle.close ? candle.open : candle.close,
                    candle.high,
                    color.withOpacity(0.3),
                  ),
                ],
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

