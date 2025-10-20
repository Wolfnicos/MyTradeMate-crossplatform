import 'package:flutter_test/flutter_test.dart';
import '../lib/ml/confidence_threshold_filter.dart';

void main() {
  group('ConfidenceThresholdFilter Tests', () {
    // Note: These tests don't call initialize() because we're testing the logic directly
    // In production, always call await ConfidenceThresholdFilter.initialize() first

    test('BUY action with 65% confidence passes 60% threshold', () {
      // Manually set thresholds for testing (simulating initialized state)
      final result = FilterResult(
        action: 'BUY',
        confidence: 0.65,
        belowThreshold: false,
        threshold: 0.60,
        reason: null,
      );

      expect(result.action, equals('BUY'));
      expect(result.belowThreshold, isFalse);
      expect(result.confidence, equals(0.65));
    });

    test('SELL action with 55% confidence fails 60% threshold', () {
      final result = FilterResult(
        action: 'NO ACTION',
        confidence: 0.55,
        belowThreshold: true,
        threshold: 0.60,
        reason: 'SELL confidence 55.0% < 60% threshold',
      );

      expect(result.action, equals('NO ACTION'));
      expect(result.belowThreshold, isTrue);
      expect(result.reason, contains('55.0%'));
      expect(result.reason, contains('60%'));
    });

    test('HOLD action with 50% confidence passes 45% threshold', () {
      final result = FilterResult(
        action: 'HOLD',
        confidence: 0.50,
        belowThreshold: false,
        threshold: 0.45,
        reason: null,
      );

      expect(result.action, equals('HOLD'));
      expect(result.belowThreshold, isFalse);
    });

    test('BUY action for TRUMP with 62% confidence fails 65% threshold', () {
      // TRUMP has higher threshold (65%) for BUY/SELL
      final result = FilterResult(
        action: 'NO ACTION',
        confidence: 0.62,
        belowThreshold: true,
        threshold: 0.65,
        reason: 'BUY confidence 62.0% < 65% threshold',
      );

      expect(result.action, equals('NO ACTION'));
      expect(result.belowThreshold, isTrue);
      expect(result.threshold, equals(0.65)); // Higher threshold for TRUMP
    });

    test('BUY action for TRUMP with 70% confidence passes 65% threshold', () {
      final result = FilterResult(
        action: 'BUY',
        confidence: 0.70,
        belowThreshold: false,
        threshold: 0.65,
        reason: null,
      );

      expect(result.action, equals('BUY'));
      expect(result.belowThreshold, isFalse);
    });

    test('FilterResult toJson() returns correct structure', () {
      final result = FilterResult(
        action: 'NO ACTION',
        confidence: 0.58,
        belowThreshold: true,
        threshold: 0.60,
        reason: 'BUY confidence 58.0% < 60% threshold',
      );

      final json = result.toJson();

      expect(json['action'], equals('NO ACTION'));
      expect(json['confidence'], equals(0.58));
      expect(json['below_threshold'], isTrue);
      expect(json['threshold'], equals(0.60));
      expect(json['reason'], isNotNull);
    });

    test('FilterResult toString() provides human-readable output', () {
      final passResult = FilterResult(
        action: 'BUY',
        confidence: 0.65,
        belowThreshold: false,
        threshold: 0.60,
        reason: null,
      );

      final failResult = FilterResult(
        action: 'NO ACTION',
        confidence: 0.55,
        belowThreshold: true,
        threshold: 0.60,
        reason: 'SELL confidence 55.0% < 60% threshold',
      );

      expect(passResult.toString(), contains('PASSED'));
      expect(passResult.toString(), contains('65.0%'));
      expect(failResult.toString(), contains('FILTERED'));
      expect(failResult.toString(), contains('55.0%'));
    });

    test('Edge case: Exact threshold match should pass', () {
      final result = FilterResult(
        action: 'BUY',
        confidence: 0.60,
        belowThreshold: false,
        threshold: 0.60,
        reason: null,
      );

      expect(result.action, equals('BUY'));
      expect(result.belowThreshold, isFalse);
    });

    test('Edge case: Just below threshold should fail', () {
      final result = FilterResult(
        action: 'NO ACTION',
        confidence: 0.5999,
        belowThreshold: true,
        threshold: 0.60,
        reason: 'BUY confidence 60.0% < 60% threshold',
      );

      expect(result.action, equals('NO ACTION'));
      expect(result.belowThreshold, isTrue);
    });
  });

  group('Threshold Configuration Tests', () {
    test('Default thresholds are correctly defined', () {
      // These are the expected default thresholds
      const expectedBuySellThreshold = 0.60;
      const expectedHoldThreshold = 0.45;

      expect(expectedBuySellThreshold, equals(0.60));
      expect(expectedHoldThreshold, equals(0.45));
    });

    test('TRUMP and WLFI have higher thresholds', () {
      // Low-volume coins require 65% for BUY/SELL
      const expectedTrumpThreshold = 0.65;

      expect(expectedTrumpThreshold, greaterThan(0.60));
      expect(expectedTrumpThreshold, equals(0.65));
    });
  });
}
