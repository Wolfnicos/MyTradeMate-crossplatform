import 'package:flutter_test/flutter_test.dart';
import '../lib/ml/ensemble_weights_v2.dart';

void main() {
  group('EnsembleWeightsV2 - ATR Calculation Tests', () {
    test('calculateATR with sufficient candles returns correct value', () {
      // Create mock OHLCV data: [timestamp, open, high, low, close, volume]
      final candles = <List<double>>[
        [1000000, 100.0, 105.0, 99.0, 103.0, 1000.0], // Candle 0
        [1000001, 103.0, 107.0, 102.0, 106.0, 1100.0], // Candle 1
        [1000002, 106.0, 110.0, 105.0, 108.0, 1200.0], // Candle 2
        [1000003, 108.0, 112.0, 107.0, 110.0, 1300.0], // Candle 3
        [1000004, 110.0, 115.0, 109.0, 113.0, 1400.0], // Candle 4
        [1000005, 113.0, 118.0, 112.0, 116.0, 1500.0], // Candle 5
        [1000006, 116.0, 121.0, 115.0, 119.0, 1600.0], // Candle 6
        [1000007, 119.0, 124.0, 118.0, 122.0, 1700.0], // Candle 7
        [1000008, 122.0, 127.0, 121.0, 125.0, 1800.0], // Candle 8
        [1000009, 125.0, 130.0, 124.0, 128.0, 1900.0], // Candle 9
        [1000010, 128.0, 133.0, 127.0, 131.0, 2000.0], // Candle 10
        [1000011, 131.0, 136.0, 130.0, 134.0, 2100.0], // Candle 11
        [1000012, 134.0, 139.0, 133.0, 137.0, 2200.0], // Candle 12
        [1000013, 137.0, 142.0, 136.0, 140.0, 2300.0], // Candle 13
        [1000014, 140.0, 145.0, 139.0, 143.0, 2400.0], // Candle 14
      ];

      final atr = EnsembleWeightsV2.calculateATR(candles: candles, period: 14);

      // ATR should be > 0 and < 1 (reasonable percentage)
      expect(atr, greaterThan(0.0));
      expect(atr, lessThan(1.0));

      // For this uptrend data with consistent 5-point ranges, ATR should be ~3-4%
      expect(atr, greaterThan(0.02)); // > 2%
      expect(atr, lessThan(0.06)); // < 6%
    });

    test('calculateATR with insufficient candles returns default value', () {
      final candles = <List<double>>[
        [1000000, 100.0, 105.0, 99.0, 103.0, 1000.0],
        [1000001, 103.0, 107.0, 102.0, 106.0, 1100.0],
      ];

      final atr = EnsembleWeightsV2.calculateATR(candles: candles, period: 14);

      // Should return default 2% volatility
      expect(atr, equals(0.02));
    });

    test('calculateATR handles high volatility correctly', () {
      // Create high volatility data with large price swings
      final candles = <List<double>>[
        [1000000, 100.0, 120.0, 90.0, 95.0, 1000.0],
        [1000001, 95.0, 110.0, 80.0, 105.0, 1100.0],
        [1000002, 105.0, 130.0, 100.0, 110.0, 1200.0],
        [1000003, 110.0, 135.0, 105.0, 125.0, 1300.0],
        [1000004, 125.0, 150.0, 120.0, 130.0, 1400.0],
        [1000005, 130.0, 155.0, 125.0, 145.0, 1500.0],
        [1000006, 145.0, 170.0, 140.0, 150.0, 1600.0],
        [1000007, 150.0, 175.0, 145.0, 165.0, 1700.0],
        [1000008, 165.0, 190.0, 160.0, 170.0, 1800.0],
        [1000009, 170.0, 195.0, 165.0, 185.0, 1900.0],
        [1000010, 185.0, 210.0, 180.0, 190.0, 2000.0],
        [1000011, 190.0, 215.0, 185.0, 205.0, 2100.0],
        [1000012, 205.0, 230.0, 200.0, 210.0, 2200.0],
        [1000013, 210.0, 235.0, 205.0, 225.0, 2300.0],
        [1000014, 225.0, 250.0, 220.0, 230.0, 2400.0],
      ];

      final atr = EnsembleWeightsV2.calculateATR(candles: candles, period: 14);

      // High volatility should produce ATR > 5%
      expect(atr, greaterThan(0.05));
    });

    test('calculateATR handles low volatility correctly', () {
      // Create low volatility data with small price swings
      final candles = <List<double>>[
        [1000000, 100.0, 100.5, 99.8, 100.2, 1000.0],
        [1000001, 100.2, 100.7, 99.9, 100.4, 1100.0],
        [1000002, 100.4, 100.9, 100.1, 100.6, 1200.0],
        [1000003, 100.6, 101.1, 100.3, 100.8, 1300.0],
        [1000004, 100.8, 101.3, 100.5, 101.0, 1400.0],
        [1000005, 101.0, 101.5, 100.7, 101.2, 1500.0],
        [1000006, 101.2, 101.7, 100.9, 101.4, 1600.0],
        [1000007, 101.4, 101.9, 101.1, 101.6, 1700.0],
        [1000008, 101.6, 102.1, 101.3, 101.8, 1800.0],
        [1000009, 101.8, 102.3, 101.5, 102.0, 1900.0],
        [1000010, 102.0, 102.5, 101.7, 102.2, 2000.0],
        [1000011, 102.2, 102.7, 101.9, 102.4, 2100.0],
        [1000012, 102.4, 102.9, 102.1, 102.6, 2200.0],
        [1000013, 102.6, 103.1, 102.3, 102.8, 2300.0],
        [1000014, 102.8, 103.3, 102.5, 103.0, 2400.0],
      ];

      final atr = EnsembleWeightsV2.calculateATR(candles: candles, period: 14);

      // Low volatility should produce ATR < 1%
      expect(atr, lessThan(0.01));
    });
  });

  group('EnsembleWeightsV2 - Timeframe Weight Calculation Tests', () {
    test('calculateTimeframeWeight exact match returns highest weight', () {
      final weight = EnsembleWeightsV2.calculateTimeframeWeight(
        requestedTf: '1h',
        modelTf: '1h',
        coin: 'BTC',
        atr: 0.02,
        modelKey: 'btc_1h',
        isGeneral: false,
      );

      // Exact match should get 0.35
      expect(weight, equals(0.35));
    });

    test('calculateTimeframeWeight applies volatility boost for short TFs', () {
      // High volatility (ATR > 2.5%)
      final weightHighVol = EnsembleWeightsV2.calculateTimeframeWeight(
        requestedTf: '1h',
        modelTf: '5m',
        coin: 'BTC',
        atr: 0.04, // 4% volatility
        modelKey: 'btc_5m',
        isGeneral: false,
      );

      // Low volatility (ATR < 2.5%)
      final weightLowVol = EnsembleWeightsV2.calculateTimeframeWeight(
        requestedTf: '1h',
        modelTf: '5m',
        coin: 'BTC',
        atr: 0.01, // 1% volatility
        modelKey: 'btc_5m',
        isGeneral: false,
      );

      // High volatility weight should be ~20% higher
      expect(weightHighVol, greaterThan(weightLowVol));
      expect(weightHighVol / weightLowVol, greaterThan(1.15)); // At least 15% boost
      expect(weightHighVol / weightLowVol, lessThan(1.25)); // At most 25% boost
    });

    test('calculateTimeframeWeight applies general model penalty', () {
      final weightSpecific = EnsembleWeightsV2.calculateTimeframeWeight(
        requestedTf: '1h',
        modelTf: '1h',
        coin: 'BTC',
        atr: 0.02,
        modelKey: 'btc_1h',
        isGeneral: false,
      );

      final weightGeneral = EnsembleWeightsV2.calculateTimeframeWeight(
        requestedTf: '1h',
        modelTf: '1h',
        coin: 'BTC',
        atr: 0.02,
        modelKey: 'general_1h',
        isGeneral: true,
      );

      // General model should have 0.8x penalty
      expect(weightGeneral, equals(weightSpecific * 0.8));
    });

    test('calculateTimeframeWeight decays for distant timeframes', () {
      final weight1h = EnsembleWeightsV2.calculateTimeframeWeight(
        requestedTf: '1h',
        modelTf: '1h',
        coin: 'BTC',
        atr: 0.02,
        modelKey: 'btc_1h',
        isGeneral: false,
      );

      final weight15m = EnsembleWeightsV2.calculateTimeframeWeight(
        requestedTf: '1h',
        modelTf: '15m',
        coin: 'BTC',
        atr: 0.02,
        modelKey: 'btc_15m',
        isGeneral: false,
      );

      final weight1d = EnsembleWeightsV2.calculateTimeframeWeight(
        requestedTf: '1h',
        modelTf: '1d',
        coin: 'BTC',
        atr: 0.02,
        modelKey: 'btc_1d',
        isGeneral: false,
      );

      // Weights should decay: 1h > 15m > 1d
      expect(weight1h, greaterThan(weight15m));
      expect(weight15m, greaterThan(weight1d));

      // All weights should be within valid range
      expect(weight1h, greaterThanOrEqualTo(0.05));
      expect(weight1h, lessThanOrEqualTo(0.35));
      expect(weight15m, greaterThanOrEqualTo(0.05));
      expect(weight15m, lessThanOrEqualTo(0.35));
      expect(weight1d, greaterThanOrEqualTo(0.05));
      expect(weight1d, lessThanOrEqualTo(0.35));
    });
  });

  group('EnsembleWeightsV2 - Performance Tracking Tests', () {
    setUp(() {
      // Clear performance cache before each test
      EnsembleWeightsV2.clearPerformanceCache();
    });

    test('trackPrediction stores prediction outcomes correctly', () {
      // Track 5 predictions: 3 correct, 2 incorrect
      EnsembleWeightsV2.trackPrediction('btc_1h', true);
      EnsembleWeightsV2.trackPrediction('btc_1h', true);
      EnsembleWeightsV2.trackPrediction('btc_1h', false);
      EnsembleWeightsV2.trackPrediction('btc_1h', true);
      EnsembleWeightsV2.trackPrediction('btc_1h', false);

      final accuracy = EnsembleWeightsV2.getRecentModelAccuracy('btc_1h');

      // Accuracy should be 3/5 = 0.6
      expect(accuracy, equals(0.6));
    });

    test('getRecentModelAccuracy returns 0.5 for unknown model', () {
      final accuracy = EnsembleWeightsV2.getRecentModelAccuracy('unknown_model');

      // Default accuracy should be 0.5 (50%)
      expect(accuracy, equals(0.5));
    });

    test('trackPrediction maintains sliding window of 50 predictions', () {
      // Track 60 predictions (all correct)
      for (int i = 0; i < 60; i++) {
        EnsembleWeightsV2.trackPrediction('btc_1h', true);
      }

      final stats = EnsembleWeightsV2.getPerformanceStats();
      final modelAccuracies = stats['model_accuracies'] as Map<String, dynamic>;

      // Should only keep last 50 predictions
      // Since all are correct, accuracy should still be 1.0
      expect(modelAccuracies['btc_1h'], equals(1.0));
    });

    test('getAverageAccuracy calculates correctly across multiple models', () {
      // Model 1: 70% accuracy
      for (int i = 0; i < 10; i++) {
        EnsembleWeightsV2.trackPrediction('model1', i < 7);
      }

      // Model 2: 50% accuracy
      for (int i = 0; i < 10; i++) {
        EnsembleWeightsV2.trackPrediction('model2', i < 5);
      }

      // Model 3: 80% accuracy
      for (int i = 0; i < 10; i++) {
        EnsembleWeightsV2.trackPrediction('model3', i < 8);
      }

      final avgAccuracy = EnsembleWeightsV2.getAverageAccuracy();

      // Average should be (0.7 + 0.5 + 0.8) / 3 = 0.6667
      expect(avgAccuracy, closeTo(0.6667, 0.01));
    });

    test('calculateTimeframeWeight applies performance boost', () {
      // Track good performance for model1 (80% accuracy)
      for (int i = 0; i < 10; i++) {
        EnsembleWeightsV2.trackPrediction('model1', i < 8);
      }

      // Track poor performance for model2 (30% accuracy)
      for (int i = 0; i < 10; i++) {
        EnsembleWeightsV2.trackPrediction('model2', i < 3);
      }

      final weight1 = EnsembleWeightsV2.calculateTimeframeWeight(
        requestedTf: '1h',
        modelTf: '1h',
        coin: 'BTC',
        atr: 0.02,
        modelKey: 'model1',
        isGeneral: false,
      );

      final weight2 = EnsembleWeightsV2.calculateTimeframeWeight(
        requestedTf: '1h',
        modelTf: '1h',
        coin: 'BTC',
        atr: 0.02,
        modelKey: 'model2',
        isGeneral: false,
      );

      // Model with better performance should have higher weight
      expect(weight1, greaterThan(weight2));
    });

    test('clearPerformanceCache resets all tracking', () {
      // Track some predictions
      EnsembleWeightsV2.trackPrediction('btc_1h', true);
      EnsembleWeightsV2.trackPrediction('btc_1h', true);

      // Clear cache
      EnsembleWeightsV2.clearPerformanceCache();

      final accuracy = EnsembleWeightsV2.getRecentModelAccuracy('btc_1h');

      // Should return default 0.5 after clearing
      expect(accuracy, equals(0.5));
    });
  });

  group('EnsembleWeightsV2 - Weight Normalization Tests', () {
    test('normalizeWeights ensures weights sum to 1.0', () {
      final weights = [0.35, 0.15, 0.10, 0.05];

      final normalized = EnsembleWeightsV2.normalizeWeights(weights);

      // Sum should be exactly 1.0
      final sum = normalized.reduce((a, b) => a + b);
      expect(sum, closeTo(1.0, 0.0001));
    });

    test('normalizeWeights handles zero weights', () {
      final weights = [0.0, 0.0, 0.0];

      final normalized = EnsembleWeightsV2.normalizeWeights(weights);

      // Should distribute equally (1/3 each)
      expect(normalized[0], closeTo(0.3333, 0.01));
      expect(normalized[1], closeTo(0.3333, 0.01));
      expect(normalized[2], closeTo(0.3333, 0.01));

      final sum = normalized.reduce((a, b) => a + b);
      expect(sum, closeTo(1.0, 0.0001));
    });

    test('normalizeWeights preserves relative proportions', () {
      final weights = [0.40, 0.20, 0.10];

      final normalized = EnsembleWeightsV2.normalizeWeights(weights);

      // Relative proportions should be 4:2:1
      expect(normalized[0] / normalized[1], closeTo(2.0, 0.01));
      expect(normalized[1] / normalized[2], closeTo(2.0, 0.01));
    });

    test('normalizeWeights handles single weight', () {
      final weights = [0.35];

      final normalized = EnsembleWeightsV2.normalizeWeights(weights);

      // Single weight should become 1.0
      expect(normalized[0], equals(1.0));
    });

    test('normalizeWeights handles very small weights', () {
      final weights = [0.0001, 0.0002, 0.0003];

      final normalized = EnsembleWeightsV2.normalizeWeights(weights);

      // Sum should still be 1.0
      final sum = normalized.reduce((a, b) => a + b);
      expect(sum, closeTo(1.0, 0.0001));

      // Relative proportions should be preserved (1:2:3)
      expect(normalized[1] / normalized[0], closeTo(2.0, 0.01));
      expect(normalized[2] / normalized[0], closeTo(3.0, 0.01));
    });
  });

  group('EnsembleWeightsV2 - Integration Tests', () {
    setUp(() {
      EnsembleWeightsV2.clearPerformanceCache();
    });

    test('Full workflow: Calculate weights for multi-model ensemble', () {
      // Simulate 3 models predicting BTC@1h
      final models = [
        {'key': 'btc_1h', 'tf': '1h', 'isGeneral': false},
        {'key': 'btc_15m', 'tf': '15m', 'isGeneral': false},
        {'key': 'general_1h', 'tf': '1h', 'isGeneral': true},
      ];

      // Track some performance history
      for (int i = 0; i < 10; i++) {
        EnsembleWeightsV2.trackPrediction('btc_1h', i < 7); // 70%
        EnsembleWeightsV2.trackPrediction('btc_15m', i < 6); // 60%
        EnsembleWeightsV2.trackPrediction('general_1h', i < 5); // 50%
      }

      // High volatility scenario
      final atr = 0.035; // 3.5% volatility

      // Calculate weights for each model
      final weights = models.map((model) {
        return EnsembleWeightsV2.calculateTimeframeWeight(
          requestedTf: '1h',
          modelTf: model['tf'] as String,
          coin: 'BTC',
          atr: atr,
          modelKey: model['key'] as String,
          isGeneral: model['isGeneral'] as bool,
        );
      }).toList();

      // Normalize weights
      final normalized = EnsembleWeightsV2.normalizeWeights(weights);

      // Assertions
      expect(normalized.length, equals(3));
      expect(normalized.reduce((a, b) => a + b), closeTo(1.0, 0.0001));

      // btc_1h should have highest weight (exact match + best performance)
      expect(normalized[0], greaterThan(normalized[1]));
      expect(normalized[0], greaterThan(normalized[2]));

      // general_1h should have lowest weight (general penalty)
      expect(normalized[2], lessThan(normalized[0]));
    });
  });
}
