import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';
import '../series/series_axis.dart';
import '../utils/axis_ticks.dart';

/// One reading of an account's value.
@immutable
class EquityPoint {
  /// Creates a reading of [equity] at [time].
  const EquityPoint({required this.time, required this.equity, this.data});

  /// When the reading was taken.
  final DateTime time;

  /// What the account was worth.
  final double equity;

  /// Anything the app wants back when this point is touched.
  final Object? data;
}

/// What an equity curve is worth and how far it fell.
@immutable
class EquityStats {
  /// Creates a summary.
  const EquityStats({
    required this.start,
    required this.end,
    required this.peak,
    required this.trough,
    required this.maxDrawdown,
    required this.maxDrawdownStart,
    required this.maxDrawdownEnd,
  });

  /// Nothing measured.
  static const EquityStats empty = EquityStats(
    start: 0,
    end: 0,
    peak: 0,
    trough: 0,
    maxDrawdown: 0,
    maxDrawdownStart: null,
    maxDrawdownEnd: null,
  );

  /// The first reading.
  final double start;

  /// The last reading.
  final double end;

  /// The highest reading.
  final double peak;

  /// The lowest reading after the peak that made the deepest drawdown.
  final double trough;

  /// The deepest fall from a high, as a fraction: -0.24 is 24% down.
  final double maxDrawdown;

  /// When the deepest drawdown began — the high it fell from.
  final DateTime? maxDrawdownStart;

  /// When it reached its lowest point.
  final DateTime? maxDrawdownEnd;

  /// The whole run's return, as a fraction.
  double get totalReturn => start == 0 ? 0 : end / start - 1;
}

/// How far below its own high the curve was at each point, as a fraction.
///
/// The first point is always 0, and every value is zero or less.
List<double> equityDrawdowns(List<EquityPoint> points) {
  final out = <double>[];
  var peak = double.negativeInfinity;
  for (final point in points) {
    final value = point.equity;
    if (!value.isFinite) {
      out.add(out.isEmpty ? 0 : out.last);
      continue;
    }
    if (value > peak) peak = value;
    out.add(peak <= 0 ? 0 : value / peak - 1);
  }
  return out;
}

/// Measures [points]: its ends, its high, and its deepest fall.
EquityStats equityStats(List<EquityPoint> points) {
  if (points.isEmpty) return EquityStats.empty;

  var peak = double.negativeInfinity;
  var peakAt = points.first.time;
  var worst = 0.0;
  var trough = points.first.equity;
  DateTime? worstFrom;
  DateTime? worstTo;
  var high = double.negativeInfinity;

  for (final point in points) {
    final value = point.equity;
    if (!value.isFinite) continue;
    if (value > peak) {
      peak = value;
      peakAt = point.time;
    }
    high = math.max(high, value);
    final fall = peak <= 0 ? 0.0 : value / peak - 1;
    if (fall < worst) {
      worst = fall;
      trough = value;
      worstFrom = peakAt;
      worstTo = point.time;
    }
  }

  return EquityStats(
    start: points.first.equity,
    end: points.last.equity,
    peak: high.isFinite ? high : 0,
    trough: trough,
    maxDrawdown: worst,
    maxDrawdownStart: worstFrom,
    maxDrawdownEnd: worstTo,
  );
}

/// Where an equity curve and its drawdown panel were laid out.
@immutable
class EquityCurveLayout {
  /// Creates a layout.
  const EquityCurveLayout({
    required this.equityRect,
    required this.drawdownRect,
    required this.equity,
    required this.drawdown,
    required this.drawdowns,
    required this.minEquity,
    required this.maxEquity,
    required this.deepestDrawdown,
  });

  /// Nothing laid out.
  static const EquityCurveLayout empty = EquityCurveLayout(
    equityRect: Rect.zero,
    drawdownRect: Rect.zero,
    equity: [],
    drawdown: [],
    drawdowns: [],
    minEquity: 0,
    maxEquity: 1,
    deepestDrawdown: 0,
  );

  /// The panel the curve is drawn in.
  final Rect equityRect;

  /// The panel below it, where the curve's fall from its high is shaded.
  final Rect drawdownRect;

  /// The curve, one point per reading.
  final List<Offset> equity;

  /// The same readings in the drawdown panel.
  final List<Offset> drawdown;

  /// The fall from the high at each reading, as a fraction.
  final List<double> drawdowns;

