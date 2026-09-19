import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../corner_radius.dart';
import '../renderer/text_painter_cache.dart';
import '../series/series_axis.dart';
import 'heatmap_data.dart';

/// Which side of the grid an axis's labels sit on.
enum HeatmapAxisSide {
  /// Under the grid, for the columns; to the left of it, for the rows.
  start,

  /// Over the grid, for the columns; to the right of it, for the rows.
  end,
}

/// The labels down one side of a [HeatmapChart].
@immutable
class HeatmapAxis {
  /// Creates an axis.
  const HeatmapAxis({
    this.labels = const [],
    this.labelBuilder,
    this.show = true,
    this.size = 24,
    this.side = HeatmapAxisSide.start,
    this.style,
    this.gap = 4,
    this.interval = 1,
  });

  /// No labels and no room held for them.
  static const hidden = HeatmapAxis(show: false, size: 0);

  /// A label per column or row; a blank one prints nothing.
  final List<String> labels;

  /// Writes the label for a column or row from its index; it wins over
  /// [labels].
  final String? Function(int index)? labelBuilder;

  /// Whether labels are drawn and room is held for them.
  final bool show;

  /// Room held for the labels, across the axis.
  final double size;

  /// Which side of the grid they sit on.
  final HeatmapAxisSide side;

  /// Style of the labels.
  final TextStyle? style;

  /// Space between the grid and the labels.
  final double gap;

  /// Label only every nth column or row.
  final int interval;

  /// The label for [index], or null when there is none.
  String? labelFor(int index) {
    if (!show) return null;
    if (interval > 1 && index % interval != 0) return null;
    final builder = labelBuilder;
    if (builder != null) return builder(index);
    return index >= 0 && index < labels.length ? labels[index] : null;
  }

  /// How much room this axis takes, counting its gap.
  double get room => show ? size + gap : 0;
}

/// Where a heatmap's grid sits, and which square is where.
@immutable
class HeatmapLayout {
  /// Creates the layout of a [rows] by [columns] grid filling [grid].
  const HeatmapLayout({
    required this.grid,
    required this.rows,
    required this.columns,
    this.spacing = 0,
  });

  /// The whole grid, labels excluded.
  final Rect grid;

  /// How many rows it has.
  final int rows;

  /// How many columns it has.
  final int columns;

  /// The gap left between two squares.
  final double spacing;

  /// How wide one column is, gap included.
  double get columnWidth => columns <= 0 ? 0 : grid.width / columns;

  /// How tall one row is, gap included.
  double get rowHeight => rows <= 0 ? 0 : grid.height / rows;

  /// The square at column [x], row [y].
  Rect cellRect(int x, int y) => Rect.fromLTWH(
    grid.left + x * columnWidth,
    grid.top + y * rowHeight,
    columnWidth,
    rowHeight,
  ).deflate(spacing / 2);

  /// The square under [local], or null when it is off the grid.
  (int, int)? cellAt(Offset local) {
    if (columns <= 0 || rows <= 0 || !grid.contains(local)) return null;
    final x = ((local.dx - grid.left) / columnWidth).floor();
    final y = ((local.dy - grid.top) / rowHeight).floor();
    if (x < 0 || x >= columns || y < 0 || y >= rows) return null;
    return (x, y);
  }

  /// The middle of column [x], across the grid.
  double columnCentre(int x) => grid.left + (x + 0.5) * columnWidth;

  /// The middle of row [y], down the grid.
  double rowCentre(int y) => grid.top + (y + 0.5) * rowHeight;
}

/// What a touch on a [HeatmapChart] landed on.
@immutable
class HeatmapTouchDetails {
  /// Creates the details of a touch on the square at ([x], [y]).
  const HeatmapTouchDetails({
    required this.x,
    required this.y,
    required this.cell,
    required this.rect,
  });

  /// The column touched.
  final int x;

  /// The row touched.
  final int y;

  /// The cell there; null when that square has none.
  final HeatmapCell? cell;

  /// The square, in the chart's local pixels.
  final Rect rect;

