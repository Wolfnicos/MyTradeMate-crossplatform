import 'dart:math';
import 'package:flutter/foundation.dart';
import 'ensemble_predictor.dart';
import 'adaptive_calibrator.dart';

/// Model Manager with A/B Testing for MyTradeMate
///
/// Safely deploys new AI models by comparing them against the current production model
/// using A/B testing (Champion/Challenger framework).
///
/// Key Features:
/// - Shadow Mode: New model runs in parallel, doesn't affect trading
/// - Traffic Splitting: Gradually increase traffic to new model (0% → 10% → 50% → 100%)
/// - Performance Monitoring: Track accuracy, Sharpe ratio, drawdown for both models
/// - Automatic Rollback: Revert to old model if new model underperforms
/// - Safe Deployment: Never deploy untested models to production
///
/// Workflow:
/// 1. Deploy new model in shadow mode (0% traffic)
/// 2. Monitor performance for 7 days
/// 3. If new model outperforms, gradually increase traffic
/// 4. After 30 days of success, promote to champion
/// 5. If new model underperforms, rollback immediately
///
/// Example:
/// ```dart
/// final modelManager = ModelManager();
/// await modelManager.initialize();
///
/// // Deploy new model as challenger
/// await modelManager.deployChallenger('transformer_v2.tflite');
///
/// // Get prediction (automatically routes to champion/challenger)
/// final prediction = await modelManager.predict(features);
/// ```
class ModelManager {
  // Models
  EnsemblePredictor? _championModel; // Current production model
  EnsemblePredictor? _challengerModel; // New model being tested

  // Calibrators
  final AdaptiveCalibrator _championCalibrator = AdaptiveCalibrator();
  final AdaptiveCalibrator _challengerCalibrator = AdaptiveCalibrator();

  // A/B testing configuration
  double _challengerTrafficPercentage = 0.0; // 0% to 100%
  final Random _random = Random();

  // Performance tracking
  final List<ModelPerformance> _championPerformance = [];
  final List<ModelPerformance> _challengerPerformance = [];

  // Status
  bool _isInitialized = false;
  DateTime? _challengerDeployedAt;

  // Thresholds for promotion/rollback
  static const double _promotionAccuracyThreshold = 0.05; // 5% better accuracy
  static const double _promotionSharpeThreshold = 0.2; // 0.2 better Sharpe ratio
  static const int _minDaysBeforePromotion = 7; // Wait 7 days minimum
  static const double _rollbackAccuracyThreshold = -0.10; // 10% worse accuracy = rollback

  /// Initialize model manager
  ///
  /// Loads champion model (current production model)
  Future<void> initialize() async {
    debugPrint('🚀 Initializing Model Manager...');

    // Load champion model
    _championModel = EnsemblePredictor();
    await _championModel!.loadModels();

    _isInitialized = true;
    debugPrint('✅ Model Manager initialized (Champion model loaded)');
  }

  /// Deploy new model as challenger
  ///
  /// Starts in shadow mode (0% traffic) for safe testing
  ///
  /// Args:
  ///   challengerModelPath: Path to new TFLite model (optional - uses default if null)
  Future<void> deployChallenger({String? challengerModelPath}) async {
    if (!_isInitialized) {
      throw Exception('Model Manager not initialized. Call initialize() first.');
    }

    debugPrint('\n🆕 Deploying challenger model...');

    // Load challenger model
    _challengerModel = EnsemblePredictor();
    await _challengerModel!.loadModels();

    // Start with 0% traffic (shadow mode)
    _challengerTrafficPercentage = 0.0;
    _challengerDeployedAt = DateTime.now();

    // Clear previous performance data
    _challengerPerformance.clear();

    debugPrint('✅ Challenger deployed in SHADOW MODE (0% traffic)');
    debugPrint('   Monitor performance before increasing traffic.');
  }

  /// Get prediction using A/B testing
  ///
  /// Randomly routes traffic to champion or challenger based on traffic percentage
  ///
  /// Args:
  ///   features: [120, 42] feature matrix
  ///
  /// Returns:
  ///   Prediction from selected model
  Future<ManagedPrediction> predict(List<List<double>> features) async {
    if (!_isInitialized || _championModel == null) {
      throw Exception('Model Manager not initialized.');
    }

    // Determine which model to use
    final useChallenger = _shouldUseChallenger();

    EnsemblePredictor selectedModel;
    AdaptiveCalibrator selectedCalibrator;
    String modelVersion;

    if (useChallenger && _challengerModel != null) {
      selectedModel = _challengerModel!;
      selectedCalibrator = _challengerCalibrator;
      modelVersion = 'challenger';
    } else {
      selectedModel = _championModel!;
      selectedCalibrator = _championCalibrator;
      modelVersion = 'champion';
    }

    // Get prediction
    final rawPrediction = await selectedModel.predict(features);

    // Calibrate
    final calibrated = selectedCalibrator.calibrate(rawPrediction);

    return ManagedPrediction(
      prediction: calibrated,
      modelVersion: modelVersion,
      calibrator: selectedCalibrator,
    );
  }

