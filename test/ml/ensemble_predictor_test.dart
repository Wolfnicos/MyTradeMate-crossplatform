import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ml/ensemble_predictor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EnsemblePredictor Tests', () {
    late EnsemblePredictor predictor;

    setUp(() {
      predictor = EnsemblePredictor();
    });

    test('Model loading test', () async {
      // Load models
      await predictor.loadModels();

      // Check if at least one model loaded
      expect(predictor.isLoaded, true);

      // Print status
      print('✅ Models loaded successfully');
      print(predictor.performanceSummary);
    });

    test('Prediction test with dummy data', () async {
      // Load models first
      await predictor.loadModels();

      // Create dummy feature matrix (120 timesteps × 42 features)
      final dummyFeatures = List.generate(
        120,
        (i) => List.generate(42, (j) => 0.5 + (i * 0.01) + (j * 0.001)),
      );

      // Make prediction
      final prediction = await predictor.predict(dummyFeatures);

      // Verify prediction structure
      expect(prediction.label, isNotEmpty);
      expect(prediction.confidence, greaterThan(0.0));
      expect(prediction.confidence, lessThanOrEqualTo(1.0));
      expect(prediction.probabilities.length, 4); // 4 classes

      // Print results
      print('🎯 Prediction: ${prediction.label}');
      print('   Confidence: ${(prediction.confidence * 100).toStringAsFixed(1)}%');
      print('   Probabilities:');
      print('      STRONG_SELL: ${(prediction.probabilities[0] * 100).toStringAsFixed(1)}%');
      print('      SELL: ${(prediction.probabilities[1] * 100).toStringAsFixed(1)}%');
      print('      BUY: ${(prediction.probabilities[2] * 100).toStringAsFixed(1)}%');
      print('      STRONG_BUY: ${(prediction.probabilities[3] * 100).toStringAsFixed(1)}%');

      print('\n${predictor.performanceSummary}');
    });

    test('Multiple predictions performance test', () async {
      // Load models
      await predictor.loadModels();

      // Create dummy feature matrix
      final dummyFeatures = List.generate(
        120,
        (i) => List.generate(42, (j) => 0.5),
      );

      // Run 10 predictions and measure average latency
      final latencies = <int>[];
      for (int i = 0; i < 10; i++) {
        final start = DateTime.now();
        await predictor.predict(dummyFeatures);
        final latency = DateTime.now().difference(start).inMilliseconds;
        latencies.add(latency);
      }

      final avgLatency = latencies.reduce((a, b) => a + b) / latencies.length;

      print('⚡ Performance Test Results:');
      print('   Average latency: ${avgLatency.toStringAsFixed(1)}ms');
      print('   Min latency: ${latencies.reduce((a, b) => a < b ? a : b)}ms');
      print('   Max latency: ${latencies.reduce((a, b) => a > b ? a : b)}ms');
      print('\n${predictor.performanceSummary}');

      // Latency should be under 500ms for good user experience
      expect(avgLatency, lessThan(500));
    });
  });
}
