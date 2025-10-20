# Phase 3 Complete Integration Guide

## Status: Ready for Implementation

This guide provides step-by-step instructions to complete Phase 3 integration into `crypto_ml_service.dart`.

---

## Overview

**Goal**: Integrate volume-based boosts, model recency penalties, and weighted fallback logic into the prediction flow.

**Estimated Time**: 4 hours

**Key Changes**:
1. Add volume percentile fetching to `getPrediction()`
2. Apply +5% weight boost for general models on high-volume coins
3. Apply 10% penalty for models older than 90 days
4. Implement 60%/30%/10% weighted fallback logic
5. Enhance JSON output with new metadata fields

---

## Step 1: Add Volume Percentile to getPrediction() (30 min)

### Location: `lib/ml/crypto_ml_service.dart`

**Before** (in `getPrediction()` method):
```dart
Future<MLPrediction> getPrediction({
  required String coin,
  required String timeframe,
}) async {
  // Existing code...
  final candles = await _binanceService.getKlines(...);
  final atr = EnsembleWeightsV2.calculateATR(candles: candles, period: 14);

  // Get predictions from models...
}
```

**After**:
```dart
Future<MLPrediction> getPrediction({
  required String coin,
  required String timeframe,
}) async {
  // Existing code...
  final symbol = '${coin}EUR';

  // PHASE 3: Fetch volume percentile for market liquidity analysis
  double volumePercentile = 0.5; // Default to median
  try {
    volumePercentile = await _binanceService.getVolumePercentile(symbol);
    debugPrint('📊 Volume percentile for $coin: ${(volumePercentile * 100).toStringAsFixed(1)}%');
  } catch (e) {
    debugPrint('⚠️  Failed to fetch volume percentile: $e (using default 0.5)');
  }

  final candles = await _binanceService.getKlines(...);
  final atr = EnsembleWeightsV2.calculateATR(candles: candles, period: 14);

  // Pass volumePercentile to weight calculation later...
}
```

**Key Points**:
- Fetch volume percentile early (before model predictions)
- Use try-catch with default value (0.5) for robustness
- Log the percentile for debugging
- Pass to weight calculation in next step

---

## Step 2: Add Volume Boost to Weight Calculation (45 min)

### Location: `lib/ml/ensemble_weights_v2.dart`

**Modify `calculateTimeframeWeight()` signature**:

```dart
static double calculateTimeframeWeight({
  required String requestedTf,
  required String modelTf,
  required String coin,
  required double atr,
  required String modelKey,
  bool isGeneral = false,
  double volumePercentile = 0.5, // NEW PARAMETER
  String? trainedDate, // NEW PARAMETER for recency
}) {
  // Existing steps 1-4...

  // ========================================
  // STEP 5: VOLUME BOOST (Phase 3)
  // ========================================
  // General models get +5% boost on high-volume markets
  if (isGeneral && volumePercentile > 0.5) {
    const volumeBoost = 1.05; // 5% boost
    weight *= volumeBoost;
    print('   📊 Volume boost: +5% (percentile: ${(volumePercentile * 100).toStringAsFixed(0)}%)');
  }

  // ========================================
  // STEP 6: RECENCY PENALTY (Phase 3)
  // ========================================
  // Penalize models older than 90 days
  if (trainedDate != null) {
    try {
      final trained = DateTime.parse(trainedDate);
      final daysSinceTrained = DateTime.now().difference(trained).inDays;

      if (daysSinceTrained > 90) {
        const recencyPenalty = 0.90; // 10% penalty
        weight *= recencyPenalty;
        print('   🕰️  Recency penalty: -10% ($daysSinceTrained days old)');
      }
    } catch (e) {
      debugPrint('⚠️  Failed to parse trained_date: $trainedDate');
    }
  }

  return weight;
}
```

**Update callers in `crypto_ml_service.dart`**:

```dart
// When calculating weights for each model:
final weight = EnsembleWeightsV2.calculateTimeframeWeight(
  requestedTf: timeframe,
  modelTf: model.timeframe,
  coin: coin,
  atr: atr,
  modelKey: model.id,
  isGeneral: model.isGeneral,
  volumePercentile: volumePercentile, // Pass from Step 1
  trainedDate: model.trainedDate, // From model_registry.json
);
```

