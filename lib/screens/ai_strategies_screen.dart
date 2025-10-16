import 'package:flutter/material.dart';
import '../widgets/risk_disclaimer.dart';
import '../ml/ml_service.dart';
import '../services/hybrid_strategies_service.dart';
import 'ai_prediction_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import '../services/binance_service.dart';

class AiStrategiesScreen extends StatefulWidget {
  const AiStrategiesScreen({super.key});

  @override
  State<AiStrategiesScreen> createState() => _AiStrategiesScreenState();
}

class _AiStrategiesScreenState extends State<AiStrategiesScreen> {
  double? _lastProb;
  TradingSignal? _lastSignal;
  List<StrategySignal>? _liveSignals;
  String _orderType = 'market'; // 'hybrid' | 'ai_model' | 'market'

  @override
  void initState() {
    super.initState();
    _simulateLiveTrading();
    _loadOrderTypePref();
    _syncOrderTypePref();
  }

  Future<void> _syncOrderTypePref() async {
    final bool anyActive = hybridStrategiesService.strategies.any((s) => s.isActive);
    final prefs = await SharedPreferences.getInstance();
    if (anyActive) {
      await prefs.setString('order_type', 'hybrid');
      setState(() => _orderType = 'hybrid');
    }
  }

  Future<void> _runInference() async {
    if (!globalMlService.isInitialized) return;
    try {
      const String symbol = 'BTCUSDT';
      const String interval = '1h';
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

  void _simulateLiveTrading() async {
    final random = Random();
    double basePrice = 34500.0;
    final priceHistory = List<double>.generate(100, (i) {
      basePrice += (random.nextDouble() - 0.5) * 200;
      return basePrice;
    });

    // Initial snapshot
    {
      final marketData = MarketData(
        price: basePrice,
        volume: 1000 + random.nextDouble() * 500,
        priceHistory: List<double>.from(priceHistory),
      );
      final signals = <StrategySignal>[];
      for (final strategy in hybridStrategiesService.strategies.where((s) => s.isActive)) {
        final signal = await strategy.analyze(marketData);
        signals.add(signal);
      }
      if (mounted) {
        setState(() {
          _liveSignals = signals;
        });
      }
    }

    while (mounted) {
      await Future.delayed(const Duration(seconds: 3));
      basePrice += (random.nextDouble() - 0.5) * 200;
      priceHistory.add(basePrice);
      if (priceHistory.length > 100) priceHistory.removeAt(0);

      final marketData = MarketData(
        price: basePrice,
        volume: 1000 + random.nextDouble() * 500,
        priceHistory: List<double>.from(priceHistory),
      );

      final signals = <StrategySignal>[];
      for (final strategy in hybridStrategiesService.strategies.where((s) => s.isActive)) {
        final signal = await strategy.analyze(marketData);
        signals.add(signal);
      }

      if (mounted) {
        setState(() {
          _liveSignals = signals;
        });
      }
    }
  }

  Future<void> _updateOrderTypePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final bool anyActive = hybridStrategiesService.strategies.any((s) => s.isActive);
    if (anyActive) {
      await prefs.setString('order_type', 'hybrid');
      setState(() => _orderType = 'hybrid');
    } else {
      final String current = prefs.getString('order_type') ?? 'market';
      if (current == 'hybrid') {
        await prefs.setString('order_type', 'market');
        setState(() => _orderType = 'market');
      }
    }
  }

  Future<void> _loadOrderTypePref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _orderType = prefs.getString('order_type') ?? 'market');
  }

  Future<void> _saveOrderType(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('order_type', value);
    setState(() => _orderType = value);
  }

  void _showRiskAcknowledgmentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Acknowledge Risk'),
          content: const Text('Automated trading involves significant risk and is not guaranteed to be profitable. Do you wish to proceed?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('I Understand & Proceed'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

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
                // Order Type selector moved to Orders screen per spec
                const RiskDisclaimer(),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                      _updateOrderTypePreference();
                    },
                    onEdit: () => _openEditParameters(strategy),
                  );
                }),
                if (hybridStrategiesService.strategies.where((s) => s.isActive).isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('No active strategies. Activate some from Discover New.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                  ),
              ],
            ),
            // Discover New
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...hybridStrategiesService.strategies.where((s) => !s.isActive).map((strategy) {
                  return StrategyCard(
                    name: '${strategy.name} ${strategy.version}',
                    status: 'Inactive',
                    performance: '${strategy.totalReturn >= 0 ? "+" : ""}${strategy.totalReturn.toStringAsFixed(1)}% (7D)',
                    isGain: strategy.totalReturn >= 0,
                    liveSignal: null,
                    onActivate: () {
                      setState(() {
                        hybridStrategiesService.toggleStrategy(strategy.name, true);
                      });
                      _updateOrderTypePreference();
                    },
                    onEdit: () => _openEditParameters(strategy),
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
                Text('Status:', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
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
                Text('Performance:', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
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

