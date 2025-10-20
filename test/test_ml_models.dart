import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ml/crypto_ml_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CryptoMLService Tests', () {
    late CryptoMLService mlService;

    setUp(() {
      mlService = CryptoMLService();
    });

    tearDown(() {
      mlService.dispose();
    });

    test('Load all 21 models (7 coins × 3 timeframes)', () async {
      // Test initialization
      await mlService.initialize();

      // Generate test data: 60 timesteps × 25 features
      final testData = List<List<double>>.generate(
        60,
        (i) => List<double>.generate(25, (j) => 0.5 + (i * 0.01) + (j * 0.001)),
      );

      // Test general models
      for (final tf in ['5m', '15m', '1h']) {
        final prediction = await mlService.getPrediction(
          coin: 'general',
          priceData: testData,
          timeframe: tf,
        );

        expect(prediction, isNotNull);
        expect(prediction.action, isIn(['SELL', 'HOLD', 'BUY']));
        expect(prediction.confidence, greaterThan(0));
        expect(prediction.confidence, lessThanOrEqualTo(1));

        print('✅ general_$tf: ${prediction.action} (${(prediction.confidence * 100).toStringAsFixed(1)}%)');
      }

      // Test coin-specific models
      final coins = ['btc', 'eth', 'bnb', 'sol', 'trump', 'wlfi'];
      for (final coin in coins) {
        for (final tf in ['5m', '15m', '1h']) {
          final prediction = await mlService.getPrediction(
            coin: coin,
            priceData: testData,
            timeframe: tf,
          );

          expect(prediction, isNotNull);
          expect(prediction.action, isIn(['SELL', 'HOLD', 'BUY']));

          print('✅ ${coin}_$tf: ${prediction.action} (${(prediction.confidence * 100).toStringAsFixed(1)}%)');
        }
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('Test ensemble prediction across timeframes', () async {
      await mlService.initialize();

      final testData = List<List<double>>.generate(
        60,
        (i) => List<double>.generate(25, (j) => 0.5 + (i * 0.01)),
      );

      // Get predictions for BTC across different timeframes
      final pred5m = await mlService.getPrediction(
        coin: 'btc',
        priceData: testData,
        timeframe: '5m',
      );

      final pred15m = await mlService.getPrediction(
        coin: 'btc',
        priceData: testData,
        timeframe: '15m',
      );

      final pred1h = await mlService.getPrediction(
        coin: 'btc',
        priceData: testData,
        timeframe: '1h',
      );

      // Combine predictions
      final ensemble = mlService.getEnsemblePrediction([pred5m, pred15m, pred1h]);

      expect(ensemble, isNotNull);
      expect(ensemble.isEnsemble, isTrue);

      print('\n📊 BTC Ensemble Prediction:');
      print('   Action: ${ensemble.action}');
      print('   Confidence: ${(ensemble.confidence * 100).toStringAsFixed(1)}%');
      print('   Signal Strength: ${ensemble.signalStrength.toStringAsFixed(1)}');
    });

    test('Test fallback to general model when coin model not available', () async {
      await mlService.initialize();

      final testData = List<List<double>>.generate(
        60,
        (i) => List<double>.generate(25, (j) => 0.5),
      );

      // Try to get prediction for a coin that doesn't have a model
      final prediction = await mlService.getPrediction(
        coin: 'unknown_coin',
        priceData: testData,
        timeframe: '5m',
      );

      // Should fallback to general model
      expect(prediction, isNotNull);
      print('✅ Fallback to general model works: ${prediction.action}');
    });

    test('Test all coins with getAllPredictions', () async {
      await mlService.initialize();

      final testData = List<List<double>>.generate(
        60,
        (i) => List<double>.generate(25, (j) => 0.5),
      );

      final priceDataMap = {
        'btc': testData,
        'eth': testData,
        'bnb': testData,
        'sol': testData,
        'trump': testData,
        'wlfi': testData,
      };

      final predictions = await mlService.getAllPredictions(
        priceDataMap: priceDataMap,
        timeframe: '5m',
      );

      expect(predictions.length, equals(6));

      print('\n📊 All Coins Predictions (5m):');
      predictions.forEach((coin, pred) {
        print('   $coin: ${pred.action} (${(pred.confidence * 100).toStringAsFixed(1)}%)');
      });
    });
  });
}
