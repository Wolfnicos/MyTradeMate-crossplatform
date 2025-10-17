import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/candle.dart';

/// Ensemble Predictor for MyTradeMate
///
/// Combines 3 AI models with weighted voting:
/// - Transformer (50% weight): Best for complex temporal patterns
/// - LSTM (30% weight): Strong at sequential dependencies
/// - Random Forest (20% weight): Interpretable baseline
///
/// This ensemble approach reduces overfitting and improves generalization
/// by leveraging strengths of different model architectures.
///
/// Input: 120 timesteps × 42 features (from MtfFeatureBuilderV2)
/// Output: 4-class probabilities [STRONG_SELL, SELL, BUY, STRONG_BUY]
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

  // Class labels
  static const List<String> _classLabels = [
    'STRONG_SELL', // 0
    'SELL', // 1
    'BUY', // 2
    'STRONG_BUY', // 3
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

    debugPrint('✅ Ensemble models loaded:');
    debugPrint('   Transformer: ${_modelStatus['transformer'] ? "✅" : "❌"}');
    debugPrint('   LSTM: ${_modelStatus['lstm'] ? "✅" : "❌"}');
    debugPrint('   Random Forest: ${_modelStatus['randomForest'] ? "✅" : "❌ (fallback)"}');
  }

  /// Load Transformer model
  Future<void> _loadTransformerModel() async {
    _transformerModel = await Interpreter.fromAsset('assets/ml/transformer_model.tflite');
    _modelStatus['transformer'] = true;
    debugPrint('   ✅ Transformer loaded');
  }

  /// Load LSTM model
  Future<void> _loadLstmModel() async {
    _lstmModel = await Interpreter.fromAsset('assets/ml/lstm_model.tflite');
    _modelStatus['lstm'] = true;
    debugPrint('   ✅ LSTM loaded');
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

  /// Predict using ensemble voting
  ///
  /// Args:
  ///   features: [120, 42] feature matrix from MtfFeatureBuilderV2
  ///
  /// Returns:
  ///   EnsemblePrediction with weighted consensus
  Future<EnsemblePrediction> predict(List<List<double>> features) async {
    if (!_isLoaded) {
      throw Exception('Models not loaded. Call loadModels() first.');
    }

    // Validate input shape
    if (features.length != 120 || features[0].length != 42) {
      throw Exception('Invalid input shape: ${features.length}x${features[0].length}. Expected 120x42');
    }

    // Get predictions from each model
    final transformerProbs = await _predictTransformer(features);
    final lstmProbs = await _predictLstm(features);
    final rfProbs = await _predictRandomForest(features);

    // Weighted voting
    final ensembleProbs = _weightedVoting(
      transformerProbs: transformerProbs,
      lstmProbs: lstmProbs,
      rfProbs: rfProbs,
    );

    // Get final prediction
    final maxIndex = ensembleProbs.indexOf(ensembleProbs.reduce((a, b) => a > b ? a : b));
    final confidence = ensembleProbs[maxIndex];

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
      return [0.25, 0.25, 0.25, 0.25]; // Neutral if model not loaded
    }

    try {
      // Reshape input: [1, 120, 42]
      var input = [features];

      // Output buffer: [1, 4]
      var output = List.filled(4, 0.0).reshape([1, 4]);

      // Run inference
      _transformerModel!.run(input, output);

      return output[0].map((e) => e.toDouble()).toList();
    } catch (e) {
      debugPrint('⚠️ Transformer inference failed: $e');
      return [0.25, 0.25, 0.25, 0.25];
    }
  }

  /// Predict using LSTM model
  Future<List<double>> _predictLstm(List<List<double>> features) async {
    if (_lstmModel == null || !_modelStatus['lstm']!) {
      return [0.25, 0.25, 0.25, 0.25]; // Neutral if model not loaded
    }

    try {
      // Reshape input: [1, 120, 42]
      var input = [features];

      // Output buffer: [1, 4]
      var output = List.filled(4, 0.0).reshape([1, 4]);

      // Run inference
      _lstmModel!.run(input, output);

      return output[0].map((e) => e.toDouble()).toList();
    } catch (e) {
      debugPrint('⚠️ LSTM inference failed: $e');
      return [0.25, 0.25, 0.25, 0.25];
    }
  }

  /// Predict using Random Forest (fallback rule-based)
  Future<List<double>> _predictRandomForest(List<List<double>> features) async {
    // Fallback: Simple rule-based prediction
    // Uses last timestep features (most recent)
    final lastTimestep = features.last;

    // Extract key indicators (assuming standard MTF feature order)
    // Index mapping: 0-9 (1h base), 10-19 (15m aligned), 20-29 (4h upsampled)
    final rsi1h = lastTimestep[0];
    final macd1h = lastTimestep[1];
    final adx1h = lastTimestep[7];

    // Simple rules (this is a placeholder - ideally load actual RF model)
    double strongSellProb = 0.0;
    double sellProb = 0.0;
    double buyProb = 0.0;
    double strongBuyProb = 0.0;

    // RSI logic
    if (rsi1h < 30) {
      strongBuyProb += 0.4; // Oversold
      buyProb += 0.2;
    } else if (rsi1h > 70) {
      strongSellProb += 0.4; // Overbought
      sellProb += 0.2;
    } else {
      buyProb += 0.2;
      sellProb += 0.2;
    }

    // MACD logic
    if (macd1h > 0) {
      buyProb += 0.3;
      strongBuyProb += 0.2;
    } else {
      sellProb += 0.3;
      strongSellProb += 0.2;
    }

    // ADX logic (trend strength)
    if (adx1h > 25) {
      // Strong trend - amplify signals
      if (macd1h > 0) {
        strongBuyProb += 0.2;
      } else {
        strongSellProb += 0.2;
      }
    }

    // Normalize
    final total = strongSellProb + sellProb + buyProb + strongBuyProb;
    if (total > 0) {
      strongSellProb /= total;
      sellProb /= total;
      buyProb /= total;
      strongBuyProb /= total;
    } else {
      // Fallback to neutral
      strongSellProb = sellProb = buyProb = strongBuyProb = 0.25;
    }

    return [strongSellProb, sellProb, buyProb, strongBuyProb];
  }

  /// Weighted voting ensemble
  ///
  /// Combines model predictions using configured weights
  List<double> _weightedVoting({
    required List<double> transformerProbs,
    required List<double> lstmProbs,
    required List<double> rfProbs,
  }) {
    final ensembleProbs = List<double>.filled(4, 0.0);

    for (int i = 0; i < 4; i++) {
      ensembleProbs[i] = _transformerWeight * transformerProbs[i] +
          _lstmWeight * lstmProbs[i] +
          _randomForestWeight * rfProbs[i];
    }

    // Normalize (should already sum to ~1.0, but ensure it)
    final sum = ensembleProbs.reduce((a, b) => a + b);
    if (sum > 0) {
      for (int i = 0; i < 4; i++) {
        ensembleProbs[i] /= sum;
      }
    }

    return ensembleProbs;
  }

  /// Check if models are loaded
  bool get isLoaded => _isLoaded;

  /// Get model load status
  Map<String, bool> get modelStatus => _modelStatus;

  /// Dispose interpreters
  void dispose() {
    _transformerModel?.close();
    _lstmModel?.close();
    _randomForestModel?.close();
    debugPrint('🧹 Ensemble models disposed');
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
      case 2: // BUY
      case 3: // STRONG_BUY
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
    return classIndex == 0 || classIndex == 3;
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
  BUY: ${(probabilities[2] * 100).toStringAsFixed(1)}%
  STRONG_BUY: ${(probabilities[3] * 100).toStringAsFixed(1)}%
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
