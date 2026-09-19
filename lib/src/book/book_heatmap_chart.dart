import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';
import '../series/series_axis.dart';

/// Which side of the book a resting order sits on.
enum BookSide {
  /// Waiting to buy.
  bid,

  /// Waiting to sell.
  ask,
}

/// How much was resting at one price at one moment.
@immutable
class BookLevel {
  /// Creates the level at [price].
  const BookLevel({
    required this.price,
    required this.size,
    required this.side,
    this.data,
  });

  /// The price the orders rest at.
  final double price;

  /// How much rests there.
  final double size;

  /// Which side of the book it is.
  final BookSide side;

  /// Anything the app wants back when this level is touched.
  final Object? data;
}

/// The book at one moment.
@immutable
class BookSnapshot {
  /// Creates the book as it stood at [time].
  const BookSnapshot({
    required this.time,
    required this.levels,
    this.mid,
    this.data,
  });

  /// When the book looked like this.
  final DateTime time;

  /// What was resting, either side.
  final List<BookLevel> levels;

  /// Where the market was; null draws no line for this column.
  final double? mid;

  /// Anything the app wants back when this column is touched.
  final Object? data;
}

/// Where one [BookLevel] was laid out.
@immutable
class BookHeatmapCell {
  /// Creates the cell of [level].
  const BookHeatmapCell({
    required this.level,
    required this.snapshot,
    required this.columnIndex,
    required this.rect,
  });

  /// The level this cell draws.
  final BookLevel level;

  /// The moment it belongs to.
  final BookSnapshot snapshot;

  /// Which column that is, from the left.
  final int columnIndex;

  /// The cell.
  final Rect rect;

  /// Whether [local] is inside it.
  bool contains(Offset local) => rect.contains(local);
}

/// One moment's cells.
@immutable
class BookHeatmapColumn {
  /// Creates the column of [snapshot].
  const BookHeatmapColumn({
    required this.snapshot,
    required this.index,
    required this.rect,
    required this.cells,
    required this.midY,
  });

  /// The moment this column draws.
  final BookSnapshot snapshot;

  /// Its position from the left.
  final int index;

  /// The whole column.
  final Rect rect;

  /// The cells in it.
  final List<BookHeatmapCell> cells;

  /// Where the mid price sits; null when the snapshot gave none.
  final double? midY;
}

/// The book over time, placed inside a box.
@immutable
class BookHeatmapLayout {
  /// Creates a layout of [columns].
  const BookHeatmapLayout({
    required this.plot,
    required this.columns,
    required this.minPrice,
    required this.maxPrice,
    required this.tickSize,
    required this.rowHeight,
    required this.largestSize,
  });

  /// Nothing laid out.
  static const BookHeatmapLayout empty = BookHeatmapLayout(
    plot: Rect.zero,
    columns: [],
    minPrice: 0,
    maxPrice: 1,
    tickSize: 1,
    rowHeight: 0,
    largestSize: 0,
  );

  /// The box the book is drawn in.
  final Rect plot;

  /// The moments, left to right.
  final List<BookHeatmapColumn> columns;

  /// The lowest price drawn.
  final double minPrice;

  /// The highest.
  final double maxPrice;

  /// How far apart two price levels are.
  final double tickSize;

  /// How tall one level's row is.
  final double rowHeight;

  /// The most resting at any one level — what the colouring is read against.
  final double largestSize;

  /// Whether nothing was laid out.
  bool get isEmpty => columns.isEmpty;

  /// Where [price] sits up the plot.
  double yOf(double price) => maxPrice == minPrice
      ? plot.center.dy
      : plot.bottom - (price - minPrice) / (maxPrice - minPrice) * plot.height;

  /// The price at [dy].
  double priceAt(double dy) => plot.height <= 0
      ? minPrice
      : maxPrice -
            ((dy - plot.top) / plot.height).clamp(0.0, 1.0) *
                (maxPrice - minPrice);
}

/// The price range [snapshots] cover.
({double min, double max}) bookPriceRange(List<BookSnapshot> snapshots) {
  var min = double.infinity;
  var max = double.negativeInfinity;
  for (final snapshot in snapshots) {
    for (final level in snapshot.levels) {
      if (!level.price.isFinite) continue;
      min = math.min(min, level.price);
      max = math.max(max, level.price);
    }
  }
  if (!min.isFinite || !max.isFinite) return (min: 0, max: 1);
  if (min == max) return (min: min - 1, max: max + 1);
  return (min: min, max: max);
}

