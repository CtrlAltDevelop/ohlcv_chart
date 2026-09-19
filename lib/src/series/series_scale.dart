import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart';

import '../utils/axis_ticks.dart';
import 'series_axis.dart';
import 'series_data.dart';

/// The window of values a [SeriesChart] shows, and where its axes are ruled.
class SeriesViewport {
  /// Creates a viewport.
  const SeriesViewport({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.xTicks,
    required this.yTicks,
    required this.yStep,
  });

  /// The x at the left edge of the plot.
  final double minX;

  /// The x at the right edge of the plot.
  final double maxX;

  /// The value at the bottom edge of the plot.
  final double minY;

  /// The value at the top edge of the plot.
  final double maxY;

  /// The x values labelled and ruled.
  final List<double> xTicks;

  /// The values labelled and ruled.
  final List<double> yTicks;

  /// The distance between two value labels, which decides their decimals.
  final double yStep;

  /// The distance between two x labels, which decides their decimals; 1 when
  /// there are fewer than two.
  double get xStep {
    var step = double.infinity;
    for (var i = 1; i < xTicks.length; i++) {
      final gap = (xTicks[i] - xTicks[i - 1]).abs();
      if (gap > 0 && gap < step) step = gap;
    }
    return step.isFinite ? step : 1;
  }

  /// A viewport part of the way from [a] to [b]; the ticks are [b]'s.
  static SeriesViewport lerp(SeriesViewport a, SeriesViewport b, double t) =>
      SeriesViewport(
        minX: lerpDouble(a.minX, b.minX, t)!,
        maxX: lerpDouble(a.maxX, b.maxX, t)!,
        minY: lerpDouble(a.minY, b.minY, t)!,
        maxY: lerpDouble(a.maxY, b.maxY, t)!,
        xTicks: b.xTicks,
        yTicks: b.yTicks,
        yStep: b.yStep,
      );
}

