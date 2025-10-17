import '../models/candle.dart';

/// Service for validating market data quality before feeding to AI models
///
/// Why this matters:
/// - Bad data → bad predictions
/// - Missing candles, outliers, stale data can all corrupt ML model output
/// - Silent failures are dangerous (model runs but gives nonsense predictions)
///
/// This validator catches issues BEFORE they reach the model.
class DataValidator {
  // Validation thresholds
  static const Duration _maxDataAge = Duration(hours: 2);
  static const double _maxPriceChangePercent = 0.15; // 15% max per candle
  static const int _minRequiredCandles = 60; // Minimum for 60-timestep model

  /// Validate a list of candles for quality
  ///
  /// Returns ValidationResult with:
  /// - isValid: true if data passes all checks
  /// - errors: List of error messages
  /// - warnings: List of warning messages
  /// - quality: 0.0 (worst) to 1.0 (perfect)
  ValidationResult validateCandles(
    List<Candle> candles, {
    String? symbol,
    String? timeframe,
  }) {
    final errors = <String>[];
    final warnings = <String>[];
    double qualityScore = 1.0;

    // Check 1: Minimum data requirement
    if (candles.isEmpty) {
      errors.add('No candles provided');
      return ValidationResult(
        isValid: false,
        errors: errors,
        warnings: warnings,
        quality: 0.0,
      );
    }

    if (candles.length < _minRequiredCandles) {
      errors.add(
          'Insufficient data: ${candles.length} candles (need at least $_minRequiredCandles)');
      qualityScore -= 0.5;
    }

    // Check 2: Data freshness
    final latestCandle = candles.last;
    final dataAge = DateTime.now().difference(latestCandle.closeTime);

    if (dataAge > _maxDataAge) {
      errors.add(
          'Stale data: Last candle is ${dataAge.inMinutes} minutes old (max: ${_maxDataAge.inMinutes} minutes)');
      qualityScore -= 0.3;
    } else if (dataAge > Duration(minutes: 30)) {
      warnings.add('Data is ${dataAge.inMinutes} minutes old (consider refreshing)');
      qualityScore -= 0.1;
    }

    // Check 3: Chronological order
    for (int i = 1; i < candles.length; i++) {
      if (candles[i].openTime.isBefore(candles[i - 1].openTime)) {
        errors.add('Candles not in chronological order at index $i');
        qualityScore -= 0.2;
        break;
      }
    }

    // Check 4: Gaps in data
    if (candles.length > 1) {
      final gaps = _detectGaps(candles, timeframe);
      if (gaps.isNotEmpty) {
        for (final gap in gaps) {
          warnings.add('Gap detected: ${gap.missedCandles} candles missing at ${gap.timestamp}');
          qualityScore -= 0.05 * gap.missedCandles;
        }
      }
    }

    // Check 5: Price outliers (flash crashes, fat-finger trades)
    final outliers = _detectPriceOutliers(candles);
    if (outliers.isNotEmpty) {
      for (final outlier in outliers) {
        warnings.add(
            'Price outlier at index ${outlier.index}: ${outlier.changePercent.toStringAsFixed(1)}% change (${outlier.reason})');
        qualityScore -= 0.1;
      }
    }

    // Check 6: Zero/negative values
    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      if (c.open <= 0 || c.high <= 0 || c.low <= 0 || c.close <= 0) {
        errors.add('Invalid price at index $i: zero or negative values');
        qualityScore -= 0.2;
      }
      if (c.volume < 0) {
        errors.add('Negative volume at index $i');
        qualityScore -= 0.1;
      }
    }

