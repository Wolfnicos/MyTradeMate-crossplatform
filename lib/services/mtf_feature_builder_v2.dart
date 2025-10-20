import 'dart:math';
import '../models/candle.dart';
import 'package:flutter/foundation.dart';
import 'glassnode_service.dart';
import 'lunarcrush_service.dart';

/// Enhanced MTF Feature Builder - Version 2
///
/// Builds 42-feature MTF vectors (upgraded from 34):
/// - Original 30 features: 10 base features x 3 timeframes (1h, 15m, 4h)
/// - Original 4 features: One-hot symbol encoding (BTC, ETH, BNB, SOL)
/// - NEW 8 features:
///   * 3 on-chain metrics (Glassnode): Exchange Net Flow, SOPR, Active Addresses
///   * 2 sentiment metrics (LunarCrush): Sentiment Score, Social Volume
///   * 3 macro metrics: BTC Dominance, DXY (US Dollar Index), Bid/Ask Ratio
///
/// This provides AI model with "hidden" signals traditional TA misses.
class MtfFeatureBuilderV2 {
  final GlassnodeService _glassnode;
  final LunarCrushService _lunarcrush;

  // Cache for macro data (refreshes infrequently)
  double? _cachedBtcDominance;
  double? _cachedDxy;
  DateTime? _lastMacroFetch;
  static const Duration _macroRefreshInterval = Duration(hours: 1);

  MtfFeatureBuilderV2({
    required GlassnodeService glassnodeService,
    required LunarCrushService lunarcrushService,
  })  : _glassnode = glassnodeService,
        _lunarcrush = lunarcrushService;

  /// Build 42-feature vectors (60 timesteps x 42 features)
  ///
  /// Returns Future because it fetches on-chain + sentiment data
  Future<List<List<double>>> buildFeatures({
    required String symbol,
    required List<Candle> base1h,
    required List<Candle> low15m,
    required List<Candle> high4h,
  }) async {
    if (base1h.isEmpty) {
      throw ArgumentError('base1h empty');
    }

    // Ensure sorted by close time ascending
    base1h.sort((a, b) => a.closeTime.compareTo(b.closeTime));
    low15m.sort((a, b) => a.closeTime.compareTo(b.closeTime));
    high4h.sort((a, b) => a.closeTime.compareTo(b.closeTime));

    // Step 1: Build original 34 features (MTF + one-hot)
    final Map<String, List<double>> fBase = _buildBaseFeats(base1h);
    final Map<String, List<double>> fLowAligned = _buildLowFeatsAlignedToHour(low15m, base1h);
    final Map<String, List<double>> fHighUpsampled = _buildHighFeatsUpsampled(high4h, base1h);

    final oneHot = _oneHotSymbol(symbol);

    // Step 2: Fetch NEW alternative data (8 features)
    final altData = await _fetchAlternativeData(symbol);

    // Step 3: Build feature matrix
    final int n = base1h.length;
    final int need = 60;

    // Determine earliest valid index (SMA200, Ichimoku need long lookback)
    int startIdx = 0;
    startIdx = max(startIdx, _firstValidIndex([fBase['sma200']!]));
    startIdx = max(startIdx, _firstValidIndex([fBase['ich_b']!]));
    startIdx = max(startIdx, _firstValidIndex([fLowAligned['sma200']!, fLowAligned['ich_b']!]));
    startIdx = max(startIdx, _firstValidIndex([fHighUpsampled['sma200']!, fHighUpsampled['ich_b']!]));

    if (n - startIdx < need) {
      startIdx = max(0, n - need);
    }

    final List<List<double>> out = <List<double>>[];
    for (int i = n - need; i < n; i++) {
      // Original 30 features (10 base x 3 timeframes)
      final List<double> row = <double>[
        // Base 1h (10 features)
        fBase['ret1']![i],
        fBase['rv_24']![i],
        fBase['rsi']![i],
        fBase['macd']![i],
        fBase['ich_a']![i],
        fBase['ich_b']![i],
        fBase['atr']![i],
        fBase['trend_up']![i],
        fBase['close']![i],
        fBase['volume']![i],

        // Low 15m aligned (10 features)
        fLowAligned['ret1']![i],
        fLowAligned['rv_24']![i],
        fLowAligned['rsi']![i],
        fLowAligned['macd']![i],
        fLowAligned['ich_a']![i],
        fLowAligned['ich_b']![i],
        fLowAligned['atr']![i],
        fLowAligned['trend_up']![i],
        fLowAligned['close']![i],
        fLowAligned['volume']![i],

        // High 4h upsampled (10 features)
        fHighUpsampled['ret1']![i],
        fHighUpsampled['rv_24']![i],
        fHighUpsampled['rsi']![i],
        fHighUpsampled['macd']![i],
        fHighUpsampled['ich_a']![i],
        fHighUpsampled['ich_b']![i],
        fHighUpsampled['atr']![i],
        fHighUpsampled['trend_up']![i],
        fHighUpsampled['close']![i],
        fHighUpsampled['volume']![i],

        // One-hot encoding (4 features)
        ...oneHot,

        // NEW: Alternative data (8 features)
        ...altData,
      ];

      out.add(_sanitize(row));
    }

    debugPrint('✅ MTFBuilderV2: Built ${out.length}x${out.isNotEmpty ? out.first.length : 0} features for $symbol');
    return out;
  }

