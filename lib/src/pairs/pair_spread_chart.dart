import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';
import '../series/series_axis.dart';
import '../utils/axis_ticks.dart';

/// Two instruments' prices at one time.
@immutable
class PairPoint {
  /// Creates the prices [a] and [b] at [time].
  const PairPoint({
    required this.time,
    required this.a,
    required this.b,
    this.data,
  });

  /// When both prices were taken.
  final DateTime time;

  /// The first instrument's price — the one bought when the spread is bought.
  final double a;

  /// The second instrument's price — the hedge.
  final double b;

  /// Anything the app wants back when this point is touched.
  final Object? data;
}

/// Pairs two price series by time, keeping only the times both have.
///
/// The result is in time order.
List<PairPoint> alignPairSeries(
  List<({DateTime time, double value})> a,
  List<({DateTime time, double value})> b,
) {
  final byTime = <DateTime, double>{
    for (final point in b) point.time: point.value,
  };
  return [
    for (final point in a)
      if (byTime.containsKey(point.time))
        PairPoint(time: point.time, a: point.value, b: byTime[point.time]!),
  ]..sort((x, y) => x.time.compareTo(y.time));
}

/// How two prices are made into one series.
enum PairSpreadMode {
  /// `a / b`.
  ratio,

  /// `ln(a / b)`, which treats a move either way alike.
  logRatio,

  /// `a - hedgeRatio × b`.
  difference,
}

/// The hedge ratio that best explains [points]' `a` by their `b` — the slope of
/// an ordinary least-squares fit — or 1 when there is no spread in `b` to fit.
double pairHedgeRatio(List<PairPoint> points) {
  var n = 0;
  var sumA = 0.0;
  var sumB = 0.0;
  var sumBB = 0.0;
  var sumAB = 0.0;
  for (final point in points) {
    if (!point.a.isFinite || !point.b.isFinite) continue;
    n++;
    sumA += point.a;
    sumB += point.b;
    sumBB += point.b * point.b;
    sumAB += point.a * point.b;
  }
  if (n < 2) return 1;
  final variance = sumBB - sumB * sumB / n;
  if (variance.abs() < 1e-12) return 1;
  return (sumAB - sumA * sumB / n) / variance;
}

/// [points] made into one series by [mode]; a value that cannot be worked out
/// — a ratio over zero, say — is NaN, and draws as a gap.
List<double> pairSpread(
  List<PairPoint> points, {
  PairSpreadMode mode = PairSpreadMode.ratio,
  double hedgeRatio = 1,
}) => [
  for (final point in points)
    switch (mode) {
      PairSpreadMode.ratio => point.b == 0 ? double.nan : point.a / point.b,
      PairSpreadMode.logRatio =>
        point.a > 0 && point.b > 0 ? math.log(point.a / point.b) : double.nan,
      PairSpreadMode.difference => point.a - hedgeRatio * point.b,
    },
];

/// The mean and standard deviation of the [lookback] values ending at each
/// index; null until the window is full, or while it holds a gap.
List<({double mean, double deviation})?> rollingMeanDeviation(
  List<double> values,
  int lookback,
) {
  final out = List<({double mean, double deviation})?>.filled(
    values.length,
    null,
  );
  if (lookback < 1) return out;
  for (var i = lookback - 1; i < values.length; i++) {
    var sum = 0.0;
    var squares = 0.0;
    var gap = false;
    for (var j = i - lookback + 1; j <= i; j++) {
      final v = values[j];
      if (!v.isFinite) {
        gap = true;
        break;
      }
      sum += v;
      squares += v * v;
    }
    if (gap) continue;
    final mean = sum / lookback;
    final variance = math.max(0.0, squares / lookback - mean * mean);
    out[i] = (mean: mean, deviation: math.sqrt(variance));
  }
  return out;
}

/// How many standard deviations each of [values] sits from the mean of the
/// [lookback] values ending there; null until the window is full, and zero
/// when the window does not move.
List<double?> rollingZScore(List<double> values, int lookback) {
  final stats = rollingMeanDeviation(values, lookback);
  return [
    for (var i = 0; i < values.length; i++)
      () {
        final s = stats[i];
        if (s == null) return null;
        // A window this flat has no spread to be measured against.
        if (s.deviation <= 1e-12 * math.max(1.0, s.mean.abs())) return 0.0;
        return (values[i] - s.mean) / s.deviation;
      }(),
  ];
}

