import 'package:ohlcv_chart/ohlcv_chart.dart';

/// On-balance volume in a pane spaced by ratio rather than evenly.
///
/// OBV runs over orders of magnitude on a long chart, so a linear pane spends
/// most of its height on the last few candles. Overriding one getter is all it
/// takes to read it the other way.
class LogObvIndicator extends ObvIndicator {
  @override
  String get name => 'OBVLOG';

  @override
  String get label => 'OBV (log)';

  @override
  IndicatorScale get scale => IndicatorScale.logarithmic;
}

/// An RSI that reports when it crosses the levels it is read against.
///
/// The same 14-period RSI, with two alerts on it — which is all an indicator
/// has to declare for the chart to watch them.
class AlertingRsiIndicator extends RsiIndicator {
  AlertingRsiIndicator() : super(period: 14);

  @override
  String get name => 'RSIALERT';

  @override
  String get label => 'RSI(14) with alerts';

  @override
  List<IndicatorAlert> get alerts => const [
    IndicatorAlert(level: 70, label: 'overbought'),
    IndicatorAlert(level: 30, label: 'oversold'),
  ];
}
