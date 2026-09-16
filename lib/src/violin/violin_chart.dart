import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../distribution/box_plot_chart.dart';
import '../renderer/text_painter_cache.dart';

/// A distribution estimated at evenly spaced points — the shape of a violin.
@immutable
class DensityCurve {
  /// Creates a curve of [densities] evenly spaced from [min] to [max].
  const DensityCurve({
    required this.min,
    required this.max,
    required this.densities,
  });

  /// Nothing at all.
  static const empty = DensityCurve(min: 0, max: 0, densities: []);

  /// The value the curve starts at.
  final double min;

  /// The value it ends at.
  final double max;

  /// How dense the samples are at each point, from [min] to [max].
  final List<double> densities;

  /// Whether there is anything to draw.
  bool get isEmpty => densities.isEmpty || !(max > min);

  /// The largest density on the curve.
  double get peak =>
      densities.isEmpty ? 0 : densities.reduce((a, b) => a > b ? a : b);

  /// The value at point [index] of the curve.
  double valueAt(int index) {
    if (densities.length <= 1) return min;
    return min + (max - min) * index / (densities.length - 1);
  }
}

/// Estimates the shape of [samples] as a smooth curve.
///
/// A Gaussian kernel is laid over every sample and the curves are added up.
/// [bandwidth] is how wide each of those kernels is; left out, it is Silverman's
/// rule of thumb, which fits most distributions without being told anything
/// about them. [points] is how finely the curve is sampled, and [cut] widens
/// the range past the samples by that many bandwidths, so the tails close
/// rather than being chopped off at the outermost sample.
DensityCurve kernelDensity(
  Iterable<double> samples, {
  double? bandwidth,
  int points = 64,
  double cut = 1.5,
  double? min,
  double? max,
}) {
  final values = [
    for (final value in samples)
      if (value.isFinite) value,
  ]..sort();
  if (values.isEmpty || points < 2) return DensityCurve.empty;

  final n = values.length;
  final mean = values.reduce((a, b) => a + b) / n;
  var variance = 0.0;
  for (final value in values) {
    variance += (value - mean) * (value - mean);
  }
  final deviation = n > 1 ? math.sqrt(variance / (n - 1)) : 0.0;
  final q1 = _quantile(values, 0.25);
  final q3 = _quantile(values, 0.75);
  final spread = math.min(
    deviation == 0 ? double.infinity : deviation,
    (q3 - q1) == 0 ? double.infinity : (q3 - q1) / 1.349,
  );
  var width = bandwidth ??
      (spread.isFinite && spread > 0
          ? 0.9 * spread * math.pow(n, -1 / 5).toDouble()
          : 0.0);
  if (!(width > 0)) {
    // Every sample the same: give the spike a width to be seen at all.
    width = (values.first.abs() * 0.01).clamp(1e-9, double.maxFinite);
  }

  final low = min ?? values.first - cut * width;
  final high = max ?? values.last + cut * width;
  if (!(high > low)) return DensityCurve.empty;

  final densities = List<double>.filled(points, 0);
  final scale = 1 / (n * width * math.sqrt(2 * math.pi));
  for (var i = 0; i < points; i++) {
    final at = low + (high - low) * i / (points - 1);
    var sum = 0.0;
    for (final value in values) {
      final z = (at - value) / width;
      // Kernels four bandwidths out add nothing worth the multiplication.
      if (z.abs() > 4) continue;
      sum += math.exp(-0.5 * z * z);
    }
    densities[i] = sum * scale;
  }
  return DensityCurve(min: low, max: high, densities: densities);
}

double _quantile(List<double> sorted, double p) {
  if (sorted.isEmpty) return 0;
  final at = p * (sorted.length - 1);
  final low = at.floor(), high = at.ceil();
  if (low == high) return sorted[low];
  return sorted[low] + (sorted[high] - sorted[low]) * (at - low);
}

/// One distribution in a [ViolinChart].
@immutable
class ViolinSeries {
  /// Creates a distribution called [label] from [samples].
  const ViolinSeries({
    required this.label,
    required this.samples,
    this.color,
    this.curve,
    this.stats,
    this.tooltip,
  });

  /// What the distribution is called.
  final String label;

  /// The numbers it is drawn from.
  final List<double> samples;

  /// What it is painted in; null takes a colour from the chart's palette.
  final Color? color;

