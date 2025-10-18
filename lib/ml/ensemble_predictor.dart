import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Ensemble Predictor for MyTradeMate
///
/// Combines 2 AI model types with weighted voting:
/// - Per-coin models (40% weight): Specialized 27MB models trained on each cryptocurrency
/// - Single TF GRU general models (60% weight): Lightweight 73KB models trained on 1H data across all coins
///
/// This ensemble approach reduces overfitting and improves generalization
/// by combining specialized per-coin knowledge with general crypto patterns.
///
/// Input: 60 timesteps × 76 features (25 candle patterns + 51 technical indicators)
/// Output: 5-class probabilities [STRONG_SELL, SELL, HOLD, BUY, STRONG_BUY]
///
/// Example:
/// ```dart
/// final predictor = EnsemblePredictor();
/// await predictor.loadModels();
///
/// final prediction = await predictor.predict(featureMatrix, symbol: 'BTC/USDT');
/// print(prediction.label); // "BUY"
/// print(prediction.confidence); // 0.78
/// ```
class EnsemblePredictor {
  // Per-coin model interpreters (specialized for each cryptocurrency, 27MB each)
  final Map<String, Interpreter?> _perCoinModels = {
    'BTC': null,
    'ETH': null,
    'BNB': null,
    'SOL': null,
    'WLFI': null,
    'TRUMP': null,
  };

  // Single TF GRU general model interpreters (trained on 1H data, 73KB each)
  final Map<String, Interpreter?> _singleTfGruModels = {
    'BTC': null,
    'ETH': null,
    'BNB': null,
    'SOL': null,
    'WLFI': null,
    'TRUMP': null,
  };

  // Scalers for Single TF GRU models (StandardScaler parameters)
  final Map<String, Map<String, dynamic>?> _singleTfGruScalers = {
    'BTC': null,
    'ETH': null,
    'BNB': null,
    'SOL': null,
    'WLFI': null,
    'TRUMP': null,
  };

  // Legacy fallback models (deprecated, kept for backward compatibility)
  Interpreter? _transformerModel;
  Interpreter? _lstmModel;
  Interpreter? _legacyTcnModel;