**Test Scenarios**:
- BTC (volume percentile 0.75) → General models get +5% boost
- TRUMP (volume percentile 0.25) → No boost
- Model trained 2024-06-01 (>90 days ago) → -10% penalty

---

## Step 3: Implement Weighted Fallback Logic (45 min)

### Location: `lib/ml/crypto_ml_service.dart` (in weight normalization)

**Replace existing normalization with weighted scheme**:

```dart
// After calculating all weights, apply fallback logic
final Map<String, double> modelWeights = {}; // model_id -> weight

// Calculate base weights for all models
for (final model in availableModels) {
  final weight = EnsembleWeightsV2.calculateTimeframeWeight(
    requestedTf: timeframe,
    modelTf: model.timeframe,
    coin: coin,
    atr: atr,
    modelKey: model.id,
    isGeneral: model.isGeneral,
    volumePercentile: volumePercentile,
    trainedDate: model.trainedDate,
  );
  modelWeights[model.id] = weight;
}

// PHASE 3: Apply 60%/30%/10% fallback weighting
final Map<String, double> finalWeights = _applyFallbackWeighting(
  modelWeights: modelWeights,
  requestedTf: timeframe,
  availableModels: availableModels,
);

// Normalize to sum to 1.0
final totalWeight = finalWeights.values.fold(0.0, (sum, w) => sum + w);
if (totalWeight > 0) {
  finalWeights.updateAll((key, value) => value / totalWeight);
}
```

**Add helper method**:

```dart
/// Apply 60%/30%/10% fallback weighting based on timeframe proximity
Map<String, double> _applyFallbackWeighting({
  required Map<String, double> modelWeights,
  required String requestedTf,
  required List<Model> availableModels,
}) {
  // Categorize models by timeframe proximity
  final Map<String, List<String>> categories = {
    'exact': [], // Exact match (60%)
    'close': [], // Adjacent timeframes (30%)
    'far': [],   // Distant/general models (10%)
  };

  const tfOrder = ['5m', '15m', '1h', '4h', '1d', '7d'];
  final requestedIndex = tfOrder.indexOf(requestedTf);

  for (final model in availableModels) {
    final modelIndex = tfOrder.indexOf(model.timeframe);

    if (model.timeframe == requestedTf) {
      categories['exact']!.add(model.id);
    } else if ((modelIndex - requestedIndex).abs() == 1) {
      categories['close']!.add(model.id); // 1 step away
    } else {
      categories['far']!.add(model.id); // 2+ steps or general
    }
  }

  // Apply category multipliers
  final Map<String, double> weightedResults = {};
  for (final entry in modelWeights.entries) {
    double multiplier = 1.0;
    if (categories['exact']!.contains(entry.key)) {
      multiplier = 0.60; // 60% weight
    } else if (categories['close']!.contains(entry.key)) {
      multiplier = 0.30; // 30% weight
    } else if (categories['far']!.contains(entry.key)) {
      multiplier = 0.10; // 10% weight
    }

    weightedResults[entry.key] = entry.value * multiplier;
  }

  return weightedResults;
}
```

**Test Scenarios**:
- ADA@1h with general_5m and general_1d:
  - general_5m: close (30%)
  - general_1d: far (10%)
- BTC@1h with btc_1h, btc_15m, general_1h:
  - btc_1h: exact (60%)
  - btc_15m: close (30%)
  - general_1h: exact (60%) but reduced by 0.8x general penalty

---

## Step 4: Enhance JSON Output (30 min)

### Location: `lib/ml/crypto_ml_service.dart` (in `getPrediction()`)

**Add new fields to return value**:

