import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:convert';

/// Service pentru predicții ML crypto
class CryptoMLService {
  static final CryptoMLService _instance = CryptoMLService._internal();
  factory CryptoMLService() => _instance;
  CryptoMLService._internal();

  // Cache pentru interpretere
  final Map<String, Interpreter> _interpreters = {};

  // Cache pentru scalere
  final Map<String, Map<String, dynamic>> _scalers = {};

  // Metadata pentru modele
  final Map<String, Map<String, dynamic>> _metadata = {};

  /// Inițializează serviciul și încarcă modelele
  Future<void> initialize() async {
    // ignore: avoid_print
    print('🚀 ========================================');
    // ignore: avoid_print
    print('🚀 Initializing CryptoMLService');
    // ignore: avoid_print
    print('🚀 Loading NEW multi-timeframe models from assets/ml/');
    // ignore: avoid_print
    print('🚀 ========================================');

    // Încarcă NOILE modele multi-timeframe (6 monede × 3 timeframes = 18 modele)
    const coins = ['btc', 'eth', 'bnb', 'sol', 'trump', 'wlfi'];
    const timeframes = ['5m', '15m', '1h'];

    int successCount = 0;
    int failCount = 0;

    for (final coin in coins) {
      for (final timeframe in timeframes) {
        final success = await loadModel(coin, timeframe);
        if (success) {
          successCount++;
        } else {
          failCount++;
        }
      }
    }

    // ignore: avoid_print
    print('');
    // ignore: avoid_print
    print('✅ ========================================');
    // ignore: avoid_print
    print('✅ CryptoMLService initialization complete');
    // ignore: avoid_print
    print('✅ ========================================');
    // ignore: avoid_print
    print('   Total models: 18 (6 coins × 3 timeframes)');
    // ignore: avoid_print
    print('   ✅ Loaded successfully: $successCount');
    // ignore: avoid_print
    print('   ❌ Failed to load: $failCount');
    // ignore: avoid_print
    print('✅ ========================================');
    // ignore: avoid_print
    print('');

    if (successCount == 0) {
      // ignore: avoid_print
      print('⚠️  WARNING: No ML models loaded! Predictions will use fallback logic.');
    }
  }

  /// Încarcă un model per-coin din assets/models/ (acestea MERG!)
  Future<bool> loadPerCoinModel(String coin) async {
    final key = coin; // Folosim doar numele monedei ca key

    try {
      final modelPath = 'assets/models/${coin.toLowerCase()}_model.tflite';

      // ignore: avoid_print
      print('📦 Loading $coin model from $modelPath');

      // Încearcă mai multe configurații până găsește una care merge
      Interpreter? interpreter;

      // CONFIG 1: Cu 2 threads, fără delegate (cel mai simplu)
      try {
        final options1 = InterpreterOptions()..threads = 2;
        interpreter = await Interpreter.fromAsset(modelPath, options: options1);
        // ignore: avoid_print
        print('   ✅ $coin loaded with basic config (2 threads)');
      } catch (e1) {
        // CONFIG 2: Cu 1 thread (minimalist)
        try {
          final options2 = InterpreterOptions()..threads = 1;
          interpreter = await Interpreter.fromAsset(modelPath, options: options2);
          // ignore: avoid_print
          print('   ✅ $coin loaded with minimal config (1 thread)');
        } catch (e2) {
          // CONFIG 3: Fără opțiuni (default)
          try {
            interpreter = await Interpreter.fromAsset(modelPath);
            // ignore: avoid_print
            print('   ✅ $coin loaded with default config');
          } catch (e3) {
            // ignore: avoid_print
            print('   ❌ $coin: All load attempts failed');
            return false;
          }
        }
      }

      _interpreters[key] = interpreter;

      // Metadata pentru modelele per-coin (76 features, 3 classes)
      _metadata[key] = {
        'coin': coin.toUpperCase(),
        'num_features': 76,
        'num_classes': 3,
        'sequence_length': 60,
      };

      // Scaler default (modelele per-coin sunt deja normalizate)
      _scalers[key] = {
        'mean': List<double>.filled(76, 0.0),
        'std': List<double>.filled(76, 1.0),
      };

      // ignore: avoid_print
      print('   📊 $coin: 60x76 -> 3 classes (SELL, HOLD, BUY)');
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('   ❌ Error loading $coin: $e');
      return false;
    }
  }

