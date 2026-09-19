import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// How far a measurement may be off, below and above it.
@immutable
class SeriesErrorRange {
  /// A range reaching [lowerBy] below the value and [upperBy] above it.
  const SeriesErrorRange(this.lowerBy, this.upperBy);

  /// A range reaching [by] either side of the value.
  const SeriesErrorRange.symmetric(double by) : lowerBy = by, upperBy = by;

  /// How far below the value the range reaches.
  final double lowerBy;

  /// How far above the value the range reaches.
  final double upperBy;

  @override
  bool operator ==(Object other) =>
      other is SeriesErrorRange &&
      other.lowerBy == lowerBy &&
      other.upperBy == upperBy;

  @override
  int get hashCode => Object.hash(lowerBy, upperBy);
}

/// One value on a [SeriesChart]'s plot.
///
/// [x] is any number — an index, a day count, a price — and [y] is the value
/// drawn against it. A null or non-finite [y] is a gap: a line breaks there,
/// and a bar or a dot is left out.
@immutable
class SeriesPoint {
  /// Creates the point ([x], [y]).
  const SeriesPoint(this.x, this.y, {this.low, this.xError, this.yError});

  /// Where the point sits along the x axis.
  final double x;

  /// The value, or null for a gap.
  final double? y;

  /// Where a bar starts instead of its baseline, for a bar that floats — a
  /// range from [low] to [y]. Lines and dots ignore it.
  final double? low;

  /// How far [x] may be off, drawn as an error bar along the x axis.
  final SeriesErrorRange? xError;

  /// How far [y] may be off, drawn as an error bar along the value axis.
  final SeriesErrorRange? yError;

  /// Whether there is no value here to draw.
  bool get isGap {
    final value = y;
    return value == null || !value.isFinite;
  }

  @override
  bool operator ==(Object other) =>
      other is SeriesPoint &&
      other.x == x &&
      other.y == y &&
      other.low == low &&
      other.xError == xError &&
      other.yError == yError;

  @override
  int get hashCode => Object.hash(x, y, low, xError, yError);

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

  /// Holds each value flat, then steps to the next; where along the way the
  /// step falls is `LineSeries.stepPosition`.
  step,
}

/// The shape of a [SeriesDot].
enum SeriesDotShape {
  /// A filled circle.
  circle,

  /// A filled square, [SeriesDot.radius] from its centre to each side.
  square,

  /// A filled square turned on its corner.
  diamond,

  /// Two crossed strokes.
  cross,
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
    this.shape = SeriesDotShape.circle,
  });

  /// Radius in logical pixels.
  final double radius;

  /// Fill colour; null uses the series colour at that value.
  final Color? color;

  /// Ring colour; null draws no ring.
  final Color? strokeColor;

  /// Ring width; 0 draws no ring. A cross is drawn this thick, or at a third
  /// of its radius when 0.
  final double strokeWidth;

  /// The dot's shape.
  final SeriesDotShape shape;

  @override
  bool operator ==(Object other) =>
      other is SeriesDot &&
      other.radius == radius &&
      other.color == color &&
      other.strokeColor == strokeColor &&
      other.strokeWidth == strokeWidth &&
      other.shape == shape;

  @override
  int get hashCode =>
      Object.hash(radius, color, strokeColor, strokeWidth, shape);
}

/// Decides the dot for one point, or returns null to leave it without one.
typedef SeriesDotBuilder = SeriesDot? Function(int index, SeriesPoint point);

/// Writes the label drawn beside one point, or returns null for none.
typedef SeriesPointLabelBuilder =
    String? Function(int index, SeriesPoint point);

/// How a series draws the error bars of points that carry
/// [SeriesPoint.xError] or [SeriesPoint.yError].
@immutable
class SeriesErrorBars {
  /// Creates an error-bar style.
  const SeriesErrorBars({this.color, this.width = 1, this.capLength = 6});

  /// Stroke colour; null uses the series colour.
  final Color? color;

  /// Stroke width.
  final double width;

  /// Length of the crossbar at either end; 0 draws none.
  final double capLength;
}

/// The area between a [LineSeries] and its baseline, or the bottom of the plot.
///
/// A fill anchored to the baseline never paints across it. The stretch above
/// is painted with [gradient] (or [color]) measured from the line's highest
/// point down to the baseline, so it fades out exactly at the baseline; the
/// stretch below is painted with [negativeGradient] (or [negativeColor]),
/// measured from the baseline down to the line's lowest point. Left unset, the
/// part below reuses the upper gradient turned upside down, so both halves
/// fade away from the line the same way.
///
/// Gradients are written for an upright chart — top is the high values — and
/// turn with a horizontal one.
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

/// The area between two [LineSeries] on the same chart — a band between a
/// high and a low, or the gap between a plan and what happened.
@immutable
class SeriesBetweenFill {
  /// Fills between `SeriesChart.series[from]` and `SeriesChart.series[to]`.
  const SeriesBetweenFill({
    required this.from,
    required this.to,
    this.color,
    this.gradient,
  });

  /// Index of one line in `SeriesChart.series`.
  final int from;

  /// Index of the other.
  final int to;

  /// Flat colour; ignored when [gradient] is set.
  final Color? color;

  /// Gradient laid over the filled area.
  final Gradient? gradient;
}

const Color _defaultSeriesColor = Color(0xFF4C86CD);