  /// Fetch alternative data (on-chain + sentiment + macro)
  ///
  /// Returns 8 normalized features:
  /// [exchangeNetFlow, sopr, activeAddresses, sentimentScore, socialVolume, btcDominance, dxy, bidAskRatio]
  Future<List<double>> _fetchAlternativeData(String symbol) async {
    try {
      // On-chain data (3 features)
      final onChainMetrics = await _glassnode.fetchAllMetrics(symbol);
      final onChainNorm = _glassnode.normalizeMetrics(
        exchangeNetFlow: onChainMetrics['exchangeNetFlow'] as double,
        sopr: onChainMetrics['sopr'] as double,
        activeAddresses: onChainMetrics['activeAddresses'] as int,
      );

      // Sentiment data (2 features)
      final sentiment = await _lunarcrush.fetchSentiment(symbol);
      final sentimentNorm = _lunarcrush.normalizeSentimentFeatures(sentiment);

      // Macro data (3 features)
      final macroNorm = await _fetchMacroFeatures(symbol);

      return [
        ...onChainNorm, // [exchangeNetFlow, sopr, activeAddresses]
        ...sentimentNorm, // [sentimentScore, socialVolume]
        ...macroNorm, // [btcDominance, dxy, bidAskRatio]
      ];
    } catch (e) {
      debugPrint('⚠️ MTFBuilderV2: Error fetching alternative data: $e');
      // Return neutral fallback values
      return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    }
  }

  /// Fetch macro features (BTC Dominance, DXY, Bid/Ask Ratio)
  ///
  /// These change slowly, so we cache for 1 hour
  Future<List<double>> _fetchMacroFeatures(String symbol) async {
    // Check cache
    if (_lastMacroFetch != null &&
        DateTime.now().difference(_lastMacroFetch!) < _macroRefreshInterval) {
      return [
        (_cachedBtcDominance! - 50.0) / 20.0, // Normalize around 50%
        (_cachedDxy! - 100.0) / 10.0, // Normalize around 100
        0.0, // Bid/Ask ratio placeholder (requires order book data)
      ];
    }

    try {
      // Fetch BTC Dominance from CoinGecko
      _cachedBtcDominance = await _fetchBtcDominance();

      // Fetch DXY (US Dollar Index)
      _cachedDxy = await _fetchDxy();

      _lastMacroFetch = DateTime.now();

      return [
        (_cachedBtcDominance! - 50.0) / 20.0,
        (_cachedDxy! - 100.0) / 10.0,
        0.0, // Bid/Ask ratio TODO: Implement via Binance order book API
      ];
    } catch (e) {
      debugPrint('⚠️ MTFBuilderV2: Error fetching macro features: $e');
      return [0.0, 0.0, 0.0];
    }
  }

