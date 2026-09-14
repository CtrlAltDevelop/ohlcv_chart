import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../renderer/text_painter_cache.dart';
import 'series_axis.dart';
import 'series_data.dart';
import 'series_paths.dart';
import 'series_scale.dart';
import 'series_touch.dart';

/// Paints a [SeriesChart]: bands, grid, reference lines, series, border and
/// axis labels.
class SeriesChartPainter extends CustomPainter {
  /// Creates the painter. `values[i][j]` is the value drawn for
  /// `series[i].points[j]`, which is where an animation puts its in-between
  /// values.
  SeriesChartPainter({
    required this.geometry,
    required this.series,
    required this.values,
    required this.xAxis,
    required this.yAxis,
    required this.grid,
    required this.border,
    required this.referenceLines,
    required this.bands,
    required this.backgroundColor,
    required this.clipToPlot,
    required this.textCache,
  });

  final SeriesGeometry geometry;
  final List<PlotSeries> series;
  final List<List<double?>> values;
  final SeriesXAxis xAxis;
  final SeriesYAxis yAxis;
  final SeriesGrid grid;
  final BorderSide? border;
  final List<SeriesReferenceLine> referenceLines;
  final List<SeriesBand> bands;
  final Color? backgroundColor;
  final bool clipToPlot;
  final TextPainterCache textCache;

  static const TextStyle _baseLabelStyle = TextStyle(
    fontSize: 10,
    color: seriesAxisTextColor,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final plot = geometry.plot;
    final background = backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (plot.width <= 0 || plot.height <= 0) return;

    canvas.save();
    canvas.clipRect(clipToPlot ? plot : Offset.zero & size);
    _paintBands(canvas);
    _paintGrid(canvas);
    _paintReferenceLines(canvas, above: false);

    final barSeries = [
      for (final s in series)
        if (s is BarSeries) s,
    ];
    final barSpacing = _barSpacing(barSeries);
    // Counted by position, not looked up: the same series given twice is two
    // groups of bars side by side, not one drawn over the other.
    var barGroup = 0;
    for (var i = 0; i < series.length; i++) {
      final row = i < values.length ? values[i] : const <double?>[];
      switch (series[i]) {
        case final LineSeries line:
          _paintLine(canvas, size, line, row);
        case final BarSeries bars:
          _paintBars(
            canvas,
            bars,
            row,
            barGroup++,
            barSeries.length,
            barSpacing,
          );
      }
    }
    _paintReferenceLines(canvas, above: true);
    canvas.restore();

    _paintBorder(canvas);
    _paintReferenceLabels(canvas, size);
    _paintValueLabels(canvas, size);
    _paintXLabels(canvas, size);
  }

  // ── Plot furniture ──────────────────────────────────────────────────────

  void _paintBands(Canvas canvas) {
    final plot = geometry.plot;
    for (final band in bands) {
      final Rect rect;
      if (band.direction == SeriesDirection.horizontal) {
        final a = geometry.yToPx(band.from);
        final b = geometry.yToPx(band.to);
        rect = Rect.fromLTRB(
          plot.left,
          math.min(a, b),
          plot.right,
          math.max(a, b),
        );
      } else {
        final a = geometry.xToPx(band.from);
        final b = geometry.xToPx(band.to);
        rect = Rect.fromLTRB(
          math.min(a, b),
          plot.top,
          math.max(a, b),
          plot.bottom,
        );
      }
      canvas.drawRect(rect, Paint()..color = band.color);
    }
  }

  void _paintGrid(Canvas canvas) {
    final plot = geometry.plot;
    if (grid.horizontal && grid.width > 0) {
      final path = Path();
      for (final tick in geometry.viewport.yTicks) {
        final y = geometry.yToPx(tick);
        path
          ..moveTo(plot.left, y)
          ..lineTo(plot.right, y);
      }
      canvas.drawPath(
        dashSeriesPath(path, grid.dashPattern),
        _strokePaint(grid.color, grid.width),
      );
    }
    if (grid.vertical && grid.width > 0) {
      final path = Path();
      for (final tick in geometry.viewport.xTicks) {
        final x = geometry.xToPx(tick);
        path
          ..moveTo(x, plot.top)
          ..lineTo(x, plot.bottom);
      }
      canvas.drawPath(
        dashSeriesPath(path, grid.verticalDashPattern ?? grid.dashPattern),
        _strokePaint(grid.verticalColor ?? grid.color, grid.width),
      );
    }
  }

