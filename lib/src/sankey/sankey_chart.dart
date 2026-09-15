import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';
import '../treemap/treemap_data.dart' show treemapPalette;

/// One end of a flow in a [SankeyChart] — an account, a source, a cost.
@immutable
class SankeyNode {
  /// Creates the node known as [id].
  const SankeyNode({
    required this.id,
    this.label,
    this.color,
    this.data,
  });

  /// What links name this node by. Unique within a chart.
  final String id;

  /// What the node is called; null writes [id].
  final String? label;

  /// A colour of this node's own.
  final Color? color;

  /// Anything the app wants back when this node is touched.
  final Object? data;
}

/// A quantity moving from one [SankeyNode] to another.
@immutable
class SankeyLink {
  /// Creates a flow of [value] from [source] to [target].
  const SankeyLink({
    required this.source,
    required this.target,
    required this.value,
    this.color,
    this.data,
  });

  /// The id of the node the flow leaves.
  final String source;

  /// The id of the node the flow arrives at.
  final String target;

  /// How much moves.
  final double value;

  /// A colour of this flow's own; null blends its two nodes' colours.
  final Color? color;

  /// Anything the app wants back when this flow is touched.
  final Object? data;
}

/// Where one [SankeyNode] was laid out.
@immutable
class SankeyNodeBox {
  /// Creates the box of [node].
  const SankeyNodeBox({
    required this.node,
    required this.index,
    required this.depth,
    required this.rect,
    required this.value,
    required this.incoming,
    required this.outgoing,
  });

  /// The node this box draws.
  final SankeyNode node;

  /// Its position in [SankeyLayout.nodes].
  final int index;

  /// Which column it stands in, counted from the left.
  final int depth;

  /// The bar drawn for it.
  final Rect rect;

  /// How much passes through it: the larger of what arrives and what leaves.
  final double value;

  /// How much arrives.
  final double incoming;

  /// How much leaves.
  final double outgoing;

  /// Whether [local] is inside the bar.
  bool contains(Offset local) => rect.contains(local);
}

/// Where one [SankeyLink] was laid out: a ribbon between two boxes.
@immutable
class SankeyLinkRibbon {
  /// Creates the ribbon of [link].
  const SankeyLinkRibbon({
    required this.link,
    required this.index,
    required this.source,
    required this.target,
    required this.sourceTop,
    required this.targetTop,
    required this.thickness,
  });

  /// The flow this ribbon draws.
  final SankeyLink link;

  /// Its position in [SankeyLayout.links].
  final int index;

  /// The box the ribbon leaves.
  final SankeyNodeBox source;

  /// The box it arrives at.
  final SankeyNodeBox target;

  /// Where it meets the source bar, in pixels from the top of the chart.
  final double sourceTop;

  /// Where it meets the target bar.
  final double targetTop;

  /// How tall the ribbon is at either end.
  final double thickness;

  /// The ribbon's outline: two cubics, curving out of the source bar and into
  /// the target bar.
  Path get path {
    final x0 = source.rect.right;
    final x1 = target.rect.left;
    final mid = (x0 + x1) / 2;
    final y0 = sourceTop;
    final y1 = targetTop;
    final h = math.max(thickness, 0.0);
    return Path()
      ..moveTo(x0, y0)
      ..cubicTo(mid, y0, mid, y1, x1, y1)
      ..lineTo(x1, y1 + h)
      ..cubicTo(mid, y1 + h, mid, y0 + h, x0, y0 + h)
      ..close();
  }

  /// Whether [local] is inside the ribbon.
  bool contains(Offset local) => path.contains(local);
}

/// Nodes and ribbons placed inside a box.
@immutable
class SankeyLayout {
  /// Creates a layout of [nodes] and [links].
  const SankeyLayout({required this.nodes, required this.links});

  /// An empty diagram.
  static const SankeyLayout empty = SankeyLayout(nodes: [], links: []);