/// Fits a viewport around [series], whose current values are [values] —
/// `values[i][j]` standing for `series[i].points[j].y`.
///
/// Anything given explicitly — [minX], [maxX], [minY], [maxY] — is kept as it
/// is. The rest is fitted: x spans the points, with [xPadding] either side (half
/// a unit by default when there are bars, so the end bars are whole); values
/// span what is inside that x window, plus each bar series' baseline, zero
/// when [includeZero] is set and any reference line that asks. The value range
/// is then widened by [yPadding] of its height — never across zero when the
/// data stays on one side of it — and, with [niceYRange], out to the nearest
/// round tick either side.
SeriesViewport fitSeriesViewport({
  required List<PlotSeries> series,
  required List<List<double?>> values,
  required SeriesXAxis xAxis,
  required SeriesYAxis yAxis,
  List<SeriesReferenceLine> referenceLines = const [],
  double? minX,
  double? maxX,
  double? xPadding,
  double? minY,
  double? maxY,
  bool includeZero = false,
  double yPadding = 0.1,
  bool niceYRange = true,
}) {
  var xLow = double.infinity;
  var xHigh = double.negativeInfinity;
  var hasBars = false;
  for (final s in series) {
    if (s is BarSeries) hasBars = true;
    for (final p in s.points) {
      if (!p.x.isFinite) continue;
      xLow = math.min(xLow, p.x);
      xHigh = math.max(xHigh, p.x);
    }
  }
  if (xLow > xHigh) {
    xLow = 0;
    xHigh = 1;
  }
  final padX = xPadding ?? (hasBars ? 0.5 : 0.0);
  final left = minX ?? xLow - padX;
  var right = maxX ?? xHigh + padX;
  if (!(right > left)) right = left + 1;

  var yLow = double.infinity;
  var yHigh = double.negativeInfinity;
  void take(double v) {
    if (!v.isFinite) return;
    yLow = math.min(yLow, v);
    yHigh = math.max(yHigh, v);
  }

  for (var i = 0; i < series.length; i++) {
    final s = series[i];
    final row = i < values.length ? values[i] : const <double?>[];
    var any = false;
    for (var j = 0; j < s.points.length && j < row.length; j++) {
      final point = s.points[j];
      final x = point.x;
      if (x < left || x > right) continue;
      final y = row[j];
      if (y == null) continue;
      // A stacked bar reaches as far as everything under it plus itself, and
      // a floating one as far as both of its ends.
      if (s is BarSeries && s.stack != null) {
        final base = stackedBase(series, values, i, j);
        take(base);
        take(base + (y - s.baseline));
      } else {
        final low = point.low;
        if (low != null) take(low);
        take(y);
      }
      final error = point.yError;
      if (error != null) {
        take(y - error.lowerBy);
        take(y + error.upperBy);
      }
      any = true;
    }
    if (s is BarSeries && any) take(s.baseline);
  }
  if (includeZero) take(0);
  for (final line in referenceLines) {
    if (line.direction == SeriesDirection.horizontal && line.extendsRange) {
      take(line.value);
    }
  }
  final hasData = yLow <= yHigh;
  if (!hasData) {
    yLow = 0;
    yHigh = 1;
  }

  final span = yHigh - yLow;
  final pad = span == 0
      ? math.max(yHigh.abs() * 0.1, 1.0)
      : span * math.max(0.0, yPadding);
  var bottom = yLow - pad;
  var top = yHigh + pad;
  // Padding is room, not data: a series that never goes below zero does not
  // get a negative axis to sit on.
  if (yLow >= 0 && bottom < 0) bottom = 0;
  if (yHigh <= 0 && top > 0) top = 0;
  if (minY != null) bottom = minY;
  if (maxY != null) top = maxY;
  if (!(top > bottom)) top = bottom + 1;

  var step = yAxis.interval ?? niceStep(top - bottom, yAxis.tickCount);
  if (niceYRange && step > 0) {
    if (minY == null) bottom = _floorTo(bottom, step);
    if (maxY == null) top = _ceilTo(top, step);
    if (!(top > bottom)) top = bottom + step;
  }

  final List<double> yTicks;
  final explicitY = yAxis.ticks;
  if (explicitY != null) {
    yTicks = [
      for (final t in explicitY)
        if (_within(t, bottom, top)) t,
    ];
    if (yTicks.length > 1) step = (yTicks[1] - yTicks[0]).abs();
  } else if (yAxis.interval != null || niceYRange) {
    yTicks = _stepTicks(bottom, top, step);
  } else {
    yTicks = niceTicks(bottom, top, target: yAxis.tickCount);
    if (yTicks.length > 1) step = yTicks[1] - yTicks[0];
  }

  return SeriesViewport(
    minX: left,
    maxX: right,
    minY: bottom,
    maxY: top,
    xTicks: _xTicks(xAxis, series, left, right),
    yTicks: yTicks,
    yStep: step,
  );
}

List<double> _xTicks(
  SeriesXAxis axis,
  List<PlotSeries> series,
  double left,
  double right,
) {
  final explicit = axis.ticks;
  if (explicit != null) {
    return [
      for (final t in explicit)
        if (_within(t, left, right)) t,
    ];
  }

  final interval = axis.interval;
  final labels = axis.labels;
  if (labels != null && axis.labelBuilder == null) {
    final every = interval == null ? 1 : math.max(1, interval.round());
    return [
      for (
        var i = math.max(0, left.ceil());
        i <= right.floor() && i < labels.length;
        i++
      )
        if (labels[i].isNotEmpty && i % every == 0) i.toDouble(),
    ];
  }

  if (interval != null && interval > 0) {
    return _stepTicks(left, right, interval);
  }

  var step = niceStep(right - left, axis.tickCount);
  final whole = series.every(
    (s) => s.points.every((p) => p.x == p.x.roundToDouble()),
  );
  if (whole) step = math.max(1.0, step.ceilToDouble());
  return _stepTicks(left, right, step);
}

bool _within(double v, double low, double high) {
  final epsilon = (high - low).abs() * 1e-9;
  return v >= low - epsilon && v <= high + epsilon;
}

double _floorTo(double v, double step) {
  final n = v / step;
  final r = n.roundToDouble();
  return ((n - r).abs() < 1e-9 ? r : n.floorToDouble()) * step;
}

double _ceilTo(double v, double step) {
  final n = v / step;
  final r = n.roundToDouble();
  return ((n - r).abs() < 1e-9 ? r : n.ceilToDouble()) * step;
}

