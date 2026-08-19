import 'package:flutter/material.dart' show Color;

import '../chart_style.dart';
import '../entity/k_line_entity.dart';

/// Where an indicator is drawn.
enum IndicatorPlacement {
  /// Over the candles, on the price scale.
  overlay,

  /// In its own pane below the chart, on its own scale.
  pane,
}

/// How one of an indicator's lines is painted.
enum IndicatorShape {
  /// A continuous stroke through every value.
  line,

  /// One dot per candle.
  dots,

  /// Bars growing from zero.
  histogram,

  /// A stroke from value to value, straight across the candles that have none.
  ///
  /// What a zigzag needs: its values sit only on the pivots, and the line is
  /// the leg between them.
  pivotLine,

  /// A dot per value with the indicator's own text beside it.
  ///
  /// See [Indicator.markerLabel], which is what the text comes from.
  markers,
}

/// A shaded area between two of an indicator's lines, such as an Ichimoku
/// cloud.
class IndicatorFill {
  /// Shades between [line] and [against].
  const IndicatorFill(this.line, this.against);

  /// The line the fill is measured from.
  final int line;

  /// The line it is shaded against.
  final int against;
}

/// How an indicator's values are written out in legends and axis labels.
enum IndicatorFormat {
  /// The chart's `fixedLength` decimals, for values on the price scale.
  price,

  /// Two decimals, for oscillators.
  decimal,

  /// Abbreviated with a K, M or B suffix, for volume-sized values.
  compact,
}

/// One line of an indicator: what it is called and how it is drawn.
class IndicatorLine {
  /// Creates a line description.
  const IndicatorLine(this.label, {this.shape = IndicatorShape.line});

  /// Name shown in the legend, such as `MA5` or `+DI`.
  final String label;

  /// How the line is painted.
  final IndicatorShape shape;
}

/// An indicator's computed values: one list per line, one entry per candle.
///
/// Entries are null where the indicator has not warmed up yet.
class IndicatorSeries {
  /// Creates a series from one list of values per line.
  const IndicatorSeries(this.lines);

  /// Values per line, in the order of the indicator's [Indicator.lines].
  final List<List<double?>> lines;

  /// The value of [line] at [index], or null if there is none.
  double? valueAt(int line, int index) {
    if (line < 0 || line >= lines.length) return null;
    final values = lines[line];
    if (index < 0 || index >= values.length) return null;
    return values[index];
  }
}

/// One configured indicator: a type, its settings, and optionally its colours.
///
/// Add as many as you like, including several of the same kind with different
/// settings — `AtrIndicator(period: 8)`, `AtrIndicator(period: 14)` and
/// `AtrIndicator(period: 20)` are three separate panes:
///
/// ```dart
/// KChartWidget(
///   candles,
///   ChartColors(),
///   isTrendLine: false,
///   watermarkAssetPath: 'assets/logo.svg',
///   timeFrame: const Duration(minutes: 15),
///   indicators: [
///     MaIndicator(period: 50, color: Colors.amber),
///     AtrIndicator(period: 8),
///     AtrIndicator(period: 14),
///   ],
/// );
/// ```
///
/// Two indicators of the same type with the same [settings] are equal, whatever
/// colours they carry. That is what makes re-adding one an edit rather than a
/// duplicate: see `upsert` on a list of indicators, and note that the chart
/// keeps the last of any equal pair it is given.
abstract class Indicator {
  /// Creates an indicator, optionally overriding its line colours.
  Indicator({List<Color>? colors})
    : colors = colors == null ? null : List<Color>.unmodifiable(colors);

  /// Colour per line, in the order of [lines]; null falls back to the theme.
  final List<Color>? colors;

  /// Whether this draws over the candles or in its own pane.
  IndicatorPlacement get placement;

  /// Short name of the indicator type, such as `ATR`.
  String get name;

  /// Name with its settings, such as `ATR(14)`.
  String get label;

  /// Legend row overlays share; instances with the same group sit on one row.
  String get group => name;

  /// The lines this indicator draws.
  List<IndicatorLine> get lines;

  /// The settings that, with the type, make one indicator distinct.
  ///
  /// Colours are deliberately left out, so re-adding an indicator with a new
  /// colour updates the one already there.
  List<Object?> get settings;

  /// Computes one value per candle for each of [lines].
  IndicatorSeries compute(List<KLineEntity> candles);

  /// Areas shaded between two lines, drawn under them.
  List<IndicatorFill> get fills => const [];

  /// Colour of [fill], which may differ with which of its lines is on top.
  ///
  /// [isAbove] is whether `fill.line` currently sits above `fill.against` —
  /// what turns an Ichimoku cloud from green to red.
  Color fillColor(
    IndicatorFill fill,
    ChartColors theme, {
    required bool isAbove,
  }) => (isAbove ? theme.upColor : theme.dnColor).withValues(alpha: 0.12);

  /// Text drawn beside the point at [index] on [line], for a marker series.
  ///
  /// Returns null where the point has no label. Only [IndicatorShape.markers]
  /// looks at it.
  String? markerLabel(int line, int index) => null;

  /// Levels to draw a faint guide line at, such as 30 and 70 for an RSI.
  List<double> get guides => const [];

  /// A scale to pin the pane to, rather than fitting it to the values.
  (double, double)? get fixedRange => null;

  /// Whether the pane's scale must include zero, as a histogram needs.
  bool get includeZero => false;

  /// How values are written out.
  IndicatorFormat get format => IndicatorFormat.decimal;

  /// Colour of [line], preferring what the caller gave over the theme.
  ///
  /// [ordinal] is the indicator's position among others of its [group], which
  /// is how repeated moving averages pick up different theme colours.
  Color colorFor(int line, ChartColors theme, {int ordinal = 0}) {
    final overrides = colors;
    if (overrides != null && line < overrides.length) return overrides[line];
    return defaultColor(line, theme, ordinal);
  }

  /// Theme colour for [line] when the caller has not chosen one.
  Color defaultColor(int line, ChartColors theme, int ordinal);

  /// Colour for a single point, where it differs from the line's colour.
  ///
  /// Returns null to use the line colour. Lets a histogram take the up and down
  /// colours, or SAR dots flip with the trend.
  Color? colorForPoint(
    int line,
    int index,
    KLineEntity candle,
    double value,
    ChartColors theme,
  ) => null;

  @override
  bool operator ==(Object other) =>
      other is Indicator &&
      other.runtimeType == runtimeType &&
      _sameSettings(other.settings, settings);

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(settings));

  @override
  String toString() => label;

  static bool _sameSettings(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Editing helpers for a list of indicators.
extension IndicatorListEditing on List<Indicator> {
  /// Adds [indicator], or replaces the equal one already in the list.
  ///
  /// Equality ignores colours, so adding `AtrIndicator(period: 14)` in a new
  /// colour restyles the ATR(14) that is already there — in its existing
  /// position — rather than stacking a second, identical pane. Returns true
  /// when an existing indicator was replaced.
  bool upsert(Indicator indicator) {
    final at = indexOf(indicator);
    if (at == -1) {
      add(indicator);
      return false;
    }
    this[at] = indicator;
    return true;
  }

  /// Removes [indicator] if the list holds it, and reports whether it did.
  bool removeIndicator(Indicator indicator) => remove(indicator);

  /// Adds [indicator] if it is missing, removes it if it is present.
  ///
  /// Returns true when the indicator ends up in the list.
  bool toggle(Indicator indicator) {
    if (remove(indicator)) return false;
    add(indicator);
    return true;
  }
}
