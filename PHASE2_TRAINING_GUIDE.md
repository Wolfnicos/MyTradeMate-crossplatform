# Phase 2: AI Model Training Guide

**MyTradeMate AI Upgrade - Complete Training Pipeline**

---

## 🎯 Overview

This guide walks you through training and deploying the ensemble AI model for MyTradeMate. You'll train 3 models:

1. **Transformer** (50% weight) - Best for complex temporal patterns
2. **LSTM** (30% weight) - Strong at sequential dependencies
3. **Random Forest** (20% weight) - Interpretable baseline

**Timeline:** 4-6 weeks (including data collection, training, and testing)

---

## 📋 Prerequisites

### Hardware Requirements

**Recommended:**
- GPU with 8GB+ VRAM (NVIDIA RTX 3060 Ti or better)
- 16GB+ RAM
- 100GB+ free disk space

**Alternatives:**
- Google Colab (free, 12h sessions, limited GPU)
- AWS EC2 g4dn.xlarge (~$0.53/hour)
- Google Cloud n1-standard-4 + Tesla T4 (~$0.40/hour)

### Software Requirements

```bash
# Python 3.8+
python --version

# Install dependencies
pip install tensorflow==2.13.0
pip install pandas numpy scikit-learn
pip install python-binance  # For data collection
pip install matplotlib seaborn  # For visualization
```

### API Keys Required

1. **Binance API** (free)
   - Sign up: https://www.binance.com/en/my/settings/api-management
   - Create API key (READ permissions only)

2. **Glassnode API** (optional, $39/month)
   - Sign up: https://studio.glassnode.com/settings/api
   - 7-day free trial available

3. **LunarCrush API** (optional, $29/month)
   - Sign up: https://lunarcrush.com/developers/api
   - Free tier: 1,000 requests/month

---

## 🗂️ Step 1: Data Collection

### 1.1 Configure API Keys

Create `python_training/.env`:

```bash
# Binance (required)
BINANCE_API_KEY=your_binance_key_here
BINANCE_API_SECRET=your_binance_secret_here

# Glassnode (optional - will use fallback if missing)
GLASSNODE_API_KEY=your_glassnode_key_or_leave_empty

# LunarCrush (optional - will use fallback if missing)
LUNARCRUSH_API_KEY=your_lunarcrush_key_or_leave_empty
```

### 1.2 Collect Training Data

```bash
cd python_training

# Collect 2 years of BTCUSDT data
python collect_training_data.py \
  --symbols BTCUSDT \
  --start-date 2022-01-01 \
  --end-date 2024-01-01 \
  --output btc_training_data.npz

# Output:
# ✅ Data collection complete!
# Saved: btc_training_data.npz
# Samples: 15,840 sequences
# Shape: [15840, 120, 42]
```

**What this script does:**
- Fetches 1h, 15m, 4h candles from Binance
- Fetches on-chain data from Glassnode (if API key provided)
- Fetches sentiment data from LunarCrush (if API key provided)
- Engineers 42 features (30 MTF + 4 one-hot + 8 alternative)
- Generates labels: STRONG_SELL (0), SELL (1), BUY (2), STRONG_BUY (3)
- Creates 120-timestep sequences
- Saves to `.npz` file

**Expected time:** 2-6 hours (depending on API rate limits)

### 1.3 Verify Data Quality

```bash
# Check data statistics
python -c "
import numpy as np
data = np.load('btc_training_data.npz')
print('Samples:', len(data['X']))
print('Shape:', data['X'].shape)
print('Labels:', np.unique(data['y'], return_counts=True))
"

# Expected output:
# Samples: 15840
# Shape: (15840, 120, 42)
# Labels: (array([0, 1, 2, 3]), array([2500, 5200, 5800, 2340]))
```

**Good signs:**
- ✅ 10,000+ samples
- ✅ All 4 classes present
- ✅ No extreme class imbalance (worst class > 15% of total)

**Bad signs:**
- ❌ < 5,000 samples → Collect more data
- ❌ Missing classes → Adjust labeling thresholds in `collect_training_data.py`
- ❌ One class > 80% → Severe imbalance, adjust thresholds

---

## 🤖 Step 2: Train Models

### 2.1 Train Transformer Model

```bash
python train_transformer_model.py \
  --data btc_training_data.npz \
  --epochs 100 \
  --batch-size 32 \
  --output-dir models/transformer

# Training progress:
# Epoch 1/100
# 440/440 [==============================] - 45s 102ms/step
# loss: 1.2345 - accuracy: 0.4523 - val_loss: 1.1234 - val_accuracy: 0.4890
# ...
# Epoch 67/100
# 440/440 [==============================] - 42s 95ms/step
# loss: 0.5678 - accuracy: 0.7234 - val_loss: 0.6123 - val_accuracy: 0.6890
# EarlyStopping: Restoring best weights

# ✅ Training complete!
# Test Accuracy: 68.5%
# Model saved: models/transformer/transformer_model.tflite (2.3 MB)
```