    // Check 7: High-Low sanity
    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      if (c.high < c.low) {
        errors.add('Invalid candle at index $i: high ($c.high) < low ($c.low)');
        qualityScore -= 0.2;
      }
      if (c.open > c.high || c.open < c.low) {
        errors.add('Invalid candle at index $i: open outside high-low range');
        qualityScore -= 0.2;
      }
      if (c.close > c.high || c.close < c.low) {
        errors.add('Invalid candle at index $i: close outside high-low range');
        qualityScore -= 0.2;
      }
    }

    // Check 8: Duplicate timestamps
    final timestamps = candles.map((c) => c.openTime.millisecondsSinceEpoch).toSet();
    if (timestamps.length < candles.length) {
      warnings.add('Duplicate timestamps detected (${candles.length - timestamps.length} duplicates)');
      qualityScore -= 0.15;
    }

    // Clamp quality score
    qualityScore = qualityScore.clamp(0.0, 1.0);

    // Determine overall validity
    final isValid = errors.isEmpty && qualityScore >= 0.5;

    return ValidationResult(
      isValid: isValid,
      errors: errors,
      warnings: warnings,
      quality: qualityScore,
      symbol: symbol,
      timeframe: timeframe,
      candleCount: candles.length,
      dataAge: dataAge,
    );
  }

  /// Detect gaps in candle data
  List<DataGap> _detectGaps(List<Candle> candles, String? timeframe) {
    final gaps = <DataGap>[];

    // Determine expected interval between candles
    Duration expectedInterval;
    switch (timeframe?.toLowerCase()) {
      case '1m':
        expectedInterval = const Duration(minutes: 1);
        break;
      case '5m':
        expectedInterval = const Duration(minutes: 5);
        break;
      case '15m':
        expectedInterval = const Duration(minutes: 15);
        break;
      case '1h':
        expectedInterval = const Duration(hours: 1);
        break;
      case '4h':
        expectedInterval = const Duration(hours: 4);
        break;
      case '1d':
        expectedInterval = const Duration(days: 1);
        break;
      default:
        // If timeframe unknown, infer from data
        if (candles.length >= 2) {
          expectedInterval = candles[1].openTime.difference(candles[0].openTime);
        } else {
          return gaps; // Can't detect gaps with < 2 candles
        }
    }

    // Check intervals between consecutive candles
    for (int i = 1; i < candles.length; i++) {
      final actualInterval = candles[i].openTime.difference(candles[i - 1].openTime);
      final toleranceMs = expectedInterval.inMilliseconds * 0.1; // 10% tolerance

      if ((actualInterval.inMilliseconds - expectedInterval.inMilliseconds).abs() > toleranceMs) {
        final missedCandles =
            (actualInterval.inMilliseconds / expectedInterval.inMilliseconds).round() - 1;
        if (missedCandles > 0) {
          gaps.add(DataGap(
            timestamp: candles[i - 1].openTime,
            missedCandles: missedCandles,
            expectedInterval: expectedInterval,
            actualInterval: actualInterval,
          ));
        }
      }
    }

    return gaps;
  }

  /// Detect price outliers (flash crashes, erroneous data)
  List<PriceOutlier> _detectPriceOutliers(List<Candle> candles) {
    final outliers = <PriceOutlier>[];

    for (int i = 1; i < candles.length; i++) {
      final prevClose = candles[i - 1].close;
      final currentOpen = candles[i].open;
      final currentClose = candles[i].close;

      // Check open vs previous close (gap)
      final gapPercent = ((currentOpen - prevClose) / prevClose).abs();
      if (gapPercent > _maxPriceChangePercent) {
        outliers.add(PriceOutlier(
          index: i,
          changePercent: gapPercent * 100,
          reason: 'Large gap: ${gapPercent > 0 ? 'up' : 'down'} ${(gapPercent * 100).toStringAsFixed(1)}%',
        ));
      }

      // Check close vs open (candle body)
      final bodyPercent = ((currentClose - currentOpen) / currentOpen).abs();
      if (bodyPercent > _maxPriceChangePercent) {
        outliers.add(PriceOutlier(
          index: i,
          changePercent: bodyPercent * 100,
          reason: 'Large candle body: ${(bodyPercent * 100).toStringAsFixed(1)}%',
        ));
      }

      // Check wicks (high-low vs close)
      final wickPercent = ((candles[i].high - candles[i].low) / candles[i].close).abs();
      if (wickPercent > _maxPriceChangePercent * 1.5) {
        outliers.add(PriceOutlier(
          index: i,
          changePercent: wickPercent * 100,
          reason: 'Extreme wick: ${(wickPercent * 100).toStringAsFixed(1)}%',
        ));
      }
    }

    return outliers;
  }

  /// Validate multi-timeframe data alignment
  ///
  /// Ensures that 15m, 1h, and 4h candles are properly aligned
  ValidationResult validateMultiTimeframeAlignment({
    required List<Candle> base1h,
    required List<Candle> low15m,
    required List<Candle> high4h,
  }) {
    final errors = <String>[];
    final warnings = <String>[];
    double qualityScore = 1.0;

    // Validate each timeframe individually
    final base1hValidation = validateCandles(base1h, timeframe: '1h');
    final low15mValidation = validateCandles(low15m, timeframe: '15m');
    final high4hValidation = validateCandles(high4h, timeframe: '4h');

    if (!base1hValidation.isValid) {
      errors.add('Base 1h data invalid: ${base1hValidation.errors.join(', ')}');
      qualityScore -= 0.4;
    }
    if (!low15mValidation.isValid) {
      errors.add('Low 15m data invalid: ${low15mValidation.errors.join(', ')}');
      qualityScore -= 0.3;
    }
    if (!high4hValidation.isValid) {
      errors.add('High 4h data invalid: ${high4hValidation.errors.join(', ')}');
      qualityScore -= 0.3;
    }

    // Check timestamp alignment (15m should align to hour boundaries)
    if (low15m.isNotEmpty) {
      final latest15m = low15m.last.openTime;
      if (latest15m.minute % 15 != 0) {
        warnings.add('15m candles not aligned to 15-minute boundaries');
        qualityScore -= 0.1;
      }
    }

    // Check timestamp alignment (4h should align to 4-hour boundaries)
    if (high4h.isNotEmpty) {
      final latest4h = high4h.last.openTime;
      if (latest4h.hour % 4 != 0 || latest4h.minute != 0) {
        warnings.add('4h candles not aligned to 4-hour boundaries');
        qualityScore -= 0.1;
      }
    }

    // Check data freshness consistency
    if (base1h.isNotEmpty && low15m.isNotEmpty) {
      final base1hAge = DateTime.now().difference(base1h.last.closeTime);
      final low15mAge = DateTime.now().difference(low15m.last.closeTime);

      if ((base1hAge.inMinutes - low15mAge.inMinutes).abs() > 60) {
        warnings.add('Timeframe data age mismatch (1h vs 15m: ${base1hAge.inMinutes}m vs ${low15mAge.inMinutes}m)');
        qualityScore -= 0.15;
      }
    }

    qualityScore = qualityScore.clamp(0.0, 1.0);
    final isValid = errors.isEmpty && qualityScore >= 0.6;

    return ValidationResult(
      isValid: isValid,
      errors: errors,
      warnings: warnings,
      quality: qualityScore,
    );
  }
}