List<double> _stepTicks(double low, double high, double step) {
  if (!(step > 0) || !low.isFinite || !high.isFinite) return const [];
  final ticks = <double>[];
  var n = _ceilTo(low, step) / step;
  while (ticks.length < 64) {
    final value = (n * step);
    // Rounded to the step's precision so 0.1 + 0.2 reads as 0.3.
    final clean = double.parse(value.toStringAsPrecision(12));
    if (!_within(clean, low, high)) break;
    ticks.add(clean == 0 ? 0 : clean);
    n += 1;
  }
  return ticks;
}

/// Which way a [SeriesChart] is turned.
enum SeriesOrientation {
  /// The x axis runs across the chart and the values grow upwards — the
  /// upright chart.
  vertical,

  /// The x axis runs down the chart and the values grow rightwards, which is
  /// what a horizontal bar chart is.
  horizontal,
}

/// Where a [SeriesChart]'s plot sits, and the mapping between values and its
/// pixels.
///
/// Two numbers place anything on the plot: the x, along the x axis, and the
/// value, along the value axis. Which screen direction each of those runs in
/// is [orientation]'s business, so everything that paints works in x and
/// value and lets [point] turn them into pixels.
class SeriesGeometry {
  /// Creates the geometry of a chart of [size] whose plot is [plot], showing
  /// [viewport].
  const SeriesGeometry({
    required this.size,
    required this.plot,
    required this.viewport,
    this.orientation = SeriesOrientation.vertical,
  });

  /// Lays out a chart of [size]: [padding] off every edge, then room for each
  /// axis on its side of the plot.
  factory SeriesGeometry.layout({
    required Size size,
    required EdgeInsets padding,
    required SeriesXAxis xAxis,
    required SeriesYAxis yAxis,
    required SeriesViewport viewport,
    SeriesOrientation orientation = SeriesOrientation.vertical,
  }) {
    final horizontal = orientation == SeriesOrientation.horizontal;
    final valueRoom = yAxis.show
        ? (horizontal
                  ? _lineHeight(seriesAxisLabelStyle.merge(yAxis.style)) +
                        yAxis.gap
                  : yAxis.width) +
              _titleRoom(yAxis.title, yAxis.titleStyle)
        : 0.0;
    final xRoom = xAxis.show
        ? xAxis.height + _titleRoom(xAxis.title, xAxis.titleStyle)
        : 0.0;

    // Each axis takes its room off one edge; which edge depends on the side
    // it was given and on which way the chart is turned.
    var left = padding.left;
    var right = size.width - padding.right;
    var top = padding.top;
    var bottom = size.height - padding.bottom;

    if (horizontal) {
      if (yAxis.side == SeriesAxisSide.left) {
        bottom -= valueRoom;
      } else {
        top += valueRoom;
      }
      if (xAxis.side == SeriesXSide.bottom) {
        left += xRoom;
      } else {
        right -= xRoom;
      }
    } else {
      if (yAxis.side == SeriesAxisSide.left) {
        left += valueRoom;
      } else {
        right -= valueRoom;
      }
      if (xAxis.side == SeriesXSide.bottom) {
        bottom -= xRoom;
      } else {
        top += xRoom;
      }
    }

    return SeriesGeometry(
      size: size,
      plot: Rect.fromLTRB(
        left,
        top,
        math.max(left, right),
        math.max(top, bottom),
      ),
      viewport: viewport,
      orientation: orientation,
    );
  }

  /// The whole chart.
  final Size size;

  /// The plot area.
  final Rect plot;

  /// The values shown.
  final SeriesViewport viewport;

  /// Which way the chart is turned.
  final SeriesOrientation orientation;

  /// Whether the x axis runs down the chart rather than across it.
  bool get isHorizontal => orientation == SeriesOrientation.horizontal;

  /// How far along the x axis [x] falls, in pixels — a column on an upright
  /// chart, a row on a horizontal one.
  double xToPx(double x) {
    final span = viewport.maxX - viewport.minX;
    final t = (x - viewport.minX) / span;
    return isHorizontal
        ? plot.top + t * plot.height
        : plot.left + t * plot.width;
  }

  /// How far along the value axis [y] falls, in pixels.
  double yToPx(double y) {
    final span = viewport.maxY - viewport.minY;
    final t = (y - viewport.minY) / span;
    return isHorizontal
        ? plot.left + t * plot.width
        : plot.bottom - t * plot.height;
  }

