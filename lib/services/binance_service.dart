import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

import '../models/candle.dart';
// import '../services/technical_indicator_calculator.dart';
import '../services/full_feature_builder.dart';

/// Result wrapper for feature extraction
class FeatureResult {
  final bool ok;
  final List<List<double>>? features;
  final String? error;
  final int? need;
  final int? got;

  const FeatureResult._({
    required this.ok,
    this.features,
    this.error,
    this.need,
    this.got,
  });

  factory FeatureResult.ok(List<List<double>> features) {
    return FeatureResult._(ok: true, features: features);
  }

  factory FeatureResult.error(String error, {int? need, int? got}) {
    return FeatureResult._(ok: false, error: error, need: need, got: got);
  }
}

/// Result wrapper for features + ATR (for Phase 3 volatility-based weights)
class FeaturesWithATR {
  final List<List<double>> features;
  final double atr;

  const FeaturesWithATR({required this.features, required this.atr});
}

class BinanceService {
  static const String _baseHost = 'api.binance.com'; // Only LIVE mode
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Singleton pattern
  static final BinanceService _instance = BinanceService._internal();
  factory BinanceService() => _instance;
  BinanceService._internal();

  String? _apiKey;
  String? _apiSecret;

  String? get apiKey => _apiKey;
  String? get apiSecret => _apiSecret;
  bool get hasCredentials => (_apiKey != null && _apiKey!.isNotEmpty && _apiSecret != null && _apiSecret!.isNotEmpty);

  /// Load API credentials from secure storage
  Future<void> loadCredentials() async {
    try {
      _apiKey = await _secureStorage.read(key: 'binance_api_key');
      _apiSecret = await _secureStorage.read(key: 'binance_api_secret');
    } catch (e) {
      debugPrint('Error loading credentials: $e');
    }
  }

  /// Save API credentials to secure storage
  Future<void> saveCredentials(String apiKey, String apiSecret) async {
    await _secureStorage.write(key: 'binance_api_key', value: apiKey);
    await _secureStorage.write(key: 'binance_api_secret', value: apiSecret);
    _apiKey = apiKey;
    _apiSecret = apiSecret;
  }

  /// Clear stored credentials
  Future<void> clearCredentials() async {
    await _secureStorage.delete(key: 'binance_api_key');
    await _secureStorage.delete(key: 'binance_api_secret');
    _apiKey = null;
    _apiSecret = null;
  }

