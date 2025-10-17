import 'package:flutter/material.dart';
import '../services/binance_service.dart';
import '../services/app_settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/ai_indicator.dart';
import '../ml/ensemble_predictor.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with AI Indicator
                    Row(
                      children: [
                        Text(
                          'Dashboard',
                          style: AppTheme.displayLarge,
                        ),
                        const SizedBox(width: AppTheme.spacing12),
                        AIIndicator(
                          isActive: globalEnsemblePredictor.isLoaded,
                          isLoading: !globalEnsemblePredictor.isLoaded,
                          label: 'AI Active',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      'Welcome back to MyTradeMate',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: AppTheme.spacing16),

                  // Portfolio Overview Card
                  const RepaintBoundary(
                    child: PortfolioOverviewCard(),
                  ),

                  const SizedBox(height: AppTheme.spacing16),

                  // AI Models Status Card
                  const RepaintBoundary(
                    child: AIModelsStatusCard(),
                  ),

                  const SizedBox(height: AppTheme.spacing16),

                  // P&L Today Section
                  const RepaintBoundary(
                    child: PnLTodaySection(),
                  ),

                  const SizedBox(height: AppTheme.spacing32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PortfolioOverviewCard extends StatelessWidget {
  const PortfolioOverviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    const totalValue = 122000.0;
    const dailyPnL = 4200.0;
    const dailyPnLPercent = 2.0;
    final isGain = dailyPnL >= 0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Text(
                'Portfolio Overview',
                style: AppTheme.headingMedium,
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacing20),

          // Total Value
          Text(
            'Total Value',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textTertiary,
              textBaseline: TextBaseline.alphabetic,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            '${AppSettingsService.currencyPrefix(AppSettingsService().quoteCurrency)}${totalValue.toStringAsFixed(0)}',
            style: AppTheme.monoLarge,
          ),

          const SizedBox(height: AppTheme.spacing16),

          // Daily P&L
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            decoration: BoxDecoration(
              gradient: isGain ? AppTheme.buyGradient : AppTheme.sellGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isGain ? Icons.trending_up : Icons.trending_down,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Text(
                      'Today',
                      style: AppTheme.bodyMedium.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Flexible(
                  child: Text(
                    '${isGain ? '+' : ''}${AppSettingsService.currencyPrefix(AppSettingsService().quoteCurrency)}${dailyPnL.toStringAsFixed(0)} (${dailyPnLPercent.toStringAsFixed(1)}%)',
                    style: AppTheme.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// AI Models Status Card
class AIModelsStatusCard extends StatelessWidget {
  const AIModelsStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing8),
                decoration: BoxDecoration(
                  gradient: AppTheme.secondaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: const Icon(
                  Icons.psychology,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Text(
                'AI Models',
                style: AppTheme.headingMedium,
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacing16),

          // Model badges
          Wrap(
            spacing: AppTheme.spacing8,
            runSpacing: AppTheme.spacing8,
            children: [
              AIStatusBadge(
                isActive: globalEnsemblePredictor.isLoaded,
                modelName: 'Transformer',
                confidence: 0.587,
              ),
              AIStatusBadge(
                isActive: globalEnsemblePredictor.isLoaded,
                modelName: 'LSTM',
                confidence: 0.51,
              ),
              AIStatusBadge(
                isActive: globalEnsemblePredictor.isLoaded,
                modelName: 'Random Forest',
                confidence: 0.438,
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacing16),

          // Status message
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            decoration: BoxDecoration(
              color: globalEnsemblePredictor.isLoaded
                  ? AppTheme.success.withOpacity(0.1)
                  : AppTheme.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              border: Border.all(
                color: globalEnsemblePredictor.isLoaded
                    ? AppTheme.success
                    : AppTheme.warning,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  globalEnsemblePredictor.isLoaded
                      ? Icons.check_circle
                      : Icons.hourglass_empty,
                  color: globalEnsemblePredictor.isLoaded
                      ? AppTheme.success
                      : AppTheme.warning,
                  size: 16,
                ),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(
                    globalEnsemblePredictor.isLoaded
                        ? 'All AI models loaded and ready'
                        : 'Loading AI models...',
                    style: AppTheme.bodySmall.copyWith(
                      color: globalEnsemblePredictor.isLoaded
                          ? AppTheme.success
                          : AppTheme.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    try {
      final quote = AppSettingsService().quoteCurrency.toUpperCase();
      _btc = await _binance.fetchTicker24h('BTC$quote');
      _eth = await _binance.fetchTicker24h('ETH$quote');
      _bnb = await _binance.fetchTicker24h('BNB$quote');
      _sol = await _binance.fetchTicker24h('SOL$quote');
      _wif = await _binance.fetchTicker24hWithFallback(['WLFI$quote', 'WLFIEUR','WLFIUSDT', 'WLFIUSDC', 'WLFIBUSD']);
      _trump = await _binance.fetchTicker24hWithFallback(['TRUMP$quote', 'TRUMPUSDT', 'DJTUSDT']);
    } catch (e) {
      print('Dashboard: Error fetching market data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacing8),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                      child: const Icon(
                        Icons.trending_up,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing12),
                    Flexible(
                      child: Text(
                        'Market',
                        style: AppTheme.headingMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _isLoading ? null : _refresh,
                color: AppTheme.textSecondary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacing16),

          // Coin list
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacing20),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            if (_btc != null) ...[
              _buildPnLRow('BTC', _btc),
              if (_eth != null || _bnb != null || _sol != null || _wif != null || _trump != null) _buildDivider(),
            ],
            if (_eth != null) ...[
              _buildPnLRow('ETH', _eth),
              if (_bnb != null || _sol != null || _wif != null || _trump != null) _buildDivider(),
            ],
            if (_bnb != null) ...[
              _buildPnLRow('BNB', _bnb),
              if (_sol != null || _wif != null || _trump != null) _buildDivider(),
            ],
            if (_sol != null) ...[
              _buildPnLRow('SOL', _sol),
              if (_wif != null || _trump != null) _buildDivider(),
            ],
            if (_wif != null) ...[
              _buildPnLRow('WIF', _wif),
              if (_trump != null) _buildDivider(),
            ],
            if (_trump != null) _buildPnLRow('TRUMP', _trump),
            if (_btc == null && _eth == null && _bnb == null && _sol == null && _wif == null && _trump == null)
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacing20),
                child: Center(
                  child: Text(
                    'No market data available',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AppTheme.glassBorder,
    );
  }

  Widget _buildPnLRow(String coin, Map<String, double>? t) {
    final double chg = t?['priceChangePercent'] ?? 0.0;
    final double price = t?['lastPrice'] ?? 0.0;
    final bool isGain = chg >= 0;
    final color = isGain ? AppTheme.buyGreen : AppTheme.sellRed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing12),
      child: Row(
        children: [
          // Coin avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.3),
                  color.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                coin.substring(0, 1),
                style: AppTheme.headingSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(width: AppTheme.spacing12),

          // Coin name & price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coin,
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${AppSettingsService.currencyPrefix(AppSettingsService().quoteCurrency)}${price.toStringAsFixed(price >= 100 ? 0 : 2)}',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),

          // Change percentage
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing12,
              vertical: AppTheme.spacing8,
            ),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isGain ? Icons.arrow_upward : Icons.arrow_downward,
                  color: color,
                  size: 16,
                ),
                const SizedBox(width: AppTheme.spacing4),
                Text(
                  '${isGain ? '+' : ''}${chg.toStringAsFixed(2)}%',
                  style: AppTheme.monoMedium.copyWith(
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

