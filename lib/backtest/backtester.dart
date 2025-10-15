import '../indicators/rsi.dart';
import '../ml/tflite_predictor.dart';
import '../models/candle.dart';

class Trade {
  final DateTime time;
  final String side; // 'BUY' or 'SELL'
  final double price;
  final double quantity; // quote or base? We'll treat base size units

  const Trade({
    required this.time,
    required this.side,
    required this.price,
    required this.quantity,
  });
}

class BacktestResult {
  final List<Trade> trades;
  final double pnl;
  final int numBuys;
  final int numSells;

  const BacktestResult({
    required this.trades,
    required this.pnl,
    required this.numBuys,
    required this.numSells,
  });
}

class RsiHybridBacktester {
  final int rsiPeriod;
  final double rsiBuyThreshold;
  final double rsiSellThreshold;
  final double positionSizeUsd; // fixed position size for simplicity
  final TFLitePredictor predictor;

  const RsiHybridBacktester({
    required this.rsiPeriod,
    required this.rsiBuyThreshold,
    required this.rsiSellThreshold,
    required this.positionSizeUsd,
    required this.predictor,
  });

  /// Simple long-only strategy: when RSI < 30 and NN prob > 0.55 => BUY;
  /// when RSI > 70 or NN prob < 0.45 => SELL (close position).
  BacktestResult run(List<Candle> candles) {
    if (candles.isEmpty) {
      return const BacktestResult(trades: [], pnl: 0.0, numBuys: 0, numSells: 0);
    }
    final List<double> closes = candles.map((c) => c.close).toList(growable: false);
    final List<double?> rsi = computeRsi(closes, period: rsiPeriod);

    final List<Trade> trades = <Trade>[];
    double basePosition = 0.0; // e.g., BTC amount
    double cashUsd = 0.0; // P&L accumulator in quote currency (USD)
    int numBuys = 0;
    int numSells = 0;

    for (int i = 0; i < candles.length; i++) {
      final Candle c = candles[i];
      final double? r = rsi[i];
      if (r == null) continue;

      // Basic features: normalized RSI and simple return momentum
      final double rsiNorm = (r / 100.0).clamp(0.0, 1.0);
      final double ret1 = i > 0 ? (closes[i] / closes[i - 1] - 1.0) : 0.0;
      final double probUp = predictor.predictBullishProbability(<double>[rsiNorm, ret1]);

      final bool shouldBuy = r < rsiBuyThreshold && probUp > 0.55 && basePosition == 0.0;
      final bool shouldSell = (r > rsiSellThreshold || probUp < 0.45) && basePosition > 0.0;

      if (shouldBuy) {
        final double qty = positionSizeUsd / c.close;
        basePosition += qty;
        trades.add(Trade(time: c.closeTime, side: 'BUY', price: c.close, quantity: qty));
        numBuys++;
      } else if (shouldSell) {
        final double proceeds = basePosition * c.close;
        // Close entire position
        trades.add(Trade(time: c.closeTime, side: 'SELL', price: c.close, quantity: basePosition));
        cashUsd += proceeds - positionSizeUsd; // realized P&L for this round-trip
        basePosition = 0.0;
        numSells++;
      }
    }

    // Mark-to-market any remaining position at last close
    if (basePosition > 0.0) {
      final Candle last = candles.last;
      final double proceeds = basePosition * last.close;
      cashUsd += proceeds - positionSizeUsd;
      trades.add(Trade(time: last.closeTime, side: 'SELL', price: last.close, quantity: basePosition));
      basePosition = 0.0;
      numSells++;
    }

    return BacktestResult(trades: trades, pnl: cashUsd, numBuys: numBuys, numSells: numSells);
  }
}

