import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../footprint/footprint_chart.dart';
import '../renderer/text_painter_cache.dart';
import '../series/series_axis.dart';
import '../utils/axis_ticks.dart';

/// One bar's worth of buying less selling.
@immutable
class DeltaBar {
  /// Creates the bar covering [time].
  const DeltaBar({
    required this.time,
    required this.delta,
    this.price,
    this.data,
  });

  /// When the bar began.
  final DateTime time;

  /// Buying less selling in that bar: positive when the offer was lifted.
  final double delta;

  /// What price closed at, for reading divergences; null leaves them out.
  final double? price;

  /// Anything the app wants back when this bar is touched.
  final Object? data;
}

/// Turns [bars] into delta bars, taking each bar's delta and close.
List<DeltaBar> deltaBarsFromFootprint(List<FootprintBar> bars) => [
  for (final bar in bars)
    DeltaBar(time: bar.time, delta: bar.delta, price: bar.close),
];

/// The running total of [bars]' deltas.
List<double> cumulativeDelta(List<DeltaBar> bars) {
  var running = 0.0;
  return [
    for (final bar in bars)
      () {
        if (bar.delta.isFinite) running += bar.delta;
        return running;
      }(),
  ];
}

/// Which way a divergence points.
enum DeltaDivergence {
  /// Price made a new high but the cumulative delta did not: the move up was
  /// not bought.
  bearish,

  /// Price made a new low but the cumulative delta did not: the move down was
  /// not sold.
  bullish,
}

/// A bar where price and the cumulative delta disagreed.
@immutable
class DeltaDivergenceMark {
  /// Creates a mark at [index].
  const DeltaDivergenceMark({required this.index, required this.kind});

  /// Which bar it is.
  final int index;

  /// Which way it points.
  final DeltaDivergence kind;
}

/// Finds the bars where price made an extreme that the cumulative delta did
/// not follow, looking [lookback] bars back.
///
/// A bar counts as bearish when its price is the highest of the window and its
/// cumulative delta is not, and bullish the other way round. Bars without a
/// price are skipped, as are the first [lookback] bars, which have no window
/// behind them.
List<DeltaDivergenceMark> deltaDivergences(
  List<DeltaBar> bars, {
  int lookback = 10,
}) {
  if (bars.length <= lookback || lookback < 1) return const [];
  final totals = cumulativeDelta(bars);

  final marks = <DeltaDivergenceMark>[];
  for (var i = lookback; i < bars.length; i++) {
    final price = bars[i].price;
    if (price == null || !price.isFinite) continue;

    var highestPrice = true;
    var lowestPrice = true;
    var highestDelta = true;
    var lowestDelta = true;
    for (var j = i - lookback; j < i; j++) {
      final other = bars[j].price;
      if (other != null && other.isFinite) {
        if (other >= price) highestPrice = false;
        if (other <= price) lowestPrice = false;
      }
      if (totals[j] >= totals[i]) highestDelta = false;
      if (totals[j] <= totals[i]) lowestDelta = false;
    }

    if (highestPrice && !highestDelta) {
      marks.add(DeltaDivergenceMark(index: i, kind: DeltaDivergence.bearish));
    } else if (lowestPrice && !lowestDelta) {
      marks.add(DeltaDivergenceMark(index: i, kind: DeltaDivergence.bullish));
    }
  }
  return marks;
}

/// Where a cumulative delta chart was laid out.
@immutable
class CumulativeDeltaLayout {
  /// Creates a layout.
  const CumulativeDeltaLayout({
    required this.lineRect,
    required this.barsRect,
    required this.line,
    required this.bars,
    required this.totals,
    required this.minTotal,
    required this.maxTotal,
    required this.largestDelta,
    required this.zeroY,
  });

  /// Nothing laid out.
  static const CumulativeDeltaLayout empty = CumulativeDeltaLayout(
    lineRect: Rect.zero,
    barsRect: Rect.zero,
    line: [],
    bars: [],
    totals: [],
    minTotal: 0,
    maxTotal: 1,
    largestDelta: 0,
    zeroY: 0,
  );

