import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

import '../treemap/treemap_data.dart' show treemapPalette;
import '../utils/plot_scaffold.dart';
import '../utils/xy_plot.dart';

/// One reading from a training run: the step it was taken at, and its value.
@immutable
class TrainingPoint {
  /// Creates a reading of [value] at [step].
  const TrainingPoint(this.step, this.value);

  /// The optimiser step, or the epoch or the number of tokens seen.
  final double step;

  /// The loss, the accuracy, or whatever is being tracked; a value that is not
  /// finite leaves a gap.
  final double value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingPoint && other.step == step && other.value == value;

  @override
  int get hashCode => Object.hash(step, value);
}

/// One training run: a named series of readings.
@immutable
class TrainingRun {
  /// Creates a run called [label] through [points], in order of step.
  const TrainingRun({
    required this.label,
    required this.points,
    this.color,
    this.dashed = false,
    this.data,
  });

  /// What the run is called: `train`, `val`, `lr=3e-4`.
  final String label;

  /// The readings, by rising step.
  final List<TrainingPoint> points;

  /// A colour of this run's own; null takes one from the chart's palette.
  final Color? color;

  /// Whether the line is dashed, to set a validation curve apart.
  final bool dashed;

  /// Anything the app wants back when this run is touched.
  final Object? data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingRun &&
          other.label == label &&
          listEquals(other.points, points) &&
          other.color == color &&
          other.dashed == dashed &&
          other.data == data;

  @override
  int get hashCode =>
      Object.hash(label, Object.hashAll(points), color, dashed, data);
}

/// Smooths [values] with the exponential moving average training dashboards
/// use, corrected for its slow start so the first readings are not dragged
/// toward zero.
///
/// [weight] runs from 0 (no smoothing) to just under 1 (a very slow average). A
/// value that is not finite is skipped — the average carries on across it — and
/// comes back as null in its own place.
List<double?> smoothValues(List<double> values, double weight) {
  final w = weight.isFinite ? weight.clamp(0.0, 0.999) : 0.0;
  var last = 0.0;
  var count = 0;
  return [
    for (final value in values)
      if (!value.isFinite)
        null
      else
        () {
          last = last * w + (1 - w) * value;
          count++;
          final debias = 1 - math.pow(w, count).toDouble();
          return debias <= 0 ? value : last / debias;
        }(),
  ];
}

/// The index of the best value in [values]: the lowest, or the highest when
/// [lowerIsBetter] is false. Null when none is finite. The first of equals.
int? bestIndex(List<double> values, {bool lowerIsBetter = true}) {
  int? best;
  for (var i = 0; i < values.length; i++) {
    final v = values[i];
    if (!v.isFinite) continue;
    if (best == null || (lowerIsBetter ? v < values[best] : v > values[best])) {
      best = i;
    }
  }
  return best;
}

/// The index where a loss curve blew up: the first value that is not finite
/// after finite ones, or that climbs past [factor] times the lowest it had
/// reached. Null when it never did.
int? divergenceIndex(List<double> values, {double factor = 3}) {
  var lowest = double.infinity;
  for (var i = 0; i < values.length; i++) {
    final v = values[i];
    if (!v.isFinite) {
      if (lowest.isFinite) return i;
      continue;
    }
    if (lowest.isFinite && lowest > 0 && v > lowest * factor) return i;
    lowest = math.min(lowest, v);
  }
  return null;
}

/// One run's reading at the step under the pointer.
@immutable
class TrainingReading {
  /// Creates a reading of [run] at the touched step.
  const TrainingReading({
    required this.run,
    required this.runIndex,
    required this.point,
    required this.smoothed,
  });

  /// The run.
  final TrainingRun run;

  /// Its position in the chart's runs.
  final int runIndex;

  /// Its reading nearest the touched step; null when it has none.
  final TrainingPoint? point;

  /// The smoothed value there; null when it has none.
  final double? smoothed;
}

/// What a touch on a [TrainingCurveChart] landed on: a step, and every run's
/// reading at it.
@immutable
class TrainingTouchDetails {
  /// Creates the details of a touch at [step].
  const TrainingTouchDetails({required this.step, required this.readings});

  /// The step touched.
  final double step;

  /// Each run's reading near it, in the chart's order.
  final List<TrainingReading> readings;
}

