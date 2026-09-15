import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';

/// A flow between two nodes of a [ChordChart].
@immutable
class ChordFlow {
  /// Creates a flow of [value] from [from] to [to].
  const ChordFlow({
    required this.from,
    required this.to,
    required this.value,
    this.color,
    this.tooltip,
  });

  /// Where the flow starts, as a node name.
  final String from;

  /// Where it ends.
  final String to;

  /// How large it is. Negatives and nonsense count as nothing.
  final double value;

  /// What the ribbon is painted in; null takes the larger end's colour.
  final Color? color;

  /// Shown when the ribbon is touched; null shows both ends and the value.
  final String? tooltip;

  /// The value actually drawn.
  double get drawnValue => value.isFinite && value > 0 ? value : 0;
}

/// A node round the ring of a [ChordChart].
@immutable
class ChordNode {
  /// Creates a node called [label].
  const ChordNode({required this.label, this.color, this.tooltip});

  /// What the node is called. Flows name their ends by this.
  final String label;

  /// What its arc and its ribbons are painted in; null takes a colour from
  /// the chart's palette by position.
  final Color? color;

  /// Shown when its arc is touched; null shows its label and total.
  final String? tooltip;
}

/// The totals of a set of [ChordFlow]s, by node.
@immutable
class ChordTotals {
  /// Creates totals already worked out.
  const ChordTotals({
    required this.names,
    required this.out,
    required this.into,
  });

  /// Adds up [flows] over [names], in that order.
  factory ChordTotals.of(List<String> names, List<ChordFlow> flows) {
    final index = {for (var i = 0; i < names.length; i++) names[i]: i};
    final out = List<double>.filled(names.length, 0);
    final into = List<double>.filled(names.length, 0);
    for (final flow in flows) {
      final from = index[flow.from], to = index[flow.to];
      if (from == null || to == null) continue;
      out[from] += flow.drawnValue;
      into[to] += flow.drawnValue;
    }
    return ChordTotals(names: names, out: out, into: into);
  }

  /// The nodes, in ring order.
  final List<String> names;

  /// How much leaves each node.
  final List<double> out;

  /// How much arrives at it.
  final List<double> into;

  /// How much passes through node [index] either way, which is the length of
  /// its arc.
  double totalAt(int index) => out[index] + into[index];

  /// Everything that passes through every node, which is twice the sum of the
  /// flows — each is counted at both its ends.
  double get grandTotal {
    var sum = 0.0;
    for (var i = 0; i < names.length; i++) {
      sum += totalAt(i);
    }
    return sum;
  }
}

/// Where one node's arc sits on a [ChordChart]'s ring.
@immutable
class ChordArc {
  /// Creates the arc of the node at [index].
  const ChordArc({
    required this.index,
    required this.node,
    required this.startAngle,
    required this.sweepAngle,
    required this.total,
  });

  /// Which node this is, into the chart's nodes.
  final int index;

  /// The node itself.
  final ChordNode node;

  /// Where the arc starts, in radians clockwise from three o'clock.
  final double startAngle;

  /// How far it runs, in radians.
  final double sweepAngle;

  /// How much passes through the node either way.
  final double total;

  /// The middle of the arc, in radians.
  double get midAngle => startAngle + sweepAngle / 2;

  /// Whether [angle] falls inside it, whatever turn it is written on.
  bool containsAngle(double angle) {
    final turn = 2 * math.pi;
    var relative = (angle - startAngle) % turn;
    if (relative < 0) relative += turn;
    return relative <= sweepAngle;
  }
}

/// Where one ribbon of a [ChordChart] runs.
@immutable
class ChordRibbon {
  /// Creates the ribbon of the flow at [index].
  const ChordRibbon({
    required this.index,
    required this.flow,
    required this.fromIndex,
    required this.toIndex,
    required this.shape,
  });

  /// Which flow this is, into the chart's flows.
  final int index;

  /// The flow itself.
  final ChordFlow flow;

  /// The node it leaves, into the chart's nodes.
  final int fromIndex;