/// One set of values on a [SeriesChart]: a [LineSeries], a [BarSeries] or a
/// [ScatterSeries].
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
    this.errorBars = const SeriesErrorBars(),
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

  /// How error ranges on the points are drawn; null draws none.
  final SeriesErrorBars? errorBars;

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
    super.errorBars,
    this.gradient,
    this.width = 2,
    this.curve = LineCurve.linear,
    this.stepPosition = 1,
    this.dashPattern,
    this.roundCap = true,
    this.shadow,
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
    super.errorBars,
    this.gradient,
    this.width = 2,
    this.curve = LineCurve.linear,
    this.stepPosition = 1,
    this.dashPattern,
    this.roundCap = true,
    this.shadow,
    this.fill,
    this.dot,
    this.dotBuilder,
  }) : super(points: pointsOf(values));

  /// Paints the stroke with a gradient laid over the whole plot, top to
  /// bottom, instead of [color]. [negativeColor] still wins below the
  /// baseline when it is set.
  final Gradient? gradient;

  /// Stroke width; 0 draws no line.
  final double width;

  /// How the line joins its points.
  final LineCurve curve;

  /// For [LineCurve.step], where between two points the value changes: 0 at
  /// the first point, 0.5 halfway, 1 — the default — at the second.
  final double stepPosition;

  /// Alternating dash and gap lengths, such as `[6, 4]`; null draws solid.
  final List<double>? dashPattern;

  /// Whether the line's ends and dashes are rounded.
  final bool roundCap;

  /// A blurred copy of the line drawn under it.
  final Shadow? shadow;

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
/// Several bar series on one chart stand side by side at each x, unless they
/// share a [stack], in which case they are piled on each other.
final class BarSeries extends PlotSeries {
  /// Creates bars at [points].
  const BarSeries({
    required super.points,
    super.label,
    super.color,
    super.negativeColor,
    super.baseline,
    super.showInTooltip,
    super.errorBars,
    this.gradient,
    this.colorBuilder,
    this.width,
    this.widthFactor = 0.6,
    this.minWidth = 0,
    this.maxWidth = double.infinity,
    this.radius = BorderRadius.zero,
    this.trackColor,
    this.stack,
    this.border,
    this.labelBuilder,
    this.labelStyle,
  });

  /// Creates bars for plain [values], placed at `x = 0, 1, 2, …`.
  BarSeries.values(
    List<double?> values, {
    super.label,
    super.color,
    super.negativeColor,
    super.baseline,
    super.showInTooltip,
    super.errorBars,
    this.gradient,
    this.colorBuilder,
    this.width,
    this.widthFactor = 0.6,
    this.minWidth = 0,
    this.maxWidth = double.infinity,
    this.radius = BorderRadius.zero,
    this.trackColor,
    this.stack,
    this.border,
    this.labelBuilder,
    this.labelStyle,
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

  /// The rounding of each bar's corners, as drawn on the screen: `topLeft` is
  /// the bar's top-left corner whichever way the bar grows. Rounding only the
  /// end away from the baseline is
  /// `BorderRadius.vertical(top: Radius.circular(4))` for bars above it, and
  /// `BorderRadius.horizontal(right: …)` on a horizontal chart. Radii too big
  /// for the bar are scaled down to fit. In a stack only the outermost bar
  /// shows its rounding.
  final BorderRadius radius;

  /// A full-height bar painted behind each one, such as a faint track.
  final Color? trackColor;

  /// Bar series with the same key are stacked: at each x, each bar starts
  /// where the ones before it in `SeriesChart.series` ended — upwards for
  /// values above the baseline, downwards for values below. Null stands the
  /// series beside the others.
  final Object? stack;

  /// An outline drawn round each bar.
  final BorderSide? border;

  /// Writes the label drawn beyond the end of each bar.
  final SeriesPointLabelBuilder? labelBuilder;

  /// Style of the labels [labelBuilder] writes.
  final TextStyle? labelStyle;

  /// The colour of the bar at [points]`[index]`.
  Color barColorAt(int index, SeriesPoint point) {
    final builder = colorBuilder;
    if (builder != null) return builder(index, point);
    return colorAt(point.y ?? baseline);
  }
}

/// A dot per point, placed freely on both axes — a scatter plot.
///
/// Pair it with `SeriesTouch(snap: SeriesTouchSnap.nearestPoint)`, so a touch
/// reads out the dot under the finger rather than everything at that x.
final class ScatterSeries extends PlotSeries {
  /// Creates dots at [points].
  const ScatterSeries({
    required super.points,
    super.label,
    super.color,
    super.negativeColor,
    super.baseline,
    super.showInTooltip,
    super.errorBars,
    this.dot = const SeriesDot(radius: 4),
    this.dotBuilder,
    this.labelBuilder,
    this.labelStyle,
  });

  /// The dot on every point; [dotBuilder] overrides it.
  final SeriesDot? dot;

  /// Chooses the dot per point — its size, colour or shape; return null to
  /// leave a point out.
  final SeriesDotBuilder? dotBuilder;

  /// Writes the label drawn above each dot.
  final SeriesPointLabelBuilder? labelBuilder;

  /// Style of the labels [labelBuilder] writes.
  final TextStyle? labelStyle;

  /// The dot drawn on [points]`[index]`, if any.
  SeriesDot? dotAt(int index, SeriesPoint point) {
    final builder = dotBuilder;
    return builder != null ? builder(index, point) : dot;
  }
}