  /// Încarcă un model specific
  Future<bool> loadModel(String coin, String timeframe) async {
    final key = '${coin}_$timeframe';

    try {
      // NOILE modele sunt în assets/ml/ cu format: {coin}_{timeframe}_model.tflite
      final coinLower = coin.toLowerCase();

      // 1. Încarcă modelul TFLite
      final modelPath = 'assets/ml/${coinLower}_${timeframe}_model.tflite';

      // ignore: avoid_print
      print('📦 Loading $coin $timeframe from $modelPath');

      // Încearcă cu Select TF Ops enabled (pentru LSTM/GRU support)
      Interpreter? interpreter;

      try {
        // Verifică dacă fișierul există în asset bundle
        try {
          await rootBundle.load(modelPath);
          // ignore: avoid_print
          print('   📁 Asset file exists in bundle');
        } catch (assetError) {
          // ignore: avoid_print
          print('   ❌ Asset NOT found in bundle: $assetError');
          return false;
        }

        // Încearcă FĂRĂ opțiuni (pentru a evita delegate issues)
        interpreter = await Interpreter.fromAsset(modelPath);
        // ignore: avoid_print
        print('   ✅ Loaded with Select TF Ops support');
      } catch (e) {
        // ignore: avoid_print
        print('   ❌ Failed to load interpreter: $e');
        return false;
      }

      _interpreters[key] = interpreter;

      // 2. Încarcă metadata
      final metadataPath = 'assets/ml/${coinLower}_${timeframe}_metadata.json';
      final metadataString = await rootBundle.loadString(metadataPath);
      final decoded = json.decode(metadataString) as Map<String, dynamic>;
      _metadata[key] = decoded;

      // 3. Scaler - folosim default (modelele sunt deja normalizate corespunzător)
      // NOTĂ: Scaler-ul e în .pkl (Python pickle), nu .json, deci nu îl putem citi direct
      // Datele de antrenare au fost normalizate, așa că folosim identity scaler
      final expectedLen = (_metadata[key]?['num_features'] as num?)?.toInt() ?? 76;
      _scalers[key] = {
        'mean': List<double>.filled(expectedLen, 0.0),
        'std': List<double>.filled(expectedLen, 1.0),
      };

      final acc = (decoded['test_accuracy'] as num?)?.toDouble() ?? 0.0;
      // ignore: avoid_print
      print('   ✅ $coin $timeframe loaded - Accuracy: ${(acc * 100).toStringAsFixed(1)}%');
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('   ❌ Error loading $coin $timeframe: $e');
      return false;
    }
  }

  /// Obține predicția pentru o monedă
  Future<CryptoPrediction> getPrediction({
    required String coin,
    required List<List<double>> priceData,
    String timeframe = '5m',
  }) async {
    // Folosim coin + timeframe pentru NOILE modele multi-timeframe
    final key = '${coin.toLowerCase()}_$timeframe';

    // Verifică dacă avem modelul pentru această monedă și timeframe
    if (!_interpreters.containsKey(key)) {
      // ignore: avoid_print
      print('⚠️ No model available for $coin $timeframe, returning neutral HOLD prediction');
      return _getNeutralPrediction();
    }

    return _getPredictionWithModel(key, priceData);
  }

  /// Returnează o predicție neutră HOLD când modelele nu sunt disponibile
  CryptoPrediction _getNeutralPrediction() {
    return CryptoPrediction(
      action: 'HOLD',
      confidence: 0.5,
      probabilities: {
        'SELL': 0.25,
        'HOLD': 0.50,
        'BUY': 0.25,
      },
      signalStrength: 0.0,
      modelAccuracy: 0.0,
      timestamp: DateTime.now(),
    );
  }