  /// The bottom of the curve's value axis.
  final double minEquity;

  /// The top of it.
  final double maxEquity;

  /// The deepest fall drawn, as a fraction; zero or less.
  final double deepestDrawdown;

  /// Whether nothing was laid out.
  bool get isEmpty => equity.isEmpty;

  /// The reading nearest [dx], or null when there is none.
  int? indexAt(double dx) {
    if (equity.isEmpty) return null;
    var best = 0;
    var distance = double.infinity;
    for (var i = 0; i < equity.length; i++) {
      final d = (equity[i].dx - dx).abs();
      if (d >= distance) continue;
      distance = d;
      best = i;
    }
    return best;
  }
}

/// Places [points] in [bounds]: the curve on top, its drawdown below.
///
/// The drawdown panel takes [drawdownFraction] of the height, with [gap]
/// pixels between the two. Readings are spread evenly along the width, in the
/// order given, so a curve with gaps in time draws without them.
EquityCurveLayout layOutEquityCurve(
  List<EquityPoint> points,
  Rect bounds, {
  double drawdownFraction = 0.3,
  double gap = 8,
  double? min,
  double? max,
  List<double>? drawdowns,
}) {
  if (points.isEmpty || bounds.width <= 0 || bounds.height <= 0) {
    return EquityCurveLayout.empty;
  }

  final falls = drawdowns ?? equityDrawdowns(points);
  final share = drawdownFraction.clamp(0.0, 0.8);
  final room = math.max(0.0, bounds.height - math.max(0.0, gap));
  final lower = room * share;
  final upper = room - lower;
  final equityRect =
      Rect.fromLTWH(bounds.left, bounds.top, bounds.width, upper);
  final drawdownRect = Rect.fromLTWH(
    bounds.left,
    bounds.bottom - lower,
    bounds.width,
    lower,
  );

  var low = min ?? double.infinity;
  var high = max ?? double.negativeInfinity;
  if (min == null || max == null) {
    for (final point in points) {
      if (!point.equity.isFinite) continue;
      if (min == null) low = math.min(low, point.equity);
      if (max == null) high = math.max(high, point.equity);
    }
  }
  if (!low.isFinite || !high.isFinite) {
    low = 0;
    high = 1;
  }
  if (high <= low) {
    low -= 1;
    high += 1;
  }

  var deepest = 0.0;
  for (final fall in falls) {
    if (fall.isFinite) deepest = math.min(deepest, fall);
  }

  final step = points.length == 1 ? 0.0 : bounds.width / (points.length - 1);
  double x(int i) =>
      points.length == 1 ? bounds.center.dx : bounds.left + i * step;

  return EquityCurveLayout(
    equityRect: equityRect,
    drawdownRect: drawdownRect,
    drawdowns: falls,
    minEquity: low,
    maxEquity: high,
    deepestDrawdown: deepest,
    equity: [
      for (var i = 0; i < points.length; i++)
        Offset(
          x(i),
          equityRect.bottom -
              ((points[i].equity - low) / (high - low)).clamp(0.0, 1.0) *
                  equityRect.height,
        ),
    ],
    drawdown: [
      for (var i = 0; i < points.length; i++)
        Offset(
          x(i),
          drawdownRect.top +
              (deepest >= 0
                  ? 0.0
                  : (falls[i] / deepest).clamp(0.0, 1.0) * drawdownRect.height),
        ),
    ],
  );
}

/// What a touch on an [EquityCurveChart] landed on.
@immutable
class EquityTouchDetails {
  /// Creates the details of a touch on the reading at [index].
  const EquityTouchDetails({
    required this.index,
    required this.point,
    required this.drawdown,
    required this.at,
  });

  /// Which reading it is.
  final int index;

  /// The reading itself.
  final EquityPoint point;

  /// How far below its high the curve was there, as a fraction.
  final double drawdown;

  /// Where the reading sits on the curve, in the chart's local pixels.
  final Offset at;
}

