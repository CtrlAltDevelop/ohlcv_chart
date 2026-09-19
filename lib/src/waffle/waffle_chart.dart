import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// One part of a [WaffleChart] — a share of the whole.
@immutable
class WaffleSlice {
  /// Creates a slice called [label] worth [value].
  const WaffleSlice({
    required this.label,
    required this.value,
    required this.color,
    this.tooltip,
  });

  /// What the slice is called.
  final String label;

  /// How much of the whole it is. Negative values count as nothing.
  final double value;

  /// What its cells are painted in.
  final Color color;

  /// Shown when one of its cells is touched; null shows the label and share.
  final String? tooltip;
}

/// How the cells of a [WaffleChart] are handed out.
///
/// Cells are whole things, so the shares have to be rounded to them. The
/// largest remainder gets the spare cells, which keeps every slice within one
/// cell of its true share and the total exactly [cells].
List<int> waffleCounts(
  List<WaffleSlice> slices, {
  int cells = 100,
  double? total,
}) {
  if (slices.isEmpty || cells <= 0) {
    return List<int>.filled(slices.length, 0);
  }
  final values = [
    for (final slice in slices)
      slice.value.isFinite && slice.value > 0 ? slice.value : 0.0,
  ];
  final sum = total != null && total.isFinite && total > 0
      ? total
      : values.fold<double>(0, (a, b) => a + b);
  if (!(sum > 0)) return List<int>.filled(slices.length, 0);

  final exact = [for (final value in values) value / sum * cells];
  final counts = [for (final share in exact) share.floor()];
  var spare = cells - counts.fold<int>(0, (a, b) => a + b);
  // Never hand out more cells than there are, which a given total under the
  // real sum would otherwise ask for.
  if (spare < 0) {
    for (var i = counts.length - 1; i >= 0 && spare < 0; i--) {
      final take = math.min(counts[i], -spare);
      counts[i] -= take;
      spare += take;
    }
    return counts;
  }
  // With a total of its own the whole is not the slices, so cells left over
  // belong to nobody and stay empty.
  if (total != null && total.isFinite && total > 0) return counts;
  final order = [for (var i = 0; i < counts.length; i++) i]
    ..sort((a, b) {
      final remainder = (exact[b] - counts[b]).compareTo(exact[a] - counts[a]);
      return remainder != 0 ? remainder : a.compareTo(b);
    });
  for (var i = 0; i < spare; i++) {
    counts[order[i % order.length]]++;
  }
  return counts;
}

/// Where a waffle's cells sit, and which slice each belongs to.
@immutable
class WaffleLayout {
  /// Creates a laid-out waffle.
  const WaffleLayout({
    required this.size,
    required this.cells,
    required this.owners,
    required this.columns,
    required this.rows,
    required this.counts,
  });

  /// Nothing to draw.
  static const empty = WaffleLayout(
    size: Size.zero,
    cells: [],
    owners: [],
    columns: 0,
    rows: 0,
    counts: [],
  );

  /// The box the waffle was laid out in.
  final Size size;

  /// Every cell, in the order they are filled.
  final List<Rect> cells;

  /// Which slice owns each cell, into the chart's slices; -1 for an empty one.
  final List<int> owners;

  /// How many cells across.
  final int columns;

  /// How many cells down.
  final int rows;

  /// How many cells each slice got.
  final List<int> counts;

  /// Whether there is anything to draw.
  bool get isEmpty => cells.isEmpty;

  /// The slice under [point]; null where no cell is, or the cell is empty.
  int? sliceAt(Offset point) {
    for (var i = 0; i < cells.length; i++) {
      if (cells[i].contains(point)) {
        final owner = owners[i];
        return owner < 0 ? null : owner;
      }
    }
    return null;
  }
}

/// Which corner a waffle starts filling from, and which way it runs.
enum WaffleFill {
  /// Along the bottom row first, then upwards — the usual one.
  bottomRowsUp,

  /// Along the top row first, then downwards.
  topRowsDown,

  /// Up the leftmost column first, then rightwards.
  leftColumnsRight,
}

