mixin CandleEntity {
  late double open;
  late double high;
  late double low;
  late double close;

  /// Simple moving averages, one per period in the chart's `maDayList`.
  List<double>? maValueList;

  /// Exponential moving averages, one per period in the chart's `maDayList`.
  List<double>? emaValueList;

  /// Volume-weighted average price, accumulated from the first candle.
  double? vwap;

  double? sar;
  double? up;
  double? mb;
  double? dn;
  double? bollMa;
}