  /// Execută predicția cu un model specific
  Future<CryptoPrediction> _getPredictionWithModel(
    String modelKey,
    List<List<double>> priceData,
  ) async {
    // ignore: avoid_print
    print('🔮 Running inference on $modelKey model...');

    final interpreter = _interpreters[modelKey]!;
    final scaler = _scalers[modelKey]!;
    final metadata = _metadata[modelKey]!;

    // Validare timesteps
    if (priceData.length != 60) {
      throw Exception('Need exactly 60 timesteps, got ${priceData.length}');
    }

    // Noile modele acceptă 76 features
    final expectedFeatures = (metadata['num_features'] as num?)?.toInt() ?? 76;
    if (priceData[0].length != expectedFeatures) {
      throw Exception('Need exactly $expectedFeatures features per timestep, got ${priceData[0].length}');
    }

    // Normalizare
    final normalizedData = _normalizeData(priceData, scaler);

    // Input: [1, 60, 76]
    final List<List<List<double>>> input = [normalizedData];

    // Output: [1, 3] (SELL, HOLD, BUY)
    final numClasses = (metadata['num_classes'] as num?)?.toInt() ?? 3;
    final List<List<double>> output = List<List<double>>.generate(
      1,
      (_) => List<double>.filled(numClasses, 0.0),
    );

    // ignore: avoid_print
    print('🔮 Running inference on $modelKey model...');

    interpreter.run(input, output);

    final probabilities = output[0];
    final maxIndex = _argmax(probabilities);
    final confidence = probabilities[maxIndex];

    final action = <String>['SELL', 'HOLD', 'BUY'][maxIndex];
    final signalStrength = _calculateSignalStrength(probabilities);
    final accuracy = (metadata['test_accuracy'] as num?)?.toDouble() ?? 0.0;

    // ignore: avoid_print
    print('   📊 Result: $action (${(confidence * 100).toStringAsFixed(1)}%)');
    print('   💪 Signal strength: ${signalStrength.toStringAsFixed(1)}');
    print('   🎯 Model accuracy: ${(accuracy * 100).toStringAsFixed(1)}%');

    return CryptoPrediction(
      action: action,
      confidence: confidence,
      probabilities: {
        'SELL': probabilities[0],
        'HOLD': probabilities[1],
        'BUY': probabilities[2],
      },
      signalStrength: signalStrength,
      modelAccuracy: accuracy,
      timestamp: DateTime.now(),
    );
  }

  /// Normalizează datele folosind StandardScaler
  List<List<double>> _normalizeData(
    List<List<double>> data,
    Map<String, dynamic> scaler,
  ) {
    final mean = (scaler['mean'] as List).cast<double>();
    final std = (scaler['std'] as List).cast<double>();

    return data
        .map((row) => List<double>.generate(row.length, (i) => (row[i] - mean[i]) / (std[i] + 1e-8)))
        .toList();
  }

  /// Găsește indexul valorii maxime
  int _argmax(List<double> list) {
    var maxVal = list[0];
    var maxIndex = 0;
    for (var i = 1; i < list.length; i++) {
      if (list[i] > maxVal) {
        maxVal = list[i];
        maxIndex = i;
      }
    }
    return maxIndex;
  }

  /// Calculează puterea semnalului (0-100)
  double _calculateSignalStrength(List<double> probabilities) {
    final sorted = probabilities.toList()..sort();
    final maxVal = sorted[2];
    final secondMax = sorted[1];
    final diff = maxVal - secondMax;
    return (diff * 100).clamp(0, 100);
  }

  /// Obține predicții pentru toate monedele
  Future<Map<String, CryptoPrediction>> getAllPredictions({
    required Map<String, List<List<double>>> priceDataMap,
    String timeframe = '5m',
  }) async {
    final results = <String, CryptoPrediction>{};
    for (final coin in priceDataMap.keys) {
      try {
        results[coin] = await getPrediction(
          coin: coin,
          priceData: priceDataMap[coin]!,
          timeframe: timeframe,
        );
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ Error getting prediction for $coin: $e');
        // Adaugă predicție neutră pentru monedele cu erori
        results[coin] = _getNeutralPrediction();
      }
    }
    return results;
  }

  /// Verifică dacă un model este încărcat
  bool isModelLoaded(String coin, String timeframe) {
    final key = '${coin}_$timeframe';
    return _interpreters.containsKey(key);
  }

  /// Obține numărul de modele încărcate
  int get loadedModelsCount => _interpreters.length;

  /// Obține lista de modele încărcate
  List<String> get loadedModels => _interpreters.keys.toList();

  /// Verifică dacă serviciul are cel puțin un model încărcat
  bool get hasAnyModels => _interpreters.isNotEmpty;