/// Lays out [counts] cells in a grid of [columns] by [rows] filling [size].
///
/// [cellGap] is the space between neighbouring cells and [progress] fills only
/// the first part of the cells, for a fill-in animation.
WaffleLayout layOutWaffle(
  List<int> counts, {
  required Size size,
  int columns = 10,
  int? rows,
  double cellGap = 3,
  WaffleFill fill = WaffleFill.bottomRowsUp,
  EdgeInsets padding = EdgeInsets.zero,
  double progress = 1,
}) {
  final total = counts.fold<int>(0, (a, b) => a + math.max(0, b));
  if (columns <= 0) return WaffleLayout.empty;
  final rowCount = rows ?? math.max(1, (total / columns).ceil());
  if (rowCount <= 0) return WaffleLayout.empty;
  final box = padding.deflateRect(Offset.zero & size);
  if (box.width <= 0 || box.height <= 0) return WaffleLayout.empty;

  // Square cells, as large as both directions allow.
  final cell = math.min(
    (box.width - cellGap * (columns - 1)) / columns,
    (box.height - cellGap * (rowCount - 1)) / rowCount,
  );
  if (!(cell > 0)) return WaffleLayout.empty;
  final gridWidth = cell * columns + cellGap * (columns - 1);
  final gridHeight = cell * rowCount + cellGap * (rowCount - 1);
  final left = box.left + (box.width - gridWidth) / 2;
  final top = box.top + (box.height - gridHeight) / 2;

  final slots = columns * rowCount;
  final shown = (total * progress.clamp(0.0, 1.0)).round();

  final cells = <Rect>[];
  final owners = <int>[];
  var slice = 0;
  var used = 0;
  for (var i = 0; i < slots; i++) {
    final int column, row;
    switch (fill) {
      case WaffleFill.bottomRowsUp:
        column = i % columns;
        row = rowCount - 1 - i ~/ columns;
      case WaffleFill.topRowsDown:
        column = i % columns;
        row = i ~/ columns;
      case WaffleFill.leftColumnsRight:
        column = i ~/ rowCount;
        row = rowCount - 1 - i % rowCount;
    }
    cells.add(
      Rect.fromLTWH(
        left + column * (cell + cellGap),
        top + row * (cell + cellGap),
        cell,
        cell,
      ),
    );

    if (i >= shown) {
      owners.add(-1);
      continue;
    }
    while (slice < counts.length && used >= math.max(0, counts[slice])) {
      slice++;
      used = 0;
    }
    if (slice >= counts.length) {
      owners.add(-1);
      continue;
    }
    owners.add(slice);
    used++;
  }

  return WaffleLayout(
    size: size,
    cells: cells,
    owners: owners,
    columns: columns,
    rows: rowCount,
    counts: [for (final count in counts) math.max(0, count)],
  );
}

/// Parts of a whole as a grid of squares — a waffle chart.
///
/// A hundred cells read as per cent without a legend to decode, which is what
/// a pie chart cannot do: "how much of the book is in crypto" is counted, not
/// judged by angle.
///
/// ```dart
/// WaffleChart(
///   slices: const [
///     WaffleSlice(label: 'Crypto', value: 45, color: Color(0xFF4C86CD)),
///     WaffleSlice(label: 'Equities', value: 35, color: Color(0xFF2F9E44)),
///     WaffleSlice(label: 'Cash', value: 20, color: Color(0xFF909196)),
///   ],
/// );
/// ```
class WaffleChart extends StatefulWidget {
  /// Creates a waffle of [slices].
  const WaffleChart({
    super.key,
    required this.slices,
    this.cells = 100,
    this.columns = 10,
    this.rows,
    this.total,
    this.cellGap = 3,
    this.cellRadius = 2,
    this.fill = WaffleFill.bottomRowsUp,
    this.emptyColor = const Color(0x22909196),
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.onSliceTap,
    this.tooltipBuilder,
    this.defaultSize = 220,
    this.semanticLabel,
  });

  /// The parts of the whole, filled in the order given.
  final List<WaffleSlice> slices;

  /// How many cells the whole is worth; 100 makes each cell a per cent.
  final int cells;

  /// How many cells across.
  final int columns;

  /// How many cells down; null takes as many rows as [cells] needs.
  final int? rows;

  /// What the slices are a share of; null takes their sum, so they always
  /// fill the grid. Give it to leave the rest of the grid empty.
  final double? total;

  /// Space between neighbouring cells.
  final double cellGap;

  /// How round the corners of a cell are.
  final double cellRadius;

  /// Which corner the cells are filled from.
  final WaffleFill fill;

  /// What a cell no slice reached is painted in.
  final Color emptyColor;

  /// Space kept clear around the grid.
  final EdgeInsets padding;

