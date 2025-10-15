/// Computes RSI vector for [closes].
/// Returns a list of nullable doubles aligned with [closes] where the first
/// [period] entries are null (insufficient data).
List<double?> computeRsi(List<double> closes, {int period = 14}) {
  if (closes.length < period + 1) return List<double?>.filled(closes.length, null);

  final List<double?> rsi = List<double?>.filled(closes.length, null);
  double gainSum = 0;
  double lossSum = 0;

  for (int i = 1; i <= period; i++) {
    final double change = closes[i] - closes[i - 1];
    if (change >= 0) {
      gainSum += change;
    } else {
      lossSum += -change;
    }
  }

  double avgGain = gainSum / period;
  double avgLoss = lossSum / period;
  rsi[period] = _calcRsi(avgGain, avgLoss);

  for (int i = period + 1; i < closes.length; i++) {
    final double change = closes[i] - closes[i - 1];
    final double gain = change > 0 ? change : 0.0;
    final double loss = change < 0 ? -change : 0.0;
    avgGain = (avgGain * (period - 1) + gain) / period;
    avgLoss = (avgLoss * (period - 1) + loss) / period;
    rsi[i] = _calcRsi(avgGain, avgLoss);
  }

  return rsi;
}

double _calcRsi(double avgGain, double avgLoss) {
  if (avgLoss == 0) return 100.0;
  final double rs = avgGain / avgLoss;
  return 100.0 - (100.0 / (1.0 + rs));
}

