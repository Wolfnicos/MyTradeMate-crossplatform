/// Candle Pattern Detector - detects 25 candlestick patterns
/// Port from Python candle_patterns.py to match ML training exactly
class CandlePatternDetector {
  /// Detect all 25 candlestick patterns
  /// Returns Map<String, List<double>> where each pattern is binary (1.0 or 0.0)
  Map<String, List<double>> detectAllPatterns({
    required List<double> opens,
    required List<double> highs,
    required List<double> lows,
    required List<double> closes,
    required List<double> volumes,
  }) {
    final int n = closes.length;
    final patterns = <String, List<double>>{};

    // Pre-calculate common values
    final body = List<double>.generate(n, (i) => closes[i] - opens[i]);
    final bodyAbs = List<double>.generate(n, (i) => (closes[i] - opens[i]).abs());
    final upperShadow = List<double>.generate(
      n,
      (i) => highs[i] - (opens[i] > closes[i] ? opens[i] : closes[i]),
    );
    final lowerShadow = List<double>.generate(
      n,
      (i) => (opens[i] < closes[i] ? opens[i] : closes[i]) - lows[i],
    );
    final candleRange = List<double>.generate(n, (i) => highs[i] - lows[i]);

    // 1. Dragonfly Doji
    patterns['dragonfly_doji'] = List<double>.generate(n, (i) {
      if (candleRange[i] == 0) return 0.0;
      return ((bodyAbs[i] / candleRange[i] <= 0.1) &&
              (lowerShadow[i] / candleRange[i] >= 0.6) &&
              (upperShadow[i] / candleRange[i] <= 0.1))
          ? 1.0
          : 0.0;
    });

    // 2. Gravestone Doji
    patterns['gravestone_doji'] = List<double>.generate(n, (i) {
      if (candleRange[i] == 0) return 0.0;
      return ((bodyAbs[i] / candleRange[i] <= 0.1) &&
              (upperShadow[i] / candleRange[i] >= 0.6) &&
              (lowerShadow[i] / candleRange[i] <= 0.1))
          ? 1.0
          : 0.0;
    });

    // 3. Long-legged Doji
    patterns['long_legged_doji'] = List<double>.generate(n, (i) {
      if (candleRange[i] == 0) return 0.0;
      return ((bodyAbs[i] / candleRange[i] <= 0.1) &&
              (upperShadow[i] / candleRange[i] >= 0.3) &&
              (lowerShadow[i] / candleRange[i] >= 0.3))
          ? 1.0
          : 0.0;
    });

    // 4. Doji (general)
    patterns['doji'] = List<double>.generate(n, (i) {
      if (candleRange[i] == 0) return 0.0;
      return (bodyAbs[i] / candleRange[i] <= 0.1) ? 1.0 : 0.0;
    });

    // 5. Hammer
    patterns['hammer'] = List<double>.generate(n, (i) {
      if (candleRange[i] == 0) return 0.0;
      return ((bodyAbs[i] / candleRange[i] <= 0.3) &&
              (lowerShadow[i] >= 2 * bodyAbs[i]) &&
              (upperShadow[i] <= bodyAbs[i] * 0.1))
          ? 1.0
          : 0.0;
    });

    // 6. Inverted Hammer
    patterns['inverted_hammer'] = List<double>.generate(n, (i) {
      if (candleRange[i] == 0) return 0.0;
      return ((bodyAbs[i] / candleRange[i] <= 0.3) &&
              (upperShadow[i] >= 2 * bodyAbs[i]) &&
              (lowerShadow[i] <= bodyAbs[i] * 0.1))
          ? 1.0
          : 0.0;
    });

    // 7. Hanging Man
    patterns['hanging_man'] = List<double>.generate(n, (i) {
      if (candleRange[i] == 0) return 0.0;
      return ((bodyAbs[i] / candleRange[i] <= 0.3) &&
              (lowerShadow[i] >= 2 * bodyAbs[i]) &&
              (upperShadow[i] <= bodyAbs[i] * 0.1) &&
              (body[i] > 0))
          ? 1.0
          : 0.0;
    });

    // 8. Shooting Star
    patterns['shooting_star'] = List<double>.generate(n, (i) {
      if (candleRange[i] == 0) return 0.0;
      return ((bodyAbs[i] / candleRange[i] <= 0.3) &&
              (upperShadow[i] >= 2 * bodyAbs[i]) &&
              (lowerShadow[i] <= bodyAbs[i] * 0.1) &&
              (body[i] < 0))
          ? 1.0
          : 0.0;
    });

    // 9. Spinning Top
    patterns['spinning_top'] = List<double>.generate(n, (i) {
      if (candleRange[i] == 0) return 0.0;
      return ((bodyAbs[i] / candleRange[i] <= 0.3) &&
              (upperShadow[i] > bodyAbs[i]) &&
              (lowerShadow[i] > bodyAbs[i]))
          ? 1.0
          : 0.0;
    });

    // 10. Marubozu Bullish
    patterns['marubozu_bullish'] = List<double>.generate(n, (i) {
      if (candleRange[i] == 0) return 0.0;
      return ((body[i] > 0) &&
              (bodyAbs[i] / candleRange[i] >= 0.95) &&
              (upperShadow[i] <= candleRange[i] * 0.02) &&
              (lowerShadow[i] <= candleRange[i] * 0.02))
          ? 1.0
          : 0.0;
    });

    // 11. Marubozu Bearish
    patterns['marubozu_bearish'] = List<double>.generate(n, (i) {
      if (candleRange[i] == 0) return 0.0;
      return ((body[i] < 0) &&
              (bodyAbs[i] / candleRange[i] >= 0.95) &&
              (upperShadow[i] <= candleRange[i] * 0.02) &&
              (lowerShadow[i] <= candleRange[i] * 0.02))
          ? 1.0
          : 0.0;
    });

    // 12. Bullish Engulfing (2-candle pattern)
    patterns['bullish_engulfing'] = List<double>.generate(n, (i) {
      if (i == 0) return 0.0;
      return ((body[i - 1] < 0) &&
              (body[i] > 0) &&
              (opens[i] < closes[i - 1]) &&
              (closes[i] > opens[i - 1]))
          ? 1.0
          : 0.0;
    });

    // 13. Bearish Engulfing (2-candle pattern)
    patterns['bearish_engulfing'] = List<double>.generate(n, (i) {
      if (i == 0) return 0.0;
      return ((body[i - 1] > 0) &&
              (body[i] < 0) &&
              (opens[i] > closes[i - 1]) &&
              (closes[i] < opens[i - 1]))
          ? 1.0
          : 0.0;
    });

    // 14. Piercing Line (2-candle pattern)
    patterns['piercing_line'] = List<double>.generate(n, (i) {
      if (i == 0) return 0.0;
      final midpoint = (opens[i - 1] + closes[i - 1]) / 2;
      return ((body[i - 1] < 0) &&
              (body[i] > 0) &&
              (opens[i] < closes[i - 1]) &&
              (closes[i] > midpoint) &&
              (closes[i] < opens[i - 1]))
          ? 1.0
          : 0.0;
    });

    // 15. Dark Cloud Cover (2-candle pattern)
    patterns['dark_cloud_cover'] = List<double>.generate(n, (i) {
      if (i == 0) return 0.0;
      final midpoint = (opens[i - 1] + closes[i - 1]) / 2;
      return ((body[i - 1] > 0) &&
              (body[i] < 0) &&
              (opens[i] > closes[i - 1]) &&
              (closes[i] < midpoint) &&
              (closes[i] > opens[i - 1]))
          ? 1.0
          : 0.0;
    });

    // 16. Bullish Harami (2-candle pattern)
    patterns['bullish_harami'] = List<double>.generate(n, (i) {
      if (i == 0) return 0.0;
      return ((body[i - 1] < 0) &&
              (body[i] > 0) &&
              (opens[i] > closes[i - 1]) &&
              (closes[i] < opens[i - 1]) &&
              (bodyAbs[i] < bodyAbs[i - 1]))
          ? 1.0
          : 0.0;
    });

    // 17. Bearish Harami (2-candle pattern)
    patterns['bearish_harami'] = List<double>.generate(n, (i) {
      if (i == 0) return 0.0;
      return ((body[i - 1] > 0) &&
              (body[i] < 0) &&
              (opens[i] < closes[i - 1]) &&
              (closes[i] > opens[i - 1]) &&
              (bodyAbs[i] < bodyAbs[i - 1]))
          ? 1.0
          : 0.0;
    });

    // 18. Tweezer Top (2-candle pattern)
    patterns['tweezer_top'] = List<double>.generate(n, (i) {
      if (i == 0) return 0.0;
      return ((highs[i] - highs[i - 1]).abs() / highs[i] < 0.001) ? 1.0 : 0.0;
    });

    // 19. Tweezer Bottom (2-candle pattern)
    patterns['tweezer_bottom'] = List<double>.generate(n, (i) {
      if (i == 0) return 0.0;
      return ((lows[i] - lows[i - 1]).abs() / lows[i] < 0.001) ? 1.0 : 0.0;
    });

    // 20. Morning Star (3-candle pattern)
    patterns['morning_star'] = List<double>.generate(n, (i) {
      if (i < 2) return 0.0;
      return ((body[i - 2] < 0) &&
              (bodyAbs[i - 2] > bodyAbs[i - 1]) &&
              (bodyAbs[i - 1] / candleRange[i - 1] < 0.3) &&
              (body[i] > 0) &&
              (closes[i] > (opens[i - 2] + closes[i - 2]) / 2))
          ? 1.0
          : 0.0;
    });

    // 21. Evening Star (3-candle pattern)
    patterns['evening_star'] = List<double>.generate(n, (i) {
      if (i < 2) return 0.0;
      return ((body[i - 2] > 0) &&
              (bodyAbs[i - 2] > bodyAbs[i - 1]) &&
              (bodyAbs[i - 1] / candleRange[i - 1] < 0.3) &&
              (body[i] < 0) &&
              (closes[i] < (opens[i - 2] + closes[i - 2]) / 2))
          ? 1.0
          : 0.0;
    });

    // 22. Three White Soldiers (3-candle pattern)
    patterns['three_white_soldiers'] = List<double>.generate(n, (i) {
      if (i < 2) return 0.0;
      return ((body[i - 2] > 0) &&
              (body[i - 1] > 0) &&
              (body[i] > 0) &&
              (closes[i - 1] > closes[i - 2]) &&
              (closes[i] > closes[i - 1]) &&
              (opens[i - 1] > opens[i - 2]) &&
              (opens[i - 1] < closes[i - 2]) &&
              (opens[i] > opens[i - 1]) &&
              (opens[i] < closes[i - 1]))
          ? 1.0
          : 0.0;
    });

    // 23. Three Black Crows (3-candle pattern)
    patterns['three_black_crows'] = List<double>.generate(n, (i) {
      if (i < 2) return 0.0;
      return ((body[i - 2] < 0) &&
              (body[i - 1] < 0) &&
              (body[i] < 0) &&
              (closes[i - 1] < closes[i - 2]) &&
              (closes[i] < closes[i - 1]) &&
              (opens[i - 1] < opens[i - 2]) &&
              (opens[i - 1] > closes[i - 2]) &&
              (opens[i] < opens[i - 1]) &&
              (opens[i] > closes[i - 1]))
          ? 1.0
          : 0.0;
    });

    // 24. Rising Three Methods (5-candle pattern)
    patterns['rising_three'] = List<double>.generate(n, (i) {
      if (i < 4) return 0.0;
      return ((body[i - 4] > 0) &&
              (bodyAbs[i - 4] > bodyAbs[i - 3]) &&
              (bodyAbs[i - 4] > bodyAbs[i - 2]) &&
              (bodyAbs[i - 4] > bodyAbs[i - 1]) &&
              (closes[i - 3] < closes[i - 4]) &&
              (closes[i - 2] < closes[i - 4]) &&
              (closes[i - 1] < closes[i - 4]) &&
              (body[i] > 0) &&
              (closes[i] > closes[i - 4]))
          ? 1.0
          : 0.0;
    });

    // 25. Falling Three Methods (5-candle pattern)
    patterns['falling_three'] = List<double>.generate(n, (i) {
      if (i < 4) return 0.0;
      return ((body[i - 4] < 0) &&
              (bodyAbs[i - 4] > bodyAbs[i - 3]) &&
              (bodyAbs[i - 4] > bodyAbs[i - 2]) &&
              (bodyAbs[i - 4] > bodyAbs[i - 1]) &&
              (closes[i - 3] > closes[i - 4]) &&
              (closes[i - 2] > closes[i - 4]) &&
              (closes[i - 1] > closes[i - 4]) &&
              (body[i] < 0) &&
              (closes[i] < closes[i - 4]))
          ? 1.0
          : 0.0;
    });

    return patterns;
  }
}
