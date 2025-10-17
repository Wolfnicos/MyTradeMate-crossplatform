import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

// Services
import '../services/app_settings_service.dart';
import '../services/binance_service.dart';
import '../services/hybrid_strategies_service.dart';

// ML
import '../ml/ensemble_predictor.dart' hide SignalType;

// Theme & Widgets
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/risk_disclaimer.dart';
import '../widgets/ai/discovery_card.dart';
import '../providers/navigation_provider.dart';

class AiStrategiesScreen extends StatefulWidget {
  const AiStrategiesScreen({super.key});

  @override
  State<AiStrategiesScreen> createState() => _AiStrategiesScreenState();
}

class _AiStrategiesScreenState extends State<AiStrategiesScreen> {
  // AI Prediction State
  EnsemblePrediction? _lastPrediction;
  bool _isRunningPrediction = false;
  String _predictionError = '';

  // Strategy State
  List<StrategySignal>? _liveSignals;
  String _selectedSymbol = 'BTCUSDT';
  String _interval = '1h';
  Timer? _liveTimer;

  @override
  void initState() {
    super.initState();
    final quote = AppSettingsService().quoteCurrency.toUpperCase();
    _selectedSymbol = 'BTC$quote';
    hybridStrategiesService.updateTradingPair(_selectedSymbol, interval: _interval);
    _startLiveFeed();
    // Auto-run first prediction
    if (globalEnsemblePredictor.isLoaded) {
      Future.delayed(const Duration(milliseconds: 500), _runInference);
    }
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  Future<void> _runInference() async {
    if (!globalEnsemblePredictor.isLoaded) return;
    setState(() {
      _isRunningPrediction = true;
      _predictionError = '';
    });

    try {
      debugPrint('▶️ AI: fetching features for $_selectedSymbol @$_interval');
      final features = await BinanceService().getFeaturesForModel(_selectedSymbol, interval: _interval);
      debugPrint('ℹ️ AI: features ${features.length}x${features.isNotEmpty ? features.first.length : 0}');

      final prediction = await globalEnsemblePredictor.predict(features);
      debugPrint('🚀 ENSEMBLE: ${prediction.label} (${(prediction.confidence * 100).toStringAsFixed(1)}%)');

      if (mounted) {
        setState(() {
          _lastPrediction = prediction;
          _isRunningPrediction = false;
        });
      }
    } catch (e) {
      debugPrint('❌ AI inference error: $e');
      if (mounted) {
        setState(() {
          _predictionError = e.toString();
          _isRunningPrediction = false;
        });
      }
    }
  }

  List<String> _buildPairs() {
    final q = AppSettingsService().quoteCurrency.toUpperCase();
    return ['BTC', 'ETH', 'BNB', 'SOL', 'WLFI', 'TRUMP'].map((b) => '$b$q').toList();
  }

  void _startLiveFeed() {
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      try {
        final klines = await BinanceService().fetchCustomKlines(_selectedSymbol, _interval, limit: 120);
        if (klines.isEmpty) return;
        final priceHistory = klines.map((c) => c.close).toList();
        final price = klines.last.close;
        final volume = klines.last.volume;
        final data = MarketData(price: price, volume: volume, priceHistory: priceHistory);
        final signals = <StrategySignal>[];
        for (final s in hybridStrategiesService.strategies.where((e) => e.isActive)) {
          try {
            final sig = await s.analyze(data);
            signals.add(sig);
          } catch (e) {
            debugPrint('Strategy analyze error (${s.name}): $e');
          }
        }
        if (mounted) setState(() => _liveSignals = signals);
      } catch (e) {
        debugPrint('Live feed error: $e');
      }
    });
  }

  Future<void> _openEditParameters(HybridStrategy strategy) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: _StrategyParamsSheet(strategy: strategy),
        );
      },
    );
    // Persist params
    final prefs = await SharedPreferences.getInstance();
    final key = 'strategy_params_${strategy.name.replaceAll(RegExp(r'\s+'), '_').toLowerCase()}';
    Map<String, dynamic> m = {};
    if (strategy is RSIMLHybridStrategy) {
      m = {
        'oversold': strategy.oversold,
        'overbought': strategy.overbought,
        'buyRsi': strategy.buyRsi,
        'sellRsi': strategy.sellRsi,
      };
    } else if (strategy is DynamicGridBotStrategy) {
      m = {'gridSize': strategy.gridSize};
    } else if (strategy is BreakoutStrategy) {
      m = {'lookback': strategy.lookback, 'confidenceBase': strategy.confidenceBase};
    } else if (strategy is MeanReversionStrategy) {
      m = {'period': strategy.period, 'stdDev': strategy.stdDev};
    }
    await prefs.setString(key, m.toString());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacing20,
                  AppTheme.spacing24,
                  AppTheme.spacing20,
                  AppTheme.spacing16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('AI Strategies', style: AppTheme.displayLarge),
                    Icon(
                      globalEnsemblePredictor.isLoaded ? Icons.check_circle : Icons.error_outline,
                      color: globalEnsemblePredictor.isLoaded ? AppTheme.success : AppTheme.error,
                    ),
                  ],
                ),
              ),

              // TabBar
              const TabBar(
                indicatorColor: AppTheme.primary,
                labelColor: AppTheme.textPrimary,
                unselectedLabelColor: AppTheme.textSecondary,
                tabs: [
                  Tab(text: 'AI Predictions'),
                  Tab(text: 'Active Strategies'),
                ],
              ),

              // TabBarView
              Expanded(
                child: TabBarView(
                  children: [
                    _buildPredictionsTab(),
                    _buildStrategiesTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== PREDICTIONS TAB ==========
  Widget _buildPredictionsTab() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppTheme.spacing20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Risk Disclaimer
              const RiskDisclaimer(),
              const SizedBox(height: AppTheme.spacing16),

              // Symbol & Interval Selector
              _buildSymbolSelector(),
              const SizedBox(height: AppTheme.spacing16),

              // AI Model Status Cards
              _buildModelStatusCards(),
              const SizedBox(height: AppTheme.spacing16),

              // AI Prediction Card
              _buildPredictionCard(),
              const SizedBox(height: AppTheme.spacing16),

              // Model Contributions
              if (_lastPrediction != null) _buildModelContributions(),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSymbolSelector() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trading Pair', style: AppTheme.headingMedium),
          const SizedBox(height: AppTheme.spacing12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    border: Border.all(color: AppTheme.glassBorder),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedSymbol,
                    isExpanded: true,
                    underline: const SizedBox(),
                    dropdownColor: AppTheme.surface,
                    style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
                    items: _buildPairs().map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _selectedSymbol = v);
                      hybridStrategiesService.updateTradingPair(v, interval: _interval);
                      _startLiveFeed();
                      _runInference();
                    },
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Wrap(
                spacing: AppTheme.spacing8,
                children: [
                  {'label': '15m', 'value': '15m'},
                  {'label': '1H', 'value': '1h'},
                  {'label': '4H', 'value': '4h'},
                ].map((item) {
                  final bool selected = _interval == item['value'];
                  return GestureDetector(
                    onTap: () {
                      setState(() => _interval = item['value'] as String);
                      hybridStrategiesService.updateTradingPair(_selectedSymbol, interval: _interval);
                      _startLiveFeed();
                      _runInference();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing12,
                        vertical: AppTheme.spacing8,
                      ),
                      decoration: BoxDecoration(
                        gradient: selected ? AppTheme.primaryGradient : null,
                        color: selected ? null : AppTheme.glassWhite,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                        border: Border.all(
                          color: selected ? Colors.transparent : AppTheme.glassBorder,
                        ),
                      ),
                      child: Text(
                        item['label'] as String,
                        style: AppTheme.bodyMedium.copyWith(
                          color: selected ? Colors.white : AppTheme.textSecondary,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModelStatusCards() {
    return Row(
      children: [
        Expanded(child: _buildModelStatusCard('Transformer', true, '58.67%')),
        const SizedBox(width: AppTheme.spacing12),
        Expanded(child: _buildModelStatusCard('LSTM', false, 'Failed')),
        const SizedBox(width: AppTheme.spacing12),
        Expanded(child: _buildModelStatusCard('Random Forest', false, 'Fallback')),
      ],
    );
  }

  Widget _buildModelStatusCard(String name, bool isLoaded, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: AppTheme.glassWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: isLoaded ? AppTheme.success.withOpacity(0.3) : AppTheme.glassBorder,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            isLoaded ? Icons.check_circle : Icons.error_outline,
            color: isLoaded ? AppTheme.success : AppTheme.textTertiary,
            size: 24,
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            name,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            subtitle,
            style: AppTheme.bodySmall.copyWith(
              color: isLoaded ? AppTheme.success : AppTheme.textTertiary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionCard() {
    if (_isRunningPrediction) {
      return GlassCard(
        child: Center(
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppTheme.spacing12),
              Text('Running AI prediction...', style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );
    }

    if (_predictionError.isNotEmpty) {
      return GlassCard(
        child: Column(
          children: [
            Icon(Icons.error_outline, color: AppTheme.error, size: 48),
            const SizedBox(height: AppTheme.spacing12),
            Text('Prediction Error', style: AppTheme.headingMedium.copyWith(color: AppTheme.error)),
            const SizedBox(height: AppTheme.spacing8),
            Text(_predictionError, style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
            const SizedBox(height: AppTheme.spacing16),
            ElevatedButton.icon(
              onPressed: _runInference,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_lastPrediction == null) {
      return GlassCard(
        child: Column(
          children: [
            Icon(Icons.psychology, color: AppTheme.primary, size: 48),
            const SizedBox(height: AppTheme.spacing12),
            Text('No prediction yet', style: AppTheme.headingMedium),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              'Run AI inference to get a trading signal',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppTheme.spacing16),
            ElevatedButton.icon(
              onPressed: globalEnsemblePredictor.isLoaded ? _runInference : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Run Inference'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // Show prediction
    final prediction = _lastPrediction!;
    final isBuy = prediction.label.contains('BUY');
    final isSell = prediction.label.contains('SELL');
    final signalColor = isBuy ? AppTheme.buyGreen : (isSell ? AppTheme.sellRed : AppTheme.holdYellow);

    return GlassCard(
      child: Column(
        children: [
          // Signal Icon & Label
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: signalColor.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: signalColor, width: 2),
            ),
            child: Icon(
              isBuy ? Icons.trending_up : (isSell ? Icons.trending_down : Icons.pause),
              color: signalColor,
              size: 40,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            prediction.label.replaceAll('_', ' '),
            style: AppTheme.displayMedium.copyWith(color: signalColor, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing8,
            ),
            decoration: BoxDecoration(
              gradient: isBuy
                  ? AppTheme.buyGradient
                  : (isSell ? AppTheme.sellGradient : const LinearGradient(colors: [AppTheme.holdYellow, AppTheme.holdYellow])),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: Text(
              'Confidence: ${(prediction.confidence * 100).toStringAsFixed(1)}%',
              style: AppTheme.headingMedium.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            'Ensemble Prediction',
            style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary),
          ),
          const SizedBox(height: AppTheme.spacing16),
          ElevatedButton.icon(
            onPressed: _runInference,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Prediction'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelContributions() {
    final prediction = _lastPrediction!;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Model Contributions', style: AppTheme.headingMedium),
          const SizedBox(height: AppTheme.spacing16),
          if (prediction.modelContributions.containsKey('transformer'))
            _buildContributionBar(
              'Transformer',
              prediction.modelContributions['transformer']![2],
              AppTheme.primary,
            ),
          const SizedBox(height: AppTheme.spacing12),
          if (prediction.modelContributions.containsKey('lstm'))
            _buildContributionBar(
              'LSTM',
              prediction.modelContributions['lstm']![2],
              AppTheme.secondary,
            ),
          const SizedBox(height: AppTheme.spacing12),
          if (prediction.modelContributions.containsKey('randomForest'))
            _buildContributionBar(
              'Random Forest',
              prediction.modelContributions['randomForest']![2],
              AppTheme.chartPurple,
            ),
        ],
      ),
    );
  }

  Widget _buildContributionBar(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
            Text('${(value * 100).toStringAsFixed(1)}%', style: AppTheme.bodyMedium.copyWith(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: AppTheme.spacing8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: AppTheme.surface,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  // ========== STRATEGIES TAB ==========
  Widget _buildStrategiesTab() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppTheme.spacing20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Execute Live Button
              if (hybridStrategiesService.strategies.any((s) => s.isActive))
                ElevatedButton.icon(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('order_type', 'hybrid');
                    if (context.mounted) {
                      Provider.of<NavigationProvider>(context, listen: false).setIndex(3);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Hybrid live execution: configure amount in Orders and arm.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.flash_on_rounded),
                  label: const Text('Execute Live (Hybrid)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                  ),
                ),
              if (hybridStrategiesService.strategies.any((s) => s.isActive)) const SizedBox(height: AppTheme.spacing16),

              // Active Strategies
              ...hybridStrategiesService.strategies.where((s) => s.isActive).map((strategy) {
                final signal = _liveSignals?.firstWhere(
                  (s) => s.strategyName == strategy.name,
                  orElse: () => StrategySignal(
                    strategyName: strategy.name,
                    type: SignalType.HOLD,
                    confidence: 0.0,
                    reason: 'Waiting for data...',
                  ),
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
                  child: _StrategyCard(
                    name: '${strategy.name} ${strategy.version}',
                    status: 'Active',
                    performance: '${strategy.totalReturn >= 0 ? "+" : ""}${strategy.totalReturn.toStringAsFixed(1)}% (7D)',
                    isGain: strategy.totalReturn >= 0,
                    liveSignal: signal,
                    onActivate: () {
                      setState(() {
                        hybridStrategiesService.toggleStrategy(strategy.name, false);
                      });
                    },
                    onEdit: () => _openEditParameters(strategy),
                  ),
                );
              }),

              if (hybridStrategiesService.strategies.where((s) => s.isActive).isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppTheme.spacing12),
                  child: Center(
                    child: Text(
                      'No active strategies. Activate from Discover tab.',
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary),
                    ),
                  ),
                ),

              // Discover Section
              const SizedBox(height: AppTheme.spacing24),
              Text('Discover Strategies', style: AppTheme.headingLarge),
              const SizedBox(height: AppTheme.spacing16),

              ...hybridStrategiesService.strategies.where((s) => !s.isActive).map((strategy) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
                  child: DiscoveryCard(
                    strategy: strategy,
                    markets: const ['BTC', 'WLFI', 'TRUMP'],
                    onActivate: () {
                      setState(() {
                        hybridStrategiesService.toggleStrategy(strategy.name, true);
                      });
                    },
                  ),
                );
              }),
            ]),
          ),
        ),
      ],
    );
  }
}

// ========== STRATEGY CARD ==========
class _StrategyCard extends StatelessWidget {
  final String name;
  final String status;
  final String performance;
  final bool isGain;
  final StrategySignal? liveSignal;
  final VoidCallback onActivate;
  final VoidCallback? onEdit;

  const _StrategyCard({
    required this.name,
    required this.status,
    required this.performance,
    required this.isGain,
    this.liveSignal,
    required this.onActivate,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final perfColor = isGain ? AppTheme.buyGreen : AppTheme.sellRed;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: AppTheme.headingLarge),
          const SizedBox(height: AppTheme.spacing12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Status:', style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing8, vertical: AppTheme.spacing4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Text(
                  status,
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.success, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Performance:', style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
              Text(performance, style: AppTheme.bodyMedium.copyWith(color: perfColor, fontWeight: FontWeight.w600)),
            ],
          ),
          if (liveSignal != null) ...[
            const SizedBox(height: AppTheme.spacing12),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              decoration: BoxDecoration(
                color: _getSignalColor(liveSignal!.type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                border: Border.all(color: _getSignalColor(liveSignal!.type), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_getSignalIcon(liveSignal!.type), color: _getSignalColor(liveSignal!.type), size: 20),
                      const SizedBox(width: AppTheme.spacing8),
                      Text(
                        liveSignal!.type.name,
                        style: AppTheme.headingSmall.copyWith(color: _getSignalColor(liveSignal!.type)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing8, vertical: AppTheme.spacing4),
                        decoration: BoxDecoration(
                          color: _getSignalColor(liveSignal!.type),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                        ),
                        child: Text(
                          '${(liveSignal!.confidence * 100).toStringAsFixed(0)}%',
                          style: AppTheme.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    liveSignal!.reason,
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppTheme.spacing16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onEdit, child: const Text('Edit')),
              const SizedBox(width: AppTheme.spacing8),
              ElevatedButton(
                onPressed: onActivate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Deactivate'),
              ),
            ],
          )
        ],
      ),
    );
  }

  Color _getSignalColor(SignalType type) {
    switch (type) {
      case SignalType.BUY:
        return AppTheme.buyGreen;
      case SignalType.SELL:
        return AppTheme.sellRed;
      case SignalType.HOLD:
        return AppTheme.holdYellow;
    }
  }

  IconData _getSignalIcon(SignalType type) {
    switch (type) {
      case SignalType.BUY:
        return Icons.arrow_upward;
      case SignalType.SELL:
        return Icons.arrow_downward;
      case SignalType.HOLD:
        return Icons.pause;
    }
  }
}

// ========== STRATEGY PARAMS SHEET ==========
class _StrategyParamsSheet extends StatefulWidget {
  final HybridStrategy strategy;
  const _StrategyParamsSheet({required this.strategy});

  @override
  State<_StrategyParamsSheet> createState() => _StrategyParamsSheetState();
}

class _StrategyParamsSheetState extends State<_StrategyParamsSheet> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Edit Parameters - ${widget.strategy.name}', style: AppTheme.headingLarge),
        const SizedBox(height: AppTheme.spacing16),
        if (widget.strategy is RSIMLHybridStrategy) ..._buildRsiMl(),
        if (widget.strategy is DynamicGridBotStrategy) ..._buildGrid(),
        if (widget.strategy is BreakoutStrategy) ..._buildBreakout(),
        if (widget.strategy is MeanReversionStrategy) ..._buildMeanRev(),
        const SizedBox(height: AppTheme.spacing12),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Done'),
          ),
        )
      ],
    );
  }

  List<Widget> _buildRsiMl() {
    final s = widget.strategy as RSIMLHybridStrategy;
    return [
      _buildParamRow('RSI oversold', s.oversold.toString(), false, (v) => s.oversold = int.tryParse(v) ?? s.oversold),
      _buildParamRow('RSI overbought', s.overbought.toString(), false, (v) => s.overbought = int.tryParse(v) ?? s.overbought),
      _buildParamRow('Buy RSI', s.buyRsi.toString(), false, (v) => s.buyRsi = int.tryParse(v) ?? s.buyRsi),
      _buildParamRow('Sell RSI', s.sellRsi.toString(), false, (v) => s.sellRsi = int.tryParse(v) ?? s.sellRsi),
    ];
  }

  List<Widget> _buildGrid() {
    final s = widget.strategy as DynamicGridBotStrategy;
    return [
      _buildParamRow('Grid Size (%)', s.gridSize.toStringAsFixed(2), true, (v) => s.gridSize = double.tryParse(v) ?? s.gridSize),
    ];
  }

  List<Widget> _buildBreakout() {
    final s = widget.strategy as BreakoutStrategy;
    return [
      _buildParamRow('Lookback', s.lookback.toString(), false, (v) => s.lookback = int.tryParse(v) ?? s.lookback),
      _buildParamRow('Confidence Base', s.confidenceBase.toStringAsFixed(2), true, (v) => s.confidenceBase = double.tryParse(v) ?? s.confidenceBase),
    ];
  }

  List<Widget> _buildMeanRev() {
    final s = widget.strategy as MeanReversionStrategy;
    return [
      _buildParamRow('Period', s.period.toString(), false, (v) => s.period = int.tryParse(v) ?? s.period),
      _buildParamRow('Std Dev', s.stdDev.toStringAsFixed(2), true, (v) => s.stdDev = double.tryParse(v) ?? s.stdDev),
    ];
  }

  Widget _buildParamRow(String label, String initialValue, bool isDecimal, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTheme.bodyMedium)),
          SizedBox(
            width: 120,
            child: TextFormField(
              initialValue: initialValue,
              keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide(color: AppTheme.glassBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide(color: AppTheme.glassBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide(color: AppTheme.primary),
                ),
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