  /// The node it arrives at.
  final int toIndex;

  /// The ribbon, as a closed path.
  final Path shape;
}

/// Where a [ChordChart]'s ring and ribbons sit.
@immutable
class ChordLayout {
  /// Creates a laid-out chart.
  const ChordLayout({
    required this.size,
    required this.center,
    required this.radius,
    required this.ringThickness,
    required this.arcs,
    required this.ribbons,
    required this.totals,
  });

  /// Nothing to draw.
  static const empty = ChordLayout(
    size: Size.zero,
    center: Offset.zero,
    radius: 0,
    ringThickness: 0,
    arcs: [],
    ribbons: [],
    totals: ChordTotals(names: [], out: [], into: []),
  );

  /// The box the chart was laid out in.
  final Size size;

  /// The middle of the ring.
  final Offset center;

  /// The outer radius of the ring.
  final double radius;

  /// How thick the ring's band is.
  final double ringThickness;

  /// The nodes' arcs, in the order they were given.
  final List<ChordArc> arcs;

  /// The ribbons, in the order their flows were given.
  final List<ChordRibbon> ribbons;

  /// What the arcs were sized from.
  final ChordTotals totals;

  /// Whether there is anything to draw.
  bool get isEmpty => arcs.isEmpty || radius <= 0;

  /// The radius the ribbons spring from.
  double get innerRadius => math.max(0, radius - ringThickness);

  /// The arc under [point]; null when the point is off the ring.
  ChordArc? arcAt(Offset point) {
    final offset = point - center;
    final distance = offset.distance;
    if (distance > radius || distance < innerRadius) return null;
    final angle = math.atan2(offset.dy, offset.dx);
    for (final arc in arcs) {
      if (arc.containsAngle(angle)) return arc;
    }
    return null;
  }

  /// The ribbon under [point]; null when none is. Ribbons drawn later are
  /// tried first, so the one on top wins.
  ChordRibbon? ribbonAt(Offset point) {
    if ((point - center).distance > innerRadius) return null;
    for (final ribbon in ribbons.reversed) {
      if (ribbon.shape.contains(point)) return ribbon;
    }
    return null;
  }
}

