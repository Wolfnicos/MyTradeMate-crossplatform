import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Ensemble Predictor for MyTradeMate
///
/// Combines 3 AI models with weighted voting:
/// - Transformer (50% weight): Best for complex temporal patterns (40.77% accuracy)
/// - LSTM (30% weight): Strong at sequential dependencies
/// - Random Forest (20% weight): Interpretable baseline
///
/// This ensemble approach reduces overfitting and improves generalization
/// by leveraging strengths of different model architectures.
///
/// Input: 60 timesteps × 76 features (25 candle patterns + 51 technical indicators)
/// Output: 5-class probabilities [STRONG_SELL, SELL, HOLD, BUY, STRONG_BUY]
///
/// Example:
/// ```dart
/// final predictor = EnsemblePredictor();
/// await predictor.loadModels();
///
/// final prediction = await predictor.predict(featureMatrix);
/// print(prediction.label); // "BUY"
/// print(prediction.confidence); // 0.78
/// ```
class EnsemblePredictor {
  // TFLite interpreters
  Interpreter? _transformerModel;
  Interpreter? _lstmModel;
  Interpreter? _randomForestModel; // Note: RF will use fallback if not TFLite

  // Legacy fallback models
  Interpreter? _legacyTcnModel;

  // Model weights (sum to 1.0)
  static const double _transformerWeight = 0.50;
  static const double _lstmWeight = 0.30;
  static const double _randomForestWeight = 0.20;

  // Model load status
  bool _isLoaded = false;
  final Map<String, bool> _modelStatus = {
    'transformer': false,
    'lstm': false,
    'randomForest': false,
  };

  // Performance metrics
  final Map<String, double> _modelLatency = {};
  final Map<String, int> _modelErrors = {};
  bool _useLegacyFallback = false;

  // Class labels (5 classes to match training)
  static const List<String> _classLabels = [
    'STRONG_SELL', // 0
    'SELL', // 1
    'HOLD', // 2
    'BUY', // 3
    'STRONG_BUY', // 4
  ];

  /// Load all ensemble models
  ///
  /// Attempts to load Transformer, LSTM, and Random Forest TFLite models.
  /// Falls back gracefully if some models are missing.
  Future<void> loadModels() async {
    debugPrint('🤖 Loading ensemble models...');

    try {
      // Load Transformer
      await _loadTransformerModel();
    } catch (e) {
      debugPrint('⚠️ Failed to load Transformer: $e');
    }

    try {
      // Load LSTM
      await _loadLstmModel();
    } catch (e) {
      debugPrint('⚠️ Failed to load LSTM: $e');
    }

    try {
      // Load Random Forest (optional, can use rule-based fallback)
      await _loadRandomForestModel();
    } catch (e) {
      debugPrint('⚠️ Failed to load Random Forest: $e (will use fallback)');
    }

    _isLoaded = _modelStatus.values.any((status) => status);

    if (!_isLoaded) {
      throw Exception('❌ No models loaded! Ensure TFLite models exist in assets/ml/');
    }

    // Load legacy fallback if new models fail
    if (!_isLoaded) {
      debugPrint('⚠️ New models failed, loading legacy TCN fallback...');
      try {
        await _loadLegacyTcnModel();
        _useLegacyFallback = true;
        _isLoaded = true;
      } catch (e) {
        debugPrint('❌ Legacy fallback also failed: $e');
      }
    }

    debugPrint('✅ Ensemble models loaded:');
    debugPrint('   Transformer: ${(_modelStatus['transformer'] ?? false) ? "✅" : "❌"}');
    debugPrint('   LSTM: ${(_modelStatus['lstm'] ?? false) ? "✅" : "❌"}');
    debugPrint('   Random Forest: ${(_modelStatus['randomForest'] ?? false) ? "✅" : "❌ (fallback)"}');
    if (_useLegacyFallback) {
      debugPrint('   💡 Using Legacy TCN Fallback');
    }
  }

  /// Load Transformer model
  Future<void> _loadTransformerModel() async {
    _transformerModel = await Interpreter.fromAsset('assets/models/transformer_crypto_model.tflite');
    _modelStatus['transformer'] = true;
    debugPrint('   ✅ Transformer loaded (40.77% accuracy on 76 features)');
  }

  /// Load LSTM model
  Future<void> _loadLstmModel() async {
    try {
      // LSTM uses Flex ops - try loading directly first
      _lstmModel = await Interpreter.fromAsset('assets/models/lstm_crypto_model.tflite');
      _modelStatus['lstm'] = true;
      debugPrint('   ✅ LSTM loaded (trained on 76 features)');
    } catch (e) {
      // If loading fails, try with options
      try {
        debugPrint('   ⚠️ LSTM direct load failed, trying with options...');
        final options = InterpreterOptions()..threads = 2;
        _lstmModel = await Interpreter.fromAsset(
          'assets/models/lstm_crypto_model.tflite',
          options: options,
        );
        _modelStatus['lstm'] = true;
        debugPrint('   ✅ LSTM loaded (with options)');
      } catch (e2) {
        debugPrint('   ❌ LSTM load failed completely: $e2');
        rethrow;
      }
    }
  }

