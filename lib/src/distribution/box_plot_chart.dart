import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';
import '../series/series_axis.dart';
import '../treemap/treemap_data.dart' show treemapPalette;
import '../utils/axis_ticks.dart';

/// The five numbers a box plot draws, and the points outside them.
@immutable
class BoxPlotStats {
  /// Creates a summary from numbers already worked out.
  const BoxPlotStats({
    required this.lower,
    required this.q1,
    required this.median,
    required this.q3,
    required this.upper,
    this.mean,
    this.outliers = const [],
  });

  /// Summarises [samples]: the quartiles, the whiskers and the outliers.
  ///
  /// Quartiles are read off the sorted samples by linear interpolation, the
  /// method spreadsheets and NumPy use. The whiskers reach the furthest sample
  /// still within [whisker] interquartile ranges of the box, and everything
  /// past them is an outlier. A [whisker] that is not finite keeps every
  /// sample inside the whiskers and reports no outliers.
  factory BoxPlotStats.fromSamples(
    Iterable<double> samples, {
    double whisker = 1.5,
  }) {
    final sorted = [
      for (final value in samples)
        if (value.isFinite) value,
    ]..sort();
    if (sorted.isEmpty) {
      return const BoxPlotStats(lower: 0, q1: 0, median: 0, q3: 0, upper: 0);
    }

    double quantile(double p) {
      final at = p * (sorted.length - 1);
      final low = at.floor();
      final high = at.ceil();
      if (low == high) return sorted[low];
      return sorted[low] + (sorted[high] - sorted[low]) * (at - low);
    }

    final q1 = quantile(0.25);
    final median = quantile(0.5);
    final q3 = quantile(0.75);
    final reach = whisker.isFinite ? (q3 - q1) * math.max(0, whisker) : null;
    final low = reach == null ? sorted.first : q1 - reach;
    final high = reach == null ? sorted.last : q3 + reach;

    var lower = sorted.last;
    var upper = sorted.first;
    final outliers = <double>[];
    for (final value in sorted) {
      if (value < low || value > high) {
        outliers.add(value);
      } else {
        lower = math.min(lower, value);
        upper = math.max(upper, value);
      }
    }
    if (upper < lower) {
      // Everything was an outlier: fall back to the quartiles.
      lower = q1;
      upper = q3;
    }

    var sum = 0.0;
    for (final value in sorted) {
      sum += value;
    }

    return BoxPlotStats(
      lower: lower,
      q1: q1,
      median: median,
      q3: q3,
      upper: upper,
      mean: sum / sorted.length,
      outliers: outliers,
    );
  }

  /// The end of the lower whisker.
  final double lower;

  /// The bottom of the box: the 25th percentile.
  final double q1;

  /// The line across the box: the 50th percentile.
  final double median;

  /// The top of the box: the 75th percentile.
  final double q3;

  /// The end of the upper whisker.
  final double upper;

  /// The average, marked apart from the median; null draws no mark.
  final double? mean;

  /// The samples past the whiskers, drawn as points.
  final List<double> outliers;

  /// The width of the box: the interquartile range.
  double get iqr => q3 - q1;

  /// The lowest value drawn, outliers included.
  double get min => outliers.fold(lower, math.min);

  /// The highest value drawn, outliers included.
  double get max => outliers.fold(upper, math.max);
}

/// One box of a [BoxPlotChart] — a strategy, a symbol, a month.
@immutable
class BoxPlotEntry {
  /// Creates an entry summarised by [stats].
  const BoxPlotEntry({required this.stats, this.label, this.color, this.data});

  /// Creates an entry by summarising [samples] itself.
  BoxPlotEntry.fromSamples(
    Iterable<double> samples, {
    this.label,
    this.color,
    this.data,
    double whisker = 1.5,
  }) : stats = BoxPlotStats.fromSamples(samples, whisker: whisker);

  /// The numbers drawn.
  final BoxPlotStats stats;