  /// Painted behind the whole chart.
  final Color? backgroundColor;

  /// How long the cells take to fill in; zero fills them at once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build fills the cells in.
  final bool animateOnMount;

  /// Called with a slice when one of its cells is touched, and with null when
  /// the touch leaves the filled cells.
  final void Function(WaffleSlice? slice)? onSliceTap;

  /// Builds the card shown over a touched slice; null shows its label and
  /// how many cells it holds.
  final Widget Function(BuildContext context, WaffleSlice slice, int cells)?
  tooltipBuilder;

  /// The size taken in a box that sets none.
  final double defaultSize;

  /// What a screen reader announces for the chart.
  final String? semanticLabel;

  @override
  State<WaffleChart> createState() => _WaffleChartState();
}

class _WaffleChartState extends State<WaffleChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  WaffleLayout _layout = WaffleLayout.empty;
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
  void didUpdateWidget(WaffleChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!identical(oldWidget.slices, widget.slices) &&
        widget.animationDuration > Duration.zero) {
      _animation.forward(from: 0);
    }
    if (_touched != null && _touched! >= widget.slices.length) _touched = null;
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void _touch(Offset point) {
    final slice = _layout.sliceAt(point);
    if (slice == _touched) return;
    setState(() => _touched = slice);
    widget.onSliceTap?.call(slice == null ? null : widget.slices[slice]);
  }

  void _clear() {
    if (_touched == null) return;
    setState(() => _touched = null);
    widget.onSliceTap?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.animationCurve.transform(_animation.value);
    final counts = waffleCounts(
      widget.slices,
      cells: widget.rows != null ? widget.columns * widget.rows! : widget.cells,
      total: widget.total,
    );

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : widget.defaultSize;
          final height =
              constraints.hasBoundedHeight && constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : widget.defaultSize;
          _layout = layOutWaffle(
            counts,
            size: Size(width, height),
            columns: widget.columns,
            rows:
                widget.rows ??
                math.max(1, (widget.cells / widget.columns).ceil()),
            cellGap: widget.cellGap,
            fill: widget.fill,
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
                      painter: WaffleChartPainter(
                        chart: widget,
                        layout: _layout,
                        touched: touched,
                      ),
                    ),
                  ),
                  if (touched != null && touched < widget.slices.length)
                    _tooltip(context, touched),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tooltip(BuildContext context, int index) {
    final slice = widget.slices[index];
    final count = index < _layout.counts.length ? _layout.counts[index] : 0;
    final build = widget.tooltipBuilder;
    final child = build != null
        ? build(context, slice, count)
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xEE1B1D22),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              slice.tooltip ?? '${slice.label}  $count',
              style: const TextStyle(color: Color(0xFFE9ECEF), fontSize: 11),
            ),
          );
    // Over the first cell the slice holds, so the card points at the run of
    // colour it describes.
    final cell = _cellOf(_layout, index);
    return Positioned(
      left: cell?.left ?? 0,
      top: math.max(0, (cell?.top ?? 0) - 24),
      child: IgnorePointer(child: child),
    );
  }
}

/// The first cell [slice] holds in [layout]; null when it holds none.
Rect? _cellOf(WaffleLayout layout, int slice) {
  for (var i = 0; i < layout.cells.length; i++) {
    if (layout.owners[i] == slice) return layout.cells[i];
  }
  return null;
}

/// Paints a [WaffleChart]: one rounded square per cell.
class WaffleChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [layout].
  WaffleChartPainter({
    required this.chart,
    required this.layout,
    required this.touched,
  });

  final WaffleChart chart;
  final WaffleLayout layout;

  /// The slice under the finger, into [WaffleChart.slices]; null when none is.
  final int? touched;

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (layout.isEmpty) return;

    final radius = Radius.circular(chart.cellRadius);
    for (var i = 0; i < layout.cells.length; i++) {
      final owner = layout.owners[i];
      var color = owner < 0 || owner >= chart.slices.length
          ? chart.emptyColor
          : chart.slices[owner].color;
      // Everything but the touched slice is dimmed, so the share stands out
      // without the cells moving.
      if (touched != null && owner != touched) {
        color = Color.lerp(color, const Color(0x00000000), 0.55) ?? color;
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(layout.cells[i], radius),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(WaffleChartPainter old) =>
      old.chart != chart || old.layout != layout || old.touched != touched;
}
