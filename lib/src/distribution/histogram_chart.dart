import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';
import '../series/series_axis.dart';
import '../utils/axis_ticks.dart';

/// One bar of a [HistogramChart]: how many samples fell in a range.
@immutable
class HistogramBin {
  /// Creates the bin holding the samples from [from] up to [to].
  const HistogramBin({
    required this.from,
    required this.to,
    required this.count,
    this.color,
    this.data,
  });

  /// The bottom of the range, included.
  final double from;

  /// The top of the range; excluded, except in the last bin.
  final double to;

  /// How many samples fell in it.
  final double count;

  /// A colour of this bin's own.
  final Color? color;

  /// Anything the app wants back when this bin is touched.
  final Object? data;

  /// The middle of the range.
  double get center => (from + to) / 2;

  /// How wide the range is.
  double get width => to - from;
}

/// Counts [samples] into bins of equal width.
///
/// The range is [min] to [max], or the samples' own range when either is null.
/// Either [binCount] or [binWidth] sets how finely it is cut; with neither,
/// the count is the square root of the number of samples, which is the usual
/// rule of thumb. Samples outside the range are dropped, and a sample landing
/// exactly on a boundary goes into the bin above it — except at the top, where
/// the last bin includes its own upper edge.
List<HistogramBin> histogramBins(
  Iterable<double> samples, {
  int? binCount,
  double? binWidth,
  double? min,
  double? max,
}) {
  final values = [
    for (final value in samples)
      if (value.isFinite) value,
  ];
  if (values.isEmpty) return const [];

  var low = min ?? values.reduce(math.min);
  var high = max ?? values.reduce(math.max);
  if (!low.isFinite || !high.isFinite || high < low) return const [];
  if (high == low) {
    low -= 0.5;
    high += 0.5;
  }

  final int count;
  if (binWidth != null && binWidth > 0) {
    count = math.max(1, ((high - low) / binWidth).ceil());
    high = low + count * binWidth;
  } else {
    count = math.max(1, binCount ?? math.sqrt(values.length).round());
  }
  final width = (high - low) / count;
  if (width <= 0) return const [];

  final counts = List<double>.filled(count, 0);
  for (final value in values) {
    if (value < low || value > high) continue;
    final at = ((value - low) / width).floor();
    counts[at.clamp(0, count - 1)] += 1;
  }

  return [
    for (var i = 0; i < count; i++)
      HistogramBin(
        from: low + i * width,
        to: low + (i + 1) * width,
        count: counts[i],
      ),
  ];
}

/// Where one [HistogramBin] was laid out.
@immutable
class HistogramBar {
  /// Creates the bar of [bin].
  const HistogramBar({
    required this.bin,
    required this.index,
    required this.rect,
    required this.band,
  });

  /// The bin this bar draws.
  final HistogramBin bin;

  /// Its position along the chart, from the left.
  final int index;

  /// The bar itself, standing on the baseline.
  final Rect rect;

  /// The full column the bin owns; what a touch is tested against.
  final Rect band;

  /// Whether [local] is inside the bin's column.
  bool contains(Offset local) => band.contains(local);
}

/// Lays [bins] out across [bounds], the tallest reaching [maxCount].
///
/// Bars sit where their range falls along the value axis, so bins of unequal
/// width draw at unequal widths. [barSpacing] pixels are taken off each side.
List<HistogramBar> layOutHistogram(
  List<HistogramBin> bins,
  Rect bounds, {
  required double maxCount,
  double barSpacing = 1,
}) {
  if (bins.isEmpty || bounds.width <= 0 || bounds.height <= 0) {
    return const [];
  }

  var low = double.infinity;
  var high = double.negativeInfinity;
  for (final bin in bins) {
    low = math.min(low, bin.from);
    high = math.max(high, bin.to);
  }
  if (!low.isFinite || !high.isFinite || high <= low) return const [];

  final span = high - low;
  double x(double value) => bounds.left + (value - low) / span * bounds.width;
  final top = maxCount <= 0 ? 0.0 : bounds.height;
  final gap = math.max(0.0, barSpacing);

  return [
    for (var i = 0; i < bins.length; i++)
      () {
        final bin = bins[i];
        final left = x(bin.from);
        final right = x(bin.to);
        final height = maxCount <= 0
            ? 0.0
            : (bin.count / maxCount).clamp(0.0, 1.0) * top;
        return HistogramBar(
          bin: bin,
          index: i,
          rect: Rect.fromLTRB(
            math.min(left + gap, right),
            bounds.bottom - height,
            math.max(right - gap, left),
            bounds.bottom,
          ),
          band: Rect.fromLTRB(left, bounds.top, right, bounds.bottom),
        );
      }(),
  ];
}

/// The bar whose column holds [local], or null when there is none.
HistogramBar? histogramBarAt(List<HistogramBar> bars, Offset local) {
  for (final bar in bars) {
    if (bar.contains(local)) return bar;
  }
  return null;
}

/// What a touch on a [HistogramChart] landed on.
@immutable
class HistogramTouchDetails {
  /// Creates the details of a touch on [bar].
  const HistogramTouchDetails({required this.bar});

