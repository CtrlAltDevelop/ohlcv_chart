import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';
import '../series/series_axis.dart';

/// What traded at one price inside one bar: how much lifted the offer and how
/// much hit the bid.
@immutable
class FootprintLevel {
  /// Creates the level at [price].
  const FootprintLevel({
    required this.price,
    this.bidVolume = 0,
    this.askVolume = 0,
    this.data,
  });

  /// The price this traded at.
  final double price;

  /// What was sold into the bid.
  final double bidVolume;

  /// What was bought from the offer.
  final double askVolume;

  /// Anything the app wants back when this level is touched.
  final Object? data;

  /// Everything that traded here.
  double get total => bidVolume + askVolume;

  /// Buying less selling: positive when the offer was being lifted.
  double get delta => askVolume - bidVolume;

  /// How lopsided the level was, from -1 (all selling) to 1 (all buying).
  double get imbalance => total <= 0 ? 0 : delta / total;
}

/// One bar of a [FootprintChart]: a candle and what traded inside it.
@immutable
class FootprintBar {
  /// Creates the bar covering [time].
  const FootprintBar({
    required this.time,
    required this.levels,
    this.open,
    this.high,
    this.low,
    this.close,
    this.data,
  });

  /// When the bar began.
  final DateTime time;

  /// What traded inside it, one entry per price.
  final List<FootprintLevel> levels;

  /// The candle's open; null draws no candle outline.
  final double? open;

  /// Its high; null takes the highest level.
  final double? high;

  /// Its low; null takes the lowest level.
  final double? low;

  /// Its close; null draws no candle outline.
  final double? close;

  /// Anything the app wants back when this bar is touched.
  final Object? data;

  /// Everything that traded in the bar.
  double get volume {
    var total = 0.0;
    for (final level in levels) {
      total += level.total;
    }
    return total;
  }

  /// Buying less selling across the whole bar.
  double get delta {
    var total = 0.0;
    for (final level in levels) {
      total += level.delta;
    }
    return total;
  }

  /// The price that traded most, or null when nothing did.
  double? get pointOfControl {
    FootprintLevel? busiest;
    for (final level in levels) {
      if (busiest == null || level.total > busiest.total) busiest = level;
    }
    return busiest?.price;
  }

  /// The highest price drawn: the candle's high, or the top level.
  double get top {
    var value = high ?? double.negativeInfinity;
    for (final level in levels) {
      value = math.max(value, level.price);
    }
    return value;
  }

  /// The lowest price drawn.
  double get bottom {
    var value = low ?? double.infinity;
    for (final level in levels) {
      value = math.min(value, level.price);
    }
    return value;
  }
}

/// The running total of [bars]' deltas — the cumulative delta.
List<double> footprintCumulativeDelta(List<FootprintBar> bars) {
  var running = 0.0;
  return [
    for (final bar in bars)
      () {
        final delta = bar.delta;
        if (delta.isFinite) running += delta;
        return running;
      }(),
  ];
}

/// The price range [bars] cover.
({double min, double max}) footprintPriceRange(List<FootprintBar> bars) {
  var min = double.infinity;
  var max = double.negativeInfinity;
  for (final bar in bars) {
    final top = bar.top;
    final bottom = bar.bottom;
    if (top.isFinite) max = math.max(max, top);
    if (bottom.isFinite) min = math.min(min, bottom);
  }
  if (!min.isFinite || !max.isFinite) return (min: 0, max: 1);
  if (min == max) return (min: min - 1, max: max + 1);
  return (min: min, max: max);
}

/// Where one [FootprintLevel] was laid out.
@immutable
class FootprintCell {
  /// Creates the cell of [level].
  const FootprintCell({
    required this.level,
    required this.bar,
    required this.barIndex,
    required this.rect,
  });

  /// The level this cell draws.
  final FootprintLevel level;

  /// The bar it belongs to.
  final FootprintBar bar;

  /// Which bar that is, from the left.
  final int barIndex;

  /// The cell, holding both numbers side by side.
  final Rect rect;

  /// The half of the cell the bid volume is written in.
  Rect get bidRect => Rect.fromLTRB(
        rect.left,
        rect.top,
        rect.center.dx,
        rect.bottom,
      );