  /// Its shape, worked out already; null estimates it from [samples].
  final DensityCurve? curve;

  /// Its quartiles, worked out already; null takes them from [samples].
  final BoxPlotStats? stats;

  /// Shown when it is touched; null shows its label and median.
  final String? tooltip;

  /// Its shape, estimated if it was not given.
  DensityCurve resolvedCurve({double? bandwidth, int points = 64}) =>
      curve ?? kernelDensity(samples, bandwidth: bandwidth, points: points);

  /// Its quartiles, worked out if they were not given.
  BoxPlotStats resolvedStats() => stats ?? BoxPlotStats.fromSamples(samples);
}

/// Whether a [ViolinChart] draws violins or a ridgeline.
enum ViolinShape {
  /// A symmetric shape per series, side by side across the chart.
  violin,

  /// Half a shape per series, stacked down the chart and overlapping — a
  /// ridgeline, or a joy plot.
  ridgeline,
}

/// Where one distribution of a [ViolinChart] sits.
@immutable
class ViolinSeriesLayout {
  /// Creates the layout of the series at [index].
  const ViolinSeriesLayout({
    required this.index,
    required this.series,
    required this.bandRect,
    required this.outline,
    required this.curve,
    required this.stats,
    required this.medianAt,
    required this.boxRect,
    required this.whiskerFrom,
    required this.whiskerTo,
  });

  /// Which series this is, into the chart's series.
  final int index;

  /// The series itself.
  final ViolinSeries series;

  /// The band of the chart it owns.
  final Rect bandRect;

  /// Its shape, as a closed path.
  final Path outline;

  /// The density curve that shape was drawn from.
  final DensityCurve curve;

  /// Its quartiles.
  final BoxPlotStats stats;

  /// Where the median sits.
  final Offset medianAt;

  /// The quartile box drawn inside a violin; null on a ridgeline.
  final Rect? boxRect;

  /// The lower whisker's end.
  final Offset whiskerFrom;

  /// The upper whisker's end.
  final Offset whiskerTo;

  /// Whether [point] falls in the series' band.
  bool hit(Offset point) => bandRect.contains(point);
}

/// Where every distribution of a [ViolinChart] sits.
@immutable
class ViolinLayout {
  /// Creates a laid-out chart.
  const ViolinLayout({
    required this.size,
    required this.plotRect,
    required this.series,
    required this.min,
    required this.max,
    required this.shape,
  });

  /// Nothing to draw.
  static const empty = ViolinLayout(
    size: Size.zero,
    plotRect: Rect.zero,
    series: [],
    min: 0,
    max: 0,
    shape: ViolinShape.violin,
  );

  /// The box the chart was laid out in.
  final Size size;

  /// The part of it the shapes are drawn in.
  final Rect plotRect;

  /// The distributions, in the order they were given.
  final List<ViolinSeriesLayout> series;

  /// The smallest value on the shared value axis.
  final double min;

  /// The largest.
  final double max;

  /// Which way the chart was drawn.
  final ViolinShape shape;

  /// Whether there is anything to draw.
  bool get isEmpty => series.isEmpty;

  /// Where [value] falls on the value axis — down the chart for violins,
  /// across it for a ridgeline.
  double positionOf(double value) {
    final span = max - min;
    if (!(span > 0) || !value.isFinite) {
      return shape == ViolinShape.violin ? plotRect.bottom : plotRect.left;
    }
    final fraction = ((value - min) / span).clamp(0.0, 1.0);
    return shape == ViolinShape.violin
        ? plotRect.bottom - fraction * plotRect.height
        : plotRect.left + fraction * plotRect.width;
  }

  /// The series under [point]; null when none is.
  ViolinSeriesLayout? seriesAt(Offset point) {
    // Backwards, so the front shape of an overlapping ridgeline wins.
    for (final laid in series.reversed) {
      if (laid.hit(point)) return laid;
    }
    return null;
  }
}

