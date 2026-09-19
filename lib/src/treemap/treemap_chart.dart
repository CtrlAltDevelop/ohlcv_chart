import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../heatmap/heatmap_data.dart';
import '../renderer/text_painter_cache.dart';
import 'treemap_data.dart';

/// What a touch on a [TreemapChart] landed on.
@immutable
class TreemapTouchDetails {
  /// Creates the details of a touch on [tile].
  const TreemapTouchDetails({required this.tile});

  /// The leaf touched.
  final TreemapTile tile;

  /// The item it draws.
  TreemapItem get item => tile.item;

  /// The tile, in the chart's local pixels.
  Rect get rect => tile.rect;
}

/// Rectangles sized by their value — a treemap.
///
/// It shows how a whole divides up: a market map of stocks sized by market cap
/// and coloured by the day's move, a portfolio by holding, a budget by line.
///
/// ```dart
/// TreemapChart(
///   items: [
///     TreemapItem.group(label: 'Tech', children: [
///       TreemapItem(value: 3400, label: 'AAPL', colorValue: 1.8),
///       TreemapItem(value: 3100, label: 'MSFT', colorValue: -0.6),
///     ]),
///     TreemapItem(value: 900, label: 'Cash'),
///   ],
///   scale: const HeatmapGradientScale(
///     colors: [Color(0xFFE03131), Color(0xFF343A40), Color(0xFF2F9E44)],
///   ),
///   minColorValue: -3,
///   maxColorValue: 3,
/// );
/// ```
///
/// The chart fills the box it is given, and is [defaultHeight] high in a box
/// with no height of its own.
class TreemapChart extends StatefulWidget {
  /// Creates a treemap of [items].
  const TreemapChart({
    super.key,
    required this.items,
    this.scale,
    this.minColorValue,
    this.maxColorValue,
    this.palette = treemapPalette,
    this.spacing = 2,
    this.radius = 2,
    this.sort = true,
    this.groupHeaderHeight = 18,
    this.groupColor,
    this.groupLabelStyle,
    this.labelBuilder,
    this.labelStyle,
    this.labelAlignment = Alignment.center,
    this.labelPadding = const EdgeInsets.all(4),
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

  /// The items, leaves and groups alike.
  final List<TreemapItem> items;

  /// Colours a leaf by its [TreemapItem.colorValue]; null colours by
  /// [palette] instead.
  final HeatmapScale? scale;

  /// The colour value the scale starts at; null takes the lowest leaf.
  final double? minColorValue;

  /// The colour value it reaches; null takes the highest leaf.
  final double? maxColorValue;

  /// Colours taken in turn by the top-level items, and inherited by everything
  /// inside them, when neither an item's colour nor the scale decides.
  final List<Color> palette;

  /// The gap left between two tiles.
  final double spacing;

  /// The corner radius of a tile.
  final double radius;

  /// Whether the largest items are placed first, which gives the squarest
  /// tiles; off keeps the order given.
  final bool sort;

  /// The strip held at the top of a group for its label; 0 holds none.
  final double groupHeaderHeight;

  /// Painted behind a group; null takes a dark wash.
  final Color? groupColor;

  /// Style of a group's label.
  final TextStyle? groupLabelStyle;

  /// Writes what is printed on a leaf; null prints its [TreemapItem.label].
  /// Line breaks are kept, so a second line can carry the value.
  final String? Function(TreemapTile tile)? labelBuilder;

  /// Style of the printed labels; null picks black or white per tile, by how
  /// dark the tile is.
  final TextStyle? labelStyle;

  /// Where a label sits inside its tile.
  final Alignment labelAlignment;

  /// Room kept between a label and the edge of its tile.
  final EdgeInsets labelPadding;

  /// Drawn round the leaf under the pointer; null marks none.
  final BorderSide? hoverBorder;

  /// Called as a touch moves over the leaves, and with null when it leaves.
  final ValueChanged<TreemapTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched leaf; null shows none.
  final Widget? Function(BuildContext context, TreemapTouchDetails details)?
  tooltipBuilder;

  /// How far the card sits from the tile.
  final double tooltipMargin;

  /// How long the tiles take to grow into place; zero draws them at once.
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
  State<TreemapChart> createState() => _TreemapChartState();
}

class _TreemapChartState extends State<TreemapChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 256);
  TreemapTile? _touched;