  /// Load Random Forest model (if available as TFLite)
  Future<void> _loadRandomForestModel() async {
    // Note: Random Forest usually saved as .pkl (scikit-learn)
    // For mobile, we either:
    // 1. Convert to TFLite (if using TensorFlow Decision Forests)
    // 2. Use a fallback rule-based approach
    // 3. Implement lightweight RF in Dart

    // For now, use fallback (mark as not loaded)
    _modelStatus['randomForest'] = false;
    debugPrint('   ⚠️ Random Forest: Using rule-based fallback');
  }

  /// Load legacy TCN model as fallback
  Future<void> _loadLegacyTcnModel() async {
    _legacyTcnModel = await Interpreter.fromAsset('assets/models/legacy/mytrademate_v8_tcn_mtf_float32.tflite');
    debugPrint('   ✅ Legacy TCN loaded (v8)');
  }

  /// Predict using ensemble voting
  ///
  /// Args:
  ///   features: [60, 76] feature matrix (60 timesteps × 76 features)
  ///
  /// Returns:
  ///   EnsemblePrediction with weighted consensus
  Future<EnsemblePrediction> predict(List<List<double>> features) async {
    if (!_isLoaded) {
      throw Exception('Models not loaded. Call loadModels() first.');
    }

    // Validate input shape
    if (features.length != 60 || features[0].length != 76) {
      throw Exception('Invalid input shape: ${features.length}x${features[0].length}. Expected 60x76 (60 timesteps × 76 features)');
    }

    debugPrint('✅ Input shape validated: ${features.length}x${features[0].length}');

    // Get predictions from each model
    final transformerProbs = await _predictTransformer(features);
    final lstmProbs = await _predictLstm(features);
    final rfProbs = await _predictRandomForest(features);

    // 🔍 DEBUG: Print raw model outputs
    debugPrint('🔍 RAW MODEL OUTPUTS:');
    debugPrint('   Transformer: [${transformerProbs.map((p) => (p * 100).toStringAsFixed(1)).join(', ')}]');
    debugPrint('   LSTM: [${lstmProbs.map((p) => (p * 100).toStringAsFixed(1)).join(', ')}]');
    debugPrint('   RF: [${rfProbs.map((p) => (p * 100).toStringAsFixed(1)).join(', ')}]');

    // Weighted voting
    final ensembleProbs = _weightedVoting(
      transformerProbs: transformerProbs,
      lstmProbs: lstmProbs,
      rfProbs: rfProbs,
    );

    // 🔍 DEBUG: Print weighted ensemble result
    debugPrint('🔍 ENSEMBLE RESULT: [${ensembleProbs.map((p) => (p * 100).toStringAsFixed(1)).join(', ')}]');

    // Get final prediction
    final maxIndex = ensembleProbs.indexOf(ensembleProbs.reduce((a, b) => a > b ? a : b));
    final confidence = ensembleProbs[maxIndex];

    debugPrint('🔍 FINAL: ${_classLabels[maxIndex]} (${(confidence * 100).toStringAsFixed(1)}%)');

    return EnsemblePrediction(
      label: _classLabels[maxIndex],
      classIndex: maxIndex,
      confidence: confidence,
      probabilities: ensembleProbs,
      modelContributions: {
        'transformer': transformerProbs,
        'lstm': lstmProbs,
        'randomForest': rfProbs,
      },
    );
  }

  /// Predict using Transformer model
  Future<List<double>> _predictTransformer(List<List<double>> features) async {
    if (_transformerModel == null || !_modelStatus['transformer']!) {
      return [0.2, 0.2, 0.2, 0.2, 0.2]; // Neutral if model not loaded (5 classes)
    }

    final startTime = DateTime.now();
    try {
      // Reshape input: [1, 60, 76]
      var input = [features];

      // Output buffer: [1, 5] (5 classes: STRONG_SELL, SELL, HOLD, BUY, STRONG_BUY)
      var output = List.generate(1, (_) => List.filled(5, 0.0));

      // Run inference
      _transformerModel!.run(input, output);

      // Track latency
      final latency = DateTime.now().difference(startTime).inMilliseconds;
      _modelLatency['transformer'] = latency.toDouble();

      return List<double>.from(output[0]);
    } catch (e) {
      debugPrint('⚠️ Transformer inference failed: $e');
      _modelErrors['transformer'] = (_modelErrors['transformer'] ?? 0) + 1;
      return [0.2, 0.2, 0.2, 0.2, 0.2];
    }
  }