**Expected time:** 2-6 hours (depending on GPU)

**Expected results:**
- Test accuracy: 60-75%
- Precision/Recall: 0.60-0.75
- Model size: < 3 MB

### 2.2 Train LSTM Model

```bash
python train_lstm_model.py \
  --data btc_training_data.npz \
  --epochs 100 \
  --batch-size 32 \
  --output-dir models/lstm

# ✅ Training complete!
# Test Accuracy: 64.2%
# Model saved: models/lstm/lstm_model.tflite (1.8 MB)
```

**Expected time:** 1-4 hours

**Expected results:**
- Test accuracy: 58-70%
- Slightly lower than Transformer (expected)
- Model size: < 2 MB

### 2.3 Train Random Forest Model

```bash
python train_random_forest_model.py \
  --data btc_training_data.npz \
  --trees 200 \
  --max-depth 20 \
  --output-dir models/random_forest

# ✅ Training complete!
# Test Accuracy: 61.8%
# Model saved: models/random_forest/random_forest_model.pkl (45 MB)

# Top 5 Most Important Features:
#   1. feat_1h_rsi_t119: 0.0523
#   2. feat_1h_macd_t119: 0.0418
#   3. feat_alt_sentiment_score_t119: 0.0392
#   4. feat_4h_adx_t119: 0.0365
#   5. feat_1h_atr_t119: 0.0341
```

**Expected time:** 10-30 minutes (CPU only)

**Expected results:**
- Test accuracy: 55-65%
- Feature importance insights (which indicators work best)
- Large model size (45+ MB) - not deployable to mobile directly

---

## 📊 Step 3: Analyze Results

### 3.1 Compare Model Performance

```bash
# Create comparison script
cat > compare_models.py << 'EOF'
import json

# Load metrics
with open('models/transformer/evaluation_metrics.json') as f:
    transformer = json.load(f)

with open('models/lstm/evaluation_metrics.json') as f:
    lstm = json.load(f)

with open('models/random_forest/evaluation_metrics.json') as f:
    rf = json.load(f)

print("\n=== Model Performance Comparison ===\n")
print(f"Transformer:   {transformer['test_accuracy']*100:.1f}% accuracy")
print(f"LSTM:          {lstm['test_accuracy']*100:.1f}% accuracy")
print(f"Random Forest: {rf['test_accuracy']*100:.1f}% accuracy")

# Weighted ensemble prediction
ensemble_acc = (
    0.50 * transformer['test_accuracy'] +
    0.30 * lstm['test_accuracy'] +
    0.20 * rf['test_accuracy']
)
print(f"\nEnsemble (weighted): {ensemble_acc*100:.1f}% accuracy (estimated)")
EOF

python compare_models.py

# Output:
# === Model Performance Comparison ===
#
# Transformer:   68.5% accuracy
# LSTM:          64.2% accuracy
# Random Forest: 61.8% accuracy
#
# Ensemble (weighted): 66.1% accuracy (estimated)
```

### 3.2 Review Confusion Matrices

Open generated plots:

```bash
# Transformer confusion matrix
open models/transformer/confusion_matrix_transformer.png

# LSTM confusion matrix
open models/lstm/confusion_matrix_lstm.png

# Random Forest confusion matrix
open models/random_forest/confusion_matrix_rf.png
```

**Good signs:**
- ✅ Diagonal dominance (correct predictions)
- ✅ BUY/STRONG_BUY classes > 60% precision
- ✅ Minimal confusion between STRONG_SELL and STRONG_BUY

**Bad signs:**
- ❌ Random-looking matrix (all cells ~25%) → Model not learning
- ❌ Severe class bias (predicts only one class) → Adjust class weights
- ❌ High confusion between opposite classes → Feature engineering issue

### 3.3 Feature Importance Analysis (Random Forest)

```bash
# View top 20 features
head -20 models/random_forest/feature_importance.csv

# Output:
# feature,importance
# feat_1h_rsi_t119,0.0523
# feat_1h_macd_t119,0.0418
# feat_alt_sentiment_score_t119,0.0392
# ...
```

**Insights to look for:**
- Which timeframe is most predictive? (1h, 15m, or 4h)
- Which indicators are most important? (RSI, MACD, ADX, etc.)
- Are alternative data sources valuable? (sentiment, on-chain)

---

## 📱 Step 4: Flutter Integration

### 4.1 Copy TFLite Models

```bash
# Create assets directory
mkdir -p ../assets/ml

# Copy models
cp models/transformer/transformer_model.tflite ../assets/ml/
cp models/lstm/lstm_model.tflite ../assets/ml/

# Note: Random Forest not deployed to mobile (too large)
# Using rule-based fallback in ensemble_predictor.dart
```