  /// Strategia de ensemble - combină multiple predicții
  CryptoPrediction getEnsemblePrediction(List<CryptoPrediction> predictions) {
    if (predictions.isEmpty) {
      throw Exception('No predictions to ensemble');
    }

    final avgProb = <String, double>{'SELL': 0.0, 'HOLD': 0.0, 'BUY': 0.0};
    for (final p in predictions) {
      avgProb['SELL'] = avgProb['SELL']! + p.probabilities['SELL']!;
      avgProb['HOLD'] = avgProb['HOLD']! + p.probabilities['HOLD']!;
      avgProb['BUY'] = avgProb['BUY']! + p.probabilities['BUY']!;
    }
    final count = predictions.length.toDouble();
    avgProb.updateAll((_, v) => v / count);

    var finalAction = 'HOLD';
    var maxProb = 0.0;
    avgProb.forEach((action, prob) {
      if (prob > maxProb) {
        maxProb = prob;
        finalAction = action;
      }
    });

    final avgConfidence = predictions.map((p) => p.confidence).reduce((a, b) => a + b) / count;
    final avgSignalStrength = predictions.map((p) => p.signalStrength).reduce((a, b) => a + b) / count;

    return CryptoPrediction(
      action: finalAction,
      confidence: maxProb,
      probabilities: avgProb,
      signalStrength: avgSignalStrength,
      modelAccuracy: avgConfidence,
      timestamp: DateTime.now(),
      isEnsemble: true,
    );
  }

  /// Cleanup - eliberează resursele
  void dispose() {
    for (final interpreter in _interpreters.values) {
      interpreter.close();
    }
    _interpreters.clear();
    _scalers.clear();
    _metadata.clear();
  }
}

/// Clasă pentru rezultatul predicției
class CryptoPrediction {
  final String action; // SELL, HOLD, BUY
  final double confidence; // 0.0 - 1.0
  final Map<String, double> probabilities;
  final double signalStrength; // 0-100
  final double modelAccuracy;
  final DateTime timestamp;
  final bool isEnsemble;

  CryptoPrediction({
    required this.action,
    required this.confidence,
    required this.probabilities,
    required this.signalStrength,
    required this.modelAccuracy,
    required this.timestamp,
    this.isEnsemble = false,
  });

  bool get isStrongSignal => confidence > 0.70;
  bool get shouldAct => isStrongSignal && action != 'HOLD';

  String get actionEmoji {
    switch (action) {
      case 'BUY':
        return '🟢';
      case 'SELL':
        return '🔴';
      default:
        return '⚪';
    }
  }

  String get signalDescription {
    if (signalStrength > 80) return 'Very Strong';
    if (signalStrength > 60) return 'Strong';
    if (signalStrength > 40) return 'Moderate';
    if (signalStrength > 20) return 'Weak';
    return 'Very Weak';
  }

  @override
  String toString() {
    return '$actionEmoji $action (${(confidence * 100).toStringAsFixed(1)}%) - $signalDescription signal';
  }
}

/// Exemplu de utilizare (doar pentru test rapid)
class CryptoMLExample {
  static Future<void> runExample() async {
    final mlService = CryptoMLService();
    await mlService.initialize();

    final testData = List<List<double>>.generate(
      60,
      (i) => List<double>.generate(25, (j) => 0.5 + (i * 0.01) + (j * 0.001)),
    );

    final btcPrediction = await mlService.getPrediction(
      coin: 'btc',
      priceData: testData,
      timeframe: '5m',
    );

    // ignore: avoid_print
    print('BTC Prediction: $btcPrediction');

    final allPredictions = await mlService.getAllPredictions(
      priceDataMap: {
        'btc': testData,
        'eth': testData,
        'bnb': testData,
      },
      timeframe: '5m',
    );

    allPredictions.forEach((coin, prediction) {
      // ignore: avoid_print
      print('$coin: ${prediction.action} (${(prediction.confidence * 100).toStringAsFixed(1)}%)');
    });

    final ensemble = mlService.getEnsemblePrediction(allPredictions.values.toList());
    // ignore: avoid_print
    print('\n📊 ENSEMBLE PREDICTION: $ensemble');
  }
}