  /// Predict using LSTM model
  Future<List<double>> _predictLstm(List<List<double>> features) async {
    if (_lstmModel == null || !_modelStatus['lstm']!) {
      return [0.2, 0.2, 0.2, 0.2, 0.2]; // Neutral if model not loaded (5 classes)
    }

    final startTime = DateTime.now();
    try {
      // Reshape input: [1, 60, 76]
      var input = [features];

      // Output buffer: [1, 5] (5 classes)
      var output = List.generate(1, (_) => List.filled(5, 0.0));

      // Run inference
      _lstmModel!.run(input, output);

      // Track latency
      final latency = DateTime.now().difference(startTime).inMilliseconds;
      _modelLatency['lstm'] = latency.toDouble();

      return List<double>.from(output[0]);
    } catch (e) {
      debugPrint('⚠️ LSTM inference failed: $e');
      _modelErrors['lstm'] = (_modelErrors['lstm'] ?? 0) + 1;
      return [0.2, 0.2, 0.2, 0.2, 0.2];
    }
  }

  /// Predict using Random Forest (fallback rule-based)
  ///
  /// Uses technical indicators from the 76-feature vector
  Future<List<double>> _predictRandomForest(List<List<double>> features) async {
    // Fallback: Simple rule-based prediction using 76-feature vector
    // Feature indices (from Python training):
    // 30-32: RSI (rsi, rsi_oversold, rsi_overbought)
    // 33-37: MACD (macd, macd_signal, macd_histogram, macd_cross_above, macd_cross_below)
    // 73-75: Trend (higher_high, lower_low, uptrend, downtrend)

    // Get features from MIDDLE of sequence
    final midIdx = features.length ~/ 2;
    final midTimestep = features[midIdx];

    // Extract key indicators (these are RAW values, not normalized 0-1)
    final rsi = midTimestep[30];  // RSI (0-100)
    final macd = midTimestep[33]; // MACD (can be negative)
    final uptrend = midTimestep[74]; // Uptrend indicator (0 or 1)

    // 🔍 DEBUG: Print RF inputs
    debugPrint('🔍 RF INPUTS: RSI=$rsi, MACD=$macd, Uptrend=$uptrend');

    // Simple rules using RAW values
    double strongSellProb = 0.0;
    double sellProb = 0.0;
    double holdProb = 0.2; // Base hold probability
    double buyProb = 0.0;
    double strongBuyProb = 0.0;

    // RSI logic (0-100 scale)
    if (rsi < 30) {
      strongBuyProb += 0.4; // Oversold
      buyProb += 0.2;
    } else if (rsi > 70) {
      strongSellProb += 0.4; // Overbought
      sellProb += 0.2;
    } else {
      holdProb += 0.3; // Neutral RSI -> hold
    }

    // MACD logic (positive = bullish, negative = bearish)
    if (macd > 0) {
      buyProb += 0.3;
      strongBuyProb += 0.2;
    } else {
      sellProb += 0.3;
      strongSellProb += 0.2;
    }

    // Trend logic (binary: 1 = uptrend, 0 = downtrend)
    if (uptrend > 0.5) {
      // Uptrend - favor buys
      buyProb += 0.2;
      strongBuyProb += 0.1;
    } else {
      // Downtrend - favor sells
      sellProb += 0.2;
      strongSellProb += 0.1;
    }

    // Normalize
    final total = strongSellProb + sellProb + holdProb + buyProb + strongBuyProb;
    if (total > 0) {
      strongSellProb /= total;
      sellProb /= total;
      holdProb /= total;
      buyProb /= total;
      strongBuyProb /= total;
    } else {
      // Fallback to neutral
      strongSellProb = sellProb = holdProb = buyProb = strongBuyProb = 0.2;
    }

    return [strongSellProb, sellProb, holdProb, buyProb, strongBuyProb];
  }

  /// Weighted voting ensemble
  ///
  /// Combines model predictions using configured weights
  List<double> _weightedVoting({
    required List<double> transformerProbs,
    required List<double> lstmProbs,
    required List<double> rfProbs,
  }) {
    final ensembleProbs = List<double>.filled(5, 0.0); // 5 classes

    for (int i = 0; i < 5; i++) {
      ensembleProbs[i] = _transformerWeight * transformerProbs[i] +
          _lstmWeight * lstmProbs[i] +
          _randomForestWeight * rfProbs[i];
    }

    // Normalize (should already sum to ~1.0, but ensure it)
    final sum = ensembleProbs.reduce((a, b) => a + b);
    if (sum > 0) {
      for (int i = 0; i < 5; i++) {
        ensembleProbs[i] /= sum;
      }
    }

    return ensembleProbs;
  }

  /// Check if models are loaded
  bool get isLoaded => _isLoaded;