/// Places [snapshots] across [bounds], one column each, priced up the side.
///
/// Rows are [tickSize] apart, so a level is in the same place in every column.
/// The largest resting size found is reported, and is what the chart shades
/// against — one loud level cannot be judged except against the rest.
BookHeatmapLayout layOutBookHeatmap(
  List<BookSnapshot> snapshots,
  Rect bounds, {
  required double tickSize,
  double? minPrice,
  double? maxPrice,
  double? largestSize,
}) {
  if (snapshots.isEmpty ||
      bounds.width <= 0 ||
      bounds.height <= 0 ||
      !tickSize.isFinite ||
      tickSize <= 0) {
    return BookHeatmapLayout.empty;
  }

  final range = bookPriceRange(snapshots);
  var low = minPrice ?? range.min - tickSize / 2;
  var high = maxPrice ?? range.max + tickSize / 2;
  if (high <= low) {
    low -= tickSize;
    high += tickSize;
  }

  final frame = BookHeatmapLayout(
    plot: bounds,
    columns: const [],
    minPrice: low,
    maxPrice: high,
    tickSize: tickSize,
    rowHeight: bounds.height * tickSize / (high - low),
    largestSize: 0,
  );

  final width = bounds.width / snapshots.length;
  var largest = largestSize ?? 0;

  final columns = <BookHeatmapColumn>[];
  for (var i = 0; i < snapshots.length; i++) {
    final snapshot = snapshots[i];
    final left = bounds.left + i * width;
    final cells = <BookHeatmapCell>[];
    for (final level in snapshot.levels) {
      if (!level.price.isFinite || !level.size.isFinite) continue;
      if (largestSize == null) largest = math.max(largest, level.size);
      final centre = frame.yOf(level.price);
      cells.add(
        BookHeatmapCell(
          level: level,
          snapshot: snapshot,
          columnIndex: i,
          rect: Rect.fromLTWH(
            left,
            centre - frame.rowHeight / 2,
            width,
            frame.rowHeight,
          ),
        ),
      );
    }
    columns.add(
      BookHeatmapColumn(
        snapshot: snapshot,
        index: i,
        rect: Rect.fromLTWH(left, bounds.top, width, bounds.height),
        cells: cells,
        midY: snapshot.mid == null ? null : frame.yOf(snapshot.mid!),
      ),
    );
  }

  return BookHeatmapLayout(
    plot: bounds,
    columns: columns,
    minPrice: low,
    maxPrice: high,
    tickSize: tickSize,
    rowHeight: frame.rowHeight,
    largestSize: largest,
  );
}

/// The cell under [local], or null when there is none.
BookHeatmapCell? bookHeatmapCellAt(BookHeatmapLayout layout, Offset local) {
  for (final column in layout.columns) {
    if (!column.rect.contains(local)) continue;
    for (final cell in column.cells) {
      if (cell.contains(local)) return cell;
    }
    return null;
  }
  return null;
}

/// What a touch on a [BookHeatmapChart] landed on.
@immutable
class BookHeatmapTouchDetails {
  /// Creates the details of a touch at [price] in [column].
  const BookHeatmapTouchDetails({
    required this.price,
    required this.column,
    required this.cell,
    required this.at,
  });

  /// The price under the pointer.
  final double price;

  /// The moment under it.
  final BookHeatmapColumn column;

  /// The level there, or null when nothing rested at that price.
  final BookHeatmapCell? cell;

  /// Where the pointer was, in the chart's local pixels.
  final Offset at;

  /// The moment the column draws.
  BookSnapshot get snapshot => column.snapshot;
}

/// Resting liquidity over time — the order-book heatmap crypto desks read.
///
/// Every column is one snapshot of the book; every row is a price. The brighter
/// a cell, the more was resting there, so walls show up as bright lines running
/// across time.
///
/// ```dart
/// BookHeatmapChart(
///   snapshots: snapshots,
///   tickSize: 0.5,
/// );
/// ```
///
/// The chart fills the box it is given, and is [defaultHeight] high in a box
/// with no height of its own.
class BookHeatmapChart extends StatefulWidget {
  /// Creates a heatmap of [snapshots].
  const BookHeatmapChart({
    super.key,
    required this.snapshots,
    required this.tickSize,
    this.minPrice,
    this.maxPrice,
    this.largestSize,
    this.bidColor = const Color(0xFF2F9E44),
    this.askColor = const Color(0xFFE03131),
    this.minOpacity = 0.05,
    this.maxOpacity = 1,
    this.gamma = 0.5,
    this.showMid = true,
    this.midColor = const Color(0xCCFFFFFF),
    this.midWidth = 1.5,
    this.showPriceAxis = true,
    this.axisWidth = 56,
    this.priceLabelEvery = 5,
    this.priceFormatter,
    this.axisLabelStyle,
    this.crosshairColor = const Color(0x66FFFFFF),
    this.onTouch,
    this.tooltipBuilder,
    this.tooltipMargin = 10,
    this.padding = EdgeInsets.zero,
    this.backgroundColor = const Color(0xFF0E0E10),
    this.defaultHeight = 320,
    this.semanticLabel,
  });

