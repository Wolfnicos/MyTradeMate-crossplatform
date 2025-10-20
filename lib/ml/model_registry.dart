import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Schema v1 Model Registry loader and selector
class ModelRegistryV1 {
  final String schema;
  final List<String> labelOrder; // e.g., ["SELL","HOLD","BUY"]
  final Map<String, String> tfMap; // e.g., {"1w":"7d","4h":"1h"}
  final Map<String, double> defaultConfThresholds; // per timeframe
  final FallbackSpec fallback;
  final String featureHash;
  final List<ModelEntry> models;
  final RiskSpec? risk; // optional risk tuning

  ModelRegistryV1({
    required this.schema,
    required this.labelOrder,
    required this.tfMap,
    required this.defaultConfThresholds,
    required this.fallback,
    required this.featureHash,
    required this.models,
    this.risk,
  });

  static Future<ModelRegistryV1> loadFromAssets({String path = 'assets/models/model_registry.json'}) async {
    final String raw = await rootBundle.loadString(path);
    final Map<String, dynamic> m = json.decode(raw) as Map<String, dynamic>;
    return ModelRegistryV1.fromJson(m);
  }

  factory ModelRegistryV1.fromJson(Map<String, dynamic> json) {
    final modelsJson = (json['models'] as List<dynamic>? ?? <dynamic>[]).cast<Map<String, dynamic>>();
    return ModelRegistryV1(
      schema: (json['schema'] ?? '').toString(),
      labelOrder: (json['label_order'] as List<dynamic>? ?? const <dynamic>[]).map((e) => e.toString()).toList(growable: false),
      tfMap: Map<String, String>.from((json['tf_map'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? const <String, String>{}),
      defaultConfThresholds: Map<String, double>.from((json['default_conf_thresholds'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) ?? const <String, double>{}),
      fallback: FallbackSpec.fromJson(json['fallback'] as Map<String, dynamic>? ?? const <String, dynamic>{}),
      featureHash: (json['feature_hash'] ?? '').toString(),
      models: modelsJson.map(ModelEntry.fromJson).toList(growable: false),
      risk: json.containsKey('risk') && json['risk'] is Map<String, dynamic> ? RiskSpec.fromJson(json['risk'] as Map<String, dynamic>) : null,
    );
  }

  /// Normalize incoming timeframe using tf_map
  String normalizeTimeframe(String tf) {
    final String key = tf.toLowerCase();
    return tfMap[key] ?? key;
  }

  /// Returns default confidence threshold for timeframe, or 0.0 if not found
  double thresholdForTimeframe(String tf) {
    final String key = tf.toLowerCase();
    return defaultConfThresholds[key] ?? 0.0;
  }

  /// Select models matching coin and timeframe (after tf mapping). Includes general (coin='*').
  List<ModelEntry> selectModels({required String coinUpper, required String timeframe}) {
    final String tfNorm = normalizeTimeframe(timeframe);
    return models.where((m) => m.tf.toLowerCase() == tfNorm.toLowerCase() && (m.coin == '*' || m.coin.toUpperCase() == coinUpper)).toList(growable: false);
  }
}

class RiskSpec {
  final double volZLimit; // e.g., 1.5 = high volatility
  final double volThreshIncrement; // e.g., +0.03 threshold when high vol

  const RiskSpec({required this.volZLimit, required this.volThreshIncrement});

  factory RiskSpec.fromJson(Map<String, dynamic> json) {
    return RiskSpec(
      volZLimit: (json['vol_z_limit'] as num?)?.toDouble() ?? 0.0,
      volThreshIncrement: (json['vol_thresh_increment'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class FallbackSpec {
  final String action; // SELL/HOLD/BUY
  final double confidence;
  final String reason;

  const FallbackSpec({required this.action, required this.confidence, required this.reason});

  factory FallbackSpec.fromJson(Map<String, dynamic> json) {
    return FallbackSpec(
      action: (json['action'] ?? 'HOLD').toString(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.33,
      reason: (json['reason'] ?? 'fallback').toString(),
    );
  }
}

class ModelEntry {
  final String id; // e.g., btc_1h, general_1h
  final String coin; // e.g., BTC or *
  final String tf; // e.g., 1h
  final String version;
  final double accVal;
  final double mcc;
  final double sharpe;
  final double ece;
  final double temp; // temperature scaling T
  final List<double> bias; // optional per-class bias on logits, len==3
  final double w; // ensemble weight
  final List<String> labels; // label order exposed by this model

  const ModelEntry({
    required this.id,
    required this.coin,
    required this.tf,
    required this.version,
    required this.accVal,
    required this.mcc,
    required this.sharpe,
    required this.ece,
    required this.temp,
    required this.bias,
    required this.w,
    required this.labels,
  });

  factory ModelEntry.fromJson(Map<String, dynamic> json) {
    final List<dynamic> biasRaw = (json['bias'] as List<dynamic>? ?? const <dynamic>[0.0, 0.0, 0.0]);
    return ModelEntry(
      id: (json['id'] ?? '').toString(),
      coin: (json['coin'] ?? '*').toString(),
      tf: (json['tf'] ?? '').toString(),
      version: (json['version'] ?? '').toString(),
      accVal: (json['acc_val'] as num?)?.toDouble() ?? 0.0,
      mcc: (json['mcc'] as num?)?.toDouble() ?? 0.0,
      sharpe: (json['sharpe'] as num?)?.toDouble() ?? 0.0,
      ece: (json['ece'] as num?)?.toDouble() ?? 0.0,
      temp: (json['temp'] as num?)?.toDouble() ?? 1.0,
      bias: biasRaw.map((e) => (e as num).toDouble()).toList(growable: false),
      w: (json['w'] as num?)?.toDouble() ?? 1.0,
      labels: (json['labels'] as List<dynamic>? ?? const <dynamic>[]).map((e) => e.toString()).toList(growable: false),
    );
  }
}

class UnifiedDecisionResult {
  final String action; // SELL/HOLD/BUY
  final double confidence; // max prob
  final List<double> probabilities; // [SELL, HOLD, BUY]
  final String timeframe; // normalized timeframe used
  final List<String> usedModelIds;
  final bool featureHashOk;
  final String reason; // 'ok' or fallback/gating reason

  const UnifiedDecisionResult({
    required this.action,
    required this.confidence,
    required this.probabilities,
    required this.timeframe,
    required this.usedModelIds,
    required this.featureHashOk,
    required this.reason,
  });
}


