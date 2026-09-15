import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';
import '../series/series_axis.dart';
import '../utils/axis_ticks.dart';

/// How a simulated trade's result is applied to the account.
enum MonteCarloSizing {
  /// Results are fractions of the account — 0.02 is 2% — and compound.
  compound,

  /// Results are amounts of money, added as they are.
  fixed,
}

/// The percentiles a [MonteCarloResult] reads by default: the middle 50% and
/// 90% of outcomes, and the median.
const List<double> defaultMonteCarloPercentiles = [0.05, 0.25, 0.5, 0.75, 0.95];

/// The value [p] of the way through [sorted], from 0 to 1, interpolating
/// between neighbours.
double _quantile(List<double> sorted, double p) {
  if (sorted.isEmpty) return double.nan;
  final at = p.clamp(0.0, 1.0) * (sorted.length - 1);
  final below = at.floor();
  final above = math.min(below + 1, sorted.length - 1);
  return sorted[below] + (sorted[above] - sorted[below]) * (at - below);
}

/// What many simulated equity paths say: their spread at every step, and how
/// often they ended badly.
@immutable
class MonteCarloResult {
  /// Creates a result from its parts; see [MonteCarloResult.fromPaths].
  const MonteCarloResult({
    required this.paths,
    required this.startingEquity,
    required this.percentiles,
    required this.bands,
    required this.maxDrawdowns,
    this.ruinLevel,
  });

  /// Reads [paths] — each an account's value at every step, starting with
  /// [startingEquity] — at [percentiles].
  ///
  /// Paths of unequal length are read up to the shortest. [ruinLevel], when
  /// given, is the account value counted as ruin.
  factory MonteCarloResult.fromPaths(
    List<List<double>> paths, {
    required double startingEquity,
    List<double> percentiles = defaultMonteCarloPercentiles,
    double? ruinLevel,
  }) {
    final levels = [...percentiles]..sort();
    final length =
        paths.isEmpty ? 0 : paths.map((path) => path.length).reduce(math.min);

    final bands = [for (final _ in levels) List<double>.filled(length, 0)];
    final column = List<double>.filled(paths.length, 0);
    for (var step = 0; step < length; step++) {
      for (var i = 0; i < paths.length; i++) {
        column[i] = paths[i][step];
      }
      column.sort();
      for (var p = 0; p < levels.length; p++) {
        bands[p][step] = _quantile(column, levels[p]);
      }
    }

    return MonteCarloResult(
      paths: paths,
      startingEquity: startingEquity,
      percentiles: levels,
      bands: length == 0 ? const [] : bands,
      maxDrawdowns: [for (final path in paths) _maxDrawdown(path, length)],
      ruinLevel: ruinLevel,
    );
  }

  /// Every simulated path, each the account's value at every step.
  final List<List<double>> paths;

  /// What each path began with.
  final double startingEquity;

  /// The percentiles [bands] reads, ascending.
  final List<double> percentiles;

  /// For each percentile, its value at every step.
  final List<List<double>> bands;

  /// Each path's deepest fall from a high, as a fraction: -0.3 is 30% down.
  final List<double> maxDrawdowns;

  /// The account value counted as ruin; null counts none.
  final double? ruinLevel;

  /// Whether there is nothing to show.
  bool get isEmpty => bands.isEmpty || bands.first.isEmpty;

  /// How many trades each path runs for.
  int get steps => isEmpty ? 0 : bands.first.length - 1;

  /// The band for percentile [p], or null when it was not read.
  List<double>? bandAt(double p) {
    for (var i = 0; i < percentiles.length; i++) {
      if ((percentiles[i] - p).abs() < 1e-9) return bands[i];
    }
    return null;
  }

  /// Where the paths ended, lowest first.
  List<double> get finalEquities => [
        for (final path in paths)
          if (path.length > steps) path[steps]
      ]..sort();

  /// The final value [p] of the way up the outcomes: 0.05 is the worst 5%.
  double finalEquityAt(double p) => _quantile(finalEquities, p);