/// Lays out [nodes] and [flows] as a ring in [size].
///
/// Each node's arc is as long as everything passing through it, and every flow
/// takes a slice of both the arcs it touches. [progress] sweeps the ring and
/// its ribbons open, for a draw-in animation.
ChordLayout layOutChord(
  List<ChordNode> nodes,
  List<ChordFlow> flows, {
  required Size size,
  double ringThickness = 12,
  double padAngle = 0.03,
  double startAngle = -math.pi / 2,
  double labelWidth = 0,
  EdgeInsets padding = EdgeInsets.zero,
  double progress = 1,
}) {
  if (nodes.isEmpty) return ChordLayout.empty;
  final box = padding.deflateRect(Offset.zero & size);
  if (box.width <= 0 || box.height <= 0) return ChordLayout.empty;

  final radius =
      math.min(box.width, box.height) / 2 - math.max(0, labelWidth);
  if (radius <= 0) return ChordLayout.empty;
  final center = box.center;
  final thickness = math.min(ringThickness, radius);

  final names = [for (final node in nodes) node.label];
  final totals = ChordTotals.of(names, flows);
  final grand = totals.grandTotal;
  if (!(grand > 0)) return ChordLayout.empty;

  // The pads come out of the turn before the arcs share what is left, so an
  // arc's length stays true to its share however wide the pads are.
  final pads = padAngle.clamp(0.0, math.pi / math.max(1, nodes.length * 2));
  final turn = 2 * math.pi * progress.clamp(0.0, 1.0);
  final usable = math.max(0.0, turn - pads * nodes.length);

  final arcs = <ChordArc>[];
  // Where the next flow at each node starts: out first, then in, so a node's
  // own side of the ring stays in one piece.
  final cursors = List<double>.filled(nodes.length, 0);
  var angle = startAngle;
  for (var i = 0; i < nodes.length; i++) {
    final sweep = usable * totals.totalAt(i) / grand;
    arcs.add(
      ChordArc(
        index: i,
        node: nodes[i],
        startAngle: angle,
        sweepAngle: sweep,
        total: totals.totalAt(i),
      ),
    );
    cursors[i] = angle;
    angle += sweep + pads;
  }

  final inner = math.max(0.0, radius - thickness);
  Offset at(double angle, double distance) =>
      center + Offset(math.cos(angle) * distance, math.sin(angle) * distance);

  final ribbons = <ChordRibbon>[];
  final index = {for (var i = 0; i < names.length; i++) names[i]: i};
  for (var f = 0; f < flows.length; f++) {
    final flow = flows[f];
    final from = index[flow.from], to = index[flow.to];
    if (from == null || to == null || flow.drawnValue <= 0) continue;
    final share = usable * flow.drawnValue / grand;

    final fromStart = cursors[from];
    cursors[from] += share;
    final toStart = cursors[to];
    cursors[to] += share;

    final path = Path()
      ..moveTo(at(fromStart, inner).dx, at(fromStart, inner).dy)
      ..arcToPoint(
        at(fromStart + share, inner),
        radius: Radius.circular(inner),
        clockwise: true,
      )
      // Through the middle: a ribbon that bends towards the centre reads as
      // one flow rather than two arcs meeting.
      ..quadraticBezierTo(
        center.dx,
        center.dy,
        at(toStart, inner).dx,
        at(toStart, inner).dy,
      )
      ..arcToPoint(
        at(toStart + share, inner),
        radius: Radius.circular(inner),
        clockwise: true,
      )
      ..quadraticBezierTo(
        center.dx,
        center.dy,
        at(fromStart, inner).dx,
        at(fromStart, inner).dy,
      )
      ..close();

    ribbons.add(
      ChordRibbon(
        index: f,
        flow: flow,
        fromIndex: from,
        toIndex: to,
        shape: path,
      ),
    );
  }

  return ChordLayout(
    size: size,
    center: center,
    radius: radius,
    ringThickness: thickness,
    arcs: arcs,
    ribbons: ribbons,
    totals: totals,
  );
}

/// Flow between nodes, both ways round a ring — a chord diagram.
///
/// Where a Sankey has to break a cycle, a chord draws it: money moving between
/// accounts, volume between venues, rotation between sectors. Each node's arc
/// is as long as everything passing through it, and every ribbon is as wide as
/// the flow it carries.
///
/// ```dart
/// ChordChart(
///   nodes: const [
///     ChordNode(label: 'Binance'),
///     ChordNode(label: 'OKX'),
///     ChordNode(label: 'Bybit'),
///   ],
///   flows: const [
///     ChordFlow(from: 'Binance', to: 'OKX', value: 40),
///     ChordFlow(from: 'OKX', to: 'Bybit', value: 25),
///     ChordFlow(from: 'Bybit', to: 'Binance', value: 30),
///   ],
/// );
/// ```
class ChordChart extends StatefulWidget {
  /// Creates a chord diagram of [nodes] and [flows].
  const ChordChart({
    super.key,
    required this.nodes,
    required this.flows,
    this.palette = defaultPalette,
    this.ringThickness = 12,
    this.padAngle = 0.03,
    this.startAngle = -math.pi / 2,
    this.ribbonOpacity = 0.4,
    this.ribbonStroke = 0.5,
    this.showLabels = true,
    this.labelWidth = 56,
    this.labelStyle,
    this.fadeUntouched = true,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.onNodeTap,
    this.onFlowTap,
    this.tooltipBuilder,
    this.defaultSize = 280,
    this.semanticLabel,
  });

  /// The nodes, placed round the ring in the order given.
  final List<ChordNode> nodes;

  /// The flows between them. A flow naming a node that is not there is
  /// dropped.
  final List<ChordFlow> flows;

  /// Colours handed to nodes that name none, in order.
  final List<Color> palette;