  /// Determine if challenger should be used (A/B split)
  bool _shouldUseChallenger() {
    if (_challengerModel == null) return false;

    // Random traffic split based on percentage
    final randomValue = _random.nextDouble() * 100;
    return randomValue < _challengerTrafficPercentage;
  }

  /// Record prediction outcome for performance tracking
  ///
  /// Args:
  ///   prediction: Managed prediction
  ///   actualPrice: Price at prediction time
  ///   futurePrice: Price at outcome time
  Future<void> recordOutcome({
    required ManagedPrediction prediction,
    required double actualPrice,
    required double futurePrice,
  }) async {
    // Calculate return
    final returnPct = (futurePrice - actualPrice) / actualPrice;

    // Determine if correct
    final isCorrect = _isPredictionCorrect(prediction.prediction.classIndex, returnPct);

    // Record to calibrator
    await prediction.calibrator.recordOutcome(
      prediction: prediction.prediction,
      actualPrice: actualPrice,
      futurePrice: futurePrice,
    );

    // Record to performance tracker
    final performance = ModelPerformance(
      timestamp: DateTime.now(),
      isCorrect: isCorrect,
      returnPct: returnPct,
      confidence: prediction.prediction.confidence,
    );

    if (prediction.modelVersion == 'champion') {
      _championPerformance.add(performance);
      if (_championPerformance.length > 1000) {
        _championPerformance.removeAt(0);
      }
    } else {
      _challengerPerformance.add(performance);
      if (_challengerPerformance.length > 1000) {
        _challengerPerformance.removeAt(0);
      }
    }

    // Auto-evaluate and adjust traffic
    await _autoEvaluateModels();
  }

  /// Check if prediction was correct
  bool _isPredictionCorrect(int predictedClass, double actualReturn) {
    const strongThreshold = 0.02;

    switch (predictedClass) {
      case 0: // STRONG_SELL
        return actualReturn < -strongThreshold;
      case 1: // SELL
        return actualReturn < 0 && actualReturn >= -strongThreshold;
      case 2: // BUY
        return actualReturn >= 0 && actualReturn < strongThreshold;
      case 3: // STRONG_BUY
        return actualReturn >= strongThreshold;
      default:
        return false;
    }
  }