  /// The half the ask volume is written in.
  Rect get askRect => Rect.fromLTRB(
        rect.center.dx,
        rect.top,
        rect.right,
        rect.bottom,
      );

  /// Whether [local] is inside the cell.
  bool contains(Offset local) => rect.contains(local);
}

/// Where one [FootprintBar] was laid out.
@immutable
class FootprintColumn {
  /// Creates the column of [bar].
  const FootprintColumn({
    required this.bar,
    required this.index,
    required this.rect,
    required this.cells,
    required this.openY,
    required this.closeY,
    required this.highY,
    required this.lowY,
  });

  /// The bar this column draws.
  final FootprintBar bar;

  /// Its position from the left.
  final int index;

  /// The whole column; what a touch is tested against.
  final Rect rect;

  /// The cells inside it, in the order the levels were given.
  final List<FootprintCell> cells;

  /// Where the candle's open sits; null when it has none.
  final double? openY;

  /// Where its close sits; null when it has none.
  final double? closeY;

  /// Where its high sits.
  final double highY;

  /// Where its low sits.
  final double lowY;
}

/// The columns and their cells, placed inside a box.
@immutable
class FootprintLayout {
  /// Creates a layout of [columns].
  const FootprintLayout({
    required this.plot,
    required this.columns,
    required this.minPrice,
    required this.maxPrice,
    required this.tickSize,
    required this.rowHeight,
    required this.largestVolume,
  });

  /// Nothing laid out.
  static const FootprintLayout empty = FootprintLayout(
    plot: Rect.zero,
    columns: [],
    minPrice: 0,
    maxPrice: 1,
    tickSize: 1,
    rowHeight: 0,
    largestVolume: 0,
  );

  /// The box the bars are drawn in.
  final Rect plot;

  /// The bars, left to right.
  final List<FootprintColumn> columns;

  /// The lowest price drawn.
  final double minPrice;

  /// The highest.
  final double maxPrice;

  /// How far apart two price levels are.
  final double tickSize;

  /// How tall one level's row is.
  final double rowHeight;

  /// The most that traded at any one level, what the cell shading is read
  /// against.
  final double largestVolume;

  /// Whether nothing was laid out.
  bool get isEmpty => columns.isEmpty;

  /// Where [price] sits up the plot.
  double yOf(double price) => maxPrice == minPrice
      ? plot.center.dy
      : plot.bottom - (price - minPrice) / (maxPrice - minPrice) * plot.height;
}

/// Places [bars] across [bounds], one column each, priced up the side.
///
/// Levels are [tickSize] apart; a row is one tick tall, so cells line up
/// across bars. [barSpacing] pixels are left between two columns.
FootprintLayout layOutFootprint(
  List<FootprintBar> bars,
  Rect bounds, {
  required double tickSize,
  double? minPrice,
  double? maxPrice,
  double barSpacing = 6,
}) {
  if (bars.isEmpty ||
      bounds.width <= 0 ||
      bounds.height <= 0 ||
      !tickSize.isFinite ||
      tickSize <= 0) {
    return FootprintLayout.empty;
  }

  final range = footprintPriceRange(bars);
  var low = minPrice ?? range.min - tickSize / 2;
  var high = maxPrice ?? range.max + tickSize / 2;
  if (high <= low) {
    low -= tickSize;
    high += tickSize;
  }

  final frame = FootprintLayout(
    plot: bounds,
    columns: const [],
    minPrice: low,
    maxPrice: high,
    tickSize: tickSize,
    rowHeight: bounds.height * tickSize / (high - low),
    largestVolume: 0,
  );

  final width = bounds.width / bars.length;
  final spacing = math.min(math.max(0.0, barSpacing), width);
  var largest = 0.0;

  final columns = <FootprintColumn>[];
  for (var i = 0; i < bars.length; i++) {
    final bar = bars[i];
    final left = bounds.left + i * width;
    final rect = Rect.fromLTWH(left, bounds.top, width, bounds.height);
    final cellLeft = left + spacing / 2;
    final cellWidth = math.max(0.0, width - spacing);

    final cells = <FootprintCell>[];
    for (final level in bar.levels) {
      if (!level.price.isFinite) continue;
      largest = math.max(largest, level.total);
      final centre = frame.yOf(level.price);
      cells.add(
        FootprintCell(
          level: level,
          bar: bar,
          barIndex: i,
          rect: Rect.fromLTWH(
            cellLeft,
            centre - frame.rowHeight / 2,
            cellWidth,
            frame.rowHeight,
          ),
        ),
      );
    }

    columns.add(
      FootprintColumn(
        bar: bar,
        index: i,
        rect: rect,
        cells: cells,
        openY: bar.open == null ? null : frame.yOf(bar.open!),
        closeY: bar.close == null ? null : frame.yOf(bar.close!),
        highY: frame.yOf(bar.top),
        lowY: frame.yOf(bar.bottom),
      ),
    );
  }

  return FootprintLayout(
    plot: bounds,
    columns: columns,
    minPrice: low,
    maxPrice: high,
    tickSize: tickSize,
    rowHeight: frame.rowHeight,
    largestVolume: largest,
  );
}

