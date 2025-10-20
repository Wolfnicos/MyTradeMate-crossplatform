# Phase 3: Optimized General Models - Implementation Summary

## Status: ✅ Foundation Complete (Partial Implementation)

**Completion Date**: 2025-10-20

---

## What Was Implemented

### 1. **Volume-Based Analysis Infrastructure** ✅

Added to `lib/services/binance_service.dart:410-478`:

#### `get24hVolume(String symbol)`
- Fetches 24h trading volume in quote currency (EUR)
- Uses Binance API endpoint: `/api/v3/ticker/24hr`
- Returns volume as `double`
- Error handling with debug logging

#### `getVolumePercentile(String targetSymbol, {List<String>? comparisonSymbols})`
- Calculates volume percentile for a target symbol
- Compares against 11 major EUR pairs (BTC, ETH, XRP, ADA, DOGE, MATIC, DOT, LINK, UNI, TRUMP, WLFI)
- Returns percentile (0.0 to 1.0)
- Uses parallel API calls with `Future.wait()` for performance
- Example: 0.75 means symbol has higher volume than 75% of comparison set

**Usage**:
```dart
// Get volume for BTCEUR
final volume = await BinanceService().get24hVolume('BTCEUR');

// Get volume percentile
final percentile = await BinanceService().getVolumePercentile('TRUMPEUR');
// percentile = 0.25 → Low volume (bottom 25%)
// percentile = 0.75 → High volume (top 25%)
```

### 2. **Model Recency Tracking** ✅

Modified `assets/models/model_registry.json:21-25`:
- Added `trained_date` field to all 5 models
- Format: "YYYY-MM-DD" (e.g., "2025-10-19")
- Allows tracking model freshness

**Example**:
```json
{
  "id": "general_5m",
  "trained_date": "2025-10-19",
  "acc_val": 0.6138,
  ...
}
```

---

## Phase 3 Goals (From Roadmap)

### ✅ Implemented:
1. **Volume API Integration**: `get24hVolume()` and `getVolumePercentile()`
2. **Recency Tracking**: `trained_date` field in model registry

### ⏳ Not Yet Implemented:
1. **Volume-Based Confidence Boost**: +5% for general models on high-volume symbols
2. **Model Recency Factor**: +3% for models < 30 days old, -1%/month for older
3. **Improved Fallback Logic**: 60% newest / 30% second / 10% oldest weighting

---

## Why Volume Boost Is Not Fully Integrated

The volume percentile calculation is **asynchronous** (requires API calls), but the current weight calculation in `ensemble_weights_v2.dart:calculateTimeframeWeight()` is **synchronous**.

### Challenge:
```dart
// Current synchronous signature
static double calculateTimeframeWeight({
  required String requestedTf,
  required String modelTf,
  required String coin,
  required double atr,
  required String modelKey,
  bool isGeneral = false,
}) {
  // Cannot call await getVolumePercentile() here!
}
```

### Solution Options:

**Option A**: Make `calculateTimeframeWeight()` async (requires refactoring callers)
**Option B**: Pre-fetch volume percentile at higher level (recommended)
**Option C**: Cache volume percentiles in-memory with periodic refresh

---

## Recommended Next Steps for Full Phase 3

### Step 1: Pre-Fetch Volume Percentile (Recommended)

Modify `lib/ml/crypto_ml_service.dart` or `ensemble_example.dart` to fetch volume before calling weight calculation:

```dart
// In getPrediction() or similar
final volumePercentile = await _binanceService.getVolumePercentile(symbol);

// Pass to weight calculation
final weight = EnsembleWeightsV2.calculateTimeframeWeight(
  requestedTf: timeframe,
  modelTf: model.timeframe,
  coin: coin,
  atr: atr,
  modelKey: model.id,
  isGeneral: model.isGeneral,
  volumePercentile: volumePercentile, // NEW parameter
);
```

### Step 2: Add Volume Boost Logic

In `ensemble_weights_v2.dart:calculateTimeframeWeight()`:

```dart
// STEP 3.5: VOLUME BOOST (Phase 3)
// General models get +5% confidence boost for high-volume coins
if (isGeneral && volumePercentile > 0.5) {
  final volumeBoost = 1.05; // 5% boost for high volume
  weight *= volumeBoost;
  print('   📊 Volume boost: ${((volumeBoost - 1) * 100).toStringAsFixed(0)}% '
      '(percentile: ${(volumePercentile * 100).toStringAsFixed(0)}%)');
}
```

### Step 3: Implement Recency Factor

Add recency boost calculation:

```dart
// STEP 3.6: RECENCY FACTOR (Phase 3)
final trainedDate = modelMetadata['trained_date'] as String?;
if (trainedDate != null) {
  final trained = DateTime.parse(trainedDate);
  final daysSinceTrained = DateTime.now().difference(trained).inDays;

  double recencyBoost = 1.0;
  if (daysSinceTrained < 30) {
    recencyBoost = 1.03; // +3% for models < 30 days old
  } else {
    final monthsSinceTrained = daysSinceTrained / 30;
    recencyBoost = 1.0 - (0.01 * monthsSinceTrained); // -1% per month
    recencyBoost = recencyBoost.clamp(0.90, 1.0); // Max -10% penalty
  }

  weight *= recencyBoost;
  print('   🕰️  Recency factor: ${((recencyBoost - 1) * 100).toStringAsFixed(0)}% '
      '($daysSinceTrained days old)');
}
```

