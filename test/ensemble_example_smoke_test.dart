import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ml/ensemble_example.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Run EnsembleExample for TRUMP@1h and ADA@1h and print final JSON', () async {
    final example = EnsembleExample();

    final trump = await example.getPredictionTRUMP();
    // Emit a machine-readable JSON line for easy grepping
    // Expected keys: action, confidence, risk, atr, models_used, threshold_filter
    // The example already prints a pretty JSON; this is an extra compact line
    // to verify quickly in CI or logs.
    // Format: JSON_TRUMP: { ... }
    // ignore: avoid_print
    print('JSON_TRUMP: ' + jsonEncode(trump));

    final ada = await example.getPredictionADA();
    // ignore: avoid_print
    print('JSON_ADA: ' + jsonEncode(ada));

    // Basic sanity checks (action present)
    expect(trump.containsKey('action'), true);
    expect(ada.containsKey('action'), true);
  });
}