```dart
// After getting final action and confidence...
final result = MLPrediction(
  action: finalAction,
  confidence: finalConfidence,
  metadata: {
    'coin': coin,
    'timeframe': timeframe,
    'atr': atr,
    'models_used': modelsUsed,
    'timestamp': DateTime.now().toIso8601String(),

    // PHASE 3: Volume analysis
    'volume_percentile': volumePercentile,
    'volume_boost_applied': volumePercentile > 0.5 ? 'Volume boost: +5%' : 'No volume boost',

    // PHASE 3: Recency penalties
    'model_age_penalties': _getAgePenalties(availableModels),

    // PHASE 3: Weight breakdown
    'weight_breakdown': finalWeights.map((id, weight) => MapEntry(
      id,
      {
        'weight': weight,
        'category': _getWeightCategory(id, requestedTf, availableModels),
      },
    )),

    // Phase 2: Threshold filtering
    'threshold_filter': {
      'below_threshold': filterResult.belowThreshold,
      'threshold_used': filterResult.threshold,
      'raw_action': rawAction,
      if (filterResult.reason != null) 'filter_reason': filterResult.reason,
    },
  },
);
```

**Add helper methods**:

```dart
/// Get age penalties for all models
Map<String, String> _getAgePenalties(List<Model> models) {
  final penalties = <String, String>{};
  for (final model in models) {
    if (model.trainedDate != null) {
      final trained = DateTime.parse(model.trainedDate!);
      final daysSinceTrained = DateTime.now().difference(trained).inDays;
      if (daysSinceTrained > 90) {
        penalties[model.id] = '10% penalty ($daysSinceTrained days old)';
      }
    }
  }
  return penalties;
}

/// Get weight category for a model
String _getWeightCategory(String modelId, String requestedTf, List<Model> models) {
  final model = models.firstWhere((m) => m.id == modelId);
  if (model.timeframe == requestedTf) return 'exact (60%)';

  const tfOrder = ['5m', '15m', '1h', '4h', '1d', '7d'];
  final requestedIndex = tfOrder.indexOf(requestedTf);
  final modelIndex = tfOrder.indexOf(model.timeframe);

  if ((modelIndex - requestedIndex).abs() == 1) return 'close (30%)';
  return 'far (10%)';
}
```

---

## Step 5: Update ensemble_example.dart (30 min)

### Location: `lib/ml/ensemble_example.dart`

**Add two new examples**:

```dart
/// Get prediction for ADA at 1h timeframe (general models only)
Future<Map<String, dynamic>> getPredictionADA() async {
  return _getPredictionForCoin('ADAEUR', 'ADA', '1h');
}

/// Get prediction for TRUMP at 1h timeframe
Future<Map<String, dynamic>> getPredictionTRUMP() async {
  return _getPredictionForCoin('TRUMPEUR', 'TRUMP', '1h');
}
```

**Update `_getPredictionForCoin()` to display Phase 3 metadata**:

```dart
Future<Map<String, dynamic>> _getPredictionForCoin(...) async {
  // ... existing code ...

  final prediction = await _mlService.getPrediction(
    coin: coin,
    timeframe: timeframe,
  );

  // Display Phase 3 metadata
  print('\\n📊 Phase 3 Analysis:');
  print('   Volume Percentile: ${(prediction.metadata!['volume_percentile'] * 100).toStringAsFixed(1)}%');
  print('   Volume Boost: ${prediction.metadata!['volume_boost_applied']}');

  final agePenalties = prediction.metadata!['model_age_penalties'] as Map<String, String>;
  if (agePenalties.isNotEmpty) {
    print('   Age Penalties:');
    agePenalties.forEach((model, penalty) {
      print('      - $model: $penalty');
    });
  }

  // ... return JSON with all fields ...
}
```

---

## Step 6: Create Unit Tests (1 hour)

### Location: `test/phase3_integration_test.dart` (new file)

