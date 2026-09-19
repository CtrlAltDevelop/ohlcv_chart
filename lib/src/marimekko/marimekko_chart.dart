import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';

/// One part of a [MarimekkoColumn] — a segment of its height.
@immutable
class MarimekkoCell {
  /// Creates a cell called [label] worth [value].
  const MarimekkoCell({
    required this.label,
    required this.value,
    this.color,
    this.tooltip,
  });

  /// What the cell is called. Cells with the same label across columns are
  /// the same category, and take the same colour from the chart's palette.
  final String label;

  /// How much of its column it is. Negatives and nonsense count as nothing.
  final double value;

  /// What it is painted in; null takes the category's colour.
  final Color? color;

  /// Shown when the cell is touched; null shows its label, value and share.
  final String? tooltip;

  /// The value actually drawn.
  double get drawnValue => value.isFinite && value > 0 ? value : 0;
}

/// One column of a [MarimekkoChart] — a whole split into cells.
@immutable
class MarimekkoColumn {
  /// Creates a column called [label] made of [cells].
  const MarimekkoColumn({
    required this.label,
    required this.cells,
    this.width,
    this.tooltip,
  });

  /// What the column is called, written across the top.
  final String label;

  /// Its parts, stacked from the bottom in the order given.
  final List<MarimekkoCell> cells;

  /// How wide the column is; null takes the sum of its cells, which is the
  /// usual thing — the column's width is how big it is.
  final double? width;

  /// Shown when the column's header is touched; null shows its label and
  /// total.
  final String? tooltip;

  /// The sum of its cells.
  double get total =>
      cells.fold<double>(0, (sum, cell) => sum + cell.drawnValue);

  /// The width actually used.
  double get drawnWidth {
    final given = width;
    if (given != null && given.isFinite && given > 0) return given;
    return total;
  }
}

/// Where one cell of a [MarimekkoChart] sits.
@immutable
class MarimekkoCellLayout {
  /// Creates the layout of the cell at [cellIndex] of column [columnIndex].
  const MarimekkoCellLayout({
    required this.columnIndex,
    required this.cellIndex,
    required this.cell,
    required this.rect,
    required this.share,
    required this.category,
  });

  /// Which column the cell is in.
  final int columnIndex;

  /// Which cell of that column it is.
  final int cellIndex;

  /// The cell itself.
  final MarimekkoCell cell;

  /// Where it sits.
  final Rect rect;

  /// How much of its column it is, from 0 to 1.
  final double share;

  /// Which category it belongs to — its position among the chart's distinct
  /// cell labels, which is what decides its colour.
  final int category;
}

/// Where one column of a [MarimekkoChart] sits.
@immutable
class MarimekkoColumnLayout {
  /// Creates the layout of the column at [index].
  const MarimekkoColumnLayout({
    required this.index,
    required this.column,
    required this.rect,
    required this.headerRect,
    required this.cells,
    required this.widthShare,
  });

  /// Which column this is, into the chart's columns.
  final int index;

  /// The column itself.
  final MarimekkoColumn column;

  /// Where it sits.
  final Rect rect;

  /// Where its name is written.
  final Rect headerRect;

  /// Its cells, bottom to top in the order they were given.
  final List<MarimekkoCellLayout> cells;

  /// How much of the chart's width it takes, from 0 to 1.
  final double widthShare;
}

/// Where every column and cell of a [MarimekkoChart] sits.
@immutable
class MarimekkoLayout {
  /// Creates a laid-out chart.
  const MarimekkoLayout({
    required this.size,
    required this.plotRect,
    required this.columns,
    required this.categories,
  });

  /// Nothing to draw.
  static const empty = MarimekkoLayout(
    size: Size.zero,
    plotRect: Rect.zero,
    columns: [],
    categories: [],
  );

  /// The box the chart was laid out in.
  final Size size;

  /// The part of it the columns fill.
  final Rect plotRect;

  /// The columns, left to right in the order they were given.
  final List<MarimekkoColumnLayout> columns;