### Step 4: Improve Fallback Logic

In `crypto_ml_service.dart:getPrediction()`:

```dart
// When no coin-specific model exists, use weighted fallback
if (generalModels.isEmpty) {
  return fallbackPrediction();
}

// Sort general models by trained_date (newest first)
generalModels.sort((a, b) {
  final dateA = DateTime.parse(a.trainedDate);
  final dateB = DateTime.parse(b.trainedDate);
  return dateB.compareTo(dateA); // Descending
});

// Apply fallback weighting: 60% newest, 30% second, 10% oldest
final weights = [0.60, 0.30, 0.10];
for (int i = 0; i < generalModels.length && i < 3; i++) {
  final model = generalModels[i];
  final weight = weights[i];
  // ... use weight in ensemble calculation
}
```

---

## Integration Example

Here's how to use Phase 3 features in production:

```dart
import 'package:mytrademate/services/binance_service.dart';
import 'package:mytrademate/ml/crypto_ml_service.dart';

Future<Map<String, dynamic>> getPredictionWithPhase3(String coin, String timeframe) async {
  final binanceService = BinanceService();
  final mlService = CryptoMLService();

  // STEP 1: Fetch volume percentile (Phase 3)
  final symbol = '${coin}EUR';
  final volumePercentile = await binanceService.getVolumePercentile(symbol);

  print('📊 Volume analysis for $coin:');
  print('   Percentile: ${(volumePercentile * 100).toStringAsFixed(1)}%');
  print('   ${volumePercentile > 0.5 ? "HIGH volume (boost eligible)" : "LOW volume"}');

  // STEP 2: Get prediction with volume context
  final prediction = await mlService.getPrediction(
    coin: coin,
    timeframe: timeframe,
    volumePercentile: volumePercentile, // Pass to ensemble logic
  );

  // STEP 3: Add Phase 3 metadata to response
  return {
    ...prediction.toJson(),
    'volume_percentile': volumePercentile,
    'volume_boost_applied': volumePercentile > 0.5,
    'phase': 'Phase 3 (Volume-Optimized General Models)',
  };
}
```

---

## Performance Considerations

### Volume API Calls
- **Cost**: 1 API call per symbol (11 total for percentile calculation)
- **Latency**: ~200-500ms for parallel batch request
- **Rate Limit**: Binance public API has 1200 requests/minute limit

### Recommended Caching Strategy:
```dart
class VolumeCache {
  static final Map<String, (double percentile, DateTime timestamp)> _cache = {};
  static const Duration cacheDuration = Duration(minutes: 5);

  static Future<double> getVolumePercentile(String symbol) async {
    final cached = _cache[symbol];
    if (cached != null && DateTime.now().difference(cached.$2) < cacheDuration) {
      return cached.$1; // Return cached value
    }

    // Fetch fresh data
    final percentile = await BinanceService().getVolumePercentile(symbol);
    _cache[symbol] = (percentile, DateTime.now());
    return percentile;
  }
}
```

---

## Testing

### Manual Testing:
```bash
# Test volume API
flutter test test/binance_volume_test.dart

# Test volume percentile calculation
dart run lib/ml/test_volume_percentile.dart
```

### Expected Results:
- **High Volume**: BTC, ETH should return percentile > 0.7
- **Medium Volume**: ADA, DOGE should return percentile ~ 0.4-0.6
- **Low Volume**: TRUMP, WLFI should return percentile < 0.3

---

## Files Modified

### Created:
- None (Phase 3 is foundation-only)

### Modified:
1. **lib/services/binance_service.dart**: Added `get24hVolume()` and `getVolumePercentile()`
2. **assets/models/model_registry.json**: Added `trained_date` field to all models

---

## Estimated Time to Complete Full Phase 3

- **Option A** (async refactor): 4-5 hours
- **Option B** (pre-fetch at higher level): 2-3 hours ✅ Recommended
- **Option C** (caching layer): 3-4 hours

**Recommendation**: Use Option B for simplest integration.

---

## Summary

✅ **Phase 3 Foundation Complete**:
- Volume API infrastructure is ready
- Model recency tracking is in place
- Ready for integration into ensemble strategy

⏳ **Next Steps**:
- Integrate volume boost into `crypto_ml_service.dart`
- Implement recency factor in weight calculation
- Add improved fallback logic for general models

**Total Time Spent**: ~2 hours
**Remaining Work**: ~2-3 hours (Option B)

---

**Created**: 2025-10-20
**Author**: Claude Code (Phase 3 Foundation)
**Status**: Foundation Complete, Integration Pending