/// Validation result
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final double quality; // 0.0 to 1.0

  // Optional metadata
  final String? symbol;
  final String? timeframe;
  final int? candleCount;
  final Duration? dataAge;

  ValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    required this.quality,
    this.symbol,
    this.timeframe,
    this.candleCount,
    this.dataAge,
  });

  /// Get quality rating as text
  String get qualityRating {
    if (quality >= 0.9) return 'Excellent';
    if (quality >= 0.75) return 'Good';
    if (quality >= 0.6) return 'Fair';
    if (quality >= 0.4) return 'Poor';
    return 'Critical';
  }

  /// Get color for UI display
  String get qualityColor {
    if (quality >= 0.8) return 'green';
    if (quality >= 0.6) return 'yellow';
    return 'red';
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('=== Data Validation Report ===');
    if (symbol != null) buffer.writeln('Symbol: $symbol');
    if (timeframe != null) buffer.writeln('Timeframe: $timeframe');
    if (candleCount != null) buffer.writeln('Candles: $candleCount');
    if (dataAge != null) buffer.writeln('Data Age: ${dataAge!.inMinutes} minutes');
    buffer.writeln('Valid: $isValid');
    buffer.writeln('Quality: ${(quality * 100).toStringAsFixed(1)}% ($qualityRating)');

    if (errors.isNotEmpty) {
      buffer.writeln('\nErrors:');
      for (final error in errors) {
        buffer.writeln('  ❌ $error');
      }
    }

    if (warnings.isNotEmpty) {
      buffer.writeln('\nWarnings:');
      for (final warning in warnings) {
        buffer.writeln('  ⚠️  $warning');
      }
    }

    return buffer.toString();
  }
}

/// Data gap information
class DataGap {
  final DateTime timestamp;
  final int missedCandles;
  final Duration expectedInterval;
  final Duration actualInterval;

  DataGap({
    required this.timestamp,
    required this.missedCandles,
    required this.expectedInterval,
    required this.actualInterval,
  });
}

/// Price outlier information
class PriceOutlier {
  final int index;
  final double changePercent;
  final String reason;

  PriceOutlier({
    required this.index,
    required this.changePercent,
    required this.reason,
  });
}

/// Example usage:
///
/// ```dart
/// final validator = DataValidator();
///
/// // Validate single timeframe
/// final candles = await binanceService.fetchHourlyKlines('BTCUSDT');
/// final result = validator.validateCandles(candles, symbol: 'BTCUSDT', timeframe: '1h');
///
/// if (!result.isValid) {
///   print('⚠️ Data quality issues detected!');
///   print(result);
///   // Don't feed to model, fetch fresh data
/// } else if (result.warnings.isNotEmpty) {
///   print('⚠️ Data quality warnings: ${result.warnings}');
///   // Can use, but with caution
/// } else {
///   print('✅ Data quality excellent (${result.quality * 100}%)');
///   // Safe to use
/// }
///
/// // Validate multi-timeframe alignment
/// final mtfResult = validator.validateMultiTimeframeAlignment(
///   base1h: hourlyCandles,
///   low15m: fifteenMinCandles,
///   high4h: fourHourCandles,
/// );
///
/// if (mtfResult.isValid) {
///   // Proceed with feature building
///   final features = mtfFeatureBuilder.buildFeatures(...);
/// } else {
///   print('❌ Multi-timeframe alignment issues: ${mtfResult.errors}');
/// }
/// ```
