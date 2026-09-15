import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';
import '../treemap/treemap_data.dart';

/// Where one [TreemapItem] was laid out in a [SunburstChart]: a ring segment.
@immutable
class SunburstArc {
  /// Creates the arc of [item].
  const SunburstArc({
    required this.item,
    required this.depth,
    required this.index,
    required this.startAngle,
    required this.sweepAngle,
    required this.innerRadius,
    required this.outerRadius,
    required this.total,
    this.parent,
  });

  /// The item this arc draws.
  final TreemapItem item;

  /// How deeply nested it is: 0 for a top-level item, drawn in the first ring.
  final int depth;

  /// Its position among its siblings, in the order they were given.
  final int index;

  /// Where the arc begins, in radians clockwise from three o'clock.
  final double startAngle;

  /// How far it goes round, in radians.
  final double sweepAngle;

  /// The radius of its inner edge.
  final double innerRadius;

  /// The radius of its outer edge.
  final double outerRadius;

  /// The item's value, or its children's total for a group.
  final double total;

  /// The arc this one sits inside, or null at the top level.
  final SunburstArc? parent;

  /// The angle half way round the arc.
  double get midAngle => startAngle + sweepAngle / 2;

  /// The top-level arc this one belongs to — itself, at the top.
  SunburstArc get root {
    var arc = this;
    while (arc.parent != null) {
      arc = arc.parent!;
    }
    return arc;
  }

  /// The arc's outline, round [center].
  Path pathAround(Offset center) {
    final outer = Rect.fromCircle(center: center, radius: outerRadius);
    final inner = Rect.fromCircle(center: center, radius: innerRadius);
    final path = Path()
      ..arcTo(outer, startAngle, sweepAngle, true);
    if (innerRadius <= 0) {
      path.lineTo(center.dx, center.dy);
    } else {
      path.arcTo(inner, startAngle + sweepAngle, -sweepAngle, false);
    }
    return path..close();
  }

  /// Whether [local] falls inside the arc, measured from [center].
  bool containsAround(Offset center, Offset local) {
    final d = local - center;
    final r = d.distance;
    if (r < innerRadius || r > outerRadius) return false;
    var angle = math.atan2(d.dy, d.dx);
    // Bring the angle into the turn the arc starts in.
    while (angle < startAngle) {
      angle += 2 * math.pi;
    }
    return angle - startAngle <= sweepAngle;
  }
}

/// Lays [items] out as rings round a centre, one ring per level.
///
/// Each item takes the share of its parent's sweep that its value is of its
/// siblings' total; the top level shares [sweepAngle]. Rings run from
/// [innerRadius] to [outerRadius], split evenly over the levels actually
/// present, [ringGap] apart. Arcs narrower than [minSweep] radians are dropped,
/// along with everything inside them, so a chart with a long tail stays
/// drawable.
List<SunburstArc> layOutSunburst(
  List<TreemapItem> items, {
  required double innerRadius,
  required double outerRadius,
  double startAngle = -math.pi / 2,
  double sweepAngle = 2 * math.pi,
  double ringGap = 1,
  int? maxDepth,
  double minSweep = 0.004,
}) {
  if (items.isEmpty || outerRadius <= 0 || outerRadius <= innerRadius) {
    return const [];
  }

  int depthOf(List<TreemapItem> level) {
    var deepest = 0;
    for (final item in level) {
      if (item.isGroup) {
        deepest = math.max(deepest, depthOf(item.children));
      }
    }
    return deepest + 1;
  }

  final levels = maxDepth == null
      ? depthOf(items)
      : math.min(depthOf(items), math.max(1, maxDepth));
  final gap = math.max(0.0, ringGap);
  final band = (outerRadius - innerRadius - gap * (levels - 1)) / levels;
  if (band <= 0) return const [];

  final arcs = <SunburstArc>[];

  void place(
    List<TreemapItem> level,
    int depth,
    double from,
    double sweep,
    SunburstArc? parent,
  ) {
    if (depth >= levels) return;
    var total = 0.0;
    for (final item in level) {
      total += item.total;
    }
    if (total <= 0) return;

    final inner = innerRadius + depth * (band + gap);
    var angle = from;
    for (var i = 0; i < level.length; i++) {
      final item = level[i];
      final share = item.total / total * sweep;
      if (share < minSweep) {
        angle += share;
        continue;
      }
      final arc = SunburstArc(
        item: item,
        depth: depth,
        index: i,
        startAngle: angle,
        sweepAngle: share,
        innerRadius: inner,
        outerRadius: inner + band,
        total: item.total,
        parent: parent,
      );
      arcs.add(arc);
      if (item.isGroup) {
        place(item.children, depth + 1, angle, share, arc);
      }
      angle += share;
    }
  }

  place(items, 0, startAngle, sweepAngle, null);
  return arcs;
}

/// The arc under [local], measured from [center], or null when there is none.
///
/// The deepest ring wins, so an inner group is not picked over the child drawn
/// on top of it.
SunburstArc? sunburstArcAt(
  List<SunburstArc> arcs,
  Offset center,
  Offset local,
) {
  SunburstArc? found;
  for (final arc in arcs) {
    if (!arc.containsAround(center, local)) continue;
    if (found == null || arc.depth > found.depth) found = arc;
  }
  return found;
}