  /// The distinct cell labels, in the order they were first seen — the
  /// categories, which is what the colours are handed out by.
  final List<String> categories;

  /// Whether there is anything to draw.
  bool get isEmpty => columns.isEmpty;

  /// The cell under [point]; null when none is.
  MarimekkoCellLayout? cellAt(Offset point) {
    for (final column in columns) {
      if (point.dx < column.rect.left || point.dx > column.rect.right) continue;
      for (final cell in column.cells) {
        if (cell.rect.contains(point)) return cell;
      }
    }
    return null;
  }

  /// The column under [point], header included; null when none is.
  MarimekkoColumnLayout? columnAt(Offset point) {
    for (final column in columns) {
      if (point.dx >= column.rect.left && point.dx <= column.rect.right) {
        return column;
      }
    }
    return null;
  }
}

/// Lays out [columns] in [size], each as wide as it is big.
///
/// [progress] runs from 0 to 1 and grows the cells up from the bottom of their
/// column, for a draw-in animation.
MarimekkoLayout layOutMarimekko(
  List<MarimekkoColumn> columns, {
  required Size size,
  double columnGap = 2,
  double cellGap = 1,
  double headerHeight = 0,
  EdgeInsets padding = EdgeInsets.zero,
  double progress = 1,
}) {
  if (columns.isEmpty) return MarimekkoLayout.empty;
  final box = padding.deflateRect(Offset.zero & size);
  if (box.width <= 0 || box.height <= 0) return MarimekkoLayout.empty;
  final plot = Rect.fromLTRB(
    box.left,
    box.top + math.max(0, headerHeight),
    box.right,
    box.bottom,
  );
  if (plot.width <= 0 || plot.height <= 0) return MarimekkoLayout.empty;

  final widths = [for (final column in columns) column.drawnWidth];
  final totalWidth = widths.fold<double>(0, (a, b) => a + b);
  if (!(totalWidth > 0)) return MarimekkoLayout.empty;

  // The gaps come out of the width before the columns share what is left, so
  // the shares stay true whatever the gap.
  final gaps = columnGap * math.max(0, columns.length - 1);
  final usable = plot.width - gaps;
  if (!(usable > 0)) return MarimekkoLayout.empty;

  final categories = <String>[];
  for (final column in columns) {
    for (final cell in column.cells) {
      if (!categories.contains(cell.label)) categories.add(cell.label);
    }
  }

  final t = progress.clamp(0.0, 1.0);
  final laid = <MarimekkoColumnLayout>[];
  var x = plot.left;
  for (var i = 0; i < columns.length; i++) {
    final column = columns[i];
    final share = widths[i] / totalWidth;
    final width = usable * share;
    final rect = Rect.fromLTWH(x, plot.top, width, plot.height);
    x += width + columnGap;

    final total = column.total;
    final cells = <MarimekkoCellLayout>[];
    var bottom = rect.bottom;
    for (var c = 0; c < column.cells.length; c++) {
      final cell = column.cells[c];
      final cellShare = total > 0 ? cell.drawnValue / total : 0.0;
      final height = rect.height * cellShare * t;
      final top = bottom - height;
      cells.add(
        MarimekkoCellLayout(
          columnIndex: i,
          cellIndex: c,
          cell: cell,
          rect: Rect.fromLTRB(
            rect.left,
            top,
            rect.right,
            math.max(top, bottom - (c == 0 ? 0 : cellGap)),
          ),
          share: cellShare,
          category: math.max(0, categories.indexOf(cell.label)),
        ),
      );
      bottom = top;
    }

    laid.add(
      MarimekkoColumnLayout(
        index: i,
        column: column,
        rect: rect,
        headerRect: Rect.fromLTWH(
          rect.left,
          box.top,
          width,
          math.max(0, headerHeight),
        ),
        cells: cells,
        widthShare: share,
      ),
    );
  }

  return MarimekkoLayout(
    size: size,
    plotRect: plot,
    columns: laid,
    categories: categories,
  );
}