  /// The snapshots, oldest first.
  final List<BookSnapshot> snapshots;

  /// How far apart two price levels are.
  final double tickSize;

  /// The lowest price drawn; null reads it off the snapshots.
  final double? minPrice;

  /// The highest; null reads it off the snapshots.
  final double? maxPrice;

  /// What the brightest cell is worth; null takes the largest level seen.
  final double? largestSize;

  /// The colour of resting bids.
  final Color bidColor;

  /// The colour of resting offers.
  final Color askColor;

  /// How visible the quietest level is.
  final double minOpacity;

  /// How visible the loudest is.
  final double maxOpacity;

  /// How the sizes are spread over that range: below 1 lifts the quiet levels,
  /// which is what makes a book with one huge wall still readable.
  final double gamma;

  /// Whether the mid price is drawn across the columns that carry one.
  final bool showMid;

  /// The colour of that line.
  final Color midColor;

  /// How thick it is.
  final double midWidth;

  /// Whether prices are written down the left.
  final bool showPriceAxis;

  /// How much room the price axis takes.
  final double axisWidth;

  /// One price is written every this many levels.
  final int priceLabelEvery;

  /// Writes a price; null writes at most two decimals.
  final String Function(double price)? priceFormatter;

  /// Style of a price label.
  final TextStyle? axisLabelStyle;

  /// Colour of the crosshair; null draws none.
  final Color? crosshairColor;

  /// Called as a touch moves over the book, and with null when it leaves.
  final ValueChanged<BookHeatmapTouchDetails?>? onTouch;

  /// Builds a card shown beside the pointer; null shows none.
  final Widget? Function(BuildContext context, BookHeatmapTouchDetails details)?
  tooltipBuilder;

  /// How far the card sits from the pointer.
  final double tooltipMargin;

  /// Space kept clear around the chart.
  final EdgeInsets padding;

  /// Painted behind the whole chart; a dark ground is what makes the bright
  /// levels read.
  final Color? backgroundColor;

  /// The height taken in a box that sets none.
  final double defaultHeight;

  /// What a screen reader announces for the chart.
  final String? semanticLabel;

  @override
  State<BookHeatmapChart> createState() => _BookHeatmapChartState();
}

class _BookHeatmapChartState extends State<BookHeatmapChart> {
  final TextPainterCache _text = TextPainterCache(capacity: 64);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  BookHeatmapLayout _layout = BookHeatmapLayout.empty;
  Offset? _pointer;

  void _handle(Offset local) {
    if (_layout.isEmpty || !_layout.plot.contains(local)) {
      _leave();
      return;
    }
    if (local == _pointer) return;
    setState(() => _pointer = local);
    widget.onTouch?.call(_detailsAt(local));
  }

  BookHeatmapTouchDetails? _detailsAt(Offset local) {
    for (final column in _layout.columns) {
      if (!column.rect.contains(local)) continue;
      BookHeatmapCell? found;
      for (final cell in column.cells) {
        if (cell.contains(local)) {
          found = cell;
          break;
        }
      }
      return BookHeatmapTouchDetails(
        price: found?.level.price ?? _layout.priceAt(local.dy),
        column: column,
        cell: found,
        at: local,
      );
    }
    return null;
  }

  void _leave() {
    if (_pointer == null) return;
    setState(() => _pointer = null);
    widget.onTouch?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
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
          box.left + (widget.showPriceAxis ? widget.axisWidth : 0),
          box.top,
          box.right,
          box.bottom,
        );
        _layout = layOutBookHeatmap(
          widget.snapshots,
          plot,
          tickSize: widget.tickSize,
          minPrice: widget.minPrice,
          maxPrice: widget.maxPrice,
          largestSize: widget.largestSize,
        );

        final pointer = _pointer;
        final details = pointer == null ? null : _detailsAt(pointer);
        final builder = widget.tooltipBuilder;
        final tooltip = details == null || builder == null
            ? null
            : builder(context, details);