/// Lays out [series] in [size] as violins or a ridgeline.
///
/// [progress] runs from 0 to 1 and grows the shapes out of their centre line,
/// for a draw-in animation.
ViolinLayout layOutViolin(
  List<ViolinSeries> series, {
  required Size size,
  ViolinShape shape = ViolinShape.violin,
  double? bandwidth,
  int points = 64,
  double? min,
  double? max,
  double bandPadding = 0.12,
  double overlap = 0.55,
  double labelWidth = 0,
  double axisHeight = 0,
  EdgeInsets padding = EdgeInsets.zero,
  double progress = 1,
}) {
  if (series.isEmpty) return ViolinLayout.empty;
  final box = padding.deflateRect(Offset.zero & size);
  if (box.width <= 0 || box.height <= 0) return ViolinLayout.empty;

  final plot = Rect.fromLTRB(
    box.left + math.max(0, labelWidth),
    box.top,
    box.right,
    math.max(box.top, box.bottom - math.max(0, axisHeight)),
  );
  if (plot.width <= 0 || plot.height <= 0) return ViolinLayout.empty;

  final curves = [
    for (final one in series)
      one.resolvedCurve(bandwidth: bandwidth, points: points),
  ];
  final stats = [for (final one in series) one.resolvedStats()];

  var low = min, high = max;
  if (low == null || high == null) {
    var lo = double.infinity, hi = double.negativeInfinity;
    for (var i = 0; i < series.length; i++) {
      if (curves[i].isEmpty) continue;
      lo = math.min(lo, curves[i].min);
      hi = math.max(hi, curves[i].max);
    }
    if (!lo.isFinite || !hi.isFinite) return ViolinLayout.empty;
    low ??= lo;
    high ??= hi;
  }
  if (!(high > low)) high = low + 1;

  final laidOut = ViolinLayout(
    size: size,
    plotRect: plot,
    series: const [],
    min: low,
    max: high,
    shape: shape,
  );
  final t = progress.clamp(0.0, 1.0);

  // Every shape is measured against the tallest peak, so their areas stay
  // comparable: a wide violin really does hold more samples.
  var tallest = 0.0;
  for (final curve in curves) {
    tallest = math.max(tallest, curve.peak);
  }
  if (!(tallest > 0)) return ViolinLayout.empty;

  final count = series.length;
  final laid = <ViolinSeriesLayout>[];
  for (var i = 0; i < count; i++) {
    final curve = curves[i];
    final Rect band;
    if (shape == ViolinShape.violin) {
      final width = plot.width / count;
      band = Rect.fromLTWH(plot.left + i * width, plot.top, width, plot.height);
    } else {
      // Ridgelines overlap: each row is taller than its share of the height.
      final step = count == 1 ? plot.height : plot.height / count;
      final height = step * (1 + overlap.clamp(0.0, 3.0));
      final top = plot.top + i * step - (height - step);
      band = Rect.fromLTWH(plot.left, top, plot.width, height);
    }

    final path = Path();
    if (!curve.isEmpty) {
      if (shape == ViolinShape.violin) {
        final centerX = band.center.dx;
        final half = band.width * (0.5 - bandPadding.clamp(0.0, 0.45)) * t;
        final right = <Offset>[];
        for (var p = 0; p < curve.densities.length; p++) {
          final y = laidOut.positionOf(curve.valueAt(p));
          right.add(Offset(centerX + curve.densities[p] / tallest * half, y));
        }
        path.moveTo(centerX, right.first.dy);
        for (final at in right) {
          path.lineTo(at.dx, at.dy);
        }
        for (final at in right.reversed) {
          path.lineTo(centerX - (at.dx - centerX), at.dy);
        }
        path.close();
      } else {
        final baseline = band.bottom;
        final height = band.height * (1 - bandPadding.clamp(0.0, 0.45)) * t;
        path.moveTo(laidOut.positionOf(curve.valueAt(0)), baseline);
        for (var p = 0; p < curve.densities.length; p++) {
          path.lineTo(
            laidOut.positionOf(curve.valueAt(p)),
            baseline - curve.densities[p] / tallest * height,
          );
        }
        path.lineTo(
          laidOut.positionOf(curve.valueAt(curve.densities.length - 1)),
          baseline,
        );
        path.close();
      }
    }

    final summary = stats[i];
    final Offset medianAt, whiskerFrom, whiskerTo;
    Rect? boxRect;
    if (shape == ViolinShape.violin) {
      final x = band.center.dx;
      medianAt = Offset(x, laidOut.positionOf(summary.median));
      whiskerFrom = Offset(x, laidOut.positionOf(summary.lower));
      whiskerTo = Offset(x, laidOut.positionOf(summary.upper));
      final boxWidth = math.max(3.0, band.width * 0.08);
      boxRect = Rect.fromLTRB(
        x - boxWidth / 2,
        laidOut.positionOf(summary.q3),
        x + boxWidth / 2,
        laidOut.positionOf(summary.q1),
      );
    } else {
      final y = band.bottom;
      medianAt = Offset(laidOut.positionOf(summary.median), y);
      whiskerFrom = Offset(laidOut.positionOf(summary.lower), y);
      whiskerTo = Offset(laidOut.positionOf(summary.upper), y);
    }

    laid.add(
      ViolinSeriesLayout(
        index: i,
        series: series[i],
        bandRect: band,
        outline: path,
        curve: curve,
        stats: summary,
        medianAt: medianAt,
        boxRect: boxRect,
        whiskerFrom: whiskerFrom,
        whiskerTo: whiskerTo,
      ),
    );
  }

  return ViolinLayout(
    size: size,
    plotRect: plot,
    series: laid,
    min: low,
    max: high,
    shape: shape,
  );
}

