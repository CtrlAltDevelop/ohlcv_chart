import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';
import '../series/series_axis.dart';
import '../treemap/treemap_data.dart' show treemapPalette;
import '../utils/axis_ticks.dart';

/// One implied volatility reading: a strike (or a maturity) and its vol.
@immutable
class VolatilityPoint {
  /// Creates a reading of [volatility] at [x].
  const VolatilityPoint({required this.x, required this.volatility, this.data});

  /// The strike, moneyness or maturity this reading belongs to.
  final double x;

  /// The implied volatility, as a fraction: 0.32 is 32%.
  final double volatility;

  /// Anything the app wants back when this reading is touched.
  final Object? data;
}

/// One curve of a [VolatilityCurveChart] — an expiry's smile, or one term
/// structure.
@immutable
class VolatilitySlice {
  /// Creates a curve through [points].
  const VolatilitySlice({
    required this.points,
    this.label,
    this.color,
    this.dashed = false,
    this.data,
  });

  /// The readings; they are sorted by [VolatilityPoint.x] when laid out.
  final List<VolatilityPoint> points;

  /// What the curve is called, written in the legend.
  final String? label;

  /// A colour of this curve's own.
  final Color? color;

  /// Whether the curve is drawn dashed — a forward or model curve, say.
  final bool dashed;

  /// Anything the app wants back when this curve is touched.
  final Object? data;
}

/// Where one [VolatilitySlice] was laid out.
@immutable
class VolatilityCurve {
  /// Creates the curve of [slice].
  const VolatilityCurve({
    required this.slice,
    required this.index,
    required this.points,
    required this.readings,
  });

  /// The curve this draws.
  final VolatilitySlice slice;

  /// Its position among the curves.
  final int index;

  /// Where each reading sits, sorted along the bottom axis.
  final List<Offset> points;

  /// The readings themselves, in the same order.
  final List<VolatilityPoint> readings;

  /// The reading nearest [dx], or null when the curve has none.
  int? nearest(double dx) {
    if (points.isEmpty) return null;
    var best = 0;
    var distance = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final d = (points[i].dx - dx).abs();
      if (d >= distance) continue;
      distance = d;
      best = i;
    }
    return best;
  }
}

/// The curves placed inside a box.
@immutable
class VolatilityLayout {
  /// Creates a layout of [curves].
  const VolatilityLayout({
    required this.plot,
    required this.curves,
    required this.minX,
    required this.maxX,
    required this.minVol,
    required this.maxVol,
  });

  /// Nothing laid out.
  static const VolatilityLayout empty = VolatilityLayout(
    plot: Rect.zero,
    curves: [],
    minX: 0,
    maxX: 1,
    minVol: 0,
    maxVol: 1,
  );

  /// The box the curves are drawn in.
  final Rect plot;

  /// The curves, in the order they were given.
  final List<VolatilityCurve> curves;

  /// The left of the bottom axis.
  final double minX;

  /// The right of it.
  final double maxX;

  /// The bottom of the volatility axis.
  final double minVol;

  /// The top of it.
  final double maxVol;

  /// Whether nothing was laid out.
  bool get isEmpty => curves.isEmpty;

  /// Where [x] sits across the plot.
  double xOf(double x) => maxX == minX
      ? plot.center.dx
      : plot.left + (x - minX) / (maxX - minX) * plot.width;

  /// Where [volatility] sits up the plot.
  double yOf(double volatility) => maxVol == minVol
      ? plot.center.dy
      : plot.bottom - (volatility - minVol) / (maxVol - minVol) * plot.height;
}

