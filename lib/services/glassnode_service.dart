import 'package:dio/dio.dart';

/// Service for fetching on-chain analytics from Glassnode API
///
/// On-chain data provides insights invisible to traditional technical analysis:
/// - Exchange flows (coins moving to/from exchanges = sell/buy pressure)
/// - SOPR (Spent Output Profit Ratio = are holders selling at profit or loss?)
/// - Active addresses (network activity = market interest)
///
/// These metrics often predict price movements before they happen.
class GlassnodeService {
  // API Configuration
  static const String _baseUrl = 'https://api.glassnode.com/v1';

  // API Key - Store in .env or Flutter Secure Storage in production
  // Get your key at: https://studio.glassnode.com/settings/api
  // Cost: $39/month for Starter plan
  String? _apiKey;

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  // Cache for reducing API calls (Glassnode has rate limits)
  final Map<String, CachedData> _cache = {};
  static const Duration _cacheDuration = Duration(minutes: 15);

  GlassnodeService({String? apiKey}) : _apiKey = apiKey;

  /// Initialize API key (can be called after construction)
  void setApiKey(String apiKey) {
    _apiKey = apiKey;
  }

  /// Fetch Exchange Net Flow
  ///
  /// Positive value = BTC flowing TO exchanges (potential sell pressure)
  /// Negative value = BTC flowing FROM exchanges (hodling, bullish)
  ///
  /// Example: +10,000 BTC = Large deposits to exchanges, expect selling
  Future<double> fetchExchangeNetFlow(String symbol, {String interval = '24h'}) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      print('⚠️ Glassnode API key not set. Returning fallback value 0.0');
      return 0.0;
    }

    final cacheKey = 'exchange_net_flow_${symbol}_$interval';
    if (_isCacheValid(cacheKey)) {
      return _cache[cacheKey]!.value as double;
    }

    try {
      final response = await _dio.get(
        '/metrics/transactions/transfers_volume_to_exchanges_net',
        queryParameters: {
          'a': symbol.toLowerCase().replaceAll('USDT', '').replaceAll('BUSD', ''),
          'api_key': _apiKey,
          'i': interval,
          'f': 'JSON',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as List;
        if (data.isEmpty) return 0.0;

        final latestValue = data.last['v'] as num;
        final result = latestValue.toDouble();

        _cache[cacheKey] = CachedData(value: result, timestamp: DateTime.now());
        return result;
      } else if (response.statusCode == 401) {
        print('❌ Glassnode API: Invalid API key');
        return 0.0;
      } else if (response.statusCode == 429) {
        print('⚠️ Glassnode API: Rate limit exceeded. Using cache or fallback.');
        return 0.0;
      } else {
        print('⚠️ Glassnode API error: ${response.statusCode}');
        return 0.0;
      }
    } catch (e) {
      print('❌ Glassnode fetch error (Exchange Net Flow): $e');
      return 0.0; // Graceful fallback
    }
  }

  /// Fetch SOPR (Spent Output Profit Ratio)
  ///
  /// SOPR = (value at sell) / (value at buy) for on-chain transactions
  ///
  /// SOPR > 1.0: Holders selling at profit (if sudden spike > 1.05 = mass profit-taking, bearish)
  /// SOPR < 1.0: Holders selling at loss (if drops < 0.95 = capitulation, bullish reversal signal)
  /// SOPR = 1.0: Break-even selling (neutral)
  Future<double> fetchSOPR(String symbol) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return 1.0; // Neutral fallback
    }

    final cacheKey = 'sopr_$symbol';
    if (_isCacheValid(cacheKey)) {
      return _cache[cacheKey]!.value as double;
    }

    try {
      final response = await _dio.get(
        '/metrics/indicators/sopr',
        queryParameters: {
          'a': symbol.toLowerCase().replaceAll('USDT', '').replaceAll('BUSD', ''),
          'api_key': _apiKey,
          'f': 'JSON',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as List;
        if (data.isEmpty) return 1.0;

        final latestValue = data.last['v'] as num;
        final result = latestValue.toDouble();

        _cache[cacheKey] = CachedData(value: result, timestamp: DateTime.now());
        return result;
      } else {
        print('⚠️ Glassnode SOPR error: ${response.statusCode}');
        return 1.0;
      }
    } catch (e) {
      print('❌ Glassnode fetch error (SOPR): $e');
      return 1.0;
    }
  }

  /// Fetch Active Addresses (24h)
  ///
  /// Number of unique wallet addresses active in last 24 hours
  ///
  /// Rising addresses + rising price = Strong bullish confirmation (real demand)
  /// Rising price + flat addresses = Weak rally (leverage-driven, may reverse)
  /// Falling addresses + falling price = Capitulation (may signal bottom)
  Future<int> fetchActiveAddresses(String symbol, {String interval = '24h'}) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return 500000; // Fallback: typical BTC active addresses
    }

    final cacheKey = 'active_addresses_${symbol}_$interval';
    if (_isCacheValid(cacheKey)) {
      return _cache[cacheKey]!.value as int;
    }

    try {
      final response = await _dio.get(
        '/metrics/addresses/active_count',
        queryParameters: {
          'a': symbol.toLowerCase().replaceAll('USDT', '').replaceAll('BUSD', ''),
          'api_key': _apiKey,
          'i': interval,
          'f': 'JSON',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as List;
        if (data.isEmpty) return 500000;

        final latestValue = data.last['v'] as num;
        final result = latestValue.toInt();

        _cache[cacheKey] = CachedData(value: result, timestamp: DateTime.now());
        return result;
      } else {
        print('⚠️ Glassnode Active Addresses error: ${response.statusCode}');
        return 500000;
      }
    } catch (e) {
      print('❌ Glassnode fetch error (Active Addresses): $e');
      return 500000;
    }
  }

  /// Fetch all on-chain metrics in one call (more efficient)
  ///
  /// Returns a map with all 3 metrics for a symbol
  Future<Map<String, num>> fetchAllMetrics(String symbol) async {
    final results = await Future.wait([
      fetchExchangeNetFlow(symbol),
      fetchSOPR(symbol),
      fetchActiveAddresses(symbol),
    ]);

    return {
      'exchangeNetFlow': results[0],
      'sopr': results[1],
      'activeAddresses': results[2],
    };
  }

  /// Normalize on-chain features for ML model input
  ///
  /// Converts raw values to normalized range suitable for neural network
  /// Returns [exchangeNetFlowNorm, soprNorm, activeAddressesNorm]
  List<double> normalizeMetrics({
    required double exchangeNetFlow,
    required double sopr,
    required int activeAddresses,
  }) {
    // Exchange Net Flow normalization
    // Typical range: -50,000 to +50,000 BTC
    // Normalize to -1 to +1
    final flowNorm = (exchangeNetFlow / 10000.0).clamp(-5.0, 5.0);

    // SOPR normalization
    // Typical range: 0.90 to 1.10
    // Center around 0 (1.0 becomes 0)
    final soprNorm = ((sopr - 1.0) / 0.1).clamp(-2.0, 2.0);

    // Active Addresses normalization
    // BTC typical: 400,000 - 600,000
    // ETH typical: 400,000 - 500,000
    // Normalize around mean
    const meanActiveAddresses = 500000;
    const stdActiveAddresses = 100000;
    final addressesNorm = ((activeAddresses - meanActiveAddresses) / stdActiveAddresses)
        .clamp(-3.0, 3.0);

    return [flowNorm, soprNorm, addressesNorm];
  }

  /// Check if cached data is still valid
  bool _isCacheValid(String key) {
    if (!_cache.containsKey(key)) return false;

    final cached = _cache[key]!;
    final age = DateTime.now().difference(cached.timestamp);
    return age < _cacheDuration;
  }

  /// Clear cache (useful for testing or forcing refresh)
  void clearCache() {
    _cache.clear();
  }

  /// Get cache statistics (for debugging)
  Map<String, dynamic> getCacheStats() {
    return {
      'entries': _cache.length,
      'oldestEntry': _cache.values.isEmpty
          ? null
          : _cache.values
              .map((e) => e.timestamp)
              .reduce((a, b) => a.isBefore(b) ? a : b),
      'newestEntry': _cache.values.isEmpty
          ? null
          : _cache.values
              .map((e) => e.timestamp)
              .reduce((a, b) => a.isAfter(b) ? a : b),
    };
  }
}

/// Cache entry with timestamp for expiration
class CachedData {
  final dynamic value;
  final DateTime timestamp;

  CachedData({required this.value, required this.timestamp});
}

/// Example usage:
///
/// ```dart
/// final glassnode = GlassnodeService(apiKey: 'YOUR_API_KEY');
///
/// // Fetch individual metrics
/// final netFlow = await glassnode.fetchExchangeNetFlow('BTCUSDT');
/// print('Exchange Net Flow: $netFlow BTC');
///
/// if (netFlow > 10000) {
///   print('⚠️ Large inflow to exchanges detected! Potential selling pressure.');
/// }
///
/// // Fetch all metrics at once
/// final metrics = await glassnode.fetchAllMetrics('BTCUSDT');
/// print('All metrics: $metrics');
///
/// // Normalize for ML model
/// final normalized = glassnode.normalizeMetrics(
///   exchangeNetFlow: metrics['exchangeNetFlow'] as double,
///   sopr: metrics['sopr'] as double,
///   activeAddresses: metrics['activeAddresses'] as int,
/// );
/// print('Normalized features: $normalized');
/// ```
