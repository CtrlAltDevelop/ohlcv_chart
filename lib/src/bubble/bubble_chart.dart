import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';
import '../series/series_axis.dart';
import '../treemap/treemap_data.dart' show treemapPalette;
import '../utils/axis_ticks.dart';

/// One bubble — a strategy at its risk, its return and its size.
@immutable
class BubblePoint {
  /// Creates a bubble at ([x], [y]) worth [size].
  const BubblePoint({
    required this.x,
    required this.y,
    this.size = 1,
    this.label,
    this.color,
    this.data,
  });

  /// Where it sits along the bottom axis.
  final double x;

  /// Where it sits up the side axis.
  final double y;

  /// What sets its area; never its radius, so a bubble worth twice as much
  /// covers twice the area.
  final double size;

  /// What the bubble is called.
  final String? label;

  /// A colour of this bubble's own.
  final Color? color;

  /// Anything the app wants back when this bubble is touched.
  final Object? data;
}

/// Where one [BubblePoint] was laid out.
@immutable
class BubbleCircle {
  /// Creates the circle of [point].
  const BubbleCircle({
    required this.point,
    required this.index,
    required this.center,
    required this.radius,
  });

  /// The bubble this circle draws.
  final BubblePoint point;

  /// Its position in the list it was given in.
  final int index;

  /// Where it sits, in the chart's local pixels.
  final Offset center;

  /// How large it is.
  final double radius;

  /// Whether [local] is inside the circle.
  bool contains(Offset local) => (local - center).distance <= radius;
}

/// The ranges [points] need on both axes, widened to leave room for the
/// bubbles at the edges.
({double minX, double maxX, double minY, double maxY}) bubbleRange(
  List<BubblePoint> points,
) {
  var minX = double.infinity;
  var maxX = double.negativeInfinity;
  var minY = double.infinity;
  var maxY = double.negativeInfinity;
  for (final point in points) {
    if (!point.x.isFinite || !point.y.isFinite) continue;
    minX = math.min(minX, point.x);
    maxX = math.max(maxX, point.x);
    minY = math.min(minY, point.y);
    maxY = math.max(maxY, point.y);
  }
  if (!minX.isFinite || !minY.isFinite) {
    return (minX: 0, maxX: 1, minY: 0, maxY: 1);
  }
  ({double min, double max}) pad(double min, double max) {
    if (min == max) return (min: min - 1, max: max + 1);
    final room = (max - min) * 0.1;
    return (min: min - room, max: max + room);
  }

  final x = pad(minX, maxX);
  final y = pad(minY, maxY);
  return (minX: x.min, maxX: x.max, minY: y.min, maxY: y.max);
}

/// Places [points] inside [bounds] against the ranges given.
///
/// A bubble's radius runs from [minRadius] to [maxRadius] with its area in
/// proportion to its size, so the eye reads the areas rather than the widths.
/// Every bubble of the same size gets [minRadius] when nothing separates them.
List<BubbleCircle> layOutBubbles(
  List<BubblePoint> points,
  Rect bounds, {
  required double minX,
  required double maxX,
  required double minY,
  required double maxY,
  double minRadius = 4,
  double maxRadius = 28,
  double? maxSize,
}) {
  if (points.isEmpty || bounds.width <= 0 || bounds.height <= 0) {
    return const [];
  }

  final spanX = maxX - minX;
  final spanY = maxY - minY;

  var largest = maxSize ?? 0;
  if (maxSize == null) {
    for (final point in points) {
      if (point.size.isFinite && point.size > 0) {
        largest = math.max(largest, point.size);
      }
    }
  }

  final low = math.max(0.0, math.min(minRadius, maxRadius));
  final high = math.max(low, maxRadius);

  return [
    for (var i = 0; i < points.length; i++)
      () {
        final point = points[i];
        final x = spanX == 0
            ? bounds.center.dx
            : bounds.left + (point.x - minX) / spanX * bounds.width;
        final y = spanY == 0
            ? bounds.center.dy
            : bounds.bottom - (point.y - minY) / spanY * bounds.height;
        final size = point.size.isFinite && point.size > 0 ? point.size : 0.0;
        // Area, not radius, carries the value: r = sqrt(share) between the
        // two radii.
        final share = largest <= 0 ? 0.0 : (size / largest).clamp(0.0, 1.0);
        return BubbleCircle(
          point: point,
          index: i,
          center: Offset(x, y),
          radius: low + (high - low) * math.sqrt(share),
        );
      }(),
  ];
}