/// The shape of a distribution — a violin chart, or a ridgeline.
///
/// A box plot says where the quartiles are; a violin says what the
/// distribution actually looks like between them. Two strategies with the same
/// median and the same spread can have very different shapes, and this is the
/// chart that shows it.
///
/// ```dart
/// ViolinChart(
///   series: [
///     ViolinSeries(label: 'Trend', samples: trendReturns),
///     ViolinSeries(label: 'Mean revert', samples: revertReturns),
///   ],
/// );
/// ```
class ViolinChart extends StatefulWidget {
  /// Creates a violin chart of [series].
  const ViolinChart({
    super.key,
    required this.series,
    this.shape = ViolinShape.violin,
    this.bandwidth,
    this.points = 64,
    this.min,
    this.max,
    this.palette = defaultPalette,
    this.fillOpacity = 0.45,
    this.outlineWidth = 1.5,
    this.showBox = true,
    this.showMedian = true,
    this.medianColor = const Color(0xFFE9ECEF),
    this.boxColor = const Color(0xCC1B1D22),
    this.bandPadding = 0.12,
    this.overlap = 0.55,
    this.showLabels = true,
    this.labelWidth = 72,
    this.labelHeight = 18,
    this.labelStyle,
    this.showAxis = true,
    this.axisWidth = 44,
    this.axisHeight = 20,
    this.tickCount = 4,
    this.axisStyle,
    this.axisFormatter,
    this.gridColor = const Color(0x14909196),
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.onSeriesTap,
    this.tooltipBuilder,
    this.defaultHeight = 260,
    this.semanticLabel,
  });

  /// The distributions, in the order they were given.
  final List<ViolinSeries> series;

  /// Whether they are drawn as violins side by side or as a stacked ridgeline.
  final ViolinShape shape;

  /// How wide the kernel over each sample is; null uses Silverman's rule.
  final double? bandwidth;

  /// How finely each shape is sampled.
  final int points;

  /// The smallest value on the shared axis; null works it out.
  final double? min;

  /// The largest; null works it out.
  final double? max;

  /// Colours handed to series that name none, in order.
  final List<Color> palette;

  /// The colours used where a series names none.
  static const defaultPalette = [
    Color(0xFF4C86CD),
    Color(0xFF2F9E44),
    Color(0xFFE8590C),
    Color(0xFF9C36B5),
    Color(0xFF0CA678),
    Color(0xFFE03131),
  ];

  /// How solid the shapes are painted.
  final double fillOpacity;

  /// How thick their outline is; 0 draws none.
  final double outlineWidth;

  /// Whether the quartile box and whiskers are drawn inside each violin.
  final bool showBox;

  /// Whether the median is marked.
  final bool showMedian;

  /// What the median mark is painted in.
  final Color medianColor;

  /// What the quartile box is painted in.
  final Color boxColor;

  /// How much of a band is left clear around its shape, from 0 to 0.45.
  final double bandPadding;

  /// How far a ridgeline's rows overlap their neighbours.
  final double overlap;

  /// Whether the series are labelled.
  final bool showLabels;

  /// How wide the label column of a ridgeline is.
  final double labelWidth;

  /// How much room the names under a violin take.
  final double labelHeight;