/// What a pair-trading signal says to do.
enum PairSignalKind {
  /// The spread is stretched high: sell `a`, buy `b`.
  enterShort,

  /// The spread is stretched low: buy `a`, sell `b`.
  enterLong,

  /// The spread has come back: close the trade.
  exit,
}

/// A point where the z-score crossed a threshold.
@immutable
class PairSignal {
  /// Creates a signal of [kind] at [index].
  const PairSignal({required this.index, required this.kind});

  /// Which point it is.
  final int index;

  /// What it says to do.
  final PairSignalKind kind;
}

/// Reads entries and exits off a z-score: short the spread when it reaches
/// [entry], long when it reaches minus [entry], and close when it comes back
/// to [exit] on the same side, or through it.
///
/// One trade is open at a time; null scores are passed over.
List<PairSignal> pairSignals(
  List<double?> zScores, {
  double entry = 2,
  double exit = 0,
}) {
  final signals = <PairSignal>[];
  var position = 0;
  for (var i = 0; i < zScores.length; i++) {
    final z = zScores[i];
    if (z == null || !z.isFinite) continue;
    if (position == 0) {
      if (z >= entry) {
        position = -1;
        signals.add(PairSignal(index: i, kind: PairSignalKind.enterShort));
      } else if (z <= -entry) {
        position = 1;
        signals.add(PairSignal(index: i, kind: PairSignalKind.enterLong));
      }
    } else if ((position < 0 && z <= exit) || (position > 0 && z >= -exit)) {
      position = 0;
      signals.add(PairSignal(index: i, kind: PairSignalKind.exit));
    }
  }
  return signals;
}

/// Where a pair spread chart was laid out.
@immutable
class PairSpreadLayout {
  /// Creates a layout.
  const PairSpreadLayout({
    required this.spreadRect,
    required this.zRect,
    required this.count,
    required this.spread,
    required this.bands,
    required this.zScores,
    required this.spreadMin,
    required this.spreadMax,
    required this.zLimit,
  });

  /// Nothing laid out.
  static const PairSpreadLayout empty = PairSpreadLayout(
    spreadRect: Rect.zero,
    zRect: Rect.zero,
    count: 0,
    spread: [],
    bands: [],
    zScores: [],
    spreadMin: 0,
    spreadMax: 1,
    zLimit: 1,
  );

  /// The upper panel, holding the spread and its bands.
  final Rect spreadRect;

  /// The lower panel, holding the z-score.
  final Rect zRect;

  /// How many points span the width.
  final int count;

  /// The spread at each point.
  final List<double> spread;

  /// The rolling mean and deviation at each point.
  final List<({double mean, double deviation})?> bands;

  /// The z-score at each point.
  final List<double?> zScores;

  /// The bottom of the spread's axis.
  final double spreadMin;

  /// The top of it.
  final double spreadMax;

  /// How far the z-score axis reaches either side of zero.
  final double zLimit;

  /// Whether nothing was laid out.
  bool get isEmpty => count == 0;

  /// Where point [index] sits across the chart: the middle of its slot.
  double xOf(int index) => count <= 0
      ? spreadRect.left
      : spreadRect.left + spreadRect.width * (index + 0.5) / count;

  /// Where [value] sits up the spread panel.
  double spreadY(double value) {
    final span = spreadMax - spreadMin;
    if (span <= 0) return spreadRect.center.dy;
    return spreadRect.bottom - (value - spreadMin) / span * spreadRect.height;
  }

  /// Where [z] sits up the z-score panel.
  double zY(double z) =>
      zRect.center.dy - (z / zLimit).clamp(-1.0, 1.0) * zRect.height / 2;

  /// The point nearest [dx], or null when there is none.
  int? indexAt(double dx) {
    if (count <= 0 || spreadRect.width <= 0) return null;
    return ((dx - spreadRect.left) / spreadRect.width * count).floor().clamp(
      0,
      count - 1,
    );
  }
}

