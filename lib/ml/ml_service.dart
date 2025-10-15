import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

// Three-class trading signal emitted by the ML model
enum TradingSignal { SELL, HOLD, BUY }

class MLService {
  late Interpreter _interpreter;
  bool isInitialized = false;

  // Exact values provided from Python training/export
  final double optimalTemperature = 2.0;
  final double thresholdBuy = 0.65;
  final double thresholdSell = 0.65;
  final double thresholdConfidence = 0.45;

  // StandardScaler mean/scale for 34 features
  final List<double> scalerMean = const [
    -6.261972257839915e-06, 0.006796661934405448, 50.08088475231509, 0.03008563712782742,
    9823.82488550076, 9818.594870037758, 79.31022523260559, 0.48493856520015854,
    9828.846171224734, 60695.67524339066, 2.4562926747518962e-05, 0.0033280663853553624,
    50.193428876843825, 0.002250047140233959, 9826.481048094374, 9824.661734620438,
    37.98391588509552, 0.49944719110499197, 9828.88318198886, 15922.288971761802,
    -2.690691703945675e-05, 0.01385255107577443, 50.13062467042356, 0.24329538429736575,
    9817.108975947596, 9809.759727246177, 165.4843219833477, 0.4508834511963619,
    9827.9506963306, 242769.9987848025, 0.2499947848217452, 0.2500052151782548,
    0.2500052151782548, 0.2499947848217452
  ];
  final List<double> scalerScale = const [
    0.008217990847552597, 0.004627414390821184, 11.966813622092445, 40.2202206308292,
    17400.13197711625, 17383.03299263452, 158.13079647130243, 0.49977310169893113,
    17413.841149449152, 134554.3121297035, 0.004330410612503934, 0.002564468704936143,
    11.27186920505309, 19.74756328885756, 17408.08955489309, 17403.01118349171,
    79.3565735210178, 0.49999969440223224, 17413.779687643335, 39095.87782191155,
    0.016085978908539657, 0.008152392886587038, 12.674613725189518, 78.69180506920333,
    17375.739395600376, 17340.255001151058, 317.8574209833367, 0.4975817165387207,
    17411.614087598955, 483380.00937141705, 0.4330096908657756, 0.4330157128349147,
    0.4330157128349147, 0.4330096908657756
  ];

  // Model window and features
  final int windowSize = 60;
  int numFeatures = 34; // Updated from model input tensor if available

  MLService();

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/mytrademate_v8_tcn_mtf_float32.tflite');
      isInitialized = true;
      // Try to infer feature count from input tensor shape [1, window, features]
      try {
        final List<int> inputShape = _interpreter.getInputTensor(0).shape;
        if (inputShape.length >= 3) {
          numFeatures = inputShape[2];
        }
        debugPrint('✅ MLService: TFLite model loaded. Input shape=' + inputShape.toString() + ', numFeatures=' + numFeatures.toString());
      } catch (_) {
        debugPrint('⚠️ MLService: Could not read input tensor shape; using numFeatures=' + numFeatures.toString());
      }
    } catch (e) {
      isInitialized = false;
      debugPrint('❌ MLService: Failed to load model → $e');
    }
  }

  Map<String, dynamic> getSignal(List<List<double>> rawInput) {
    if (!isInitialized) {
      throw Exception('MLService not initialized. Call loadModel() first.');
    }
    if (rawInput.length != windowSize) {
      throw Exception('Expected $windowSize timesteps, got ${rawInput.length}.');
    }

    final List<double> rawProbs = _getRawProbabilities(rawInput);
    final List<double> calibrated = _applyTemperature(rawProbs, optimalTemperature);
    final TradingSignal signal = _applyPolicy(calibrated);

    return {
      'signal': signal,
      'probabilities': calibrated,
    };
  }

  List<double> _getRawProbabilities(List<List<double>> rawInput) {
    // Use StandardScaler only if provided and matching current feature count
    final bool useScaling = scalerMean.isNotEmpty &&
        scalerScale.isNotEmpty &&
        scalerMean.length == scalerScale.length &&
        scalerMean.length == numFeatures;

    final List<List<double>> scaledInput = List<List<double>>.generate(windowSize, (int i) {
      final List<double> row = rawInput[i];
      if (!useScaling) {
        if (row.length != numFeatures) {
          throw Exception('Each row must have ' + numFeatures.toString() + ' features.');
        }
        return List<double>.from(row);
      }
      // Scaling path
      if (row.length != numFeatures) {
        throw Exception('Each row must have ' + numFeatures.toString() + ' features for scaling.');
      }
      return List<double>.generate(numFeatures, (int j) => (row[j] - scalerMean[j]) / scalerScale[j]);
    }, growable: false);

    // Prepare tensors: shape [1, windowSize, numFeatures]
    final List<List<List<double>>> inputTensor = <List<List<double>>>[scaledInput];
    final List<List<double>> outputTensor = <List<double>>[List<double>.filled(3, 0.0)];

    try {
      _interpreter.run(inputTensor, outputTensor);
      return outputTensor[0];
    } catch (e) {
      debugPrint('❌ MLService: Inference error → $e');
      return const [0.333, 0.333, 0.333];
    }
  }

  List<double> _applyTemperature(List<double> probs, double temp) {
    final List<double> scaled = probs.map((double p) => pow(p, 1.0 / temp).toDouble()).toList(growable: false);
    final double sum = scaled.fold(0.0, (double a, double b) => a + b);
    if (sum < 1e-9) return const [0.333, 0.333, 0.333];
    return scaled.map((double p) => p / sum).toList(growable: false);
  }

  TradingSignal _applyPolicy(List<double> calibrated) {
    final double probSell = calibrated[0];
    final double probHold = calibrated[1];
    final double probBuy = calibrated[2];

    final double maxProb = [probSell, probHold, probBuy].reduce(max);
    if (maxProb < thresholdConfidence) return TradingSignal.HOLD;

    if (probBuy >= thresholdBuy) return TradingSignal.BUY;
    if (probSell >= thresholdSell) return TradingSignal.SELL;
    return TradingSignal.HOLD;
  }

  void dispose() {
    try {
      _interpreter.close();
    } catch (_) {}
  }
}

// Global singleton for convenient access from UI layers
final MLService globalMlService = MLService();


