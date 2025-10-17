import 'package:dio/dio.dart';

/// Service for fetching social sentiment data from LunarCrush API
///
/// Social sentiment analysis tracks crowd psychology through:
/// - Twitter/X mentions and sentiment scores
/// - Social volume (how much people are talking about an asset)
/// - Social dominance (% of crypto conversation)
///
/// Why this matters: Sentiment often leads price (bullish buzz → price follows)
/// Divergences are powerful: Price up + sentiment down = potential reversal
class LunarCrushService {
  // API Configuration
  static const String _baseUrl = 'https://api.lunarcrush.com/v2';

  // API Key - Get yours at: https://lunarcrush.com/developers/api
  // Cost: $29/month for Basic plan (50,000 credits/month)
  String? _apiKey;

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  // Cache for reducing API calls
  final Map<String, CachedSentiment> _cache = {};
  static const Duration _cacheDuration = Duration(minutes: 30);

  LunarCrushService({String? apiKey}) : _apiKey = apiKey;

  /// Initialize API key (can be called after construction)
  void setApiKey(String apiKey) {
    _apiKey = apiKey;
  }

  /// Fetch sentiment data for a symbol
  ///
  /// Returns map with:
  /// - sentimentScore: -1 (very bearish) to +1 (very bullish)
  /// - socialVolume: Number of social media mentions (last 24h)
  /// - socialDominance: % of total crypto social conversation
  /// - sentimentTrend: 'rising', 'falling', or 'stable'
  Future<Map<String, dynamic>> fetchSentiment(String symbol) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      print('⚠️ LunarCrush API key not set. Returning neutral sentiment.');
      return _neutralSentiment();
    }

    final cacheKey = 'sentiment_$symbol';
    if (_isCacheValid(cacheKey)) {
      return _cache[cacheKey]!.data;
    }

    try {
      // Clean symbol (remove USDT, BUSD suffixes)
      final cleanSymbol = symbol
          .toUpperCase()
          .replaceAll('USDT', '')
          .replaceAll('BUSD', '')
          .replaceAll('USD', '');

      final response = await _dio.get(
        '/assets',
        queryParameters: {
          'data': 'assets',
          'key': _apiKey,
          'symbol': cleanSymbol,
          'interval': 'day', // 24h data
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;

        if (data['data'] == null || (data['data'] as List).isEmpty) {
          print('⚠️ LunarCrush: No data for $cleanSymbol');
          return _neutralSentiment();
        }

        final assetData = (data['data'] as List).first;

        // Extract sentiment metrics
        final sentimentScore = _calculateSentimentScore(assetData);
        final socialVolume = assetData['social_volume'] ?? 0;
        final socialDominance = (assetData['social_dominance'] ?? 0.0).toDouble();
        final galaxyScore = (assetData['galaxy_score'] ?? 50.0).toDouble();
        final altRank = assetData['alt_rank'] ?? 999;

        // Calculate trend
        final sentiment24hChange = (assetData['sentiment_relative'] ?? 0.0).toDouble();
        final sentimentTrend = _determineTrend(sentiment24hChange);

        final result = {
          'sentimentScore': sentimentScore,
          'socialVolume': socialVolume,
          'socialDominance': socialDominance,
          'sentimentTrend': sentimentTrend,
          'galaxyScore': galaxyScore, // LunarCrush's proprietary score (0-100)
          'altRank': altRank, // Ranking vs other altcoins (1 = best)
          'timestamp': DateTime.now().toIso8601String(),
        };

        _cache[cacheKey] = CachedSentiment(data: result, timestamp: DateTime.now());
        return result;
      } else if (response.statusCode == 401) {
        print('❌ LunarCrush API: Invalid API key');
        return _neutralSentiment();
      } else if (response.statusCode == 429) {
        print('⚠️ LunarCrush API: Rate limit exceeded');
        return _neutralSentiment();
      } else {
        print('⚠️ LunarCrush API error: ${response.statusCode}');
        return _neutralSentiment();
      }
    } catch (e) {
      print('❌ LunarCrush fetch error: $e');
      return _neutralSentiment();
    }
  }

  /// Fetch weighted sentiment (sentiment * social volume)
  ///
  /// Filters out low-engagement noise. A sentiment of +0.8 with only 10 mentions
  /// is less reliable than +0.6 with 10,000 mentions.
  Future<double> fetchWeightedSentiment(String symbol) async {
    final sentiment = await fetchSentiment(symbol);

    final score = sentiment['sentimentScore'] as double;
    final volume = sentiment['socialVolume'] as int;

    // Weight by log of social volume (diminishing returns for very high volume)
    final volumeWeight = volume > 0 ? (1 + (volume / 1000).clamp(0, 10)) : 1.0;

    return (score * volumeWeight).clamp(-10.0, 10.0);
  }

  /// Detect sentiment-price divergence
  ///
  /// Bullish divergence: Price falling BUT sentiment improving (potential reversal up)
  /// Bearish divergence: Price rising BUT sentiment worsening (potential reversal down)
  ///
  /// Returns: 'bullish_divergence', 'bearish_divergence', or 'none'
  Future<String> detectDivergence({
    required List<double> prices,
    required List<double> sentiments,
  }) async {
    if (prices.length < 2 || sentiments.length < 2) {
      return 'none';
    }

    // Compare last 24 hours vs previous 24 hours
    final priceChange = ((prices.last - prices.first) / prices.first);
    final sentimentChange = sentiments.last - sentiments.first;

    // Divergence thresholds
    const priceThreshold = 0.02; // 2% price move
    const sentimentThreshold = 0.1; // 0.1 sentiment change

    // Bullish divergence: Price down, sentiment up
    if (priceChange < -priceThreshold && sentimentChange > sentimentThreshold) {
      return 'bullish_divergence';
    }

    // Bearish divergence: Price up, sentiment down
    if (priceChange > priceThreshold && sentimentChange < -sentimentThreshold) {
      return 'bearish_divergence';
    }

    return 'none';
  }

  /// Calculate sentiment score from LunarCrush data
  ///
  /// Combines multiple sentiment indicators into -1 to +1 range
  double _calculateSentimentScore(Map<String, dynamic> assetData) {
    // LunarCrush provides multiple sentiment-related metrics
    // We'll combine them into a single normalized score

    // 1. Galaxy Score (0-100, proprietary metric)
    final galaxyScore = (assetData['galaxy_score'] ?? 50.0).toDouble();
    final galaxyNorm = ((galaxyScore - 50.0) / 50.0).clamp(-1.0, 1.0);

    // 2. Alt Rank (lower is better, 1-1000+)
    final altRank = (assetData['alt_rank'] ?? 500).toInt();
    final altRankNorm = (1.0 - (altRank / 500.0)).clamp(-1.0, 1.0);

    // 3. Social Volume Trend (are mentions increasing?)
    final volumeChange = (assetData['percent_change_24h'] ?? 0.0).toDouble();
    final volumeNorm = (volumeChange / 100.0).clamp(-1.0, 1.0);

    // Weighted average (Galaxy Score weighted highest)
    final sentimentScore = (galaxyNorm * 0.6) + (altRankNorm * 0.3) + (volumeNorm * 0.1);

    return sentimentScore.clamp(-1.0, 1.0);
  }

  /// Determine sentiment trend
  String _determineTrend(double change) {
    if (change > 0.05) return 'rising';
    if (change < -0.05) return 'falling';
    return 'stable';
  }

  /// Neutral sentiment fallback
  Map<String, dynamic> _neutralSentiment() {
    return {
      'sentimentScore': 0.0,
      'socialVolume': 0,
      'socialDominance': 0.0,
      'sentimentTrend': 'stable',
      'galaxyScore': 50.0,
      'altRank': 500,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Normalize sentiment features for ML model input
  ///
  /// Returns [sentimentScore, socialVolumeNorm]
  List<double> normalizeSentimentFeatures(Map<String, dynamic> sentiment) {
    final score = sentiment['sentimentScore'] as double;
    final volume = sentiment['socialVolume'] as int;

    // Sentiment already in -1 to +1 range
    final sentimentNorm = score.clamp(-1.0, 1.0);

    // Social volume normalization
    // Typical range: 0 - 50,000 mentions for major coins
    final volumeNorm = (volume / 10000.0).clamp(0.0, 5.0);

    return [sentimentNorm, volumeNorm];
  }

  /// Check if cached data is still valid
  bool _isCacheValid(String key) {
    if (!_cache.containsKey(key)) return false;

    final cached = _cache[key]!;
    final age = DateTime.now().difference(cached.timestamp);
    return age < _cacheDuration;
  }

  /// Clear cache
  void clearCache() {
    _cache.clear();
  }

  /// Get cache statistics
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

/// Cache entry for sentiment data
class CachedSentiment {
  final Map<String, dynamic> data;
  final DateTime timestamp;

  CachedSentiment({required this.data, required this.timestamp});
}

/// Example usage:
///
/// ```dart
/// final lunarCrush = LunarCrushService(apiKey: 'YOUR_API_KEY');
///
/// // Fetch sentiment
/// final sentiment = await lunarCrush.fetchSentiment('BTCUSDT');
/// print('Sentiment Score: ${sentiment['sentimentScore']}');
/// print('Social Volume: ${sentiment['socialVolume']} mentions');
/// print('Trend: ${sentiment['sentimentTrend']}');
///
/// if (sentiment['sentimentScore'] > 0.6) {
///   print('🚀 Very bullish social sentiment!');
/// } else if (sentiment['sentimentScore'] < -0.6) {
///   print('📉 Very bearish social sentiment!');
/// }
///
/// // Weighted sentiment (accounts for volume)
/// final weighted = await lunarCrush.fetchWeightedSentiment('BTCUSDT');
/// print('Weighted Sentiment: $weighted');
///
/// // Detect divergence
/// final divergence = await lunarCrush.detectDivergence(
///   prices: [50000, 49500, 49000, 48500],
///   sentiments: [-0.2, -0.1, 0.1, 0.3],
/// );
/// if (divergence == 'bullish_divergence') {
///   print('⚠️ Bullish divergence detected! Price down but sentiment improving.');
/// }
///
/// // Normalize for ML model
/// final normalized = lunarCrush.normalizeSentimentFeatures(sentiment);
/// print('Normalized features: $normalized');
/// ```