        Widget chart = SizedBox(
          width: width,
          height: height,
          child: MouseRegion(
            onHover: (e) => _handle(e.localPosition),
            onExit: (_) => _leave(),
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
                      painter: BookHeatmapChartPainter(
                        chart: widget,
                        layout: _layout,
                        pointer: pointer,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (tooltip != null && details != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomSingleChildLayout(
                          delegate: _BookTooltipLayout(
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

        final label = widget.semanticLabel;
        if (label != null) {
          chart = Semantics(container: true, label: label, child: chart);
        }
        return chart;
      },
    );
  }
}

/// Puts the tooltip beside the pointer, kept inside the chart.
class _BookTooltipLayout extends SingleChildLayoutDelegate {
  _BookTooltipLayout({required this.anchor, required this.margin});

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
      (anchor.dy - childSize.height / 2).clamp(
        0.0,
        math.max(0.0, size.height - childSize.height),
      ),
    );
  }

  @override
  bool shouldRelayout(_BookTooltipLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.margin != margin;
}

/// Paints a [BookHeatmapChart]: the cells, the mid line and the prices.
class BookHeatmapChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [layout].
  BookHeatmapChartPainter({
    required this.chart,
    required this.layout,
    required this.pointer,
    required this.textCache,
  });

  final BookHeatmapChart chart;
  final BookHeatmapLayout layout;
  final Offset? pointer;
  final TextPainterCache textCache;

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (layout.isEmpty) return;

    final fill = Paint()..isAntiAlias = false;
    for (final column in layout.columns) {
      for (final cell in column.cells) {
        if (cell.rect.height <= 0 || cell.rect.width <= 0) continue;
        fill.color = _colorOf(cell.level.size, cell.level.side);
        canvas.drawRect(cell.rect, fill);
      }
    }

    if (chart.showMid) _paintMid(canvas);
    _paintPrices(canvas);
    _paintCrosshair(canvas);
  }

  /// A level's colour: its side, faded by how much rests there against the
  /// largest level, with [BookHeatmapChart.gamma] lifting the quiet ones.
  Color _colorOf(double size, BookSide side) {
    final largest = layout.largestSize;
    final share = largest <= 0 ? 0.0 : (size / largest).clamp(0.0, 1.0);
    final curve = chart.gamma <= 0 ? share : math.pow(share, chart.gamma);
    final low = chart.minOpacity.clamp(0.0, 1.0);
    final high = chart.maxOpacity.clamp(0.0, 1.0);
    final alpha = (low + (high - low) * curve).clamp(0.0, 1.0);
    final color = side == BookSide.bid ? chart.bidColor : chart.askColor;
    return color.withValues(alpha: alpha.toDouble());
  }

  void _paintMid(Canvas canvas) {
    final pen = Paint()
      ..color = chart.midColor
      ..strokeWidth = chart.midWidth
      ..isAntiAlias = true;
    Offset? previous;
    for (final column in layout.columns) {
      final y = column.midY;
      if (y == null) {
        previous = null;
        continue;
      }
      final at = Offset(column.rect.center.dx, y);
      if (previous != null) canvas.drawLine(previous, at, pen);
      previous = at;
    }
  }

  void _paintPrices(Canvas canvas) {
    if (!chart.showPriceAxis || layout.rowHeight <= 0) return;
    final steps = ((layout.maxPrice - layout.minPrice) / layout.tickSize)
        .floor();
    if (steps <= 0 || steps > 2000) return;
    final every = math.max(1, chart.priceLabelEvery);
    final style = seriesAxisLabelStyle.merge(chart.axisLabelStyle);
    for (var i = 0; i <= steps; i += every) {
      final price = layout.minPrice + i * layout.tickSize;
      final tp = textCache.get(_formatPrice(price), style);
      final left = layout.plot.left - 6 - tp.width;
      if (left < 0) continue;
      tp.paint(canvas, Offset(left, layout.yOf(price) - tp.height / 2));
    }
  }

  void _paintCrosshair(Canvas canvas) {
    final at = pointer;
    final color = chart.crosshairColor;
    if (at == null || color == null) return;
    final pen = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas
      ..drawLine(
        Offset(layout.plot.left, at.dy),
        Offset(layout.plot.right, at.dy),
        pen,
      )
      ..drawLine(
        Offset(at.dx, layout.plot.top),
        Offset(at.dx, layout.plot.bottom),
        pen,
      );
  }

  String _formatPrice(double price) {
    final format = chart.priceFormatter;
    if (format != null) return format(price);
    final rounded = double.parse(price.toStringAsFixed(2));
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toString();
  }

  @override
  bool shouldRepaint(BookHeatmapChartPainter oldDelegate) =>
      !identical(oldDelegate.chart, chart) ||
      !identical(oldDelegate.layout, layout) ||
      oldDelegate.pointer != pointer;
}
