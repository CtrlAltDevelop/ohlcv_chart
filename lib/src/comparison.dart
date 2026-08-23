import 'dart:ui';

import 'entity/k_line_entity.dart';
import 'entity/line.dart';

/// One point of a compared instrument: a value at an instant.
typedef ComparisonPoint = ({DateTime time, double value});

/// How a compared instrument is fitted onto the chart's price scale.
enum ComparisonScale {
  /// Rebased to the main series at the left edge of the window.
  ///
  /// The two lines start together and diverge by how differently they moved, so
  /// what is being read is relative performance rather than price. This is what
  /// comparing two instruments usually means, and it is the default.
  percent,

  /// Drawn at its own prices, on the same scale as the candles.
  ///
  /// Right where the two are quoted in the same units — a future against its
  /// spot, two tenors of the same curve — and misleading where they are not.
  price,
}

/// A second instrument drawn over the candles.
///
/// Hand a list of them to `KChartWidget.comparisons` and each is drawn as a
/// line over the main series, rebased so the two can be read against each other.
/// Points are matched to candles by time, so the compared instrument does not
/// have to have a bar wherever the main one does — a gap simply leaves the line
/// flat until the next point.
///
/// ```dart
/// KChartWidget(
///   candles,
///   ChartColors(),
///   comparisons: [
///     ComparisonSeries(
///       label: 'ETH',
///       points: [for (final c in ethCandles) (time: c.dateTime!, value: c.close)],
///       color: Colors.purpleAccent,
///     ),
///   ],
/// );
/// ```
class ComparisonSeries {
  /// Creates a comparison called [label] over [points], oldest first.
  ComparisonSeries({
    required this.label,
    required List<ComparisonPoint> points,
    this.color,
    this.scale = ComparisonScale.percent,
    this.thickness = 1.5,
    this.style = LineStyle.solid,
  }) : points = _sorted(points);

  /// Builds a comparison from another instrument's candles.
  ///
  /// Takes each candle's close, which is what a compared line is drawn from.
  factory ComparisonSeries.ofCandles({
    required String label,
    required List<KLineEntity> candles,
    Color? color,
    ComparisonScale scale = ComparisonScale.percent,
    double thickness = 1.5,
    LineStyle style = LineStyle.solid,
  }) => ComparisonSeries(
    label: label,
    points: [
      for (final candle in candles)
        if (candle.dateTime case final time?) (time: time, value: candle.close),
    ],
    color: color,
    scale: scale,
    thickness: thickness,
    style: style,
  );

  /// The points, oldest first.
  ///
  /// Sorted on the way in, so a series handed over newest-first still draws in
  /// the right order.
  final List<ComparisonPoint> points;

  /// What to call it in the legend.
  final String label;

  /// The line's colour, or null to take one from the comparison palette.
  final Color? color;

  /// How the series is fitted onto the price scale.
  final ComparisonScale scale;

  /// Stroke width in logical pixels.
  final double thickness;

  /// Whether the stroke is solid, dashed or dotted.
  final LineStyle style;

  /// Whether there is anything to draw.
  bool get isEmpty => points.isEmpty;

  static List<ComparisonPoint> _sorted(List<ComparisonPoint> points) =>
      [...points]..sort((a, b) => a.time.compareTo(b.time));

  @override
  bool operator ==(Object other) =>
      other is ComparisonSeries &&
      other.label == label &&
      other.color == color &&
      other.scale == scale &&
      other.thickness == thickness &&
      other.style == style &&
      other.points.length == points.length &&
      (points.isEmpty ||
          (other.points.first == points.first &&
              other.points.last == points.last));

  @override
  int get hashCode => Object.hash(
    label,
    color,
    scale,
    thickness,
    style,
    points.length,
    points.isEmpty ? null : points.first,
    points.isEmpty ? null : points.last,
  );
}

/// A comparison lined up against the chart's own candles.
///
/// [values] holds one entry per candle — the compared instrument's value at or
/// before that candle's time, or null where it has nothing to say yet. Built
/// once when the candles or the comparisons change, the same way an indicator's
/// series is.
class ResolvedComparison {
  /// Creates a resolved comparison over [values], one per candle.
  const ResolvedComparison({
    required this.series,
    required this.values,
    this.ordinal = 0,
  });

  /// The comparison this came from.
  final ComparisonSeries series;

  /// Its value at each candle, or null where there is none.
  final List<double?> values;

  /// Which comparison this is, for picking a colour from the palette.
  final int ordinal;

  /// The value at [index], or null when there is none.
  double? valueAt(int index) =>
      index < 0 || index >= values.length ? null : values[index];
}

/// Lines [series] up against [candles], one value per candle.
///
/// Each candle takes the last point at or before its own time, so a compared
/// instrument on a slower bar — a daily series over an hourly chart — holds its
/// value until the next one arrives. Candles before the first point, and
/// candles with no timestamp, get null.
List<double?> alignComparison(
  List<KLineEntity> candles,
  ComparisonSeries series,
) {
  final values = List<double?>.filled(candles.length, null);
  if (candles.isEmpty || series.points.isEmpty) return values;

  // Both are in time order, so one walk down each is enough.
  var next = 0;
  double? held;
  for (var i = 0; i < candles.length; i++) {
    final time = candles[i].dateTime;
    if (time == null) continue;

    while (next < series.points.length &&
        !series.points[next].time.isAfter(time)) {
      held = series.points[next].value;
      next++;
    }
    values[i] = held;
  }
  return values;
}

/// Where a rebased comparison is pinned to the main series.
///
/// [value] is the comparison's own value at the left edge of the window and
/// [price] the main series' price there, so every later value is drawn at
/// `price * v / value` — the same proportional move, started from the same
/// place.
typedef ComparisonAnchor = ({double value, double price});

/// Where [resolved] is pinned, over the window from [start] to [stop].
///
/// The first candle in the window that both series have a value for. Null where
/// they share none, or where the comparison's value there is zero and nothing
/// can be measured against it.
ComparisonAnchor? comparisonAnchor(
  ResolvedComparison resolved,
  List<KLineEntity> candles,
  int start,
  int stop,
) {
  if (resolved.series.scale != ComparisonScale.percent) return null;

  final from = start.clamp(0, candles.length);
  final to = stop.clamp(0, candles.length - 1);
  for (var i = from; i <= to; i++) {
    final value = resolved.valueAt(i);
    if (value == null || !value.isFinite || value == 0) continue;
    return (value: value, price: candles[i].close);
  }
  return null;
}

/// The price [resolved] draws at [index], or null where it draws nothing.
///
/// A comparison on its own price scale answers its own value; a rebased one
/// answers the value mapped through [anchor], and nothing at all until there is
/// an anchor to map through.
double? comparisonPriceAt(
  ResolvedComparison resolved,
  int index,
  ComparisonAnchor? anchor,
) {
  final value = resolved.valueAt(index);
  if (value == null || !value.isFinite) return null;
  if (resolved.series.scale == ComparisonScale.price) return value;
  if (anchor == null) return null;
  return anchor.price * value / anchor.value;
}

/// Lines every one of [comparisons] up against [candles].
List<ResolvedComparison> resolveComparisons(
  List<KLineEntity> candles,
  List<ComparisonSeries> comparisons,
) => [
  for (final (index, series) in comparisons.indexed)
    ResolvedComparison(
      series: series,
      values: alignComparison(candles, series),
      ordinal: index,
    ),
];
