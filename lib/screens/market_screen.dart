import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/candle.dart';
import '../services/binance_service.dart';
import '../services/app_settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final BinanceService _binance = BinanceService();
  final Map<String, Map<String, double>> _tickers = {};
  String _interval = '1h';
  String _selectedSymbol = 'BTCUSDT';
  List<CandleData> _candles = <CandleData>[];
  bool _loadingChart = true;
  bool _loadingTickers = true;
  String _chartError = '';

  List<List<String>> get _symbols {
    final q = AppSettingsService().quoteCurrency.toUpperCase();
    return [
      ['BTC$q', 'BTCUSDT', 'BTCEUR', 'BTCUSDC'],
      ['ETH$q', 'ETHUSDT', 'ETHEUR', 'ETHUSDC'],
      ['BNB$q', 'BNBUSDT', 'BNBEUR', 'BNBUSDC'],
      ['SOL$q', 'SOLUSDT', 'SOLEUR', 'SOLUSDC'],
      ['WLFI$q', 'WLFIUSDT', 'WLFIEUR', 'WLFIUSDC'],
      ['TRUMP$q', 'TRUMPUSDT', 'DJTUSDT'],
    ];
  }

  @override
  void initState() {
    super.initState();
    final q = AppSettingsService().quoteCurrency.toUpperCase();
    _selectedSymbol = 'BTC$q';
    _refreshTickers();
    _loadChart();
  }

  Future<void> _refreshTickers() async {
    setState(() => _loadingTickers = true);
    for (final List<String> symbolList in _symbols) {
      try {
        final Map<String, double> t = await _binance.fetchTicker24hWithFallback(symbolList);
        if (mounted) {
          setState(() => _tickers[symbolList.first] = t);
        }
      } catch (e) {
        print('Market: Failed to fetch ticker for ${symbolList.first}: $e');
      }
    }
    if (mounted) {
      setState(() => _loadingTickers = false);
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
      if (mounted) {
        setState(() {
          _candles = data;
          _loadingChart = false;
        });
      }
    } catch (e) {
      print('Market: Failed to load chart: $e');
      if (mounted) {
        setState(() {
          _chartError = 'Failed to load chart';
          _loadingChart = false;
        });
      }
    }
  }

  String _labelForSymbol(String symbol) {
    if (symbol.endsWith('USDT')) return symbol.replaceAll('USDT', '/USDT');
    if (symbol.endsWith('USDC')) return symbol.replaceAll('USDC', '/USDC');
    if (symbol.endsWith('USD')) return symbol.replaceAll('USD', '/USD');
    if (symbol.endsWith('EUR')) return symbol.replaceAll('EUR', '/EUR');
    return symbol;
  }

  @override
  Widget build(BuildContext context) {
    final quote = AppSettingsService().quoteCurrency;
    final prefix = AppSettingsService.currencyPrefix(quote);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacing20,
                  AppTheme.spacing24,
                  AppTheme.spacing20,
                  AppTheme.spacing16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Market',
                      style: AppTheme.displayLarge,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        color: AppTheme.textSecondary,
                      ),
                      onPressed: _loadingTickers ? null : () {
                        _refreshTickers();
                        _loadChart();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),

            // Coin Carousel
            SliverToBoxAdapter(
              child: SizedBox(
                height: 120,
                child: _loadingTickers
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing20),
                        children: _buildTickerCards(quote, prefix),
                      ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacing20)),

            // Chart Card
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing20),
              sliver: SliverToBoxAdapter(
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Chart Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _labelForSymbol(_selectedSymbol),
                                style: AppTheme.headingLarge,
                              ),
                              const SizedBox(height: AppTheme.spacing4),
                              if (_candles.isNotEmpty)
                                Text(
                                  prefix + (_candles.last.close >= 100
                                      ? _candles.last.close.toStringAsFixed(0)
                                      : _candles.last.close.toStringAsFixed(4)),
                                  style: AppTheme.monoLarge.copyWith(
                                    color: _candles.last.close > _candles.last.open
                                        ? AppTheme.buyGreen
                                        : AppTheme.sellRed,
                                  ),
                                ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacing12,
                              vertical: AppTheme.spacing8,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppTheme.secondaryGradient,
                              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                            ),
                            child: Text(
                              _interval.toUpperCase(),
                              style: AppTheme.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppTheme.spacing20),

                      // Chart
                      SizedBox(
                        height: 300,
                        child: _loadingChart
                            ? const Center(child: CircularProgressIndicator())
                            : _chartError.isNotEmpty
                                ? Center(
                                    child: Text(
                                      _chartError,
                                      style: AppTheme.bodyMedium.copyWith(
                                        color: AppTheme.error,
                                      ),
                                    ),
                                  )
                                : CandlestickChart(
                                    data: _candles,
                                    bullColor: AppTheme.buyGreen,
                                    bearColor: AppTheme.sellRed,
                                  ),
                      ),

                      const SizedBox(height: AppTheme.spacing20),

                      // Interval Selector
                      Wrap(
                        spacing: AppTheme.spacing8,
                        children: [
                          _buildIntervalChip('15m', '15m'),
                          _buildIntervalChip('1H', '1h'),
                          _buildIntervalChip('4H', '4h'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacing32)),
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalChip(String label, String value) {
    final bool selected = _interval == value;
    return GestureDetector(
      onTap: () {
        setState(() => _interval = value);
        _loadChart();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing8,
        ),
        decoration: BoxDecoration(
          gradient: selected ? AppTheme.primaryGradient : null,
          color: selected ? null : AppTheme.glassWhite,
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          border: Border.all(
            color: selected ? Colors.transparent : AppTheme.glassBorder,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: AppTheme.bodyMedium.copyWith(
            color: selected ? Colors.white : AppTheme.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTickerCards(String quote, String prefix) {
    final q = quote.toUpperCase();

    Widget buildCard(String base, String key) {
      final t = _tickers[key];
      final double price = t?['lastPrice'] ?? 0.0;
      final double chg = t?['priceChangePercent'] ?? 0.0;
      final bool isGain = chg >= 0;
      final symbol = key;
      final bool isSelected = _selectedSymbol == symbol;

      return GestureDetector(
        onTap: () {
          setState(() => _selectedSymbol = symbol);
          _loadChart();
        },
        child: Container(
          width: 140,
          margin: const EdgeInsets.only(right: AppTheme.spacing12),
          padding: const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            gradient: isSelected ? AppTheme.primaryGradient : null,
            color: isSelected ? null : AppTheme.glassWhite,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(
              color: isSelected ? Colors.transparent : AppTheme.glassBorder,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Coin name
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: (isGain ? AppTheme.buyGreen : AppTheme.sellRed).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      border: Border.all(
                        color: (isGain ? AppTheme.buyGreen : AppTheme.sellRed).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        base.substring(0, 1),
                        style: AppTheme.headingSmall.copyWith(
                          color: isGain ? AppTheme.buyGreen : AppTheme.sellRed,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Expanded(
                    child: Text(
                      base,
                      style: AppTheme.bodyLarge.copyWith(
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spacing8),

              // Price
              Text(
                price > 0 ? prefix + (price >= 100 ? price.toStringAsFixed(0) : price.toStringAsFixed(4)) : '—',
                style: AppTheme.monoMedium.copyWith(
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: AppTheme.spacing4),

              // Change %
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing8,
                  vertical: AppTheme.spacing4,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : (isGain ? AppTheme.buyGreen : AppTheme.sellRed).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isGain ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isSelected
                          ? Colors.white
                          : (isGain ? AppTheme.buyGreen : AppTheme.sellRed),
                      size: 12,
                    ),
                    const SizedBox(width: AppTheme.spacing4),
                    Text(
                      '${isGain ? '+' : ''}${chg.toStringAsFixed(2)}%',
                      style: AppTheme.bodySmall.copyWith(
                        color: isSelected
                            ? Colors.white
                            : (isGain ? AppTheme.buyGreen : AppTheme.sellRed),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return [
      buildCard('BTC', 'BTC$q'),
      buildCard('ETH', 'ETH$q'),
      buildCard('BNB', 'BNB$q'),
      buildCard('SOL', 'SOL$q'),
      buildCard('WLFI', 'WLFI$q'),
      buildCard('TRUMP', 'TRUMP$q'),
    ];
  }
}

// CandleData and CandlestickChart remain the same
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

  const CandlestickChart({
    super.key,
    required this.data,
    required this.bullColor,
    required this.bearColor,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary),
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        maxY: data.map((e) => e.high).reduce((a, b) => a > b ? a : b) * 1.03,
        minY: data.map((e) => e.low).reduce((a, b) => a < b ? a : b) * 0.97,
        groupsSpace: 6,
        barTouchData: BarTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => AppTheme.surface,
            tooltipPadding: const EdgeInsets.all(AppTheme.spacing8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final candle = data[group.x.toInt()];
              return BarTooltipItem(
                'O: ${candle.open.toStringAsFixed(4)}\n'
                'H: ${candle.high.toStringAsFixed(4)}\n'
                'L: ${candle.low.toStringAsFixed(4)}\n'
                'C: ${candle.close.toStringAsFixed(4)}',
                AppTheme.bodySmall.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
          touchCallback: (event, response) {},
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
                final double absValue = value.abs();
                final int decimals = absValue >= 100
                    ? 0
                    : absValue >= 1
                        ? 2
                        : 4;
                return Text(
                  '\$${value.toStringAsFixed(decimals)}',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textTertiary,
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
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textTertiary,
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
              color: AppTheme.glassBorder,
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
                width: 2.2,
                color: color,
                rodStackItems: [
                  BarChartRodStackItem(
                    candle.low,
                    candle.open < candle.close ? candle.open : candle.close,
                    color.withOpacity(0.35),
                  ),
                  BarChartRodStackItem(
                    candle.open < candle.close ? candle.open : candle.close,
                    candle.open > candle.close ? candle.open : candle.close,
                    color,
                  ),
                  BarChartRodStackItem(
                    candle.open > candle.close ? candle.open : candle.close,
                    candle.high,
                    color.withOpacity(0.35),
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