  /// The deepest drawdown [p] of the way up the outcomes: 0.05 is a fall only
  /// one path in twenty was worse than.
  double drawdownAt(double p) => _quantile([...maxDrawdowns]..sort(), p);

  /// The share of paths that ended below where they started.
  double get lossProbability {
    if (paths.isEmpty || isEmpty) return 0;
    var below = 0;
    for (final path in paths) {
      if (path[steps] < startingEquity) below++;
    }
    return below / paths.length;
  }

  /// The share of paths that touched [ruinLevel] at any step; zero without
  /// one.
  double get ruinProbability {
    final level = ruinLevel;
    if (level == null || paths.isEmpty || isEmpty) return 0;
    var ruined = 0;
    for (final path in paths) {
      for (var step = 0; step <= steps; step++) {
        if (path[step] <= level) {
          ruined++;
          break;
        }
      }
    }
    return ruined / paths.length;
  }
}

double _maxDrawdown(List<double> path, int length) {
  var peak = double.negativeInfinity;
  var deepest = 0.0;
  for (var i = 0; i < length; i++) {
    peak = math.max(peak, path[i]);
    if (peak > 0) deepest = math.min(deepest, path[i] / peak - 1);
  }
  return deepest;
}

/// Simulates [pathCount] accounts, each taking [steps] trades drawn at random,
/// with replacement, from [results] — the trades a backtest produced.
///
/// Each draw reshuffles the order luck dealt the trades in, so the spread of
/// the paths shows what the same edge could have looked like. [sizing] says
/// whether results are fractions that compound or amounts that add; an account
/// never falls below zero. [steps] defaults to the number of results, and
/// [seed] makes the run repeatable.
MonteCarloResult runMonteCarlo(
  List<double> results, {
  int pathCount = 1000,
  int? steps,
  double startingEquity = 10000,
  MonteCarloSizing sizing = MonteCarloSizing.compound,
  int? seed,
  List<double> percentiles = defaultMonteCarloPercentiles,
  double? ruinLevel,
}) {
  final pool = [
    for (final r in results)
      if (r.isFinite) r,
  ];
  final length = steps ?? pool.length;
  if (pool.isEmpty || pathCount < 1 || length < 1) {
    return MonteCarloResult.fromPaths(
      const [],
      startingEquity: startingEquity,
      percentiles: percentiles,
      ruinLevel: ruinLevel,
    );
  }

  final random = math.Random(seed);
  final paths = [
    for (var p = 0; p < pathCount; p++)
      () {
        final path = List<double>.filled(length + 1, startingEquity);
        var equity = startingEquity;
        for (var step = 1; step <= length; step++) {
          final r = pool[random.nextInt(pool.length)];
          equity = switch (sizing) {
            MonteCarloSizing.compound => equity * (1 + r),
            MonteCarloSizing.fixed => equity + r,
          };
          if (equity < 0) equity = 0;
          path[step] = equity;
        }
        return path;
      }(),
  ];
  return MonteCarloResult.fromPaths(
    paths,
    startingEquity: startingEquity,
    percentiles: percentiles,
    ruinLevel: ruinLevel,
  );
}

/// Where a Monte Carlo fan was laid out.
@immutable
class MonteCarloLayout {
  /// Creates a layout.
  const MonteCarloLayout({
    required this.plot,
    required this.min,
    required this.max,
    required this.steps,
    required this.bands,
    required this.samples,
    required this.actual,
  });

  /// The area the fan is drawn in.
  final Rect plot;

  /// The bottom of the value axis.
  final double min;

  /// The top of it.
  final double max;

  /// How many steps span the width.
  final int steps;

  /// For each percentile, a point at every step.
  final List<List<Offset>> bands;

  /// The individual paths drawn faintly behind the fan.
  final List<List<Offset>> samples;

  /// The real curve, laid over the fan; empty when there is none.
  final List<Offset> actual;