/// Loss and accuracy curves of one or more training runs: smoothing, a log
/// axis, the best checkpoint and the point a run diverged.
///
/// ```dart
/// TrainingCurveChart(
///   runs: [
///     TrainingRun(label: 'train', points: train),
///     TrainingRun(label: 'val', points: val, dashed: true),
///   ],
///   smoothing: 0.9,
///   gapBetween: (0, 1), // shade the overfitting gap
/// );
/// ```
///
/// The raw readings are drawn faintly under the smoothed line. The chart fills
/// the box it is given, and is [defaultHeight] high in a box with no height of
/// its own.
class TrainingCurveChart extends StatelessWidget {
  /// Creates a chart of [runs].
  const TrainingCurveChart({
    super.key,
    required this.runs,
    this.smoothing = 0,
    this.showRaw = true,
    this.rawOpacity = 0.25,
    this.lowerIsBetter = true,
    this.logY = false,
    this.showBest = true,
    this.showDivergence = true,
    this.divergenceFactor = 3,
    this.gapBetween,
    this.gapColor = const Color(0x33E03131),
    this.lineWidth = 2,
    this.palette = treemapPalette,
    this.showLegend = true,
    this.legendStyle,
    this.showAxes = true,
    this.axisWidth = 48,
    this.axisHeight = 18,
    this.tickCount = 5,
    this.stepFormatter,
    this.valueFormatter,
    this.axisLabelStyle,
    this.xAxisTitle = 'Step',
    this.yAxisTitle,
    this.axisTitleStyle,
    this.gridColor = const Color(0x22FFFFFF),
    this.crosshairColor = const Color(0x66FFFFFF),
    this.bestColor = const Color(0xFFF2B01E),
    this.divergenceColor = const Color(0xFFE03131),
    this.onTouch,
    this.tooltipBuilder,
    this.tooltipMargin = 12,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.defaultHeight = 280,
    this.semanticLabel,
  });

  /// The runs, drawn in this order and given palette colours in it.
  final List<TrainingRun> runs;

  /// How much the lines are smoothed, from 0 (not at all) to just under 1.
  final double smoothing;

  /// Whether the raw readings are drawn faintly under a smoothed line.
  final bool showRaw;

  /// How opaque the raw readings are.
  final double rawOpacity;

  /// Whether a lower value is better — a loss — or a higher one — accuracy.
  final bool lowerIsBetter;

  /// Whether the value axis is logarithmic, for losses spanning decades.
  final bool logY;

  /// Whether each run's best checkpoint is marked.
  final bool showBest;

  /// Whether the step a run's loss blew up at is marked.
  final bool showDivergence;

  /// How many times its lowest value a loss must climb to count as diverged.
  final double divergenceFactor;

  /// The indices of two runs — typically train and validation — whose gap is
  /// shaded. Null shades nothing.
  final (int, int)? gapBetween;

  /// The colour of that shading.
  final Color gapColor;

  /// How thick a line is.
  final double lineWidth;

  /// Colours taken in turn by runs that name none.
  final List<Color> palette;

  /// Whether the runs' names are listed in the corner.
  final bool showLegend;

  /// Style of the legend.
  final TextStyle? legendStyle;

  /// Whether the two axes are drawn.
  final bool showAxes;

  /// How much room the value axis takes.
  final double axisWidth;

  /// How much room the step axis takes.
  final double axisHeight;

  /// About how many ticks to write on each axis.
  final int tickCount;

  /// Writes a step; null writes at most two decimals.
  final String Function(double step)? stepFormatter;

  /// Writes a value; null writes at most two decimals.
  final String Function(double value)? valueFormatter;

  /// Style of an axis label.
  final TextStyle? axisLabelStyle;

  /// Written under the step axis.
  final String? xAxisTitle;

  /// Written up the value axis.
  final String? yAxisTitle;

  /// Style of an axis title.
  final TextStyle? axisTitleStyle;

  /// Colour of the grid ruled at each tick; null rules none.
  final Color? gridColor;

  /// The colour of the line under the pointer.
  final Color crosshairColor;

  /// The colour of the best-checkpoint marker.
  final Color bestColor;

  /// The colour of the divergence marker.
  final Color divergenceColor;

  /// Called as a touch moves along the steps, and with null when it leaves.
  final ValueChanged<TrainingTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched step; null shows none.
  final Widget? Function(BuildContext context, TrainingTouchDetails details)?
  tooltipBuilder;

  /// How far the card sits from the crosshair.
  final double tooltipMargin;

  /// How long the lines take to draw in; zero draws them at once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build animates.
  final bool animateOnMount;

  /// Space kept clear around the chart.
  final EdgeInsets padding;

  /// Painted behind the whole chart.
  final Color? backgroundColor;

  /// The height taken in a box that sets none.
  final double defaultHeight;

  /// What a screen reader announces for the chart.
  final String? semanticLabel;