/// Lays [points] out in [bounds]: the spread with bands [bandWidth] deviations
/// either side of its rolling mean on top, and its z-score over [lookback]
/// points below, taking [zFraction] of the height.
///
/// [hedgeRatio] defaults to [pairHedgeRatio] of the points for
/// [PairSpreadMode.difference]. The z-score axis reaches at least a quarter
/// past [entry].
PairSpreadLayout layOutPairSpread(
  List<PairPoint> points,
  Rect bounds, {
  PairSpreadMode mode = PairSpreadMode.ratio,
  double? hedgeRatio,
  int lookback = 20,
  double bandWidth = 2,
  double entry = 2,
  double zFraction = 0.35,
  double gap = 6,
}) {
  if (points.isEmpty || bounds.width <= 0 || bounds.height <= 0) {
    return PairSpreadLayout.empty;
  }

  final spread = pairSpread(
    points,
    mode: mode,
    hedgeRatio: hedgeRatio ?? pairHedgeRatio(points),
  );
  final bands = rollingMeanDeviation(spread, lookback);
  final zScores = rollingZScore(spread, lookback);

  final share = zFraction.clamp(0.0, 0.8);
  final room = math.max(0.0, bounds.height - math.max(0.0, gap));
  final lower = room * share;
  final spreadRect = Rect.fromLTWH(
    bounds.left,
    bounds.top,
    bounds.width,
    room - lower,
  );
  final zRect = Rect.fromLTWH(
    bounds.left,
    bounds.bottom - lower,
    bounds.width,
    lower,
  );

  var low = double.infinity;
  var high = double.negativeInfinity;
  void take(double v) {
    if (!v.isFinite) return;
    low = math.min(low, v);
    high = math.max(high, v);
  }

  for (var i = 0; i < spread.length; i++) {
    take(spread[i]);
    final band = bands[i];
    if (band != null) {
      take(band.mean + bandWidth * band.deviation);
      take(band.mean - bandWidth * band.deviation);
    }
  }
  if (!low.isFinite || !high.isFinite) {
    low = 0;
    high = 1;
  } else if (high <= low) {
    final pad = low.abs() * 0.01 + 1e-6;
    low -= pad;
    high += pad;
  } else {
    final pad = (high - low) * 0.05;
    low -= pad;
    high += pad;
  }

  var zLimit = entry.abs() * 1.25;
  for (final z in zScores) {
    if (z != null && z.isFinite) zLimit = math.max(zLimit, z.abs());
  }
  if (!(zLimit > 0)) zLimit = 1;

  return PairSpreadLayout(
    spreadRect: spreadRect,
    zRect: zRect,
    count: points.length,
    spread: spread,
    bands: bands,
    zScores: zScores,
    spreadMin: low,
    spreadMax: high,
    zLimit: zLimit,
  );
}

/// What a touch on a [PairSpreadChart] landed on.
@immutable
class PairSpreadTouchDetails {
  /// Creates the details of a touch on the point at [index].
  const PairSpreadTouchDetails({
    required this.index,
    required this.point,
    required this.spread,
    required this.mean,
    required this.zScore,
    required this.at,
  });

  /// Which point it is.
  final int index;

  /// The point itself.
  final PairPoint point;

  /// The spread there.
  final double spread;

  /// The rolling mean there; null before the window fills.
  final double? mean;

  /// The z-score there; null before the window fills.
  final double? zScore;

  /// Where the spread sits, in the chart's local pixels.
  final Offset at;
}