  /// The last layout, kept while neither the items nor the size change: the
  /// squarified layout walks every item, and a hover should not redo it.
  List<TreemapTile> _tiles = const [];
  Object? _laidOutFrom;

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
  void didUpdateWidget(TreemapChart oldWidget) {
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

  List<TreemapTile> _layout(Size size) {
    final key = (
      widget.items,
      size,
      widget.padding,
      widget.spacing,
      widget.groupHeaderHeight,
      widget.sort,
    );
    if (key != _laidOutFrom) {
      _tiles = layOutTreemap(
        widget.items,
        widget.padding.deflateRect(Offset.zero & size),
        spacing: widget.spacing,
        groupHeaderHeight: widget.groupHeaderHeight,
        sort: widget.sort,
      );
      _laidOutFrom = key;
    }
    return _tiles;
  }

  void _handle(Offset local) {
    final tile = treemapTileAt(_tiles, local);
    if (identical(tile, _touched)) return;
    setState(() => _touched = tile);
    widget.onTouch?.call(tile == null ? null : TreemapTouchDetails(tile: tile));
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
        final tiles = _layout(size);

        final touched = _touched;
        final details = touched == null
            ? null
            : TreemapTouchDetails(tile: touched);
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
                      painter: TreemapChartPainter(
                        chart: widget,
                        tiles: tiles,
                        colorRange: _colorRange(),
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
                          delegate: _TreemapTooltipLayout(
                            anchor: details.rect,
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

  /// The range the scale is spread over.
  (double, double) _colorRange() {
    var low = double.infinity;
    var high = double.negativeInfinity;
    void visit(List<TreemapItem> items) {
      for (final item in items) {
        if (item.isGroup) {
          visit(item.children);
          continue;
        }
        final v = item.colorValue;
        if (v == null || !v.isFinite) continue;
        low = math.min(low, v);
        high = math.max(high, v);
      }
    }

    if (widget.minColorValue == null || widget.maxColorValue == null) {
      visit(widget.items);
    }
    final min = widget.minColorValue ?? (low.isFinite ? low : 0.0);
    final max = widget.maxColorValue ?? (high.isFinite ? high : 0.0);
    return (min, max);
  }
}

/// Puts the tooltip above the touched tile, kept inside the chart.
class _TreemapTooltipLayout extends SingleChildLayoutDelegate {
  _TreemapTooltipLayout({required this.anchor, required this.margin});

  final Rect anchor;
  final double margin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var top = anchor.top - margin - childSize.height;
    if (top < 0) top = anchor.bottom + margin;
    return Offset(
      (anchor.center.dx - childSize.width / 2).clamp(
        0.0,
        math.max(0.0, size.width - childSize.width),
      ),
      top.clamp(0.0, math.max(0.0, size.height - childSize.height)),
    );
  }

  @override
  bool shouldRelayout(_TreemapTooltipLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.margin != margin;
}

/// Paints a [TreemapChart]: the groups, the leaves and their labels.
class TreemapChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [tiles].
  TreemapChartPainter({
    required this.chart,
    required this.tiles,
    required this.colorRange,
    required this.touched,
    required this.animation,
    required this.textCache,
  });

  final TreemapChart chart;
  final List<TreemapTile> tiles;
  final (double, double) colorRange;
  final TreemapTile? touched;
  final double animation;
  final TextPainterCache textCache;

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (tiles.isEmpty) return;

    final t = animation.clamp(0.0, 1.0);
    final radius = Radius.circular(chart.radius);
    final fill = Paint()..isAntiAlias = true;

    for (final tile in tiles) {
      final rect = _grown(tile.rect, t);
      if (rect.width <= 0 || rect.height <= 0) continue;
      final shape = RRect.fromRectAndRadius(rect, radius);

      if (tile.item.isGroup) {
        fill.color =
            tile.item.color ?? chart.groupColor ?? const Color(0x33000000);
        canvas.drawRRect(shape, fill);
        _paintGroupLabel(canvas, tile, t);
        continue;
      }

      fill.color = _colorOf(tile);
      canvas.drawRRect(shape, fill);
      _paintLeafLabel(canvas, tile, rect);
    }

    final hover = chart.hoverBorder;
    final at = touched;
    if (at != null &&
        hover != null &&
        hover.style != BorderStyle.none &&
        hover.width > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(at.rect.deflate(hover.width / 2), radius),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = hover.width
          ..color = hover.color
          ..isAntiAlias = true,
      );
    }
  }

  /// [rect] scaled about its centre by [t], for the tiles growing in.
  static Rect _grown(Rect rect, double t) => t >= 1
      ? rect
      : Rect.fromCenter(
          center: rect.center,
          width: rect.width * t,
          height: rect.height * t,
        );

  /// The colour of a leaf: its own, then the scale's, then its root's turn in
  /// the palette.
  Color _colorOf(TreemapTile tile) {
    final item = tile.item;
    final own = item.color;
    if (own != null) return own;

    final scale = chart.scale;
    final v = item.colorValue;
    if (scale != null) {
      if (v == null || !v.isFinite) return scale.emptyColor;
      return scale.colorAt(v, colorRange.$1, colorRange.$2);
    }

    // Inherit the nearest colour a group names, then the palette by root.
    for (var parent = tile.parent; parent != null; parent = parent.parent) {
      final color = parent.item.color;
      if (color != null) return color;
    }
    final palette = chart.palette;
    if (palette.isEmpty) return heatmapDefaultColor;
    return palette[tile.root.index % palette.length];
  }

  void _paintGroupLabel(Canvas canvas, TreemapTile tile, double t) {
    final header = tile.headerRect;
    final text = tile.item.label;
    if (header == null || text == null || text.isEmpty || t < 1) return;
    final style = const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: Color(0xFFE9ECEF),
    ).merge(chart.groupLabelStyle);
    final tp = textCache.get(text, style);
    final room = header.deflate(4);
    if (tp.width > room.width || tp.height > header.height) return;
    tp.paint(canvas, Offset(room.left, header.center.dy - tp.height / 2));
  }