### 4.2 Update pubspec.yaml

Ensure TFLite dependency and assets are declared:

```yaml
dependencies:
  tflite_flutter: ^0.10.0

flutter:
  assets:
    - assets/ml/transformer_model.tflite
    - assets/ml/lstm_model.tflite
```

### 4.3 Install Dependencies

```bash
cd ..  # Back to Flutter project root
flutter pub get
```

### 4.4 Test Ensemble Predictor

Create test file `test/ensemble_predictor_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ml/ensemble_predictor.dart';
import 'package:mytrademate/services/mtf_feature_builder_v2.dart';

void main() {
  test('Ensemble predictor loads and predicts', () async {
    // Load predictor
    final predictor = EnsemblePredictor();
    await predictor.loadModels();

    expect(predictor.isLoaded, true);

    // Create dummy features (120 x 42)
    final dummyFeatures = List.generate(
      120,
      (i) => List.generate(42, (j) => 0.5),
    );

    // Get prediction
    final prediction = await predictor.predict(dummyFeatures);

    expect(prediction.label, isNotEmpty);
    expect(prediction.confidence, greaterThan(0.0));
    expect(prediction.confidence, lessThanOrEqual(1.0));

    print('Test Prediction: ${prediction.label} (${(prediction.confidence * 100).toStringAsFixed(1)}%)');

    predictor.dispose();
  });
}
```

Run test:

```bash
flutter test test/ensemble_predictor_test.dart

# Output:
# 00:01 +1: All tests passed!
# Test Prediction: BUY (62.3%)
```

---

## 🚀 Step 5: Deploy to Production

### 5.1 Initialize Model Manager

In `lib/main.dart` or service locator:

```dart
import 'package:mytrademate/ml/model_manager.dart';

// Initialize at app startup
final modelManager = ModelManager();
await modelManager.initialize();
```

### 5.2 Integrate with Trading Flow

Replace old AI predictor with new ensemble:

```dart
// OLD (Phase 1):
// final prediction = await mlPredictor.predict(candles);

// NEW (Phase 2):
final features = await featureBuilder.buildFeatures(
  symbol: 'BTCUSDT',
  base1h: candles1h,
  low15m: candles15m,
  high4h: candles4h,
);

final prediction = await modelManager.predict(features);

if (prediction.prediction.isTradeable) {
  // Execute trade with confidence-based position sizing
  final baseSize = 1000.0; // $1000
  final adjustedSize = baseSize * prediction.prediction.confidence;

  await executeTrade(
    signal: prediction.prediction.toSignalType(),
    size: adjustedSize,
  );

  // Record outcome after 4 hours
  Timer(Duration(hours: 4), () async {
    final futurePrice = await binanceService.getCurrentPrice('BTCUSDT');
    await modelManager.recordOutcome(
      prediction: prediction,
      actualPrice: currentPrice,
      futurePrice: futurePrice,
    );
  });
}
```

### 5.3 Monitor Performance

Add UI for monitoring:

```dart
// In settings or debug screen
final summary = modelManager.getABTestingSummary();

print('Champion Accuracy: ${(summary['championPerformance']['accuracy'] * 100).toStringAsFixed(1)}%');
print('Champion Sharpe: ${summary['championPerformance']['sharpeRatio'].toStringAsFixed(2)}');
```

---

## 🧪 Step 6: A/B Testing New Models

### 6.1 Train Improved Model (v2)

After production deployment, continue improving:

```bash
# Collect more recent data
python collect_training_data.py \
  --symbols BTCUSDT \
  --start-date 2023-01-01 \
  --end-date 2025-01-01 \
  --output btc_training_data_v2.npz

# Train Transformer v2 with more data
python train_transformer_model.py \
  --data btc_training_data_v2.npz \
  --epochs 120 \
  --output-dir models/transformer_v2
```

### 6.2 Deploy as Challenger

```dart
// Deploy new model in shadow mode (0% traffic)
await modelManager.deployChallenger();

// Monitor for 7 days
// If challenger outperforms, traffic automatically increases:
// 0% → 10% → 50% → 100% → promoted to champion
```

### 6.3 Monitor A/B Test

```dart
final summary = modelManager.getABTestingSummary();

if (summary['challengerActive']) {
  final championAcc = summary['championPerformance']['accuracy'];
  final challengerAcc = summary['challengerPerformance']['accuracy'];
  final trafficPct = summary['challengerTrafficPercentage'];

  print('A/B Test Status:');
  print('  Champion:   ${(championAcc * 100).toStringAsFixed(1)}%');
  print('  Challenger: ${(challengerAcc * 100).toStringAsFixed(1)}%');
  print('  Traffic:    ${trafficPct.toStringAsFixed(0)}% to challenger');
}
```

---