  /// Test API connection
  Future<bool> testConnection() async {
    if (_apiKey == null || _apiSecret == null) {
      throw Exception('API credentials not set');
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final queryString = 'timestamp=$timestamp';
      final signature = _generateSignature(queryString);

      final uri = Uri.https(_baseHost, '/api/v3/account', {
        'timestamp': timestamp.toString(),
        'signature': signature,
      });

      final response = await http.get(
        uri,
        headers: {'X-MBX-APIKEY': _apiKey!},
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Connection test failed: $e');
      return false;
    }
  }

  /// Get account balances
  /// Returns Map<String, double> with asset symbol as key and free balance as value
  Future<Map<String, double>> getAccountBalances() async {
    if (_apiKey == null || _apiSecret == null) {
      throw Exception('API credentials not set');
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final queryString = 'timestamp=$timestamp';
      final signature = _generateSignature(queryString);

      final uri = Uri.https(_baseHost, '/api/v3/account', {
        'timestamp': timestamp.toString(),
        'signature': signature,
      });

      final response = await http.get(
        uri,
        headers: {'X-MBX-APIKEY': _apiKey!},
      );

      if (response.statusCode != 200) {
        throw Exception('Binance account error ${response.statusCode}: ${response.body}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final balances = data['balances'] as List<dynamic>;

      final Map<String, double> result = {};
      for (final balance in balances) {
        final asset = balance['asset'] as String;
        final free = double.tryParse(balance['free'].toString()) ?? 0.0;
        final locked = double.tryParse(balance['locked'].toString()) ?? 0.0;
        final total = free + locked;
        if (total > 0) {
          result[asset] = total;
        }
      }

      return result;
    } catch (e) {
      debugPrint('Failed to fetch account balances: $e');
      rethrow;
    }
  }

  String _generateSignature(String queryString) {
    final key = utf8.encode(_apiSecret!);
    final bytes = utf8.encode(queryString);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return digest.toString();
  }

  /// Place a MARKET order (BUY/SELL) on spot. Uses testnet when selected in settings.
  /// Either [quantity] (base units) or [quoteOrderQty] (quote currency) must be provided.
  Future<Map<String, dynamic>> placeMarketOrder({
    required String symbol,
    required String side, // 'BUY' | 'SELL'
    double? quantity,
    double? quoteOrderQty,
    int recvWindowMs = 5000,
  }) async {
    if (_apiKey == null || _apiSecret == null) {
      throw Exception('API credentials not set');
    }
    if ((quantity == null || quantity <= 0) && (quoteOrderQty == null || quoteOrderQty <= 0)) {
      throw Exception('Provide quantity (base) or quoteOrderQty (>0)');
    }

    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    final Map<String, String> params = <String, String>{
      'symbol': symbol,
      'side': side.toUpperCase(),
      'type': 'MARKET',
      'newOrderRespType': 'RESULT',
      'recvWindow': recvWindowMs.toString(),
      'timestamp': timestamp.toString(),
    };
    if (quantity != null && quantity > 0) {
      params['quantity'] = quantity.toString();
    } else if (quoteOrderQty != null && quoteOrderQty > 0) {
      params['quoteOrderQty'] = quoteOrderQty.toString();
    }

    // Build query string for signature
    final String queryString = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final String signature = _generateSignature(queryString);

    final uri = Uri.https(_baseHost, '/api/v3/order');
    final String body = '$queryString&signature=$signature';
    final res = await http.post(
      uri,
      headers: <String, String>{
        'X-MBX-APIKEY': _apiKey!,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: body,
    );
    if (res.statusCode != 200) {
      throw Exception('Binance order error ${res.statusCode}: ${res.body}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  /// Fetch open spot orders (signed). If [symbol] provided, filters by symbol.
  Future<List<Map<String, dynamic>>> fetchOpenOrders({String? symbol, int recvWindowMs = 5000}) async {
    if (_apiKey == null || _apiSecret == null) {
      throw Exception('API credentials not set');
    }
    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    final Map<String, String> params = <String, String>{
      'timestamp': timestamp.toString(),
      'recvWindow': recvWindowMs.toString(),
    };
    if (symbol != null && symbol.isNotEmpty) params['symbol'] = symbol;

    final String queryString = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final String signature = _generateSignature(queryString);

    final uri = Uri.https(_baseHost, '/api/v3/openOrders', {
      ...params,
      'signature': signature,
    });

    final res = await http.get(uri, headers: {'X-MBX-APIKEY': _apiKey!});
    if (res.statusCode != 200) {
      throw Exception('Binance openOrders error ${res.statusCode}: ${res.body}');
    }
    final List<dynamic> data = json.decode(res.body) as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  /// Cancel an open order by orderId or origClientOrderId
  Future<Map<String, dynamic>> cancelOrder({
    required String symbol,
    int? orderId,
    String? origClientOrderId,
    int recvWindowMs = 5000,
  }) async {
    if (_apiKey == null || _apiSecret == null) {
      throw Exception('API credentials not set');
    }
    if (orderId == null && (origClientOrderId == null || origClientOrderId.isEmpty)) {
      throw Exception('Provide orderId or origClientOrderId');
    }
    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    final Map<String, String> params = <String, String>{
      'symbol': symbol,
      'recvWindow': recvWindowMs.toString(),
      'timestamp': timestamp.toString(),
    };
    if (orderId != null) params['orderId'] = orderId.toString();
    if (origClientOrderId != null && origClientOrderId.isNotEmpty) params['origClientOrderId'] = origClientOrderId;

    final String queryString = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final String signature = _generateSignature(queryString);

    final uri = Uri.https(_baseHost, '/api/v3/order', {
      ...params,
      'signature': signature,
    });
    final res = await http.delete(uri, headers: {'X-MBX-APIKEY': _apiKey!});
    if (res.statusCode != 200) {
      throw Exception('Binance cancel error ${res.statusCode}: ${res.body}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  /// Place an OCO order (One-Cancels-the-Other) for spot.
  /// Typical use: side=SELL for take-profit + stop-loss after a BUY.
  Future<Map<String, dynamic>> placeOcoOrder({
    required String symbol,
    required String side, // 'BUY' | 'SELL'
    required double quantity,
    required double price, // take-profit price
    required double stopPrice,
    double? stopLimitPrice,
    String stopLimitTimeInForce = 'GTC',
    int recvWindowMs = 5000,
  }) async {
    if (_apiKey == null || _apiSecret == null) {
      throw Exception('API credentials not set');
    }
    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    final Map<String, String> params = <String, String>{
      'symbol': symbol,
      'side': side.toUpperCase(),
      'quantity': quantity.toString(),
      'price': price.toString(),
      'stopPrice': stopPrice.toString(),
      'recvWindow': recvWindowMs.toString(),
      'timestamp': timestamp.toString(),
    };
    if (stopLimitPrice != null) {
      params['stopLimitPrice'] = stopLimitPrice.toString();
      params['stopLimitTimeInForce'] = stopLimitTimeInForce;
    }

    final String queryString = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final String signature = _generateSignature(queryString);

    final uri = Uri.https(_baseHost, '/api/v3/order/oco');
    final String body = '$queryString&signature=$signature';
    final res = await http.post(
      uri,
      headers: <String, String>{
        'X-MBX-APIKEY': _apiKey!,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: body,
    );
    if (res.statusCode != 200) {
      throw Exception('Binance OCO error ${res.statusCode}: ${res.body}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  /// Fetches klines (OHLCV) for a spot symbol with configurable interval
  /// Returns up to [limit] candles between [start] and [end].
  Future<List<Candle>> fetchKlines(
    String symbol, {
    String interval = '1h',
    DateTime? start,
    DateTime? end,
    int limit = 1000,
  }) async {
    final Map<String, String> query = {
      'symbol': symbol,
      'interval': interval,
      'limit': limit.toString(),
    };
    if (start != null) query['startTime'] = start.millisecondsSinceEpoch.toString();
    if (end != null) query['endTime'] = end.millisecondsSinceEpoch.toString();

    final uri = Uri.https(_baseHost, '/api/v3/klines', query);
    final http.Response res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Binance klines error ${res.statusCode}: ${res.body}');
    }
    final List<dynamic> raw = json.decode(res.body) as List<dynamic>;
    return raw.map((e) => _parseKlineArray(e as List<dynamic>)).toList();
  }

  /// Fetches daily klines (OHLCV) for a spot symbol like 'BTCUSDT'.
  Future<List<Candle>> fetchDailyKlines(
    String symbol, {
    DateTime? start,
    DateTime? end,
    int limit = 1000,
  }) async {
    return fetchKlines(symbol, interval: '1d', start: start, end: end, limit: limit);
  }

  /// Fetches hourly klines (OHLCV) for a spot symbol like 'BTCUSDT'.
  Future<List<Candle>> fetchHourlyKlines(
    String symbol, {
    DateTime? start,
    DateTime? end,
    int limit = 60,
  }) async {
    return fetchKlines(symbol, interval: '1h', start: start, end: end, limit: limit);
  }

  /// Generic klines fetch for a custom interval like '15m', '1h', '4h'
  Future<List<Candle>> fetchCustomKlines(String symbol, String interval, {int limit = 60}) async {
    return fetchKlines(symbol, interval: interval, limit: limit);
  }

  /// Fetch tradable spot pairs (symbol, base, quote) from exchangeInfo
  Future<List<Map<String, String>>> fetchTradingPairs() async {
    final uri = Uri.https(_baseHost, '/api/v3/exchangeInfo');
    final http.Response res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Binance exchangeInfo error ${res.statusCode}: ${res.body}');
    }
    final Map<String, dynamic> data = json.decode(res.body) as Map<String, dynamic>;
    final List<dynamic> symbols = (data['symbols'] as List<dynamic>?) ?? <dynamic>[];
    final List<Map<String, String>> pairs = <Map<String, String>>[];
    for (final dynamic s in symbols) {
      final Map<String, dynamic> m = s as Map<String, dynamic>;
      final String status = (m['status'] ?? '').toString();
      final bool spot = (m['isSpotTradingAllowed'] ?? false) == true;
      if (status == 'TRADING' && spot) {
        final String symbol = (m['symbol'] ?? '').toString();
        final String base = (m['baseAsset'] ?? '').toString();
        final String quote = (m['quoteAsset'] ?? '').toString();
        pairs.add({'symbol': symbol, 'base': base, 'quote': quote});
      }
    }
    return pairs;
  }

  /// Fetch 24h ticker data for a symbol. Returns lastPrice and priceChangePercent.
  Future<Map<String, double>> fetchTicker24h(String symbol) async {
    final uri = Uri.https(_baseHost, '/api/v3/ticker/24hr', {'symbol': symbol});
    final http.Response res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Binance 24hr ticker error ${res.statusCode}: ${res.body}');
    }
    final Map<String, dynamic> data = json.decode(res.body) as Map<String, dynamic>;
    final double lastPrice = double.tryParse((data['lastPrice']).toString()) ?? 0.0;
    final double changePercent = double.tryParse((data['priceChangePercent']).toString()) ?? 0.0;
    return {'lastPrice': lastPrice, 'priceChangePercent': changePercent};
  }

  /// Get 24h trading volume for a symbol in quote currency (e.g., EUR for BTCEUR)
  /// Returns volume in quote currency (for BTCEUR, returns EUR volume)
  ///
  /// Used by Phase 3 of Enhanced Ensemble Strategy to apply volume-based confidence boost.
  /// High-volume coins (> median) get +5% confidence boost for general models.
  Future<double> get24hVolume(String symbol) async {
    try {
      final uri = Uri.https(_baseHost, '/api/v3/ticker/24hr', {'symbol': symbol});
      final http.Response res = await http.get(uri);
      if (res.statusCode != 200) {
        throw Exception('Binance 24hr volume error ${res.statusCode}: ${res.body}');
      }
      final Map<String, dynamic> data = json.decode(res.body) as Map<String, dynamic>;

      // quoteVolume = 24h trading volume in quote currency (e.g., EUR)
      final double quoteVolume = double.tryParse((data['quoteVolume']).toString()) ?? 0.0;
      return quoteVolume;
    } catch (e) {
      debugPrint('❌ BinanceService: Failed to fetch 24h volume for $symbol: $e');
      rethrow;
    }
  }

  /// Get 24h volumes for multiple symbols and calculate volume percentile for target symbol
  /// Returns volume percentile (0.0 to 1.0) indicating where target symbol ranks
  ///
  /// Example: percentile = 0.75 means target symbol has higher volume than 75% of comparison symbols
  ///
  /// Used by Phase 3: High-volume symbols (percentile > 0.5) get +5% confidence boost
  Future<double> getVolumePercentile(String targetSymbol, {List<String>? comparisonSymbols}) async {
    try {
      // Default comparison set: major EUR pairs
      final symbols = comparisonSymbols ?? [
        'BTCEUR',
        'ETHEUR',
        'XRPEUR',
        'ADAEUR',
        'DOGEEUR',
        'MATICEUR',
        'DOTEUR',
        'LINKEUR',
        'UNIEUR',
        'TRUMPEUR',
        'WLFIEUR',
      ];

      // Fetch volumes for all symbols in parallel
      final volumeFutures = symbols.map((s) => get24hVolume(s));
      final volumes = await Future.wait(volumeFutures, eagerError: false);

      // Get target volume
      final targetVolume = await get24hVolume(targetSymbol);

      // Calculate percentile: % of symbols with lower volume
      int lowerCount = 0;
      for (final vol in volumes) {
        if (vol < targetVolume) lowerCount++;
      }

      final percentile = lowerCount / volumes.length;
      debugPrint('📊 Volume percentile for $targetSymbol: ${(percentile * 100).toStringAsFixed(1)}% (volume: ${targetVolume.toStringAsFixed(0)} EUR)');

      return percentile;
    } catch (e) {
      debugPrint('❌ BinanceService: Failed to calculate volume percentile: $e');
      // Return median (0.5) on error - no boost or penalty
      return 0.5;
    }
  }

  /// Try multiple symbols until one works (useful for tokens with alt tickers like 1000TRUMPUSDT)
  Future<Map<String, double>> fetchTicker24hWithFallback(List<String> symbols) async {
    for (final String s in symbols) {
      try {
        return await fetchTicker24h(s);
      } catch (_) {}
    }
    throw Exception('No working symbol among: ${symbols.join(', ')}');
  }

  /// Try multiple symbols until one works for klines/candles (useful for handling USD/USDT/EUR pairs)
  Future<List<Candle>> fetchKlinesWithFallback(List<String> symbols, String interval, {int limit = 60}) async {
    for (final String s in symbols) {
      try {
        return await fetchKlines(s, interval: interval, limit: limit);
      } catch (_) {
        // Try next symbol in list
      }
    }
    throw Exception('No working symbol among: ${symbols.join(', ')} for interval $interval');
  }

  /// Build ML features with symbol fallback (e.g., BTCUSD -> try BTCUSDT/BTCEUR/BTCUSDC)
  Future<List<List<double>>> getFeaturesForModelWithFallback(String symbol, {String interval = '1h'}) async {
    final result = await getFeaturesWithATRFallback(symbol, interval: interval);
    return result.features;
  }

  /// Build ML features + ATR with symbol fallback (for Phase 3 volatility-based weights)
  Future<FeaturesWithATR> getFeaturesWithATRFallback(String symbol, {String interval = '1h'}) async {
    final String upper = symbol.toUpperCase();
    final RegExp suffix = RegExp(r'(USDT|USDC|EUR|USD)$');
    String base = upper;
    String? quote;
    final match = suffix.firstMatch(upper);
    if (match != null) {
      quote = match.group(1);
      base = upper.substring(0, match.start);
    }

    final List<String> candidates = <String>[
      if (quote != null) '$base$quote',
      '${base}USDT',
      '${base}EUR',
      '${base}USDC',
    ];

    String resolved = candidates.first;
    for (final s in candidates) {
      try {
        // Probe minimal klines request to verify symbol validity
        await fetchKlines(s, interval: interval, limit: 1);
        resolved = s;
        break;
      } catch (_) {
        // try next candidate
      }
    }

    // Fetch candles to calculate ATR before feature engineering
    int limit;
    switch (interval) {
      case '15m':
        limit = 1000;
        break;
      case '4h':
        limit = 1000;
        break;
      case '1d':
        limit = 1000;
        break;
      case '1w':
        limit = 1000;
        break;
      default:
        limit = 1000;
    }

    final candles = await fetchKlines(resolved, interval: interval, limit: limit);
    
    // Calculate ATR from raw candles
    final candlesForATR = candles.map((c) => [
      c.openTime.millisecondsSinceEpoch.toDouble(),
      c.open,
      c.high,
      c.low,
      c.close,
      c.volume,
    ]).toList();
    
    final atr = _calculateATR(candlesForATR, period: 14);
    
    // Build features
    final fullBuilder = FullFeatureBuilder();
    final features = fullBuilder.buildFeatures(candles: candles);
    
    return FeaturesWithATR(features: features, atr: atr);
  }

  /// Calculate ATR (Average True Range) from candles
  static double _calculateATR(List<List<double>> candles, {int period = 14}) {
    if (candles.length < period + 1) {
      debugPrint('⚠️  Insufficient candles for ATR (need ${period + 1}, got ${candles.length})');
      return 0.02; // Default 2% volatility
    }

    final trueRanges = <double>[];
    for (int i = 1; i < candles.length; i++) {
      final high = candles[i][2];
      final low = candles[i][3];
      final prevClose = candles[i - 1][4];
      final tr = _max3(high - low, (high - prevClose).abs(), (low - prevClose).abs());
      trueRanges.add(tr);
    }

    if (trueRanges.length < period) {
      return 0.02;
    }

    final lastN = trueRanges.sublist(trueRanges.length - period);
    final atrValue = lastN.reduce((a, b) => a + b) / period;
    final avgPrice = candles.map((c) => c[4]).reduce((a, b) => a + b) / candles.length;
    return avgPrice > 0 ? atrValue / avgPrice : 0.02;
  }

  static double _max3(double a, double b, double c) {
    return a > b ? (a > c ? a : c) : (b > c ? b : c);
  }

  static Candle _parseKlineArray(List<dynamic> arr) {
    // Binance kline fields:
    // 0 Open time (ms), 1 Open, 2 High, 3 Low, 4 Close, 5 Volume,
    // 6 Close time (ms), ... others not used
    final DateTime openTime = DateTime.fromMillisecondsSinceEpoch(arr[0] as int, isUtc: true).toLocal();
    final DateTime closeTime = DateTime.fromMillisecondsSinceEpoch(arr[6] as int, isUtc: true).toLocal();
    return Candle(
      openTime: openTime,
      open: double.parse(arr[1] as String),
      high: double.parse(arr[2] as String),
      low: double.parse(arr[3] as String),
      close: double.parse(arr[4] as String),
      volume: double.parse(arr[5] as String),
      closeTime: closeTime,
    );
  }

  /// Convenience method to fetch last 1 year of daily candles.
  Future<List<Candle>> fetchLastYearDaily(String symbol) async {
    final DateTime end = DateTime.now().toUtc();
    final DateTime start = DateTime(end.year - 1, end.month, end.day).toUtc();
    return fetchDailyKlines(symbol, start: start, end: end, limit: 1000);
  }

  /// Fetch ML features in the exact Python MTF order (base interval + aligned timeframes + one-hot symbol)
  /// Returns List<List<double>> with shape 60x34
  ///
  /// interval: '15m', '1h', or '4h' - determines the base timeframe
  Future<List<List<double>>> getFeaturesForModel(String symbol, {String interval = '1h'}) async {
    try {
      // Fetch data based on selected interval
      // MTF structure: base timeframe + lower timeframe + higher timeframe
      List<Candle> baseData;

      if (interval == '15m') {
        // Base: 15m, Low: 5m, High: 1h - MAXIM 1000 from Binance
        baseData = await fetchCustomKlines(symbol, '15m', limit: 1000);
      } else if (interval == '4h') {
        // Base: 4h, Low: 1h, High: 1d - MAXIM 1000 from Binance
        baseData = await fetchCustomKlines(symbol, '4h', limit: 1000);
      } else if (interval == '1d') {
        // Base: 1d (daily), Low: 4h, High: 1w - MAXIM 1000 from Binance
        baseData = await fetchCustomKlines(symbol, '1d', limit: 1000);
      } else if (interval == '1w') {
        // Base: 1w (weekly), Low: 1d, High: 1M - MAXIM 1000 from Binance
        baseData = await fetchCustomKlines(symbol, '1w', limit: 1000);
      } else {
        // Default: Base: 1h, Low: 15m, High: 4h - MAXIM 1000 from Binance
        baseData = await fetchCustomKlines(symbol, '1h', limit: 1000);
      }

      if (baseData.length < 120) {
        throw Exception('Insufficient $interval candles: got ${baseData.length}, need >=120 (for SMA100 + 60 sequence)');
      }

      debugPrint('🔧 BinanceService: Building 76 features from ${baseData.length} candles');
      final fullBuilder = FullFeatureBuilder();
      final features = fullBuilder.buildFeatures(candles: baseData);
      debugPrint('✅ BinanceService: Full features ${features.length}x${features.isNotEmpty ? features.first.length : 0} [@$interval]');
      return features;
    } catch (e) {
      debugPrint('❌ BinanceService: Error getting features → $e');
      rethrow;
    }
  }

  /// Feature extraction with structured error reporting
  Future<FeatureResult> getFeaturesForModelResult(String symbol, {String interval = '1h'}) async {
    try {
      List<Candle> baseData;
      if (interval == '15m') {
        baseData = await fetchCustomKlines(symbol, '15m', limit: 1000);
      } else if (interval == '4h') {
        baseData = await fetchCustomKlines(symbol, '4h', limit: 1000);
      } else if (interval == '1d') {
        baseData = await fetchCustomKlines(symbol, '1d', limit: 1000);
      } else if (interval == '1w') {
        baseData = await fetchCustomKlines(symbol, '1w', limit: 1000);
      } else {
        baseData = await fetchCustomKlines(symbol, '1h', limit: 1000);
      }

      if (baseData.length < 120) {
        debugPrint('❌ BinanceService: insufficient_data for $symbol @$interval need=120 got=${baseData.length}');
        return FeatureResult.error('insufficient_data', need: 120, got: baseData.length);
      }

      debugPrint('🔧 BinanceService: Building 76 features from ${baseData.length} candles');
      final fullBuilder = FullFeatureBuilder();
      final features = fullBuilder.buildFeatures(candles: baseData);
      debugPrint('✅ BinanceService: Full features ${features.length}x${features.isNotEmpty ? features.first.length.toString() : '0'} [@$interval]');
      return FeatureResult.ok(features);
    } catch (e) {
      debugPrint('❌ BinanceService: feature build error → $e');
      return FeatureResult.error('error');
    }
  }
}