/// What a touch on a [SunburstChart] landed on.
@immutable
class SunburstTouchDetails {
  /// Creates the details of a touch on [arc].
  const SunburstTouchDetails({required this.arc, required this.center});

  /// The arc touched.
  final SunburstArc arc;

  /// The centre the rings are drawn round, in the chart's local pixels.
  final Offset center;

  /// The item it draws.
  TreemapItem get item => arc.item;
}

/// A hierarchy as rings round a centre — a sunburst.
///
/// Each ring is one level: holdings inside sectors inside asset classes, files
/// inside folders, revenue inside regions.
///
/// ```dart
/// SunburstChart(
///   items: const [
///     TreemapItem.group(
///       label: 'Equities',
///       children: [
///         TreemapItem(value: 32, label: 'AAPL'),
///         TreemapItem(value: 18, label: 'MSFT'),
///       ],
///     ),
///     TreemapItem(value: 25, label: 'Bonds'),
///   ],
/// );
/// ```
///
/// The chart fills the box it is given, and is [defaultHeight] high in a box
/// with no height of its own.
class SunburstChart extends StatefulWidget {
  /// Creates a sunburst of [items], the first level in the innermost ring.
  const SunburstChart({
    super.key,
    required this.items,
    this.innerRadiusFraction = 0.25,
    this.startAngle = -math.pi / 2,
    this.sweepAngle = 2 * math.pi,
    this.ringGap = 1,
    this.maxDepth,
    this.palette = treemapPalette,
    this.depthFade = 0.12,
    this.labelBuilder,
    this.valueFormatter,
    this.labelStyle,
    this.showLabels = true,
    this.center,
    this.hoverBorder = const BorderSide(color: Color(0xCCFFFFFF), width: 1.5),
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

  /// The top level of the hierarchy; groups become further rings.
  final List<TreemapItem> items;

  /// The hole in the middle, as a share of the chart's radius.
  final double innerRadiusFraction;

  /// Where the first arc begins, in radians clockwise from three o'clock;
  /// twelve o'clock by default.
  final double startAngle;

  /// How far round the rings go, in radians; the whole turn by default.
  final double sweepAngle;

  /// The gap left between two rings.
  final double ringGap;

  /// How many levels to draw; null draws them all.
  final int? maxDepth;

  /// Colours taken in turn by the top level; deeper rings lighten their
  /// ancestor's colour.
  final List<Color> palette;

  /// How much lighter each ring is drawn than the one inside it.
  final double depthFade;

  /// Writes an arc's label; null writes the item's name, or its value when it
  /// has no name.
  final String? Function(SunburstArc arc)? labelBuilder;

  /// Writes a value in a label; null groups thousands.
  final String Function(double value)? valueFormatter;

  /// Style of a label; null picks black or white by how dark the arc is.
  final TextStyle? labelStyle;

  /// Whether labels are written along the arcs that can hold them.
  final bool showLabels;

  /// Shown in the hole in the middle; null shows nothing.
  final Widget? center;

  /// Drawn round the arc under the pointer; null marks none.
  final BorderSide? hoverBorder;

  /// Called as a touch moves over the rings, and with null when it leaves.
  final ValueChanged<SunburstTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched arc; null shows none.
  final Widget? Function(BuildContext context, SunburstTouchDetails details)?
      tooltipBuilder;

  /// How far the card sits from the arc.
  final double tooltipMargin;

  /// How long the rings take to sweep in; zero draws them at once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build sweeps in.
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
  State<SunburstChart> createState() => _SunburstChartState();
}

class _SunburstChartState extends State<SunburstChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 64);
  List<SunburstArc> _arcs = const [];
  Offset _center = Offset.zero;
  double _radius = 0;
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
  void didUpdateWidget(SunburstChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!identical(oldWidget.items, widget.items)) {
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
    final arc = sunburstArcAt(_arcs, _center, local);
    final index = arc == null ? null : _arcs.indexOf(arc);
    if (index == _touched) return;
    setState(() => _touched = index);
    widget.onTouch?.call(
      arc == null
          ? null
          : SunburstTouchDetails(arc: arc, center: _center),
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
        _center = box.center;
        _radius = math.max(0.0, math.min(box.width, box.height) / 2);
        final inner = _radius * widget.innerRadiusFraction.clamp(0.0, 0.95);
        _arcs = layOutSunburst(
          widget.items,
          innerRadius: inner,
          outerRadius: _radius,
          startAngle: widget.startAngle,
          sweepAngle: widget.sweepAngle,
          ringGap: widget.ringGap,
          maxDepth: widget.maxDepth,
        );

        final touched = _touched;
        final details = touched == null || touched >= _arcs.length
            ? null
            : SunburstTouchDetails(arc: _arcs[touched], center: _center);
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
                      painter: SunburstChartPainter(
                        chart: widget,
                        arcs: _arcs,
                        center: _center,
                        touched: details == null ? null : touched,
                        animation: t,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (widget.center != null)
                    Positioned.fromRect(
                      rect: Rect.fromCircle(
                        center: _center,
                        radius: inner / math.sqrt2,
                      ),
                      child: IgnorePointer(
                        child: Center(child: widget.center),
                      ),
                    ),
                  if (tooltip != null && details != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomSingleChildLayout(
                          delegate: _SunburstTooltipLayout(
                            anchor: _anchorOf(details.arc),
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

  /// A small box at the middle of the arc, for the tooltip to sit beside.
  Rect _anchorOf(SunburstArc arc) {
    final r = (arc.innerRadius + arc.outerRadius) / 2;
    final at = _center +
        Offset(math.cos(arc.midAngle) * r, math.sin(arc.midAngle) * r);
    return Rect.fromCenter(center: at, width: 8, height: 8);
  }
}

/// Puts the tooltip to the right of the touched arc, or to its left when there
/// is no room, kept inside the chart.
class _SunburstTooltipLayout extends SingleChildLayoutDelegate {
  _SunburstTooltipLayout({required this.anchor, required this.margin});

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
  bool shouldRelayout(_SunburstTooltipLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.margin != margin;
}

/// Paints a [SunburstChart]: the rings and the labels that fit.
class SunburstChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [arcs] round [center].
  SunburstChartPainter({
    required this.chart,
    required this.arcs,
    required this.center,
    required this.touched,
    required this.animation,
    required this.textCache,
  });

  final SunburstChart chart;
  final List<SunburstArc> arcs;
  final Offset center;
  final int? touched;
  final double animation;
  final TextPainterCache textCache;

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (arcs.isEmpty) return;

    final t = animation.clamp(0.0, 1.0);
    final fill = Paint()..isAntiAlias = true;

    for (final arc in arcs) {
      final shown = t >= 1 ? arc : _swept(arc, t);
      final color = _colorOf(arc);
      fill.color = color;
      canvas.drawPath(shown.pathAround(center), fill);
      if (t >= 1 && chart.showLabels) _paintLabel(canvas, arc, color);
    }

    final hover = chart.hoverBorder;
    final at = touched;
    if (at != null &&
        at < arcs.length &&
        hover != null &&
        hover.style != BorderStyle.none &&
        hover.width > 0) {
      canvas.drawPath(
        arcs[at].pathAround(center),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = hover.width
          ..strokeJoin = StrokeJoin.round
          ..color = hover.color
          ..isAntiAlias = true,
      );
    }
  }

  /// The arc as it looks [t] of the way in: swept out from its start.
  SunburstArc _swept(SunburstArc arc, double t) => SunburstArc(
        item: arc.item,
        depth: arc.depth,
        index: arc.index,
        startAngle: arc.startAngle,
        sweepAngle: arc.sweepAngle * t,
        innerRadius: arc.innerRadius,
        outerRadius: arc.outerRadius,
        total: arc.total,
        parent: arc.parent,
      );

  Color _colorOf(SunburstArc arc) {
    final own = arc.item.color;
    if (own != null) return own;
    final palette = chart.palette;
    final base = palette.isEmpty
        ? const Color(0xFF4C86CD)
        : palette[arc.root.index % palette.length];
    if (arc.depth == 0) return base;
    final fade = (chart.depthFade * arc.depth).clamp(0.0, 0.8);
    return Color.lerp(base, const Color(0xFFFFFFFF), fade) ?? base;
  }

  String _formatValue(double value) {
    final format = chart.valueFormatter;
    if (format != null) return format(value);
    final whole = value.round();
    final digits = whole.abs().toString();
    final grouped = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return whole < 0 ? '-$grouped' : grouped;
  }

  String? _labelOf(SunburstArc arc) {
    final builder = chart.labelBuilder;
    if (builder != null) return builder(arc);
    return arc.item.label ?? _formatValue(arc.total);
  }

  /// Writes the label along the middle of the arc, turned to follow it, and
  /// only when the arc is long and thick enough to hold it.
  void _paintLabel(Canvas canvas, SunburstArc arc, Color color) {
    final text = _labelOf(arc);
    if (text == null || text.isEmpty) return;

    final style = chart.labelStyle ??
        TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color.computeLuminance() > 0.5
              ? const Color(0xDD000000)
              : const Color(0xFFFFFFFF),
        );
    final tp = textCache.get(text, style);
    final band = arc.outerRadius - arc.innerRadius;
    final mid = (arc.innerRadius + arc.outerRadius) / 2;
    if (tp.height > band - 2) return;
    if (tp.width > arc.sweepAngle * mid - 4) return;

    var angle = arc.midAngle;
    // Kept upright: text on the left half is turned the other way.
    final flip = angle > math.pi / 2 || angle < -math.pi / 2;
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(flip ? angle + math.pi : angle)
      ..translate(flip ? -mid : mid, 0);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(SunburstChartPainter oldDelegate) =>
      !identical(oldDelegate.chart, chart) ||
      !identical(oldDelegate.arcs, arcs) ||
      oldDelegate.center != center ||
      oldDelegate.touched != touched ||
      oldDelegate.animation != animation;
}
