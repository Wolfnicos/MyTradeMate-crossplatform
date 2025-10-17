import 'dart:math';
import 'package:flutter/foundation.dart';
import 'ensemble_predictor.dart';

/// Adaptive Calibrator for MyTradeMate
///
/// Dynamically adjusts model confidence scores based on recent performance.
/// This solves the "overconfidence" problem where models may be poorly calibrated
/// (e.g., predicting 90% confidence but only correct 60% of the time).
///
/// Key Features:
/// - Temperature Scaling: Adjusts prediction sharpness based on accuracy
/// - Rolling Window: Tracks last 100 predictions for adaptive calibration
/// - Per-Class Calibration: Different adjustments for STRONG_SELL/SELL/BUY/STRONG_BUY
/// - Confidence Thresholds: Dynamic minimum confidence based on win rate
///
/// Example:
/// ```dart
/// final calibrator = AdaptiveCalibrator();
/// final prediction = await ensemblePredictor.predict(features);
///
/// // Calibrate prediction
/// final calibrated = calibrator.calibrate(prediction);
///
/// // Update with actual outcome
/// await calibrator.recordOutcome(
///   prediction: prediction,
///   actualPrice: currentPrice,
///   futurePrice: priceIn4Hours,
/// );
/// ```
class AdaptiveCalibrator {
  // Performance tracking
  final List<PredictionOutcome> _history = [];
  static const int _maxHistory = 100; // Last 100 predictions

  // Temperature parameter (adaptive)
  double _temperature = 1.0; // 1.0 = no adjustment, >1.0 = softer, <1.0 = sharper

  // Per-class accuracy tracking
  final Map<int, ClassPerformance> _classPerformance = {
    0: ClassPerformance(className: 'STRONG_SELL'),
    1: ClassPerformance(className: 'SELL'),
    2: ClassPerformance(className: 'BUY'),
    3: ClassPerformance(className: 'STRONG_BUY'),
  };

  // Confidence thresholds (adaptive)
  double _minConfidenceThreshold = 0.60;

  // Calibration update frequency
  int _predictionCount = 0;
  static const int _recalibrationInterval = 10; // Recalibrate every 10 predictions

  /// Calibrate prediction probabilities
  ///
  /// Applies temperature scaling to adjust confidence based on recent accuracy
  ///
  /// Args:
  ///   prediction: Raw ensemble prediction
  ///
  /// Returns:
  ///   Calibrated prediction with adjusted probabilities
  EnsemblePrediction calibrate(EnsemblePrediction prediction) {
    // Apply temperature scaling
    final calibratedProbs = _applyTemperatureScaling(prediction.probabilities);

    // Get new max class
    final maxIndex = calibratedProbs.indexOf(calibratedProbs.reduce(max));
    final confidence = calibratedProbs[maxIndex];

    return EnsemblePrediction(
      label: _classLabels[maxIndex],
      classIndex: maxIndex,
      confidence: confidence,
      probabilities: calibratedProbs,
      modelContributions: prediction.modelContributions,
    );
  }

  /// Apply temperature scaling
  ///
  /// Formula: p_calibrated = softmax(logits / T)
  /// - T > 1: Softer probabilities (less confident)
  /// - T < 1: Sharper probabilities (more confident)
  /// - T = 1: No change
  List<double> _applyTemperatureScaling(List<double> probs) {
    // Convert probabilities to logits
    final logits = probs.map((p) => log(p + 1e-10)).toList();

    // Scale by temperature
    final scaledLogits = logits.map((l) => l / _temperature).toList();

    // Apply softmax
    return _softmax(scaledLogits);
  }

  /// Softmax function
  List<double> _softmax(List<double> logits) {
    // Subtract max for numerical stability
    final maxLogit = logits.reduce(max);
    final expLogits = logits.map((l) => exp(l - maxLogit)).toList();
    final sumExp = expLogits.reduce((a, b) => a + b);

    return expLogits.map((e) => e / sumExp).toList();
  }