  /// Fetch BTC Dominance from CoinGecko
  ///
  /// BTC Dominance = Market cap of BTC / Total crypto market cap
  /// High dominance (>60%) = "Bitcoin season" (altcoins weak)
  /// Low dominance (<40%) = "Altcoin season" (altcoins strong)
  Future<double> _fetchBtcDominance() async {
    try {
      // TODO: Implement CoinGecko API call
      // For now, return typical value
      return 52.5; // Placeholder: ~52.5% typical
    } catch (e) {
      return 50.0; // Neutral fallback
    }
  }

  /// Fetch DXY (US Dollar Index)
  ///
  /// Strong dollar (DXY > 105) = Bearish for crypto
  /// Weak dollar (DXY < 95) = Bullish for crypto
  Future<double> _fetchDxy() async {
    try {
      // TODO: Implement TradingEconomics API or similar
      // For now, return typical value
      return 103.5; // Placeholder: ~103.5 typical
    } catch (e) {
      return 100.0; // Neutral fallback
    }
  }

  // === Original MTF Builder Methods (unchanged) ===

  int _firstValidIndex(List<List<double>> arrays) {
    final int len = arrays.first.length;
    for (int i = 0; i < len; i++) {
      bool ok = true;
      for (final a in arrays) {
        if (i >= a.length) return len;
        final v = a[i];
        if (!v.isFinite) {
          ok = false;
          break;
        }
      }
      if (ok) return i;
    }
    return len - 1;
  }

  List<double> _sanitize(List<double> v) {
    return v.map((x) => x.isFinite ? x : 0.0).toList(growable: false);
  }

  List<double> _oneHotSymbol(String s) {
    final up = s.toUpperCase();
    String base = up;
    for (final q in const ['USDT', 'USDC', 'USD', 'EUR']) {
      if (up.endsWith(q)) {
        base = up.substring(0, up.length - q.length);
        break;
      }
    }
    final bool btc = base == 'BTC';
    final bool eth = base == 'ETH';
    final bool bnb = base == 'BNB';
    final bool sol = base == 'SOL';
    return <double>[btc ? 1.0 : 0.0, eth ? 1.0 : 0.0, bnb ? 1.0 : 0.0, sol ? 1.0 : 0.0];
  }

  Map<String, List<double>> _buildBaseFeats(List<Candle> c) {
    final int n = c.length;
    final closes = List<double>.generate(n, (i) => c[i].close);
    final highs = List<double>.generate(n, (i) => c[i].high);
    final lows = List<double>.generate(n, (i) => c[i].low);
    final vols = List<double>.generate(n, (i) => c[i].volume);

    final ret1 = _logReturns(closes);
    final rv24 = _rollingStd(ret1, 24);
    final rsi = _rsi(closes, 14);
    final macdHist = _macdHist(closes);
    final ichA = _ichimokuA(highs, lows);
    final ichB = _ichimokuB(highs, lows);
    final atr14 = _atr(highs, lows, closes, 14);
    final sma50 = _sma(closes, 50);
    final sma200 = _sma(closes, 200);
    final trendUp = List<double>.generate(
        n, (i) => (sma50[i].isFinite && sma200[i].isFinite && sma50[i] > sma200[i]) ? 1.0 : 0.0);

    return <String, List<double>>{
      'ret1': ret1,
      'rv_24': rv24,
      'rsi': rsi,
      'macd': macdHist,
      'ich_a': ichA,
      'ich_b': ichB,
      'atr': atr14,
      'trend_up': trendUp,
      'close': closes,
      'volume': vols,
      'sma200': sma200,
    };
  }