/// The ranges [slices] need, with a little room above and below.
({double minX, double maxX, double minVol, double maxVol}) volatilityRange(
  List<VolatilitySlice> slices,
) {
  var minX = double.infinity;
  var maxX = double.negativeInfinity;
  var minVol = double.infinity;
  var maxVol = double.negativeInfinity;
  for (final slice in slices) {
    for (final point in slice.points) {
      if (!point.x.isFinite || !point.volatility.isFinite) continue;
      minX = math.min(minX, point.x);
      maxX = math.max(maxX, point.x);
      minVol = math.min(minVol, point.volatility);
      maxVol = math.max(maxVol, point.volatility);
    }
  }
  if (!minX.isFinite || !minVol.isFinite) {
    return (minX: 0, maxX: 1, minVol: 0, maxVol: 1);
  }
  if (minX == maxX) {
    minX -= 1;
    maxX += 1;
  }
  if (minVol == maxVol) {
    minVol = math.max(0, minVol - 0.01);
    maxVol += 0.01;
  } else {
    final room = (maxVol - minVol) * 0.12;
    minVol = math.max(0, minVol - room);
    maxVol += room;
  }
  return (minX: minX, maxX: maxX, minVol: minVol, maxVol: maxVol);
}

/// Places [slices] inside [bounds] against the ranges given.
///
/// Each curve's readings are sorted along the bottom axis first, so a smile
/// given out of order still draws as one line.
VolatilityLayout layOutVolatility(
  List<VolatilitySlice> slices,
  Rect bounds, {
  required double minX,
  required double maxX,
  required double minVol,
  required double maxVol,
}) {
  if (slices.isEmpty || bounds.width <= 0 || bounds.height <= 0) {
    return VolatilityLayout.empty;
  }

  final frame = VolatilityLayout(
    plot: bounds,
    curves: const [],
    minX: minX,
    maxX: maxX,
    minVol: minVol,
    maxVol: maxVol,
  );

  final curves = <VolatilityCurve>[];
  for (var i = 0; i < slices.length; i++) {
    final readings = [
      for (final point in slices[i].points)
        if (point.x.isFinite && point.volatility.isFinite) point,
    ]..sort((a, b) => a.x.compareTo(b.x));
    curves.add(
      VolatilityCurve(
        slice: slices[i],
        index: i,
        readings: readings,
        points: [
          for (final point in readings)
            Offset(frame.xOf(point.x), frame.yOf(point.volatility)),
        ],
      ),
    );
  }

  return VolatilityLayout(
    plot: bounds,
    curves: curves,
    minX: minX,
    maxX: maxX,
    minVol: minVol,
    maxVol: maxVol,
  );
}

/// One curve's reading under the pointer.
@immutable
class VolatilityReadout {
  /// Creates a readout of [point] on [curve].
  const VolatilityReadout({
    required this.curve,
    required this.point,
    required this.at,
  });

  /// The curve it belongs to.
  final VolatilityCurve curve;

  /// The reading itself.
  final VolatilityPoint point;

  /// Where it sits, in the chart's local pixels.
  final Offset at;
}

/// What a touch on a [VolatilityCurveChart] landed on: one reading per curve.
@immutable
class VolatilityTouchDetails {
  /// Creates the details of a touch at [x].
  const VolatilityTouchDetails({required this.x, required this.readouts});

  /// The strike or maturity under the pointer.
  final double x;

  /// The nearest reading on each curve, in the order the curves were given.
  final List<VolatilityReadout> readouts;
}

/// Implied volatility against strike or maturity — a smile, a skew, a term
/// structure.
///
/// ```dart
/// VolatilityCurveChart(
///   slices: const [
///     VolatilitySlice(
///       label: '7d',
///       points: [
///         VolatilityPoint(x: 90, volatility: 0.42),
///         VolatilityPoint(x: 100, volatility: 0.31),
///         VolatilityPoint(x: 110, volatility: 0.36),
///       ],
///     ),
///   ],
///   atTheMoney: 100,
/// );
/// ```
///
/// The chart fills the box it is given, and is [defaultHeight] high in a box
/// with no height of its own.
class VolatilityCurveChart extends StatefulWidget {
  /// Creates a chart of [slices].
  const VolatilityCurveChart({
    super.key,
    required this.slices,
    this.minX,
    this.maxX,
    this.minVolatility,
    this.maxVolatility,
    this.atTheMoney,
    this.palette = treemapPalette,
    this.lineWidth = 1.8,
    this.showPoints = true,
    this.pointRadius = 2.5,
    this.curved = true,
    this.showLegend = true,
    this.legendStyle,
    this.showAxes = true,
    this.axisWidth = 44,
    this.axisHeight = 18,
    this.tickCount = 5,
    this.xFormatter,
    this.volatilityFormatter,
    this.axisLabelStyle,
    this.xAxisTitle,
    this.axisTitleStyle,
    this.gridColor = const Color(0x22FFFFFF),
    this.atTheMoneyColor = const Color(0x88F59F00),
    this.crosshairColor = const Color(0x66FFFFFF),
    this.onTouch,
    this.tooltipBuilder,
    this.tooltipMargin = 10,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.defaultHeight = 240,
    this.semanticLabel,
  });

