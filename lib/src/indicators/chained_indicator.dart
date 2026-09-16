import 'package:flutter/material.dart' show Color;

import '../chart_style.dart';
import '../entity/k_line_entity.dart';
import 'indicator.dart';

/// An indicator computed over another indicator's output rather than over the
/// candles.
///
/// [source] is computed first, one of its lines is taken, and [applied] is run
/// over that as if it were a series of closes — so a moving average of a MACD
/// line, or an RSI of a volume average, is one line of configuration:
///
/// ```dart
/// KChartWidget(
///   candles,
///   ChartColors(),
///   indicators: [
///     ChainedIndicator(
///       source: MacdIndicator(),
///       applied: MaIndicator(period: 9),
///     ),
///   ],
/// );
/// ```
///
/// The values are handed on as flat candles — open, high, low and close all the
/// same — which is what lets any indicator that reads closes be applied.
/// One that reads the range or the volume instead (`ATR`, `OBV`, `MFI`) has
/// nothing to read here and will say so by drawing nothing; that is the
/// caller's choice to make.
///
/// Where the source has no value yet, neither does this: the warm-up of the two
/// adds up rather than the second one starting from a guess.
class ChainedIndicator extends Indicator {
  /// Applies [applied] to line [sourceLine] of [source].
  ChainedIndicator({
    required this.source,
    required this.applied,
    this.sourceLine = 0,
    super.colors,
  });

  /// The indicator whose output is being read.
  final Indicator source;

  /// The indicator run over that output.
  final Indicator applied;

  /// Which of [source]'s lines to read.
  final int sourceLine;

  @override
  IndicatorPlacement get placement => applied.placement;

  @override
  String get name => '${applied.name}(${source.name})';

  @override
  String get label => '${applied.label} of ${source.label}';

  @override
  List<IndicatorLine> get lines => applied.lines;

  @override
  List<Object?> get settings => [
        source.name,
        ...source.settings,
        sourceLine,
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
    final upstream = source.compute(candles);
    if (sourceLine < 0 || sourceLine >= upstream.lines.length) {
      return IndicatorSeries([
        for (var i = 0; i < lines.length; i++)
          List<double?>.filled(candles.length, null),
      ]);
    }

    final values = upstream.lines[sourceLine];
    final series = applied.compute(flattenToCandles(candles, values));

    // The source's own warm-up is carried through: a value computed from
    // nothing upstream is not a value.
    return IndicatorSeries([
      for (final line in series.lines)
        [
          for (var i = 0; i < line.length; i++)
            i < values.length && values[i] == null ? null : line[i],
        ],
    ]);
  }

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      applied.defaultColor(line, theme, ordinal);

  @override
  Color? colorForPoint(
    int line,
    int index,
    KLineEntity candle,
    double value,
    ChartColors theme,
  ) =>
      applied.colorForPoint(line, index, candle, value, theme);

  @override
  String? markerLabel(int line, int index) => applied.markerLabel(line, index);
}

/// Turns [values] into candles an indicator can be run over.
///
/// Open, high, low and close are all the value, so anything that reads closes
/// reads the value — and anything that reads the range reads nothing, which is
/// the honest answer. Times and volumes are carried over from [candles] so the
/// result still lines up with the chart.
///
/// A leading run of nulls is left flat at the first known value rather than at
/// zero, which would look to the applied indicator like a crash and back.
List<KLineEntity> flattenToCandles(
  List<KLineEntity> candles,
  List<double?> values,
) {
  double? held;
  for (final value in values) {
    if (value != null && value.isFinite) {
      held = value;
      break;
    }
  }
  final first = held ?? 0;

  var last = first;
  return [
    for (var i = 0; i < candles.length; i++)
      () {
        final value = i < values.length ? values[i] : null;
        if (value != null && value.isFinite) last = value;
        return KLineEntity.fromCustom(
          open: last,
          high: last,
          low: last,
          close: last,
          vol: candles[i].vol,
          dateTime: candles[i].dateTime ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        );
      }(),
  ];
}
