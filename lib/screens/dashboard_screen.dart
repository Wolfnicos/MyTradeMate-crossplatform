import 'package:flutter/material.dart';
import '../services/binance_service.dart';
import '../services/app_settings_service.dart';
import '../design_system/screen_backgrounds.dart';
import '../design_system/widgets/glass_card.dart';
import '../widgets/dashboard/dashboard_grid.dart';
import '../widgets/dashboard/collapsible_news_banner.dart';
 

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: ScreenBackgrounds.market(context),
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Text('Dashboard', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const CollapsibleNewsBanner(),
              const SizedBox(height: 16),
              const DashboardGrid(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class PortfolioOverviewCard extends StatelessWidget {
  const PortfolioOverviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gainColor = theme.colorScheme.secondary;

    return GlassCard(
      padding: const EdgeInsets.all(20.0),
      showGlow: true,
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Portfolio Overview', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              (AppSettingsService.currencyPrefix(AppSettingsService().quoteCurrency)) + '122,000',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '+' + AppSettingsService.currencyPrefix(AppSettingsService().quoteCurrency) + '4,200 (2.0%)',
                  style: theme.textTheme.titleMedium?.copyWith(color: gainColor, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_upward, color: gainColor, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PnLTodaySection extends StatefulWidget {
  const PnLTodaySection({super.key});

  @override
  State<PnLTodaySection> createState() => _PnLTodaySectionState();
}

class _PnLTodaySectionState extends State<PnLTodaySection> {
  final BinanceService _binance = BinanceService();
  Map<String, double>? _btc;
  Map<String, double>? _eth;
  Map<String, double>? _bnb;
  Map<String, double>? _sol;
  Map<String, double>? _wif;
  Map<String, double>? _trump;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      _btc = await _binance.fetchTicker24h('BTCUSDT');
      _eth = await _binance.fetchTicker24h('ETHUSDT');
      _bnb = await _binance.fetchTicker24h('BNBUSDT');
      _sol = await _binance.fetchTicker24h('SOLUSDT');
      _wif = await _binance.fetchTicker24hWithFallback(['WLFIEUR','WLFIUSDT', 'WLFIUSDC', 'WLFIBUSD']);
      _trump = await _binance.fetchTicker24hWithFallback(['TRUMPUSDT', 'DJTUSDT']);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20.0),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'P&L Today',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildPnLRow(context, 'BTC', _btc),
            _buildPnLRow(context, 'ETH', _eth),
            _buildPnLRow(context, 'BNB', _bnb),
            _buildPnLRow(context, 'SOL', _sol),
            _buildPnLRow(context, 'WIF', _wif),
            _buildPnLRow(context, 'TRUMP', _trump),
          ],
        ),
      ),
    );
  }

  Widget _buildPnLRow(BuildContext context, String coin, Map<String, double>? t) {
    final double chg = t?['priceChangePercent'] ?? 0.0;
    final bool isGain = chg >= 0;
    final color = isGain ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.error;
    final icon = isGain ? Icons.arrow_upward : Icons.arrow_downward;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey.shade300,
            child: Text(coin.substring(0, 1), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Text(coin, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text((isGain ? '+' : '') + chg.toStringAsFixed(2) + '%', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Icon(icon, color: color, size: 18),
        ],
      ),
    );
  }
}