  /// Whether nothing was laid out.
  bool get isEmpty => bands.isEmpty;

  /// Where [step] sits across the plot.
  double xOf(num step) =>
      steps <= 0 ? plot.left : plot.left + step / steps * plot.width;

  /// Where [value] sits up the plot.
  double yOf(double value) {
    final span = max - min;
    if (span <= 0) return plot.center.dy;
    return plot.bottom - (value - min) / span * plot.height;
  }

  /// The step nearest [dx], or null when nothing was laid out.
  int? stepAt(double dx) {
    if (isEmpty || plot.width <= 0) return null;
    return ((dx - plot.left) / plot.width * steps).round().clamp(0, steps);
  }
}

/// Places [result] in [bounds], with [sampleCount] of its paths and the
/// [actual] curve alongside.
///
/// [min] and [max] default to the outermost percentiles, the starting equity,
/// the ruin level and everything else drawn, with a little room.
MonteCarloLayout layOutMonteCarlo(
  MonteCarloResult result,
  Rect bounds, {
  double? min,
  double? max,
  int sampleCount = 0,
  List<double>? actual,
}) {
  if (result.isEmpty || bounds.width <= 0 || bounds.height <= 0) {
    return MonteCarloLayout(
      plot: bounds,
      min: 0,
      max: 1,
      steps: 0,
      bands: const [],
      samples: const [],
      actual: const [],
    );
  }

  final steps = result.steps;
  final count = math.min(math.max(0, sampleCount), result.paths.length);
  final sampled = [
    for (var i = 0; i < count; i++)
      result.paths[i * result.paths.length ~/ count],
  ];
  final real = [
    for (final value in actual ?? const <double>[])
      if (value.isFinite) value,
  ];

  var low = min ?? double.infinity;
  var high = max ?? double.negativeInfinity;
  void take(double value) {
    if (!value.isFinite) return;
    if (min == null) low = math.min(low, value);
    if (max == null) high = math.max(high, value);
  }

  take(result.startingEquity);
  final ruin = result.ruinLevel;
  if (ruin != null) take(ruin);
  for (final value in result.bands.first) {
    take(value);
  }
  for (final value in result.bands.last) {
    take(value);
  }
  for (final path in sampled) {
    for (var step = 0; step <= steps; step++) {
      take(path[step]);
    }
  }
  for (final value in real.take(steps + 1)) {
    take(value);
  }
  if (!low.isFinite || !high.isFinite || high <= low) {
    final centre = result.startingEquity;
    low = centre - 1;
    high = centre + 1;
  } else {
    final room = (high - low) * 0.04;
    if (min == null) low -= room;
    if (max == null) high += room;
  }

  final shell = MonteCarloLayout(
    plot: bounds,
    min: low,
    max: high,
    steps: steps,
    bands: const [],
    samples: const [],
    actual: const [],
  );
  List<Offset> line(List<double> values) => [
        for (var step = 0; step <= steps && step < values.length; step++)
          Offset(shell.xOf(step), shell.yOf(values[step])),
      ];

  return MonteCarloLayout(
    plot: bounds,
    min: low,
    max: high,
    steps: steps,
    bands: [for (final band in result.bands) line(band)],
    samples: [for (final path in sampled) line(path)],
    actual: line(real),
  );
}

/// What a touch on a [MonteCarloChart] landed on.
@immutable
class MonteCarloTouchDetails {
  /// Creates the details of a touch at [step].
  const MonteCarloTouchDetails({
    required this.step,
    required this.percentiles,
    required this.values,
    required this.actual,
    required this.at,
  });

  /// Which trade it is, from zero at the start.
  final int step;

  /// The percentiles read, ascending.
  final List<double> percentiles;

  /// Each percentile's value at [step].
  final List<double> values;

  /// The real curve's value there; null past its end or without one.
  final double? actual;

  /// Where the middle band sits at [step], in the chart's local pixels.
  final Offset at;