  /// What the entry is called, written under its box.
  final String? label;

  /// A colour of this entry's own.
  final Color? color;

  /// Anything the app wants back when this entry is touched.
  final Object? data;
}

/// Where one [BoxPlotEntry] was laid out.
@immutable
class BoxPlotBox {
  /// Creates the box of [entry].
  const BoxPlotBox({
    required this.entry,
    required this.index,
    required this.band,
    required this.rect,
    required this.medianY,
    required this.meanY,
    required this.lowerY,
    required this.upperY,
    required this.outlierYs,
  });

  /// The entry this box draws.
  final BoxPlotEntry entry;

  /// Its position along the chart, from the left.
  final int index;

  /// The full column the entry owns, including the space either side of the
  /// box; what a touch is tested against.
  final Rect band;

  /// The box itself: q1 to q3.
  final Rect rect;

  /// Where the median line is drawn.
  final double medianY;

  /// Where the mean is marked; null when the entry reports none.
  final double? meanY;

  /// Where the lower whisker ends.
  final double lowerY;

  /// Where the upper whisker ends.
  final double upperY;

  /// Where each outlier sits, in the order they were given.
  final List<double> outlierYs;

  /// The middle of the box, left to right.
  double get centerX => rect.center.dx;

  /// Whether [local] is inside the entry's column.
  bool contains(Offset local) => band.contains(local);
}

/// The value range [entries] need, widened to round numbers.
///
/// Returns a flat range unchanged apart from a unit of padding, so a chart of
/// identical values still draws.
({double min, double max}) boxPlotRange(List<BoxPlotEntry> entries) {
  var min = double.infinity;
  var max = double.negativeInfinity;
  for (final entry in entries) {
    min = math.min(min, entry.stats.min);
    max = math.max(max, entry.stats.max);
  }
  if (!min.isFinite || !max.isFinite) return (min: 0, max: 1);
  if (min == max) return (min: min - 1, max: max + 1);
  final pad = (max - min) * 0.05;
  return (min: min - pad, max: max + pad);
}

/// Lays [entries] out across [bounds], one column each, against `[min, max]`.
///
/// Each column is as wide as the space allows; the box takes
/// [boxWidthFraction] of it and is centred. Values run up the box, so [min] is
/// at the bottom.
List<BoxPlotBox> layOutBoxPlot(
  List<BoxPlotEntry> entries,
  Rect bounds, {
  required double min,
  required double max,
  double boxWidthFraction = 0.6,
  double maxBoxWidth = 64,
}) {
  if (entries.isEmpty || bounds.width <= 0 || bounds.height <= 0) {
    return const [];
  }

  final span = max - min;
  double y(double value) => span == 0
      ? bounds.center.dy
      : bounds.bottom - (value - min) / span * bounds.height;

  final column = bounds.width / entries.length;
  final width = math.min(
    maxBoxWidth,
    column * boxWidthFraction.clamp(0.05, 1.0),
  );

  return [
    for (var i = 0; i < entries.length; i++)
      () {
        final stats = entries[i].stats;
        final centerX = bounds.left + column * (i + 0.5);
        final top = y(stats.q3);
        final bottom = y(stats.q1);
        return BoxPlotBox(
          entry: entries[i],
          index: i,
          band: Rect.fromLTWH(
            bounds.left + column * i,
            bounds.top,
            column,
            bounds.height,
          ),
          rect: Rect.fromLTRB(
            centerX - width / 2,
            math.min(top, bottom),
            centerX + width / 2,
            math.max(top, bottom),
          ),
          medianY: y(stats.median),
          meanY: stats.mean == null ? null : y(stats.mean!),
          lowerY: y(stats.lower),
          upperY: y(stats.upper),
          outlierYs: [for (final value in stats.outliers) y(value)],
        );
      }(),
  ];
}