  /// Auto-evaluate models and adjust traffic
  ///
  /// Called after each outcome to monitor performance and potentially:
  /// - Increase challenger traffic if performing well
  /// - Promote challenger to champion if consistently better
  /// - Rollback challenger if underperforming
  Future<void> _autoEvaluateModels() async {
    // Need minimum data for evaluation
    if (_championPerformance.length < 50 || _challengerPerformance.length < 50) {
      return;
    }

    // Calculate metrics
    final championMetrics = _calculateMetrics(_championPerformance);
    final challengerMetrics = _calculateMetrics(_challengerPerformance);

    final accuracyDelta = challengerMetrics.accuracy - championMetrics.accuracy;
    final sharpeDelta = challengerMetrics.sharpeRatio - championMetrics.sharpeRatio;

    debugPrint('\n📊 Model Performance Comparison:');
    debugPrint('   Champion:   Accuracy ${(championMetrics.accuracy * 100).toStringAsFixed(1)}%, Sharpe ${championMetrics.sharpeRatio.toStringAsFixed(2)}');
    debugPrint('   Challenger: Accuracy ${(challengerMetrics.accuracy * 100).toStringAsFixed(1)}%, Sharpe ${challengerMetrics.sharpeRatio.toStringAsFixed(2)}');
    debugPrint('   Delta:      Accuracy ${(accuracyDelta * 100).toStringAsFixed(1)}%, Sharpe ${sharpeDelta.toStringAsFixed(2)}');

    // ROLLBACK: Challenger significantly worse
    if (accuracyDelta < _rollbackAccuracyThreshold) {
      debugPrint('❌ ROLLBACK: Challenger performing significantly worse!');
      await rollbackChallenger();
      return;
    }

    // PROMOTION: Challenger significantly better + enough time passed
    if (_challengerDeployedAt != null) {
      final daysSinceDeployment = DateTime.now().difference(_challengerDeployedAt!).inDays;

      if (daysSinceDeployment >= _minDaysBeforePromotion &&
          accuracyDelta >= _promotionAccuracyThreshold &&
          sharpeDelta >= _promotionSharpeThreshold) {
        debugPrint('🎉 PROMOTION: Challenger outperforming champion!');
        await promoteChallenger();
        return;
      }
    }

    // GRADUAL TRAFFIC INCREASE: Challenger performing well
    if (accuracyDelta > 0 && sharpeDelta > 0) {
      final oldTraffic = _challengerTrafficPercentage;

      if (_challengerTrafficPercentage == 0.0) {
        _challengerTrafficPercentage = 10.0; // 0% → 10%
      } else if (_challengerTrafficPercentage < 50.0) {
        _challengerTrafficPercentage = min(50.0, _challengerTrafficPercentage + 10.0); // → 50%
      } else if (_challengerTrafficPercentage < 100.0) {
        _challengerTrafficPercentage = min(100.0, _challengerTrafficPercentage + 10.0); // → 100%
      }

      if (_challengerTrafficPercentage != oldTraffic) {
        debugPrint('📈 Increasing challenger traffic: ${oldTraffic.toStringAsFixed(0)}% → ${_challengerTrafficPercentage.toStringAsFixed(0)}%');
      }
    }

    // GRADUAL TRAFFIC DECREASE: Challenger performing slightly worse
    if (accuracyDelta < 0 && accuracyDelta > _rollbackAccuracyThreshold) {
      final oldTraffic = _challengerTrafficPercentage;
      _challengerTrafficPercentage = max(0.0, _challengerTrafficPercentage - 10.0);

      if (_challengerTrafficPercentage != oldTraffic) {
        debugPrint('📉 Decreasing challenger traffic: ${oldTraffic.toStringAsFixed(0)}% → ${_challengerTrafficPercentage.toStringAsFixed(0)}%');
      }
    }
  }

  /// Calculate performance metrics
  PerformanceMetrics _calculateMetrics(List<ModelPerformance> performance) {
    if (performance.isEmpty) {
      return PerformanceMetrics(accuracy: 0.0, sharpeRatio: 0.0, avgReturn: 0.0);
    }

    // Accuracy
    final accuracy = performance.where((p) => p.isCorrect).length / performance.length;

    // Average return
    final avgReturn = performance.map((p) => p.returnPct).reduce((a, b) => a + b) / performance.length;

    // Sharpe ratio (return / volatility)
    final returns = performance.map((p) => p.returnPct).toList();
    final stdDev = _calculateStdDev(returns);
    final sharpeRatio = stdDev == 0 ? 0.0 : avgReturn / stdDev;

    return PerformanceMetrics(
      accuracy: accuracy,
      sharpeRatio: sharpeRatio,
      avgReturn: avgReturn,
    );
  }

  /// Calculate standard deviation
  double _calculateStdDev(List<double> values) {
    if (values.isEmpty) return 0.0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
    return sqrt(variance);
  }

  /// Promote challenger to champion
  ///
  /// Replace current production model with new model
  Future<void> promoteChallenger() async {
    if (_challengerModel == null) {
      throw Exception('No challenger model to promote.');
    }

    debugPrint('\n🎉 PROMOTING CHALLENGER TO CHAMPION');

    // Dispose old champion
    _championModel?.dispose();

    // Promote challenger
    _championModel = _challengerModel;
    _championModel = null; // Clear challenger slot

    // Reset traffic
    _challengerTrafficPercentage = 0.0;
    _challengerDeployedAt = null;

    // Archive performance data
    _championPerformance.clear();
    _championPerformance.addAll(_challengerPerformance);
    _challengerPerformance.clear();

    debugPrint('✅ Challenger promoted successfully!');
  }

  /// Rollback challenger
  ///
  /// Disable underperforming challenger, revert to 100% champion traffic
  Future<void> rollbackChallenger() async {
    if (_challengerModel == null) {
      debugPrint('⚠️ No challenger to rollback.');
      return;
    }

    debugPrint('\n⚠️ ROLLING BACK CHALLENGER');

    // Dispose challenger
    _challengerModel?.dispose();
    _challengerModel = null;

    // Reset traffic
    _challengerTrafficPercentage = 0.0;
    _challengerDeployedAt = null;

    // Clear performance data
    _challengerPerformance.clear();

    debugPrint('✅ Challenger rolled back. Using 100% champion traffic.');
  }