  /// The node bars, left to right.
  final List<SankeyNodeBox> nodes;

  /// The ribbons between them.
  final List<SankeyLinkRibbon> links;

  /// Whether nothing was laid out.
  bool get isEmpty => nodes.isEmpty;
}

/// Arranges [nodes] in columns across [bounds] and joins them with [links].
///
/// A node's column is how many flows deep it lies: a node with nothing
/// arriving stands in the first column, and every other node stands one column
/// right of the furthest node feeding it. A link that would point backwards —
/// a cycle — is dropped. Bars are [nodeWidth] wide, [nodePadding] apart, and
/// their heights share the remaining height by value.
SankeyLayout layOutSankey(
  List<SankeyNode> nodes,
  List<SankeyLink> links,
  Rect bounds, {
  double nodeWidth = 14,
  double nodePadding = 12,
}) {
  if (nodes.isEmpty || bounds.width <= 0 || bounds.height <= 0) {
    return SankeyLayout.empty;
  }

  final indexOf = <String, int>{};
  for (var i = 0; i < nodes.length; i++) {
    indexOf.putIfAbsent(nodes[i].id, () => i);
  }

  double clean(double v) => v.isFinite && v > 0 ? v : 0;

  // Links naming two known, different nodes and carrying something.
  final kept = <SankeyLink>[];
  for (final link in links) {
    final from = indexOf[link.source];
    final to = indexOf[link.target];
    if (from == null || to == null || from == to) continue;
    if (clean(link.value) <= 0) continue;
    kept.add(link);
  }

  // Longest path from a source, relaxed until it settles; a link that cannot
  // advance any further is part of a cycle and is dropped.
  final depth = List<int>.filled(nodes.length, 0);
  for (var pass = 0; pass < nodes.length; pass++) {
    var moved = false;
    for (final link in kept) {
      final from = indexOf[link.source]!;
      final to = indexOf[link.target]!;
      if (depth[to] < depth[from] + 1) {
        depth[to] = depth[from] + 1;
        moved = true;
      }
    }
    if (!moved) break;
  }
  final forward = [
    for (final link in kept)
      if (depth[indexOf[link.source]!] < depth[indexOf[link.target]!]) link,
  ];

  final incoming = List<double>.filled(nodes.length, 0);
  final outgoing = List<double>.filled(nodes.length, 0);
  for (final link in forward) {
    outgoing[indexOf[link.source]!] += clean(link.value);
    incoming[indexOf[link.target]!] += clean(link.value);
  }
  final through = [
    for (var i = 0; i < nodes.length; i++) math.max(incoming[i], outgoing[i]),
  ];

  // The tallest column decides how many pixels a unit of value is worth.
  final columns = <int, List<int>>{};
  for (var i = 0; i < nodes.length; i++) {
    columns.putIfAbsent(depth[i], () => []).add(i);
  }
  final depths = columns.keys.toList()..sort();

  var scale = double.infinity;
  for (final d in depths) {
    final column = columns[d]!;
    var total = 0.0;
    for (final i in column) {
      total += through[i];
    }
    final free = bounds.height - nodePadding * (column.length - 1);
    if (total <= 0 || free <= 0) continue;
    scale = math.min(scale, free / total);
  }
  if (!scale.isFinite) scale = 0;

  final width = math.max(0.0, math.min(nodeWidth, bounds.width));
  final span = depths.length <= 1
      ? 0.0
      : (bounds.width - width) / (depths.last - depths.first);

  final boxes = List<SankeyNodeBox?>.filled(nodes.length, null);
  for (final d in depths) {
    final column = columns[d]!;
    var total = 0.0;
    for (final i in column) {
      total += through[i] * scale;
    }
    total += nodePadding * (column.length - 1);
    final left = bounds.left + (d - depths.first) * span;
    var top = bounds.top + math.max(0.0, (bounds.height - total) / 2);
    for (final i in column) {
      final height = through[i] * scale;
      boxes[i] = SankeyNodeBox(
        node: nodes[i],
        index: i,
        depth: d,
        rect: Rect.fromLTWH(left, top, width, height),
        value: through[i],
        incoming: incoming[i],
        outgoing: outgoing[i],
      );
      top += height + nodePadding;
    }
  }

  // Ribbons stack against each bar in the order the links were given.
  final usedOut = List<double>.filled(nodes.length, 0);
  final usedIn = List<double>.filled(nodes.length, 0);
  final ribbons = <SankeyLinkRibbon>[];
  for (final link in forward) {
    final from = indexOf[link.source]!;
    final to = indexOf[link.target]!;
    final source = boxes[from]!;
    final target = boxes[to]!;
    final thickness = clean(link.value) * scale;
    ribbons.add(
      SankeyLinkRibbon(
        link: link,
        index: ribbons.length,
        source: source,
        target: target,
        sourceTop: source.rect.top + usedOut[from],
        targetTop: target.rect.top + usedIn[to],
        thickness: thickness,
      ),
    );
    usedOut[from] += thickness;
    usedIn[to] += thickness;
  }

  return SankeyLayout(
    nodes: [for (final box in boxes) box!],
    links: ribbons,
  );
}