  /// The curves, one per expiry or one per term structure.
  final List<VolatilitySlice> slices;

  /// The left of the bottom axis; null reads it off the readings.
  final double? minX;

  /// The right of it; null reads it off the readings.
  final double? maxX;

  /// The bottom of the volatility axis; null reads it off the readings.
  final double? minVolatility;

  /// The top of it; null reads it off the readings.
  final double? maxVolatility;

  /// The strike the underlying is at now, marked with a line; null marks none.
  final double? atTheMoney;

  /// Colours taken in turn by curves that name none.
  final List<Color> palette;

  /// How thick a curve is.
  final double lineWidth;

  /// Whether each reading is marked with a dot.
  final bool showPoints;

  /// How large those dots are.
  final double pointRadius;

  /// Whether the curves are smoothed; false joins the readings with straight
  /// lines.
  final bool curved;

  /// Whether the curves' names are listed in the corner.
  final bool showLegend;

  /// Style of a legend entry.
  final TextStyle? legendStyle;

  /// Whether the two axes are drawn.
  final bool showAxes;

  /// How much room the volatility axis takes.
  final double axisWidth;

  /// How much room the bottom axis takes.
  final double axisHeight;

  /// About how many ticks to write on each axis.
  final int tickCount;

  /// Writes a strike or maturity; null writes at most two decimals.
  final String Function(double x)? xFormatter;

  /// Writes a volatility; null writes it as a percentage.
  final String Function(double volatility)? volatilityFormatter;

  /// Style of an axis label.
  final TextStyle? axisLabelStyle;

  /// Written under the bottom axis — 'Strike', 'Days to expiry'.
  final String? xAxisTitle;

  /// Style of that title.
  final TextStyle? axisTitleStyle;

  /// Colour of the grid ruled at each tick; null rules none.
  final Color? gridColor;

  /// The colour of the line marking [atTheMoney].
  final Color atTheMoneyColor;

  /// Colour of the line drawn at the touched strike; null draws none.
  final Color? crosshairColor;

  /// Called as a touch moves across the chart, and with null when it leaves.
  final ValueChanged<VolatilityTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched strike; null shows none.
  final Widget? Function(BuildContext context, VolatilityTouchDetails details)?
  tooltipBuilder;

  /// How far the card sits from the crosshair.
  final double tooltipMargin;

  /// How long the curves take to draw themselves in; zero draws them at once.
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
  State<VolatilityCurveChart> createState() => _VolatilityCurveChartState();
}