/// An account's value over time, with how far it fell below its own high
/// shaded underneath — the equity curve every backtest ends with.
///
/// ```dart
/// EquityCurveChart(
///   points: [
///     for (final row in backtest) EquityPoint(time: row.time, equity: row.equity),
///   ],
/// );
/// ```
///
/// The chart fills the box it is given, and is [defaultHeight] high in a box
/// with no height of its own.
class EquityCurveChart extends StatefulWidget {
  /// Creates an equity curve of [points], in time order.
  const EquityCurveChart({
    super.key,
    required this.points,
    this.min,
    this.max,
    this.drawdownFraction = 0.3,
    this.panelGap = 8,
    this.lineColor = const Color(0xFF12B886),
    this.lineWidth = 1.5,
    this.fillOpacity = 0.14,
    this.drawdownColor = const Color(0xFFFA5252),
    this.drawdownOpacity = 0.35,
    this.markMaxDrawdown = true,
    this.showValueAxis = true,
    this.showDrawdownAxis = true,
    this.axisWidth = 52,
    this.timeAxisHeight = 16,
    this.showTimeAxis = true,
    this.tickCount = 4,
    this.valueFormatter,
    this.percentFormatter,
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

  /// The readings, in time order.
  final List<EquityPoint> points;

  /// The bottom of the curve's axis; null reads it off the points.
  final double? min;

  /// The top of it; null reads it off the points.
  final double? max;

  /// How much of the height the drawdown panel takes.
  final double drawdownFraction;

  /// The gap left between the two panels.
  final double panelGap;

  /// The colour of the curve.
  final Color lineColor;

  /// How thick the curve is.
  final double lineWidth;

  /// How opaque the shading under the curve is; zero draws none.
  final double fillOpacity;

  /// The colour of the drawdown panel.
  final Color drawdownColor;

  /// How opaque its shading is.
  final double drawdownOpacity;

  /// Whether the deepest drawdown is marked on both panels.
  final bool markMaxDrawdown;

  /// Whether the curve's value axis is written down the left.
  final bool showValueAxis;

  /// Whether the drawdown panel's percentage axis is written down the left.
  final bool showDrawdownAxis;

  /// How much room the axes take.
  final double axisWidth;

  /// How much room the time axis takes.
  final double timeAxisHeight;

  /// Whether the time axis is written along the bottom.
  final bool showTimeAxis;

  /// About how many ticks to write on the value axis.
  final int tickCount;

  /// Writes a value on the curve's axis; null writes at most two decimals.
  final String Function(double value)? valueFormatter;

  /// Writes a fraction on the drawdown axis; null writes whole percents.
  final String Function(double fraction)? percentFormatter;

  /// Writes a time on the bottom axis; null writes the date.
  final String Function(DateTime time)? timeFormatter;

  /// Style of an axis label.
  final TextStyle? axisLabelStyle;

  /// Colour of the grid ruled at each tick; null rules none.
  final Color? gridColor;

  /// Colour of the line drawn through the touched reading; null draws none.
  final Color? crosshairColor;

  /// Called as a touch moves along the curve, and with null when it leaves.
  final ValueChanged<EquityTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched reading; null shows none.
  final Widget? Function(BuildContext context, EquityTouchDetails details)?
      tooltipBuilder;

  /// How far the card sits from the reading.
  final double tooltipMargin;

  /// How long the curve takes to draw itself in; zero draws it at once.
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
  State<EquityCurveChart> createState() => _EquityCurveChartState();
}

class _EquityCurveChartState extends State<EquityCurveChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 64);
  EquityCurveLayout _layout = EquityCurveLayout.empty;
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
  void didUpdateWidget(EquityCurveChart oldWidget) {
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
    _animation.dispose();
    super.dispose();
  }

  void _handle(Offset local) {
    final index = _layout.indexAt(local.dx);
    if (index == _touched) return;
    setState(() => _touched = index);
    widget.onTouch?.call(index == null ? null : _detailsAt(index));
  }

  EquityTouchDetails? _detailsAt(int index) {
    if (index >= widget.points.length || index >= _layout.equity.length) {
      return null;
    }
    return EquityTouchDetails(
      index: index,
      point: widget.points[index],
      drawdown: _layout.drawdowns[index],
      at: _layout.equity[index],
    );
  }