  void _paintReferenceLines(Canvas canvas, {required bool above}) {
    final plot = geometry.plot;
    for (final line in referenceLines) {
      if (line.aboveSeries != above || line.width <= 0) continue;
      final path = Path();
      if (line.direction == SeriesDirection.horizontal) {
        final y = geometry.yToPx(line.value);
        path
          ..moveTo(plot.left, y)
          ..lineTo(plot.right, y);
      } else {
        final x = geometry.xToPx(line.value);
        path
          ..moveTo(x, plot.top)
          ..lineTo(x, plot.bottom);
      }
      canvas.drawPath(
        dashSeriesPath(path, line.dashPattern),
        _strokePaint(line.color, line.width),
      );
    }
  }

  void _paintReferenceLabels(Canvas canvas, Size size) {
    final plot = geometry.plot;
    for (final line in referenceLines) {
      final label = line.label;
      if (label == null || label.isEmpty) continue;
      final style = _baseLabelStyle
          .copyWith(color: line.color)
          .merge(line.labelStyle);
      final tp = textCache.get(label, style);
      final align = line.labelAlignment;
      double dx;
      double dy;
      if (line.direction == SeriesDirection.horizontal) {
        final y = geometry.yToPx(line.value);
        if (y < plot.top - 0.5 || y > plot.bottom + 0.5) continue;
        dx = _lerp(plot.left + 4, plot.right - 4 - tp.width, (align.x + 1) / 2);
        dy = align.y < 0
            ? y - tp.height - 2
            : align.y > 0
            ? y + 2
            : y - tp.height / 2;
      } else {
        final x = geometry.xToPx(line.value);
        if (x < plot.left - 0.5 || x > plot.right + 0.5) continue;
        dx = align.x < 0
            ? x - tp.width - 2
            : align.x > 0
            ? x + 2
            : x - tp.width / 2;
        dy = _lerp(
          plot.top + 2,
          plot.bottom - 2 - tp.height,
          (align.y + 1) / 2,
        );
      }
      dx = dx.clamp(0.0, math.max(0.0, size.width - tp.width));
      dy = dy.clamp(0.0, math.max(0.0, size.height - tp.height));
      tp.paint(canvas, Offset(dx, dy));
    }
  }

  void _paintBorder(Canvas canvas) {
    final side = border;
    if (side == null || side.style == BorderStyle.none || side.width <= 0) {
      return;
    }
    canvas.drawRect(
      geometry.plot.deflate(side.width / 2),
      _strokePaint(side.color, side.width),
    );
  }

  // ── Axis labels ─────────────────────────────────────────────────────────

  void _paintValueLabels(Canvas canvas, Size size) {
    if (!yAxis.show) return;
    final plot = geometry.plot;
    final style = _baseLabelStyle.merge(yAxis.style);
    final step = geometry.viewport.yStep;
    for (final tick in geometry.viewport.yTicks) {
      final text = yAxis.format(tick, step);
      if (text.isEmpty) continue;
      final tp = textCache.get(text, style);
      final y = geometry.yToPx(tick);
      final top = (y - tp.height / 2)
          .clamp(0.0, math.max(0.0, size.height - tp.height))
          .toDouble();
      final left = yAxis.side == SeriesAxisSide.left
          ? math.max(0.0, plot.left - yAxis.gap - tp.width)
          : plot.right + yAxis.gap;
      tp.paint(canvas, Offset(left, top));
    }
  }

