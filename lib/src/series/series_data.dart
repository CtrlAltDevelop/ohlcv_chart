import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// One value on a [SeriesChart]'s plot.
///
/// [x] is any number — an index, a day count, a price — and [y] is the value
/// drawn against it. A null or non-finite [y] is a gap: a line breaks there
/// and a bar is left out.
@immutable
class SeriesPoint {
  /// Creates the point ([x], [y]).
  const SeriesPoint(this.x, this.y);

  /// Where the point sits along the horizontal axis.
  final double x;

  /// The value, or null for a gap.
  final double? y;

  /// Whether there is no value here to draw.
  bool get isGap {
    final value = y;
    return value == null || !value.isFinite;
  }

  @override
  bool operator ==(Object other) =>
      other is SeriesPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'SeriesPoint($x, $y)';
}

/// Points at `x = 0, 1, 2, …` for a list of plain values.
List<SeriesPoint> pointsOf(List<double?> values) => [
  for (var i = 0; i < values.length; i++) SeriesPoint(i.toDouble(), values[i]),
];

/// How a [LineSeries] joins one point to the next.
enum LineCurve {
  /// Straight segments.
  linear,

  /// A curve through every point that can swing past a peak or a trough
  /// between two points — `fl_chart`'s `isCurved`.
  smooth,

  /// A curve through every point that never swings past its neighbours, so a
  /// peak on the line is a peak in the data — `fl_chart`'s `isCurved` with
  /// `preventCurveOverShooting`.
  monotone,

  /// Holds each value flat until the next point, then steps to it.
  step,
}

/// A dot drawn on a point.
@immutable
class SeriesDot {
  /// Creates a dot of [radius], filled with [color] and ringed by
  /// [strokeColor].
  const SeriesDot({
    this.radius = 3,
    this.color,
    this.strokeColor,
    this.strokeWidth = 0,
  });

  /// Radius in logical pixels.
  final double radius;

  /// Fill colour; null uses the series colour at that value.
  final Color? color;

  /// Ring colour; null draws no ring.
  final Color? strokeColor;

  /// Ring width; 0 draws no ring.
  final double strokeWidth;

  @override
  bool operator ==(Object other) =>
      other is SeriesDot &&
      other.radius == radius &&
      other.color == color &&
      other.strokeColor == strokeColor &&
      other.strokeWidth == strokeWidth;

  @override
  int get hashCode => Object.hash(radius, color, strokeColor, strokeWidth);
}

/// Decides the dot for one point, or returns null to leave it without one.
typedef SeriesDotBuilder = SeriesDot? Function(int index, SeriesPoint point);

/// The area between a [LineSeries] and its baseline, or the bottom of the plot.
///
/// A fill anchored to the baseline never paints across it. The stretch above
/// is painted with [gradient] (or [color]) measured from the line's highest
/// point down to the baseline, so it fades out exactly at the baseline; the
/// stretch below is painted with [negativeGradient] (or [negativeColor]),
/// measured from the baseline down to the line's lowest point. Left unset, the
/// part below reuses the upper gradient turned upside down, so both halves
/// fade away from the line the same way.
@immutable
class SeriesFill {
  /// Creates a fill.
  const SeriesFill({
    this.color,
    this.gradient,
    this.negativeColor,
    this.negativeGradient,
    this.toBaseline = true,
    this.mirrorBelowBaseline = true,
  });

  /// A vertical fade from [color] at [opacity] under the line to transparent
  /// at the baseline.
  factory SeriesFill.fade(
    Color color, {
    double opacity = 0.24,
    Color? negativeColor,
    bool toBaseline = true,
  }) => SeriesFill(
    gradient: _fade(color, opacity),
    negativeGradient: negativeColor == null
        ? null
        : _fade(negativeColor, opacity, upward: true),
    toBaseline: toBaseline,
  );

  static LinearGradient _fade(
    Color color,
    double opacity, {
    bool upward = false,
  }) => LinearGradient(
    begin: upward ? Alignment.bottomCenter : Alignment.topCenter,
    end: upward ? Alignment.topCenter : Alignment.bottomCenter,
    colors: [
      color.withValues(alpha: opacity),
      color.withValues(alpha: 0),
    ],
  );

  /// Flat colour above the baseline; ignored when [gradient] is set.
  final Color? color;

  /// Gradient above the baseline, top of the line to the baseline.
  final Gradient? gradient;

  /// Flat colour below the baseline; null follows [color].
  final Color? negativeColor;

  /// Gradient below the baseline, baseline to the bottom of the line; null
  /// follows [gradient], mirrored when [mirrorBelowBaseline] is set.
  final Gradient? negativeGradient;

  /// Fills to the series' `baseline` when true, and to the bottom of the plot
  /// when false.
  final bool toBaseline;

  /// Whether the part below the baseline turns [gradient] upside down.
  final bool mirrorBelowBaseline;

  @override
  bool operator ==(Object other) =>
      other is SeriesFill &&
      other.color == color &&
      other.gradient == gradient &&
      other.negativeColor == negativeColor &&
      other.negativeGradient == negativeGradient &&
      other.toBaseline == toBaseline &&
      other.mirrorBelowBaseline == mirrorBelowBaseline;

  @override
  int get hashCode => Object.hash(
    color,
    gradient,
    negativeColor,
    negativeGradient,
    toBaseline,
    mirrorBelowBaseline,
  );
}