  /// Style of the series labels.
  final TextStyle? labelStyle;

  /// Whether the value axis is written.
  final bool showAxis;

  /// How much room it takes down the side of a violin chart.
  final double axisWidth;

  /// How much room it takes along the bottom of a ridgeline.
  final double axisHeight;

  /// How many gaps it is divided into; 0 draws no gridlines.
  final int tickCount;

  /// Style of the axis labels.
  final TextStyle? axisStyle;

  /// Writes an axis label; null writes the value with as few decimals as it
  /// needs.
  final String Function(double value)? axisFormatter;

  /// The gridlines behind the shapes.
  final Color gridColor;

  /// Space kept clear around the chart.
  final EdgeInsets padding;

  /// Painted behind the whole chart.
  final Color? backgroundColor;

  /// How long the shapes take to grow out; zero draws them at once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build grows the shapes out.
  final bool animateOnMount;

  /// Called with a series when it is touched, and with null when the touch
  /// leaves the shapes.
  final void Function(ViolinSeries? series)? onSeriesTap;

  /// Builds the card shown over a touched series; null shows its label and
  /// quartiles.
  final Widget Function(
    BuildContext context,
    ViolinSeries series,
    BoxPlotStats stats,
  )? tooltipBuilder;

  /// How tall the chart is in a box that sets no height.
  final double defaultHeight;

  /// What a screen reader announces for the chart.
  final String? semanticLabel;

  @override
  State<ViolinChart> createState() => _ViolinChartState();
}

class _ViolinChartState extends State<ViolinChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 128);
  ViolinLayout _layout = ViolinLayout.empty;
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
  void didUpdateWidget(ViolinChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!identical(oldWidget.series, widget.series) &&
        widget.animationDuration > Duration.zero) {
      _animation.forward(from: 0);
    }
    if (_touched != null && _touched! >= widget.series.length) _touched = null;
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void _touch(Offset point) {
    final found = _layout.seriesAt(point);
    if (found?.index == _touched) return;
    setState(() => _touched = found?.index);
    widget.onSeriesTap?.call(found?.series);
  }

  void _clear() {
    if (_touched == null) return;
    setState(() => _touched = null);
    widget.onSeriesTap?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.animationCurve.transform(_animation.value);

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width =
              constraints.hasBoundedWidth ? constraints.maxWidth : 420.0;
          final height =
              constraints.hasBoundedHeight && constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : widget.defaultHeight;
          _layout = layOutViolin(
            widget.series,
            size: Size(width, height),
            shape: widget.shape,
            bandwidth: widget.bandwidth,
            points: widget.points,
            min: widget.min,
            max: widget.max,
            bandPadding: widget.bandPadding,
            overlap: widget.overlap,
            // A ridgeline is named down the left and a violin chart reads its
            // values there, so the left gutter belongs to whichever it is.
            labelWidth: widget.shape == ViolinShape.ridgeline
                ? (widget.showLabels ? widget.labelWidth : 0)
                : (widget.showAxis ? widget.axisWidth : 0),
            // Violins are named under the plot and read their values off the
            // left, so the strip at the bottom belongs to the names; a
            // ridgeline is the other way round.
            axisHeight: widget.shape == ViolinShape.violin
                ? (widget.showLabels ? widget.labelHeight : 0)
                : (widget.showAxis ? widget.axisHeight : 0),
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
                      painter: ViolinChartPainter(
                        chart: widget,
                        layout: _layout,
                        touched: touched,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (touched != null && touched < _layout.series.length)
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
    final laid = _layout.series[index];
    final build = widget.tooltipBuilder;
    final child = build != null
        ? build(context, laid.series, laid.stats)
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xEE1B1D22),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              laid.series.tooltip ??
                  '${laid.series.label}  median '
                      '${_number(widget, laid.stats.median)}',
              style: const TextStyle(color: Color(0xFFE9ECEF), fontSize: 11),
            ),
          );
    return Positioned(
      left: math.max(0, laid.medianAt.dx - 30),
      top: math.max(0, laid.medianAt.dy - 30),
      child: IgnorePointer(child: child),
    );
  }
}

String _number(ViolinChart chart, double value) {
  final format = chart.axisFormatter;
  if (format != null) return format(value);
  if (!value.isFinite) return '';
  if (value == value.roundToDouble() && value.abs() < 1e15) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}