/// Two dimensions at once — a Marimekko, or mosaic, chart.
///
/// Every column is as wide as it is big and as tall as every other, so the
/// width says how much a group is worth and the height says what it is made
/// of. Volume by venue split by instrument, revenue by desk split by product,
/// exposure by sector split by symbol: one chart instead of a pie beside a bar.
///
/// ```dart
/// MarimekkoChart(
///   columns: const [
///     MarimekkoColumn(
///       label: 'Spot',
///       cells: [
///         MarimekkoCell(label: 'BTC', value: 60),
///         MarimekkoCell(label: 'ETH', value: 40),
///       ],
///     ),
///     MarimekkoColumn(
///       label: 'Perps',
///       cells: [
///         MarimekkoCell(label: 'BTC', value: 150),
///         MarimekkoCell(label: 'ETH', value: 50),
///       ],
///     ),
///   ],
/// );
/// ```
class MarimekkoChart extends StatefulWidget {
  /// Creates a Marimekko chart of [columns].
  const MarimekkoChart({
    super.key,
    required this.columns,
    this.palette = defaultPalette,
    this.columnGap = 2,
    this.cellGap = 1,
    this.showHeaders = true,
    this.headerHeight = 20,
    this.headerStyle,
    this.showWidthShare = true,
    this.showCellLabels = true,
    this.minLabelHeight = 16,
    this.cellStyle,
    this.cellFormatter,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.onCellTap,
    this.tooltipBuilder,
    this.defaultHeight = 260,
    this.semanticLabel,
  });

  /// The columns, left to right in the order given.
  final List<MarimekkoColumn> columns;

  /// Colours handed to the categories, in the order the labels first appear.
  final List<Color> palette;

  /// The colours used where a cell names none.
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

  /// Space between neighbouring columns.
  final double columnGap;

  /// Space between the cells of one column.
  final double cellGap;

  /// Whether the column names are written across the top.
  final bool showHeaders;

  /// How much room they take.
  final double headerHeight;

  /// Style of the column names.
  final TextStyle? headerStyle;

  /// Whether a column's share of the width is written after its name.
  final bool showWidthShare;

  /// Whether a cell's name is written in it where there is room.
  final bool showCellLabels;

  /// How tall a cell has to be, in pixels, before it is labelled.
  final double minLabelHeight;

  /// Style of the cell labels.
  final TextStyle? cellStyle;

  /// Writes a cell's label; null writes its name and its share of the column.
  final String Function(MarimekkoCell cell, double share)? cellFormatter;

  /// Space kept clear around the chart.
  final EdgeInsets padding;

  /// Painted behind the whole chart.
  final Color? backgroundColor;

  /// How long the cells take to grow up; zero draws them at once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build grows the cells up.
  final bool animateOnMount;

  /// Called with a cell and its column when one is touched, and with nulls
  /// when the touch leaves the columns.
  final void Function(MarimekkoCell? cell, MarimekkoColumn? column)? onCellTap;

  /// Builds the card shown over a touched cell; null shows its label, value
  /// and share.
  final Widget Function(
    BuildContext context,
    MarimekkoCell cell,
    MarimekkoColumn column,
    double share,
  )?
  tooltipBuilder;

  /// How tall the chart is in a box that sets no height.
  final double defaultHeight;

  /// What a screen reader announces for the chart.
  final String? semanticLabel;

  @override
  State<MarimekkoChart> createState() => _MarimekkoChartState();
}