  /// The bar touched.
  final HistogramBar bar;

  /// The bin it draws.
  HistogramBin get bin => bar.bin;
}

/// How often values fall in each part of their range — a histogram.
///
/// It shows the shape of a distribution: where returns cluster, how fat the
/// tails are, when trades happen.
///
/// ```dart
/// HistogramChart(bins: histogramBins(dailyReturns, binCount: 24));
/// ```
///
/// The chart fills the box it is given, and is [defaultHeight] high in a box
/// with no height of its own.
class HistogramChart extends StatefulWidget {
  /// Creates a histogram of [bins], left to right.
  const HistogramChart({
    super.key,
    required this.bins,
    this.maxCount,
    this.barColor = const Color(0xFF4C86CD),
    this.negativeColor,
    this.barSpacing = 1,
    this.barRadius = 1,
    this.showValueAxis = true,
    this.showCountAxis = true,
    this.countAxisWidth = 40,
    this.valueAxisHeight = 18,
    this.tickCount = 5,
    this.valueFormatter,
    this.countFormatter,
    this.axisLabelStyle,
    this.gridColor = const Color(0x22FFFFFF),
    this.referenceLines = const [],
    this.referenceColor = const Color(0x66FFFFFF),
    this.hoverColor = const Color(0x14FFFFFF),
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

  /// The bins, in order along the value axis.
  final List<HistogramBin> bins;

  /// What a full-height bar counts; null takes the largest bin.
  final double? maxCount;

  /// The colour of a bar that names none.
  final Color barColor;

  /// The colour of a bar whose range lies below zero; null uses [barColor], so
  /// a returns histogram can be red on the left and green on the right.
  final Color? negativeColor;

  /// How many pixels are taken off each side of a bar.
  final double barSpacing;

  /// How rounded the top corners of a bar are.
  final double barRadius;

  /// Whether the value axis is written along the bottom.
  final bool showValueAxis;

  /// Whether the count axis is written down the left.
  final bool showCountAxis;

  /// How much room the count axis takes.
  final double countAxisWidth;

  /// How much room the value axis takes.
  final double valueAxisHeight;

  /// About how many ticks to write on each axis.
  final int tickCount;

  /// Writes a value on the bottom axis; null writes at most two decimals.
  final String Function(double value)? valueFormatter;

  /// Writes a count on the left axis; null writes whole numbers.
  final String Function(double count)? countFormatter;

  /// Style of an axis label.
  final TextStyle? axisLabelStyle;

  /// Colour of the line ruled across the chart at each count tick; null rules
  /// none.
  final Color? gridColor;

  /// Values marked with a vertical line — zero, the mean, a target.
  final List<double> referenceLines;

  /// The colour of those lines.
  final Color referenceColor;

  /// Painted behind the column under the pointer; null marks none.
  final Color? hoverColor;

  /// Called as a touch moves over the bars, and with null when it leaves.
  final ValueChanged<HistogramTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched bar; null shows none.
  final Widget? Function(BuildContext context, HistogramTouchDetails details)?
  tooltipBuilder;

  /// How far the card sits from the bar.
  final double tooltipMargin;

  /// How long the bars take to grow up; zero draws them at once.
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
  State<HistogramChart> createState() => _HistogramChartState();
}

class _HistogramChartState extends State<HistogramChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 64);
  List<HistogramBar> _bars = const [];
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
  void didUpdateWidget(HistogramChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!identical(oldWidget.bins, widget.bins)) {
      if (_touched != null && _touched! >= widget.bins.length) _touched = null;
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
    final index = histogramBarAt(_bars, local)?.index;
    if (index == _touched) return;
    setState(() => _touched = index);
    widget.onTouch?.call(
      index == null ? null : HistogramTouchDetails(bar: _bars[index]),
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
    var tallest = widget.maxCount ?? 0;
    if (widget.maxCount == null) {
      for (final bin in widget.bins) {
        tallest = math.max(tallest, bin.count);
      }
    }

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
          box.left + (widget.showCountAxis ? widget.countAxisWidth : 0),
          box.top,
          box.right,
          math.max(
            box.top,
            box.bottom - (widget.showValueAxis ? widget.valueAxisHeight : 0),
          ),
        );
        _bars = layOutHistogram(
          widget.bins,
          plot,
          maxCount: tallest,
          barSpacing: widget.barSpacing,
        );

        final touched = _touched;
        final details = touched == null || touched >= _bars.length
            ? null
            : HistogramTouchDetails(bar: _bars[touched]);
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
                      painter: HistogramChartPainter(
                        chart: widget,
                        bars: _bars,
                        plot: plot,
                        maxCount: tallest,
                        touched: details?.bar.index,
                        animation: t,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (tooltip != null && details != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomSingleChildLayout(
                          delegate: _HistogramTooltipLayout(
                            anchor: details.bar.rect,
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

/// Puts the tooltip above the touched bar, or below it when there is no room,
/// kept inside the chart.
class _HistogramTooltipLayout extends SingleChildLayoutDelegate {
  _HistogramTooltipLayout({required this.anchor, required this.margin});

  final Rect anchor;
  final double margin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var top = anchor.top - margin - childSize.height;
    if (top < 0) top = anchor.top + margin;
    return Offset(
      (anchor.center.dx - childSize.width / 2).clamp(
        0.0,
        math.max(0.0, size.width - childSize.width),
      ),
      top.clamp(0.0, math.max(0.0, size.height - childSize.height)),
    );
  }

  @override
  bool shouldRelayout(_HistogramTooltipLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.margin != margin;
}

/// Paints a [HistogramChart]: the axes, the grid and the bars.
class HistogramChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [bars] inside [plot].
  HistogramChartPainter({
    required this.chart,
    required this.bars,
    required this.plot,
    required this.maxCount,
    required this.touched,
    required this.animation,
    required this.textCache,
  });

  final HistogramChart chart;
  final List<HistogramBar> bars;
  final Rect plot;
  final double maxCount;
  final int? touched;
  final double animation;
  final TextPainterCache textCache;

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (bars.isEmpty) return;

    _paintCountAxis(canvas);

    final hover = chart.hoverColor;
    final at = touched;
    if (at != null && at < bars.length && hover != null) {
      canvas.drawRect(bars[at].band, Paint()..color = hover);
    }

    final t = animation.clamp(0.0, 1.0);
    final fill = Paint()..isAntiAlias = true;
    final radius = Radius.circular(math.max(0, chart.barRadius));
    for (final bar in bars) {
      if (bar.rect.width <= 0) continue;
      fill.color = _colorOf(bar);
      final rect = Rect.fromLTRB(
        bar.rect.left,
        bar.rect.bottom - bar.rect.height * t,
        bar.rect.right,
        bar.rect.bottom,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(rect, topLeft: radius, topRight: radius),
        fill,
      );
    }

    _paintReferenceLines(canvas);
    _paintValueAxis(canvas);
  }

  Color _colorOf(HistogramBar bar) {
    final own = bar.bin.color;
    if (own != null) return own;
    final negative = chart.negativeColor;
    if (negative != null && bar.bin.center < 0) return negative;
    return chart.barColor;
  }

  void _paintCountAxis(Canvas canvas) {
    final grid = chart.gridColor;
    if (!chart.showCountAxis && grid == null) return;
    final ticks = niceTicks(0, maxCount, target: chart.tickCount);
    if (ticks.isEmpty) return;

    final style = seriesAxisLabelStyle.merge(chart.axisLabelStyle);
    final line = grid == null
        ? null
        : (Paint()
            ..color = grid
            ..strokeWidth = 1);

    for (final tick in ticks) {
      final y = plot.bottom - (tick / maxCount).clamp(0.0, 1.0) * plot.height;
      if (line != null) {
        canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), line);
      }
      if (!chart.showCountAxis) continue;
      final tp = textCache.get(_formatCount(tick), style);
      final left = plot.left - 6 - tp.width;
      if (left < 0) continue;
      tp.paint(canvas, Offset(left, y - tp.height / 2));
    }
  }

  void _paintValueAxis(Canvas canvas) {
    if (!chart.showValueAxis) return;
    final low = bars.first.bin.from;
    final high = bars.last.bin.to;
    final ticks = niceTicks(low, high, target: chart.tickCount);
    if (ticks.isEmpty || high <= low) return;

    final style = seriesAxisLabelStyle.merge(chart.axisLabelStyle);
    var written = -double.infinity;
    for (final tick in ticks) {
      final x = plot.left + (tick - low) / (high - low) * plot.width;
      final tp = textCache.get(_formatValue(tick), style);
      final left = x - tp.width / 2;
      if (left < written || left + tp.width > plot.right) continue;
      tp.paint(canvas, Offset(left, plot.bottom + 3));
      written = left + tp.width + 4;
    }
  }

  void _paintReferenceLines(Canvas canvas) {
    if (chart.referenceLines.isEmpty) return;
    final low = bars.first.bin.from;
    final high = bars.last.bin.to;
    if (high <= low) return;
    final pen = Paint()
      ..color = chart.referenceColor
      ..strokeWidth = 1;
    for (final value in chart.referenceLines) {
      if (!value.isFinite || value < low || value > high) continue;
      final x = plot.left + (value - low) / (high - low) * plot.width;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), pen);
    }
  }

  String _formatValue(double value) {
    final format = chart.valueFormatter;
    if (format != null) return format(value);
    final rounded = double.parse(value.toStringAsFixed(2));
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toString();
  }

  String _formatCount(double count) {
    final format = chart.countFormatter;
    if (format != null) return format(count);
    return count.round().toString();
  }

  @override
  bool shouldRepaint(HistogramChartPainter oldDelegate) =>
      !identical(oldDelegate.chart, chart) ||
      !identical(oldDelegate.bars, bars) ||
      oldDelegate.plot != plot ||
      oldDelegate.maxCount != maxCount ||
      oldDelegate.touched != touched ||
      oldDelegate.animation != animation;
}