/// Paints a [ViolinChart]: the gridlines, the shapes, their quartiles and the
/// labels.
class ViolinChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [layout].
  ViolinChartPainter({
    required this.chart,
    required this.layout,
    required this.touched,
    required this.textCache,
  });

  final ViolinChart chart;
  final ViolinLayout layout;

  /// The series under the finger, into [ViolinChart.series]; null when none is.
  final int? touched;
  final TextPainterCache textCache;

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (layout.isEmpty) return;

    final labelStyle = chart.labelStyle ??
        const TextStyle(color: Color(0xFFB4B8C0), fontSize: 11);
    final axisStyle = chart.axisStyle ??
        const TextStyle(color: Color(0xFF909196), fontSize: 10);
    final ridge = layout.shape == ViolinShape.ridgeline;

    // The value axis: down the side for violins, across the bottom for a
    // ridgeline, since that is the direction the values run in each.
    if (chart.tickCount > 0) {
      final grid = Paint()
        ..color = chart.gridColor
        ..strokeWidth = 1;
      for (var i = 0; i <= chart.tickCount; i++) {
        final value =
            layout.min + (layout.max - layout.min) * i / chart.tickCount;
        final at = layout.positionOf(value);
        if (ridge) {
          canvas.drawLine(
            Offset(at, layout.plotRect.top),
            Offset(at, layout.plotRect.bottom),
            grid,
          );
        } else {
          canvas.drawLine(
            Offset(layout.plotRect.left, at),
            Offset(layout.plotRect.right, at),
            grid,
          );
        }
        if (chart.showAxis) {
          final painter = textCache.get(_number(chart, value), axisStyle);
          painter.paint(
            canvas,
            ridge
                ? Offset(
                    (at - painter.width / 2)
                        .clamp(0.0, math.max(0.0, size.width - painter.width)),
                    layout.plotRect.bottom + 4,
                  )
                : Offset(
                    math.max(0, layout.plotRect.left - painter.width - 4),
                    at - painter.height / 2,
                  ),
          );
        }
      }
    }

    // Back to front, so an overlapping ridgeline stacks the way it reads.
    for (final laid in layout.series.reversed) {
      final base = laid.series.color ??
          chart.palette[laid.index % math.max(1, chart.palette.length)];
      final lifted = touched == laid.index;
      canvas.drawPath(
        laid.outline,
        Paint()
          ..color = base.withValues(
            alpha: (chart.fillOpacity + (lifted ? 0.25 : 0)).clamp(0.0, 1.0),
          ),
      );
      if (chart.outlineWidth > 0) {
        canvas.drawPath(
          laid.outline,
          Paint()
            ..color = base
            ..style = PaintingStyle.stroke
            ..strokeWidth = chart.outlineWidth,
        );
      }

      if (chart.showBox) {
        final pen = Paint()
          ..color = chart.boxColor
          ..strokeWidth = 1.5;
        canvas.drawLine(laid.whiskerFrom, laid.whiskerTo, pen);
        final box = laid.boxRect;
        if (box != null) {
          canvas.drawRect(box, Paint()..color = chart.boxColor);
        }
      }
      if (chart.showMedian) {
        final pen = Paint()
          ..color = chart.medianColor
          ..strokeWidth = 2;
        if (ridge) {
          canvas.drawLine(
            laid.medianAt,
            laid.medianAt - Offset(0, laid.bandRect.height * 0.25),
            pen,
          );
        } else {
          final half = math.max(4.0, laid.bandRect.width * 0.06);
          canvas.drawLine(
            laid.medianAt - Offset(half, 0),
            laid.medianAt + Offset(half, 0),
            pen,
          );
        }
      }

      if (chart.showLabels) {
        final painter = textCache.get(laid.series.label, labelStyle);
        painter.paint(
          canvas,
          ridge
              ? Offset(
                  math.max(0, layout.plotRect.left - painter.width - 6),
                  laid.bandRect.bottom - painter.height,
                )
              : Offset(
                  laid.bandRect.center.dx - painter.width / 2,
                  math.min(
                    layout.plotRect.bottom + 4,
                    size.height - painter.height,
                  ),
                ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(ViolinChartPainter old) =>
      old.chart != chart || old.layout != layout || old.touched != touched;
}
