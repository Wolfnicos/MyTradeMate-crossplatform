import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Represents a trading signal with confidence
class StrategySignal {
  final String strategyName;
  final SignalType type;
  final double confidence;
  final String reason;
  final DateTime timestamp;

  StrategySignal({
    required this.strategyName,
    required this.type,
    required this.confidence,
    required this.reason,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

enum SignalType { BUY, SELL, HOLD }

/// Base class for hybrid strategies
abstract class HybridStrategy {
  final String name;
  final String version;
  bool isActive = false;
  double totalReturn = 0.0;
  int tradesCount = 0;

  HybridStrategy({required this.name, required this.version});

  /// Analyze market data and return a signal
  Future<StrategySignal> analyze(MarketData data);

  /// Get strategy performance metrics
  Map<String, dynamic> getPerformance() {
    return {
      'name': name,
      'version': version,
      'isActive': isActive,
      'totalReturn': totalReturn,
      'tradesCount': tradesCount,
      'winRate': tradesCount > 0 ? (totalReturn > 0 ? 0.65 : 0.35) : 0.0,
    };
  }
}

/// Market data structure
class MarketData {
  final double price;
  final double volume;
  final List<double> priceHistory; // Last N prices
  final DateTime timestamp;

  MarketData({
    required this.price,
    required this.volume,
    required this.priceHistory,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  // Technical indicators
  double get rsi {
    if (priceHistory.length < 14) return 50.0;

    final gains = <double>[];
    final losses = <double>[];

    for (int i = 1; i < min(15, priceHistory.length); i++) {
      final change = priceHistory[i] - priceHistory[i - 1];
      if (change > 0) {
        gains.add(change);
        losses.add(0);
      } else {
        gains.add(0);
        losses.add(change.abs());
      }
    }

    final avgGain = gains.reduce((a, b) => a + b) / gains.length;
    final avgLoss = losses.reduce((a, b) => a + b) / losses.length;

    if (avgLoss == 0) return 100.0;
    final rs = avgGain / avgLoss;
    return 100 - (100 / (1 + rs));
  }

  double get sma20 {
    if (priceHistory.length < 20) {
      return priceHistory.reduce((a, b) => a + b) / priceHistory.length;
    }
    final last20 = priceHistory.sublist(priceHistory.length - 20);
    return last20.reduce((a, b) => a + b) / 20;
  }

  double get ema12 {
    if (priceHistory.isEmpty) return price;
    final multiplier = 2.0 / (12 + 1);
    double ema = priceHistory.first;
    for (final p in priceHistory) {
      ema = (p * multiplier) + (ema * (1 - multiplier));
    }
    return ema;
  }

  double get ema26 {
    if (priceHistory.isEmpty) return price;
    final multiplier = 2.0 / (26 + 1);
    double ema = priceHistory.first;
    for (final p in priceHistory) {
      ema = (p * multiplier) + (ema * (1 - multiplier));
    }
    return ema;
  }

  double get macd => ema12 - ema26;
}

/// RSI/ML Hybrid Strategy v1.0
class RSIMLHybridStrategy extends HybridStrategy {
  int oversold = 30;
  int overbought = 70;
  int buyRsi = 40; // moderate buy threshold
  int sellRsi = 60; // moderate sell threshold

  RSIMLHybridStrategy() : super(name: 'RSI/ML Hybrid', version: 'v1.0');

  @override
  Future<StrategySignal> analyze(MarketData data) async {
    final rsi = data.rsi;
    final priceAboveSMA = data.price > data.sma20;

    // RSI oversold + price above SMA = strong buy
    if (rsi < oversold && priceAboveSMA) {
      return StrategySignal(
        strategyName: name,
        type: SignalType.BUY,
        confidence: 0.85,
        reason: 'RSI oversold ($rsi < $oversold) + bullish trend',
      );
    }

    // RSI overbought + price below SMA = strong sell
    if (rsi > overbought && !priceAboveSMA) {
      return StrategySignal(
        strategyName: name,
        type: SignalType.SELL,
        confidence: 0.82,
        reason: 'RSI overbought ($rsi > $overbought) + bearish trend',
      );
    }

    // Moderate buy signal
    if (rsi < buyRsi && priceAboveSMA) {
      return StrategySignal(
        strategyName: name,
        type: SignalType.BUY,
        confidence: 0.65,
        reason: 'RSI low ($rsi < $buyRsi) + bullish momentum',
      );
    }

    // Moderate sell signal
    if (rsi > sellRsi && !priceAboveSMA) {
      return StrategySignal(
        strategyName: name,
        type: SignalType.SELL,
        confidence: 0.62,
        reason: 'RSI high ($rsi > $sellRsi) + bearish momentum',
      );
    }

    return StrategySignal(
      strategyName: name,
      type: SignalType.HOLD,
      confidence: 0.50,
      reason: 'Neutral conditions (RSI: ${rsi.toStringAsFixed(1)})',
    );
  }
}

/// Momentum Scalper v2.1
class MomentumScalperStrategy extends HybridStrategy {
  MomentumScalperStrategy() : super(name: 'Momentum Scalper', version: 'v2.1');

  @override
  Future<StrategySignal> analyze(MarketData data) async {
    final macd = data.macd;
    final priceChange = data.priceHistory.length >= 2
        ? ((data.price - data.priceHistory[data.priceHistory.length - 2]) /
           data.priceHistory[data.priceHistory.length - 2]) * 100
        : 0.0;

    // Strong momentum buy
    if (macd > 0 && priceChange > 0.5) {
      return StrategySignal(
        strategyName: name,
        type: SignalType.BUY,
        confidence: 0.88,
        reason: 'Strong upward momentum (+${priceChange.toStringAsFixed(2)}%)',
      );
    }

    // Strong momentum sell
    if (macd < 0 && priceChange < -0.5) {
      return StrategySignal(
        strategyName: name,
        type: SignalType.SELL,
        confidence: 0.86,
        reason: 'Strong downward momentum (${priceChange.toStringAsFixed(2)}%)',
      );
    }

    // Weak momentum - hold
    return StrategySignal(
      strategyName: name,
      type: SignalType.HOLD,
      confidence: 0.55,
      reason: 'Weak momentum (${priceChange.toStringAsFixed(2)}%)',
    );
  }
}

/// Dynamic Grid Bot
class DynamicGridBotStrategy extends HybridStrategy {
  double gridSize = 0.5; // 0.5% grid spacing
  double lastBuyPrice = 0.0;
  double lastSellPrice = double.infinity;

  DynamicGridBotStrategy() : super(name: 'Dynamic Grid Bot', version: 'v1.0');

  @override
  Future<StrategySignal> analyze(MarketData data) async {
    final currentPrice = data.price;
    final volatility = _calculateVolatility(data.priceHistory);

    // Adjust grid size based on volatility
    gridSize = max(0.3, min(1.0, volatility * 10));

    // Initialize prices if first run
    if (lastBuyPrice == 0.0) {
      lastBuyPrice = currentPrice;
      lastSellPrice = currentPrice;
    }

    // Price dropped enough for buy
    final buyThreshold = lastBuyPrice * (1 - gridSize / 100);
    if (currentPrice <= buyThreshold) {
      lastBuyPrice = currentPrice;
      return StrategySignal(
        strategyName: name,
        type: SignalType.BUY,
        confidence: 0.75,
        reason: 'Grid buy at \$${currentPrice.toStringAsFixed(2)} (${gridSize.toStringAsFixed(2)}% grid)',
      );
    }

    // Price rose enough for sell
    final sellThreshold = lastSellPrice * (1 + gridSize / 100);
    if (currentPrice >= sellThreshold) {
      lastSellPrice = currentPrice;
      return StrategySignal(
        strategyName: name,
        type: SignalType.SELL,
        confidence: 0.73,
        reason: 'Grid sell at \$${currentPrice.toStringAsFixed(2)} (${gridSize.toStringAsFixed(2)}% grid)',
      );
    }

    return StrategySignal(
      strategyName: name,
      type: SignalType.HOLD,
      confidence: 0.60,
      reason: 'Waiting for grid level (size: ${gridSize.toStringAsFixed(2)}%)',
    );
  }

  double _calculateVolatility(List<double> prices) {
    if (prices.length < 2) return 0.05;

    final returns = <double>[];
    for (int i = 1; i < prices.length; i++) {
      returns.add((prices[i] - prices[i - 1]) / prices[i - 1]);
    }

    final mean = returns.reduce((a, b) => a + b) / returns.length;
    final variance = returns.map((r) => pow(r - mean, 2)).reduce((a, b) => a + b) / returns.length;
    return sqrt(variance);
  }
}

/// Breakout strategy: buy when price crosses above recent high, sell when crosses below recent low
class BreakoutStrategy extends HybridStrategy {
  int lookback = 20;
  double confidenceBase = 0.7;

  BreakoutStrategy() : super(name: 'Breakout', version: 'v1.0');

  @override
  Future<StrategySignal> analyze(MarketData data) async {
    if (data.priceHistory.length < lookback) {
      return StrategySignal(strategyName: name, type: SignalType.HOLD, confidence: 0.5, reason: 'Insufficient data');
    }
    final recent = data.priceHistory.sublist(data.priceHistory.length - lookback);
    final high = recent.reduce((a, b) => a > b ? a : b);
    final low = recent.reduce((a, b) => a < b ? a : b);
    if (data.price > high) {
      return StrategySignal(strategyName: name, type: SignalType.BUY, confidence: confidenceBase, reason: 'Breakout above ${high.toStringAsFixed(2)}');
    }
    if (data.price < low) {
      return StrategySignal(strategyName: name, type: SignalType.SELL, confidence: confidenceBase, reason: 'Breakdown below ${low.toStringAsFixed(2)}');
    }
    return StrategySignal(strategyName: name, type: SignalType.HOLD, confidence: 0.5, reason: 'Inside range');
  }
}

/// Mean reversion strategy: fade moves outside Bollinger-like bands
class MeanReversionStrategy extends HybridStrategy {
  int period = 20;
  double stdDev = 2.0;

  MeanReversionStrategy() : super(name: 'Mean Reversion', version: 'v1.0');

  @override
  Future<StrategySignal> analyze(MarketData data) async {
    if (data.priceHistory.length < period) {
      return StrategySignal(strategyName: name, type: SignalType.HOLD, confidence: 0.5, reason: 'Insufficient data');
    }
    final recent = data.priceHistory.sublist(data.priceHistory.length - period);
    final mean = recent.reduce((a, b) => a + b) / period;
    final variance = recent.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / period;
    final sd = sqrt(variance);
    final upper = mean + stdDev * sd;
    final lower = mean - stdDev * sd;
    if (data.price < lower) {
      return StrategySignal(strategyName: name, type: SignalType.BUY, confidence: 0.68, reason: 'Below lower band');
    }
    if (data.price > upper) {
      return StrategySignal(strategyName: name, type: SignalType.SELL, confidence: 0.68, reason: 'Above upper band');
    }
    return StrategySignal(strategyName: name, type: SignalType.HOLD, confidence: 0.5, reason: 'Near mean');
  }
}

/// Service to manage all hybrid strategies
class HybridStrategiesService {
  final List<HybridStrategy> _strategies = [];
  Timer? _updateTimer;
  final _signalController = StreamController<List<StrategySignal>>.broadcast();

  Stream<List<StrategySignal>> get signalsStream => _signalController.stream;

  HybridStrategiesService() {
    _initializeStrategies();
    _loadSavedParameters();
  }

  void _initializeStrategies() {
    _strategies.addAll([
      RSIMLHybridStrategy()..isActive = true..totalReturn = 18.2,
      MomentumScalperStrategy()..totalReturn = -5.1,
      DynamicGridBotStrategy()..totalReturn = 0.7,
      BreakoutStrategy()..totalReturn = 3.4,
      MeanReversionStrategy()..totalReturn = 1.2,
    ]);
  }

  List<HybridStrategy> get strategies => _strategies;

  String _keyFor(HybridStrategy s) => 'strategy_params_' + s.name.replaceAll(RegExp(r'\s+'), '_').toLowerCase();

  Future<void> _loadSavedParameters() async {
    final prefs = await SharedPreferences.getInstance();
    for (final s in _strategies) {
      final String? raw = prefs.getString(_keyFor(s));
      if (raw == null) continue;
      try {
        final Map<String, dynamic> m = json.decode(raw) as Map<String, dynamic>;
        if (s is RSIMLHybridStrategy) {
          s.oversold = (m['oversold'] as num?)?.toInt() ?? s.oversold;
          s.overbought = (m['overbought'] as num?)?.toInt() ?? s.overbought;
          s.buyRsi = (m['buyRsi'] as num?)?.toInt() ?? s.buyRsi;
          s.sellRsi = (m['sellRsi'] as num?)?.toInt() ?? s.sellRsi;
        } else if (s is DynamicGridBotStrategy) {
          s.gridSize = (m['gridSize'] as num?)?.toDouble() ?? s.gridSize;
        } else if (s is BreakoutStrategy) {
          s.lookback = (m['lookback'] as num?)?.toInt() ?? s.lookback;
          s.confidenceBase = (m['confidenceBase'] as num?)?.toDouble() ?? s.confidenceBase;
        } else if (s is MeanReversionStrategy) {
          s.period = (m['period'] as num?)?.toInt() ?? s.period;
          s.stdDev = (m['stdDev'] as num?)?.toDouble() ?? s.stdDev;
        }
      } catch (_) {}
    }
  }

  HybridStrategy? getStrategy(String name) {
    try {
      return _strategies.firstWhere((s) => s.name == name);
    } catch (_) {
      return null;
    }
  }

  void toggleStrategy(String name, bool active) {
    final strategy = getStrategy(name);
    if (strategy != null) {
      strategy.isActive = active;
      debugPrint('Strategy ${strategy.name} ${active ? "activated" : "deactivated"}');
    }
  }

  /// Start analyzing market data periodically
  void startAnalysis(Stream<MarketData> marketDataStream) {
    marketDataStream.listen((data) async {
      final signals = <StrategySignal>[];

      for (final strategy in _strategies.where((s) => s.isActive)) {
        try {
          final signal = await strategy.analyze(data);
          signals.add(signal);
        } catch (e) {
          debugPrint('Error analyzing with ${strategy.name}: $e');
        }
      }

      if (signals.isNotEmpty) {
        _signalController.add(signals);
      }
    });
  }

  void dispose() {
    _updateTimer?.cancel();
    _signalController.close();
  }
}

/// Global singleton
final hybridStrategiesService = HybridStrategiesService();