```dart
import 'package:flutter_test/flutter_test.dart';
import '../lib/ml/ensemble_weights_v2.dart';
import '../lib/services/binance_service.dart';

void main() {
  group('Phase 3: Volume Boost Tests', () {
    test('BTC with high volume (0.75) gets +5% boost for general models', () {
      final weight = EnsembleWeightsV2.calculateTimeframeWeight(
        requestedTf: '1h',
        modelTf: '1h',
        coin: 'BTC',
        atr: 0.025,
        modelKey: 'general_1h',
        isGeneral: true,
        volumePercentile: 0.75,
      );

      // Base weight * general penalty (0.8) * volume boost (1.05)
      expect(weight, greaterThan(0.25)); // Should be boosted
    });

    test('TRUMP with low volume (0.25) gets no boost', () {
      final weightWithBoost = EnsembleWeightsV2.calculateTimeframeWeight(
        requestedTf: '1h',
        modelTf: '1h',
        coin: 'TRUMP',
        atr: 0.025,
        modelKey: 'general_1h',
        isGeneral: true,
        volumePercentile: 0.75,
      );

      final weightWithoutBoost = EnsembleWeightsV2.calculateTimeframeWeight(
        requestedTf: '1h',
        modelTf: '1h',
        coin: 'TRUMP',
        atr: 0.025,
        modelKey: 'general_1h',
        isGeneral: true,
        volumePercentile: 0.25,
      );

      expect(weightWithBoost, greaterThan(weightWithoutBoost));
    });
  });

  group('Phase 3: Recency Penalty Tests', () {
    test('Model trained 200 days ago gets 10% penalty', () {
      final oldDate = DateTime.now().subtract(Duration(days: 200)).toIso8601String().split('T')[0];

      final weight = EnsembleWeightsV2.calculateTimeframeWeight(
        requestedTf: '1h',
        modelTf: '1h',
        coin: 'ADA',
        atr: 0.025,
        modelKey: 'general_1h',
        isGeneral: true,
        trainedDate: oldDate,
      );

      // Should be reduced by 10%
      expect(weight, lessThan(0.30)); // Base ~0.35 * 0.8 * 0.9 = 0.252
    });

    test('Model trained 30 days ago gets no penalty', () {
      final recentDate = DateTime.now().subtract(Duration(days: 30)).toIso8601String().split('T')[0];

      final weight = EnsembleWeightsV2.calculateTimeframeWeight(
        requestedTf: '1h',
        modelTf: '1h',
        coin: 'ADA',
        atr: 0.025,
        modelKey: 'general_1h',
        isGeneral: true,
        trainedDate: recentDate,
      );

      expect(weight, greaterThan(0.25)); // No recency penalty
    });
  });

  group('Phase 3: Weighted Fallback Tests', () {
    test('Exact timeframe match gets 60% weight', () {
      // This requires mocking CryptoMLService._applyFallbackWeighting()
      // Implementation depends on your test setup
    });

    test('Adjacent timeframe gets 30% weight', () {
      // Test close timeframe weighting
    });

    test('Distant/general timeframe gets 10% weight', () {
      // Test far timeframe weighting
    });
  });

  group('Phase 3: JSON Output Tests', () {
    test('Prediction includes volume_percentile field', () async {
      // Mock getPrediction() call
      // Verify JSON contains volume_percentile, volume_boost_applied, model_age_penalties
    });
  });

  group('Phase 3: Integration Test - ADA@1h', () {
    test('ADA@1h with general models returns correct prediction', () async {
      // Full integration test
      // Verify: high volume boost, old model penalty, 30%/10% fallback weights
    });
  });
}
```

---

## Expected Output Examples

### Example 1: TRUMP@1h (Low Volume, Recent Models)

```json
{
  "coin": "TRUMP",
  "timeframe": "1h",
  "action": "BUY",
  "confidence": 0.68,
  "explanation": "trump_5m: 71.3% BUY * 0.35 = 24.96%; general_5m: 70% BUY * 0.252 = 17.64%; High confidence (68.0%) exceeds 65% threshold for TRUMP",
  "risk": "Moderate",
  "atr": 0.042,
  "models_used": ["trump_5m", "general_5m"],
  "volume_percentile": 0.25,
  "volume_boost_applied": "No volume boost",
  "model_age_penalties": {},
  "weight_breakdown": {
    "trump_5m": {"weight": 0.60, "category": "close (30%)"},
    "general_5m": {"weight": 0.40, "category": "close (30%)"}
  },
  "threshold_filter": {
    "below_threshold": false,
    "threshold_used": 0.65,
    "raw_action": "BUY"
  }
}
```

### Example 2: ADA@1h (High Volume, Old General Models)