/// The cell under [local], or null when there is none.
FootprintCell? footprintCellAt(FootprintLayout layout, Offset local) {
  for (final column in layout.columns) {
    if (!column.rect.contains(local)) continue;
    for (final cell in column.cells) {
      if (cell.contains(local)) return cell;
    }
    return null;
  }
  return null;
}

/// What a touch on a [FootprintChart] landed on.
@immutable
class FootprintTouchDetails {
  /// Creates the details of a touch on [cell].
  const FootprintTouchDetails({required this.cell});

  /// The cell touched.
  final FootprintCell cell;

  /// The level it draws.
  FootprintLevel get level => cell.level;

  /// The bar it belongs to.
  FootprintBar get bar => cell.bar;
}

/// What traded at every price inside every bar — a footprint, or order-flow
/// chart.
///
/// Each bar is a column of price levels, each showing what was sold into the
/// bid and what was bought from the offer, shaded by how one-sided it was.
///
/// ```dart
/// FootprintChart(
///   bars: bars,
///   tickSize: 0.5,
/// );
/// ```
///
/// The chart fills the box it is given, and is [defaultHeight] high in a box
/// with no height of its own.
class FootprintChart extends StatefulWidget {
  /// Creates a footprint of [bars].
  const FootprintChart({
    super.key,
    required this.bars,
    required this.tickSize,
    this.minPrice,
    this.maxPrice,
    this.barSpacing = 6,
    this.buyColor = const Color(0xFF2F9E44),
    this.sellColor = const Color(0xFFE03131),
    this.cellOpacity = 0.55,
    this.imbalanceThreshold = 0.4,
    this.imbalanceColor = const Color(0xFFF59F00),
    this.showNumbers = true,
    this.numberStyle,
    this.volumeFormatter,
    this.markPointOfControl = true,
    this.pointOfControlColor = const Color(0xCCFFFFFF),
    this.showCandles = true,
    this.candleColor = const Color(0x66FFFFFF),
    this.candleWidth = 3,
    this.showPriceAxis = true,
    this.axisWidth = 56,
    this.priceLabelEvery = 2,
    this.priceFormatter,
    this.axisLabelStyle,
    this.gridColor,
    this.hoverBorder = const BorderSide(color: Color(0xCCFFFFFF), width: 1.5),
    this.onTouch,
    this.tooltipBuilder,
    this.tooltipMargin = 10,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.defaultHeight = 360,
    this.semanticLabel,
  });

  /// The bars, left to right.
  final List<FootprintBar> bars;

  /// How far apart two price levels are.
  final double tickSize;

  /// The lowest price drawn; null reads it off the bars.
  final double? minPrice;

  /// The highest; null reads it off the bars.
  final double? maxPrice;

  /// The gap left between two columns.
  final double barSpacing;

  /// The colour of buying.
  final Color buyColor;

  /// The colour of selling.
  final Color sellColor;

  /// How opaque the busiest cell is painted; quieter cells fade towards
  /// nothing.
  final double cellOpacity;

  /// How one-sided a level must be, from 0 to 1, before it is outlined as an
  /// imbalance; 1 marks none.
  final double imbalanceThreshold;

  /// The colour of that outline.
  final Color imbalanceColor;

  /// Whether the two volumes are written in each cell.
  final bool showNumbers;

  /// Style of those numbers.
  final TextStyle? numberStyle;

  /// Writes a volume; null writes whole numbers, thousands as `1.2k`.
  final String Function(double volume)? volumeFormatter;