const Color _defaultSeriesColor = Color(0xFF4C86CD);

/// One set of values on a [SeriesChart]: a [LineSeries] or a [BarSeries].
///
/// Points are read in order and should run from the lowest x to the highest.
sealed class PlotSeries {
  const PlotSeries({
    required this.points,
    this.label,
    this.color = _defaultSeriesColor,
    this.negativeColor,
    this.baseline = 0,
    this.showInTooltip = true,
  });

  /// The values, lowest x first.
  final List<SeriesPoint> points;

  /// A name for the series, shown by the default tooltip.
  final String? label;

  /// The series colour.
  final Color color;

  /// The colour of whatever lies below [baseline]; null keeps [color].
  final Color? negativeColor;

  /// The value the series is measured from: where a fill stops, where bars
  /// grow from, and where [negativeColor] takes over.
  final double baseline;

  /// Whether the series gets a marker and a tooltip row when touched.
  final bool showInTooltip;

  /// The colour the series is drawn in at [value].
  Color colorAt(double value) {
    final negative = negativeColor;
    return negative != null && value < baseline ? negative : color;
  }
}

/// A line through a series of values, optionally filled and dotted.
final class LineSeries extends PlotSeries {
  /// Creates a line through [points].
  const LineSeries({
    required super.points,
    super.label,
    super.color,
    super.negativeColor,
    super.baseline,
    super.showInTooltip,
    this.gradient,
    this.width = 2,
    this.curve = LineCurve.linear,
    this.dashPattern,
    this.roundCap = true,
    this.fill,
    this.dot,
    this.dotBuilder,
  });

  /// Creates a line through plain [values], placed at `x = 0, 1, 2, …`.
  LineSeries.values(
    List<double?> values, {
    super.label,
    super.color,
    super.negativeColor,
    super.baseline,
    super.showInTooltip,
    this.gradient,
    this.width = 2,
    this.curve = LineCurve.linear,
    this.dashPattern,
    this.roundCap = true,
    this.fill,
    this.dot,
    this.dotBuilder,
  }) : super(points: pointsOf(values));

  /// Paints the stroke with a gradient laid over the whole plot, top to
  /// bottom, instead of [color]. [negativeColor] still wins below the
  /// baseline when it is set.
  final Gradient? gradient;

  /// Stroke width; 0 draws no line, which with [dot] makes a scatter plot.
  final double width;

  /// How the line joins its points.
  final LineCurve curve;

  /// Alternating dash and gap lengths, such as `[6, 4]`; null draws solid.
  final List<double>? dashPattern;

  /// Whether the line's ends and dashes are rounded.
  final bool roundCap;

  /// The area under the line; null leaves it unfilled.
  final SeriesFill? fill;

  /// A dot on every point; null draws none unless [dotBuilder] gives one.
  final SeriesDot? dot;

  /// Chooses the dot per point, overriding [dot]; return null for no dot.
  final SeriesDotBuilder? dotBuilder;

  /// The dot drawn on [points]`[index]`, if any.
  SeriesDot? dotAt(int index, SeriesPoint point) {
    final builder = dotBuilder;
    return builder != null ? builder(index, point) : dot;
  }
}

/// Chooses the colour of one bar.
typedef BarColorBuilder = Color Function(int index, SeriesPoint point);

/// One bar per value, grown from the series' baseline.
///
/// Several bar series on one chart stand side by side at each x.
final class BarSeries extends PlotSeries {
  /// Creates bars at [points].
  const BarSeries({
    required super.points,
    super.label,
    super.color,
    super.negativeColor,
    super.baseline,
    super.showInTooltip,
    this.gradient,
    this.colorBuilder,
    this.width,
    this.widthFactor = 0.6,
    this.minWidth = 0,
    this.maxWidth = double.infinity,
    this.radius = 0,
    this.trackColor,
  });

  /// Creates bars for plain [values], placed at `x = 0, 1, 2, …`.
  BarSeries.values(
    List<double?> values, {
    super.label,
    super.color,
    super.negativeColor,
    super.baseline,
    super.showInTooltip,
    this.gradient,
    this.colorBuilder,
    this.width,
    this.widthFactor = 0.6,
    this.minWidth = 0,
    this.maxWidth = double.infinity,
    this.radius = 0,
    this.trackColor,
  }) : super(points: pointsOf(values));

  /// Paints every bar with this gradient, measured over the bar itself.
  final Gradient? gradient;

  /// Chooses each bar's colour, overriding [color] and [negativeColor].
  final BarColorBuilder? colorBuilder;

  /// A fixed bar width in logical pixels; null sizes bars by [widthFactor].
  final double? width;

  /// The share of the room between two neighbouring x values that the bars
  /// at one x take together, before [minWidth] and [maxWidth] are applied.
  final double widthFactor;

  /// The narrowest a bar may be.
  final double minWidth;

  /// The widest a bar may be.
  final double maxWidth;

  /// Corner radius on the end away from the baseline — the top of a bar above
  /// it, the bottom of one below.
  final double radius;

  /// A full-height bar painted behind each one, such as a faint track.
  final Color? trackColor;

  /// The colour of the bar at [points]`[index]`.
  Color barColorAt(int index, SeriesPoint point) {
    final builder = colorBuilder;
    if (builder != null) return builder(index, point);
    return colorAt(point.y ?? baseline);
  }
}
