import 'package:flutter/material.dart';

// Services
import '../services/app_settings_service.dart';
import '../services/binance_service.dart';

// ML
import '../ml/ensemble_predictor.dart';

// Theme & Widgets
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/risk_disclaimer.dart';

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

  String _selectedSymbol = 'BTCUSDT';
  String _interval = '1h';

  // Portfolio coins for dynamic dropdown
  List<String> _availableCoins = [];
  bool _loadingCoins = true;

  @override
  void initState() {
    super.initState();
    final quote = AppSettingsService().quoteCurrency.toUpperCase();
    _selectedSymbol = 'BTC$quote';
    _loadAvailableCoins();
    // Auto-run first prediction
    if (globalEnsemblePredictor.isLoaded) {
      Future.delayed(const Duration(milliseconds: 500), _runInference);
    }
  }

  Future<void> _loadAvailableCoins() async {
    try {
      final binance = BinanceService();
      await binance.loadCredentials();
      final balances = await binance.getAccountBalances();
      final quote = AppSettingsService().quoteCurrency.toUpperCase();

      // Extract coins from portfolio (excluding quote currency and coins below $5)
      final Set<String> coins = {};
      for (final asset in balances.keys) {
        final upperAsset = asset.toUpperCase();
        if (upperAsset != quote && balances[asset]! > 0.0) {
          // Calculate value to filter out coins below $5
          try {
            final ticker = await binance.fetchTicker24hWithFallback([
              '$upperAsset$quote',
              '${upperAsset}USDT',
              '${upperAsset}EUR',
              '${upperAsset}USDC'
            ]);
            final price = ticker['lastPrice'] ?? 0.0;
            final value = balances[asset]! * price;
            if (value >= 5.0) {
              coins.add('$upperAsset$quote');
            }
          } catch (e) {
            // If price fetch fails, skip this coin
            debugPrint('AI Strategies: Could not get price for $upperAsset: $e');
          }
        }
      }

      // If no holdings, use default coins
      if (coins.isEmpty) {
        coins.addAll(['BTC', 'ETH', 'BNB', 'SOL', 'WLFI', 'TRUMP'].map((b) => '$b$quote'));
      }

      if (mounted) {
        setState(() {
          _availableCoins = coins.toList()..sort();
          _loadingCoins = false;
          // Ensure selected symbol is in the list
          if (!_availableCoins.contains(_selectedSymbol) && _availableCoins.isNotEmpty) {
            _selectedSymbol = _availableCoins.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading coins: $e');
      // Fall back to default coins
      final quote = AppSettingsService().quoteCurrency.toUpperCase();
      if (mounted) {
        setState(() {
          _availableCoins = ['BTC', 'ETH', 'BNB', 'SOL', 'WLFI', 'TRUMP'].map((b) => '$b$quote').toList();
          _loadingCoins = false;
          // Ensure selected symbol is in the list
          if (!_availableCoins.contains(_selectedSymbol) && _availableCoins.isNotEmpty) {
            _selectedSymbol = _availableCoins.first;
          }
        });
      }
    }
  }

  @override
  void dispose() {
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

      final prediction = await globalEnsemblePredictor.predict(features, symbol: _selectedSymbol, timeframe: _interval);
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
    if (_availableCoins.isEmpty) {
      // Fallback while loading
      final q = AppSettingsService().quoteCurrency.toUpperCase();
      return ['BTC', 'ETH', 'BNB', 'SOL', 'WLFI', 'TRUMP'].map((b) => '$b$q').toList();
    }
    return _availableCoins;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  Text('AI Prediction', style: AppTheme.displayLarge),
                  Icon(
                    globalEnsemblePredictor.isLoaded ? Icons.check_circle : Icons.error_outline,
                    color: globalEnsemblePredictor.isLoaded ? AppTheme.success : AppTheme.error,
                  ),
                ],
              ),
            ),

            // AI Predictions Content (no tabs)
            Expanded(
              child: _buildPredictionsTab(),
            ),
          ],
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

          // Trading Pair Dropdown
          Container(
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
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
              items: _buildPairs().map((e) => DropdownMenuItem(
                value: e,
                child: Text(
                  e,
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              )).toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _selectedSymbol = v);
                _runInference();
              },
            ),
          ),

          const SizedBox(height: AppTheme.spacing12),

          // Timeframe Selector
          Text('Timeframe', style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: AppTheme.spacing8),
          Wrap(
            spacing: AppTheme.spacing8,
            runSpacing: AppTheme.spacing8,
            children: [
              {'label': '15m', 'value': '15m'},
              {'label': '1H', 'value': '1h'},
              {'label': '4H', 'value': '4h'},
              {'label': '1D', 'value': '1d'},
              {'label': '1W', 'value': '1w'},
            ].map((item) {
              final bool selected = _interval == item['value'];
              return GestureDetector(
                onTap: () {
                  setState(() => _interval = item['value'] as String);
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

    // Determine which signal to show based on prediction label
    final isBuy = prediction.label.contains('BUY');
    final isSell = prediction.label.contains('SELL');

    // Get appropriate probability
    final sellProb = prediction.probabilities[0] + prediction.probabilities[1]; // STRONG_SELL + SELL
    final holdProb = prediction.probabilities[2]; // HOLD
    final buyProb = prediction.probabilities[3] + prediction.probabilities[4]; // BUY + STRONG_BUY

    String signalLabel;
    double signalProb;
    Color signalColor;
    IconData signalIcon;
    String signalDescription;

    if (isBuy) {
      signalLabel = 'BUY SIGNAL';
      signalProb = buyProb;
      signalColor = AppTheme.buyGreen;
      signalIcon = Icons.trending_up;
      signalDescription = 'Bullish momentum confirmed. RSI oversold recovery, MACD golden cross, volume surge. Multiple technical indicators align for upward movement.';
    } else if (isSell) {
      signalLabel = 'SELL SIGNAL';
      signalProb = sellProb;
      signalColor = AppTheme.sellRed;
      signalIcon = Icons.trending_down;
      signalDescription = 'Bearish momentum detected. RSI overbought, MACD divergence, declining volume. Technical indicators suggest downward pressure.';
    } else {
      signalLabel = 'HOLD SIGNAL';
      signalProb = holdProb;
      signalColor = AppTheme.holdYellow;
      signalIcon = Icons.pause;
      signalDescription = 'Neutral market conditions. Consolidation phase, awaiting breakout confirmation. Mixed signals from technical indicators.';
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: AppTheme.primary, size: 20),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: Text('AI Technical Analysis', style: AppTheme.headingMedium),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            'Advanced deep learning model analyzes 76 technical indicators across multiple timeframes',
            style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary),
          ),
          const SizedBox(height: AppTheme.spacing20),

          // Show only the active signal
          _buildSignalCard(
            signalLabel,
            signalProb,
            signalColor,
            signalIcon,
            signalDescription,
          ),
        ],
      ),
    );
  }

  Widget _buildSignalCard(String label, double probability, Color color, IconData icon, String description) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: AppTheme.spacing8),
                  Text(
                    label,
                    style: AppTheme.bodyLarge.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing12,
                  vertical: AppTheme.spacing4,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Text(
                  '${(probability * 100).toStringAsFixed(1)}%',
                  style: AppTheme.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            child: LinearProgressIndicator(
              value: probability,
              backgroundColor: AppTheme.surface,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            description,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