  /// Whether each bar's busiest price is marked.
  final bool markPointOfControl;

  /// The colour of that mark.
  final Color pointOfControlColor;

  /// Whether a thin candle is drawn behind each column.
  final bool showCandles;

  /// The colour of those candles.
  final Color candleColor;

  /// How wide the candle body is.
  final double candleWidth;

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

  /// Colour of the line ruled across each price level; null rules none.
  final Color? gridColor;

  /// Drawn round the cell under the pointer; null marks none.
  final BorderSide? hoverBorder;

  /// Called as a touch moves over the cells, and with null when it leaves.
  final ValueChanged<FootprintTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched cell; null shows none.
  final Widget? Function(BuildContext context, FootprintTouchDetails details)?
      tooltipBuilder;

  /// How far the card sits from the cell.
  final double tooltipMargin;

  /// Space kept clear around the chart.
  final EdgeInsets padding;

  /// Painted behind the whole chart.
  final Color? backgroundColor;

  /// The height taken in a box that sets none.
  final double defaultHeight;

  /// What a screen reader announces for the chart.
  final String? semanticLabel;

  @override
  State<FootprintChart> createState() => _FootprintChartState();
}

class _FootprintChartState extends State<FootprintChart> {
  final TextPainterCache _text = TextPainterCache(capacity: 256);
  FootprintLayout _layout = FootprintLayout.empty;
  (int, double)? _touched;

  void _handle(Offset local) {
    final cell = footprintCellAt(_layout, local);
    final key = cell == null ? null : (cell.barIndex, cell.level.price);
    if (key == _touched) return;
    setState(() => _touched = key);
    widget.onTouch
        ?.call(cell == null ? null : FootprintTouchDetails(cell: cell));
  }

  void _leave() {
    if (_touched == null) return;
    setState(() => _touched = null);
    widget.onTouch?.call(null);
  }

