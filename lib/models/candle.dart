class Candle {
  final DateTime openTime;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final DateTime closeTime;

  const Candle({
    required this.openTime,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.closeTime,
  });
}