  /// The colours used where a node names none.
  static const defaultPalette = [
    Color(0xFF4C86CD),
    Color(0xFF2F9E44),
    Color(0xFFE8590C),
    Color(0xFF9C36B5),
    Color(0xFF0CA678),
    Color(0xFFE03131),
    Color(0xFFF59F00),
    Color(0xFF4263EB),
  ];

  /// How thick the ring's band is.
  final double ringThickness;

  /// The gap between two arcs, in radians.
  final double padAngle;

  /// Where the first arc starts, in radians clockwise from three o'clock.
  final double startAngle;

  /// How solid the ribbons are painted.
  final double ribbonOpacity;

  /// How thick an outline they get; 0 draws none.
  final double ribbonStroke;

  /// Whether the nodes are labelled outside the ring.
  final bool showLabels;

  /// How much room those labels take outside it.
  final double labelWidth;

  /// Style of the labels.
  final TextStyle? labelStyle;

  /// Whether everything not touching the held node or ribbon fades.
  final bool fadeUntouched;

  /// Space kept clear around the ring.
  final EdgeInsets padding;

  /// Painted behind the whole chart.
  final Color? backgroundColor;

  /// How long the ring takes to sweep open; zero draws it at once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build sweeps the ring open.
  final bool animateOnMount;

  /// Called with a node when its arc is touched, and with null when the touch
  /// leaves it.
  final void Function(ChordNode? node)? onNodeTap;

  /// Called with a flow when its ribbon is touched, and with null when the
  /// touch leaves it.
  final void Function(ChordFlow? flow)? onFlowTap;

  /// Builds the card shown over a touched ribbon; null shows both its ends
  /// and its value.
  final Widget Function(BuildContext context, ChordFlow flow)? tooltipBuilder;

  /// The size taken in a box that sets none.
  final double defaultSize;

  /// What a screen reader announces for the chart.
  final String? semanticLabel;

  @override
  State<ChordChart> createState() => _ChordChartState();
}