  /// The panel the running total is drawn in.
  final Rect lineRect;

  /// The panel below it, one column per bar's own delta.
  final Rect barsRect;

  /// The running total, one point per bar.
  final List<Offset> line;

  /// Each bar's own delta, as a column standing on or hanging from zero.
  final List<Rect> bars;

  /// The running total at each bar.
  final List<double> totals;

  /// The bottom of the running total's axis.
  final double minTotal;

  /// The top of it.
  final double maxTotal;

  /// The largest single-bar delta, either way.
  final double largestDelta;

  /// Where zero sits in the lower panel.
  final double zeroY;

  /// Whether nothing was laid out.
  bool get isEmpty => line.isEmpty;

  /// The bar nearest [dx], or null when there is none.
  int? indexAt(double dx) {
    if (line.isEmpty) return null;
    var best = 0;
    var distance = double.infinity;
    for (var i = 0; i < line.length; i++) {
      final d = (line[i].dx - dx).abs();
      if (d >= distance) continue;
      distance = d;
      best = i;
    }
    return best;
  }
}

/// Places [bars] in [bounds]: the running total on top, each bar's own delta
/// below.
CumulativeDeltaLayout layOutCumulativeDelta(
  List<DeltaBar> bars,
  Rect bounds, {
  double histogramFraction = 0.3,
  double gap = 6,
  double barSpacing = 1,
  double? min,
  double? max,
  List<double>? totals,
}) {
  if (bars.isEmpty || bounds.width <= 0 || bounds.height <= 0) {
    return CumulativeDeltaLayout.empty;
  }

  final running = totals ?? cumulativeDelta(bars);
  final share = histogramFraction.clamp(0.0, 0.8);
  final room = math.max(0.0, bounds.height - math.max(0.0, gap));
  final lower = room * share;
  final upper = room - lower;
  final lineRect = Rect.fromLTWH(bounds.left, bounds.top, bounds.width, upper);
  final barsRect = Rect.fromLTWH(
    bounds.left,
    bounds.bottom - lower,
    bounds.width,
    lower,
  );

  var low = min ?? double.infinity;
  var high = max ?? double.negativeInfinity;
  if (min == null || max == null) {
    for (final total in running) {
      if (!total.isFinite) continue;
      if (min == null) low = math.min(low, total);
      if (max == null) high = math.max(high, total);
    }
    // Zero always shows: a delta chart is read against it.
    if (min == null) low = math.min(low, 0);
    if (max == null) high = math.max(high, 0);
  }
  if (!low.isFinite || !high.isFinite || high <= low) {
    low = -1;
    high = 1;
  }

  var largest = 0.0;
  for (final bar in bars) {
    if (bar.delta.isFinite) largest = math.max(largest, bar.delta.abs());
  }

  final width = bounds.width / bars.length;
  final spacing = math.min(math.max(0.0, barSpacing), width);
  final zeroY = barsRect.center.dy;

  return CumulativeDeltaLayout(
    lineRect: lineRect,
    barsRect: barsRect,
    totals: running,
    minTotal: low,
    maxTotal: high,
    largestDelta: largest,
    zeroY: zeroY,
    line: [
      for (var i = 0; i < bars.length; i++)
        Offset(
          bounds.left + width * (i + 0.5),
          lineRect.bottom -
              ((running[i] - low) / (high - low)).clamp(0.0, 1.0) *
                  lineRect.height,
        ),
    ],
    bars: [
      for (var i = 0; i < bars.length; i++)
        () {
          final delta = bars[i].delta.isFinite ? bars[i].delta : 0.0;
          final height = largest <= 0
              ? 0.0
              : (delta.abs() / largest) * (barsRect.height / 2);
          final left = bounds.left + width * i + spacing / 2;
          return Rect.fromLTRB(
            left,
            delta >= 0 ? zeroY - height : zeroY,
            left + math.max(0.0, width - spacing),
            delta >= 0 ? zeroY : zeroY + height,
          );
        }(),
    ],
  );
}