/// The node bar under [local], or null when there is none.
SankeyNodeBox? sankeyNodeAt(SankeyLayout layout, Offset local) {
  for (final box in layout.nodes) {
    if (box.contains(local)) return box;
  }
  return null;
}

/// The ribbon under [local], or null when there is none.
SankeyLinkRibbon? sankeyLinkAt(SankeyLayout layout, Offset local) {
  for (final ribbon in layout.links.reversed) {
    if (ribbon.contains(local)) return ribbon;
  }
  return null;
}

/// What a touch on a [SankeyChart] landed on: a node bar or a ribbon.
@immutable
class SankeyTouchDetails {
  /// Creates the details of a touch on [node] or [link].
  const SankeyTouchDetails({this.node, this.link});

  /// The bar touched, when the touch was on one.
  final SankeyNodeBox? node;

  /// The ribbon touched, when the touch was on one.
  final SankeyLinkRibbon? link;

  /// Where the touch landed, in pixels from the top left of the chart.
  Rect get anchor => node?.rect ?? link!.path.getBounds();
}

/// Flows between nodes, their width the quantity moved — a Sankey diagram.
///
/// It shows where a quantity comes from and where it goes: money between
/// accounts, income into expenses, traffic between pages.
///
/// ```dart
/// SankeyChart(
///   nodes: const [
///     SankeyNode(id: 'salary', label: 'Salary'),
///     SankeyNode(id: 'budget', label: 'Budget'),
///     SankeyNode(id: 'rent', label: 'Rent'),
///     SankeyNode(id: 'saved', label: 'Saved'),
///   ],
///   links: const [
///     SankeyLink(source: 'salary', target: 'budget', value: 5200),
///     SankeyLink(source: 'budget', target: 'rent', value: 1800),
///     SankeyLink(source: 'budget', target: 'saved', value: 3400),
///   ],
/// );
/// ```
///
/// The chart fills the box it is given, and is [defaultHeight] high in a box
/// with no height of its own.
class SankeyChart extends StatefulWidget {
  /// Creates a diagram of [links] between [nodes].
  const SankeyChart({
    super.key,
    required this.nodes,
    required this.links,
    this.nodeWidth = 14,
    this.nodePadding = 12,
    this.palette = treemapPalette,
    this.linkOpacity = 0.45,
    this.labelBuilder,
    this.valueFormatter,
    this.labelStyle,
    this.showLabels = true,
    this.labelGap = 6,
    this.hoverBorder = const BorderSide(color: Color(0xCCFFFFFF), width: 1.5),
    this.fadeUntouched = true,
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

  /// The nodes, in the order their ribbons stack.
  final List<SankeyNode> nodes;

  /// The flows between them.
  final List<SankeyLink> links;

  /// How wide a node bar is.
  final double nodeWidth;

  /// The gap left between two bars in a column.
  final double nodePadding;

  /// Colours taken in turn by nodes that name none.
  final List<Color> palette;

  /// How opaque a ribbon is drawn.
  final double linkOpacity;

  /// Writes a node's label; null writes its name and value.
  final String? Function(SankeyNodeBox node)? labelBuilder;

  /// Writes a value in the default label; null groups thousands.
  final String Function(double value)? valueFormatter;

  /// Style of a node label.
  final TextStyle? labelStyle;

  /// Whether node labels are written beside the bars.
  final bool showLabels;

  /// How far a label sits from its bar.
  final double labelGap;

  /// Drawn round the node or ribbon under the pointer; null marks none.
  final BorderSide? hoverBorder;

  /// Whether ribbons not touching the hovered node fade back.
  final bool fadeUntouched;

  /// Called as a touch moves over the diagram, and with null when it leaves.
  final ValueChanged<SankeyTouchDetails?>? onTouch;

  /// Builds a card shown beside what was touched; null shows none.
  final Widget? Function(BuildContext context, SankeyTouchDetails details)?
      tooltipBuilder;

  /// How far the card sits from what was touched.
  final double tooltipMargin;

  /// How long the ribbons take to grow in; zero draws them at once.
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
  State<SankeyChart> createState() => _SankeyChartState();
}

class _SankeyChartState extends State<SankeyChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 64);
  SankeyLayout _layout = SankeyLayout.empty;
  int? _node;
  int? _link;

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
  void didUpdateWidget(SankeyChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!identical(oldWidget.nodes, widget.nodes) ||
        !identical(oldWidget.links, widget.links)) {
      _node = null;
      _link = null;
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
    final node = sankeyNodeAt(_layout, local);
    final link = node == null ? sankeyLinkAt(_layout, local) : null;
    if (node?.index == _node && link?.index == _link) return;
    setState(() {
      _node = node?.index;
      _link = link?.index;
    });
    widget.onTouch?.call(
      node == null && link == null
          ? null
          : SankeyTouchDetails(node: node, link: link),
    );
  }