  Color _colorOf(int index) {
    final own = runs[index].color;
    if (own != null) return own;
    if (palette.isEmpty) return const Color(0xFF4C86CD);
    return palette[index % palette.length];
  }

  _Frame _frame() {
    var minStep = double.infinity;
    var maxStep = double.negativeInfinity;
    final values = <double>[];
    final smoothed = <List<double?>>[];
    for (final run in runs) {
      final raw = [for (final p in run.points) p.value];
      final line = smoothValues(raw, smoothing);
      smoothed.add(line);
      for (final p in run.points) {
        if (!p.step.isFinite) continue;
        minStep = math.min(minStep, p.step);
        maxStep = math.max(maxStep, p.step);
      }
      for (var i = 0; i < raw.length; i++) {
        final v = raw[i];
        if (v.isFinite && (!logY || v > 0)) values.add(v);
        final s = line[i];
        if (s != null && (!logY || s > 0)) values.add(s);
      }
    }
    if (!minStep.isFinite) {
      minStep = 0;
      maxStep = 1;
    }
    if (minStep == maxStep) maxStep = minStep + 1;

    double lo;
    double hi;
    if (values.isEmpty) {
      lo = logY ? 0.1 : 0;
      hi = logY ? 10 : 1;
    } else if (logY) {
      lo = values.reduce(math.min);
      hi = values.reduce(math.max);
      if (lo == hi) {
        lo /= 2;
        hi *= 2;
      }
      // Half a decade of room, so the lowest curve is not drawn on the axis.
      lo /= 1.4;
      hi *= 1.4;
    } else {
      final r = paddedRange(values, pad: 0.06);
      lo = r.min;
      hi = r.max;
    }
    return _Frame(
      minStep: minStep,
      maxStep: maxStep,
      minValue: lo,
      maxValue: hi,
      smoothed: smoothed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frame();
    final insets = EdgeInsets.fromLTRB(
      showAxes ? axisWidth : 0,
      0,
      0,
      showAxes ? axisHeight + (xAxisTitle != null ? 14 : 0) : 0,
    );

    Offset at(Rect plot, double step, double value) {
      final x = mapAcross(
        step,
        frame.minStep,
        frame.maxStep,
        plot.left,
        plot.right,
      );
      final y = logY
          ? mapAcrossLog(
                  value,
                  frame.minValue,
                  frame.maxValue,
                  plot.bottom,
                  plot.top,
                ) ??
                double.nan
          : mapAcross(
              value,
              frame.minValue,
              frame.maxValue,
              plot.bottom,
              plot.top,
            );
      return Offset(x, y);
    }

    TrainingTouchDetails? hit(Offset local, Rect plot) {
      if (!plot.inflate(2).contains(local) || runs.isEmpty) return null;
      // The step nearest the pointer among every run's readings.
      double? nearest;
      var closest = double.infinity;
      for (final run in runs) {
        for (final p in run.points) {
          if (!p.step.isFinite) continue;
          final x = mapAcross(
            p.step,
            frame.minStep,
            frame.maxStep,
            plot.left,
            plot.right,
          );
          final d = (x - local.dx).abs();
          if (d < closest) {
            closest = d;
            nearest = p.step;
          }
        }
      }
      if (nearest == null) return null;
      return TrainingTouchDetails(
        step: nearest,
        readings: [
          for (var r = 0; r < runs.length; r++)
            () {
              TrainingPoint? best;
              var bestIndex = -1;
              var gap = double.infinity;
              for (var i = 0; i < runs[r].points.length; i++) {
                final p = runs[r].points[i];
                if (!p.step.isFinite) continue;
                final d = (p.step - nearest!).abs();
                if (d < gap) {
                  gap = d;
                  best = p;
                  bestIndex = i;
                }
              }
              return TrainingReading(
                run: runs[r],
                runIndex: r,
                point: best,
                smoothed: bestIndex < 0 ? null : frame.smoothed[r][bestIndex],
              );
            }(),
        ],
      );
    }

    return PlotScaffold<TrainingTouchDetails>(
      restartKey: Object.hashAll([...runs, smoothing, logY]),
      insets: insets,
      padding: padding,
      backgroundColor: backgroundColor,
      defaultHeight: defaultHeight,
      animationDuration: animationDuration,
      animationCurve: animationCurve,
      animateOnMount: animateOnMount,
      semanticLabel: semanticLabel,
      tooltipMargin: tooltipMargin,
      onTouch: onTouch,
      tooltipBuilder: tooltipBuilder,
      hitTest: hit,
      keyOf: (d) => d.step,
      anchorOf: (d, plot) {
        final x = mapAcross(
          d.step,
          frame.minStep,
          frame.maxStep,
          plot.left,
          plot.right,
        );
        return Rect.fromLTRB(x - 1, plot.top, x + 1, plot.bottom);
      },
      painter: (plot, t, text, hovered) => _TrainingCurvePainter(
        chart: this,
        frame: frame,
        project: (step, value) => at(plot, step, value),
        plot: plot,
        animation: t,
        text: text,
        hovered: hovered,
        backgroundColor: backgroundColor,
        colorOf: _colorOf,
      ),
    );
  }
}

class _Frame {
  const _Frame({
    required this.minStep,
    required this.maxStep,
    required this.minValue,
    required this.maxValue,
    required this.smoothed,
  });