class _ChordChartState extends State<ChordChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 128);
  ChordLayout _layout = ChordLayout.empty;
  int? _node;
  int? _flow;

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
  void didUpdateWidget(ChordChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!identical(oldWidget.flows, widget.flows) ||
        !identical(oldWidget.nodes, widget.nodes)) {
      _node = null;
      _flow = null;
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

  void _touch(Offset point) {
    final arc = _layout.arcAt(point);
    final ribbon = arc == null ? _layout.ribbonAt(point) : null;
    if (arc?.index == _node && ribbon?.index == _flow) return;
    setState(() {
      _node = arc?.index;
      _flow = ribbon?.index;
    });
    widget.onNodeTap?.call(arc?.node);
    widget.onFlowTap?.call(ribbon?.flow);
  }

  void _clear() {
    if (_node == null && _flow == null) return;
    setState(() {
      _node = null;
      _flow = null;
    });
    widget.onNodeTap?.call(null);
    widget.onFlowTap?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.animationCurve.transform(_animation.value);

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : widget.defaultSize;
          final height = constraints.hasBoundedHeight &&
                  constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : widget.defaultSize;
          _layout = layOutChord(
            widget.nodes,
            widget.flows,
            size: Size(width, height),
            ringThickness: widget.ringThickness,
            padAngle: widget.padAngle,
            startAngle: widget.startAngle,
            labelWidth: widget.showLabels ? widget.labelWidth : 0,
            padding: widget.padding,
            progress: progress,
          );

          final flow = _flow;
          return SizedBox(
            width: width,
            height: height,
            child: Listener(
              onPointerDown: (event) => _touch(event.localPosition),
              onPointerMove: (event) => _touch(event.localPosition),
              onPointerUp: (_) => _clear(),
              onPointerCancel: (_) => _clear(),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: ChordChartPainter(
                        chart: widget,
                        layout: _layout,
                        node: _node,
                        flow: flow,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (flow != null && flow < widget.flows.length)
                    _tooltip(context, widget.flows[flow]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tooltip(BuildContext context, ChordFlow flow) {
    final build = widget.tooltipBuilder;
    final child = build != null
        ? build(context, flow)
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xEE1B1D22),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              flow.tooltip ??
                  '${flow.from} → ${flow.to}  ${_number(flow.drawnValue)}',
              style: const TextStyle(color: Color(0xFFE9ECEF), fontSize: 11),
            ),
          );
    return Positioned(
      left: math.max(0, _layout.center.dx - 40),
      top: math.max(0, _layout.center.dy - 12),
      child: IgnorePointer(child: child),
    );
  }
}

String _number(double value) {
  if (!value.isFinite) return '';
  if (value == value.roundToDouble() && value.abs() < 1e15) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}

/// Paints a [ChordChart]: the ribbons, the ring's arcs and the node labels.
class ChordChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [layout].
  ChordChartPainter({
    required this.chart,
    required this.layout,
    required this.node,
    required this.flow,
    required this.textCache,
  });

  final ChordChart chart;
  final ChordLayout layout;

  /// The node whose arc is under the finger; null when none is.
  final int? node;

  /// The flow whose ribbon is; null when none is.
  final int? flow;
  final TextPainterCache textCache;

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (layout.isEmpty) return;

    Color colorOf(int index) =>
        chart.nodes[index].color ??
        chart.palette[index % math.max(1, chart.palette.length)];

    final labelStyle = chart.labelStyle ??
        const TextStyle(color: Color(0xFFB4B8C0), fontSize: 11);

    for (final ribbon in layout.ribbons) {
      // The larger end's colour, so a ribbon reads as belonging to the node
      // it mostly comes from.
      final owner =
          layout.totals.totalAt(ribbon.fromIndex) >=
                  layout.totals.totalAt(ribbon.toIndex)
              ? ribbon.fromIndex
              : ribbon.toIndex;
      final base = ribbon.flow.color ?? colorOf(owner);
      final touchesHeld = node == null ||
          ribbon.fromIndex == node ||
          ribbon.toIndex == node;
      final held = flow == null || flow == ribbon.index;
      final dimmed = chart.fadeUntouched && (!touchesHeld || !held);
      canvas.drawPath(
        ribbon.shape,
        Paint()
          ..color = base.withValues(
            alpha: (chart.ribbonOpacity * (dimmed ? 0.25 : 1.4))
                .clamp(0.0, 1.0),
          ),
      );
      if (chart.ribbonStroke > 0 && !dimmed) {
        canvas.drawPath(
          ribbon.shape,
          Paint()
            ..color = base
            ..style = PaintingStyle.stroke
            ..strokeWidth = chart.ribbonStroke,
        );
      }
    }

    final ringRect = Rect.fromCircle(
      center: layout.center,
      radius: layout.radius - layout.ringThickness / 2,
    );
    for (final arc in layout.arcs) {
      if (arc.sweepAngle <= 0) continue;
      final base = colorOf(arc.index);
      final dimmed =
          chart.fadeUntouched && node != null && node != arc.index;
      canvas.drawArc(
        ringRect,
        arc.startAngle,
        arc.sweepAngle,
        false,
        Paint()
          ..color = dimmed
              ? base.withValues(alpha: 0.35)
              : base
          ..style = PaintingStyle.stroke
          ..strokeWidth = layout.ringThickness,
      );

      if (chart.showLabels && chart.labelWidth > 0) {
        final painter = textCache.get(arc.node.label, labelStyle);
        final at = layout.center +
            Offset(
              math.cos(arc.midAngle),
              math.sin(arc.midAngle),
            ) *
                (layout.radius + 6);
        // Pushed outwards from the ring: left of it on the left half, right
        // of it on the right, so a label never sits on the ring.
        final left = math.cos(arc.midAngle) < 0
            ? at.dx - painter.width
            : at.dx;
        painter.paint(
          canvas,
          Offset(
            left.clamp(0.0, math.max(0.0, size.width - painter.width)),
            (at.dy - painter.height / 2)
                .clamp(0.0, math.max(0.0, size.height - painter.height)),
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(ChordChartPainter old) =>
      old.chart != chart ||
      old.layout != layout ||
      old.node != node ||
      old.flow != flow;
}