/// The bubble under [local], the smallest one winning so a bubble sitting
/// inside a larger one can still be picked; null when there is none.
BubbleCircle? bubbleAt(List<BubbleCircle> circles, Offset local) {
  BubbleCircle? found;
  for (final circle in circles) {
    if (!circle.contains(local)) continue;
    if (found == null || circle.radius < found.radius) found = circle;
  }
  return found;
}

/// What a touch on a [BubbleChart] landed on.
@immutable
class BubbleTouchDetails {
  /// Creates the details of a touch on [circle].
  const BubbleTouchDetails({required this.circle});

  /// The circle touched.
  final BubbleCircle circle;

  /// The bubble it draws.
  BubblePoint get point => circle.point;
}

/// Points on two axes, each as large as a third number — a bubble chart.
///
/// It compares three numbers at once: risk against return with position size,
/// spread against volume with trade count.
///
/// ```dart
/// BubbleChart(
///   points: const [
///     BubblePoint(x: 8.2, y: 14.5, size: 120000, label: 'Trend'),
///     BubblePoint(x: 15.1, y: 21.0, size: 40000, label: 'Breakout'),
///   ],
///   xAxisTitle: 'Volatility %',
///   yAxisTitle: 'Return %',
/// );
/// ```
///
/// The chart fills the box it is given, and is [defaultHeight] high in a box
/// with no height of its own.
class BubbleChart extends StatefulWidget {
  /// Creates a bubble chart of [points].
  const BubbleChart({
    super.key,
    required this.points,
    this.minX,
    this.maxX,
    this.minY,
    this.maxY,
    this.minRadius = 4,
    this.maxRadius = 28,
    this.maxSize,
    this.palette = treemapPalette,
    this.fillOpacity = 0.5,
    this.strokeWidth = 1.5,
    this.showLabels = true,
    this.labelStyle,
    this.showAxes = true,
    this.axisWidth = 44,
    this.axisHeight = 18,
    this.tickCount = 5,
    this.xFormatter,
    this.yFormatter,
    this.axisLabelStyle,
    this.xAxisTitle,
    this.yAxisTitle,
    this.axisTitleStyle,
    this.gridColor = const Color(0x22FFFFFF),
    this.xReferenceLines = const [],
    this.yReferenceLines = const [],
    this.referenceColor = const Color(0x66FFFFFF),
    this.hoverBorder = const BorderSide(color: Color(0xCCFFFFFF), width: 1.5),
    this.onTouch,
    this.tooltipBuilder,
    this.tooltipMargin = 10,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.defaultHeight = 260,
    this.semanticLabel,
  });

  /// The bubbles, drawn largest first so a small one is never hidden.
  final List<BubblePoint> points;

  /// The left of the bottom axis; null reads it off the points.
  final double? minX;

  /// The right of the bottom axis; null reads it off the points.
  final double? maxX;

  /// The bottom of the side axis; null reads it off the points.
  final double? minY;

  /// The top of the side axis; null reads it off the points.
  final double? maxY;

  /// The radius of the smallest bubble.
  final double minRadius;

  /// The radius of the largest.
  final double maxRadius;

  /// What [maxRadius] is worth; null takes the largest point.
  final double? maxSize;

  /// Colours taken in turn by bubbles that name none.
  final List<Color> palette;

  /// How opaque a bubble's fill is; its outline is drawn solid.
  final double fillOpacity;

  /// How thick the outline is.
  final double strokeWidth;

  /// Whether a bubble's name is written inside it when it fits.
  final bool showLabels;

  /// Style of a bubble's name.
  final TextStyle? labelStyle;

  /// Whether the two axes are drawn.
  final bool showAxes;

  /// How much room the side axis takes.
  final double axisWidth;

  /// How much room the bottom axis takes.
  final double axisHeight;

  /// About how many ticks to write on each axis.
  final int tickCount;

  /// Writes a value on the bottom axis; null writes at most two decimals.
  final String Function(double value)? xFormatter;

  /// Writes a value on the side axis; null writes at most two decimals.
  final String Function(double value)? yFormatter;

  /// Style of an axis label.
  final TextStyle? axisLabelStyle;

  /// Written under the bottom axis; null writes nothing.
  final String? xAxisTitle;

  /// Written up the side axis; null writes nothing.
  final String? yAxisTitle;

  /// Style of an axis title.
  final TextStyle? axisTitleStyle;

  /// Colour of the grid ruled at each tick; null rules none.
  final Color? gridColor;

  /// Values marked with a vertical line — a benchmark's volatility, say.
  final List<double> xReferenceLines;

  /// Values marked with a horizontal line — zero return, a target.
  final List<double> yReferenceLines;

  /// The colour of those lines.
  final Color referenceColor;

  /// Drawn round the bubble under the pointer; null marks none.
  final BorderSide? hoverBorder;