class _VolatilityCurveChartState extends State<VolatilityCurveChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 64);
  VolatilityLayout _layout = VolatilityLayout.empty;
  double? _touchedX;

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
  void didUpdateWidget(VolatilityCurveChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!identical(oldWidget.slices, widget.slices)) {
      _touchedX = null;
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
    if (_layout.isEmpty) return;
    final dx = local.dx.clamp(_layout.plot.left, _layout.plot.right);
    if (dx == _touchedX) return;
    setState(() => _touchedX = dx);
    widget.onTouch?.call(_detailsAt(dx));
  }

  VolatilityTouchDetails? _detailsAt(double dx) {
    final readouts = <VolatilityReadout>[];
    for (final curve in _layout.curves) {
      final at = curve.nearest(dx);
      if (at == null) continue;
      readouts.add(
        VolatilityReadout(
          curve: curve,
          point: curve.readings[at],
          at: curve.points[at],
        ),
      );
    }
    if (readouts.isEmpty) return null;
    return VolatilityTouchDetails(
      x: readouts.first.point.x,
      readouts: readouts,
    );
  }

  void _leave() {
    if (_touchedX == null) return;
    setState(() => _touchedX = null);
    widget.onTouch?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.animationCurve.transform(_animation.value);
    final range = volatilityRange(widget.slices);

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
        final titleRoom = widget.xAxisTitle == null ? 0.0 : 14.0;
        final plot = Rect.fromLTRB(
          box.left + (widget.showAxes ? widget.axisWidth : 0),
          box.top,
          box.right,
          math.max(
            box.top,
            box.bottom - (widget.showAxes ? widget.axisHeight : 0) - titleRoom,
          ),
        );
        _layout = layOutVolatility(
          widget.slices,
          plot,
          minX: widget.minX ?? range.minX,
          maxX: widget.maxX ?? range.maxX,
          minVol: widget.minVolatility ?? range.minVol,
          maxVol: widget.maxVolatility ?? range.maxVol,
        );

        final dx = _touchedX;
        final details = dx == null ? null : _detailsAt(dx);
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
                      painter: VolatilityCurveChartPainter(
                        chart: widget,
                        layout: _layout,
                        touchedX: dx,
                        readouts: details?.readouts ?? const [],
                        animation: t,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (tooltip != null && details != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomSingleChildLayout(
                          delegate: _VolatilityTooltipLayout(
                            anchor: details.readouts.first.at,
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
class _VolatilityTooltipLayout extends SingleChildLayoutDelegate {
  _VolatilityTooltipLayout({required this.anchor, required this.margin});

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
  bool shouldRelayout(_VolatilityTooltipLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.margin != margin;
}

/// Paints a [VolatilityCurveChart]: the axes, the curves and the legend.
class VolatilityCurveChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [layout].
  VolatilityCurveChartPainter({
    required this.chart,
    required this.layout,
    required this.touchedX,
    required this.readouts,
    required this.animation,
    required this.textCache,
  });

  final VolatilityCurveChart chart;
  final VolatilityLayout layout;
  final double? touchedX;
  final List<VolatilityReadout> readouts;
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
    _paintAtTheMoney(canvas);

    final t = animation.clamp(0.0, 1.0);
    for (final curve in layout.curves) {
      _paintCurve(canvas, curve, t);
    }
    if (t < 1) return;

    _paintCrosshair(canvas);
    if (chart.showLegend) _paintLegend(canvas);
  }

  void _paintCurve(Canvas canvas, VolatilityCurve curve, double t) {
    final points = curve.points;
    if (points.isEmpty) return;
    final shown = math.max(1, (points.length * t).ceil());
    final color = _colorOf(curve);
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = chart.lineWidth
      ..strokeJoin = StrokeJoin.round
      ..color = color
      ..isAntiAlias = true;

    if (shown > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < shown; i++) {
        if (!chart.curved) {
          path.lineTo(points[i].dx, points[i].dy);
          continue;
        }
        // A smooth curve through the readings: a control point half way
        // between each pair, which cannot overshoot into silly volatilities.
        final previous = points[i - 1];
        final current = points[i];
        final midX = (previous.dx + current.dx) / 2;
        path.cubicTo(
          midX,
          previous.dy,
          midX,
          current.dy,
          current.dx,
          current.dy,
        );
      }
      if (curve.slice.dashed) {
        _drawDashed(canvas, path, pen);
      } else {
        canvas.drawPath(path, pen);
      }
    }

    if (!chart.showPoints) return;
    final dot = Paint()
      ..color = color
      ..isAntiAlias = true;
    for (var i = 0; i < shown; i++) {
      canvas.drawCircle(points[i], chart.pointRadius, dot);
    }
  }

  void _drawDashed(Canvas canvas, Path path, Paint pen) {
    for (final metric in path.computeMetrics()) {
      var at = 0.0;
      while (at < metric.length) {
        final to = math.min(at + 6, metric.length);
        canvas.drawPath(metric.extractPath(at, to), pen);
        at = to + 4;
      }
    }
  }

  void _paintAtTheMoney(Canvas canvas) {
    final atm = chart.atTheMoney;
    if (atm == null || atm < layout.minX || atm > layout.maxX) return;
    final x = layout.xOf(atm);
    canvas.drawLine(
      Offset(x, layout.plot.top),
      Offset(x, layout.plot.bottom),
      Paint()
        ..color = chart.atTheMoneyColor
        ..strokeWidth = 1.5,
    );
  }

  void _paintCrosshair(Canvas canvas) {
    final dx = touchedX;
    final color = chart.crosshairColor;
    if (dx == null || color == null || readouts.isEmpty) return;
    canvas.drawLine(
      Offset(dx, layout.plot.top),
      Offset(dx, layout.plot.bottom),
      Paint()
        ..color = color
        ..strokeWidth = 1,
    );
    for (final readout in readouts) {
      canvas.drawCircle(
        readout.at,
        chart.pointRadius + 1.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _colorOf(readout.curve)
          ..isAntiAlias = true,
      );
    }
  }

  void _paintLegend(Canvas canvas) {
    final style = seriesAxisLabelStyle.merge(chart.legendStyle);
    var y = layout.plot.top + 4;
    for (final curve in layout.curves) {
      final name = curve.slice.label;
      if (name == null || name.isEmpty) continue;
      final tp = textCache.get(name, style);
      final left = layout.plot.right - tp.width;
      if (left < layout.plot.left || y + tp.height > layout.plot.bottom) break;
      canvas.drawCircle(
        Offset(left - 8, y + tp.height / 2),
        3,
        Paint()
          ..color = _colorOf(curve)
          ..isAntiAlias = true,
      );
      tp.paint(canvas, Offset(left, y));
      y += tp.height + 2;
    }
  }

  void _paintAxes(Canvas canvas) {
    final grid = chart.gridColor;
    if (!chart.showAxes && grid == null) return;
    final style = seriesAxisLabelStyle.merge(chart.axisLabelStyle);
    final line = grid == null
        ? null
        : (Paint()
            ..color = grid
            ..strokeWidth = 1);

    for (final tick in niceTicks(
      layout.minVol,
      layout.maxVol,
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
      if (!chart.showAxes) continue;
      final tp = textCache.get(_formatVolatility(tick), style);
      final left = layout.plot.left - 6 - tp.width;
      if (left >= 0) tp.paint(canvas, Offset(left, y - tp.height / 2));
    }

    var written = -double.infinity;
    for (final tick in niceTicks(
      layout.minX,
      layout.maxX,
      target: chart.tickCount,
    )) {
      final x = layout.xOf(tick);
      if (line != null) {
        canvas.drawLine(
          Offset(x, layout.plot.top),
          Offset(x, layout.plot.bottom),
          line,
        );
      }
      if (!chart.showAxes) continue;
      final tp = textCache.get(_formatX(tick), style);
      final left = x - tp.width / 2;
      if (left < written || left + tp.width > layout.plot.right) continue;
      tp.paint(canvas, Offset(left, layout.plot.bottom + 3));
      written = left + tp.width + 4;
    }

    final title = chart.xAxisTitle;
    if (title != null && title.isNotEmpty) {
      final tp = textCache.get(
        title,
        seriesAxisTitleStyle.merge(chart.axisTitleStyle),
      );
      tp.paint(
        canvas,
        Offset(
          layout.plot.center.dx - tp.width / 2,
          layout.plot.bottom + chart.axisHeight + 2,
        ),
      );
    }
  }

  Color _colorOf(VolatilityCurve curve) {
    final own = curve.slice.color;
    if (own != null) return own;
    final palette = chart.palette;
    if (palette.isEmpty) return const Color(0xFF4C86CD);
    return palette[curve.index % palette.length];
  }

  String _formatX(double x) {
    final format = chart.xFormatter;
    if (format != null) return format(x);
    final rounded = double.parse(x.toStringAsFixed(2));
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toString();
  }

  String _formatVolatility(double volatility) {
    final format = chart.volatilityFormatter;
    if (format != null) return format(volatility);
    final percent = volatility * 100;
    return percent == percent.roundToDouble()
        ? '${percent.toStringAsFixed(0)}%'
        : '${percent.toStringAsFixed(1)}%';
  }

  @override
  bool shouldRepaint(VolatilityCurveChartPainter oldDelegate) =>
      !identical(oldDelegate.chart, chart) ||
      !identical(oldDelegate.layout, layout) ||
      oldDelegate.touchedX != touchedX ||
      oldDelegate.animation != animation;
}