  final double minStep, maxStep, minValue, maxValue;
  final List<List<double?>> smoothed;
}

class _TrainingCurvePainter extends PlotPainter {
  _TrainingCurvePainter({
    required this.chart,
    required this.frame,
    required this.project,
    required this.hovered,
    required this.colorOf,
    required super.plot,
    required super.animation,
    required super.text,
    super.backgroundColor,
  });

  final TrainingCurveChart chart;
  final _Frame frame;
  final Offset Function(double step, double value) project;
  final TrainingTouchDetails? hovered;
  final Color Function(int index) colorOf;

  @override
  void paintPlot(Canvas canvas, Size size) {
    paintXyAxes(
      canvas,
      text,
      plot: plot,
      minX: frame.minStep,
      maxX: frame.maxStep,
      minY: frame.minValue,
      maxY: frame.maxValue,
      tickCount: chart.tickCount,
      gridColor: chart.gridColor,
      showAxes: chart.showAxes,
      xFormatter: chart.stepFormatter,
      yFormatter: chart.valueFormatter,
      labelStyle: chart.axisLabelStyle,
      xTitle: chart.xAxisTitle,
      yTitle: chart.yAxisTitle,
      titleStyle: chart.axisTitleStyle,
      axisWidth: chart.axisWidth,
      axisHeight: chart.axisHeight,
      logY: chart.logY,
    );

    final t = animation.clamp(0.0, 1.0);
    canvas
      ..save()
      ..clipRect(
        Rect.fromLTRB(
          plot.left,
          plot.top,
          plot.left + plot.width * t + 2,
          plot.bottom,
        ),
      );

    _paintGap(canvas);
    for (var r = 0; r < chart.runs.length; r++) {
      _paintRun(canvas, r);
    }
    canvas.restore();

    for (var r = 0; r < chart.runs.length; r++) {
      _paintMarkers(canvas, r);
    }
    _paintCrosshair(canvas);
    _paintLegend(canvas);
  }

  /// The polyline through a run's points, broken wherever a value is missing.
  List<List<Offset>> _segments(int r, {required bool smoothed}) {
    final run = chart.runs[r];
    final line = frame.smoothed[r];
    final segments = <List<Offset>>[];
    var current = <Offset>[];
    for (var i = 0; i < run.points.length; i++) {
      final p = run.points[i];
      final value = smoothed ? line[i] : p.value;
      final usable =
          p.step.isFinite &&
          value != null &&
          value.isFinite &&
          (!chart.logY || value > 0);
      if (!usable) {
        if (current.length > 1) segments.add(current);
        current = <Offset>[];
        continue;
      }
      final o = project(p.step, value);
      if (!o.dx.isFinite || !o.dy.isFinite) continue;
      current.add(o);
    }
    if (current.length > 1) segments.add(current);
    return segments;
  }