  void _paintXLabels(Canvas canvas, Size size) {
    if (!xAxis.show) return;
    final plot = geometry.plot;
    final style = _baseLabelStyle.merge(xAxis.style);
    var previousRight = double.negativeInfinity;
    final step = geometry.viewport.xStep;
    for (final tick in geometry.viewport.xTicks) {
      final text = xAxis.labelFor(tick, step: step);
      if (text == null || text.isEmpty) continue;
      final tp = textCache.get(text, style);
      var left = geometry.xToPx(tick) - tp.width / 2;
      if (xAxis.fitInside) {
        left = left.clamp(0.0, math.max(0.0, size.width - tp.width));
      }
      // A label that would run into the one before it is dropped rather than
      // drawn on top of it.
      if (left < previousRight + 4) continue;
      tp.paint(canvas, Offset(left, plot.bottom + xAxis.gap));
      previousRight = left + tp.width;
    }
  }

  // ── Lines ───────────────────────────────────────────────────────────────

  void _paintLine(
    Canvas canvas,
    Size size,
    LineSeries line,
    List<double?> row,
  ) {
    final runs = <List<Offset>>[];
    var run = <Offset>[];
    for (var j = 0; j < line.points.length; j++) {
      final x = line.points[j].x;
      final y = j < row.length ? row[j] : null;
      if (y == null || !y.isFinite || !x.isFinite) {
        if (run.isNotEmpty) {
          runs.add(run);
          run = <Offset>[];
        }
        continue;
      }
      run.add(Offset(geometry.xToPx(x), geometry.yToPx(y)));
    }
    if (run.isNotEmpty) runs.add(run);
    if (runs.isEmpty) return;

    if (line.fill != null) _paintFill(canvas, size, line, runs);

    if (line.width > 0) {
      final path = Path();
      for (final r in runs) {
        addSeriesRun(path, r, line.curve);
      }
      _paintStroke(canvas, size, line, dashSeriesPath(path, line.dashPattern));
    }

    _paintDots(canvas, line, row);
  }

  void _paintFill(
    Canvas canvas,
    Size size,
    LineSeries line,
    List<List<Offset>> runs,
  ) {
    final fill = line.fill!;
    final plot = geometry.plot;
    final baseY = fill.toBaseline
        ? geometry.yToPx(line.baseline).clamp(plot.top, plot.bottom)
        : plot.bottom;

    final area = Path();
    var highest = double.infinity;
    var lowest = double.negativeInfinity;
    for (final r in runs) {
      if (r.length < 2) continue;
      addSeriesRun(area, r, line.curve);
      area
        ..lineTo(r.last.dx, baseY)
        ..lineTo(r.first.dx, baseY)
        ..close();
      for (final p in r) {
        highest = math.min(highest, p.dy);
        lowest = math.max(lowest, p.dy);
      }
    }
    if (highest > lowest) return;

    if (!fill.toBaseline) {
      final paint = _areaPaint(
        fill.gradient,
        fill.color,
        Rect.fromLTRB(
          plot.left,
          highest,
          plot.right,
          math.max(plot.bottom, highest + 1),
        ),
      );
      if (paint != null) canvas.drawPath(area, paint);
      return;
    }

    if (highest < baseY) {
      final paint = _areaPaint(
        fill.gradient,
        fill.color,
        Rect.fromLTRB(
          plot.left,
          highest,
          plot.right,
          math.max(baseY, highest + 1),
        ),
      );
      if (paint != null) {
        canvas
          ..save()
          ..clipRect(Rect.fromLTRB(0, 0, size.width, baseY))
          ..drawPath(area, paint)
          ..restore();
      }
    }

    if (lowest > baseY) {
      final upper = fill.gradient;
      final gradient =
          fill.negativeGradient ??
          (upper == null
              ? null
              : fill.mirrorBelowBaseline
              ? _mirrored(upper)
              : upper);
      final paint = _areaPaint(
        gradient,
        fill.negativeColor ?? fill.color,
        Rect.fromLTRB(
          plot.left,
          baseY,
          plot.right,
          math.max(lowest, baseY + 1),
        ),
      );
      if (paint != null) {
        canvas
          ..save()
          ..clipRect(Rect.fromLTRB(0, baseY, size.width, size.height))
          ..drawPath(area, paint)
          ..restore();
      }
    }
  }

