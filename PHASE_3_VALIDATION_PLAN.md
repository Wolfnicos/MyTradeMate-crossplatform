# Phase 3: Validation Plan

**Status**: 🔬 Ready for Validation
**Branch**: `feature/phase3-optimized-general-models`
**Validation Period**: 1-2 weeks recommended
**Date Created**: 2025-10-20

---

## Overview

Phase 3 preview mode is **complete and stable**. Before proceeding with full integration (applying Phase 3 weights to predictions), we will validate the preview mode in production to ensure:

1. ✅ Volume percentiles are accurate
2. ✅ Recency calculations are correct
3. ✅ Phase 3 weights make sense
4. ✅ No edge cases or bugs
5. ✅ Existing predictions remain stable

---

## What to Deploy

**Branch**: `feature/phase3-optimized-general-models`

**Commits**:
1. `3bdf206` - Initial Phase 3 implementation (ensemble weights + preview integration)
2. `c450c40` - Fixed `_getTrainedDate()` to handle nulls gracefully

**Files Changed**:
- `lib/ml/ensemble_weights_v2.dart` (new file, 316 lines)
- `lib/ml/crypto_ml_service.dart` (+420 lines with Phase 3 preview)
- `PHASE_3_IMPROVEMENTS.md` (documentation)

**Compilation Status**: ✅ 0 errors, 5 style warnings (acceptable)

---

## Validation Checklist

### Week 1: Volume Percentile Validation

**Goal**: Verify volume percentiles match market reality

#### Test Cases:

| Symbol | Expected Volume Percentile | Validation Method |
|--------|---------------------------|-------------------|
| **BTCEUR** | 75-85% (high) | Check logs: `📊 Phase 3: Volume percentile for BTCEUR: X%` |
| **ETHEUR** | 70-80% (high) | Should be similar to BTC |
| **ADAEUR** | 60-75% (medium-high) | Mid-tier altcoin |
| **TRUMPEUR** | 0-25% (low) | Low-volume meme coin |
| **WLFIEUR** | 0-25% (low) | Low-volume meme coin |

#### How to Validate:

```bash
# Tail production logs and filter for Phase 3 volume percentile
tail -f /var/log/mytrademate/app.log | grep "Phase 3: Volume percentile"

# Expected output:
# 📊 Phase 3: Volume percentile for BTCEUR: 81.8%
# 📊 Phase 3: Volume percentile for TRUMPEUR: 0.0%
# 📊 Phase 3: Volume percentile for ADAEUR: 72.3%
```

**Success Criteria**:
- ✅ High-volume coins (BTC, ETH) show percentiles > 70%
- ✅ Low-volume coins (TRUMP, WLFI) show percentiles < 30%
- ✅ No API failures (fallback to 0.5 should be rare)

---

### Week 1-2: Recency Calculations

**Goal**: Verify trained_date parsing and recency penalties

#### Test Cases:

| Model | Trained Date | Days Since Training | Expected Penalty |
|-------|--------------|---------------------|------------------|
| `general_5m` | 2025-10-19 | 1 day | None (0%) |
| `btc_1h` | 2025-10-18 | 2 days | None (0%) |
| `general_1h` | 2025-10-10 | 10 days | None (0%) |
| `general_4h` | 2025-10-20 | 0 days | None (0%) |
| `general_1d` | 2025-10-19 | 1 day | None (0%) |

**Note**: All current models are fresh (< 30 days old), so no penalties should apply yet. Re-check in 90 days to validate penalty logic.

#### How to Validate:

```bash
# Check Phase 3 preview logs for recency penalties
tail -f /var/log/mytrademate/app.log | grep "Phase 3 preview"

# Expected output (no penalties for fresh models):
# 🔮 Phase 3 preview for general_5m: volumePercentile=81.8%, trainedDate=2025-10-19
#    🕰️  Recency penalty: no penalty (1 days old)
#
# 🔮 Phase 3 preview for btc_1h: volumePercentile=81.8%, trainedDate=2025-10-18
#    🕰️  Recency penalty: no penalty (2 days old)
```

**Success Criteria**:
- ✅ No `trainedDate=null` errors
- ✅ All models show valid dates (YYYY-MM-DD format)
- ✅ "No penalty" for models < 90 days old
- ✅ "-10% penalty" for models > 90 days old (test in 90 days)

---

### Week 2: Phase 3 Weight Previews

**Goal**: Verify Phase 3 weights are calculated correctly

#### Test Cases:

**BTC@1h** (high volume, exact timeframe match):
```
Expected Phase 3 preview:
📊 Volume percentile: 81.8%
   📏 Base weight: 0.350 (exact match: 1h vs 1h)
   🔥 Volatility boost: +20% (if ATR > 2.5%)
   📈 Performance boost: +10% (if accuracy > avg)
   📊 Volume boost: +5% (percentile: 82%)
   🕰️  Recency penalty: no penalty (2 days old)
```

