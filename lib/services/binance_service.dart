import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert' show utf8;

import '../models/candle.dart';
import '../services/app_settings_service.dart';
// import '../services/technical_indicator_calculator.dart';
import '../services/mtf_feature_builder.dart';

class BinanceService {
  static const String _baseHostLive = 'api.binance.com';
  static const String _baseHostTestnet = 'testnet.binance.vision';
  String get _baseHost => AppSettingsService().isTestnet ? _baseHostTestnet : _baseHostLive;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Singleton pattern
  static final BinanceService _instance = BinanceService._internal();
  factory BinanceService() => _instance;
  BinanceService._internal();

  String? _apiKey;
  String? _apiSecret;

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

  String _generateSignature(String queryString) {
    final key = utf8.encode(_apiSecret!);
    final bytes = utf8.encode(queryString);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return digest.toString();
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

  /// Try multiple symbols until one works (useful for tokens with alt tickers like 1000TRUMPUSDT)
  Future<Map<String, double>> fetchTicker24hWithFallback(List<String> symbols) async {
    for (final String s in symbols) {
      try {
        return await fetchTicker24h(s);
      } catch (_) {}
    }
    throw Exception('No working symbol among: ' + symbols.join(', '));
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

  /// Fetch ML features in the exact Python MTF order (1h base + aligned 15m + upsampled 4h + one-hot symbol)
  /// Returns List<List<double>> with shape 60x34
  Future<List<List<double>>> getFeaturesForModel(String symbol, {String interval = '1h'}) async {
    try {
      // Always fetch base=1h, low=15m, high=4h
      final base1h = await fetchCustomKlines(symbol, '1h', limit: 260); // more to allow indicators warmup
      final low15m = await fetchCustomKlines(symbol, '15m', limit: 260 * 4);
      final high4h = await fetchCustomKlines(symbol, '4h', limit: 260 ~/ 4 + 10);

      if (base1h.length < 60) {
        throw Exception('Insufficient 1h candles: got ${base1h.length}, need >=60');
      }

      final mtf = MtfFeatureBuilder().buildFeatures(symbol: symbol, base1h: base1h, low15m: low15m, high4h: high4h);
      debugPrint('✅ BinanceService: MTF features ${mtf.length}x${mtf.isNotEmpty ? mtf.first.length : 0}');
      return mtf;
    } catch (e) {
      debugPrint('❌ BinanceService: Error getting features → $e');
      rethrow;
    }
  }
}