## 📈 Expected Results

### Performance Targets

**Minimum acceptable:**
- Overall accuracy: > 55% (better than random)
- Sharpe ratio: > 0.5 (positive risk-adjusted returns)
- Win rate: > 50%

**Good performance:**
- Overall accuracy: 60-70%
- Sharpe ratio: 0.8-1.2
- Win rate: 55-65%

**Exceptional performance:**
- Overall accuracy: > 70%
- Sharpe ratio: > 1.5
- Win rate: > 65%

### Realistic Expectations

**Do NOT expect:**
- ❌ 90%+ accuracy (impossible in crypto markets)
- ❌ 100% win rate (unrealistic)
- ❌ Immediate profitability (needs calibration period)

**DO expect:**
- ✅ Gradual improvement over weeks
- ✅ Better performance in trending markets than choppy markets
- ✅ Occasional losing streaks (normal)
- ✅ Need for periodic retraining (monthly recommended)

---

## 🐛 Troubleshooting

### Issue: Low Model Accuracy (< 50%)

**Possible causes:**
1. Insufficient data → Collect more (aim for 20,000+ samples)
2. Poor feature engineering → Check for NaN/inf values
3. Overfitting → Reduce model complexity, add dropout
4. Class imbalance → Adjust class weights

**Fix:**
```bash
# Check for data issues
python -c "
import numpy as np
data = np.load('btc_training_data.npz')
print('NaN values:', np.isnan(data['X']).sum())
print('Inf values:', np.isinf(data['X']).sum())
"

# If NaN/Inf found, re-run data collection with validation
```

### Issue: TFLite Model Too Large (> 5 MB)

**Possible causes:**
1. Too many layers
2. Too many units per layer
3. No quantization

**Fix:**
```python
# In training script, add quantization
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]  # Half precision
```

### Issue: Model Predicts Only One Class

**Possible causes:**
1. Severe class imbalance
2. Class weights too extreme
3. Threshold too high/low

**Fix:**
```python
# In collect_training_data.py, adjust thresholds
STRONG_THRESHOLD = 0.015  # Lower from 0.02
WEAK_THRESHOLD = 0.005    # Adjust
```

### Issue: Inference Too Slow on Mobile (> 500ms)

**Possible causes:**
1. Model too complex
2. No GPU acceleration
3. Inefficient feature builder

**Fix:**
```dart
// Enable GPU delegate (Android)
final options = InterpreterOptions()..useNnApiForAndroid = true;
final interpreter = await Interpreter.fromAsset(modelPath, options: options);
```

---

## 📚 Next Steps

After completing Phase 2:

### Option 1: Phase 3 - Risk Management (Recommended)

Implement advanced risk controls:
- Dynamic stop-loss/take-profit (ATR-based)
- Trailing stop-loss
- Kelly Criterion position sizing
- Circuit breakers
- Correlation-based hedging

**Timeline:** 2 weeks

### Option 2: Phase 4 - Educational Features

Add in-app education:
- Interactive onboarding
- Strategy explanations with animations
- Paper trading tutorial
- Performance analytics dashboard

**Timeline:** 1-2 weeks

### Option 3: Continue Model Improvement

- Experiment with attention mechanisms
- Add more alternative data sources (funding rates, liquidations)
- Implement meta-learning (few-shot adaptation)
- Multi-symbol ensemble

**Timeline:** Ongoing

---

## 📞 Support

**Common Questions:**

**Q: Can I skip Glassnode/LunarCrush APIs?**
A: Yes! The system uses fallback values if these APIs are missing. Performance may be 2-5% lower.

**Q: How often should I retrain models?**
A: Monthly recommended. Crypto markets evolve quickly.

**Q: Can I train on Google Colab?**
A: Yes! Upload scripts and data, run training. Beware 12-hour session limits.

**Q: What if my GPU runs out of memory?**
A: Reduce batch size: `--batch-size 16` or even `--batch-size 8`.

**Q: How do I know if ensemble is working?**
A: Check `modelManager.getABTestingSummary()` - champion accuracy should be > 60% after 100+ predictions.

---

## ✅ Checklist

Before deploying to production:

- [ ] Collected 10,000+ training samples
- [ ] All 3 models trained successfully
- [ ] Test accuracy > 55% for all models
- [ ] TFLite models < 3 MB each
- [ ] Integration tests passing
- [ ] Model Manager initialized correctly
- [ ] Adaptive Calibrator recording outcomes
- [ ] A/B testing dashboard visible in UI
- [ ] Tested on paper trading for 1 week minimum
- [ ] No errors in production logs

---

**Date:** 17 Octombrie 2025
**Phase 2 Status:** Implementation Complete ✅
**Estimated Training Time:** 4-6 weeks (including data collection and testing)

**Ready to train? Start with Step 1: Data Collection! 🚀**
