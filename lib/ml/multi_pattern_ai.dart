import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Lightweight TFLite wrapper for a single-vector, 3-class model (SELL/BUY/HOLD)
/// Model path: assets/models/multi_pattern_model.tflite
/// Optional scaler path: assets/models/multi_pattern_scaler.json
/// Expected scaler json format: { "mean": [...], "scale": [...] }
class MultiPatternAI {
  late final Interpreter _interpreter;
  bool _loaded = false;

  List<double> _mean = const <double>[];
  List<double> _scale = const <double>[];

  Future<void> load() async {
    _interpreter = await Interpreter.fromAsset('assets/models/multi_pattern_model.tflite');
    await _tryLoadScalerJson();
    _loaded = true;
    try {
      final inputShape = _interpreter.getInputTensor(0).shape;
      debugPrint('✅ MultiPatternAI loaded. Input shape=$inputShape, scalerLen=${_mean.length}');
    } catch (_) {}
  }

  Future<void> _tryLoadScalerJson() async {
    try {
      final String raw = await rootBundle.loadString('assets/models/multi_pattern_scaler.json');
      final Map<String, dynamic> m = json.decode(raw) as Map<String, dynamic>;
      final List<dynamic>? mm = m['mean'] as List<dynamic>?;
      final List<dynamic>? ss = m['scale'] as List<dynamic>?;
      if (mm != null && ss != null && mm.length == ss.length) {
        _mean = mm.map((e) => (e as num).toDouble()).toList(growable: false);
        _scale = ss.map((e) => (e as num).toDouble()).toList(growable: false);
      }
    } catch (e) {
      debugPrint('ℹ️ MultiPatternAI: scaler json not found/invalid, proceed without scaling. ($e)');
      _mean = const <double>[];
      _scale = const <double>[];
    }
  }

  /// Predict returns one of: SELL, BUY, HOLD
  String predict(List<double> input) {
    if (!_loaded) {
      throw StateError('MultiPatternAI not loaded. Call load() first.');
    }
    if (_mean.isNotEmpty && (_mean.length != input.length || _scale.length != input.length)) {
      throw ArgumentError('Input length (${input.length}) != scaler length (${_mean.length}).');
    }

    final List<double> x = _scaleInput(input);
    final List<List<double>> inTensor = <List<double>>[x];
    final List<List<double>> outTensor = <List<double>>[List<double>.filled(3, 0.0)];

    _interpreter.run(inTensor, outTensor);

    final List<double> probs = outTensor[0];
    final int predIdx = _argMax(probs);
    return const <String>['SELL', 'BUY', 'HOLD'][predIdx];
  }

  List<double> _scaleInput(List<double> input) {
    if (_mean.isEmpty || _scale.isEmpty) return input;
    return List<double>.generate(
      input.length,
      (int i) => (input[i] - _mean[i]) / (_scale[i] == 0 ? 1.0 : _scale[i]),
      growable: false,
    );
  }

  int _argMax(List<double> xs) {
    int idx = 0;
    double best = xs[0];
    for (int i = 1; i < xs.length; i++) {
      if (xs[i] > best) {
        best = xs[i];
        idx = i;
      }
    }
    return idx;
  }

  void dispose() {
    if (_loaded) {
      try {
        _interpreter.close();
      } catch (_) {}
      _loaded = false;
    }
  }
}

final MultiPatternAI multiPatternAI = MultiPatternAI();