/// What a touch on a [CumulativeDeltaChart] landed on.
@immutable
class CumulativeDeltaTouchDetails {
  /// Creates the details of a touch on the bar at [index].
  const CumulativeDeltaTouchDetails({
    required this.index,
    required this.bar,
    required this.total,
    required this.at,
  });

  /// Which bar it is.
  final int index;

  /// The bar itself.
  final DeltaBar bar;

  /// The running total there.
  final double total;

  /// Where that sits on the line, in the chart's local pixels.
  final Offset at;
}

/// Buying less selling, as a running total with each bar's own delta beneath —
/// the cumulative delta order-flow traders read against price.
///
/// ```dart
/// CumulativeDeltaChart(
///   bars: deltaBarsFromFootprint(footprintBars),
/// );
/// ```
///
/// The chart fills the box it is given, and is [defaultHeight] high in a box
/// with no height of its own.
class CumulativeDeltaChart extends StatefulWidget {
  /// Creates a cumulative delta chart of [bars], in time order.
  const CumulativeDeltaChart({
    super.key,
    required this.bars,
    this.min,
    this.max,
    this.histogramFraction = 0.3,
    this.panelGap = 6,
    this.barSpacing = 1,
    this.lineColor = const Color(0xFF4C86CD),
    this.lineWidth = 1.5,
    this.fillOpacity = 0.12,
    this.buyColor = const Color(0xFF2F9E44),
    this.sellColor = const Color(0xFFE03131),
    this.divergenceLookback = 10,
    this.showDivergences = true,
    this.bearishDivergenceColor = const Color(0xFFE03131),
    this.bullishDivergenceColor = const Color(0xFF2F9E44),
    this.showValueAxis = true,
    this.axisWidth = 52,
    this.timeAxisHeight = 16,
    this.showTimeAxis = true,
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
    this.defaultHeight = 220,
    this.semanticLabel,
  });

  /// The bars, in time order.
  final List<DeltaBar> bars;

  /// The bottom of the running total's axis; null reads it off the bars.
  final double? min;

  /// The top of it; null reads it off the bars.
  final double? max;

  /// How much of the height the per-bar panel takes.
  final double histogramFraction;

  /// The gap left between the two panels.
  final double panelGap;

  /// How many pixels are taken off each side of a delta column.
  final double barSpacing;

  /// The colour of the running total.
  final Color lineColor;

  /// How thick that line is.
  final double lineWidth;

  /// How opaque the shading under it is; zero draws none.
  final double fillOpacity;

  /// The colour of a bar that bought more than it sold.
  final Color buyColor;

  /// The colour of one that sold more.
  final Color sellColor;

  /// How many bars back a divergence is read against.
  final int divergenceLookback;

  /// Whether divergences are marked.
  final bool showDivergences;

  /// The colour of a mark where price rose and delta did not follow.
  final Color bearishDivergenceColor;

  /// The colour of one where price fell and delta did not follow.
  final Color bullishDivergenceColor;

  /// Whether the running total's axis is written down the left.
  final bool showValueAxis;

  /// How much room that axis takes.
  final double axisWidth;

  /// How much room the time axis takes.
  final double timeAxisHeight;

  /// Whether the time axis is written along the bottom.
  final bool showTimeAxis;

  /// About how many ticks to write on the value axis.
  final int tickCount;

  /// Writes a value; null writes whole numbers, thousands as `1.2k`.
  final String Function(double value)? valueFormatter;

  /// Writes a time; null writes the hour and minute.
  final String Function(DateTime time)? timeFormatter;

  /// Style of an axis label.
  final TextStyle? axisLabelStyle;

  /// Colour of the grid ruled at each tick; null rules none.
  final Color? gridColor;

  /// Colour of the line drawn through the touched bar; null draws none.
  final Color? crosshairColor;