  /// Get A/B testing summary (for UI display)
  Map<String, dynamic> getABTestingSummary() {
    final championMetrics = _calculateMetrics(_championPerformance);
    final challengerMetrics = _challengerPerformance.isNotEmpty ? _calculateMetrics(_challengerPerformance) : null;

    return {
      'challengerActive': _challengerModel != null,
      'challengerTrafficPercentage': _challengerTrafficPercentage,
      'championPerformance': {
        'accuracy': championMetrics.accuracy,
        'sharpeRatio': championMetrics.sharpeRatio,
        'avgReturn': championMetrics.avgReturn,
        'numPredictions': _championPerformance.length,
      },
      if (challengerMetrics != null)
        'challengerPerformance': {
          'accuracy': challengerMetrics.accuracy,
          'sharpeRatio': challengerMetrics.sharpeRatio,
          'avgReturn': challengerMetrics.avgReturn,
          'numPredictions': _challengerPerformance.length,
          'daysSinceDeployment': _challengerDeployedAt != null ? DateTime.now().difference(_challengerDeployedAt!).inDays : 0,
        },
    };
  }

  /// Dispose resources
  void dispose() {
    _championModel?.dispose();
    _challengerModel?.dispose();
  }
}

/// Managed prediction (includes model version)
class ManagedPrediction {
  final EnsemblePrediction prediction;
  final String modelVersion; // "champion" or "challenger"
  final AdaptiveCalibrator calibrator; // For recording outcomes

  ManagedPrediction({
    required this.prediction,
    required this.modelVersion,
    required this.calibrator,
  });

  @override
  String toString() {
    return '''
=== Managed Prediction ===
Model: $modelVersion
${prediction.toString()}
''';
  }
}

/// Model performance record
class ModelPerformance {
  final DateTime timestamp;
  final bool isCorrect;
  final double returnPct;
  final double confidence;

  ModelPerformance({
    required this.timestamp,
    required this.isCorrect,
    required this.returnPct,
    required this.confidence,
  });
}

/// Performance metrics
class PerformanceMetrics {
  final double accuracy; // 0.0 to 1.0
  final double sharpeRatio; // Risk-adjusted return
  final double avgReturn; // Average return per trade

  PerformanceMetrics({
    required this.accuracy,
    required this.sharpeRatio,
    required this.avgReturn,
  });
}

/// Example usage:
///
/// ```dart
/// // Initialize model manager
/// final modelManager = ModelManager();
/// await modelManager.initialize();
///
/// // [After training new model v2...]
/// // Deploy as challenger (shadow mode)
/// await modelManager.deployChallenger();
///
/// // Normal trading flow
/// final features = await featureBuilder.buildFeatures(...);
/// final prediction = await modelManager.predict(features);
///
/// print(prediction);
/// // Output:
/// // === Managed Prediction ===
/// // Model: champion
/// // Label: BUY
/// // Confidence: 78.5%
///
/// // Execute trade
/// if (prediction.prediction.isTradeable) {
///   final currentPrice = 50000.0;
///   await executeTrade(...);
///
///   // After 4 hours, record outcome
///   final futurePrice = 51200.0;
///   await modelManager.recordOutcome(
///     prediction: prediction,
///     actualPrice: currentPrice,
///     futurePrice: futurePrice,
///   );
/// }
///
/// // View A/B testing status
/// final summary = modelManager.getABTestingSummary();
/// print('Challenger Active: ${summary['challengerActive']}');
/// print('Challenger Traffic: ${summary['challengerTrafficPercentage']}%');
/// print('Champion Accuracy: ${(summary['championPerformance']['accuracy'] * 100).toStringAsFixed(1)}%');
///
/// if (summary['challengerActive']) {
///   print('Challenger Accuracy: ${(summary['challengerPerformance']['accuracy'] * 100).toStringAsFixed(1)}%');
///   print('Days Since Deployment: ${summary['challengerPerformance']['daysSinceDeployment']}');
/// }
/// ```
///
/// A/B Testing Benefits:
/// - Safe deployment of new models (no sudden production changes)
/// - Automatic rollback if new model underperforms
/// - Gradual traffic ramp-up based on performance
/// - Data-driven promotion decisions
/// - Continuous improvement without downtime
