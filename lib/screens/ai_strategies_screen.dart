import 'package:flutter/material.dart';
import '../widgets/risk_disclaimer.dart';
import '../ml/ml_service.dart';
import '../services/hybrid_strategies_service.dart';
import 'ai_prediction_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../design_system/screen_backgrounds.dart';
import '../design_system/widgets/glass_card.dart';
import '../design_system/app_colors.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
// import 'dart:math';
import 'dart:async';
import '../services/app_settings_service.dart';
import '../services/binance_service.dart';
import '../widgets/ai/discovery_card.dart';

class AiStrategiesScreen extends StatefulWidget {
  const AiStrategiesScreen({super.key});

  @override
  State<AiStrategiesScreen> createState() => _AiStrategiesScreenState();
}

class _AiStrategiesScreenState extends State<AiStrategiesScreen> {
  double? _lastProb;
  TradingSignal? _lastSignal;
  List<StrategySignal>? _liveSignals;
  // String _orderType = 'market'; // removed unused
  String _selectedSymbol = 'BTCUSDT';
  String _interval = '1h';
  Timer? _liveTimer;

  @override
  void initState() {
    super.initState();
    final quote = AppSettingsService().quoteCurrency.toUpperCase();
    _selectedSymbol = 'BTC' + quote;
    _startLiveFeed();
    // removed order type sync from here (managed in Orders)
  }

  // removed unused _syncOrderTypePref

  Future<void> _runInference() async {
    if (!globalMlService.isInitialized) return;
    try {
      final String symbol = _selectedSymbol;
      final String interval = _interval;
      debugPrint('▶️ AI Strategies: fetching features for ' + symbol + ' @' + interval);
      final features = await BinanceService().getFeaturesForModel(symbol, interval: interval);
      debugPrint('ℹ️ AI Strategies: features shape = ' + features.length.toString() + 'x' + (features.isNotEmpty ? features.first.length.toString() : '0'));
      final Map<String, dynamic> result = globalMlService.getSignal(features, symbol: symbol);
      final List<double> probs = (result['probabilities'] as List<dynamic>).cast<double>();
      setState(() {
        _lastProb = probs.length > 2 ? probs[2] : null; // BUY probability
        _lastSignal = result['signal'] as TradingSignal?;
      });
      debugPrint('ℹ️ AI Strategies: result=' + result.toString());
    } catch (e) {
      debugPrint('❌ AI Strategies: inference error → ' + e.toString());
    }
  }

  List<String> _buildPairs() {
    final q = AppSettingsService().quoteCurrency.toUpperCase();
    return <String>['BTC','ETH','BNB','SOL','WLFI','TRUMP'].map((b) => b + q).toList(growable: false);
  }

