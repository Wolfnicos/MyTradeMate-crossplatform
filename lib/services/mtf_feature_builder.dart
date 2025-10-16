import 'dart:math';
import '../models/candle.dart';
import 'package:flutter/foundation.dart';

/// Builds 34-feature MTF vectors to match the Python pipeline exactly:
/// BASE_FEATS (10) on 1h + the same 10 on 15m aligned to hour (last-of-hour)
/// + the same 10 on 4h upsampled to 1h with ffill + 4 one-hot symbols (BTC, ETH, BNB, SOL)
class MtfFeatureBuilder {
  // === Public API ===
  /// Returns 60 timesteps x 34 features for the given inputs, aligned to the last 60 1h candles
  List<List<double>> buildFeatures({
    required String symbol,
    required List<Candle> base1h, // recent to oldest or oldest to recent (any order ok if closeTime sorted)
    required List<Candle> low15m,
    required List<Candle> high4h,
  }) {
    if (base1h.isEmpty) {
      throw ArgumentError('base1h empty');
    }

    // Ensure sorted by close time ascending
    base1h.sort((a, b) => a.closeTime.compareTo(b.closeTime));
    low15m.sort((a, b) => a.closeTime.compareTo(b.closeTime));
    high4h.sort((a, b) => a.closeTime.compareTo(b.closeTime));

    // Build features per timeframe
    final Map<String, List<double>> fBase = _buildBaseFeats(base1h);
    final Map<String, List<double>> fLowAligned = _buildLowFeatsAlignedToHour(low15m, base1h);
    final Map<String, List<double>> fHighUpsampled = _buildHighFeatsUpsampled(high4h, base1h);

    // Align vectors by base1h timeline; build rows for the last 60 valid hours
    final int n = base1h.length;
    final int need = 60;

    // Determine earliest index where all features are non-null-ish (SMA200, Ichimoku etc need long lookback)
    int startIdx = 0;
    // SMA200 on base needs at least 199 prior values
    startIdx = max(startIdx, _firstValidIndex([fBase['sma200']!]));
    // Ichimoku spanB 52 requires 51 prior values
    startIdx = max(startIdx, _firstValidIndex([fBase['ich_b']!]));
    // Repeat for low/high aligned
    startIdx = max(startIdx, _firstValidIndex([fLowAligned['sma200']!, fLowAligned['ich_b']!]));
    startIdx = max(startIdx, _firstValidIndex([fHighUpsampled['sma200']!, fHighUpsampled['ich_b']!]));

    if (n - startIdx < need) {
      // Not enough fully-formed rows; fallback to as many as possible but still require 60
      startIdx = max(0, n - need);
    }

    final oneHot = _oneHotSymbol(symbol);
    final List<List<double>> out = <List<double>>[];
    for (int i = n - need; i < n; i++) {
      // Build in the exact Python FEATURES order:
      // BASE_FEATS = ['ret1','rv_24','rsi','macd','ich_a','ich_b','atr','trend_up','close','volume']
      final List<double> row = <double>[
        fBase['ret1']![i], fBase['rv_24']![i], fBase['rsi']![i], fBase['macd']![i], fBase['ich_a']![i], fBase['ich_b']![i], fBase['atr']![i], fBase['trend_up']![i], fBase['close']![i], fBase['volume']![i],
        fLowAligned['ret1']![i], fLowAligned['rv_24']![i], fLowAligned['rsi']![i], fLowAligned['macd']![i], fLowAligned['ich_a']![i], fLowAligned['ich_b']![i], fLowAligned['atr']![i], fLowAligned['trend_up']![i], fLowAligned['close']![i], fLowAligned['volume']![i],
        fHighUpsampled['ret1']![i], fHighUpsampled['rv_24']![i], fHighUpsampled['rsi']![i], fHighUpsampled['macd']![i], fHighUpsampled['ich_a']![i], fHighUpsampled['ich_b']![i], fHighUpsampled['atr']![i], fHighUpsampled['trend_up']![i], fHighUpsampled['close']![i], fHighUpsampled['volume']![i],
        ...oneHot,
      ];
      out.add(_sanitize(row));
    }

    debugPrint('✅ MTFBuilder: Built ${out.length}x${out.isNotEmpty ? out.first.length : 0} features for ' + symbol);
    return out;
  }

  // === Internals ===