class _MarimekkoChartState extends State<MarimekkoChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 256);
  MarimekkoLayout _layout = MarimekkoLayout.empty;
  MarimekkoCellLayout? _touched;

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
  void didUpdateWidget(MarimekkoChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!identical(oldWidget.columns, widget.columns)) {
      _touched = null;
      if (widget.animationDuration > Duration.zero) {
        _animation.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _animation.dispose();
    super.dispose();
  }

  void _touch(Offset point) {
    final found = _layout.cellAt(point);
    if (found?.columnIndex == _touched?.columnIndex &&
        found?.cellIndex == _touched?.cellIndex) {
      return;
    }
    setState(() => _touched = found);
    widget.onCellTap?.call(
      found?.cell,
      found == null ? null : widget.columns[found.columnIndex],
    );
  }

  void _clear() {
    if (_touched == null) return;
    setState(() => _touched = null);
    widget.onCellTap?.call(null, null);
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
              : 420.0;
          final height =
              constraints.hasBoundedHeight && constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : widget.defaultHeight;
          _layout = layOutMarimekko(
            widget.columns,
            size: Size(width, height),
            columnGap: widget.columnGap,
            cellGap: widget.cellGap,
            headerHeight: widget.showHeaders ? widget.headerHeight : 0,
            padding: widget.padding,
            progress: progress,
          );

          final touched = _touched;
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
                      painter: MarimekkoChartPainter(
                        chart: widget,
                        layout: _layout,
                        touched: touched,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (touched != null) _tooltip(context, touched),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tooltip(BuildContext context, MarimekkoCellLayout laid) {
    final column = widget.columns[laid.columnIndex];
    final build = widget.tooltipBuilder;
    final child = build != null
        ? build(context, laid.cell, column, laid.share)
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xEE1B1D22),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              laid.cell.tooltip ??
                  '${column.label} · ${laid.cell.label}  '
                      '${_number(laid.cell.drawnValue)}  '
                      '${(laid.share * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: Color(0xFFE9ECEF), fontSize: 11),
            ),
          );
    return Positioned(
      left: math.max(0, laid.rect.left),
      top: math.max(0, laid.rect.top - 26),
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

/// Paints a [MarimekkoChart]: the cells, their names and the column headers.
class MarimekkoChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [layout].
  MarimekkoChartPainter({
    required this.chart,
    required this.layout,
    required this.touched,
    required this.textCache,
  });

  final MarimekkoChart chart;
  final MarimekkoLayout layout;

  /// The cell under the finger; null when none is.
  final MarimekkoCellLayout? touched;
  final TextPainterCache textCache;

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (layout.isEmpty) return;

    final headerStyle =
        chart.headerStyle ??
        const TextStyle(color: Color(0xFFB4B8C0), fontSize: 11);
    final cellStyle =
        chart.cellStyle ??
        const TextStyle(color: Color(0xFF15171C), fontSize: 10);

    for (final column in layout.columns) {
      for (final laid in column.cells) {
        if (laid.rect.height <= 0) continue;
        final base =
            laid.cell.color ??
            chart.palette[laid.category % math.max(1, chart.palette.length)];
        final lit =
            touched?.columnIndex == laid.columnIndex &&
            touched?.cellIndex == laid.cellIndex;
        canvas.drawRect(
          laid.rect,
          Paint()..color = lit ? _lighten(base) : base,
        );

        if (chart.showCellLabels && laid.rect.height >= chart.minLabelHeight) {
          final text =
              chart.cellFormatter?.call(laid.cell, laid.share) ??
              laid.cell.label;
          final painter = textCache.get(text, cellStyle);
          if (painter.width <= laid.rect.width - 6) {
            painter.paint(
              canvas,
              Offset(
                laid.rect.center.dx - painter.width / 2,
                laid.rect.center.dy - painter.height / 2,
              ),
            );
          }
        }
      }

      if (chart.showHeaders && column.headerRect.height > 0) {
        final text = chart.showWidthShare
            ? '${column.column.label}  '
                  '${(column.widthShare * 100).toStringAsFixed(0)}%'
            : column.column.label;
        final painter = textCache.get(text, headerStyle);
        // Clipped to the column, so a narrow one does not write over its
        // neighbour's name.
        canvas.save();
        canvas.clipRect(column.headerRect);
        painter.paint(
          canvas,
          Offset(
            column.headerRect.center.dx - painter.width / 2,
            column.headerRect.center.dy - painter.height / 2,
          ),
        );
        canvas.restore();
      }
    }
  }

  Color _lighten(Color color) =>
      Color.lerp(color, const Color(0xFFFFFFFF), 0.22) ?? color;

  @override
  bool shouldRepaint(MarimekkoChartPainter old) =>
      old.chart != chart || old.layout != layout || old.touched != touched;
}