  void _leave() {
    if (_touched == null) return;
    setState(() => _touched = null);
    widget.onTouch?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.animationCurve.transform(_animation.value);
    final stats = equityStats(widget.points);

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
        final axis = widget.showValueAxis || widget.showDrawdownAxis
            ? widget.axisWidth
            : 0.0;
        final plot = Rect.fromLTRB(
          box.left + axis,
          box.top,
          box.right,
          math.max(
            box.top,
            box.bottom - (widget.showTimeAxis ? widget.timeAxisHeight : 0),
          ),
        );
        _layout = layOutEquityCurve(
          widget.points,
          plot,
          drawdownFraction: widget.drawdownFraction,
          gap: widget.panelGap,
          min: widget.min,
          max: widget.max,
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
            // Raw pointer events rather than a GestureDetector: the crosshair
            // follows a finger dragged along the curve, with no gesture arena
            // to wait on first.
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
                      painter: EquityCurveChartPainter(
                        chart: widget,
                        layout: _layout,
                        stats: stats,
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
                          delegate: _EquityTooltipLayout(
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

/// Puts the tooltip beside the touched reading, kept inside the chart.
class _EquityTooltipLayout extends SingleChildLayoutDelegate {
  _EquityTooltipLayout({required this.anchor, required this.margin});

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
  bool shouldRelayout(_EquityTooltipLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.margin != margin;
}

/// Paints an [EquityCurveChart]: the curve, the drawdown panel and the axes.
class EquityCurveChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [layout].
  EquityCurveChartPainter({
    required this.chart,
    required this.layout,
    required this.stats,
    required this.touched,
    required this.animation,
    required this.textCache,
  });

  final EquityCurveChart chart;
  final EquityCurveLayout layout;
  final EquityStats stats;
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

    final t = animation.clamp(0.0, 1.0);
    final shown = math.max(1, (layout.equity.length * t).ceil());
    _paintCurve(canvas, shown);
    _paintDrawdown(canvas, shown);
    if (chart.markMaxDrawdown && t >= 1) _paintMaxDrawdown(canvas);
    if (t >= 1) _paintCrosshair(canvas);
  }

  void _paintCurve(Canvas canvas, int shown) {
    final line = Path()..moveTo(layout.equity.first.dx, layout.equity.first.dy);
    for (var i = 1; i < shown; i++) {
      line.lineTo(layout.equity[i].dx, layout.equity[i].dy);
    }

    if (chart.fillOpacity > 0) {
      final fill = Path.from(line)
        ..lineTo(layout.equity[shown - 1].dx, layout.equityRect.bottom)
        ..lineTo(layout.equity.first.dx, layout.equityRect.bottom)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..color =
              chart.lineColor.withValues(alpha: chart.fillOpacity.clamp(0, 1))
          ..isAntiAlias = true,
      );
    }

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = chart.lineWidth
        ..strokeJoin = StrokeJoin.round
        ..color = chart.lineColor
        ..isAntiAlias = true,
    );
  }

  void _paintDrawdown(Canvas canvas, int shown) {
    if (layout.drawdownRect.height <= 0) return;
    final top = layout.drawdownRect.top;
    final path = Path()..moveTo(layout.drawdown.first.dx, top);
    for (var i = 0; i < shown; i++) {
      path.lineTo(layout.drawdown[i].dx, layout.drawdown[i].dy);
    }
    path
      ..lineTo(layout.drawdown[shown - 1].dx, top)
      ..close();
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = chart.drawdownColor
              .withValues(alpha: chart.drawdownOpacity.clamp(0, 1))
          ..isAntiAlias = true,
      )
      ..drawLine(
        Offset(layout.drawdownRect.left, top),
        Offset(layout.drawdownRect.right, top),
        Paint()
          ..color = chart.drawdownColor.withValues(alpha: 0.6)
          ..strokeWidth = 1,
      );
  }

  void _paintMaxDrawdown(Canvas canvas) {
    if (layout.deepestDrawdown >= 0) return;
    var at = 0;
    for (var i = 1; i < layout.drawdowns.length; i++) {
      if (layout.drawdowns[i] < layout.drawdowns[at]) at = i;
    }
    final pen = Paint()
      ..color = chart.drawdownColor.withValues(alpha: 0.8)
      ..strokeWidth = 1;
    canvas
      ..drawLine(
        Offset(layout.equity[at].dx, layout.equityRect.top),
        Offset(layout.equity[at].dx, layout.equityRect.bottom),
        pen,
      )
      ..drawCircle(
        layout.drawdown[at],
        3,
        Paint()
          ..color = chart.drawdownColor
          ..isAntiAlias = true,
      );

    final style = seriesAxisLabelStyle.merge(chart.axisLabelStyle);
    final tp = textCache.get(
      _formatPercent(layout.deepestDrawdown),
      style.copyWith(color: chart.drawdownColor),
    );
    final left = math.min(
      layout.drawdown[at].dx + 4,
      layout.drawdownRect.right - tp.width,
    );
    tp.paint(
        canvas,
        Offset(math.max(layout.drawdownRect.left, left),
            layout.drawdown[at].dy - tp.height - 2));
  }

  void _paintCrosshair(Canvas canvas) {
    final at = touched;
    final color = chart.crosshairColor;
    if (at == null || color == null || at >= layout.equity.length) return;
    final x = layout.equity[at].dx;
    final pen = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas
      ..drawLine(
        Offset(x, layout.equityRect.top),
        Offset(x, layout.drawdownRect.bottom),
        pen,
      )
      ..drawCircle(
        layout.equity[at],
        3,
        Paint()
          ..color = chart.lineColor
          ..isAntiAlias = true,
      );
  }

  void _paintAxes(Canvas canvas) {
    final grid = chart.gridColor;
    final style = seriesAxisLabelStyle.merge(chart.axisLabelStyle);
    final line = grid == null
        ? null
        : (Paint()
          ..color = grid
          ..strokeWidth = 1);

    final span = layout.maxEquity - layout.minEquity;
    for (final tick in niceTicks(
      layout.minEquity,
      layout.maxEquity,
      target: chart.tickCount,
    )) {
      final y = layout.equityRect.bottom -
          (tick - layout.minEquity) / span * layout.equityRect.height;
      if (line != null) {
        canvas.drawLine(
          Offset(layout.equityRect.left, y),
          Offset(layout.equityRect.right, y),
          line,
        );
      }
      if (!chart.showValueAxis) continue;
      final tp = textCache.get(_formatValue(tick), style);
      final left = layout.equityRect.left - 6 - tp.width;
      if (left >= 0) tp.paint(canvas, Offset(left, y - tp.height / 2));
    }

    if (chart.showDrawdownAxis && layout.deepestDrawdown < 0) {
      for (final fraction in [0.0, layout.deepestDrawdown]) {
        final y = layout.drawdownRect.top +
            (fraction / layout.deepestDrawdown) * layout.drawdownRect.height;
        final tp = textCache.get(_formatPercent(fraction), style);
        final left = layout.drawdownRect.left - 6 - tp.width;
        if (left >= 0) {
          tp.paint(
            canvas,
            Offset(
              left,
              (y - tp.height / 2).clamp(
                layout.drawdownRect.top,
                math.max(layout.drawdownRect.top,
                    layout.drawdownRect.bottom - tp.height),
              ),
            ),
          );
        }
      }
    }

    _paintTimeAxis(canvas, style);
  }

  void _paintTimeAxis(Canvas canvas, TextStyle style) {
    if (!chart.showTimeAxis || layout.equity.isEmpty) return;
    final points = layout.equity;
    final count = math.min(4, points.length);
    var written = -double.infinity;
    for (var i = 0; i < count; i++) {
      final index =
          count == 1 ? 0 : ((points.length - 1) * (i / (count - 1))).round();
      final time = _timeAt(index);
      if (time == null) continue;
      final tp = textCache.get(_formatTime(time), style);
      final left = (points[index].dx - tp.width / 2)
          .clamp(layout.equityRect.left, layout.equityRect.right - tp.width);
      if (left < written) continue;
      tp.paint(canvas, Offset(left, layout.drawdownRect.bottom + 3));
      written = left + tp.width + 6;
    }
  }

  DateTime? _timeAt(int index) =>
      index < chart.points.length ? chart.points[index].time : null;

  String _formatValue(double value) {
    final format = chart.valueFormatter;
    if (format != null) return format(value);
    final rounded = double.parse(value.toStringAsFixed(2));
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toString();
  }

  String _formatPercent(double fraction) {
    final format = chart.percentFormatter;
    if (format != null) return format(fraction);
    return '${(fraction * 100).round()}%';
  }

  String _formatTime(DateTime time) {
    final format = chart.timeFormatter;
    if (format != null) return format(time);
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '${time.year}-$month-$day';
  }

  @override
  bool shouldRepaint(EquityCurveChartPainter oldDelegate) =>
      !identical(oldDelegate.chart, chart) ||
      !identical(oldDelegate.layout, layout) ||
      oldDelegate.touched != touched ||
      oldDelegate.animation != animation;
}