  void _leave() {
    if (_node == null && _link == null) return;
    setState(() {
      _node = null;
      _link = null;
    });
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
        _layout = layOutSankey(
          widget.nodes,
          widget.links,
          widget.padding.deflateRect(Offset.zero & size),
          nodeWidth: widget.nodeWidth,
          nodePadding: widget.nodePadding,
        );

        final node = _node == null || _node! >= _layout.nodes.length
            ? null
            : _layout.nodes[_node!];
        final link = _link == null || _link! >= _layout.links.length
            ? null
            : _layout.links[_link!];
        final details = node == null && link == null
            ? null
            : SankeyTouchDetails(node: node, link: link);
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
                      painter: SankeyChartPainter(
                        chart: widget,
                        layout: _layout,
                        touchedNode: node?.index,
                        touchedLink: link?.index,
                        animation: t,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (tooltip != null && details != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomSingleChildLayout(
                          delegate: _SankeyTooltipLayout(
                            anchor: details.anchor,
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

/// Puts the tooltip to the right of what was touched, or to its left when
/// there is no room, kept inside the chart.
class _SankeyTooltipLayout extends SingleChildLayoutDelegate {
  _SankeyTooltipLayout({required this.anchor, required this.margin});

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
  bool shouldRelayout(_SankeyTooltipLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.margin != margin;
}

/// Paints a [SankeyChart]: the ribbons, the node bars and their labels.
class SankeyChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [layout].
  SankeyChartPainter({
    required this.chart,
    required this.layout,
    required this.touchedNode,
    required this.touchedLink,
    required this.animation,
    required this.textCache,
  });

  final SankeyChart chart;
  final SankeyLayout layout;
  final int? touchedNode;
  final int? touchedLink;
  final double animation;
  final TextPainterCache textCache;

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (layout.isEmpty) return;

    final t = animation.clamp(0.0, 1.0);
    final fill = Paint()..isAntiAlias = true;
    final highlighted = touchedNode == null
        ? null
        : layout.nodes[touchedNode!];

    for (final ribbon in layout.links) {
      final dimmed = chart.fadeUntouched &&
          highlighted != null &&
          ribbon.source.index != highlighted.index &&
          ribbon.target.index != highlighted.index;
      final opacity = chart.linkOpacity.clamp(0.0, 1.0) * (dimmed ? 0.25 : 1);
      fill.color = _linkColor(ribbon).withValues(alpha: opacity);
      canvas.drawPath(t >= 1 ? ribbon.path : _grown(ribbon, t), fill);
    }

    for (final box in layout.nodes) {
      fill.color = _nodeColor(box);
      final rect = t >= 1
          ? box.rect
          : Rect.fromLTWH(
              box.rect.left,
              box.rect.top,
              box.rect.width,
              box.rect.height * t,
            );
      canvas.drawRect(rect, fill);
      if (t >= 1 && chart.showLabels) _paintLabel(canvas, size, box);
    }

    final hover = chart.hoverBorder;
    if (hover == null ||
        hover.style == BorderStyle.none ||
        hover.width <= 0 ||
        t < 1) {
      return;
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = hover.width
      ..strokeJoin = StrokeJoin.round
      ..color = hover.color
      ..isAntiAlias = true;
    if (highlighted != null) {
      canvas.drawRect(highlighted.rect, stroke);
    } else if (touchedLink != null && touchedLink! < layout.links.length) {
      canvas.drawPath(layout.links[touchedLink!].path, stroke);
    }
  }

  /// The ribbon as it looks [t] of the way in: grown from the source bar.
  Path _grown(SankeyLinkRibbon ribbon, double t) => SankeyLinkRibbon(
        link: ribbon.link,
        index: ribbon.index,
        source: ribbon.source,
        target: ribbon.target,
        sourceTop: ribbon.sourceTop,
        targetTop: ribbon.targetTop,
        thickness: ribbon.thickness * t,
      ).path;

  Color _nodeColor(SankeyNodeBox box) {
    final own = box.node.color;
    if (own != null) return own;
    final palette = chart.palette;
    if (palette.isEmpty) return const Color(0xFF4C86CD);
    return palette[box.index % palette.length];
  }

  Color _linkColor(SankeyLinkRibbon ribbon) {
    final own = ribbon.link.color;
    if (own != null) return own;
    return Color.lerp(
          _nodeColor(ribbon.source),
          _nodeColor(ribbon.target),
          0.5,
        ) ??
        _nodeColor(ribbon.source);
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

  String? _labelOf(SankeyNodeBox box) {
    final builder = chart.labelBuilder;
    if (builder != null) return builder(box);
    final name = box.node.label ?? box.node.id;
    return '$name  ${_formatValue(box.value)}';
  }

  /// Writes the label to the right of the bar, or to its left when the bar is
  /// in the last column or there is no room on the right.
  void _paintLabel(Canvas canvas, Size size, SankeyNodeBox box) {
    final text = _labelOf(box);
    if (text == null || text.isEmpty) return;
    final style = chart.labelStyle ??
        const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Color(0xDDFFFFFF),
        );
    final tp = textCache.get(text, style);
    var left = box.rect.right + chart.labelGap;
    if (left + tp.width > size.width) {
      left = box.rect.left - chart.labelGap - tp.width;
    }
    if (left < 0) return;
    tp.paint(canvas, Offset(left, box.rect.center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(SankeyChartPainter oldDelegate) =>
      !identical(oldDelegate.chart, chart) ||
      !identical(oldDelegate.layout, layout) ||
      oldDelegate.touchedNode != touchedNode ||
      oldDelegate.touchedLink != touchedLink ||
      oldDelegate.animation != animation;
}