/// Two instruments read as one: their ratio or spread with bands round its
/// rolling mean, and the z-score that pair traders enter and exit on.
///
/// ```dart
/// PairSpreadChart(
///   points: alignPairSeries(btcCloses, ethCloses),
///   mode: PairSpreadMode.logRatio,
///   lookback: 30,
/// );
/// ```
///
/// The chart fills the box it is given, and is [defaultHeight] high in a box
/// with no height of its own.
class PairSpreadChart extends StatefulWidget {
  /// Creates a spread chart of [points], in time order.
  const PairSpreadChart({
    super.key,
    required this.points,
    this.mode = PairSpreadMode.ratio,
    this.hedgeRatio,
    this.lookback = 20,
    this.bandWidth = 2,
    this.entry = 2,
    this.exit = 0,
    this.showSignals = true,
    this.zFraction = 0.35,
    this.panelGap = 6,
    this.spreadColor = const Color(0xFF4C86CD),
    this.lineWidth = 1.5,
    this.meanColor = const Color(0x99FFFFFF),
    this.bandColor = const Color(0x224C86CD),
    this.zColor = const Color(0xFFF59F00),
    this.entryColor = const Color(0x88E03131),
    this.longColor = const Color(0xFF2F9E44),
    this.shortColor = const Color(0xFFE03131),
    this.exitColor = const Color(0xFFADB5BD),
    this.showValueAxis = true,
    this.axisWidth = 56,
    this.showTimeAxis = true,
    this.timeAxisHeight = 16,
    this.tickCount = 4,
    this.valueFormatter,
    this.timeFormatter,
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

  /// Both prices at each time, in time order.
  final List<PairPoint> points;

  /// How the two prices are made into one series.
  final PairSpreadMode mode;

  /// How much of `b` offsets one of `a` in [PairSpreadMode.difference]; null
  /// fits it to the points.
  final double? hedgeRatio;

  /// How many points the rolling mean, bands and z-score look back over.
  final int lookback;

  /// How many deviations the bands sit from the mean.
  final double bandWidth;

  /// The z-score a trade is entered at, either way.
  final double entry;

  /// The z-score it is closed at.
  final double exit;

  /// Whether entries and exits are marked on the z-score.
  final bool showSignals;

  /// How much of the height the z-score panel takes.
  final double zFraction;

  /// The gap between the panels.
  final double panelGap;

  /// The colour of the spread.
  final Color spreadColor;

  /// How thick the spread and z-score lines are.
  final double lineWidth;

  /// The colour of the rolling mean.
  final Color meanColor;

  /// The colour between the bands.
  final Color bandColor;

  /// The colour of the z-score.
  final Color zColor;

  /// The colour of the lines at plus and minus [entry].
  final Color entryColor;

  /// The colour of a long entry.
  final Color longColor;

  /// The colour of a short entry.
  final Color shortColor;

  /// The colour of an exit.
  final Color exitColor;

  /// Whether values are written down the left.
  final bool showValueAxis;

  /// How much room they take.
  final double axisWidth;

  /// Whether times are written along the bottom.
  final bool showTimeAxis;

  /// How much room they take.
  final double timeAxisHeight;

  /// About how many ticks to write on the spread's axis.
  final int tickCount;

  /// Writes a spread value; null picks the decimals to suit the range.
  final String Function(double value)? valueFormatter;

  /// Writes a time; null writes the day and month.
  final String Function(DateTime time)? timeFormatter;

  /// Style of an axis label.
  final TextStyle? axisLabelStyle;

  /// Colour of the grid; null rules none.
  final Color? gridColor;

  /// Colour of the line through the touched point; null draws none.
  final Color? crosshairColor;

  /// Called as a touch moves along the chart, and with null when it leaves.
  final ValueChanged<PairSpreadTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched point; null shows none.
  final Widget? Function(BuildContext context, PairSpreadTouchDetails details)?
  tooltipBuilder;

  /// How far the card sits from the point.
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

  @override
  State<PairSpreadChart> createState() => _PairSpreadChartState();
}

class _PairSpreadChartState extends State<PairSpreadChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 64);
  PairSpreadLayout _layout = PairSpreadLayout.empty;
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
  void didUpdateWidget(PairSpreadChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!identical(oldWidget.points, widget.points)) {
      _touched = null;
      if (widget.animationDuration > Duration.zero) {
        _animation.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _animation.dispose();
    super.dispose();
  }

  void _handle(Offset local) {
    final index = _layout.indexAt(local.dx);
    if (index == _touched) return;
    setState(() => _touched = index);
    widget.onTouch?.call(index == null ? null : _detailsAt(index));
  }

  void _leave() {
    if (_touched == null) return;
    setState(() => _touched = null);
    widget.onTouch?.call(null);
  }

  PairSpreadTouchDetails? _detailsAt(int index) {
    final layout = _layout;
    if (index >= widget.points.length || index >= layout.count) return null;
    final spread = layout.spread[index];
    return PairSpreadTouchDetails(
      index: index,
      point: widget.points[index],
      spread: spread,
      mean: layout.bands[index]?.mean,
      zScore: layout.zScores[index],
      at: Offset(
        layout.xOf(index),
        spread.isFinite ? layout.spreadY(spread) : layout.spreadRect.center.dy,
      ),
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
        final box = widget.padding.deflateRect(
          Offset.zero & Size(width, height),
        );
        final plot = Rect.fromLTRB(
          box.left + (widget.showValueAxis ? widget.axisWidth : 0),
          box.top,
          math.max(box.left, box.right),
          math.max(
            box.top,
            box.bottom - (widget.showTimeAxis ? widget.timeAxisHeight : 0),
          ),
        );
        final layout = _layout = layOutPairSpread(
          widget.points,
          plot,
          mode: widget.mode,
          hedgeRatio: widget.hedgeRatio,
          lookback: widget.lookback,
          bandWidth: widget.bandWidth,
          entry: widget.entry,
          zFraction: widget.zFraction,
          gap: widget.panelGap,
        );
        final signals = widget.showSignals
            ? pairSignals(
                layout.zScores,
                entry: widget.entry,
                exit: widget.exit,
              )
            : const <PairSignal>[];

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
                      painter: PairSpreadChartPainter(
                        chart: widget,
                        layout: layout,
                        signals: signals,
                        touched: details?.index,
                        animation: t,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (tooltip != null && details != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomSingleChildLayout(
                          delegate: _PairTooltipLayout(
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

/// Puts the tooltip beside the touched point, kept inside the chart.
class _PairTooltipLayout extends SingleChildLayoutDelegate {
  _PairTooltipLayout({required this.anchor, required this.margin});

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
  bool shouldRelayout(_PairTooltipLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.margin != margin;
}

/// Paints a [PairSpreadChart]: the spread and its bands, the z-score and the
/// signals.
class PairSpreadChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [layout].
  PairSpreadChartPainter({
    required this.chart,
    required this.layout,
    required this.signals,
    required this.touched,
    required this.animation,
    required this.textCache,
  });

  final PairSpreadChart chart;
  final PairSpreadLayout layout;
  final List<PairSignal> signals;
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

    final style = seriesAxisLabelStyle.merge(chart.axisLabelStyle);
    _paintSpreadAxis(canvas, style);
    _paintZAxis(canvas, style);
    _paintTimeAxis(canvas, style);

    final t = animation.clamp(0.0, 1.0);
    final shown = math.max(1, (layout.count * t).ceil());

    _paintBands(canvas, shown);
    _paintLine(
      canvas,
      [for (var i = 0; i < shown; i++) layout.spread[i]],
      layout.spreadY,
      chart.spreadColor,
      chart.lineWidth,
    );
    _paintLine(
      canvas,
      [for (var i = 0; i < shown; i++) layout.zScores[i] ?? double.nan],
      layout.zY,
      chart.zColor,
      chart.lineWidth,
    );
    if (t >= 1) {
      _paintSignals(canvas);
      _paintCrosshair(canvas);
    }
  }

  void _paintBands(Canvas canvas, int shown) {
    final upper = <Offset>[];
    final lower = <Offset>[];
    final mean = <double>[];
    void flush() {
      if (upper.length >= 2) {
        final path = Path()..moveTo(upper.first.dx, upper.first.dy);
        for (final p in upper.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        for (final p in lower.reversed) {
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path..close(), Paint()..color = chart.bandColor);
      }
      upper.clear();
      lower.clear();
    }

    for (var i = 0; i < shown; i++) {
      final band = layout.bands[i];
      mean.add(band?.mean ?? double.nan);
      if (band == null) {
        flush();
        continue;
      }
      final x = layout.xOf(i);
      final reach = chart.bandWidth * band.deviation;
      upper.add(Offset(x, layout.spreadY(band.mean + reach)));
      lower.add(Offset(x, layout.spreadY(band.mean - reach)));
    }
    flush();

    _paintLine(canvas, mean, layout.spreadY, chart.meanColor, 1);
  }

  void _paintLine(
    Canvas canvas,
    List<double> values,
    double Function(double) y,
    Color color,
    double width,
  ) {
    final path = Path();
    var drawing = false;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (!v.isFinite) {
        drawing = false;
        continue;
      }
      final point = Offset(layout.xOf(i), y(v));
      if (drawing) {
        path.lineTo(point.dx, point.dy);
      } else {
        path.moveTo(point.dx, point.dy);
        drawing = true;
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round
        ..color = color
        ..isAntiAlias = true,
    );
  }

  void _paintSignals(Canvas canvas) {
    for (final signal in signals) {
      final z = layout.zScores[signal.index];
      if (z == null) continue;
      final at = Offset(layout.xOf(signal.index), layout.zY(z));
      final fill = Paint()..isAntiAlias = true;
      switch (signal.kind) {
        case PairSignalKind.exit:
          canvas.drawCircle(at, 3.5, fill..color = chart.exitColor);
        case PairSignalKind.enterLong:
        case PairSignalKind.enterShort:
          final long = signal.kind == PairSignalKind.enterLong;
          fill.color = long ? chart.longColor : chart.shortColor;
          // A triangle pointing the way the spread is traded.
          final tip = at + Offset(0, long ? -6 : 6);
          final base = at + Offset(0, long ? 3 : -3);
          canvas.drawPath(
            Path()
              ..moveTo(tip.dx, tip.dy)
              ..lineTo(base.dx - 4.5, base.dy)
              ..lineTo(base.dx + 4.5, base.dy)
              ..close(),
            fill,
          );
      }
    }
  }

  void _paintCrosshair(Canvas canvas) {
    final at = touched;
    final color = chart.crosshairColor;
    if (at == null || color == null || at >= layout.count) return;
    final x = layout.xOf(at);
    canvas.drawLine(
      Offset(x, layout.spreadRect.top),
      Offset(x, layout.zRect.bottom),
      Paint()
        ..color = color
        ..strokeWidth = 1,
    );
    final spread = layout.spread[at];
    if (spread.isFinite) {
      canvas.drawCircle(
        Offset(x, layout.spreadY(spread)),
        3,
        Paint()
          ..color = chart.spreadColor
          ..isAntiAlias = true,
      );
    }
    final z = layout.zScores[at];
    if (z != null) {
      canvas.drawCircle(
        Offset(x, layout.zY(z)),
        3,
        Paint()
          ..color = chart.zColor
          ..isAntiAlias = true,
      );
    }
  }

  void _paintSpreadAxis(Canvas canvas, TextStyle style) {
    final grid = chart.gridColor;
    final ticks = niceTicks(
      layout.spreadMin,
      layout.spreadMax,
      target: chart.tickCount,
    );
    for (final tick in ticks) {
      final y = layout.spreadY(tick);
      if (grid != null) {
        canvas.drawLine(
          Offset(layout.spreadRect.left, y),
          Offset(layout.spreadRect.right, y),
          Paint()
            ..color = grid
            ..strokeWidth = 1,
        );
      }
      if (!chart.showValueAxis) continue;
      final tp = textCache.get(_formatValue(tick), style);
      final left = layout.spreadRect.left - 6 - tp.width;
      if (left >= 0) tp.paint(canvas, Offset(left, y - tp.height / 2));
    }
  }

  void _paintZAxis(Canvas canvas, TextStyle style) {
    if (layout.zRect.height <= 0) return;
    void rule(double z, Color? color) {
      if (color == null || z.abs() > layout.zLimit) return;
      final y = layout.zY(z);
      canvas.drawLine(
        Offset(layout.zRect.left, y),
        Offset(layout.zRect.right, y),
        Paint()
          ..color = color
          ..strokeWidth = 1,
      );
      if (!chart.showValueAxis) return;
      final text = z == 0
          ? 'z 0'
          : '${z > 0 ? '+' : ''}${z.toStringAsFixed(z == z.roundToDouble() ? 0 : 1)}';
      final tp = textCache.get(text, style);
      final left = layout.zRect.left - 6 - tp.width;
      if (left >= 0) tp.paint(canvas, Offset(left, y - tp.height / 2));
    }

    rule(0, chart.gridColor);
    rule(chart.entry.abs(), chart.entryColor);
    rule(-chart.entry.abs(), chart.entryColor);
  }

  void _paintTimeAxis(Canvas canvas, TextStyle style) {
    if (!chart.showTimeAxis || layout.count == 0) return;
    final count = math.min(5, layout.count);
    var written = -double.infinity;
    for (var i = 0; i < count; i++) {
      final index = count == 1
          ? 0
          : ((layout.count - 1) * (i / (count - 1))).round();
      if (index >= chart.points.length) continue;
      final tp = textCache.get(_formatTime(chart.points[index].time), style);
      final left = (layout.xOf(index) - tp.width / 2).clamp(
        layout.spreadRect.left,
        math.max(layout.spreadRect.left, layout.spreadRect.right - tp.width),
      );
      if (left < written) continue;
      tp.paint(canvas, Offset(left.toDouble(), layout.zRect.bottom + 3));
      written = left + tp.width + 6;
    }
  }

  String _formatValue(double value) {
    final format = chart.valueFormatter;
    if (format != null) return format(value);
    final span = (layout.spreadMax - layout.spreadMin).abs();
    final decimals = span <= 0
        ? 2
        : (2 - (math.log(span) / math.ln10).floor()).clamp(0, 6);
    return value.toStringAsFixed(decimals);
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatTime(DateTime time) {
    final format = chart.timeFormatter;
    if (format != null) return format(time);
    return '${time.day} ${_months[time.month - 1]}';
  }

  @override
  bool shouldRepaint(PairSpreadChartPainter oldDelegate) =>
      !identical(oldDelegate.chart, chart) ||
      !identical(oldDelegate.layout, layout) ||
      oldDelegate.touched != touched ||
      oldDelegate.animation != animation;
}