  /// The value there, or null when the square is empty.
  double? get value => cell?.value;
}

/// A grid of squares coloured by their value — a heatmap.
///
/// It draws what a table of numbers hides: a contribution graph, a
/// correlation matrix, sales by weekday and hour, a risk grid.
///
/// ```dart
/// HeatmapChart(
///   cells: heatmapCellsOf(byHourAndDay),
///   scale: HeatmapGradientScale.of(green),
///   xAxis: const HeatmapAxis(labels: dayNames),
///   yAxis: const HeatmapAxis(labels: hourNames, size: 34),
///   spacing: 3,
///   radius: const BorderRadius.all(Radius.circular(3)),
/// );
/// ```
///
/// The chart fills the box it is given, and is [defaultHeight] high in a box
/// with no height of its own.
class HeatmapChart extends StatefulWidget {
  /// Creates a heatmap of [cells].
  const HeatmapChart({
    super.key,
    required this.cells,
    this.columns,
    this.rows,
    this.scale = const HeatmapGradientScale(
      colors: [Color(0x224C86CD), heatmapDefaultColor],
    ),
    this.minValue,
    this.maxValue,
    this.xAxis = const HeatmapAxis(),
    this.yAxis = const HeatmapAxis(size: 30),
    this.spacing = 2,
    this.radius = const BorderRadius.all(Radius.circular(2)),
    this.squareCells = false,
    this.border,
    this.labelBuilder,
    this.labelStyle,
    this.hoverBorder = const BorderSide(color: Color(0xCCFFFFFF), width: 1.5),
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

  /// Creates a heatmap of [values], a list of rows each holding its columns.
  HeatmapChart.matrix(
    List<List<double?>> values, {
    super.key,
    this.columns,
    this.rows,
    this.scale = const HeatmapGradientScale(
      colors: [Color(0x224C86CD), heatmapDefaultColor],
    ),
    this.minValue,
    this.maxValue,
    this.xAxis = const HeatmapAxis(),
    this.yAxis = const HeatmapAxis(size: 30),
    this.spacing = 2,
    this.radius = const BorderRadius.all(Radius.circular(2)),
    this.squareCells = false,
    this.border,
    this.labelBuilder,
    this.labelStyle,
    this.hoverBorder = const BorderSide(color: Color(0xCCFFFFFF), width: 1.5),
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
  }) : cells = heatmapCellsOf(values);

  /// The squares, in any order; two cells at one position draw the later one.
  final List<HeatmapCell> cells;

  /// How many columns the grid has; null takes the widest cell plus one.
  final int? columns;

  /// How many rows it has; null takes the lowest cell plus one.
  final int? rows;

  /// What turns a value into a colour.
  final HeatmapScale scale;

  /// The value the scale starts at; null takes the lowest cell.
  final double? minValue;

  /// The value it reaches; null takes the highest cell.
  final double? maxValue;

  /// The labels along the columns; [HeatmapAxis.hidden] for none.
  final HeatmapAxis xAxis;

  /// The labels down the rows; [HeatmapAxis.hidden] for none.
  final HeatmapAxis yAxis;

  /// The gap left between two squares.
  final double spacing;

  /// The rounding of each square's corners, as drawn on the screen.
  final BorderRadius radius;

  /// Whether the squares are kept square, which leaves the grid smaller than
  /// the box when the two do not have the same shape.
  final bool squareCells;

  /// An outline round every square.
  final BorderSide? border;

  /// Writes what is printed in a square; [HeatmapCell.label] wins over it.
  final String? Function(HeatmapCell cell)? labelBuilder;

  /// Style of the printed labels; null picks black or white per square, by
  /// how dark the square is.
  final TextStyle? labelStyle;

  /// Drawn round the square under the pointer; null marks none.
  final BorderSide? hoverBorder;

  /// Called as a touch moves over the squares, and with null when it leaves.
  final ValueChanged<HeatmapTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched square; null shows none.
  final Widget? Function(BuildContext context, HeatmapTouchDetails details)?
  tooltipBuilder;

  /// How far the card sits from the square.
  final double tooltipMargin;

  /// How long the squares take to come up to their colour; zero draws them at
  /// once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build fades in.
  final bool animateOnMount;

  /// Space kept clear around the chart, labels included.
  final EdgeInsets padding;

  /// Painted behind the whole chart.
  final Color? backgroundColor;

  /// The height taken in a box that sets none.
  final double defaultHeight;

  /// What a screen reader announces for the chart.
  final String? semanticLabel;

  @override
  State<HeatmapChart> createState() => _HeatmapChartState();
}

class _HeatmapChartState extends State<HeatmapChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 128);
  (int, int)? _touched;

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
  void didUpdateWidget(HeatmapChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (oldWidget.cells.length != widget.cells.length &&
        widget.animationDuration > Duration.zero) {
      _animation.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  /// The cells by position, so a square is looked up rather than searched for.
  Map<(int, int), HeatmapCell> get _byPosition => {
    for (final cell in widget.cells) (cell.x, cell.y): cell,
  };

  int get _columns {
    final given = widget.columns;
    if (given != null) return math.max(0, given);
    var high = -1;
    for (final cell in widget.cells) {
      high = math.max(high, cell.x);
    }
    return high + 1;
  }

  int get _rows {
    final given = widget.rows;
    if (given != null) return math.max(0, given);
    var high = -1;
    for (final cell in widget.cells) {
      high = math.max(high, cell.y);
    }
    return high + 1;
  }

  void _handle(Offset local, HeatmapLayout layout) {
    final at = layout.cellAt(local);
    if (at == _touched) return;
    setState(() => _touched = at);
    final onTouch = widget.onTouch;
    if (onTouch == null) return;
    onTouch(at == null ? null : _detailsAt(at, layout));
  }

  void _leave() {
    if (_touched == null) return;
    setState(() => _touched = null);
    widget.onTouch?.call(null);
  }

  HeatmapTouchDetails _detailsAt((int, int) at, HeatmapLayout layout) {
    final (x, y) = at;
    return HeatmapTouchDetails(
      x: x,
      y: y,
      cell: _byPosition[at],
      rect: layout.cellRect(x, y),
    );
  }

  /// The grid, after the labels have taken their room, and squared off when
  /// that was asked for.
  HeatmapLayout _layout(Size size, int columns, int rows) {
    final box = widget.padding.deflateRect(Offset.zero & size);
    var left = box.left;
    var right = box.right;
    var top = box.top;
    var bottom = box.bottom;

    if (widget.yAxis.side == HeatmapAxisSide.start) {
      left += widget.yAxis.room;
    } else {
      right -= widget.yAxis.room;
    }
    if (widget.xAxis.side == HeatmapAxisSide.start) {
      bottom -= widget.xAxis.room;
    } else {
      top += widget.xAxis.room;
    }

    var grid = Rect.fromLTRB(
      left,
      top,
      math.max(left, right),
      math.max(top, bottom),
    );
    if (widget.squareCells && columns > 0 && rows > 0) {
      final side = math.min(grid.width / columns, grid.height / rows);
      grid = Rect.fromLTWH(grid.left, grid.top, side * columns, side * rows);
    }
    return HeatmapLayout(
      grid: grid,
      rows: rows,
      columns: columns,
      spacing: widget.spacing,
    );
  }

  @override
  Widget build(BuildContext context) {
    final columns = _columns;
    final rows = _rows;
    final cells = _byPosition;
    final (fittedMin, fittedMax) = heatmapValueRange(widget.cells);
    final min = widget.minValue ?? fittedMin;
    final max = widget.maxValue ?? fittedMax;
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
        final layout = _layout(size, columns, rows);

        final touched = _touched;
        final details = touched == null ? null : _detailsAt(touched, layout);
        final builder = widget.tooltipBuilder;
        final tooltip = details == null || builder == null
            ? null
            : builder(context, details);

        return SizedBox(
          width: width,
          height: height,
          child: MouseRegion(
            onHover: (e) => _handle(e.localPosition, layout),
            onExit: (_) => _leave(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _handle(d.localPosition, layout),
              onTapUp: (_) => _leave(),
              onTapCancel: _leave,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: HeatmapChartPainter(
                        chart: widget,
                        layout: layout,
                        cells: cells,
                        minValue: min,
                        maxValue: max,
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
                          delegate: _HeatmapTooltipLayout(
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
}

/// Puts the tooltip above the touched square, kept inside the chart.
class _HeatmapTooltipLayout extends SingleChildLayoutDelegate {
  _HeatmapTooltipLayout({required this.anchor, required this.margin});

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
  bool shouldRelayout(_HeatmapTooltipLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.margin != margin;
}

/// Paints a [HeatmapChart]: the squares, their labels and the axis labels.
class HeatmapChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [layout] says.
  HeatmapChartPainter({
    required this.chart,
    required this.layout,
    required this.cells,
    required this.minValue,
    required this.maxValue,
    required this.touched,
    required this.animation,
    required this.textCache,
  });

  final HeatmapChart chart;
  final HeatmapLayout layout;
  final Map<(int, int), HeatmapCell> cells;
  final double minValue;
  final double maxValue;
  final (int, int)? touched;
  final double animation;
  final TextPainterCache textCache;

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (layout.grid.width <= 0 ||
        layout.grid.height <= 0 ||
        layout.columns <= 0 ||
        layout.rows <= 0) {
      return;
    }

    _paintCells(canvas);
    _paintLabels(canvas, size);
  }

  void _paintCells(Canvas canvas) {
    final side = chart.border;
    final outline =
        side != null && side.style != BorderStyle.none && side.width > 0
        ? (Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = side.width
            ..color = side.color
            ..isAntiAlias = true)
        : null;
    // One path per colour, so a grid of a thousand squares is a handful of
    // draws rather than a thousand.
    final byColor = <Color, Path>{};

    for (var y = 0; y < layout.rows; y++) {
      for (var x = 0; x < layout.columns; x++) {
        final rect = layout.cellRect(x, y);
        if (rect.width <= 0 || rect.height <= 0) continue;
        final shape = roundedBox(rect, chart.radius);
        final color = _colorOf(cells[(x, y)]);
        byColor.putIfAbsent(color, Path.new).addRRect(shape);
        if (outline != null) canvas.drawRRect(shape, outline);
      }
    }
    byColor.forEach((color, path) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..isAntiAlias = true,
      );
    });

    final at = touched;
    final hover = chart.hoverBorder;
    if (at != null &&
        hover != null &&
        hover.style != BorderStyle.none &&
        hover.width > 0) {
      canvas.drawRRect(
        roundedBox(
          layout.cellRect(at.$1, at.$2).deflate(hover.width / 2),
          chart.radius,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = hover.width
          ..color = hover.color
          ..isAntiAlias = true,
      );
    }

    _paintCellLabels(canvas);
  }

  /// The colour of one square, faded towards the empty colour while the chart
  /// is still coming up.
  Color _colorOf(HeatmapCell? cell) {
    final empty = chart.scale.emptyColor;
    if (cell == null || cell.isEmpty) return empty;
    final full =
        cell.color ?? chart.scale.colorAt(cell.value!, minValue, maxValue);
    final t = animation.clamp(0.0, 1.0);
    return t >= 1 ? full : Color.lerp(empty, full, t)!;
  }

  void _paintCellLabels(Canvas canvas) {
    final builder = chart.labelBuilder;
    for (final cell in cells.values) {
      if (cell.x < 0 ||
          cell.x >= layout.columns ||
          cell.y < 0 ||
          cell.y >= layout.rows) {
        continue;
      }
      final text = cell.label ?? (builder == null ? null : builder(cell));
      if (text == null || text.isEmpty) continue;
      final rect = layout.cellRect(cell.x, cell.y);
      // A label that cannot fit is left out rather than drawn over its
      // neighbours.
      final style =
          chart.labelStyle ??
          TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _readableOn(_colorOf(cell)),
          );
      final tp = textCache.get(text, style);
      if (tp.width > rect.width || tp.height > rect.height) continue;
      tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _paintLabels(Canvas canvas, Size size) {
    final grid = layout.grid;
    if (chart.xAxis.show) {
      final style = seriesAxisLabelStyle.merge(chart.xAxis.style);
      for (var x = 0; x < layout.columns; x++) {
        final text = chart.xAxis.labelFor(x);
        if (text == null || text.isEmpty) continue;
        final tp = textCache.get(text, style);
        tp.paint(
          canvas,
          Offset(
            (layout.columnCentre(x) - tp.width / 2).clamp(
              0.0,
              math.max(0.0, size.width - tp.width),
            ),
            chart.xAxis.side == HeatmapAxisSide.start
                ? grid.bottom + chart.xAxis.gap
                : math.max(0.0, grid.top - chart.xAxis.gap - tp.height),
          ),
        );
      }
    }

    if (chart.yAxis.show) {
      final style = seriesAxisLabelStyle.merge(chart.yAxis.style);
      for (var y = 0; y < layout.rows; y++) {
        final text = chart.yAxis.labelFor(y);
        if (text == null || text.isEmpty) continue;
        final tp = textCache.get(text, style);
        tp.paint(
          canvas,
          Offset(
            chart.yAxis.side == HeatmapAxisSide.start
                ? math.max(0.0, grid.left - chart.yAxis.gap - tp.width)
                : grid.right + chart.yAxis.gap,
            (layout.rowCentre(y) - tp.height / 2).clamp(
              0.0,
              math.max(0.0, size.height - tp.height),
            ),
          ),
        );
      }
    }
  }

  /// Black or white, whichever reads on [background].
  static Color _readableOn(Color background) =>
      background.computeLuminance() > 0.5
      ? const Color(0xDD000000)
      : const Color(0xFFFFFFFF);

  @override
  bool shouldRepaint(HeatmapChartPainter oldDelegate) => true;
}

/// The key to a [HeatmapChart]'s colours: the scale as a bar, from the lowest
/// value to the highest.
class HeatmapLegend extends StatelessWidget {
  /// Creates a legend for [scale].
  const HeatmapLegend({
    super.key,
    required this.scale,
    this.low,
    this.high,
    this.labelStyle,
    this.height = 10,
    this.width,
    this.radius = 3,
    this.gap = 6,
  });

  /// The scale it draws.
  final HeatmapScale scale;

  /// What the low end is called; null writes nothing.
  final String? low;

  /// What the high end is called.
  final String? high;

  /// Style of [low] and [high].
  final TextStyle? labelStyle;

  /// How thick the bar is.
  final double height;

  /// How long the bar is; null lets it take the room it is given.
  final double? width;

  /// The bar's corner radius.
  final double radius;

  /// Space between the bar and its labels.
  final double gap;

  @override
  Widget build(BuildContext context) {
    final style = seriesAxisLabelStyle
        .copyWith(decoration: TextDecoration.none)
        .merge(labelStyle);
    final colors = scale.colors;
    Widget bar = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        // One colour would make a gradient of nothing, so it is doubled.
        gradient: LinearGradient(
          colors: colors.length >= 2
              ? colors
              : [
                  ...colors,
                  ...colors,
                  if (colors.isEmpty) ...[
                    heatmapEmptyColor,
                    heatmapDefaultColor,
                  ],
                ],
        ),
      ),
      child: SizedBox(height: height, width: width),
    );
    // Without a width the bar takes the room it is given, which only works in
    // a row that is allowed to fill it.
    final fills = width == null;
    if (fills) bar = Expanded(child: bar);

    return Row(
      mainAxisSize: fills ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (low != null) ...[Text(low!, style: style), SizedBox(width: gap)],
        bar,
        if (high != null) ...[SizedBox(width: gap), Text(high!, style: style)],
      ],
    );
  }
}
