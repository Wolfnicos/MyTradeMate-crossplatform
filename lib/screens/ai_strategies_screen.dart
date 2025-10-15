import 'package:flutter/material.dart';
import '../widgets/risk_disclaimer.dart';
import '../ml/ml_service.dart';
import '../services/hybrid_strategies_service.dart';
import 'ai_prediction_page.dart';
import 'dart:math';

class AiStrategiesScreen extends StatefulWidget {
  const AiStrategiesScreen({super.key});

  @override
  State<AiStrategiesScreen> createState() => _AiStrategiesScreenState();
}

class _AiStrategiesScreenState extends State<AiStrategiesScreen> {
  double? _lastProb;
  TradingSignal? _lastSignal;
  List<StrategySignal>? _liveSignals;

  @override
  void initState() {
    super.initState();
    _simulateLiveTrading();
  }

  Future<void> _runInference() async {
    if (!globalMlService.isInitialized) return;
    final int w = globalMlService.windowSize;
    final int f = globalMlService.numFeatures;
    // Example placeholder raw input; replace with real features window
    final List<List<double>> rawInput = List<List<double>>.generate(
      w,
      (_) => List<double>.filled(f, 0.0),
    );
    final Map<String, dynamic> result = globalMlService.getSignal(rawInput);
    final List<double> probs = (result['probabilities'] as List<dynamic>).cast<double>();
    setState(() {
      _lastProb = probs.length > 2 ? probs[2] : null; // BUY probability
      _lastSignal = result['signal'] as TradingSignal?;
    });
  }

  /// Simulate live trading by generating market data
  void _simulateLiveTrading() async {
    final random = Random();
    double basePrice = 34500.0;
    final priceHistory = List<double>.generate(100, (i) {
      basePrice += (random.nextDouble() - 0.5) * 200;
      return basePrice;
    });

    // Produce an initial set of signals immediately (avoid 0% placeholders)
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

      // Generate new price
      basePrice += (random.nextDouble() - 0.5) * 200;
      priceHistory.add(basePrice);
      if (priceHistory.length > 100) priceHistory.removeAt(0);

      // Create market data
      final marketData = MarketData(
        price: basePrice,
        volume: 1000 + random.nextDouble() * 500,
        priceHistory: List<double>.from(priceHistory),
      );

      // Analyze with all active strategies
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
                // TODO: activate the AI strategy here
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          child: Column(
          children: [
            // Header with title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('AI Strategies', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ),
            // TabBar
            const TabBar(
              tabs: [
                Tab(text: 'Active Strategies'),
                Tab(text: 'Discover New'),
              ],
            ),
            // TabBarView
            Expanded(
              child: TabBarView(
          children: [
            // Tab-ul "Active Strategies"
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
                ...hybridStrategiesService.strategies.map((strategy) {
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
                  );
                }),
              ],
            ),
            // Tab-ul "Discover New" - placeholder
            const Center(child: Text('Discover new AI strategies here.')),
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

  const StrategyCard({
    super.key,
    required this.name,
    required this.status,
    required this.performance,
    required this.isGain,
    this.liveSignal,
    required this.onActivate,
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
                TextButton(onPressed: () {}, child: const Text('Edit Parameters')),
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

