import 'package:ohlcv_chart/ohlcv_chart.dart';

/// Builds a candle whose OHLC is derived from a single [close] price.
KLineEntity candle(
  double close, {
  double? open,
  double? high,
  double? low,
  double vol = 100,
  int minute = 0,
}) {
  return KLineEntity.fromCustom(
    open: open ?? close,
    high: high ?? close + 1,
    low: low ?? close - 1,
    close: close,
    vol: vol,
    dateTime: DateTime.utc(2024, 1, 1).add(Duration(minutes: minute)),
  );
}

/// Builds [count] candles from [closes]-style generator, timestamped in order.
List<KLineEntity> candles(List<double> closes) {
  return [for (var i = 0; i < closes.length; i++) candle(closes[i], minute: i)];
}

/// A simple deterministic price walk, useful for smoke-testing indicators.
List<double> rampThenFall(int count) {
  return [
    for (var i = 0; i < count; i++)
      i < count / 2 ? 100.0 + i : 100.0 + count - i,
  ];
}