  /// Called as a touch moves along the chart, and with null when it leaves.
  final ValueChanged<CumulativeDeltaTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched bar; null shows none.
  final Widget? Function(
    BuildContext context,
    CumulativeDeltaTouchDetails details,
  )?
  tooltipBuilder;

  /// How far the card sits from the bar.
  final double tooltipMargin;

  /// How long the line takes to draw itself in; zero draws it at once.
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
  State<CumulativeDeltaChart> createState() => _CumulativeDeltaChartState();
}

class _CumulativeDeltaChartState extends State<CumulativeDeltaChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 64);
  CumulativeDeltaLayout _layout = CumulativeDeltaLayout.empty;
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
  void didUpdateWidget(CumulativeDeltaChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!identical(oldWidget.bars, widget.bars)) {
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

  CumulativeDeltaTouchDetails? _detailsAt(int index) {
    if (index >= widget.bars.length || index >= _layout.line.length) {
      return null;
    }
    return CumulativeDeltaTouchDetails(
      index: index,
      bar: widget.bars[index],
      total: _layout.totals[index],
      at: _layout.line[index],
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
    final marks = widget.showDivergences
        ? deltaDivergences(widget.bars, lookback: widget.divergenceLookback)
        : const <DeltaDivergenceMark>[];

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
          box.right,
          math.max(
            box.top,
            box.bottom - (widget.showTimeAxis ? widget.timeAxisHeight : 0),
          ),
        );
        _layout = layOutCumulativeDelta(
          widget.bars,
          plot,
          histogramFraction: widget.histogramFraction,
          gap: widget.panelGap,
          barSpacing: widget.barSpacing,
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
                      painter: CumulativeDeltaChartPainter(
                        chart: widget,
                        layout: _layout,
                        divergences: marks,
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
                          delegate: _DeltaTooltipLayout(
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

/// Puts the tooltip beside the touched bar, kept inside the chart.
class _DeltaTooltipLayout extends SingleChildLayoutDelegate {
  _DeltaTooltipLayout({required this.anchor, required this.margin});

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
  bool shouldRelayout(_DeltaTooltipLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.margin != margin;
}

/// Paints a [CumulativeDeltaChart]: the running total, the per-bar deltas and
/// the divergences.
class CumulativeDeltaChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [layout].
  CumulativeDeltaChartPainter({
    required this.chart,
    required this.layout,
    required this.divergences,
    required this.touched,
    required this.animation,
    required this.textCache,
  });

  final CumulativeDeltaChart chart;
  final CumulativeDeltaLayout layout;
  final List<DeltaDivergenceMark> divergences;
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
    final shown = math.max(1, (layout.line.length * t).ceil());
    _paintBars(canvas, shown);
    _paintLine(canvas, shown);
    if (t >= 1) {
      _paintDivergences(canvas);
      _paintCrosshair(canvas);
    }
  }

  void _paintBars(Canvas canvas, int shown) {
    if (layout.barsRect.height <= 0) return;
    final fill = Paint()..isAntiAlias = false;
    for (var i = 0; i < shown && i < layout.bars.length; i++) {
      final rect = layout.bars[i];
      if (rect.width <= 0) continue;
      fill.color = rect.bottom <= layout.zeroY
          ? chart.buyColor
          : chart.sellColor;
      canvas.drawRect(rect, fill);
    }
    canvas.drawLine(
      Offset(layout.barsRect.left, layout.zeroY),
      Offset(layout.barsRect.right, layout.zeroY),
      Paint()
        ..color = const Color(0x44FFFFFF)
        ..strokeWidth = 1,
    );
  }

  void _paintLine(Canvas canvas, int shown) {
    final points = layout.line.take(shown).toList();
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    if (chart.fillOpacity > 0) {
      final fill = Path.from(path)
        ..lineTo(points.last.dx, layout.lineRect.bottom)
        ..lineTo(points.first.dx, layout.lineRect.bottom)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..color = chart.lineColor.withValues(
            alpha: chart.fillOpacity.clamp(0, 1),
          )
          ..isAntiAlias = true,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = chart.lineWidth
        ..strokeJoin = StrokeJoin.round
        ..color = chart.lineColor
        ..isAntiAlias = true,
    );
  }

  void _paintDivergences(Canvas canvas) {
    for (final mark in divergences) {
      if (mark.index >= layout.line.length) continue;
      final at = layout.line[mark.index];
      final bearish = mark.kind == DeltaDivergence.bearish;
      final color = bearish
          ? chart.bearishDivergenceColor
          : chart.bullishDivergenceColor;
      // A small triangle, pointing the way the divergence warns.
      final tip = bearish ? at - const Offset(0, 9) : at + const Offset(0, 9);
      final base = bearish ? at - const Offset(0, 3) : at + const Offset(0, 3);
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(base.dx - 4, base.dy)
          ..lineTo(base.dx + 4, base.dy)
          ..close(),
        Paint()
          ..color = color
          ..isAntiAlias = true,
      );
    }
  }

  void _paintCrosshair(Canvas canvas) {
    final at = touched;
    final color = chart.crosshairColor;
    if (at == null || color == null || at >= layout.line.length) return;
    final x = layout.line[at].dx;
    canvas
      ..drawLine(
        Offset(x, layout.lineRect.top),
        Offset(x, layout.barsRect.bottom),
        Paint()
          ..color = color
          ..strokeWidth = 1,
      )
      ..drawCircle(
        layout.line[at],
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

    final span = layout.maxTotal - layout.minTotal;
    for (final tick in niceTicks(
      layout.minTotal,
      layout.maxTotal,
      target: chart.tickCount,
    )) {
      final y =
          layout.lineRect.bottom -
          (tick - layout.minTotal) / span * layout.lineRect.height;
      if (line != null) {
        canvas.drawLine(
          Offset(layout.lineRect.left, y),
          Offset(layout.lineRect.right, y),
          line,
        );
      }
      if (!chart.showValueAxis) continue;
      final tp = textCache.get(_formatValue(tick), style);
      final left = layout.lineRect.left - 6 - tp.width;
      if (left >= 0) tp.paint(canvas, Offset(left, y - tp.height / 2));
    }

    _paintTimeAxis(canvas, style);
  }

  void _paintTimeAxis(Canvas canvas, TextStyle style) {
    if (!chart.showTimeAxis || layout.line.isEmpty) return;
    final count = math.min(4, layout.line.length);
    var written = -double.infinity;
    for (var i = 0; i < count; i++) {
      final index = count == 1
          ? 0
          : ((layout.line.length - 1) * (i / (count - 1))).round();
      if (index >= chart.bars.length) continue;
      final tp = textCache.get(_formatTime(chart.bars[index].time), style);
      final left = (layout.line[index].dx - tp.width / 2).clamp(
        layout.lineRect.left,
        math.max(layout.lineRect.left, layout.lineRect.right - tp.width),
      );
      if (left < written) continue;
      tp.paint(canvas, Offset(left.toDouble(), layout.barsRect.bottom + 3));
      written = left + tp.width + 6;
    }
  }

  String _formatValue(double value) {
    final format = chart.valueFormatter;
    if (format != null) return format(value);
    if (value.abs() >= 1000) {
      final thousands = value / 1000;
      return '${thousands.toStringAsFixed(thousands.abs() >= 10 ? 0 : 1)}k';
    }
    return value.round().toString();
  }

  String _formatTime(DateTime time) {
    final format = chart.timeFormatter;
    if (format != null) return format(time);
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  bool shouldRepaint(CumulativeDeltaChartPainter oldDelegate) =>
      !identical(oldDelegate.chart, chart) ||
      !identical(oldDelegate.layout, layout) ||
      oldDelegate.touched != touched ||
      oldDelegate.animation != animation;
}