  /// The value at percentile [p], or null when it was not read.
  double? valueAt(double p) {
    for (var i = 0; i < percentiles.length; i++) {
      if ((percentiles[i] - p).abs() < 1e-9) return values[i];
    }
    return null;
  }
}

/// A fan of simulated equity curves: what a strategy's trades could have made
/// in another order, drawn as percentile bands round the median.
///
/// ```dart
/// MonteCarloChart(
///   result: runMonteCarlo(tradeReturns, seed: 7, ruinLevel: 5000),
///   actual: [for (final p in equity) p.equity],
/// );
/// ```
///
/// Simulating is kept out of the widget so it runs once, not on every build;
/// keep the [MonteCarloResult] in state. The chart fills the box it is given,
/// and is [defaultHeight] high in a box with no height of its own.
class MonteCarloChart extends StatefulWidget {
  /// Creates a fan of [result].
  const MonteCarloChart({
    super.key,
    required this.result,
    this.actual,
    this.min,
    this.max,
    this.sampleCount = 20,
    this.bandColor = const Color(0xFF4C86CD),
    this.bandOpacity = 0.16,
    this.medianColor = const Color(0xFF74A9E8),
    this.medianWidth = 2,
    this.sampleColor = const Color(0x1FFFFFFF),
    this.actualColor = const Color(0xFFF59F00),
    this.actualWidth = 1.5,
    this.startLineColor = const Color(0x66FFFFFF),
    this.ruinColor = const Color(0xFFE03131),
    this.showSummary = true,
    this.summaryStyle,
    this.showValueAxis = true,
    this.axisWidth = 52,
    this.showStepAxis = true,
    this.stepAxisHeight = 16,
    this.tickCount = 5,
    this.valueFormatter,
    this.stepFormatter,
    this.axisLabelStyle,
    this.gridColor = const Color(0x22FFFFFF),
    this.crosshairColor = const Color(0x66FFFFFF),
    this.onTouch,
    this.tooltipBuilder,
    this.tooltipMargin = 10,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.defaultHeight = 280,
    this.semanticLabel,
  });

  /// The simulation to draw.
  final MonteCarloResult result;

  /// The real equity curve, one value per trade from the start, laid over the
  /// fan; null draws none.
  final List<double>? actual;

  /// The bottom of the value axis; null reads it off what is drawn.
  final double? min;

  /// The top of it; null reads it off what is drawn.
  final double? max;

  /// How many individual paths are drawn faintly behind the fan.
  final int sampleCount;

  /// The colour of the bands.
  final Color bandColor;

  /// How opaque each band is; inner bands, drawn over outer ones, come out
  /// stronger.
  final double bandOpacity;

  /// The colour of the median.
  final Color medianColor;

  /// How thick the median is.
  final double medianWidth;

  /// The colour of the sample paths.
  final Color sampleColor;

  /// The colour of the real curve.
  final Color actualColor;

  /// How thick the real curve is.
  final double actualWidth;

  /// The colour of the line at the starting equity; null draws none.
  final Color? startLineColor;

  /// The colour of the line at the ruin level, when there is one; null draws
  /// none.
  final Color? ruinColor;

  /// Whether the median, the outer range and the odds of loss and ruin are
  /// written at the top left.
  final bool showSummary;

  /// Style of that text.
  final TextStyle? summaryStyle;

  /// Whether the value axis is written down the left.
  final bool showValueAxis;

  /// How much room that axis takes.
  final double axisWidth;

  /// Whether trade numbers are written along the bottom.
  final bool showStepAxis;

  /// How much room they take.
  final double stepAxisHeight;

  /// About how many ticks to write on each axis.
  final int tickCount;

  /// Writes a value; null writes whole numbers, thousands as `12.3k`.
  final String Function(double value)? valueFormatter;

  /// Writes a trade number; null writes the number.
  final String Function(int step)? stepFormatter;

  /// Style of an axis label.
  final TextStyle? axisLabelStyle;

  /// Colour of the grid; null rules none.
  final Color? gridColor;