  // Model weights (sum to 1.0)
  // Per-coin models: 40% (specialized knowledge for each coin)
  // Single TF GRU general: 60% (general patterns across all coins at 1H timeframe)
  static const double _perCoinWeight = 0.40;
  static const double _singleTfGruWeight = 0.60;

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
  /// Loads per-coin specialized models and Single TF GRU general models.
  /// Falls back gracefully if some models are missing.
  Future<void> loadModels() async {
    debugPrint('🤖 Loading ensemble models...');

    // Legacy models commented out for potential future use
    // try {
    //   // Load Transformer
    //   await _loadTransformerModel();
    // } catch (e) {
    //   debugPrint('⚠️ Failed to load Transformer: $e');
    // }

    // try {
    //   // Load LSTM
    //   await _loadLstmModel();
    // } catch (e) {
    //   debugPrint('⚠️ Failed to load LSTM: $e');
    // }

    try {
      // Load Random Forest (optional, can use rule-based fallback)
      await _loadRandomForestModel();
    } catch (e) {
      debugPrint('⚠️ Failed to load Random Forest: $e (will use fallback)');
    }

    try {
      // Load per-coin models (BTC, ETH, BNB, SOL, WLFI, TRUMP)
      await _loadPerCoinModels();
    } catch (e) {
      debugPrint('⚠️ Failed to load per-coin models: $e');
    }

    try {
      // Load Single TF GRU general models (1H timeframe, 73KB each)
      await _loadSingleTfGruModels();
    } catch (e) {
      debugPrint('⚠️ Failed to load Single TF GRU models: $e');
    }

    // Check if at least one model type loaded
    final perCoinLoaded = _perCoinModels.values.any((model) => model != null);
    final singleTfGruLoaded = _singleTfGruModels.values.any((model) => model != null);
    _isLoaded = perCoinLoaded || singleTfGruLoaded || _modelStatus.values.any((status) => status);

    if (!_isLoaded) {
      throw Exception('❌ No models loaded! Ensure TFLite models exist in assets/models/ and assets/ml/');
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

    debugPrint('');
    debugPrint('✅ ========================================');
    debugPrint('✅ Ensemble models loaded summary:');
    debugPrint('✅ ========================================');
    debugPrint('   Per-Coin Models (40% weight):');
    _perCoinModels.forEach((coin, model) {
      debugPrint('      $coin: ${model != null ? "✅ LOADED (27MB specialized)" : "❌ NOT LOADED"}');
    });
    debugPrint('');
    debugPrint('   Single TF GRU Models (60% weight):');
    _singleTfGruModels.forEach((coin, model) {
      debugPrint('      $coin: ${model != null ? "✅ LOADED (73KB 1H general)" : "❌ NOT LOADED"}');
    });
    debugPrint('✅ ========================================');
    if (_useLegacyFallback) {
      debugPrint('   💡 Using Legacy TCN Fallback');
    }
    debugPrint('');
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

  /// Load per-coin specialized models
  Future<void> _loadPerCoinModels() async {
    debugPrint('');
    debugPrint('🪙 ========================================');
    debugPrint('🪙 Loading per-coin specialized models');
    debugPrint('🪙 Location: assets/models/');
    debugPrint('🪙 ========================================');

    for (var entry in _perCoinModels.keys) {
      try {
        final coinLower = entry.toLowerCase();
        final modelPath = 'assets/models/${coinLower}_model.tflite';
        debugPrint('');
        debugPrint('🪙 [$entry] Attempting to load: $modelPath');

        _perCoinModels[entry] = await Interpreter.fromAsset(modelPath);

        debugPrint('   ✅ $entry model loaded successfully!');
        debugPrint('   📊 Model: Per-coin specialized');
        debugPrint('   📏 Size: ~27MB');
        debugPrint('   🎯 Input: [1, 60, 76] -> Output: [1, 3] (SELL, HOLD, BUY)');
      } catch (e) {
        debugPrint('');
        debugPrint('   ❌ $entry model NOT FOUND!');
        debugPrint('   ⚠️  Error: $e');
        debugPrint('   💡 Will fallback to general ensemble models');
        _perCoinModels[entry] = null;
      }
    }

    debugPrint('');
    debugPrint('🪙 ========================================');
    debugPrint('🪙 Per-coin models loading summary:');
    debugPrint('🪙 ========================================');
    _perCoinModels.forEach((coin, model) {
      debugPrint('   $coin: ${model != null ? "✅ LOADED (specialized 27MB model)" : "❌ NOT LOADED (will use ensemble fallback)"}');
    });
    debugPrint('🪙 ========================================');
    debugPrint('');
  }

  /// Load Single TF GRU general models (trained on 1H data, 73KB each)
  Future<void> _loadSingleTfGruModels() async {
    debugPrint('');
    debugPrint('🧠 ========================================');
    debugPrint('🧠 Loading Single TF GRU general models (1H timeframe)');
    debugPrint('🧠 Location: assets/ml/');
    debugPrint('🧠 ========================================');

    for (var entry in _singleTfGruModels.keys) {
      try {
        final coinLower = entry.toLowerCase();
        final modelPath = 'assets/ml/${coinLower}_model.tflite';
        final scalerPath = 'assets/ml/${coinLower}_scaler.json';
        debugPrint('');
        debugPrint('🧠 [$entry] Attempting to load: $modelPath');

        _singleTfGruModels[entry] = await Interpreter.fromAsset(modelPath);

        // Load scaler parameters
        try {
          final scalerJson = await rootBundle.loadString(scalerPath);
          _singleTfGruScalers[entry] = json.decode(scalerJson) as Map<String, dynamic>;
          final nFeatures = _singleTfGruScalers[entry]!['n_features'] as int;
          debugPrint('   ✅ $entry Single TF GRU loaded successfully!');
          debugPrint('   📊 Model: Single TF GRU (quantized)');
          debugPrint('   📏 Size: ~73KB (optimized for mobile)');
          debugPrint('   ⏰ Timeframe: 1H');
          debugPrint('   🎯 Input: [1, 60, 76] -> Output: [1, 3] (SELL, HOLD, BUY)');
          debugPrint('   🎯 Test Accuracy: ~44-48%');
          debugPrint('   🔧 Scaler: StandardScaler with $nFeatures features loaded');
        } catch (scalerError) {
          debugPrint('   ⚠️  Model loaded but scaler failed: $scalerError');
          debugPrint('   ⚠️  Model will be disabled without scaler');
          _singleTfGruModels[entry] = null;
          _singleTfGruScalers[entry] = null;
        }
      } catch (e) {
        debugPrint('');
        debugPrint('   ❌ $entry Single TF GRU NOT FOUND!');
        debugPrint('   ⚠️  Error: $e');
        _singleTfGruModels[entry] = null;
        _singleTfGruScalers[entry] = null;
      }
    }

    debugPrint('');
    debugPrint('🧠 ========================================');
    debugPrint('🧠 Single TF GRU models loading summary:');
    debugPrint('🧠 ========================================');
    _singleTfGruModels.forEach((coin, model) {
      debugPrint('   $coin: ${model != null ? "✅ LOADED (Single TF GRU 1H 73KB)" : "❌ NOT LOADED"}');
    });
    debugPrint('🧠 ========================================');
    debugPrint('');
  }

  /// Predict using ensemble voting
  ///
  /// Args:
  ///   features: [60, 76] feature matrix (60 timesteps × 76 features)
  ///   symbol: Trading pair symbol (e.g., 'BTC/USDT', 'BTCEUR') to select per-coin model
  ///
  /// Returns:
  ///   EnsemblePrediction with weighted consensus
  Future<EnsemblePrediction> predict(List<List<double>> features, {String? symbol}) async {
    if (!_isLoaded) {
      throw Exception('Models not loaded. Call loadModels() first.');
    }

    // Validate input shape
    if (features.length != 60 || features[0].length != 76) {
      throw Exception('Invalid input shape: ${features.length}x${features[0].length}. Expected 60x76 (60 timesteps × 76 features)');
    }

    debugPrint('✅ Input shape validated: ${features.length}x${features[0].length}');

    // Extract coin symbol (BTC, ETH, etc.) from trading pair
    String? coinSymbol;
    if (symbol != null) {
      // Handle formats like 'BTC/USDT', 'BTCEUR', 'BTCUSDT'
      coinSymbol = symbol.replaceAll('/', '').replaceAll('USDT', '').replaceAll('EUR', '').toUpperCase();
      // Take first part if still has slash
      if (coinSymbol.contains('/')) {
        coinSymbol = coinSymbol.split('/')[0];
      }
      debugPrint('🪙 Using per-coin model for: $coinSymbol (from $symbol)');
    }

    // Get predictions from each model
    final perCoinProbs = await _predictPerCoin(features, coinSymbol);
    final singleTfGruProbs = await _predictSingleTfGru(features, coinSymbol);
    // Legacy models commented out
    // final transformerProbs = await _predictTransformer(features);
    // final lstmProbs = await _predictLstm(features);
    final rfProbs = await _predictRandomForest(features);

    // 🔍 DEBUG: Print raw model outputs
    debugPrint('🔍 RAW MODEL OUTPUTS:');
    debugPrint('   Per-Coin ($coinSymbol): [${perCoinProbs.map((p) => (p * 100).toStringAsFixed(1)).join(', ')}]');
    debugPrint('   Single TF GRU ($coinSymbol): [${singleTfGruProbs.map((p) => (p * 100).toStringAsFixed(1)).join(', ')}]');
    debugPrint('   RF: [${rfProbs.map((p) => (p * 100).toStringAsFixed(1)).join(', ')}]');

    // Weighted voting (40% per-coin + 60% Single TF GRU)
    final ensembleProbs = _weightedVoting(
      perCoinProbs: perCoinProbs,
      singleTfGruProbs: singleTfGruProbs,
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
        'perCoin_$coinSymbol': perCoinProbs,
        'singleTfGru_$coinSymbol': singleTfGruProbs,
        'randomForest': rfProbs,
      },
    );
  }

  // Legacy Transformer and LSTM models (commented out for potential future use)
  // /// Predict using Transformer model
  // Future<List<double>> _predictTransformer(List<List<double>> features) async {
  //   if (_transformerModel == null || !_modelStatus['transformer']!) {
  //     return [0.2, 0.2, 0.2, 0.2, 0.2]; // Neutral if model not loaded (5 classes)
  //   }

  //   final startTime = DateTime.now();
  //   try {
  //     // Reshape input: [1, 60, 76]
  //     var input = [features];

  //     // Output buffer: [1, 5] (5 classes: STRONG_SELL, SELL, HOLD, BUY, STRONG_BUY)
  //     var output = List.generate(1, (_) => List.filled(5, 0.0));

  //     // Run inference
  //     _transformerModel!.run(input, output);

  //     // Track latency
  //     final latency = DateTime.now().difference(startTime).inMilliseconds;
  //     _modelLatency['transformer'] = latency.toDouble();

  //     return List<double>.from(output[0]);
  //   } catch (e) {
  //     debugPrint('⚠️ Transformer inference failed: $e');
  //     _modelErrors['transformer'] = (_modelErrors['transformer'] ?? 0) + 1;
  //     return [0.2, 0.2, 0.2, 0.2, 0.2];
  //   }
  // }

  // /// Predict using LSTM model
  // Future<List<double>> _predictLstm(List<List<double>> features) async {
  //   if (_lstmModel == null || !_modelStatus['lstm']!) {
  //     return [0.2, 0.2, 0.2, 0.2, 0.2]; // Neutral if model not loaded (5 classes)
  //   }

  //   final startTime = DateTime.now();
  //   try {
  //     // Reshape input: [1, 60, 76]
  //     var input = [features];

  //     // Output buffer: [1, 5] (5 classes)
  //     var output = List.generate(1, (_) => List.filled(5, 0.0));

  //     // Run inference
  //     _lstmModel!.run(input, output);

  //     // Track latency
  //     final latency = DateTime.now().difference(startTime).inMilliseconds;
  //     _modelLatency['lstm'] = latency.toDouble();

  //     return List<double>.from(output[0]);
  //   } catch (e) {
  //     debugPrint('⚠️ LSTM inference failed: $e');
  //     _modelErrors['lstm'] = (_modelErrors['lstm'] ?? 0) + 1;
  //     return [0.2, 0.2, 0.2, 0.2, 0.2];
  //   }
  // }

  /// Extract coin symbol from trading pair (BTC from BTC/USDT, BTCUSDT, etc.)
  String _extractCoinSymbol(String symbol) {
    // Handle formats like 'BTC/USDT', 'BTCEUR', 'BTCUSDT'
    String coinSymbol = symbol.replaceAll('/', '').replaceAll('USDT', '').replaceAll('EUR', '').toUpperCase();
    // Take first part if still has slash
    if (coinSymbol.contains('/')) {
      coinSymbol = coinSymbol.split('/')[0];
    }
    return coinSymbol;
  }

  /// Predict using per-coin specialized model
  ///
  /// Per-coin models output 3 classes [SELL, HOLD, BUY]
  /// This method maps them to 5 classes [STRONG_SELL, SELL, HOLD, BUY, STRONG_BUY]
  Future<List<double>> _predictPerCoin(List<List<double>> features, String? coinSymbol) async {
    debugPrint('');
    debugPrint('🪙 === PER-COIN MODEL PREDICTION ===');
    debugPrint('🪙 Coin Symbol: $coinSymbol');

    // If no coin symbol or model not available, return neutral
    if (coinSymbol == null) {
      debugPrint('⚠️ Per-coin model: No coin symbol provided!');
      debugPrint('   Using neutral probabilities: [0.0, 0.0, 1.0, 0.0, 0.0] (HOLD)');
      return [0.0, 0.0, 1.0, 0.0, 0.0]; // HOLD
    }

    final coin = _extractCoinSymbol(coinSymbol);
    final model = _perCoinModels[coin];

    if (model == null) {
      debugPrint('⚠️ Per-coin model for $coin not available!');
      debugPrint('   Reason: Model not loaded');
      debugPrint('   Using neutral probabilities: [0.0, 0.0, 1.0, 0.0, 0.0] (HOLD)');
      return [0.0, 0.0, 1.0, 0.0, 0.0]; // HOLD
    }
    final startTime = DateTime.now();
    debugPrint('✅ $coin model is loaded!');
    debugPrint('📥 Input shape: [1, ${features.length}, ${features[0].length}]');

    try {
      // Reshape input: [1, 60, 76]
      var input = [features];

      // Output buffer: [1, 3] for 3-class models (SELL, HOLD, BUY)
      var output = List.generate(1, (_) => List.filled(3, 0.0));

      debugPrint('🔄 Running inference on $coin model...');

      // Run inference
      model.run(input, output);

      // Track latency
      final latency = DateTime.now().difference(startTime).inMilliseconds;
      _modelLatency['perCoin_$coin'] = latency.toDouble();

      debugPrint('⏱️  Inference time: ${latency}ms');

      // Convert 3-class [SELL, HOLD, BUY] to 5-class [STRONG_SELL, SELL, HOLD, BUY, STRONG_BUY]
      final sell = output[0][0];
      final hold = output[0][1];
      final buy = output[0][2];

      debugPrint('📊 Raw 3-class output:');
      debugPrint('   SELL: ${(sell * 100).toStringAsFixed(2)}%');
      debugPrint('   HOLD: ${(hold * 100).toStringAsFixed(2)}%');
      debugPrint('   BUY:  ${(buy * 100).toStringAsFixed(2)}%');

      // Map 3-class to 5-class:
      // - High SELL probability (>0.6) -> split between STRONG_SELL and SELL
      // - Low-medium SELL (<0.6) -> mostly SELL
      // - HOLD stays as HOLD
      // - High BUY probability (>0.6) -> split between BUY and STRONG_BUY
      // - Low-medium BUY (<0.6) -> mostly BUY
      double strongSell, normalSell, normalBuy, strongBuy;

      if (sell > 0.6) {
        strongSell = sell * 0.5;
        normalSell = sell * 0.5;
        debugPrint('🔴 High SELL probability -> splitting to STRONG_SELL + SELL');
      } else {
        strongSell = sell * 0.2;
        normalSell = sell * 0.8;
        debugPrint('🟠 Normal SELL probability -> mostly SELL');
      }

      if (buy > 0.6) {
        strongBuy = buy * 0.5;
        normalBuy = buy * 0.5;
        debugPrint('🟢 High BUY probability -> splitting to BUY + STRONG_BUY');
      } else {
        strongBuy = buy * 0.2;
        normalBuy = buy * 0.8;
        debugPrint('🟡 Normal BUY probability -> mostly BUY');
      }

      final result = [strongSell, normalSell, hold, normalBuy, strongBuy];

      debugPrint('📊 Mapped to 5-class output:');
      debugPrint('   STRONG_SELL: ${(strongSell * 100).toStringAsFixed(2)}%');
      debugPrint('   SELL:        ${(normalSell * 100).toStringAsFixed(2)}%');
      debugPrint('   HOLD:        ${(hold * 100).toStringAsFixed(2)}%');
      debugPrint('   BUY:         ${(normalBuy * 100).toStringAsFixed(2)}%');
      debugPrint('   STRONG_BUY:  ${(strongBuy * 100).toStringAsFixed(2)}%');

      return result;
    } catch (e) {
      debugPrint('❌ Per-coin ($coin) inference FAILED!');
      debugPrint('   Error: $e');
      _modelErrors['perCoin_$coin'] = (_modelErrors['perCoin_$coin'] ?? 0) + 1;
      return [0.0, 0.0, 1.0, 0.0, 0.0]; // HOLD
    }
  }

  /// Predict using Single TF GRU general model for the given coin
  ///
  /// NOTE: Single TF GRU models are DISABLED because scalers cannot be loaded
  /// from .pkl files (Python-specific format). Models return 100% HOLD without
  /// proper feature normalization. To fix, the user needs to re-export scalers
  /// to JSON format from the training script.
  Future<List<double>> _predictSingleTfGru(List<List<double>> features, String? coinSymbol) async {
    if (coinSymbol == null) {
      debugPrint('   ⚠️  Single TF GRU: No coin symbol provided, returning HOLD');
      return [0.0, 0.0, 1.0, 0.0, 0.0];
    }

    final coin = _extractCoinSymbol(coinSymbol);
    final model = _singleTfGruModels[coin];
    final scaler = _singleTfGruScalers[coin];

    if (model == null || scaler == null) {
      debugPrint('   ⚠️  Single TF GRU ($coin): Model or scaler not loaded, returning HOLD');
      return [0.0, 0.0, 1.0, 0.0, 0.0];
    }

    debugPrint('   🧠 Single TF GRU ($coin): Running inference...');
    debugPrint('      Input shape (raw): [1, ${features.length}, ${features[0].length}]');

    // Apply StandardScaler normalization using loaded scaler parameters
    final mean = (scaler['mean'] as List).cast<double>();
    final scale = (scaler['scale'] as List).cast<double>();

    var normalizedFeatures = List.generate(features.length, (i) {
      return List.generate(features[i].length, (j) {
        return (features[i][j] - mean[j]) / scale[j];
      });
    });

    debugPrint('      Applied StandardScaler normalization (76 features)');

    var input = List.generate(1, (_) => normalizedFeatures);
    var output = List.generate(1, (_) => List.filled(3, 0.0));

    try {
      model.run(input, output);
      debugPrint('      RAW 3-class output: [SELL: ${(output[0][0] * 100).toStringAsFixed(2)}%, HOLD: ${(output[0][1] * 100).toStringAsFixed(2)}%, BUY: ${(output[0][2] * 100).toStringAsFixed(2)}%]');
    } catch (e) {
      debugPrint('   ❌ Single TF GRU ($coin): Inference error: $e');
      return [0.0, 0.0, 1.0, 0.0, 0.0];
    }

    final sell = output[0][0];
    final hold = output[0][1];
    final buy = output[0][2];

    double strongSell, normalSell, strongBuy, normalBuy;

    if (sell > 0.6) {
      strongSell = sell * 0.5;
      normalSell = sell * 0.5;
    } else {
      strongSell = sell * 0.2;
      normalSell = sell * 0.8;
    }

    if (buy > 0.6) {
      strongBuy = buy * 0.5;
      normalBuy = buy * 0.5;
    } else {
      strongBuy = buy * 0.2;
      normalBuy = buy * 0.8;
    }

    final result = [strongSell, normalSell, hold, normalBuy, strongBuy];
    debugPrint('      Converted to 5-class: [${result.map((p) => (p * 100).toStringAsFixed(2)).join(', ')}]');

    return result;
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
  /// Combines model predictions using configured weights:
  /// - Per-coin model: 40% (specialized knowledge for each coin)
  /// - Single TF GRU general: 60% (general patterns across all coins at 1H timeframe)
  List<double> _weightedVoting({
    required List<double> perCoinProbs,
    required List<double> singleTfGruProbs,
    required List<double> rfProbs,
  }) {
    debugPrint('');
    debugPrint('⚖️  === WEIGHTED VOTING ENSEMBLE ===');
    debugPrint('⚖️  Model Weights:');
    debugPrint('   Per-Coin (40%):        Specialized 27MB models from assets/models/');
    debugPrint('   Single TF GRU (60%):   General 73KB models (1H) from assets/ml/');
    debugPrint('');

    final ensembleProbs = List<double>.filled(5, 0.0); // 5 classes
    final labels = ['STRONG_SELL', 'SELL', 'HOLD', 'BUY', 'STRONG_BUY'];

    debugPrint('⚖️  Calculating weighted ensemble for each class:');

    for (int i = 0; i < 5; i++) {
      final perCoinContrib = _perCoinWeight * perCoinProbs[i];
      final singleTfGruContrib = _singleTfGruWeight * singleTfGruProbs[i];

      ensembleProbs[i] = perCoinContrib + singleTfGruContrib;

      debugPrint('   ${labels[i].padRight(12)}:');
      debugPrint('      Per-Coin:      ${(perCoinContrib * 100).toStringAsFixed(2)}% (${(perCoinProbs[i] * 100).toStringAsFixed(1)}% × 40%)');
      debugPrint('      Single TF GRU: ${(singleTfGruContrib * 100).toStringAsFixed(2)}% (${(singleTfGruProbs[i] * 100).toStringAsFixed(1)}% × 60%)');
      debugPrint('      → Total:       ${(ensembleProbs[i] * 100).toStringAsFixed(2)}%');
    }

    // Normalize (should already sum to ~1.0, but ensure it)
    final sum = ensembleProbs.reduce((a, b) => a + b);
    debugPrint('');
    debugPrint('⚖️  Sum before normalization: ${(sum * 100).toStringAsFixed(2)}%');

    if (sum > 0) {
      for (int i = 0; i < 5; i++) {
        ensembleProbs[i] /= sum;
      }
      debugPrint('⚖️  Normalized ensemble probabilities:');
      for (int i = 0; i < 5; i++) {
        debugPrint('   ${labels[i].padRight(12)}: ${(ensembleProbs[i] * 100).toStringAsFixed(2)}%');
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
    // Legacy models (commented out but kept for potential future use)
    // _transformerModel?.close();
    // _lstmModel?.close();
    _legacyTcnModel?.close();

    // Dispose per-coin models
    for (var entry in _perCoinModels.entries) {
      entry.value?.close();
    }

    // Dispose Single TF GRU models
    for (var entry in _singleTfGruModels.entries) {
      entry.value?.close();
    }

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