  /// The pixel the pair ([x], [y]) sits on.
  Offset point(double x, double y) =>
      isHorizontal ? Offset(yToPx(y), xToPx(x)) : Offset(xToPx(x), yToPx(y));

  /// The x at [px] pixels along the x axis.
  double pxToX(double px) {
    final length = isHorizontal ? plot.height : plot.width;
    if (length <= 0) return viewport.minX;
    final span = viewport.maxX - viewport.minX;
    final start = isHorizontal ? plot.top : plot.left;
    return viewport.minX + (px - start) / length * span;
  }

  /// The x under [local], wherever the chart is pointing.
  double pxToXAt(Offset local) => pxToX(isHorizontal ? local.dy : local.dx);

  /// How many pixels one unit of x takes.
  double get unitWidth =>
      (isHorizontal ? plot.height : plot.width) /
      math.max(1e-12, viewport.maxX - viewport.minX);

  /// The stretch of plot between the x values [from] and [to].
  Rect xBand(double from, double to) {
    final a = xToPx(from);
    final b = xToPx(to);
    return isHorizontal
        ? Rect.fromLTRB(plot.left, math.min(a, b), plot.right, math.max(a, b))
        : Rect.fromLTRB(math.min(a, b), plot.top, math.max(a, b), plot.bottom);
  }

  /// The stretch of plot between the values [from] and [to].
  Rect valueBand(double from, double to) {
    final a = yToPx(from);
    final b = yToPx(to);
    return isHorizontal
        ? Rect.fromLTRB(math.min(a, b), plot.top, math.max(a, b), plot.bottom)
        : Rect.fromLTRB(plot.left, math.min(a, b), plot.right, math.max(a, b));
  }

  /// The box covering x [x0] to [x1] and values [v0] to [v1] — a bar.
  Rect box(double x0, double x1, double v0, double v1) {
    final a = point(x0, v0);
    final b = point(x1, v1);
    return Rect.fromLTRB(
      math.min(a.dx, b.dx),
      math.min(a.dy, b.dy),
      math.max(a.dx, b.dx),
      math.max(a.dy, b.dy),
    );
  }

  /// The line ruled right across the plot at the value [y].
  (Offset, Offset) valueLine(double y) {
    final band = valueBand(y, y);
    return isHorizontal
        ? (Offset(band.left, plot.top), Offset(band.left, plot.bottom))
        : (Offset(plot.left, band.top), Offset(plot.right, band.top));
  }

  /// The line ruled right across the plot at the x [x].
  (Offset, Offset) xLine(double x) {
    final band = xBand(x, x);
    return isHorizontal
        ? (Offset(plot.left, band.top), Offset(plot.right, band.top))
        : (Offset(band.left, plot.top), Offset(band.left, plot.bottom));
  }

  /// How much room a title and its gap take across an axis.
  static double _titleRoom(String? title, TextStyle? style) {
    if (title == null || title.isEmpty) return 0;
    return _lineHeight(seriesAxisTitleStyle.merge(style)) + 2;
  }

  /// The height of one line of [style], measured once per layout.
  static double _lineHeight(TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: '0', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }
}

/// The value a stacked bar starts from: how far the bars before it in the
/// same stack have already reached at that point, on its own side of the
/// baseline. A bar that stacks on nothing starts at its series' baseline.
double stackedBase(
  List<PlotSeries> series,
  List<List<double?>> values,
  int index,
  int pointIndex,
) {
  final self = series[index];
  if (self is! BarSeries) return self.baseline;
  final stack = self.stack;
  if (stack == null) return self.baseline;
  final row = index < values.length ? values[index] : const <double?>[];
  final own = pointIndex < row.length ? row[pointIndex] : null;
  if (own == null) return self.baseline;
  final up = own >= self.baseline;
  final x = self.points[pointIndex].x;

  var base = self.baseline;
  for (var i = 0; i < index; i++) {
    final other = series[i];
    if (other is! BarSeries || other.stack != stack) continue;
    final otherRow = i < values.length ? values[i] : const <double?>[];
    for (var j = 0; j < other.points.length && j < otherRow.length; j++) {
      if (other.points[j].x != x) continue;
      final y = otherRow[j];
      if (y == null || !y.isFinite) continue;
      final height = y - other.baseline;
      if (height >= 0 == up) base += height;
    }
  }
  return base;
}