  void _paintStroke(Canvas canvas, Size size, LineSeries line, Path path) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = line.width
      ..strokeCap = line.roundCap ? StrokeCap.round : StrokeCap.butt
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final gradient = line.gradient;
    if (gradient != null) {
      paint.shader = gradient.createShader(geometry.plot);
    } else {
      paint.color = line.color;
    }

    final negative = line.negativeColor;
    if (negative == null) {
      canvas.drawPath(path, paint);
      return;
    }

    // Split at the baseline: whatever lies above keeps the series colour and
    // whatever lies below takes the negative one, cut exactly where the line
    // crosses rather than at the nearest point.
    final baseY = geometry.yToPx(line.baseline).clamp(0.0, size.height);
    canvas
      ..save()
      ..clipRect(Rect.fromLTRB(0, 0, size.width, baseY))
      ..drawPath(path, paint)
      ..restore();
    paint
      ..shader = null
      ..color = negative;
    canvas
      ..save()
      ..clipRect(Rect.fromLTRB(0, baseY, size.width, size.height))
      ..drawPath(path, paint)
      ..restore();
  }

  void _paintDots(Canvas canvas, LineSeries line, List<double?> row) {
    if (line.dot == null && line.dotBuilder == null) return;
    for (var j = 0; j < line.points.length && j < row.length; j++) {
      final y = row[j];
      final point = line.points[j];
      if (y == null || !y.isFinite || point.isGap) continue;
      final dot = line.dotAt(j, point);
      if (dot == null) continue;
      paintSeriesDot(
        canvas,
        Offset(geometry.xToPx(point.x), geometry.yToPx(y)),
        dot,
        line.colorAt(point.y!),
      );
    }
  }

  // ── Bars ────────────────────────────────────────────────────────────────

  /// The smallest gap between two x values any bar series uses, so bars at
  /// irregular positions never overlap.
  static double _barSpacing(List<BarSeries> bars) {
    var spacing = double.infinity;
    for (final s in bars) {
      for (var j = 1; j < s.points.length; j++) {
        final gap = (s.points[j].x - s.points[j - 1].x).abs();
        if (gap > 0) spacing = math.min(spacing, gap);
      }
    }
    return spacing.isFinite ? spacing : 1;
  }

  void _paintBars(
    Canvas canvas,
    BarSeries bars,
    List<double?> row,
    int group,
    int groups,
    double spacing,
  ) {
    final plot = geometry.plot;
    final slot = geometry.unitWidth * spacing;
    const gap = 2.0;
    final raw = bars.width ?? slot * bars.widthFactor / math.max(1, groups);
    final width = raw
        .clamp(bars.minWidth, math.max(bars.minWidth, bars.maxWidth))
        .toDouble();
    final offset =
        (group - (groups - 1) / 2) * (width + (groups > 1 ? gap : 0));
    final baseY = geometry.yToPx(bars.baseline).clamp(plot.top, plot.bottom);

    final track = bars.trackColor;
    final trackPath = Path();
    final byColor = <Color, Path>{};
    final shaded = <RRect>[];

    for (var j = 0; j < bars.points.length && j < row.length; j++) {
      final y = row[j];
      final point = bars.points[j];
      if (y == null || !y.isFinite || point.isGap) continue;
      final centre = geometry.xToPx(point.x) + offset;
      final left = centre - width / 2;
      final right = centre + width / 2;
      if (right < plot.left || left > plot.right) continue;

      if (track != null) {
        trackPath.addRRect(
          RRect.fromLTRBR(
            left,
            plot.top,
            right,
            plot.bottom,
            Radius.circular(math.min(bars.radius, width / 2)),
          ),
        );
      }

      final shape = seriesBarShape(
        left: left,
        right: right,
        valueY: geometry.yToPx(y).clamp(plot.top - 1, plot.bottom + 1),
        baseY: baseY,
        radius: bars.radius,
      );
      if (shape == null) continue;
      if (bars.gradient != null) {
        shaded.add(shape);
      } else {
        byColor
            .putIfAbsent(bars.barColorAt(j, point), Path.new)
            .addRRect(shape);
      }
    }

    if (track != null) canvas.drawPath(trackPath, Paint()..color = track);
    // One draw per colour, however many bars there are.
    byColor.forEach((color, path) {
      canvas.drawPath(path, Paint()..color = color);
    });
    final gradient = bars.gradient;
    if (gradient != null) {
      for (final shape in shaded) {
        canvas.drawRRect(
          shape,
          Paint()..shader = gradient.createShader(shape.outerRect),
        );
      }
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  static Paint _strokePaint(Color color, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..color = color
    ..strokeWidth = width
    ..isAntiAlias = true;

  static Paint? _areaPaint(Gradient? gradient, Color? color, Rect rect) {
    if (gradient != null) return Paint()..shader = gradient.createShader(rect);
    if (color != null) return Paint()..color = color;
    return null;
  }

  static Gradient _mirrored(Gradient gradient) => gradient is LinearGradient
      ? LinearGradient(
          begin: gradient.end,
          end: gradient.begin,
          colors: gradient.colors,
          stops: gradient.stops,
          tileMode: gradient.tileMode,
          transform: gradient.transform,
        )
      : gradient;

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(SeriesChartPainter oldDelegate) => true;
}

/// Paints [dot] at [centre], filled with [fallback] when it names no colour.
void paintSeriesDot(
  Canvas canvas,
  Offset centre,
  SeriesDot dot,
  Color fallback,
) {
  if (dot.radius <= 0) return;
  canvas.drawCircle(
    centre,
    dot.radius,
    Paint()
      ..color = dot.color ?? fallback
      ..isAntiAlias = true,
  );
  final ring = dot.strokeColor;
  if (ring != null && dot.strokeWidth > 0) {
    canvas.drawCircle(
      centre,
      dot.radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = dot.strokeWidth
        ..color = ring
        ..isAntiAlias = true,
    );
  }
}

/// Paints a [SeriesChart]'s crosshair and markers over the plot.
class SeriesOverlayPainter extends CustomPainter {
  /// Creates the overlay for [details].
  SeriesOverlayPainter({
    required this.geometry,
    required this.details,
    required this.touch,
  });

  final SeriesGeometry geometry;
  final SeriesTouchDetails details;
  final SeriesTouch touch;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = geometry.plot;
    final x = details.position.dx;
    if (x < plot.left - 0.5 || x > plot.right + 0.5) return;

    final vertical = touch.line;
    if (vertical != null && vertical.width > 0) {
      canvas.drawPath(
        dashSeriesPath(
          Path()
            ..moveTo(x, plot.top)
            ..lineTo(x, plot.bottom),
          vertical.dashPattern,
        ),
        SeriesChartPainter._strokePaint(vertical.color, vertical.width),
      );
    }

    final horizontal = touch.horizontalLine;
    if (horizontal != null &&
        horizontal.width > 0 &&
        details.values.isNotEmpty) {
      final y = details.values.first.position.dy;
      canvas.drawPath(
        dashSeriesPath(
          Path()
            ..moveTo(plot.left, y)
            ..lineTo(plot.right, y),
          horizontal.dashPattern,
        ),
        SeriesChartPainter._strokePaint(horizontal.color, horizontal.width),
      );
    }

    if (!touch.showMarkers) return;
    for (final value in details.values) {
      final builder = touch.markerBuilder;
      final dot = builder != null ? builder(value) : const SeriesDot(radius: 4);
      if (dot == null) continue;
      paintSeriesDot(canvas, value.position, dot, value.color);
    }
  }

  @override
  bool shouldRepaint(SeriesOverlayPainter oldDelegate) => true;
}