**TRUMP@1h** (low volume, general models):
```
Expected Phase 3 preview:
📊 Volume percentile: 0.0%
   📏 Base weight: 0.150 (tf mismatch: 1h vs 5m for general_5m)
   ⚖️  General model penalty: -20%
   🕰️  Recency penalty: no penalty (1 days old)
   (No volume boost: percentile < 50%)
```

**ADA@1h** (medium-high volume):
```
Expected Phase 3 preview:
📊 Volume percentile: 72.3%
   📏 Base weight: 0.150 (tf mismatch for general models)
   ⚖️  General model penalty: -20%
   📊 Volume boost: +5% (percentile: 72%)
   🕰️  Recency penalty: no penalty (1 days old)
```

#### How to Validate:

```bash
# Get BTC@1h prediction and check Phase 3 preview
curl http://localhost:8080/api/predict?coin=BTC&timeframe=1h

# Or check app logs for manual predictions
tail -f /var/log/mytrademate/app.log | grep -A 10 "Phase 3 preview"
```

**Success Criteria**:
- ✅ Volume boost (+5%) applied for high-volume symbols (> 50% percentile)
- ✅ No volume boost for low-volume symbols (< 50% percentile)
- ✅ Base weights follow timeframe proximity (exact match = 0.35, mismatch = 0.15)
- ✅ General model penalty (-20%) applied to `general_*` models
- ✅ No crashes or null pointer exceptions

---

### Week 2: Stability Testing

**Goal**: Ensure Phase 3 preview does NOT affect predictions

#### Test Cases:

1. **Prediction Consistency**:
   - Get 10 predictions for BTC@1h
   - Verify `action`, `confidence`, and `risk` are unchanged from pre-Phase 3
   - Check logs: predictions should match exactly (preview mode only logs, doesn't alter)

2. **Performance**:
   - Monitor API response times
   - Volume API calls add ~200-500ms latency
   - Check Binance API rate limits (1200 req/min)

3. **Error Handling**:
   - Simulate Binance API failure (e.g., network timeout)
   - Verify fallback to `volumePercentile = 0.5` works
   - Check logs: `⚠️ Phase 3: Failed to fetch volume percentile, using default 0.5`

#### How to Validate:

```bash
# Compare predictions before and after Phase 3
# (Should be identical since preview mode doesn't alter logic)
curl http://localhost:8080/api/predict?coin=BTC&timeframe=1h > before.json
# ... deploy Phase 3 branch ...
curl http://localhost:8080/api/predict?coin=BTC&timeframe=1h > after.json
diff before.json after.json  # Should show no differences

# Monitor API latency
ab -n 100 -c 10 http://localhost:8080/api/predict?coin=BTC&timeframe=1h
# Check average response time (should be < 1s)
```

**Success Criteria**:
- ✅ Predictions are byte-for-byte identical to pre-Phase 3
- ✅ No crashes, exceptions, or errors
- ✅ API latency < 1 second (includes volume API call)
- ✅ Graceful fallback when volume API fails

---

## Edge Cases to Test

### 1. API Failures

**Scenario**: Binance API is down or rate-limited

**Expected Behavior**:
- Fallback to `volumePercentile = 0.5`
- Log: `⚠️ Phase 3: Failed to fetch volume percentile, using default 0.5`
- Prediction continues normally (no crash)

**How to Test**:
```bash
# Temporarily block Binance API in firewall
sudo iptables -A OUTPUT -d api.binance.com -j DROP
# Make prediction
curl http://localhost:8080/api/predict?coin=BTC&timeframe=1h
# Should see fallback log and prediction succeeds
sudo iptables -D OUTPUT -d api.binance.com -j DROP  # Restore
```

---

### 2. Model Not in Registry

**Scenario**: Coin-specific model exists but not in `model_registry.json`

**Expected Behavior**:
- `_getTrainedDate()` defaults to current date
- Log: No error (silent fallback)
- Phase 3 preview shows `trainedDate=2025-10-20` (current date)

**How to Test**:
```bash
# Remove a model entry from model_registry.json (e.g., btc_1h)
# Make prediction for BTC@1h
curl http://localhost:8080/api/predict?coin=BTC&timeframe=1h
# Should NOT crash, should show current date as fallback
```

---

### 3. Low Candle Count

**Scenario**: New coin (e.g., WLFI) has < 251 candles for 1d timeframe

**Expected Behavior**:
- ATR calculation falls back to default (0.02)
- Volume percentile fetched normally
- Prediction may be HOLD (low confidence)

**How to Test**:
```bash
# Request prediction for WLFI@1d (low candle count)
curl http://localhost:8080/api/predict?coin=WLFI&timeframe=1d
# Check logs for ATR fallback and volume percentile
```

---

## Monitoring Commands

### Real-Time Log Monitoring

```bash
# Monitor all Phase 3 activity
tail -f /var/log/mytrademate/app.log | grep -E "Phase 3|volume_percentile|trainedDate"

# Monitor volume API calls
tail -f /var/log/mytrademate/app.log | grep "Volume percentile for"

# Monitor Phase 3 preview weights
tail -f /var/log/mytrademate/app.log | grep "Phase 3 preview"

# Check for errors
tail -f /var/log/mytrademate/app.log | grep -E "ERROR|Exception|Failed"
```

### Metrics to Track

| Metric | Target | How to Measure |
|--------|--------|----------------|
| **API Latency** | < 1 second | Response time logs |
| **Volume API Success Rate** | > 95% | Count failures vs. successes |
| **Prediction Accuracy** | Unchanged | Compare to baseline |
| **Error Rate** | 0% | Check error logs |

---

## Success Criteria for Full Integration

After 1-2 weeks of validation, Phase 3 is ready for full integration if:

1. ✅ **Volume Percentiles**: Align with market reality (high-volume coins > 70%, low-volume < 30%)
2. ✅ **Recency Calculations**: All dates valid, no nulls, penalties apply correctly
3. ✅ **Phase 3 Weights**: Logged correctly, boosts/penalties make sense
4. ✅ **Stability**: No crashes, errors, or prediction changes
5. ✅ **Performance**: API latency < 1 second, no rate limit issues
6. ✅ **Edge Cases**: API failures handled gracefully, low candles supported

---

## Post-Validation: Full Integration Steps

Once validation passes, proceed with full integration (estimated 2-3 hours):

### 1. Replace Weight Calculation (~30 min)

**File**: `lib/ml/crypto_ml_service.dart`

**Change**:
```dart
// OLD (line 326, 360):
final weight = _calculateTimeframeWeight(timeframe, tf);

// NEW:
final weight = EnsembleWeightsV2.calculateTimeframeWeight(
  requestedTf: timeframe,
  modelTf: tf,
  coin: coin,
  atr: atr,
  modelKey: modelKey,
  isGeneral: isGeneral,
  volumePercentile: volumePercentile,
  trainedDate: _getTrainedDate(modelKey),
);
```

**Remove**:
- `_calculateTimeframeWeight()` method (lines 695-725)
- Phase 3 preview logging (lines 296-310, 326-340)

---

### 2. Extend CryptoPrediction (~30 min)

**File**: `lib/ml/crypto_ml_service.dart` (CryptoPrediction class)

**Add Fields**:
```dart
class CryptoPrediction {
  // ... existing fields ...
  final double? volumePercentile;  // NEW
  final String? phase3Note;         // NEW

  CryptoPrediction({
    // ... existing params ...
    this.volumePercentile,
    this.phase3Note,
  });
}
```

**Update `getPrediction()`**:
```dart
return CryptoPrediction(
  // ... existing params ...
  volumePercentile: volumePercentile,
  phase3Note: 'Phase 3 weights applied (volume boost + recency penalty)',
);
```

---

### 3. Add Unit Tests (~1 hour)

**File**: `test/ensemble_weights_test.dart`

**Tests to Add**:
- Volume boost (+5%) for `volumePercentile > 0.5`
- Recency penalty (-10%) for models > 90 days old
- Weight normalization (sum ≈ 1.0)
- Edge cases (API failures, null dates)

---

### 4. Deploy and Monitor

**Deployment**:
1. Merge `feature/phase3-optimized-general-models` to `main`
2. Deploy to staging first
3. Run smoke tests (BTC@1h, TRUMP@1h, ADA@1h)
4. Deploy to production

**Monitoring**:
- Track prediction accuracy (should improve by 2-5%)
- Monitor for any regressions or bugs
- Adjust thresholds if needed (65% TRUMP/WLFI, 60% others)

---

## Rollback Plan

If issues arise during validation or full integration:

### Immediate Rollback:

```bash
# Checkout main branch
git checkout main

# Or revert specific commits
git revert c450c40  # Revert Phase 3 improvements
git revert 3bdf206  # Revert Phase 3 implementation
```

### Gradual Rollback:

1. Disable Phase 3 logging (comment out preview prints)
2. Keep infrastructure (BinanceService, model registry)
3. Re-enable after fixing issues

---

## Contact & Support

**Documentation**:
- `PHASE_3_IMPROVEMENTS.md` - Technical details
- `PHASE_3_SUMMARY.md` - Foundation overview
- `ENSEMBLE_UPGRADE_ROADMAP.md` - Overall strategy

**Questions**:
- Check logs first: `grep "Phase 3" /var/log/mytrademate/app.log`
- Review documentation above
- Test in staging before production

---

## Summary

✅ **Phase 3 Preview Mode**: Complete and stable
🔬 **Validation Period**: 1-2 weeks recommended
📊 **What to Monitor**: Volume percentiles, recency penalties, stability
🚀 **Full Integration**: Proceed only after successful validation

**Key Decision**: Validate in production first, then apply Phase 3 weights to predictions. This ensures stability and validates logic with real data before making changes that affect user-facing predictions.

---

**Created**: 2025-10-20
**Author**: Claude Code (Phase 3 Validation Plan)
**Status**: Ready for Deployment & Validation