  int _firstValidIndex(List<List<double>> arrays) {
    final int len = arrays.first.length;
    for (int i = 0; i < len; i++) {
      bool ok = true;
      for (final a in arrays) {
        if (i >= a.length) return len; // out of bounds safeguard
        final v = a[i];
        if (!v.isFinite) { ok = false; break; }
      }
      if (ok) return i;
    }
    return len - 1;
  }

  List<double> _sanitize(List<double> v) {
    return v.map((x) => x.isFinite ? x : 0.0).toList(growable: false);
  }

  List<double> _oneHotSymbol(String s) {
    // Python training used: ['BTC/USDT','ETH/USDT','BNB/USDT','SOL/USDT']
    // Here symbols are 'BTCUSDT', ...
    final bool btc = s.toUpperCase() == 'BTCUSDT';
    final bool eth = s.toUpperCase() == 'ETHUSDT';
    final bool bnb = s.toUpperCase() == 'BNBUSDT';
    final bool sol = s.toUpperCase() == 'SOLUSDT';
    return <double>[btc ? 1.0 : 0.0, eth ? 1.0 : 0.0, bnb ? 1.0 : 0.0, sol ? 1.0 : 0.0];
  }

  Map<String, List<double>> _buildBaseFeats(List<Candle> c) {
    final int n = c.length;
    final closes = List<double>.generate(n, (i) => c[i].close);
    final highs  = List<double>.generate(n, (i) => c[i].high);
    final lows   = List<double>.generate(n, (i) => c[i].low);
    final vols   = List<double>.generate(n, (i) => c[i].volume);

    final ret1 = _logReturns(closes);
    final rv24 = _rollingStd(ret1, 24);
    final rsi  = _rsi(closes, 14);
    final macdHist = _macdHist(closes);
    final ichA = _ichimokuA(highs, lows);
    final ichB = _ichimokuB(highs, lows);
    final atr14 = _atr(highs, lows, closes, 14);
    final sma50 = _sma(closes, 50);
    final sma200 = _sma(closes, 200);
    final trendUp = List<double>.generate(n, (i) => (sma50[i].isFinite && sma200[i].isFinite && sma50[i] > sma200[i]) ? 1.0 : 0.0);

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
      'sma200': sma200, // internal for validity checks
    };
  }

  Map<String, List<double>> _buildLowFeatsAlignedToHour(List<Candle> low15m, List<Candle> base1h) {
    // Compute features on 15m series, then align to hour by taking candles where minute == 0 (last-of-hour)
    final Map<String, List<double>> fLow = _buildBaseFeats(low15m);
    final times15 = List<DateTime>.generate(low15m.length, (i) => low15m[i].closeTime);

    // Build mapping from hour close time to index in low15m (minute == 0)
    final Map<int, int> hourToIdx = <int, int>{};
    for (int i = 0; i < times15.length; i++) {
      final t = times15[i];
      if (t.minute == 0) {
        hourToIdx[t.millisecondsSinceEpoch] = i;
      }
    }

    // Now create aligned arrays with same length as base1h
    final int n = base1h.length;
    List<double> pick(List<double> arr) {
      final List<double> out = List<double>.filled(n, double.nan);
      for (int i = 0; i < n; i++) {
        final key = DateTime(base1h[i].closeTime.year, base1h[i].closeTime.month, base1h[i].closeTime.day, base1h[i].closeTime.hour).millisecondsSinceEpoch;
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

  // === Indicators used in Python pipeline ===
  List<double> _logReturns(List<double> closes) {
    final List<double> out = List<double>.filled(closes.length, 0.0);
    for (int i = 1; i < closes.length; i++) {
      final prev = closes[i - 1];
      final cur = closes[i];
      out[i] = (prev > 0.0 && cur > 0.0) ? log(cur / prev) : 0.0;
    }
    return out;
  }

  List<double> _rollingStd(List<double> v, int window) {
    final int n = v.length;
    final List<double> out = List<double>.filled(n, double.nan);
    double sum = 0.0, sum2 = 0.0;
    final List<double> q = <double>[];
    for (int i = 0; i < n; i++) {
      final x = v[i];
      q.add(x);
      sum += x; sum2 += x * x;
      if (q.length > window) {
        final xr = q.removeAt(0);
        sum -= xr; sum2 -= xr * xr;
      }
      if (q.length == window) {
        final m = sum / window;
        final varr = max(0.0, (sum2 / window) - m * m);
        out[i] = sqrt(varr);
      }
    }
    return out;
  }

  List<double> _rsi(List<double> closes, int period) {
    final int n = closes.length;
    final List<double> out = List<double>.filled(n, double.nan);
    if (n < period + 1) return out;
    double avgGain = 0.0, avgLoss = 0.0;
    for (int i = 1; i <= period; i++) {
      final ch = closes[i] - closes[i - 1];
      if (ch >= 0) avgGain += ch; else avgLoss -= ch;
    }
    avgGain /= period; avgLoss /= period;
    out[period] = _rsiFromAvg(avgGain, avgLoss);
    for (int i = period + 1; i < n; i++) {
      final ch = closes[i] - closes[i - 1];
      final g = ch > 0 ? ch : 0.0;
      final l = ch < 0 ? -ch : 0.0;
      avgGain = (avgGain * (period - 1) + g) / period;
      avgLoss = (avgLoss * (period - 1) + l) / period;
      out[i] = _rsiFromAvg(avgGain, avgLoss);
    }
    return out;
  }

  double _rsiFromAvg(double avgGain, double avgLoss) {
    if (avgLoss == 0.0) return 100.0;
    final rs = avgGain / avgLoss;
    return 100.0 - (100.0 / (1.0 + rs));
  }

  List<double> _ema(List<double> v, int period) {
    final int n = v.length;
    final List<double> out = List<double>.filled(n, double.nan);
    if (n == 0) return out;
    final double k = 2.0 / (period + 1);
    out[0] = v[0];
    for (int i = 1; i < n; i++) {
      out[i] = (v[i] - out[i - 1]) * k + out[i - 1];
    }
    return out;
  }

  List<double> _macdHist(List<double> closes) {
    final fast = _ema(closes, 12);
    final slow = _ema(closes, 26);
    final int n = closes.length;
    final List<double> macd = List<double>.filled(n, double.nan);
    for (int i = 0; i < n; i++) {
      final a = fast[i]; final b = slow[i];
      macd[i] = (a.isFinite && b.isFinite) ? (a - b) : double.nan;
    }
    final signal = _ema(macd.map((e) => e.isFinite ? e : 0.0).toList(growable: false), 9);
    final List<double> hist = List<double>.filled(n, double.nan);
    for (int i = 0; i < n; i++) {
      final m = macd[i]; final s = signal[i];
      hist[i] = (m.isFinite && s.isFinite) ? (m - s) : double.nan;
    }
    return hist;
  }

  List<double> _ichimokuA(List<double> highs, List<double> lows) {
    final conv = _midpoint(highs, lows, 9);
    final base = _midpoint(highs, lows, 26);
    final int n = highs.length;
    final List<double> out = List<double>.filled(n, double.nan);
    for (int i = 0; i < n; i++) {
      final a = conv[i]; final b = base[i];
      out[i] = (a.isFinite && b.isFinite) ? (a + b) / 2.0 : double.nan;
    }
    return out;
  }

  List<double> _ichimokuB(List<double> highs, List<double> lows) {
    return _midpoint(highs, lows, 52);
  }

  List<double> _midpoint(List<double> highs, List<double> lows, int period) {
    final int n = highs.length;
    final List<double> out = List<double>.filled(n, double.nan);
    for (int i = period - 1; i < n; i++) {
      double hh = -double.maxFinite;
      double ll = double.maxFinite;
      for (int j = i - period + 1; j <= i; j++) {
        hh = max(hh, highs[j]);
        ll = min(ll, lows[j]);
      }
      out[i] = (hh + ll) / 2.0;
    }
    return out;
  }

  List<double> _atr(List<double> highs, List<double> lows, List<double> closes, int period) {
    final int n = closes.length;
    final List<double> tr = List<double>.filled(n, double.nan);
    tr[0] = highs[0] - lows[0];
    for (int i = 1; i < n; i++) {
      final hl = highs[i] - lows[i];
      final hc = (highs[i] - closes[i - 1]).abs();
      final lc = (lows[i] - closes[i - 1]).abs();
      tr[i] = max(hl, max(hc, lc));
    }
    return _ema(tr.map((e) => e.isFinite ? e : 0.0).toList(growable: false), period);
  }

  List<double> _sma(List<double> v, int period) {
    final int n = v.length;
    final List<double> out = List<double>.filled(n, double.nan);
    double sum = 0.0;
    for (int i = 0; i < n; i++) {
      sum += v[i];
      if (i >= period) sum -= v[i - period];
      if (i >= period - 1) out[i] = sum / period;
    }
    return out;
  }
}


