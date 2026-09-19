import 'package:flutter/material.dart' show Color;

import '../chart_style.dart';
import '../entity/k_line_entity.dart';
import '../utils/candle_transforms.dart';
import 'indicator.dart';

/// An indicator computed on a higher timeframe than the chart is drawn at.
///
/// The candles are aggregated up to [timeframe], [applied] is computed over
/// those bars, and each value is read back against the candles it covers — so
/// a daily moving average can be read on a fifteen-minute chart:
///
/// ```dart
/// KChartWidget(
///   candles,
///   ChartColors(),
///   isTrendLine: false,
///   timeFrame: const Duration(minutes: 15),
///   indicators: [
///     TimeframeIndicator(
///       timeframe: const Duration(days: 1),
///       applied: MaIndicator(period: 20),
///     ),
///   ],
/// );
/// ```
///
/// ## What it draws, and what it will not
///
/// Each candle reads the value of the last higher-timeframe bar that had
/// *closed* by the time that candle opened. The line therefore steps once per
/// higher-timeframe bar and holds flat between, and the candles of the first
/// bar have nothing behind them and draw nothing.
///
/// That is a deliberate choice over the alternative. Reading the bar a candle
/// is *inside* would mean this morning's candles showing a value computed from
/// this afternoon's — the whole day's high, low and close are in it — which
/// reads as uncanny foresight when backtesting and then repaints as the day
/// fills in. The value here is one that was genuinely known at the time, and it
/// never changes once drawn.
///
/// A [timeframe] finer than the candles themselves gives one bar per candle,
/// which is the plain indicator with an extra candle of delay; use [applied] on
/// its own instead.
class TimeframeIndicator extends Indicator {
  /// Computes [applied] over candles aggregated up to [timeframe].
  TimeframeIndicator({
    required this.timeframe,
    required this.applied,
    super.colors,
  });

  /// The bar size the indicator is computed on.
  final Duration timeframe;

  /// The indicator run over the aggregated bars.
  final Indicator applied;

  @override
  IndicatorPlacement get placement => applied.placement;

  @override
  String get name => '${applied.name}@${formatTimeframe(timeframe)}';

  @override
  String get label => '${applied.label} @ ${formatTimeframe(timeframe)}';

  /// The applied indicator's lines, each named with the timeframe.
  ///
  /// Without this a daily `MA20` and the chart's own `MA20` are two legend rows
  /// reading exactly alike, which is the one thing a reader has to be able to
  /// tell apart here.
  @override
  List<IndicatorLine> get lines => [
    for (final line in applied.lines)
      IndicatorLine(
        '${line.label}@${formatTimeframe(timeframe)}',
        shape: line.shape,
      ),
  ];

  @override
  List<Object?> get settings => [
    timeframe.inMilliseconds,
    applied.name,
    ...applied.settings,
  ];

  @override
  List<double> get guides => applied.guides;

  @override
  (double, double)? get fixedRange => applied.fixedRange;

  @override
  bool get includeZero => applied.includeZero;

  @override
  IndicatorScale get scale => applied.scale;

  @override
  List<IndicatorAlert> get alerts => applied.alerts;

  @override
  IndicatorFormat get format => applied.format;

  @override
  List<IndicatorFill> get fills => applied.fills;

  @override
  IndicatorSeries compute(List<KLineEntity> candles) {
    final blank = IndicatorSeries([
      for (var i = 0; i < lines.length; i++)
        List<double?>.filled(candles.length, null),
    ]);
    if (candles.isEmpty || timeframe <= Duration.zero) return blank;

    final buckets = CandleTransforms.bucketIndices(candles, timeframe);
    final bars = CandleTransforms.resample(candles, timeframe);
    if (bars.isEmpty) return blank;

    final higher = applied.compute(bars);

    return IndicatorSeries([
      for (final line in higher.lines)
        [
          for (var i = 0; i < candles.length; i++)
            // The bar before the one this candle sits in: the last that had
            // closed when the candle opened.
            _at(line, buckets[i] - 1),
        ],
    ]);
  }

  /// The value at [index], or null where there is none to read.
  static double? _at(List<double?> line, int index) =>
      index < 0 || index >= line.length ? null : line[index];

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      applied.defaultColor(line, theme, ordinal);

  @override
  String? markerLabel(int line, int index) => applied.markerLabel(line, index);
}

/// Writes a bar size the way a trading platform does: `15m`, `4h`, `1D`, `1W`.
///
/// The units step at the point the next one reads better, so 90 minutes is
/// `90m` rather than `1.5h`, and a fortnight is `2W`.
String formatTimeframe(Duration timeframe) {
  if (timeframe <= Duration.zero) return '0';
  if (timeframe.inDays >= 365 && timeframe.inDays % 365 == 0) {
    return '${timeframe.inDays ~/ 365}Y';
  }
  if (timeframe.inDays >= 30 && timeframe.inDays % 30 == 0) {
    return '${timeframe.inDays ~/ 30}M';
  }
  if (timeframe.inDays >= 7 && timeframe.inDays % 7 == 0) {
    return '${timeframe.inDays ~/ 7}W';
  }
  if (timeframe.inHours >= 24 && timeframe.inHours % 24 == 0) {
    return '${timeframe.inDays}D';
  }
  if (timeframe.inMinutes >= 60 && timeframe.inMinutes % 60 == 0) {
    return '${timeframe.inHours}h';
  }
  if (timeframe.inSeconds >= 60 && timeframe.inSeconds % 60 == 0) {
    return '${timeframe.inMinutes}m';
  }
  return '${timeframe.inSeconds}s';
}