  /// Get model load status
  Map<String, bool> get modelStatus => _modelStatus;

  /// Get model performance metrics (latency in ms)
  Map<String, double> get modelLatency => Map.unmodifiable(_modelLatency);

  /// Get model error counts
  Map<String, int> get modelErrors => Map.unmodifiable(_modelErrors);

  /// Check if using legacy fallback
  bool get isUsingLegacyFallback => _useLegacyFallback;

  /// Get performance summary
  String get performanceSummary {
    if (_modelLatency.isEmpty) return 'No metrics yet';

    final buffer = StringBuffer('📊 Model Performance:\n');
    _modelLatency.forEach((model, latency) {
      final errors = _modelErrors[model] ?? 0;
      buffer.writeln('   $model: ${latency.toStringAsFixed(0)}ms (errors: $errors)');
    });
    return buffer.toString();
  }


  /// Dispose interpreters
  void dispose() {
    _transformerModel?.close();
    _lstmModel?.close();
    _randomForestModel?.close();
    _legacyTcnModel?.close();
    debugPrint('🧹 Ensemble models disposed');
    debugPrint(performanceSummary);
  }
}

/// Ensemble prediction result
class EnsemblePrediction {
  final String label; // "STRONG_SELL", "SELL", "BUY", "STRONG_BUY"
  final int classIndex; // 0, 1, 2, 3
  final double confidence; // 0.0 to 1.0
  final List<double> probabilities; // [p(STRONG_SELL), p(SELL), p(BUY), p(STRONG_BUY)]
  final Map<String, List<double>> modelContributions; // Individual model predictions

  EnsemblePrediction({
    required this.label,
    required this.classIndex,
    required this.confidence,
    required this.probabilities,
    required this.modelContributions,
  });

  /// Convert to signal type for strategy execution
  SignalType toSignalType() {
    switch (classIndex) {
      case 0: // STRONG_SELL
      case 1: // SELL
        return SignalType.sell;
      case 2: // HOLD
        return SignalType.hold;
      case 3: // BUY
      case 4: // STRONG_BUY
        return SignalType.buy;
      default:
        return SignalType.hold;
    }
  }

  /// Check if prediction is tradeable (high confidence)
  bool get isTradeable {
    // Require at least 60% confidence for trading
    return confidence >= 0.60;
  }

  /// Check if prediction is strong (STRONG_SELL or STRONG_BUY)
  bool get isStrong {
    return classIndex == 0 || classIndex == 4;
  }

  @override
  String toString() {
    return '''
=== Ensemble Prediction ===
Label: $label
Confidence: ${(confidence * 100).toStringAsFixed(1)}%
Probabilities:
  STRONG_SELL: ${(probabilities[0] * 100).toStringAsFixed(1)}%
  SELL: ${(probabilities[1] * 100).toStringAsFixed(1)}%
  HOLD: ${(probabilities[2] * 100).toStringAsFixed(1)}%
  BUY: ${(probabilities[3] * 100).toStringAsFixed(1)}%
  STRONG_BUY: ${(probabilities[4] * 100).toStringAsFixed(1)}%
Tradeable: ${isTradeable ? "YES ✅" : "NO ❌"}
''';
  }
}

/// Signal type enum (for compatibility with existing strategies)
enum SignalType {
  buy,
  sell,
  hold,
}

/// Example usage:
///
/// ```dart
/// // Initialize predictor
/// final predictor = EnsemblePredictor();
/// await predictor.loadModels();
///
/// // Build features (from MtfFeatureBuilderV2)
/// final featureBuilder = MtfFeatureBuilderV2();
/// final features = await featureBuilder.buildFeatures(
///   symbol: 'BTCUSDT',
///   base1h: candles1h,
///   low15m: candles15m,
///   high4h: candles4h,
/// );
///
/// // Get ensemble prediction
/// final prediction = await predictor.predict(features);
///
/// print(prediction);
/// // Output:
/// // === Ensemble Prediction ===
/// // Label: BUY
/// // Confidence: 78.5%
/// // Probabilities:
/// //   STRONG_SELL: 5.2%
/// //   SELL: 8.3%
/// //   BUY: 58.0%
/// //   STRONG_BUY: 28.5%
/// // Tradeable: YES ✅
///
/// if (prediction.isTradeable) {
///   // Execute trade with adaptive position sizing
///   final signal = prediction.toSignalType();
///   final positionSize = baseSize * prediction.confidence; // Scale by confidence
///
///   await executeTrade(
///     signal: signal,
///     size: positionSize,
///     confidence: prediction.confidence,
///   );
/// }
///
/// // Dispose when done
/// predictor.dispose();
/// ```

// Global singleton for convenient access from UI layers
final EnsemblePredictor globalEnsemblePredictor = EnsemblePredictor();