  /// Record prediction outcome for calibration
  ///
  /// Args:
  ///   prediction: Original prediction
  ///   actualPrice: Price at prediction time
  ///   futurePrice: Price 4 hours later (prediction horizon)
  Future<void> recordOutcome({
    required EnsemblePrediction prediction,
    required double actualPrice,
    required double futurePrice,
  }) async {
    // Calculate actual return
    final returnPct = (futurePrice - actualPrice) / actualPrice;

    // Determine if prediction was correct
    final isCorrect = _isPredictionCorrect(prediction.classIndex, returnPct);

    // Create outcome record
    final outcome = PredictionOutcome(
      timestamp: DateTime.now(),
      predictedClass: prediction.classIndex,
      confidence: prediction.confidence,
      actualReturn: returnPct,
      isCorrect: isCorrect,
    );

    // Add to history
    _history.add(outcome);
    if (_history.length > _maxHistory) {
      _history.removeAt(0); // Remove oldest
    }

    // Update class performance
    _classPerformance[prediction.classIndex]!.addOutcome(isCorrect, prediction.confidence);

    // Increment counter and recalibrate if needed
    _predictionCount++;
    if (_predictionCount % _recalibrationInterval == 0) {
      await _recalibrate();
    }
  }

  /// Check if prediction was correct based on actual return
  ///
  /// Thresholds:
  /// - STRONG_SELL: < -2% return
  /// - SELL: -2% to 0% return
  /// - BUY: 0% to +2% return
  /// - STRONG_BUY: > +2% return
  bool _isPredictionCorrect(int predictedClass, double actualReturn) {
    const strongThreshold = 0.02; // 2%

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

  /// Recalibrate temperature and thresholds
  ///
  /// Adjusts temperature based on calibration error (ECE - Expected Calibration Error)
  Future<void> _recalibrate() async {
    if (_history.length < 20) {
      debugPrint('⚠️ Insufficient data for calibration (${_history.length} samples)');
      return;
    }

    debugPrint('\n🔧 Recalibrating adaptive calibrator...');

    // Calculate overall accuracy
    final accuracy = _history.where((o) => o.isCorrect).length / _history.length;

    // Calculate Expected Calibration Error (ECE)
    final ece = _calculateECE();

    // Adjust temperature based on ECE
    final oldTemperature = _temperature;

    if (ece > 0.15) {
      // High calibration error → increase temperature (soften probabilities)
      _temperature = min(2.0, _temperature * 1.2);
    } else if (ece < 0.05 && accuracy > 0.65) {
      // Well calibrated and accurate → decrease temperature (sharpen probabilities)
      _temperature = max(0.5, _temperature * 0.9);
    }

    // Adjust minimum confidence threshold
    if (accuracy < 0.55) {
      // Low accuracy → increase threshold (be more conservative)
      _minConfidenceThreshold = min(0.80, _minConfidenceThreshold + 0.05);
    } else if (accuracy > 0.70) {
      // High accuracy → decrease threshold (allow more trades)
      _minConfidenceThreshold = max(0.50, _minConfidenceThreshold - 0.05);
    }

    debugPrint('📊 Calibration Results:');
    debugPrint('   Accuracy: ${(accuracy * 100).toStringAsFixed(1)}%');
    debugPrint('   ECE: ${(ece * 100).toStringAsFixed(1)}%');
    debugPrint('   Temperature: ${oldTemperature.toStringAsFixed(2)} → ${_temperature.toStringAsFixed(2)}');
    debugPrint('   Min Confidence: ${(_minConfidenceThreshold * 100).toStringAsFixed(0)}%');
  }

  /// Calculate Expected Calibration Error (ECE)
  ///
  /// Measures how well predicted confidences match actual accuracy.
  /// Lower is better (0 = perfect calibration).
  double _calculateECE() {
    const numBins = 10;
    final binSize = 1.0 / numBins;

    double ece = 0.0;

    for (int i = 0; i < numBins; i++) {
      final binLower = i * binSize;
      final binUpper = (i + 1) * binSize;

      // Get predictions in this confidence bin
      final binOutcomes = _history.where((o) => o.confidence >= binLower && o.confidence < binUpper).toList();

      if (binOutcomes.isEmpty) continue;

      // Average confidence in bin
      final avgConfidence = binOutcomes.map((o) => o.confidence).reduce((a, b) => a + b) / binOutcomes.length;

      // Actual accuracy in bin
      final avgAccuracy = binOutcomes.where((o) => o.isCorrect).length / binOutcomes.length;

      // Contribution to ECE
      final weight = binOutcomes.length / _history.length;
      ece += weight * (avgConfidence - avgAccuracy).abs();
    }

    return ece;
  }

  /// Get calibration summary (for UI display)
  Map<String, dynamic> getCalibrationSummary() {
    final accuracy = _history.isEmpty ? 0.0 : _history.where((o) => o.isCorrect).length / _history.length;

    return {
      'temperature': _temperature,
      'minConfidenceThreshold': _minConfidenceThreshold,
      'overallAccuracy': accuracy,
      'numPredictions': _history.length,
      'classPerformance': _classPerformance.map((key, value) => MapEntry(
            value.className,
            {
              'accuracy': value.accuracy,
              'avgConfidence': value.avgConfidence,
              'count': value.count,
            },
          )),
    };
  }

  /// Check if prediction is tradeable after calibration
  bool isTradeable(EnsemblePrediction prediction) {
    return prediction.confidence >= _minConfidenceThreshold;
  }

  /// Get current minimum confidence threshold
  double get minConfidenceThreshold => _minConfidenceThreshold;

  /// Get current temperature
  double get temperature => _temperature;

  /// Class labels (must match EnsemblePredictor)
  static const List<String> _classLabels = [
    'STRONG_SELL',
    'SELL',
    'BUY',
    'STRONG_BUY',
  ];
}

/// Prediction outcome record
class PredictionOutcome {
  final DateTime timestamp;
  final int predictedClass; // 0, 1, 2, 3
  final double confidence; // 0.0 to 1.0
  final double actualReturn; // Actual price return
  final bool isCorrect;