  /// Colour of the line drawn at the touched step; null draws none.
  final Color? crosshairColor;

  /// Called as a touch moves along the chart, and with null when it leaves.
  final ValueChanged<MonteCarloTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched step; null shows none.
  final Widget? Function(BuildContext context, MonteCarloTouchDetails details)?
      tooltipBuilder;

  /// How far the card sits from the median.
  final double tooltipMargin;

  /// How long the fan takes to draw itself in; zero draws it at once.
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

  @override
  State<MonteCarloChart> createState() => _MonteCarloChartState();
}

class _MonteCarloChartState extends State<MonteCarloChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 64);
  MonteCarloLayout? _layout;
  int? _touched;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
      value: 1,
    )..addListener(() => setState(() {}));
    if (widget.animateOnMount && widget.animationDuration > Duration.zero) {
      _animation.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(MonteCarloChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!identical(oldWidget.result, widget.result)) {
      _touched = null;
      if (widget.animationDuration > Duration.zero) {
        _animation.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void _handle(Offset local) {
    final step = _layout?.stepAt(local.dx);
    if (step == _touched) return;
    setState(() => _touched = step);
    widget.onTouch?.call(step == null ? null : _detailsAt(step));
  }

  void _leave() {
    if (_touched == null) return;
    setState(() => _touched = null);
    widget.onTouch?.call(null);
  }

  MonteCarloTouchDetails? _detailsAt(int step) {
    final layout = _layout;
    final result = widget.result;
    if (layout == null || result.isEmpty || step > result.steps) return null;
    final middle = layout.bands[layout.bands.length ~/ 2];
    final actual = widget.actual;
    return MonteCarloTouchDetails(
      step: step,
      percentiles: result.percentiles,
      values: [for (final band in result.bands) band[step]],
      actual: actual != null && step < actual.length ? actual[step] : null,
      at: middle[step],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.animationCurve.transform(_animation.value);

    Widget chart = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.maybeSizeOf(context)?.width ?? 300;
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : widget.defaultHeight;
        final size = Size(width, height);
        final box = widget.padding.deflateRect(Offset.zero & size);
        final plot = Rect.fromLTRB(
          box.left + (widget.showValueAxis ? widget.axisWidth : 0),
          box.top,
          math.max(box.left, box.right),
          math.max(
            box.top,
            box.bottom - (widget.showStepAxis ? widget.stepAxisHeight : 0),
          ),
        );
        final layout = _layout = layOutMonteCarlo(
          widget.result,
          plot,
          min: widget.min,
          max: widget.max,
          sampleCount: widget.sampleCount,
          actual: widget.actual,
        );

        final touched = _touched;
        final details = touched == null ? null : _detailsAt(touched);
        final builder = widget.tooltipBuilder;
        final tooltip = details == null || builder == null
            ? null
            : builder(context, details);

        return SizedBox(
          width: width,
          height: height,
          child: MouseRegion(
            onHover: (e) => _handle(e.localPosition),
            onExit: (_) => _leave(),
            // Raw pointer events so the crosshair follows a drag at once.
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e) => _handle(e.localPosition),
              onPointerMove: (e) => _handle(e.localPosition),
              onPointerUp: (_) => _leave(),
              onPointerCancel: (_) => _leave(),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: MonteCarloChartPainter(
                        chart: widget,
                        layout: layout,
                        touched: details?.step,
                        animation: t,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (tooltip != null && details != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomSingleChildLayout(
                          delegate: _MonteCarloTooltipLayout(
                            anchor: details.at,
                            margin: widget.tooltipMargin,
                          ),
                          child: tooltip,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );

    final label = widget.semanticLabel;
    if (label != null) {
      chart = Semantics(container: true, label: label, child: chart);
    }
    return chart;
  }
}

/// Puts the tooltip beside the touched step, kept inside the chart.
class _MonteCarloTooltipLayout extends SingleChildLayoutDelegate {
  _MonteCarloTooltipLayout({required this.anchor, required this.margin});

  final Offset anchor;
  final double margin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var left = anchor.dx + margin;
    if (left + childSize.width > size.width) {
      left = anchor.dx - margin - childSize.width;
    }
    return Offset(
      left.clamp(0.0, math.max(0.0, size.width - childSize.width)),
      (anchor.dy - childSize.height - margin).clamp(
        0.0,
        math.max(0.0, size.height - childSize.height),
      ),
    );
  }

  @override
  bool shouldRelayout(_MonteCarloTooltipLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.margin != margin;
}

/// Paints a [MonteCarloChart]: the bands, the median, the sample paths, the
/// real curve and the summary.
class MonteCarloChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [layout].
  MonteCarloChartPainter({
    required this.chart,
    required this.layout,
    required this.touched,
    required this.animation,
    required this.textCache,
  });

  final MonteCarloChart chart;
  final MonteCarloLayout layout;
  final int? touched;
  final double animation;
  final TextPainterCache textCache;

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (layout.isEmpty) return;

    _paintAxes(canvas);
    _paintLevels(canvas);

    final t = animation.clamp(0.0, 1.0);
    final shown = math.max(1, (layout.steps * t).ceil()) + 1;

    canvas
      ..save()
      ..clipRect(layout.plot);
    _paintSamples(canvas, shown);
    _paintBands(canvas, shown);
    _paintActual(canvas, shown);
    canvas.restore();

    if (t >= 1) {
      _paintCrosshair(canvas);
      if (chart.showSummary) _paintSummary(canvas);
    }
  }

  void _paintSamples(Canvas canvas, int shown) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = chart.sampleColor
      ..isAntiAlias = true;
    for (final sample in layout.samples) {
      canvas.drawPath(_line(sample.take(shown).toList()), paint);
    }
  }

  void _paintBands(Canvas canvas, int shown) {
    final bands = [for (final band in layout.bands) band.take(shown).toList()];
    final fill = Paint()
      ..color = chart.bandColor.withValues(
        alpha: chart.bandColor.a * chart.bandOpacity.clamp(0.0, 1.0),
      )
      ..isAntiAlias = true;

    // Pair the lowest with the highest, and so on inwards.
    for (var i = 0; i < bands.length ~/ 2; i++) {
      final lower = bands[i];
      final upper = bands[bands.length - 1 - i];
      if (lower.length < 2) continue;
      final path = Path()..moveTo(upper.first.dx, upper.first.dy);
      for (final point in upper.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      for (final point in lower.reversed) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path..close(), fill);
    }

    if (bands.length.isOdd) {
      canvas.drawPath(
        _line(bands[bands.length ~/ 2]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = chart.medianWidth
          ..strokeJoin = StrokeJoin.round
          ..color = chart.medianColor
          ..isAntiAlias = true,
      );
    }
  }

  void _paintActual(Canvas canvas, int shown) {
    if (layout.actual.length < 2) return;
    canvas.drawPath(
      _line(layout.actual.take(shown).toList()),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = chart.actualWidth
        ..strokeJoin = StrokeJoin.round
        ..color = chart.actualColor
        ..isAntiAlias = true,
    );
  }

  Path _line(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path;
  }

  void _paintLevels(Canvas canvas) {
    void level(double value, Color? color) {
      if (color == null || value < layout.min || value > layout.max) return;
      final y = layout.yOf(value);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 1;
      // Dashed, so it reads as a reference rather than data.
      for (var x = layout.plot.left; x < layout.plot.right; x += 8) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 4, layout.plot.right), y),
          paint,
        );
      }
    }

    level(chart.result.startingEquity, chart.startLineColor);
    final ruin = chart.result.ruinLevel;
    if (ruin != null) level(ruin, chart.ruinColor);
  }

  void _paintCrosshair(Canvas canvas) {
    final step = touched;
    final color = chart.crosshairColor;
    if (step == null || color == null) return;
    final x = layout.xOf(step);
    canvas.drawLine(
      Offset(x, layout.plot.top),
      Offset(x, layout.plot.bottom),
      Paint()
        ..color = color
        ..strokeWidth = 1,
    );
    if (layout.bands.length.isOdd) {
      final middle = layout.bands[layout.bands.length ~/ 2];
      if (step < middle.length) {
        canvas.drawCircle(
          middle[step],
          3,
          Paint()
            ..color = chart.medianColor
            ..isAntiAlias = true,
        );
      }
    }
  }

  void _paintSummary(Canvas canvas) {
    final result = chart.result;
    final low = result.percentiles.first;
    final high = result.percentiles.last;
    final style = seriesAxisLabelStyle
        .copyWith(color: const Color(0xCCFFFFFF))
        .merge(chart.summaryStyle);
    String percent(double p) => '${(p * 100).toStringAsFixed(0)}%';
    final lines = [
      'median ${_formatValue(result.finalEquityAt(0.5))}  ·  '
          '${percent(low)}–${percent(high)} '
          '${_formatValue(result.finalEquityAt(low))} – '
          '${_formatValue(result.finalEquityAt(high))}',
      'loss ${percent(result.lossProbability)}'
          '${result.ruinLevel == null ? '' : '  ·  ruin ${percent(result.ruinProbability)}'}'
          '  ·  drawdown ${percent(-result.drawdownAt(0.5))} median, '
          '${percent(-result.drawdownAt(0.05))} worst 5%',
    ];
    var y = layout.plot.top + 4;
    for (final line in lines) {
      final tp = textCache.get(line, style);
      tp.paint(canvas, Offset(layout.plot.left + 6, y));
      y += tp.height + 2;
    }
  }

  void _paintAxes(Canvas canvas) {
    final grid = chart.gridColor;
    final style = seriesAxisLabelStyle.merge(chart.axisLabelStyle);
    final line = grid == null
        ? null
        : (Paint()
          ..color = grid
          ..strokeWidth = 1);

    for (final tick in niceTicks(
      layout.min,
      layout.max,
      target: chart.tickCount,
    )) {
      final y = layout.yOf(tick);
      if (line != null) {
        canvas.drawLine(
          Offset(layout.plot.left, y),
          Offset(layout.plot.right, y),
          line,
        );
      }
      if (!chart.showValueAxis) continue;
      final tp = textCache.get(_formatValue(tick), style);
      final left = layout.plot.left - 6 - tp.width;
      if (left >= 0) tp.paint(canvas, Offset(left, y - tp.height / 2));
    }

    if (!chart.showStepAxis || layout.steps <= 0) return;
    var written = -double.infinity;
    for (final tick
        in niceTicks(0, layout.steps.toDouble(), target: chart.tickCount)) {
      if (tick != tick.roundToDouble()) continue;
      final step = tick.round();
      final format = chart.stepFormatter;
      final tp = textCache.get(
        format == null ? '$step' : format(step),
        style,
      );
      final left = (layout.xOf(step) - tp.width / 2).clamp(
        layout.plot.left,
        math.max(layout.plot.left, layout.plot.right - tp.width),
      );
      if (left < written) continue;
      tp.paint(canvas, Offset(left.toDouble(), layout.plot.bottom + 3));
      written = left + tp.width + 6;
    }
  }

  String _formatValue(double value) {
    final format = chart.valueFormatter;
    if (format != null) return format(value);
    if (!value.isFinite) return '–';
    if (value.abs() >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value.abs() >= 1000) {
      final thousands = value / 1000;
      return '${thousands.toStringAsFixed(thousands.abs() >= 100 ? 0 : 1)}k';
    }
    return value.round().toString();
  }

  @override
  bool shouldRepaint(MonteCarloChartPainter oldDelegate) =>
      !identical(oldDelegate.chart, chart) ||
      !identical(oldDelegate.layout, layout) ||
      oldDelegate.touched != touched ||
      oldDelegate.animation != animation;
}