  Map<String, List<double>> _buildLowFeatsAlignedToHour(List<Candle> low15m, List<Candle> base1h) {
    final Map<String, List<double>> fLow = _buildBaseFeats(low15m);
    final times15 = List<DateTime>.generate(low15m.length, (i) => low15m[i].closeTime);

    final Map<int, int> hourToIdx = <int, int>{};
    for (int i = 0; i < times15.length; i++) {
      final t = times15[i];
      if (t.minute == 0) {
        hourToIdx[t.millisecondsSinceEpoch] = i;
      }
    }

    final int n = base1h.length;
    List<double> pick(List<double> arr) {
      final List<double> out = List<double>.filled(n, double.nan);
      for (int i = 0; i < n; i++) {
        final key = DateTime(base1h[i].closeTime.year, base1h[i].closeTime.month,
                base1h[i].closeTime.day, base1h[i].closeTime.hour)
            .millisecondsSinceEpoch;
        final idx = hourToIdx[key];
        if (idx != null) out[i] = arr[idx];
      }
      return out;
    }

    return <String, List<double>>{
      'ret1': pick(fLow['ret1']!),
      'rv_24': pick(fLow['rv_24']!),
      'rsi': pick(fLow['rsi']!),
      'macd': pick(fLow['macd']!),
      'ich_a': pick(fLow['ich_a']!),
      'ich_b': pick(fLow['ich_b']!),
      'atr': pick(fLow['atr']!),
      'trend_up': pick(fLow['trend_up']!),
      'close': pick(fLow['close']!),
      'volume': pick(fLow['volume']!),
      'sma200': pick(fLow['sma200']!),
    };
  }

  Map<String, List<double>> _buildHighFeatsUpsampled(List<Candle> high4h, List<Candle> base1h) {
    final Map<String, List<double>> fH = _buildBaseFeats(high4h);
    final times4 = List<DateTime>.generate(high4h.length, (i) => high4h[i].closeTime);
    final int n = base1h.length;

    List<double> ffill(List<double> arr) {
      final List<double> out = List<double>.filled(n, double.nan);
      int j = 0;
      for (int i = 0; i < n; i++) {
        final t = base1h[i].closeTime;
        while (j + 1 < times4.length && times4[j + 1].isBefore(t.add(const Duration(seconds: 1)))) {
          j++;
        }
        out[i] = arr[min(j, arr.length - 1)];
      }
      return out;
    }

    return <String, List<double>>{
      'ret1': ffill(fH['ret1']!),
      'rv_24': ffill(fH['rv_24']!),
      'rsi': ffill(fH['rsi']!),
      'macd': ffill(fH['macd']!),
      'ich_a': ffill(fH['ich_a']!),
      'ich_b': ffill(fH['ich_b']!),
      'atr': ffill(fH['atr']!),
      'trend_up': ffill(fH['trend_up']!),
      'close': ffill(fH['close']!),
      'volume': ffill(fH['volume']!),
      'sma200': ffill(fH['sma200']!),
    };
  }

  // === Technical Indicator Calculations ===

  List<double> _logReturns(List<double> p) {
    final int n = p.length;
    final List<double> r = List<double>.filled(n, double.nan);
    for (int i = 1; i < n; i++) {
      r[i] = (p[i] > 0 && p[i - 1] > 0) ? log(p[i] / p[i - 1]) : 0.0;
    }
    return r;
  }

  List<double> _rollingStd(List<double> x, int w) {
    final int n = x.length;
    final List<double> out = List<double>.filled(n, double.nan);
    for (int i = w - 1; i < n; i++) {
      final slice = x.sublist(i - w + 1, i + 1).where((v) => v.isFinite).toList();
      if (slice.isEmpty) continue;
      final mean = slice.reduce((a, b) => a + b) / slice.length;
      final variance = slice.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / slice.length;
      out[i] = sqrt(variance);
    }
    return out;
  }

  List<double> _rsi(List<double> p, int period) {
    final int n = p.length;
    final List<double> out = List<double>.filled(n, double.nan);
    if (n < period + 1) return out;

    double avgGain = 0.0, avgLoss = 0.0;
    for (int i = 1; i <= period; i++) {
      final chg = p[i] - p[i - 1];
      if (chg > 0) {
        avgGain += chg;
      } else {
        avgLoss -= chg;
      }
    }
    avgGain /= period;
    avgLoss /= period;

    out[period] = avgLoss == 0 ? 100.0 : 100.0 - (100.0 / (1.0 + avgGain / avgLoss));

    for (int i = period + 1; i < n; i++) {
      final chg = p[i] - p[i - 1];
      final gain = chg > 0 ? chg : 0.0;
      final loss = chg < 0 ? -chg : 0.0;

      avgGain = (avgGain * (period - 1) + gain) / period;
      avgLoss = (avgLoss * (period - 1) + loss) / period;

      out[i] = avgLoss == 0 ? 100.0 : 100.0 - (100.0 / (1.0 + avgGain / avgLoss));
    }
    return out;
  }