  /// Called as a touch moves over the bubbles, and with null when it leaves.
  final ValueChanged<BubbleTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched bubble; null shows none.
  final Widget? Function(BuildContext context, BubbleTouchDetails details)?
      tooltipBuilder;

  /// How far the card sits from the bubble.
  final double tooltipMargin;

  /// How long the bubbles take to grow in; zero draws them at once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build grows in.
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
  State<BubbleChart> createState() => _BubbleChartState();
}

class _BubbleChartState extends State<BubbleChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 64);
  List<BubbleCircle> _circles = const [];
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
  void didUpdateWidget(BubbleChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!identical(oldWidget.points, widget.points)) {
      if (_touched != null && _touched! >= widget.points.length) {
        _touched = null;
      }
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
    final index = bubbleAt(_circles, local)?.index;
    if (index == _touched) return;
    setState(() => _touched = index);
    widget.onTouch?.call(
      index == null
          ? null
          : BubbleTouchDetails(
              circle: _circles.firstWhere((c) => c.index == index),
            ),
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
    final range = bubbleRange(widget.points);
    final minX = widget.minX ?? range.minX;
    final maxX = widget.maxX ?? range.maxX;
    final minY = widget.minY ?? range.minY;
    final maxY = widget.maxY ?? range.maxY;

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
        _circles = layOutBubbles(
          widget.points,
          plot,
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          minRadius: widget.minRadius,
          maxRadius: widget.maxRadius,
          maxSize: widget.maxSize,
        );

        final touched = _touched;
        final circle = touched == null
            ? null
            : _circles.where((c) => c.index == touched).firstOrNull;
        final details =
            circle == null ? null : BubbleTouchDetails(circle: circle);
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
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _handle(d.localPosition),
              onTapUp: (_) => _leave(),
              onTapCancel: _leave,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: BubbleChartPainter(
                        chart: widget,
                        circles: _circles,
                        plot: plot,
                        minX: minX,
                        maxX: maxX,
                        minY: minY,
                        maxY: maxY,
                        touched: touched,
                        animation: t,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (tooltip != null && details != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomSingleChildLayout(
                          delegate: _BubbleTooltipLayout(
                            anchor: Rect.fromCircle(
                              center: circle!.center,
                              radius: circle.radius,
                            ),
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

/// Puts the tooltip to the right of the touched bubble, or to its left when
/// there is no room, kept inside the chart.
class _BubbleTooltipLayout extends SingleChildLayoutDelegate {
  _BubbleTooltipLayout({required this.anchor, required this.margin});

  final Rect anchor;
  final double margin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var left = anchor.right + margin;
    if (left + childSize.width > size.width) {
      left = anchor.left - margin - childSize.width;
    }
    return Offset(
      left.clamp(0.0, math.max(0.0, size.width - childSize.width)),
      (anchor.center.dy - childSize.height / 2).clamp(
        0.0,
        math.max(0.0, size.height - childSize.height),
      ),
    );
  }

  @override
  bool shouldRelayout(_BubbleTooltipLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.margin != margin;
}

/// Paints a [BubbleChart]: the grid, the axes and the bubbles.
class BubbleChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [circles] inside [plot].
  BubbleChartPainter({
    required this.chart,
    required this.circles,
    required this.plot,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.touched,
    required this.animation,
    required this.textCache,
  });

  final BubbleChart chart;
  final List<BubbleCircle> circles;
  final Rect plot;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final int? touched;
  final double animation;
  final TextPainterCache textCache;

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (circles.isEmpty) return;

    _paintGridAndAxes(canvas);
    _paintReferenceLines(canvas);

    final t = animation.clamp(0.0, 1.0);
    // Largest first, so a small bubble is never buried.
    final order = [...circles]..sort((a, b) => b.radius.compareTo(a.radius));
    for (final circle in order) {
      final color = _colorOf(circle);
      final radius = circle.radius * t;
      canvas
        ..drawCircle(
          circle.center,
          radius,
          Paint()
            ..color = color.withValues(alpha: chart.fillOpacity.clamp(0.0, 1.0))
            ..isAntiAlias = true,
        )
        ..drawCircle(
          circle.center,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = chart.strokeWidth
            ..color = color
            ..isAntiAlias = true,
        );
      if (t >= 1 && chart.showLabels) _paintLabel(canvas, circle, color);
    }

    final hover = chart.hoverBorder;
    final at = touched;
    if (at != null &&
        hover != null &&
        hover.style != BorderStyle.none &&
        hover.width > 0) {
      for (final circle in circles) {
        if (circle.index != at) continue;
        canvas.drawCircle(
          circle.center,
          circle.radius * t + hover.width,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = hover.width
            ..color = hover.color
            ..isAntiAlias = true,
        );
      }
    }
  }

  void _paintGridAndAxes(Canvas canvas) {
    final grid = chart.gridColor;
    if (!chart.showAxes && grid == null) return;
    final style = seriesAxisLabelStyle.merge(chart.axisLabelStyle);
    final line = grid == null
        ? null
        : (Paint()
          ..color = grid
          ..strokeWidth = 1);

    final spanY = maxY - minY;
    for (final tick in niceTicks(minY, maxY, target: chart.tickCount)) {
      final y = spanY == 0
          ? plot.center.dy
          : plot.bottom - (tick - minY) / spanY * plot.height;
      if (line != null) {
        canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), line);
      }
      if (!chart.showAxes) continue;
      final tp = textCache.get(_format(tick, chart.yFormatter), style);
      final left = plot.left - 6 - tp.width;
      if (left >= 0) tp.paint(canvas, Offset(left, y - tp.height / 2));
    }

    final spanX = maxX - minX;
    var written = -double.infinity;
    for (final tick in niceTicks(minX, maxX, target: chart.tickCount)) {
      final x = spanX == 0
          ? plot.center.dx
          : plot.left + (tick - minX) / spanX * plot.width;
      if (line != null) {
        canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), line);
      }
      if (!chart.showAxes) continue;
      final tp = textCache.get(_format(tick, chart.xFormatter), style);
      final left = x - tp.width / 2;
      if (left < written || left + tp.width > plot.right) continue;
      tp.paint(canvas, Offset(left, plot.bottom + 3));
      written = left + tp.width + 4;
    }

    _paintTitles(canvas);
  }

  void _paintTitles(Canvas canvas) {
    final style = seriesAxisTitleStyle.merge(chart.axisTitleStyle);
    final x = chart.xAxisTitle;
    if (x != null && x.isNotEmpty) {
      final tp = textCache.get(x, style);
      tp.paint(
        canvas,
        Offset(
          plot.center.dx - tp.width / 2,
          plot.bottom + chart.axisHeight + 2,
        ),
      );
    }
    final y = chart.yAxisTitle;
    if (y != null && y.isNotEmpty) {
      final tp = textCache.get(y, style);
      canvas
        ..save()
        ..translate(plot.left - chart.axisWidth + tp.height, plot.center.dy)
        ..rotate(-math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height));
      canvas.restore();
    }
  }

  void _paintReferenceLines(Canvas canvas) {
    if (chart.xReferenceLines.isEmpty && chart.yReferenceLines.isEmpty) return;
    final pen = Paint()
      ..color = chart.referenceColor
      ..strokeWidth = 1;
    final spanX = maxX - minX;
    for (final value in chart.xReferenceLines) {
      if (!value.isFinite || spanX <= 0) continue;
      final x = plot.left + (value - minX) / spanX * plot.width;
      if (x < plot.left || x > plot.right) continue;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), pen);
    }
    final spanY = maxY - minY;
    for (final value in chart.yReferenceLines) {
      if (!value.isFinite || spanY <= 0) continue;
      final y = plot.bottom - (value - minY) / spanY * plot.height;
      if (y < plot.top || y > plot.bottom) continue;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), pen);
    }
  }

  void _paintLabel(Canvas canvas, BubbleCircle circle, Color color) {
    final name = circle.point.label;
    if (name == null || name.isEmpty) return;
    final style = chart.labelStyle ??
        TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color.computeLuminance() > 0.5
              ? const Color(0xDD000000)
              : const Color(0xFFFFFFFF),
        );
    final tp = textCache.get(name, style);
    if (tp.width > circle.radius * 1.8) return;
    tp.paint(
      canvas,
      circle.center - Offset(tp.width / 2, tp.height / 2),
    );
  }

  Color _colorOf(BubbleCircle circle) {
    final own = circle.point.color;
    if (own != null) return own;
    final palette = chart.palette;
    if (palette.isEmpty) return const Color(0xFF4C86CD);
    return palette[circle.index % palette.length];
  }

  String _format(double value, String Function(double)? formatter) {
    if (formatter != null) return formatter(value);
    final rounded = double.parse(value.toStringAsFixed(2));
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toString();
  }

  @override
  bool shouldRepaint(BubbleChartPainter oldDelegate) =>
      !identical(oldDelegate.chart, chart) ||
      !identical(oldDelegate.circles, circles) ||
      oldDelegate.plot != plot ||
      oldDelegate.minX != minX ||
      oldDelegate.maxX != maxX ||
      oldDelegate.minY != minY ||
      oldDelegate.maxY != maxY ||
      oldDelegate.touched != touched ||
      oldDelegate.animation != animation;
}
