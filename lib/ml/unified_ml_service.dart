import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert' show utf8;
// import 'package:tflite_flutter/tflite_flutter.dart';
// import '../services/full_feature_builder.dart';
import '../services/binance_service.dart';
import 'model_registry.dart';
import 'crypto_ml_service.dart';

/// Unified ML Service:
/// - Loads Model Registry from assets
/// - Normalizes labels to [SELL,HOLD,BUY]
/// - Applies per-model temperature scaling (+bias on logits)
/// - Weighted averaging ensemble using weights from registry
/// - Confidence gating per timeframe
/// - Feature parity guard via feature_hash
/// - Consistent fallback when models/data missing
class UnifiedMLService {
  static final UnifiedMLService _instance = UnifiedMLService._internal();
  factory UnifiedMLService() => _instance;
  UnifiedMLService._internal();

  ModelRegistryV1? _registry;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    try {
      _registry = await ModelRegistryV1.loadFromAssets();
      _initialized = true;
      debugPrint('✅ UnifiedMLService initialized with registry schema=${_registry?.schema ?? ''}'); 
    } catch (e) {
      _initialized = false;
      debugPrint('❌ UnifiedMLService: failed to load registry → $e');
    }
  }

  /// Compute features and return a unified decision
  Future<UnifiedDecisionResult> predict({
    required String symbol, // e.g., BTCUSDT
    required String timeframe, // '15m','1h','4h','1d','7d'
  }) async {
    final ModelRegistryV1? reg = _registry;
    if (!_initialized || reg == null) {
      // Unified telemetry log
      _logTelemetry(
        coin: _extractBase(symbol),
        tf: timeframe,
        ids: const <String>[],
        weights: const <double>[],
        temps: const <double>[],
        pFinal: const <double>[0.33, 0.34, 0.33],
        action: 'HOLD',
        confidence: 0.33,
        confThresh: 0.0,
        featureHashOk: false,
        reason: 'registry_not_loaded',
      );
      return UnifiedDecisionResult(
        action: 'HOLD',
        confidence: 0.33,
        probabilities: const <double>[0.33, 0.34, 0.33],
        timeframe: timeframe,
        usedModelIds: const <String>[],
        featureHashOk: false,
        reason: 'registry_not_loaded',
      );
    }

    // Feature-parity guard BEFORE inference
    final String runtimeHash = _computeRuntimeFeatureHash();
    if ((reg.featureHash).isNotEmpty && runtimeHash != reg.featureHash) {
      final String tfNormEarly = reg.normalizeTimeframe(timeframe);
      debugPrint('❌ UnifiedML: data_quality=BAD — feature hash mismatch. runtime=$runtimeHash expected=${reg.featureHash}');
      _logTelemetry(
        coin: _extractBase(symbol),
        tf: tfNormEarly,
        ids: const <String>[],
        weights: const <double>[],
        temps: const <double>[],
        pFinal: _fallbackProbs('HOLD'),
        action: 'HOLD',
        confidence: 0.33,
        confThresh: reg.thresholdForTimeframe(tfNormEarly),
        featureHashOk: false,
        reason: 'feature_hash_mismatch',
      );
      return UnifiedDecisionResult(
        action: 'HOLD',
        confidence: reg.fallback.confidence,
        probabilities: _fallbackProbs('HOLD'),
        timeframe: tfNormEarly,
        usedModelIds: const <String>[],
        featureHashOk: false,
        reason: 'feature_hash_mismatch',
      );
    }

    // Build features (60 x 76) or return fallback on insufficient candles
    List<List<double>> features;
    try {
      features = await BinanceService().getFeaturesForModel(symbol, interval: timeframe);
    } catch (e) {
      final String tfNormEarly = reg.normalizeTimeframe(timeframe);
      debugPrint('❌ UnifiedML: insufficient_data — failed to build features (e.g., SMA200 needs >=260 candles). error=$e');
      _logTelemetry(
        coin: _extractBase(symbol),
        tf: tfNormEarly,
        ids: const <String>[],
        weights: const <double>[],
        temps: const <double>[],
        pFinal: _fallbackProbs('HOLD'),
        action: 'HOLD',
        confidence: reg.fallback.confidence,
        confThresh: reg.thresholdForTimeframe(tfNormEarly),
        featureHashOk: false,
        reason: 'insufficient_data',
      );
      return UnifiedDecisionResult(
        action: reg.fallback.action,
        confidence: reg.fallback.confidence,
        probabilities: _fallbackProbs('HOLD'),
        timeframe: tfNormEarly,
        usedModelIds: const <String>[],
        featureHashOk: false,
        reason: 'insufficient_data',
      );
    }

    // Feature parity guard result (post-build confirmation)
    final bool featureHashOk = (reg.featureHash).isEmpty || _verifyRuntimeFeatureHash(reg.featureHash);

    final String coin = _extractBase(symbol);
    final String tfNorm = reg.normalizeTimeframe(timeframe);

    // Collect model predictions
    final selected = reg.selectModels(coinUpper: coin, timeframe: tfNorm);
    if (selected.isEmpty) {
      // If no per-coin models, try general-only for tf
      final general = reg.selectModels(coinUpper: '*', timeframe: tfNorm);
      if (general.isEmpty) {
        debugPrint('⚠️ UnifiedML: model unavailable for coin=$coin tf=$tfNorm → using registry fallback HOLD');
        _logTelemetry(
          coin: coin,
          tf: tfNorm,
          ids: const <String>[],
          weights: const <double>[],
          temps: const <double>[],
          pFinal: _fallbackProbs('HOLD'),
          action: reg.fallback.action,
          confidence: reg.fallback.confidence,
          confThresh: reg.thresholdForTimeframe(tfNorm),
          featureHashOk: true,
          reason: 'model_unavailable',
        );
        return UnifiedDecisionResult(
          action: reg.fallback.action,
          confidence: reg.fallback.confidence,
          probabilities: _fallbackProbs(reg.fallback.action),
          timeframe: tfNorm,
          usedModelIds: const <String>[],
          featureHashOk: featureHashOk,
          reason: 'model_unavailable',
        );
      }
    }
    final modelsToUse = selected.isNotEmpty ? selected : reg.selectModels(coinUpper: '*', timeframe: tfNorm);

    // For execution, we rely on CryptoMLService interpreters naming convention
    // model ids align with coin+tf (e.g., btc_1h, general_1h)
    final probsAccum = List<double>.filled(3, 0.0);
    double totalW = 0.0;
    final usedIds = <String>[];
    final usedWeights = <double>[];
    final usedTemps = <double>[];

    for (final m in modelsToUse) {
      try {
        final Map<String, double> pMap = await _predictWithCryptoService(modelId: m.id, coin: m.coin, timeframe: m.tf, features: features);
        // Normalize incoming labels to registry order
        final List<double> p = _reorderToRegistry(pMap, m.labels, reg.labelOrder);
        // Apply bias on logits then temperature scaling
        final List<double> pCal = _calibrate(p, temperature: m.temp, bias: m.bias);
        // Weighted sum
        probsAccum[0] += pCal[0] * m.w;
        probsAccum[1] += pCal[1] * m.w;
        probsAccum[2] += pCal[2] * m.w;
        totalW += m.w;
        usedIds.add(m.id);
        usedWeights.add(m.w);
        usedTemps.add(m.temp);
      } catch (e) {
        debugPrint('⚠️ UnifiedMLService: model ${m.id} failed → $e');
      }
    }

    if (totalW <= 0) {
      // Telemetry
      _logTelemetry(
        coin: coin,
        tf: tfNorm,
        ids: usedIds,
        weights: usedWeights,
        temps: usedTemps,
        pFinal: _fallbackProbs('HOLD'),
        action: reg.fallback.action,
        confidence: reg.fallback.confidence,
        confThresh: reg.thresholdForTimeframe(tfNorm),
        featureHashOk: featureHashOk,
        reason: 'no_active_models',
      );
      return UnifiedDecisionResult(
        action: reg.fallback.action,
        confidence: reg.fallback.confidence,
        probabilities: _fallbackProbs(reg.fallback.action),
        timeframe: tfNorm,
        usedModelIds: usedIds,
        featureHashOk: featureHashOk,
        reason: 'no_active_models',
      );
    }

    // Normalize final ensemble
    final List<double> pFinal = probsAccum.map((v) => v / totalW).toList(growable: false);

    // Gating by timeframe threshold + optional risk adjustment based on volatility z-score
    double gate = reg.thresholdForTimeframe(tfNorm);
    double usedGate = gate;
    String reason = 'ok';

    // Optional: risk-based threshold bump if volatility is high
    final double? volZ = _estimateVolatilityZ(features);
    if (volZ != null && reg.risk != null && volZ > reg.risk!.volZLimit && reg.risk!.volThreshIncrement > 0) {
      usedGate = (gate + reg.risk!.volThreshIncrement).clamp(0.0, 0.95);
    }

    final int argMax = _argmax(pFinal);
    final double conf = pFinal[argMax];

    if (conf < usedGate) {
      // Telemetry
      _logTelemetry(
        coin: coin,
        tf: tfNorm,
        ids: usedIds,
        weights: usedWeights,
        temps: usedTemps,
        pFinal: pFinal,
        action: 'HOLD',
        confidence: pFinal[1],
        confThresh: usedGate,
        featureHashOk: featureHashOk,
        reason: 'below_threshold',
      );
      return UnifiedDecisionResult(
        action: 'HOLD',
        confidence: pFinal[1],
        probabilities: pFinal,
        timeframe: tfNorm,
        usedModelIds: usedIds,
        featureHashOk: featureHashOk,
        reason: 'below_threshold',
      );
    }

    final String action = reg.labelOrder[argMax];
    // Telemetry
    _logTelemetry(
      coin: coin,
      tf: tfNorm,
      ids: usedIds,
      weights: usedWeights,
      temps: usedTemps,
      pFinal: pFinal,
      action: action,
      confidence: conf,
      confThresh: usedGate,
      featureHashOk: featureHashOk,
      reason: 'ok',
    );
    return UnifiedDecisionResult(
      action: action,
      confidence: conf,
      probabilities: pFinal,
      timeframe: tfNorm,
      usedModelIds: usedIds,
      featureHashOk: featureHashOk,
      reason: reason,
    );
  }

  // --- Helpers ---
  String _extractBase(String symbol) {
    // BTCUSDT, BTCEUR, BTC/USDT
    String s = symbol.replaceAll('/', '').toUpperCase();
    for (final q in const <String>['USDT','USDC','USD','EUR']) {
      if (s.endsWith(q)) {
        return s.substring(0, s.length - q.length);
      }
    }
    return s;
  }

  void _logTelemetry({
    required String coin,
    required String tf,
    required List<String> ids,
    required List<double> weights,
    required List<double> temps,
    required List<double> pFinal,
    required String action,
    required double confidence,
    required double confThresh,
    required bool featureHashOk,
    required String reason,
  }) {
    final String weightsStr = weights.isEmpty ? '[]' : '[${weights.map((w) => w.toStringAsFixed(2)).join(', ')}]';
    final String tempsStr = temps.isEmpty ? '[]' : '[${temps.map((t) => t.toStringAsFixed(2)).join(', ')}]';
    final String pStr = '[${pFinal.map((p) => p.toStringAsFixed(4)).join(', ')}]';
    final String dq = featureHashOk ? 'OK' : 'BAD';
    debugPrint('');
    debugPrint('🎯 ENSEMBLE PREDICTION $coin @ ${tf.toUpperCase()}');
    debugPrint('models_used=$ids, weights=$weightsStr, temps=$tempsStr, labels=["SELL","HOLD","BUY"]');
    debugPrint('P_final=$pStr, action=$action, confidence=${confidence.toStringAsFixed(4)}, confThresh=${confThresh.toStringAsFixed(2)}');
    debugPrint('data_quality=$dq${reason.isNotEmpty ? ', reason=$reason' : ''}');
  }

  Future<Map<String, double>> _predictWithCryptoService({required String modelId, required String coin, required String timeframe, required List<List<double>> features}) async {
    // CryptoMLService stores interpreters keyed by coin_tf (lowercase)
    // final String key = modelId.toLowerCase();
    // If not loaded, try load once via its API
    if (!CryptoMLService().isModelLoaded(coin.toLowerCase(), timeframe)) {
      await CryptoMLService().loadModel(coin.toLowerCase(), timeframe);
    }
    // Use the public inference to get probabilities as map in [SELL,HOLD,BUY]
    final pred = await CryptoMLService().getPrediction(
      coin: coin == '*' ? 'general' : coin.toLowerCase(),
      priceData: features,
      timeframe: timeframe,
    );
    return pred.probabilities;
  }

  List<double> _reorderToRegistry(Map<String, double> pMap, List<String> modelLabels, List<String> registryOrder) {
    // Ensure we can handle binary outputs (HOLD might be 0)
    final double sell = pMap['SELL'] ?? 0.0;
    final double hold = pMap['HOLD'] ?? 0.0;
    final double buy = pMap['BUY'] ?? 0.0;
    // Normalize to sum 1 across three slots (allow 0 HOLD for binary)
    double sum = sell + hold + buy;
    if (sum <= 0) {
      return const <double>[1/3, 1/3, 1/3];
    }
    final norm = <double>[sell / sum, hold / sum, buy / sum];
    // Registry order is fixed [SELL,HOLD,BUY]
    return norm;
  }

  List<double> _calibrate(List<double> probs, {required double temperature, required List<double> bias}) {
    // p -> logit clip, temperature scaling, then bias: softmax((logits / T) + bias)
    final double eps = 1e-6;
    final List<double> logits = <double>[
      math.log((probs[0]).clamp(eps, 1.0)),
      math.log((probs[1]).clamp(eps, 1.0)),
      math.log((probs[2]).clamp(eps, 1.0)),
    ];
    final double T = (temperature <= 0) ? 1.0 : temperature;
    final List<double> scaled = List<double>.generate(logits.length, (int i) {
      final double b = i < bias.length ? bias[i] : 0.0;
      return (logits[i] / T) + b;
    }, growable: false);
    return _softmax(scaled);
  }

  List<double> _softmax(List<double> logits) {
    final double maxLogit = logits.reduce(math.max);
    final List<double> expVals = logits.map((l) => math.exp(l - maxLogit)).toList(growable: false);
    final double sumExp = expVals.reduce((a, b) => a + b);
    if (sumExp <= 0) {
      return const <double>[1/3, 1/3, 1/3];
    }
    return expVals.map((e) => e / sumExp).toList(growable: false);
  }

  int _argmax(List<double> v) {
    int idx = 0; double best = v[0];
    for (int i = 1; i < v.length; i++) {
      if (v[i] > best) { best = v[i]; idx = i; }
    }
    return idx;
  }

  List<double> _fallbackProbs(String action) {
    switch (action) {
      case 'SELL':
        return const <double>[0.6, 0.2, 0.2];
      case 'BUY':
        return const <double>[0.2, 0.2, 0.6];
      default:
        return const <double>[0.33, 0.34, 0.33];
    }
  }

  // (removed old _checkFeatureHash) — now using runtime hash verification

  // Compose deterministic feature spec string and compute SHA256
  String _computeRuntimeFeatureHash() {
    // NOTE: Keep this spec in sync with FullFeatureBuilder
    // keep list in spec string to avoid unused variable warning
    const String spec =
      'features:76;window:60;'
      'patterns:'
      'doji,dragonfly_doji,gravestone_doji,long_legged_doji,hammer,inverted_hammer,shooting_star,hanging_man,'
      'spinning_top,marubozu_bullish,marubozu_bearish,bullish_engulfing,bearish_engulfing,piercing_line,'
      'dark_cloud_cover,bullish_harami,bearish_harami,tweezer_bottom,tweezer_top,morning_star,evening_star,'
      'three_white_soldiers,three_black_crows,rising_three,falling_three;'
      'price_action:returns,log_returns,volatility,hl_range,close_position;'
      'rsi:14;'
      'macd:12,26,9;'
      'bollinger:20,2.0;'
      'atr:14;'
      'adx:14;'
      'stoch:14,k3;'
      'ichimoku:tenkan9,kijun26,senkouB52;'
      'volume_sma:20;'
      'ma:20,50,200;'
      'trend:higher_high,lower_low,uptrend,downtrend;'
      'scaler:identity_76';
    final List<int> bytes = utf8.encode(spec);
    return crypto.sha256.convert(bytes).toString();
  }

  bool _verifyRuntimeFeatureHash(String expected) {
    try {
      final String current = _computeRuntimeFeatureHash();
      return current == expected;
    } catch (_) {
      return false;
    }
  }

  // Simple realized volatility z-score estimator over the last 60 closes (approx from features)
  // We approximate close returns as first price-action feature (returns). If unavailable, return null.
  double? _estimateVolatilityZ(List<List<double>> features) {
    try {
      if (features.isEmpty || features[0].length < 30) {
        return null;
      }
      // FullFeatureBuilder: index 25 = returns, 30 = RSI; use 25 as simple daily-ish return proxy
      final int n = features.length;
      final List<double> rets = List<double>.generate(n, (int i) => features[i][25]);

      double mean = 0.0;
      for (int i = 0; i < rets.length; i++) {
        mean += rets[i];
      }
      mean = mean / (rets.isEmpty ? 1 : rets.length);

      double variance = 0.0;
      for (int i = 0; i < rets.length; i++) {
        final double d = rets[i] - mean;
        variance += d * d;
      }
      final int denom = (rets.length > 1) ? (rets.length - 1) : 1;
      variance = variance / denom;
      final double stdev = math.sqrt(variance);

      // Use long-term typical stdev baseline (fallback)
      const double baseline = 0.01;
      if (baseline <= 0) {
        return null;
      }
      final double z = (stdev - baseline) / (baseline + 1e-12);
      return z;
    } catch (_) {
      return null;
    }
  }
}

// Global singleton
final UnifiedMLService unifiedMLService = UnifiedMLService();