  void _paintGap(Canvas canvas) {
    final gap = chart.gapBetween;
    if (gap == null) return;
    final a = gap.$1;
    final b = gap.$2;
    if (a < 0 || b < 0 || a >= chart.runs.length || b >= chart.runs.length) {
      return;
    }
    final upper = _segments(a, smoothed: true);
    final lower = _segments(b, smoothed: true);
    if (upper.isEmpty || lower.isEmpty) return;
    // One band between the two lines, over the steps they share.
    final top = [for (final s in upper) ...s];
    final bottom = [for (final s in lower) ...s];
    final path = Path()..moveTo(top.first.dx, top.first.dy);
    for (final o in top.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    for (final o in bottom.reversed) {
      path.lineTo(o.dx, o.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = chart.gapColor);
  }

  void _paintRun(Canvas canvas, int r) {
    final color = colorOf(r);
    final dashed = chart.runs[r].dashed;
    final smoothed = chart.smoothing > 0;

    if (smoothed && chart.showRaw) {
      final pen = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, chart.lineWidth - 1)
        ..color = color.withValues(alpha: chart.rawOpacity.clamp(0.0, 1.0))
        ..isAntiAlias = true;
      for (final segment in _segments(r, smoothed: false)) {
        _polyline(canvas, segment, pen, false);
      }
    }

    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = chart.lineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color
      ..isAntiAlias = true;
    for (final segment in _segments(r, smoothed: true)) {
      _polyline(canvas, segment, pen, dashed);
    }
  }

  void _polyline(Canvas canvas, List<Offset> points, Paint pen, bool dashed) {
    if (!dashed) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final o in points.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, pen);
      return;
    }
    const dash = 6.0;
    const gap = 4.0;
    var draw = true;
    var remaining = dash;
    for (var i = 1; i < points.length; i++) {
      var from = points[i - 1];
      final to = points[i];
      var length = (to - from).distance;
      if (length <= 0) continue;
      final direction = (to - from) / length;
      while (length > 0) {
        final step = math.min(remaining, length);
        final end = from + direction * step;
        if (draw) canvas.drawLine(from, end, pen);
        from = end;
        length -= step;
        remaining -= step;
        if (remaining <= 0) {
          draw = !draw;
          remaining = draw ? dash : gap;
        }
      }
    }
  }

  void _paintMarkers(Canvas canvas, int r) {
    final run = chart.runs[r];
    final values = [
      for (var i = 0; i < run.points.length; i++)
        frame.smoothed[r][i] ?? double.nan,
    ];
    if (chart.showBest) {
      final index = bestIndex(values, lowerIsBetter: chart.lowerIsBetter);
      if (index != null && (!chart.logY || values[index] > 0)) {
        final o = project(run.points[index].step, values[index]);
        if (o.dx.isFinite && o.dy.isFinite && plot.inflate(2).contains(o)) {
          canvas.drawCircle(
            o,
            5,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = chart.bestColor
              ..isAntiAlias = true,
          );
          canvas.drawCircle(
            o,
            2,
            Paint()
              ..color = chart.bestColor
              ..isAntiAlias = true,
          );
        }
      }
    }
    if (chart.showDivergence && chart.lowerIsBetter) {
      final index = divergenceIndex([
        for (final p in run.points) p.value,
      ], factor: chart.divergenceFactor);
      if (index != null) {
        final x = mapAcross(
          run.points[index].step,
          frame.minStep,
          frame.maxStep,
          plot.left,
          plot.right,
        );
        if (x.isFinite && x >= plot.left && x <= plot.right) {
          canvas.drawLine(
            Offset(x, plot.top),
            Offset(x, plot.bottom),
            Paint()
              ..color = chart.divergenceColor.withValues(alpha: 0.7)
              ..strokeWidth = 1,
          );
          final tp = text.get(
            'diverged',
            TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: chart.divergenceColor,
            ),
          );
          final left = math.min(x + 4, plot.right - tp.width);
          tp.paint(canvas, Offset(math.max(plot.left, left), plot.top + 2));
        }
      }
    }
  }

  void _paintCrosshair(Canvas canvas) {
    final at = hovered;
    if (at == null) return;
    final x = mapAcross(
      at.step,
      frame.minStep,
      frame.maxStep,
      plot.left,
      plot.right,
    );
    canvas.drawLine(
      Offset(x, plot.top),
      Offset(x, plot.bottom),
      Paint()
        ..color = chart.crosshairColor
        ..strokeWidth = 1,
    );
    for (final reading in at.readings) {
      final v = reading.smoothed;
      if (v == null || (chart.logY && v <= 0)) continue;
      final o = project(at.step, v);
      if (!o.dx.isFinite || !o.dy.isFinite) continue;
      canvas.drawCircle(
        o,
        4,
        Paint()
          ..color = colorOf(reading.runIndex)
          ..isAntiAlias = true,
      );
    }
  }

  void _paintLegend(Canvas canvas) {
    if (!chart.showLegend || chart.runs.length < 2) return;
    final style = const TextStyle(
      fontSize: 10,
      color: Color(0xCCFFFFFF),
    ).merge(chart.legendStyle);
    var top = plot.top + 4;
    for (var r = 0; r < chart.runs.length; r++) {
      final tp = text.get(chart.runs[r].label, style);
      final left = plot.right - 8 - tp.width;
      canvas.drawLine(
        Offset(left - 22, top + tp.height / 2),
        Offset(left - 6, top + tp.height / 2),
        Paint()
          ..color = colorOf(r)
          ..strokeWidth = 2,
      );
      tp.paint(canvas, Offset(left, top));
      top += tp.height + 3;
    }
  }
}