  FootprintCell? _cellFor((int, double)? key) {
    if (key == null || key.$1 >= _layout.columns.length) return null;
    for (final cell in _layout.columns[key.$1].cells) {
      if (cell.level.price == key.$2) return cell;
    }
    return null;
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
        _layout = layOutFootprint(
          widget.bars,
          plot,
          tickSize: widget.tickSize,
          minPrice: widget.minPrice,
          maxPrice: widget.maxPrice,
          barSpacing: widget.barSpacing,
        );

        final cell = _cellFor(_touched);
        final details = cell == null ? null : FootprintTouchDetails(cell: cell);
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
                      painter: FootprintChartPainter(
                        chart: widget,
                        layout: _layout,
                        touched: cell,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (tooltip != null && cell != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomSingleChildLayout(
                          delegate: _FootprintTooltipLayout(
                            anchor: cell.rect,
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

/// Puts the tooltip beside the touched cell, kept inside the chart.
class _FootprintTooltipLayout extends SingleChildLayoutDelegate {
  _FootprintTooltipLayout({required this.anchor, required this.margin});

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
  bool shouldRelayout(_FootprintTooltipLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.margin != margin;
}

/// Paints a [FootprintChart]: the cells, their numbers and the candles.
class FootprintChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [layout].
  FootprintChartPainter({
    required this.chart,
    required this.layout,
    required this.touched,
    required this.textCache,
  });

  final FootprintChart chart;
  final FootprintLayout layout;
  final FootprintCell? touched;
  final TextPainterCache textCache;

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (layout.isEmpty) return;

    _paintGridAndPrices(canvas);

    for (final column in layout.columns) {
      if (chart.showCandles) _paintCandle(canvas, column);
      for (final cell in column.cells) {
        _paintCell(canvas, cell);
      }
      if (chart.markPointOfControl) _paintPointOfControl(canvas, column);
    }

    final hover = chart.hoverBorder;
    final cell = touched;
    if (cell != null &&
        hover != null &&
        hover.style != BorderStyle.none &&
        hover.width > 0) {
      canvas.drawRect(
        cell.rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = hover.width
          ..color = hover.color
          ..isAntiAlias = true,
      );
    }
  }

  void _paintCell(Canvas canvas, FootprintCell cell) {
    if (cell.rect.height <= 0 || cell.rect.width <= 0) return;
    final level = cell.level;
    final busiest = layout.largestVolume;
    final fill = Paint()..isAntiAlias = true;

    // Each half is shaded by how much traded on that side, against the
    // busiest level anywhere on the chart.
    for (final (rect, volume, color) in [
      (cell.bidRect, level.bidVolume, chart.sellColor),
      (cell.askRect, level.askVolume, chart.buyColor),
    ]) {
      final share = busiest <= 0 ? 0.0 : (volume / busiest).clamp(0.0, 1.0);
      fill.color = color.withValues(
        alpha: share * chart.cellOpacity.clamp(0.0, 1.0),
      );
      canvas.drawRect(rect, fill);
    }

    final threshold = chart.imbalanceThreshold;
    if (threshold < 1 && level.imbalance.abs() >= threshold) {
      final side = level.imbalance > 0 ? cell.askRect : cell.bidRect;
      canvas.drawRect(
        side.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = chart.imbalanceColor
          ..isAntiAlias = true,
      );
    }

    if (!chart.showNumbers) return;
    final style = chart.numberStyle ??
        TextStyle(
          fontSize: math.min(9, cell.rect.height - 1),
          height: 1,
          color: const Color(0xDDFFFFFF),
        );
    if (style.fontSize != null && style.fontSize! < 5) return;
    for (final (rect, volume) in [
      (cell.bidRect, level.bidVolume),
      (cell.askRect, level.askVolume),
    ]) {
      final tp = textCache.get(_formatVolume(volume), style);
      if (tp.width > rect.width - 2 || tp.height > rect.height) continue;
      tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _paintCandle(Canvas canvas, FootprintColumn column) {
    final open = column.openY;
    final close = column.closeY;
    if (open == null || close == null) return;
    final x = column.rect.center.dx;
    final pen = Paint()
      ..color = chart.candleColor
      ..strokeWidth = 1;
    canvas
      ..drawLine(Offset(x, column.highY), Offset(x, column.lowY), pen)
      ..drawRect(
        Rect.fromLTRB(
          x - chart.candleWidth / 2,
          math.min(open, close),
          x + chart.candleWidth / 2,
          math.max(open, close),
        ),
        Paint()..color = chart.candleColor,
      );
  }

  void _paintPointOfControl(Canvas canvas, FootprintColumn column) {
    final poc = column.bar.pointOfControl;
    if (poc == null) return;
    for (final cell in column.cells) {
      if (cell.level.price != poc) continue;
      canvas.drawLine(
        Offset(cell.rect.left, cell.rect.center.dy),
        Offset(cell.rect.right, cell.rect.center.dy),
        Paint()
          ..color = chart.pointOfControlColor
          ..strokeWidth = 1,
      );
      return;
    }
  }

  void _paintGridAndPrices(Canvas canvas) {
    final grid = chart.gridColor;
    if (!chart.showPriceAxis && grid == null) return;
    if (layout.rowHeight <= 0) return;

    final style = seriesAxisLabelStyle.merge(chart.axisLabelStyle);
    final every = math.max(1, chart.priceLabelEvery);
    final steps =
        ((layout.maxPrice - layout.minPrice) / layout.tickSize).floor();
    if (steps <= 0 || steps > 2000) return;

    for (var i = 0; i <= steps; i++) {
      final price = layout.minPrice + i * layout.tickSize;
      final y = layout.yOf(price);
      if (grid != null) {
        canvas.drawLine(
          Offset(layout.plot.left, y),
          Offset(layout.plot.right, y),
          Paint()
            ..color = grid
            ..strokeWidth = 1,
        );
      }
      if (!chart.showPriceAxis || i % every != 0) continue;
      final tp = textCache.get(_formatPrice(price), style);
      final left = layout.plot.left - 6 - tp.width;
      if (left >= 0) tp.paint(canvas, Offset(left, y - tp.height / 2));
    }
  }

  String _formatVolume(double volume) {
    final format = chart.volumeFormatter;
    if (format != null) return format(volume);
    if (volume.abs() >= 1000) {
      final thousands = volume / 1000;
      return '${thousands.toStringAsFixed(thousands.abs() >= 10 ? 0 : 1)}k';
    }
    return volume.round().toString();
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
  bool shouldRepaint(FootprintChartPainter oldDelegate) =>
      !identical(oldDelegate.chart, chart) ||
      !identical(oldDelegate.layout, layout) ||
      oldDelegate.touched != touched;
}