  void _paintLeafLabel(Canvas canvas, TreemapTile tile, Rect rect) {
    final builder = chart.labelBuilder;
    final text = builder == null ? tile.item.label : builder(tile);
    if (text == null || text.isEmpty) return;

    final room = chart.labelPadding.deflateRect(rect);
    if (room.width <= 0 || room.height <= 0) return;

    final style =
        chart.labelStyle ??
        TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _readableOn(_colorOf(tile)),
        );
    final tp = textCache.get(text, style);
    // A label that cannot fit is left out rather than spilling into the next
    // tile.
    if (tp.width > room.width || tp.height > room.height) return;
    final offset = chart.labelAlignment.inscribe(tp.size, room).topLeft;
    tp.paint(canvas, offset);
  }

  /// Black or white, whichever reads on [background].
  static Color _readableOn(Color background) =>
      background.computeLuminance() > 0.5
      ? const Color(0xDD000000)
      : const Color(0xFFFFFFFF);

  @override
  bool shouldRepaint(TreemapChartPainter oldDelegate) =>
      !identical(oldDelegate.chart, chart) ||
      !identical(oldDelegate.tiles, tiles) ||
      oldDelegate.colorRange != colorRange ||
      !identical(oldDelegate.touched, touched) ||
      oldDelegate.animation != animation;
}
