import '../backtest/backtester.dart';

/// Minimal paper broker interface inspired by Superalgos logic.
/// Executes market orders against provided price and maintains balances.
class PaperBroker {
  double quoteBalance; // e.g., USD
  double baseBalance; // e.g., BTC

  PaperBroker({this.quoteBalance = 10000.0, this.baseBalance = 0.0});

  void execute(Trade trade) {
    if (trade.side == 'BUY') {
      final double cost = trade.quantity * trade.price;
      if (quoteBalance >= cost) {
        quoteBalance -= cost;
        baseBalance += trade.quantity;
      }
    } else if (trade.side == 'SELL') {
      if (baseBalance >= trade.quantity) {
        final double proceeds = trade.quantity * trade.price;
        baseBalance -= trade.quantity;
        quoteBalance += proceeds;
      }
    }
  }
}

