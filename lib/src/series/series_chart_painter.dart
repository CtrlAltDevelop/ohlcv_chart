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
///
/// Everything here works in two numbers — an x and a value — and leaves it to
/// the geometry to say which way each of them runs, so an upright chart and a
/// horizontal one share one set of drawing code.
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
    required this.betweenFills,
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
  final List<SeriesBetweenFill> betweenFills;
  final Color? backgroundColor;
  final bool clipToPlot;
  final TextPainterCache textCache;

  /// Whether the x axis runs down the chart rather than across it.
  bool get _horizontal => geometry.isHorizontal;

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
    _paintBetweenFills(canvas);

    final barSeries = [
      for (final s in series)
        if (s is BarSeries) s,
    ];
    final barSpacing = _barSpacing(barSeries);
    // Counted by position, not looked up: the same series given twice is two
    // groups of bars side by side, not one drawn over the other. Series in a
    // stack share the group of the first of them, since they pile up in one
    // place rather than standing beside each other.
    final groupOf = _barGroups(barSeries);
    final groups = groupOf.isEmpty ? 0 : groupOf.values.reduce(math.max) + 1;
    var barIndex = 0;
    for (var i = 0; i < series.length; i++) {
      final row = i < values.length ? values[i] : const <double?>[];
      switch (series[i]) {
        case final LineSeries line:
          _paintLine(canvas, size, line, row);
        case final BarSeries bars:
          _paintBars(
            canvas,
            size,
            bars,
            i,
            row,
            groupOf[barIndex++] ?? 0,
            groups,
            barSpacing,
          );
        case final ScatterSeries dots:
          _paintScatter(canvas, dots, row);
      }
    }
    _paintReferenceLines(canvas, above: true);
    canvas.restore();

    _paintBorder(canvas);
    _paintReferenceLabels(canvas, size);
    _paintValueLabels(canvas, size);
    _paintXLabels(canvas, size);
    _paintAxisTitles(canvas, size);
  }

  // ── Plot furniture ──────────────────────────────────────────────────────

  void _paintBands(Canvas canvas) {
    for (final band in bands) {
      final rect = band.direction == SeriesDirection.horizontal
          ? geometry.valueBand(band.from, band.to)
          : geometry.xBand(band.from, band.to);
      final paint = _areaPaint(_orient(band.gradient), band.color, rect);
      if (paint != null) canvas.drawRect(rect, paint);
    }
  }

  void _paintGrid(Canvas canvas) {
    if (grid.horizontal && grid.width > 0) {
      final path = Path();
      for (final tick in geometry.viewport.yTicks) {
        _addLine(path, geometry.valueLine(tick));
      }
      canvas.drawPath(
        dashSeriesPath(path, grid.dashPattern),
        _strokePaint(grid.color, grid.width),
      );
    }
    if (grid.vertical && grid.width > 0) {
      final path = Path();
      for (final tick in geometry.viewport.xTicks) {
        _addLine(path, geometry.xLine(tick));
      }
      canvas.drawPath(
        dashSeriesPath(path, grid.verticalDashPattern ?? grid.dashPattern),
        _strokePaint(grid.verticalColor ?? grid.color, grid.width),
      );
    }
  }

  void _paintReferenceLines(Canvas canvas, {required bool above}) {
    for (final line in referenceLines) {
      if (line.aboveSeries != above || line.width <= 0) continue;
      final path = Path();
      _addLine(
        path,
        line.direction == SeriesDirection.horizontal
            ? geometry.valueLine(line.value)
            : geometry.xLine(line.value),
      );
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
      final style = seriesAxisLabelStyle
          .copyWith(color: line.color)
          .merge(line.labelStyle);
      final tp = textCache.get(label, style);
      final align = line.labelAlignment;
      final (start, end) = line.direction == SeriesDirection.horizontal
          ? geometry.valueLine(line.value)
          : geometry.xLine(line.value);
      final rect = Rect.fromPoints(start, end);
      if (rect.right < plot.left - 0.5 ||
          rect.left > plot.right + 0.5 ||
          rect.bottom < plot.top - 0.5 ||
          rect.top > plot.bottom + 0.5) {
        continue;
      }
      // A line is a segment, so one of these two is a length to slide the
      // label along and the other is the line itself to sit beside.
      final dx = rect.width > 0
          ? _lerp(rect.left + 4, rect.right - 4 - tp.width, (align.x + 1) / 2)
          : align.x < 0
          ? rect.left - tp.width - 2
          : align.x > 0
          ? rect.left + 2
          : rect.left - tp.width / 2;
      final dy = rect.height > 0
          ? _lerp(rect.top + 2, rect.bottom - 2 - tp.height, (align.y + 1) / 2)
          : align.y < 0
          ? rect.top - tp.height - 2
          : align.y > 0
          ? rect.top + 2
          : rect.top - tp.height / 2;
      tp.paint(
        canvas,
        Offset(
          dx.clamp(0.0, math.max(0.0, size.width - tp.width)),
          dy.clamp(0.0, math.max(0.0, size.height - tp.height)),
        ),
      );
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

  /// How much room the value labels take across their axis.
  double get _valueLabelRoom {
    if (!yAxis.show) return 0;
    if (!_horizontal) return yAxis.width;
    final style = seriesAxisLabelStyle.merge(yAxis.style);
    return textCache.get('0', style).height + yAxis.gap;
  }

  void _paintValueLabels(Canvas canvas, Size size) {
    if (!yAxis.show) return;
    final plot = geometry.plot;
    final style = seriesAxisLabelStyle.merge(yAxis.style);
    final step = geometry.viewport.yStep;
    var previousEnd = double.negativeInfinity;
    for (final tick in geometry.viewport.yTicks) {
      final text = yAxis.format(tick, step);
      if (text.isEmpty) continue;
      final tp = textCache.get(text, style);
      final at = geometry.yToPx(tick);
      final Offset offset;
      if (_horizontal) {
        final left = (at - tp.width / 2)
            .clamp(0.0, math.max(0.0, size.width - tp.width))
            .toDouble();
        if (left < previousEnd + 4) continue;
        previousEnd = left + tp.width;
        offset = Offset(
          left,
          yAxis.side == SeriesAxisSide.left
              ? plot.bottom + yAxis.gap
              : math.max(0.0, plot.top - yAxis.gap - tp.height),
        );
      } else {
        offset = Offset(
          yAxis.side == SeriesAxisSide.left
              ? math.max(0.0, plot.left - yAxis.gap - tp.width)
              : plot.right + yAxis.gap,
          (at - tp.height / 2).clamp(
            0.0,
            math.max(0.0, size.height - tp.height),
          ),
        );
      }
      tp.paint(canvas, offset);
    }
  }

  void _paintXLabels(Canvas canvas, Size size) {
    if (!xAxis.show) return;
    final plot = geometry.plot;
    final style = seriesAxisLabelStyle.merge(xAxis.style);
    var previousEnd = double.negativeInfinity;
    final step = geometry.viewport.xStep;
    for (final tick in geometry.viewport.xTicks) {
      final text = xAxis.labelFor(tick, step: step);
      if (text == null || text.isEmpty) continue;
      final tp = textCache.get(text, style);
      final at = geometry.xToPx(tick);
      final Offset offset;
      if (_horizontal) {
        var top = at - tp.height / 2;
        if (xAxis.fitInside) {
          top = top.clamp(0.0, math.max(0.0, size.height - tp.height));
        }
        if (top < previousEnd + 2) continue;
        previousEnd = top + tp.height;
        offset = Offset(
          xAxis.side == SeriesXSide.bottom
              ? math.max(0.0, plot.left - xAxis.gap - tp.width)
              : plot.right + xAxis.gap,
          top,
        );
      } else {
        var left = at - tp.width / 2;
        if (xAxis.fitInside) {
          left = left.clamp(0.0, math.max(0.0, size.width - tp.width));
        }
        // A label that would run into the one before it is dropped rather
        // than drawn on top of it.
        if (left < previousEnd + 4) continue;
        previousEnd = left + tp.width;
        offset = Offset(
          left,
          xAxis.side == SeriesXSide.bottom
              ? plot.bottom + xAxis.gap
              : math.max(0.0, plot.top - xAxis.gap - tp.height),
        );
      }
      tp.paint(canvas, offset);
    }
  }

  void _paintAxisTitles(Canvas canvas, Size size) {
    final plot = geometry.plot;
    final valueTitle = yAxis.title;
    if (yAxis.show && valueTitle != null && valueTitle.isNotEmpty) {
      final tp = textCache.get(
        valueTitle,
        seriesAxisTitleStyle.merge(yAxis.titleStyle),
      );
      final room = _valueLabelRoom;
      if (_horizontal) {
        _paintTitle(
          canvas,
          tp,
          along: plot.center.dx,
          across: yAxis.side == SeriesAxisSide.left
              ? plot.bottom + room + 2
              : plot.top - room - 2 - tp.height,
          turned: false,
          size: size,
        );
      } else {
        _paintTitle(
          canvas,
          tp,
          along: plot.center.dy,
          across: yAxis.side == SeriesAxisSide.left
              ? plot.left - room - 2 - tp.height
              : plot.right + room + 2,
          turned: true,
          size: size,
        );
      }
    }

    final xTitle = xAxis.title;
    if (xAxis.show && xTitle != null && xTitle.isNotEmpty) {
      final tp = textCache.get(
        xTitle,
        seriesAxisTitleStyle.merge(xAxis.titleStyle),
      );
      if (_horizontal) {
        _paintTitle(
          canvas,
          tp,
          along: plot.center.dy,
          across: xAxis.side == SeriesXSide.bottom
              ? plot.left - xAxis.height - 2 - tp.height
              : plot.right + xAxis.height + 2,
          turned: true,
          size: size,
        );
      } else {
        _paintTitle(
          canvas,
          tp,
          along: plot.center.dx,
          across: xAxis.side == SeriesXSide.bottom
              ? plot.bottom + xAxis.height + 2
              : plot.top - xAxis.height - 2 - tp.height,
          turned: false,
          size: size,
        );
      }
    }
  }

  /// Writes an axis title centred at [along] down its axis and [across] from
  /// the plot; [turned] reads it bottom-to-top, for an axis that runs down the
  /// chart.
  void _paintTitle(
    Canvas canvas,
    TextPainter tp, {
    required double along,
    required double across,
    required bool turned,
    required Size size,
  }) {
    if (turned) {
      final left = across.clamp(0.0, math.max(0.0, size.width - tp.height));
      canvas
        ..save()
        ..translate(left + tp.height, along + tp.width / 2)
        ..rotate(-math.pi / 2);
      tp.paint(canvas, Offset.zero);
      canvas.restore();
      return;
    }
    tp.paint(
      canvas,
      Offset(
        (along - tp.width / 2).clamp(0.0, math.max(0.0, size.width - tp.width)),
        across.clamp(0.0, math.max(0.0, size.height - tp.height)),
      ),
    );
  }

  // ── Lines ───────────────────────────────────────────────────────────────

  /// The pixels of one series' points, broken into unbroken runs at its gaps.
  List<List<Offset>> _runs(PlotSeries s, List<double?> row) {
    final runs = <List<Offset>>[];
    var run = <Offset>[];
    for (var j = 0; j < s.points.length; j++) {
      final x = s.points[j].x;
      final y = j < row.length ? row[j] : null;
      if (y == null || !y.isFinite || !x.isFinite) {
        if (run.isNotEmpty) {
          runs.add(run);
          run = <Offset>[];
        }
        continue;
      }
      run.add(geometry.point(x, y));
    }
    if (run.isNotEmpty) runs.add(run);
    return runs;
  }

  Path _runPath(LineSeries line, List<Offset> run) => seriesRunPath(
    run,
    line.curve,
    stepPosition: line.stepPosition,
    transpose: _horizontal,
  );

  void _paintLine(
    Canvas canvas,
    Size size,
    LineSeries line,
    List<double?> row,
  ) {
    final runs = _runs(line, row);
    if (runs.isEmpty) return;

    if (line.fill != null) _paintFill(canvas, size, line, runs);

    if (line.width > 0) {
      final path = Path();
      for (final run in runs) {
        path.addPath(_runPath(line, run), Offset.zero);
      }
      final dashed = dashSeriesPath(path, line.dashPattern);
      final shadow = line.shadow;
      if (shadow != null) {
        canvas.drawPath(
          dashed.shift(shadow.offset),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = line.width
            ..strokeCap = line.roundCap ? StrokeCap.round : StrokeCap.butt
            ..strokeJoin = StrokeJoin.round
            ..color = shadow.color
            ..maskFilter = shadow.blurRadius > 0
                ? MaskFilter.blur(BlurStyle.normal, shadow.blurRadius)
                : null,
        );
      }
      _paintStroke(canvas, size, line, dashed);
    }

    _paintDots(canvas, line, row);
    _paintErrorBars(canvas, line, row);
  }

  void _paintFill(
    Canvas canvas,
    Size size,
    LineSeries line,
    List<List<Offset>> runs,
  ) {
    final fill = line.fill!;
    final basePx = fill.toBaseline
        ? _clampValuePx(geometry.yToPx(line.baseline), inside: true)
        : _lowEdgePx;

    final area = Path();
    var high = double.nan;
    var low = double.nan;
    for (final run in runs) {
      if (run.length < 2) continue;
      area.addPath(_runPath(line, run), Offset.zero);
      _closeToBase(area, run, basePx);
      for (final p in run) {
        final at = _valuePx(p);
        high = high.isNaN ? at : _towardHigh(high, at);
        low = low.isNaN ? at : _towardLow(low, at);
      }
    }
    if (high.isNaN) return;

    if (!fill.toBaseline) {
      final paint = _areaPaint(
        fill.gradient,
        fill.color,
        _valueSpan(high, _lowEdgePx),
      );
      if (paint != null) canvas.drawPath(area, paint);
      return;
    }

    if (_isAbove(high, basePx)) {
      final paint = _areaPaint(
        fill.gradient,
        fill.color,
        _valueSpan(high, basePx),
      );
      if (paint != null) {
        canvas
          ..save()
          ..clipRect(_side(size, basePx, above: true))
          ..drawPath(area, paint)
          ..restore();
      }
    }

    if (_isAbove(basePx, low)) {
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
        _valueSpan(basePx, low),
      );
      if (paint != null) {
        canvas
          ..save()
          ..clipRect(_side(size, basePx, above: false))
          ..drawPath(area, paint)
          ..restore();
      }
    }
  }

  void _paintBetweenFills(Canvas canvas) {
    for (final between in betweenFills) {
      if (between.from < 0 ||
          between.from >= series.length ||
          between.to < 0 ||
          between.to >= series.length) {
        continue;
      }
      final first = series[between.from];
      final second = series[between.to];
      if (first is! LineSeries || second is! LineSeries) continue;
      final top = _runs(first, _rowOf(between.from)).expand((r) => r).toList();
      final bottom = _runs(
        second,
        _rowOf(between.to),
      ).expand((r) => r).toList();
      if (top.length < 2 || bottom.length < 2) continue;

      final path = Path()
        ..addPath(_runPath(first, top), Offset.zero)
        ..extendWithPath(
          _runPath(second, bottom.reversed.toList()),
          Offset.zero,
        )
        ..close();
      final paint = _areaPaint(between.gradient, between.color, geometry.plot);
      if (paint != null) canvas.drawPath(path, paint);
    }
  }

  List<double?> _rowOf(int index) =>
      index < values.length ? values[index] : const <double?>[];

  void _paintStroke(Canvas canvas, Size size, LineSeries line, Path path) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = line.width
      ..strokeCap = line.roundCap ? StrokeCap.round : StrokeCap.butt
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final gradient = line.gradient;
    if (gradient != null) {
      paint.shader = _orient(gradient)!.createShader(geometry.plot);
    } else {
      paint.color = line.color;
    }

    final negative = line.negativeColor;
    if (negative == null) {
      canvas.drawPath(path, paint);
      return;
    }

    // Split at the baseline: whatever lies beyond it keeps the series colour
    // and whatever lies short of it takes the negative one, cut exactly where
    // the line crosses rather than at the nearest point.
    final basePx = geometry.yToPx(line.baseline);
    canvas
      ..save()
      ..clipRect(_side(size, basePx, above: true))
      ..drawPath(path, paint)
      ..restore();
    paint
      ..shader = null
      ..color = negative;
    canvas
      ..save()
      ..clipRect(_side(size, basePx, above: false))
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
        geometry.point(point.x, y),
        dot,
        line.colorAt(point.y!),
      );
    }
  }

  // ── Scatter ─────────────────────────────────────────────────────────────

  void _paintScatter(Canvas canvas, ScatterSeries scatter, List<double?> row) {
    for (var j = 0; j < scatter.points.length && j < row.length; j++) {
      final y = row[j];
      final point = scatter.points[j];
      if (y == null || !y.isFinite || point.isGap) continue;
      final at = geometry.point(point.x, y);
      final dot = scatter.dotAt(j, point);
      final color = scatter.colorAt(point.y!);
      if (dot != null) paintSeriesDot(canvas, at, dot, color);
      final label = scatter.labelBuilder?.call(j, point);
      if (label != null && label.isNotEmpty) {
        final tp = textCache.get(
          label,
          seriesAxisLabelStyle.copyWith(color: color).merge(scatter.labelStyle),
        );
        tp.paint(
          canvas,
          Offset(
            at.dx - tp.width / 2,
            at.dy - (dot?.radius ?? 0) - tp.height - 2,
          ),
        );
      }
    }
    _paintErrorBars(canvas, scatter, row);
  }

  // ── Error bars ──────────────────────────────────────────────────────────

  void _paintErrorBars(Canvas canvas, PlotSeries s, List<double?> row) {
    final style = s.errorBars;
    if (style == null || style.width <= 0) return;
    Paint? paint;
    for (var j = 0; j < s.points.length && j < row.length; j++) {
      final y = row[j];
      final point = s.points[j];
      if (y == null || !y.isFinite || point.isGap) continue;
      final vertical = point.yError;
      final horizontal = point.xError;
      if (vertical == null && horizontal == null) continue;
      paint ??= _strokePaint(
        style.color ?? s.colorAt(point.y ?? s.baseline),
        style.width,
      );
      if (vertical != null) {
        _paintErrorBar(
          canvas,
          paint,
          from: geometry.point(point.x, y - vertical.lowerBy),
          to: geometry.point(point.x, y + vertical.upperBy),
          capLength: style.capLength,
          alongValue: true,
        );
      }
      if (horizontal != null) {
        _paintErrorBar(
          canvas,
          paint,
          from: geometry.point(point.x - horizontal.lowerBy, y),
          to: geometry.point(point.x + horizontal.upperBy, y),
          capLength: style.capLength,
          alongValue: false,
        );
      }
    }
  }

  void _paintErrorBar(
    Canvas canvas,
    Paint paint, {
    required Offset from,
    required Offset to,
    required double capLength,
    required bool alongValue,
  }) {
    canvas.drawLine(from, to, paint);
    if (capLength <= 0) return;
    // The caps cross the bar, so they run along whichever axis it does not.
    final cap = alongValue == _horizontal
        ? Offset(0, capLength / 2)
        : Offset(capLength / 2, 0);
    canvas
      ..drawLine(from - cap, from + cap, paint)
      ..drawLine(to - cap, to + cap, paint);
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

  /// The group each bar series stands in, counted along [bars]: series that
  /// share a stack share a group, and everything else gets its own.
  static Map<int, int> _barGroups(List<BarSeries> bars) {
    final groups = <int, int>{};
    final stacks = <Object, int>{};
    var next = 0;
    for (var i = 0; i < bars.length; i++) {
      final stack = bars[i].stack;
      if (stack == null) {
        groups[i] = next++;
      } else {
        groups[i] = stacks.putIfAbsent(stack, () => next++);
      }
    }
    return groups;
  }

  void _paintBars(
    Canvas canvas,
    Size size,
    BarSeries bars,
    int index,
    List<double?> row,
    int group,
    int groups,
    double spacing,
  ) {
    final slot = geometry.unitWidth * spacing;
    const gap = 2.0;
    final raw = bars.width ?? slot * bars.widthFactor / math.max(1, groups);
    final width = raw
        .clamp(bars.minWidth, math.max(bars.minWidth, bars.maxWidth))
        .toDouble();
    final offset =
        (group - (groups - 1) / 2) * (width + (groups > 1 ? gap : 0));

    final track = bars.trackColor;
    final trackPath = Path();
    final byColor = <Color, Path>{};
    final shaded = <RRect>[];
    final outlined = <RRect>[];

    for (var j = 0; j < bars.points.length && j < row.length; j++) {
      final y = row[j];
      final point = bars.points[j];
      if (y == null || !y.isFinite || point.isGap) continue;

      // Where the bar starts: on the stack under it, on its own low, or on
      // the series' baseline.
      final double from;
      final double to;
      if (bars.stack != null) {
        from = stackedBase(series, values, index, j);
        to = from + (y - bars.baseline);
      } else {
        from = point.low ?? bars.baseline;
        to = y;
      }

      final centre = geometry.xToPx(point.x) + offset;
      final rect = _barRect(
        centre,
        width,
        _clampValuePx(geometry.yToPx(from), inside: true),
        _clampValuePx(geometry.yToPx(to)),
      );
      if (!rect.overlaps(geometry.plot.inflate(width))) continue;

      if (track != null) {
        trackPath.addRRect(
          RRect.fromRectAndCorners(
            _trackRect(centre, width),
            topLeft: bars.radius.topLeft,
            topRight: bars.radius.topRight,
            bottomLeft: bars.radius.bottomLeft,
            bottomRight: bars.radius.bottomRight,
          ).scaleRadii(),
        );
      }

      final shape = seriesBarBox(rect: rect, radius: bars.radius);
      if (shape == null) continue;
      if (bars.gradient != null) {
        shaded.add(shape);
      } else {
        byColor
            .putIfAbsent(bars.barColorAt(j, point), Path.new)
            .addRRect(shape);
      }
      if (bars.border != null) outlined.add(shape);
      _paintBarLabel(canvas, bars, j, point, rect, positive: to >= from);
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
          Paint()..shader = _orient(gradient)!.createShader(shape.outerRect),
        );
      }
    }
    final side = bars.border;
    if (side != null && side.style != BorderStyle.none && side.width > 0) {
      final paint = _strokePaint(side.color, side.width);
      for (final shape in outlined) {
        canvas.drawRRect(shape.deflate(side.width / 2), paint);
      }
    }
    _paintErrorBars(canvas, bars, row);
  }

  void _paintBarLabel(
    Canvas canvas,
    BarSeries bars,
    int index,
    SeriesPoint point,
    Rect rect, {
    required bool positive,
  }) {
    final label = bars.labelBuilder?.call(index, point);
    if (label == null || label.isEmpty) return;
    final tp = textCache.get(
      label,
      seriesAxisLabelStyle.merge(bars.labelStyle),
    );
    const pad = 3.0;
    final Offset offset;
    if (_horizontal) {
      offset = Offset(
        positive ? rect.right + pad : rect.left - pad - tp.width,
        rect.center.dy - tp.height / 2,
      );
    } else {
      offset = Offset(
        rect.center.dx - tp.width / 2,
        positive ? rect.top - pad - tp.height : rect.bottom + pad,
      );
    }
    tp.paint(canvas, offset);
  }

  /// One bar: [width] across the x axis at [centre], reaching from [fromPx] to
  /// [toPx] along the value axis.
  Rect _barRect(double centre, double width, double fromPx, double toPx) {
    final low = math.min(fromPx, toPx);
    final high = math.max(fromPx, toPx);
    return _horizontal
        ? Rect.fromLTRB(low, centre - width / 2, high, centre + width / 2)
        : Rect.fromLTRB(centre - width / 2, low, centre + width / 2, high);
  }

  Rect _trackRect(double centre, double width) {
    final plot = geometry.plot;
    return _horizontal
        ? Rect.fromLTRB(
            plot.left,
            centre - width / 2,
            plot.right,
            centre + width / 2,
          )
        : Rect.fromLTRB(
            centre - width / 2,
            plot.top,
            centre + width / 2,
            plot.bottom,
          );
  }

  // ── The value axis in pixels ────────────────────────────────────────────

  /// Where on the screen a point sits along the value axis.
  double _valuePx(Offset p) => _horizontal ? p.dx : p.dy;

  /// The pixel of the plot edge the low values are at.
  double get _lowEdgePx =>
      _horizontal ? geometry.plot.left : geometry.plot.bottom;

  /// Whichever of two value pixels stands for the higher value.
  double _towardHigh(double a, double b) =>
      _horizontal ? math.max(a, b) : math.min(a, b);

  /// Whichever of two value pixels stands for the lower value.
  double _towardLow(double a, double b) =>
      _horizontal ? math.min(a, b) : math.max(a, b);

  /// Whether the value at pixel [a] is above the one at [b].
  bool _isAbove(double a, double b) => _horizontal ? a > b : a < b;

  /// A pixel on the value axis brought back to the plot, [inside] keeping it
  /// strictly within rather than a pixel over the edge.
  double _clampValuePx(double px, {bool inside = false}) {
    final plot = geometry.plot;
    final slack = inside ? 0.0 : 1.0;
    return _horizontal
        ? px.clamp(plot.left - slack, plot.right + slack)
        : px.clamp(plot.top - slack, plot.bottom + slack);
  }

  /// The stretch of plot between two value pixels, right across the x axis.
  Rect _valueSpan(double a, double b) {
    final plot = geometry.plot;
    final low = math.min(a, b);
    final high = math.max(a, b);
    return _horizontal
        ? Rect.fromLTRB(low, plot.top, math.max(high, low + 1), plot.bottom)
        : Rect.fromLTRB(plot.left, low, plot.right, math.max(high, low + 1));
  }

  /// The half of the chart on one side of the value pixel [basePx].
  Rect _side(Size size, double basePx, {required bool above}) {
    if (_horizontal) {
      return above
          ? Rect.fromLTRB(basePx, 0, size.width, size.height)
          : Rect.fromLTRB(0, 0, basePx, size.height);
    }
    return above
        ? Rect.fromLTRB(0, 0, size.width, basePx)
        : Rect.fromLTRB(0, basePx, size.width, size.height);
  }

  /// Closes a filled area back to the baseline at [basePx].
  void _closeToBase(Path area, List<Offset> run, double basePx) {
    if (_horizontal) {
      area
        ..lineTo(basePx, run.last.dy)
        ..lineTo(basePx, run.first.dy);
    } else {
      area
        ..lineTo(run.last.dx, basePx)
        ..lineTo(run.first.dx, basePx);
    }
    area.close();
  }

  void _addLine(Path path, (Offset, Offset) line) {
    path
      ..moveTo(line.$1.dx, line.$1.dy)
      ..lineTo(line.$2.dx, line.$2.dy);
  }

  /// A gradient written for an upright chart, turned to follow a horizontal
  /// one: what pointed at the high values still does.
  Gradient? _orient(Gradient? gradient) {
    if (!_horizontal || gradient is! LinearGradient) return gradient;
    return LinearGradient(
      begin: _turn(gradient.begin),
      end: _turn(gradient.end),
      colors: gradient.colors,
      stops: gradient.stops,
      tileMode: gradient.tileMode,
      transform: gradient.transform,
    );
  }

  static AlignmentGeometry _turn(AlignmentGeometry alignment) =>
      alignment is Alignment ? Alignment(-alignment.y, alignment.x) : alignment;

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
  final fill = Paint()
    ..color = dot.color ?? fallback
    ..isAntiAlias = true;
  final ring = dot.strokeColor;
  final ringPaint = ring == null || dot.strokeWidth <= 0
      ? null
      : (Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = dot.strokeWidth
          ..color = ring
          ..isAntiAlias = true);

  switch (dot.shape) {
    case SeriesDotShape.circle:
      canvas.drawCircle(centre, dot.radius, fill);
      if (ringPaint != null) canvas.drawCircle(centre, dot.radius, ringPaint);
    case SeriesDotShape.square:
      final rect = Rect.fromCenter(
        center: centre,
        width: dot.radius * 2,
        height: dot.radius * 2,
      );
      canvas.drawRect(rect, fill);
      if (ringPaint != null) canvas.drawRect(rect, ringPaint);
    case SeriesDotShape.diamond:
      final path = Path()
        ..moveTo(centre.dx, centre.dy - dot.radius)
        ..lineTo(centre.dx + dot.radius, centre.dy)
        ..lineTo(centre.dx, centre.dy + dot.radius)
        ..lineTo(centre.dx - dot.radius, centre.dy)
        ..close();
      canvas.drawPath(path, fill);
      if (ringPaint != null) canvas.drawPath(path, ringPaint);
    case SeriesDotShape.cross:
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = dot.strokeWidth > 0
            ? dot.strokeWidth
            : math.max(1.0, dot.radius / 3)
        ..color = dot.color ?? fallback
        ..isAntiAlias = true;
      final r = dot.radius;
      canvas
        ..drawLine(centre + Offset(-r, -r), centre + Offset(r, r), stroke)
        ..drawLine(centre + Offset(-r, r), centre + Offset(r, -r), stroke);
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
    final across = touch.line;
    if (across != null && across.width > 0) {
      final (start, end) = geometry.xLine(details.x);
      if (_inside(start, plot) && _inside(end, plot)) {
        canvas.drawPath(
          dashSeriesPath(
            Path()
              ..moveTo(start.dx, start.dy)
              ..lineTo(end.dx, end.dy),
            across.dashPattern,
          ),
          SeriesChartPainter._strokePaint(across.color, across.width),
        );
      }
    }

    final along = touch.horizontalLine;
    if (along != null && along.width > 0 && details.values.isNotEmpty) {
      final (start, end) = geometry.valueLine(details.values.first.value);
      canvas.drawPath(
        dashSeriesPath(
          Path()
            ..moveTo(start.dx, start.dy)
            ..lineTo(end.dx, end.dy),
          along.dashPattern,
        ),
        SeriesChartPainter._strokePaint(along.color, along.width),
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

  static bool _inside(Offset p, Rect plot) =>
      p.dx >= plot.left - 0.5 &&
      p.dx <= plot.right + 0.5 &&
      p.dy >= plot.top - 0.5 &&
      p.dy <= plot.bottom + 0.5;

  @override
  bool shouldRepaint(SeriesOverlayPainter oldDelegate) => true;
}