  void _startLiveFeed() {
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      try {
        final klines = await BinanceService().fetchCustomKlines(_selectedSymbol, _interval, limit: 120);
        if (klines.isEmpty) return;
        final priceHistory = klines.map((c) => c.close).toList(growable: false);
        final price = klines.last.close;
        final volume = klines.last.volume;
        final data = MarketData(price: price, volume: volume, priceHistory: priceHistory);
        final signals = <StrategySignal>[];
        for (final s in hybridStrategiesService.strategies.where((e) => e.isActive)) {
          try {
            final sig = await s.analyze(data);
            signals.add(sig);
          } catch (e) {
            debugPrint('Hybrid analyze error (${s.name}): $e');
          }
        }
        if (mounted) setState(() => _liveSignals = signals);
      } catch (e) {
        debugPrint('Live feed error: $e');
      }
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  // removed old simulator (replaced with live feed based on selected symbol/interval)

  // removed unused _updateOrderTypePreference

  // removed unused _loadOrderTypePref

  // removed unused _saveOrderType

  // removed unused _showRiskAcknowledgmentDialog

  Future<void> _openEditParameters(HybridStrategy strategy) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
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
    // Persist params after editing
    final prefs = await SharedPreferences.getInstance();
    final key = 'strategy_params_' + strategy.name.replaceAll(RegExp(r'\s+'), '_').toLowerCase();
    Map<String, dynamic> m = {};
    if (strategy is RSIMLHybridStrategy) {
      m = {
        'oversold': strategy.oversold,
        'overbought': strategy.overbought,
        'buyRsi': strategy.buyRsi,
        'sellRsi': strategy.sellRsi,
      };
    } else if (strategy is DynamicGridBotStrategy) {
      m = {
        'gridSize': strategy.gridSize,
      };
    } else if (strategy is BreakoutStrategy) {
      m = {
        'lookback': strategy.lookback,
        'confidenceBase': strategy.confidenceBase,
      };
    } else if (strategy is MeanReversionStrategy) {
      m = {
        'period': strategy.period,
        'stdDev': strategy.stdDev,
      };
    }
    await prefs.setString(key, m.toString());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          child: Container(
            decoration: ScreenBackgrounds.market(context),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('AI Strategies', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Active Strategies'),
                    Tab(text: 'Discover New'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const RiskDisclaimer(),
                          const SizedBox(height: 12),
                          GlassCard(
                            padding: const EdgeInsets.all(16.0),
                            showGlow: true,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButton<String>(
                                          value: _selectedSymbol,
                                          isExpanded: true,
                                          underline: const SizedBox(),
                                          items: _buildPairs().map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                          onChanged: (v) {
                                            if (v == null) return;
                                            setState(() => _selectedSymbol = v);
                                            _startLiveFeed();
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Wrap(
                                        spacing: 6,
                                        children: [
                                          {'label': '15m', 'value': '15m'},
                                          {'label': '1H', 'value': '1h'},
                                          {'label': '4H', 'value': '4h'},
                                        ].map((item) {
                                          final bool sel = _interval == item['value'];
                                          return ChoiceChip(
                                            label: Text(item['label'] as String),
                                            selected: sel,
                                            onSelected: (_) {
                                              setState(() => _interval = item['value'] as String);
                                              _startLiveFeed();
                                            },
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('AI Model', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                      Icon(globalMlService.isInitialized ? Icons.check_circle : Icons.error_outline, color: globalMlService.isInitialized ? Colors.green : Colors.red),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(globalMlService.isInitialized ? 'Model loaded' : 'Model not loaded'),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    alignment: WrapAlignment.start,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: [
                                      ElevatedButton(
                                        onPressed: globalMlService.isInitialized ? _runInference : null,
                                        child: const Text('Run inference'),
                                      ),
                                      OutlinedButton(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(builder: (_) => const AiPredictionPage()),
                                          );
                                        },
                                        child: const Text('Open Prediction Page'),
                                      ),
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
                              ),
                                      if (_lastSignal != null && _lastProb != null)
                                        Text(
                                          'Signal: ' + _lastSignal!.name + '  |  P(BUY) = ' + _lastProb!.toStringAsFixed(3),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
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

                            return StrategyCard(
                              name: '${strategy.name} ${strategy.version}',
                              status: strategy.isActive ? 'Active' : 'Inactive',
                              performance: '${strategy.totalReturn >= 0 ? "+" : ""}${strategy.totalReturn.toStringAsFixed(1)}% (7D)',
                              isGain: strategy.totalReturn >= 0,
                              liveSignal: strategy.isActive ? signal : null,
                              onActivate: () {
                                setState(() {
                                  hybridStrategiesService.toggleStrategy(strategy.name, !strategy.isActive);
                                });
                              },
                              onEdit: () => _openEditParameters(strategy),
                            );
                          }),
                          if (hybridStrategiesService.strategies.where((s) => s.isActive).isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                          child: Text('No active strategies. Activate some from Discover New.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
                            ),
                        ],
                      ),
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          ...hybridStrategiesService.strategies.where((s) => !s.isActive).map((strategy) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: DiscoveryCard(
                                strategy: strategy,
                                markets: const <String>['BTC','WLFI','TRUMP'],
                                onActivate: () {
                                  setState(() {
                                    hybridStrategiesService.toggleStrategy(strategy.name, true);
                                  });
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StrategyCard extends StatelessWidget {
  final String name;
  final String status;
  final String performance;
  final bool isGain;
  final StrategySignal? liveSignal;
  final VoidCallback onActivate;
  final VoidCallback? onEdit;

  const StrategyCard({
    super.key,
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
    final theme = Theme.of(context);
    final perfColor = isGain ? theme.colorScheme.secondary : theme.colorScheme.error;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Status:', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
                Text(
                  status,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: status == 'Active' ? perfColor : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Performance:', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
                Text(performance, style: theme.textTheme.bodyMedium?.copyWith(color: perfColor, fontWeight: FontWeight.bold)),
              ],
            ),
            if (liveSignal != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getSignalColor(liveSignal!.type, theme).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getSignalColor(liveSignal!.type, theme),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getSignalIcon(liveSignal!.type),
                          color: _getSignalColor(liveSignal!.type, theme),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          liveSignal!.type.name,
                          style: TextStyle(
                            color: _getSignalColor(liveSignal!.type, theme),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getSignalColor(liveSignal!.type, theme),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${(liveSignal!.confidence * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      liveSignal!.reason,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(onPressed: onEdit, child: const Text('Edit Parameters')),
                ElevatedButton(
                  onPressed: onActivate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: status == 'Active' ? Colors.grey : theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(status == 'Active' ? 'Deactivate' : 'Activate'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Color _getSignalColor(SignalType type, ThemeData theme) {
    switch (type) {
      case SignalType.BUY:
        return theme.colorScheme.secondary;
      case SignalType.SELL:
        return theme.colorScheme.error;
      case SignalType.HOLD:
        return Colors.orange;
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

class _StrategyParamsSheet extends StatefulWidget {
  final HybridStrategy strategy;
  const _StrategyParamsSheet({required this.strategy});

  @override
  State<_StrategyParamsSheet> createState() => _StrategyParamsSheetState();
}

class _StrategyParamsSheetState extends State<_StrategyParamsSheet> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Edit Parameters - ' + widget.strategy.name, style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        if (widget.strategy is RSIMLHybridStrategy) ..._buildRsiMl(),
        if (widget.strategy is DynamicGridBotStrategy) ..._buildGrid(),
        if (widget.strategy is BreakoutStrategy) ..._buildBreakout(),
        if (widget.strategy is MeanReversionStrategy) ..._buildMeanRev(),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        )
      ],
    );
  }

  List<Widget> _buildRsiMl() {
    final s = widget.strategy as RSIMLHybridStrategy;
    return [
      Row(children: [Expanded(child: const Text('RSI oversold')), SizedBox(width: 120, child: TextFormField(initialValue: s.oversold.toString(), keyboardType: const TextInputType.numberWithOptions(decimal: false), onChanged: (v) => s.oversold = int.tryParse(v) ?? s.oversold))]),
      const SizedBox(height: 8),
      Row(children: [Expanded(child: const Text('RSI overbought')), SizedBox(width: 120, child: TextFormField(initialValue: s.overbought.toString(), keyboardType: const TextInputType.numberWithOptions(decimal: false), onChanged: (v) => s.overbought = int.tryParse(v) ?? s.overbought))]),
      const SizedBox(height: 8),
      Row(children: [Expanded(child: const Text('Buy RSI')), SizedBox(width: 120, child: TextFormField(initialValue: s.buyRsi.toString(), keyboardType: const TextInputType.numberWithOptions(decimal: false), onChanged: (v) => s.buyRsi = int.tryParse(v) ?? s.buyRsi))]),
      const SizedBox(height: 8),
      Row(children: [Expanded(child: const Text('Sell RSI')), SizedBox(width: 120, child: TextFormField(initialValue: s.sellRsi.toString(), keyboardType: const TextInputType.numberWithOptions(decimal: false), onChanged: (v) => s.sellRsi = int.tryParse(v) ?? s.sellRsi))]),
    ];
  }

  List<Widget> _buildGrid() {
    final s = widget.strategy as DynamicGridBotStrategy;
    return [
      Row(children: [Expanded(child: const Text('Grid Size (%)')), SizedBox(width: 120, child: TextFormField(initialValue: s.gridSize.toStringAsFixed(2), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) => s.gridSize = double.tryParse(v) ?? s.gridSize))]),
    ];
  }

  List<Widget> _buildBreakout() {
    final s = widget.strategy as BreakoutStrategy;
    return [
      Row(children: [Expanded(child: const Text('Lookback')), SizedBox(width: 120, child: TextFormField(initialValue: s.lookback.toString(), keyboardType: const TextInputType.numberWithOptions(decimal: false), onChanged: (v) => s.lookback = int.tryParse(v) ?? s.lookback))]),
      const SizedBox(height: 8),
      Row(children: [Expanded(child: const Text('Confidence Base')), SizedBox(width: 120, child: TextFormField(initialValue: s.confidenceBase.toStringAsFixed(2), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) => s.confidenceBase = double.tryParse(v) ?? s.confidenceBase))]),
    ];
  }

  List<Widget> _buildMeanRev() {
    final s = widget.strategy as MeanReversionStrategy;
    return [
      Row(children: [Expanded(child: const Text('Period')), SizedBox(width: 120, child: TextFormField(initialValue: s.period.toString(), keyboardType: const TextInputType.numberWithOptions(decimal: false), onChanged: (v) => s.period = int.tryParse(v) ?? s.period))]),
      const SizedBox(height: 8),
      Row(children: [Expanded(child: const Text('Std Dev')), SizedBox(width: 120, child: TextFormField(initialValue: s.stdDev.toStringAsFixed(2), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) => s.stdDev = double.tryParse(v) ?? s.stdDev))]),
    ];
  }
}