  PredictionOutcome({
    required this.timestamp,
    required this.predictedClass,
    required this.confidence,
    required this.actualReturn,
    required this.isCorrect,
  });
}

/// Per-class performance tracking
class ClassPerformance {
  final String className;
  int _correct = 0;
  int _total = 0;
  double _sumConfidence = 0.0;

  ClassPerformance({required this.className});

  void addOutcome(bool isCorrect, double confidence) {
    _total++;
    _sumConfidence += confidence;
    if (isCorrect) _correct++;
  }

  double get accuracy => _total == 0 ? 0.0 : _correct / _total;
  double get avgConfidence => _total == 0 ? 0.0 : _sumConfidence / _total;
  int get count => _total;

  @override
  String toString() {
    return '$className: ${(_accuracy * 100).toStringAsFixed(1)}% accuracy, ${(_avgConfidence * 100).toStringAsFixed(1)}% avg confidence ($count samples)';
  }

  double get _accuracy => accuracy;
  double get _avgConfidence => avgConfidence;
}

/// Example usage:
///
/// ```dart
/// // Initialize components
/// final ensemblePredictor = EnsemblePredictor();
/// await ensemblePredictor.loadModels();
///
/// final calibrator = AdaptiveCalibrator();
///
/// // Get and calibrate prediction
/// final rawPrediction = await ensemblePredictor.predict(features);
/// final calibrated = calibrator.calibrate(rawPrediction);
///
/// print('Raw confidence: ${(rawPrediction.confidence * 100).toStringAsFixed(1)}%');
/// print('Calibrated confidence: ${(calibrated.confidence * 100).toStringAsFixed(1)}%');
///
/// // Execute trade if tradeable
/// if (calibrator.isTradeable(calibrated)) {
///   final currentPrice = 50000.0;
///
///   await executeTrade(
///     signal: calibrated.toSignalType(),
///     size: baseSize * calibrated.confidence,
///   );
///
///   // After 4 hours, record outcome
///   final futurePrice = 51200.0; // Price 4 hours later
///   await calibrator.recordOutcome(
///     prediction: calibrated,
///     actualPrice: currentPrice,
///     futurePrice: futurePrice,
///   );
/// }
///
/// // View calibration status
/// final summary = calibrator.getCalibrationSummary();
/// print('Overall Accuracy: ${(summary['overallAccuracy'] * 100).toStringAsFixed(1)}%');
/// print('Temperature: ${summary['temperature'].toStringAsFixed(2)}');
/// print('Min Confidence: ${(summary['minConfidenceThreshold'] * 100).toStringAsFixed(0)}%');
/// ```
///
/// Benefits of Adaptive Calibration:
/// - Prevents overconfident predictions from causing losses
/// - Dynamically adjusts to changing market conditions
/// - Improves expected value of trades over time
/// - Provides per-class performance insights