/// The box whose column holds [local], or null when there is none.
BoxPlotBox? boxPlotBoxAt(List<BoxPlotBox> boxes, Offset local) {
  for (final box in boxes) {
    if (box.contains(local)) return box;
  }
  return null;
}

/// What a touch on a [BoxPlotChart] landed on.
@immutable
class BoxPlotTouchDetails {
  /// Creates the details of a touch on [box].
  const BoxPlotTouchDetails({required this.box});

  /// The box touched.
  final BoxPlotBox box;

  /// The entry it draws.
  BoxPlotEntry get entry => box.entry;

  /// The numbers it draws.
  BoxPlotStats get stats => box.entry.stats;
}

/// The spread of several sets of numbers, side by side — a box plot.
///
/// Each entry is drawn as a box from the first to the third quartile, a line at
/// the median, whiskers out to the furthest ordinary value, and a point for
/// every outlier. It compares distributions: the returns of several strategies,
/// the daily range of several symbols.
///
/// ```dart
/// BoxPlotChart(
///   entries: [
///     BoxPlotEntry.fromSamples(trendReturns, label: 'Trend'),
///     BoxPlotEntry.fromSamples(meanReversionReturns, label: 'Reversion'),
///   ],
/// );
/// ```
///
/// The chart fills the box it is given, and is [defaultHeight] high in a box
/// with no height of its own.
class BoxPlotChart extends StatefulWidget {
  /// Creates a box plot of [entries], left to right.
  const BoxPlotChart({
    super.key,
    required this.entries,
    this.min,
    this.max,
    this.boxWidthFraction = 0.6,
    this.maxBoxWidth = 64,
    this.palette = treemapPalette,
    this.fillOpacity = 0.4,
    this.strokeWidth = 1.5,
    this.medianWidth = 2,
    this.showMean = true,
    this.outlierRadius = 2.5,
    this.whiskerCapFraction = 0.5,
    this.showAxis = true,
    this.axisWidth = 44,
    this.tickCount = 5,
    this.valueFormatter,
    this.axisLabelStyle,
    this.entryLabelStyle,
    this.labelHeight = 18,
    this.gridColor = const Color(0x22FFFFFF),
    this.hoverColor = const Color(0x14FFFFFF),
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

  /// The entries, left to right.
  final List<BoxPlotEntry> entries;

  /// The bottom of the value axis; null reads it off the entries.
  final double? min;

  /// The top of the value axis; null reads it off the entries.
  final double? max;

  /// How much of its column a box takes.
  final double boxWidthFraction;

  /// The widest a box is drawn, however much room there is.
  final double maxBoxWidth;

  /// Colours taken in turn by entries that name none.
  final List<Color> palette;

  /// How opaque a box's fill is; its outline is drawn solid.
  final double fillOpacity;

  /// How thick the box outline and whiskers are.
  final double strokeWidth;

  /// How thick the median line is.
  final double medianWidth;

  /// Whether the mean is marked, when an entry reports one.
  final bool showMean;

  /// How large an outlier point is.
  final double outlierRadius;

  /// How wide a whisker's cap is, as a share of the box width.
  final double whiskerCapFraction;

  /// Whether the value axis is drawn down the left.
  final bool showAxis;

  /// How much room the value axis takes.
  final double axisWidth;

  /// About how many value ticks to write.
  final int tickCount;

  /// Writes a value on the axis and in the default tooltip; null writes at
  /// most two decimals.
  final String Function(double value)? valueFormatter;

  /// Style of a value label.
  final TextStyle? axisLabelStyle;

  /// Style of an entry's name, written under its box.
  final TextStyle? entryLabelStyle;

  /// How much room the entry names take under the boxes; zero writes none.
  final double labelHeight;

  /// Colour of the line ruled across the chart at each tick; null rules none.
  final Color? gridColor;

  /// Painted behind the column under the pointer; null marks none.
  final Color? hoverColor;

  /// Called as a touch moves over the entries, and with null when it leaves.
  final ValueChanged<BoxPlotTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched entry; null shows none.
  final Widget? Function(BuildContext context, BoxPlotTouchDetails details)?
  tooltipBuilder;

  /// How far the card sits from the column.
  final double tooltipMargin;

  /// How long the boxes take to grow out of the median; zero draws them at
  /// once.
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
  State<BoxPlotChart> createState() => _BoxPlotChartState();
}

class _BoxPlotChartState extends State<BoxPlotChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 64);
  List<BoxPlotBox> _boxes = const [];
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
  void didUpdateWidget(BoxPlotChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!identical(oldWidget.entries, widget.entries)) {
      if (_touched != null && _touched! >= widget.entries.length) {
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
    final index = boxPlotBoxAt(_boxes, local)?.index;
    if (index == _touched) return;
    setState(() => _touched = index);
    widget.onTouch?.call(
      index == null ? null : BoxPlotTouchDetails(box: _boxes[index]),
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
    final range = boxPlotRange(widget.entries);
    final min = widget.min ?? range.min;
    final max = widget.max ?? range.max;

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
        final plot = Rect.fromLTRB(
          box.left + (widget.showAxis ? widget.axisWidth : 0),
          box.top,
          box.right,
          math.max(box.top, box.bottom - widget.labelHeight),
        );
        _boxes = layOutBoxPlot(
          widget.entries,
          plot,
          min: min,
          max: max,
          boxWidthFraction: widget.boxWidthFraction,
          maxBoxWidth: widget.maxBoxWidth,
        );

        final touched = _touched;
        final details = touched == null || touched >= _boxes.length
            ? null
            : BoxPlotTouchDetails(box: _boxes[touched]);
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
                      painter: BoxPlotChartPainter(
                        chart: widget,
                        boxes: _boxes,
                        plot: plot,
                        min: min,
                        max: max,
                        touched: details?.box.index,
                        animation: t,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (tooltip != null && details != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomSingleChildLayout(
                          delegate: _BoxPlotTooltipLayout(
                            anchor: details.box.rect,
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

/// Puts the tooltip to the right of the touched box, or to its left when there
/// is no room, kept inside the chart.
class _BoxPlotTooltipLayout extends SingleChildLayoutDelegate {
  _BoxPlotTooltipLayout({required this.anchor, required this.margin});

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
  bool shouldRelayout(_BoxPlotTooltipLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.margin != margin;
}

/// Paints a [BoxPlotChart]: the axis, the boxes, the whiskers and the labels.
class BoxPlotChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [boxes] inside [plot].
  BoxPlotChartPainter({
    required this.chart,
    required this.boxes,
    required this.plot,
    required this.min,
    required this.max,
    required this.touched,
    required this.animation,
    required this.textCache,
  });

  final BoxPlotChart chart;
  final List<BoxPlotBox> boxes;
  final Rect plot;
  final double min;
  final double max;
  final int? touched;
  final double animation;
  final TextPainterCache textCache;

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (boxes.isEmpty) return;

    _paintAxis(canvas);

    final hover = chart.hoverColor;
    final at = touched;
    if (at != null && at < boxes.length && hover != null) {
      canvas.drawRect(boxes[at].band, Paint()..color = hover);
    }

    final t = animation.clamp(0.0, 1.0);
    for (final box in boxes) {
      _paintBox(canvas, box, t);
      if (chart.labelHeight > 0) _paintName(canvas, box);
    }
  }

  void _paintAxis(Canvas canvas) {
    final grid = chart.gridColor;
    if (!chart.showAxis && grid == null) return;
    final ticks = niceTicks(min, max, target: chart.tickCount);
    if (ticks.isEmpty) return;

    final span = max - min;
    final style = seriesAxisLabelStyle.merge(chart.axisLabelStyle);
    final line = grid == null
        ? null
        : (Paint()
            ..color = grid
            ..strokeWidth = 1);

    for (final tick in ticks) {
      final y = span == 0
          ? plot.center.dy
          : plot.bottom - (tick - min) / span * plot.height;
      if (line != null) {
        canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), line);
      }
      if (!chart.showAxis) continue;
      final tp = textCache.get(_format(tick), style);
      final left = plot.left - 6 - tp.width;
      if (left < 0) continue;
      tp.paint(canvas, Offset(left, y - tp.height / 2));
    }
  }

  void _paintBox(Canvas canvas, BoxPlotBox box, double t) {
    final color = _colorOf(box);
    final centerX = box.centerX;
    final median = box.medianY;

    // The box grows out of the median, and the whiskers out of the box.
    double from(double y) => median + (y - median) * t;
    final rect = Rect.fromLTRB(
      box.rect.left,
      from(box.rect.top),
      box.rect.right,
      from(box.rect.bottom),
    );

    final fill = Paint()
      ..color = color.withValues(alpha: chart.fillOpacity.clamp(0.0, 1.0))
      ..isAntiAlias = true;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = chart.strokeWidth
      ..color = color
      ..isAntiAlias = true;

    final cap = box.rect.width * chart.whiskerCapFraction.clamp(0.0, 1.0) / 2;
    final upper = from(box.upperY);
    final lower = from(box.lowerY);
    canvas
      ..drawLine(Offset(centerX, upper), Offset(centerX, rect.top), stroke)
      ..drawLine(Offset(centerX, rect.bottom), Offset(centerX, lower), stroke)
      ..drawLine(
        Offset(centerX - cap, upper),
        Offset(centerX + cap, upper),
        stroke,
      )
      ..drawLine(
        Offset(centerX - cap, lower),
        Offset(centerX + cap, lower),
        stroke,
      )
      ..drawRect(rect, fill)
      ..drawRect(rect, stroke)
      ..drawLine(
        Offset(rect.left, median),
        Offset(rect.right, median),
        Paint()
          ..strokeWidth = chart.medianWidth
          ..color = color
          ..isAntiAlias = true,
      );

    final mean = box.meanY;
    if (chart.showMean && mean != null) {
      final at = Offset(centerX, from(mean));
      final pen = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = chart.strokeWidth
        ..color = color
        ..isAntiAlias = true;
      final arm = math.max(3.0, box.rect.width / 8);
      canvas
        ..drawLine(at - Offset(arm, arm), at + Offset(arm, arm), pen)
        ..drawLine(at - Offset(-arm, arm), at + Offset(-arm, arm), pen);
    }

    final dot = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = chart.strokeWidth
      ..color = color
      ..isAntiAlias = true;
    for (final y in box.outlierYs) {
      canvas.drawCircle(Offset(centerX, from(y)), chart.outlierRadius, dot);
    }
  }

  void _paintName(Canvas canvas, BoxPlotBox box) {
    final name = box.entry.label;
    if (name == null || name.isEmpty) return;
    final style = seriesAxisLabelStyle.merge(chart.entryLabelStyle);
    final tp = textCache.get(name, style);
    if (tp.width > box.band.width) return;
    tp.paint(canvas, Offset(box.centerX - tp.width / 2, plot.bottom + 3));
  }

  Color _colorOf(BoxPlotBox box) {
    final own = box.entry.color;
    if (own != null) return own;
    final palette = chart.palette;
    if (palette.isEmpty) return const Color(0xFF4C86CD);
    return palette[box.index % palette.length];
  }

  String _format(double value) {
    final format = chart.valueFormatter;
    if (format != null) return format(value);
    final rounded = double.parse(value.toStringAsFixed(2));
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toString();
  }

  @override
  bool shouldRepaint(BoxPlotChartPainter oldDelegate) =>
      !identical(oldDelegate.chart, chart) ||
      !identical(oldDelegate.boxes, boxes) ||
      oldDelegate.plot != plot ||
      oldDelegate.min != min ||
      oldDelegate.max != max ||
      oldDelegate.touched != touched ||
      oldDelegate.animation != animation;
}
