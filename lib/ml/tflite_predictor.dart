import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

/// Lightweight wrapper around a TensorFlow Lite model.
/// If loading fails (e.g. missing asset), predictions gracefully return 0.5.
class TFLitePredictor {
  tfl.Interpreter? _interpreter;
  bool get isReady => _interpreter != null;

  Future<void> init({String assetPath = 'assets/models/mytrademate_v8_tcn_mtf_dynamic_int8.tflite'}) async {
    try {
      _interpreter = await tfl.Interpreter.fromAsset(assetPath);
    } catch (_) {
      _interpreter = null;
    }
  }

  /// Returns a bullish probability in [0,1]. Fallback is 0.5 if model not loaded.
  double predictBullishProbability(List<double> features) {
    final tfl.Interpreter? interpreter = _interpreter;
    if (interpreter == null) return 0.5;

    final int featureLen = features.length;
    final Float32List input = Float32List(featureLen);
    for (int i = 0; i < featureLen; i++) {
      input[i] = features[i].toDouble();
    }

    try {
      final Float32List output = Float32List(1);
      interpreter.run(input, output);
      final double p = output.isNotEmpty ? output[0].toDouble() : 0.5;
      if (p.isNaN) return 0.5;
      if (p < 0) return 0.0;
      if (p > 1) return 1.0;
      return p;
    } catch (_) {
      return 0.5;
    }
  }
}

/// Global singleton for easy access across the app
final TFLitePredictor globalPredictor = TFLitePredictor();