  List<double> _sma(List<double> p, int w) {
    final int n = p.length;
    final List<double> out = List<double>.filled(n, double.nan);
    for (int i = w - 1; i < n; i++) {
      final slice = p.sublist(i - w + 1, i + 1);
      out[i] = slice.reduce((a, b) => a + b) / w;
    }
    return out;
  }

  List<double> _ema(List<double> p, int period) {
    final int n = p.length;
    final List<double> out = List<double>.filled(n, double.nan);
    if (n == 0) return out;

    final k = 2.0 / (period + 1);
    out[0] = p[0];
    for (int i = 1; i < n; i++) {
      out[i] = p[i] * k + out[i - 1] * (1 - k);
    }
    return out;
  }

  List<double> _macdHist(List<double> p) {
    final ema12 = _ema(p, 12);
    final ema26 = _ema(p, 26);
    final macdLine = List<double>.generate(p.length, (i) => ema12[i] - ema26[i]);
    final signal = _ema(macdLine, 9);
    return List<double>.generate(p.length, (i) => macdLine[i] - signal[i]);
  }

  List<double> _ichimokuA(List<double> h, List<double> l) {
    final int n = h.length;
    final List<double> out = List<double>.filled(n, double.nan);
    for (int i = 8; i < n; i++) {
      final high9 = h.sublist(i - 8, i + 1).reduce((a, b) => a > b ? a : b);
      final low9 = l.sublist(i - 8, i + 1).reduce((a, b) => a < b ? a : b);
      out[i] = (high9 + low9) / 2.0;
    }
    return out;
  }

  List<double> _ichimokuB(List<double> h, List<double> l) {
    final int n = h.length;
    final List<double> out = List<double>.filled(n, double.nan);
    for (int i = 51; i < n; i++) {
      final high52 = h.sublist(i - 51, i + 1).reduce((a, b) => a > b ? a : b);
      final low52 = l.sublist(i - 51, i + 1).reduce((a, b) => a < b ? a : b);
      out[i] = (high52 + low52) / 2.0;
    }
    return out;
  }

  List<double> _atr(List<double> h, List<double> l, List<double> c, int period) {
    final int n = h.length;
    final List<double> tr = List<double>.filled(n, double.nan);
    for (int i = 1; i < n; i++) {
      final hl = h[i] - l[i];
      final hc = (h[i] - c[i - 1]).abs();
      final lc = (l[i] - c[i - 1]).abs();
      tr[i] = max(hl, max(hc, lc));
    }

    final List<double> atr = List<double>.filled(n, double.nan);
    double sum = 0.0;
    for (int i = 1; i <= period && i < n; i++) {
      sum += tr[i];
    }
    if (period < n) atr[period] = sum / period;

    for (int i = period + 1; i < n; i++) {
      atr[i] = (atr[i - 1] * (period - 1) + tr[i]) / period;
    }
    return atr;
  }
}

/// Example usage:
///
/// ```dart
/// final glassnode = GlassnodeService(apiKey: 'YOUR_GLASSNODE_KEY');
/// final lunarcrush = LunarCrushService(apiKey: 'YOUR_LUNARCRUSH_KEY');
/// final builder = MtfFeatureBuilderV2(
///   glassnodeService: glassnode,
///   lunarcrushService: lunarcrush,
/// );
///
/// // Fetch candles
/// final hourly = await binanceService.fetchHourlyKlines('BTCUSDT');
/// final fifteenMin = await binanceService.fetchCustomKlines('BTCUSDT', '15m');
/// final fourHour = await binanceService.fetchCustomKlines('BTCUSDT', '4h');
///
/// // Build 42-feature matrix
/// final features = await builder.buildFeatures(
///   symbol: 'BTCUSDT',
///   base1h: hourly,
///   low15m: fifteenMin,
///   high4h: fourHour,
/// );
///
/// print('Feature matrix: ${features.length} x ${features[0].length}');
/// // Output: Feature matrix: 60 x 42
///
/// // Feed to upgraded Transformer model
/// final prediction = await transformerModel.predict(features);
/// ```