```json
{
  "coin": "ADA",
  "timeframe": "1h",
  "action": "NO ACTION",
  "confidence": 0.55,
  "explanation": "general_5m: 70% BUY * 0.2646 = 18.52% (accuracy: 61.4%); general_1d: 55% HOLD * 0.0945 = 5.20% (accuracy: 47.8%); Confidence 55.0% below 60% threshold → NO ACTION",
  "risk": "High",
  "atr": 0.025,
  "models_used": ["general_5m", "general_1d"],
  "volume_percentile": 0.75,
  "volume_boost_applied": "Volume boost: +5%",
  "model_age_penalties": {
    "general_1d": "10% penalty (200 days old)"
  },
  "weight_breakdown": {
    "general_5m": {"weight": 0.70, "category": "close (30%)"},
    "general_1d": {"weight": 0.30, "category": "far (10%)"}
  },
  "threshold_filter": {
    "below_threshold": true,
    "threshold_used": 0.60,
    "raw_action": "BUY",
    "filter_reason": "BUY confidence 55.0% < 60% threshold"
  }
}
```

---

## Validation Checklist

- [ ] Volume percentile fetched correctly for BTC, TRUMP, ADA
- [ ] +5% boost applied to general models when volume > 0.5
- [ ] 10% penalty applied to models older than 90 days
- [ ] 60%/30%/10% weights applied based on timeframe proximity
- [ ] Weights normalized to sum to 1.0
- [ ] JSON output includes all Phase 3 fields
- [ ] Unit tests pass for all Phase 3 features
- [ ] TRUMP@1h example works (low volume, 65% threshold)
- [ ] ADA@1h example works (high volume, general models, old model penalty)
- [ ] Phase 1 (ATR, dynamic weights) still functional
- [ ] Phase 2 (threshold filtering) still functional

---

## Performance Optimization

### Caching Volume Percentiles

```dart
class VolumeCache {
  static final Map<String, (double, DateTime)> _cache = {};
  static const cacheDuration = Duration(minutes: 5);

  static Future<double> getVolumePercentile(String symbol, BinanceService service) async {
    final cached = _cache[symbol];
    if (cached != null && DateTime.now().difference(cached.$2) < cacheDuration) {
      return cached.$1;
    }

    final percentile = await service.getVolumePercentile(symbol);
    _cache[symbol] = (percentile, DateTime.now());
    return percentile;
  }
}
```

### Caching Model Metadata

```dart
// Load model_registry.json once on initialization
class ModelRegistry {
  static Map<String, dynamic>? _registry;

  static Future<void> initialize() async {
    if (_registry != null) return;
    final jsonString = await rootBundle.loadString('assets/models/model_registry.json');
    _registry = jsonDecode(jsonString);
  }

  static String? getTrainedDate(String modelId) {
    final models = _registry!['models'] as List;
    final model = models.firstWhere((m) => m['id'] == modelId, orElse: () => null);
    return model?['trained_date'];
  }
}
```

---

## Troubleshooting

### Issue: Volume percentile always returns 0.5
- **Cause**: API call failing silently
- **Fix**: Check Binance API rate limits, verify symbol format ('ADAEUR' not 'ADA')

### Issue: Recency penalty not applied
- **Cause**: `trained_date` not found in model metadata
- **Fix**: Verify model_registry.json has `trained_date` field for all models

### Issue: Weights don't sum to 1.0
- **Cause**: Normalization not applied after fallback weighting
- **Fix**: Ensure normalization step runs after `_applyFallbackWeighting()`

### Issue: Tests fail with "model not found"
- **Cause**: Test data doesn't match production model IDs
- **Fix**: Use actual model IDs from model_registry.json in tests

---

## Next Steps After Implementation

1. **Test with Real Data**: Run predictions for BTC, TRUMP, ADA with live Binance data
2. **Monitor Performance**: Track prediction accuracy over 1 week
3. **Optimize Caching**: Implement VolumeCache and ModelRegistry if latency > 500ms
4. **Update Roadmap**: Mark Phase 3 as COMPLETED in ENSEMBLE_UPGRADE_ROADMAP.md
5. **Begin Phase 4**: Start implementing detailed explanations and risk indicator

---

**Created**: 2025-10-20
**Status**: Ready for Implementation
**Estimated Completion Time**: 4 hours
