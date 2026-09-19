import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';

/// One band of a [StreamChart] — a thing whose share changes over time.
@immutable
class StreamSeries {
  /// Creates a band called [label] with one value per period.
  ///
  /// Negative and non-finite values count as nothing: a stacked band cannot
  /// be thinner than nothing without tearing the stack.
  const StreamSeries({
    required this.label,
    required this.values,
    this.color,
    this.tooltip,
  });

  /// What the band is called.
  final String label;

  /// How much of it there was at each period.
  final List<double> values;

  /// What it is painted in; null takes a colour from the chart's palette.
  final Color? color;

  /// Shown when the band is touched; null shows its label and value.
  final String? tooltip;

  /// Its value at [period], or 0 where it has none.
  double valueAt(int period) {
    if (period < 0 || period >= values.length) return 0;
    final value = values[period];
    return value.isFinite && value > 0 ? value : 0;
  }
}

/// Where a [StreamChart]'s stack is centred.
enum StreamBaseline {
  /// Everything grows up from a flat bottom — an ordinary stacked area.
  zero,

  /// The stack is centred on one line, so it thickens either way.
  silhouette,

  /// The baseline is chosen to keep the bands as level as possible, which is
  /// what makes a stream graph read as flow rather than as growth.
  wiggle,
}

/// How the bands of a [StreamChart] are ordered bottom to top.
enum StreamOrder {
  /// The order they were given in.
  given,

  /// Largest total nearest the baseline.
  largestFirst,

  /// Largest totals in the middle, the rest alternating outwards, which keeps
  /// the busiest bands where the stack moves least.
  insideOut,
}

/// The offsets and the order a [StreamChart]'s stack is built from.
@immutable
class StreamStack {
  /// Creates a stack of [tops] and [bottoms] in [order].
  const StreamStack({
    required this.order,
    required this.bottoms,
    required this.tops,
    required this.min,
    required this.max,
  });

  /// Nothing at all.
  static const empty = StreamStack(
    order: [],
    bottoms: [],
    tops: [],
    min: 0,
    max: 0,
  );

  /// The series bottom to top, as indexes into the chart's series.
  final List<int> order;

  /// The bottom edge of each series at each period, by the series' own index.
  final List<List<double>> bottoms;

  /// Its top edge, likewise.
  final List<List<double>> tops;

  /// The lowest edge anywhere in the stack.
  final double min;

  /// The highest.
  final double max;

  /// Whether there is anything to draw.
  bool get isEmpty => order.isEmpty;
}

/// Stacks [series] over [periods], offset by [baseline] and in [order].
///
/// The wiggle baseline is Byron and Wattenberg's: at each step the whole stack
/// is moved so the bands' slopes, weighted by how thick they are, cancel out.
StreamStack stackStream(
  List<StreamSeries> series, {
  required int periods,
  StreamBaseline baseline = StreamBaseline.wiggle,
  StreamOrder order = StreamOrder.insideOut,
}) {
  if (series.isEmpty || periods <= 0) return StreamStack.empty;

  final totals = [
    for (final one in series)
      [
        for (var p = 0; p < periods; p++) one.valueAt(p),
      ].fold<double>(0, (a, b) => a + b),
  ];

  List<int> stackOrder;
  switch (order) {
    case StreamOrder.given:
      stackOrder = [for (var i = 0; i < series.length; i++) i];
    case StreamOrder.largestFirst:
      stackOrder = [for (var i = 0; i < series.length; i++) i]
        ..sort((a, b) => totals[b].compareTo(totals[a]));
    case StreamOrder.insideOut:
      final bySize = [for (var i = 0; i < series.length; i++) i]
        ..sort((a, b) => totals[b].compareTo(totals[a]));
      // Largest in the middle, the next two either side of it, and so on.
      final left = <int>[], right = <int>[];
      for (var i = 0; i < bySize.length; i++) {
        (i.isEven ? left : right).add(bySize[i]);
      }
      stackOrder = [...left.reversed, ...right];
  }

  final bottoms = [
    for (var i = 0; i < series.length; i++) List<double>.filled(periods, 0),
  ];
  final tops = [
    for (var i = 0; i < series.length; i++) List<double>.filled(periods, 0),
  ];

  final offsets = List<double>.filled(periods, 0);
  if (baseline == StreamBaseline.silhouette) {
    for (var p = 0; p < periods; p++) {
      var sum = 0.0;
      for (final one in series) {
        sum += one.valueAt(p);
      }
      offsets[p] = -sum / 2;
    }
  } else if (baseline == StreamBaseline.wiggle) {
    for (var p = 1; p < periods; p++) {
      var weighted = 0.0;
      var total = 0.0;
      for (var s = 0; s < stackOrder.length; s++) {
        final index = stackOrder[s];
        final change = series[index].valueAt(p) - series[index].valueAt(p - 1);
        // Half this band's own change, plus all of everything below it.
        var below = 0.0;
        for (var b = 0; b < s; b++) {
          final other = stackOrder[b];
          below += series[other].valueAt(p) - series[other].valueAt(p - 1);
        }
        weighted += (below + change / 2) * series[index].valueAt(p);
        total += series[index].valueAt(p);
      }
      offsets[p] = offsets[p - 1] - (total > 0 ? weighted / total : 0);
    }
  }

  var min = double.infinity, max = double.negativeInfinity;
  for (var p = 0; p < periods; p++) {
    var y = offsets[p];
    for (final index in stackOrder) {
      final value = series[index].valueAt(p);
      bottoms[index][p] = y;
      tops[index][p] = y + value;
      y += value;
    }
    min = math.min(min, offsets[p]);
    max = math.max(max, y);
  }
  if (!min.isFinite || !max.isFinite) return StreamStack.empty;
  if (!(max > min)) max = min + 1;

  return StreamStack(
    order: stackOrder,
    bottoms: bottoms,
    tops: tops,
    min: min,
    max: max,
  );
}

/// Where one band of a [StreamChart] runs.
@immutable
class StreamSeriesLayout {
  /// Creates the layout of the band at [index].
  const StreamSeriesLayout({
    required this.index,
    required this.series,
    required this.shape,
    required this.topPoints,
    required this.bottomPoints,
  });

  /// Which series this is, into the chart's series.
  final int index;

  /// The series itself.
  final StreamSeries series;

  /// Its band, as a closed path.
  final Path shape;

  /// Its top edge, a point per period.
  final List<Offset> topPoints;

  /// Its bottom edge, likewise.
  final List<Offset> bottomPoints;

  /// How thick the band is at [period], in pixels.
  double thicknessAt(int period) {
    if (period < 0 || period >= topPoints.length) return 0;
    return (bottomPoints[period].dy - topPoints[period].dy).abs();
  }

  /// Whether [point] falls between the band's edges at the period nearest it.
  bool hit(Offset point, int period) {
    if (period < 0 || period >= topPoints.length) return false;
    return point.dy >= topPoints[period].dy &&
        point.dy <= bottomPoints[period].dy;
  }
}

/// Where every band of a [StreamChart] runs.
@immutable
class StreamLayout {
  /// Creates a laid-out chart.
  const StreamLayout({
    required this.size,
    required this.plotRect,
    required this.series,
    required this.columnX,
    required this.stack,
  });

  /// Nothing to draw.
  static const empty = StreamLayout(
    size: Size.zero,
    plotRect: Rect.zero,
    series: [],
    columnX: [],
    stack: StreamStack.empty,
  );

  /// The box the chart was laid out in.
  final Size size;

  /// The part of it the bands run in.
  final Rect plotRect;

  /// The bands, by the order their series were given in.
  final List<StreamSeriesLayout> series;

  /// Where each period sits across the plot.
  final List<double> columnX;

  /// The stack the bands were built from.
  final StreamStack stack;

  /// Whether there is anything to draw.
  bool get isEmpty => series.isEmpty || columnX.isEmpty;

  /// The period nearest [x].
  int periodAt(double x) {
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < columnX.length; i++) {
      final distance = (columnX[i] - x).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    return best;
  }

  /// The band under [point]; null when the point is outside the stack.
  StreamSeriesLayout? seriesAt(Offset point) {
    final period = periodAt(point.dx);
    // Top of the stack first, so the thin band drawn over another wins.
    for (final index in stack.order.reversed) {
      final laid = series[index];
      if (laid.hit(point, period)) return laid;
    }
    return null;
  }
}

/// Lays out [series] over [periods] columns in [size].
///
/// [progress] runs from 0 to 1 and flattens every band towards the baseline,
/// for a draw-in animation.
StreamLayout layOutStream(
  List<StreamSeries> series, {
  required Size size,
  required int periods,
  StreamBaseline baseline = StreamBaseline.wiggle,
  StreamOrder order = StreamOrder.insideOut,
  bool curved = true,
  double axisHeight = 0,
  EdgeInsets padding = EdgeInsets.zero,
  double progress = 1,
}) {
  if (series.isEmpty || periods <= 0) return StreamLayout.empty;
  final box = padding.deflateRect(Offset.zero & size);
  if (box.width <= 0 || box.height <= 0) return StreamLayout.empty;
  final plot = Rect.fromLTRB(
    box.left,
    box.top,
    box.right,
    math.max(box.top, box.bottom - math.max(0, axisHeight)),
  );
  if (plot.width <= 0 || plot.height <= 0) return StreamLayout.empty;

  final stack = stackStream(
    series,
    periods: periods,
    baseline: baseline,
    order: order,
  );
  if (stack.isEmpty) return StreamLayout.empty;

  final columns = [
    for (var p = 0; p < periods; p++)
      periods == 1
          ? plot.center.dx
          : plot.left + plot.width * p / (periods - 1),
  ];
  final span = stack.max - stack.min;
  final t = progress.clamp(0.0, 1.0);
  // Everything shrinks towards the middle of the stack, so the draw-in opens
  // out rather than sliding in from an edge.
  final middle = (stack.min + stack.max) / 2;
  double yOf(double value) {
    final eased = middle + (value - middle) * t;
    return plot.bottom - (eased - stack.min) / span * plot.height;
  }

  Path pathOf(List<Offset> top, List<Offset> bottom) {
    final path = Path();
    if (top.isEmpty) return path;
    path.moveTo(top.first.dx, top.first.dy);
    void run(List<Offset> points) {
      for (var i = 1; i < points.length; i++) {
        if (curved) {
          final midX = (points[i - 1].dx + points[i].dx) / 2;
          path.cubicTo(
            midX,
            points[i - 1].dy,
            midX,
            points[i].dy,
            points[i].dx,
            points[i].dy,
          );
        } else {
          path.lineTo(points[i].dx, points[i].dy);
        }
      }
    }

    run(top);
    path.lineTo(bottom.last.dx, bottom.last.dy);
    run(bottom.reversed.toList());
    path.close();
    return path;
  }

  final laid = <StreamSeriesLayout>[];
  for (var i = 0; i < series.length; i++) {
    final top = [
      for (var p = 0; p < periods; p++)
        Offset(columns[p], yOf(stack.tops[i][p])),
    ];
    final bottom = [
      for (var p = 0; p < periods; p++)
        Offset(columns[p], yOf(stack.bottoms[i][p])),
    ];
    laid.add(
      StreamSeriesLayout(
        index: i,
        series: series[i],
        shape: pathOf(top, bottom),
        topPoints: top,
        bottomPoints: bottom,
      ),
    );
  }

  return StreamLayout(
    size: size,
    plotRect: plot,
    series: laid,
    columnX: columns,
    stack: stack,
  );
}

/// A stack that flows — a stream graph.
///
/// The make-up of a portfolio month by month, volume by venue, positions by
/// symbol: a stacked area answers "how much in total", and a stream graph on a
/// wiggle baseline answers "what was it made of", which is usually the
/// question.
///
/// ```dart
/// StreamChart(
///   periodLabels: const ['Jan', 'Feb', 'Mar'],
///   series: const [
///     StreamSeries(label: 'BTC', values: [40, 55, 48]),
///     StreamSeries(label: 'ETH', values: [30, 20, 35]),
///     StreamSeries(label: 'Cash', values: [30, 25, 17]),
///   ],
/// );
/// ```
class StreamChart extends StatefulWidget {
  /// Creates a stream graph of [series].
  const StreamChart({
    super.key,
    required this.series,
    this.periodLabels = const [],
    this.periods,
    this.baseline = StreamBaseline.wiggle,
    this.order = StreamOrder.insideOut,
    this.palette = defaultPalette,
    this.curved = true,
    this.fillOpacity = 0.9,
    this.strokeWidth = 0,
    this.showLabels = true,
    this.minLabelThickness = 16,
    this.labelStyle,
    this.showAxis = true,
    this.axisHeight = 20,
    this.axisStyle,
    this.crosshairColor = const Color(0x66E9ECEF),
    this.fadeUntouched = true,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.onSeriesTap,
    this.tooltipBuilder,
    this.defaultHeight = 240,
    this.semanticLabel,
  });

  /// The bands, in the order they were given.
  final List<StreamSeries> series;

  /// What each period is called, written along the bottom.
  final List<String> periodLabels;

  /// How many periods there are; null takes the longest series, or the number
  /// of [periodLabels], whichever is larger.
  final int? periods;

  /// Where the stack is centred.
  final StreamBaseline baseline;

  /// How the bands are ordered bottom to top.
  final StreamOrder order;

  /// Colours handed to bands that name none, in order.
  final List<Color> palette;

  /// The colours used where a band names none.
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

  /// Whether the edges are eased between periods rather than straight.
  final bool curved;

  /// How solid the bands are painted.
  final double fillOpacity;

  /// How thick an outline the bands get; 0 draws none.
  final double strokeWidth;

  /// Whether a band's name is written in it where there is room.
  final bool showLabels;

  /// How thick a band has to be, in pixels, before it is labelled.
  final double minLabelThickness;

  /// Style of those labels.
  final TextStyle? labelStyle;

  /// Whether the period labels are written along the bottom.
  final bool showAxis;

  /// How much room they take.
  final double axisHeight;

  /// Style of the period labels.
  final TextStyle? axisStyle;

  /// The line drawn down the period under the finger.
  final Color crosshairColor;

  /// Whether the other bands fade while one is touched.
  final bool fadeUntouched;

  /// Space kept clear around the chart.
  final EdgeInsets padding;

  /// Painted behind the whole chart.
  final Color? backgroundColor;

  /// How long the bands take to open out; zero draws them at once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build opens the bands out.
  final bool animateOnMount;

  /// Called with a band and the period under the finger when one is touched,
  /// and with nulls when the touch leaves the stack.
  final void Function(StreamSeries? series, int? period)? onSeriesTap;

  /// Builds the card shown over a touched band; null shows its label and its
  /// value at that period.
  final Widget Function(BuildContext context, StreamSeries series, int period)?
  tooltipBuilder;

  /// How tall the chart is in a box that sets no height.
  final double defaultHeight;

  /// What a screen reader announces for the chart.
  final String? semanticLabel;

  /// How many periods the chart actually draws.
  int get resolvedPeriods {
    final given = periods;
    if (given != null) return math.max(0, given);
    var longest = periodLabels.length;
    for (final one in series) {
      longest = math.max(longest, one.values.length);
    }
    return longest;
  }

  @override
  State<StreamChart> createState() => _StreamChartState();
}

class _StreamChartState extends State<StreamChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 256);
  StreamLayout _layout = StreamLayout.empty;
  int? _touched;
  int? _period;

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
  void didUpdateWidget(StreamChart oldWidget) {
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
    _text.dispose();
    _animation.dispose();
    super.dispose();
  }

  void _touch(Offset point) {
    if (_layout.isEmpty) return;
    final found = _layout.seriesAt(point);
    final period = _layout.periodAt(point.dx);
    if (found?.index == _touched && period == _period) return;
    setState(() {
      _touched = found?.index;
      _period = period;
    });
    widget.onSeriesTap?.call(found?.series, found == null ? null : period);
  }

  void _clear() {
    if (_touched == null && _period == null) return;
    setState(() {
      _touched = null;
      _period = null;
    });
    widget.onSeriesTap?.call(null, null);
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
          _layout = layOutStream(
            widget.series,
            size: Size(width, height),
            periods: widget.resolvedPeriods,
            baseline: widget.baseline,
            order: widget.order,
            curved: widget.curved,
            axisHeight: widget.showAxis && widget.periodLabels.isNotEmpty
                ? widget.axisHeight
                : 0,
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
                      painter: StreamChartPainter(
                        chart: widget,
                        layout: _layout,
                        touched: touched,
                        period: _period,
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
    final period = (_period ?? 0)
        .clamp(0, math.max(0, laid.topPoints.length - 1))
        .toInt();
    final at = laid.topPoints[period];
    final build = widget.tooltipBuilder;
    final child = build != null
        ? build(context, laid.series, period)
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xEE1B1D22),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              laid.series.tooltip ??
                  '${laid.series.label}  '
                      '${_number(laid.series.valueAt(period))}',
              style: const TextStyle(color: Color(0xFFE9ECEF), fontSize: 11),
            ),
          );
    return Positioned(
      left: math.max(0, at.dx - 30),
      top: math.max(0, at.dy - 28),
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

/// Paints a [StreamChart]: the bands, their names and the period axis.
class StreamChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [layout].
  StreamChartPainter({
    required this.chart,
    required this.layout,
    required this.touched,
    required this.period,
    required this.textCache,
  });

  final StreamChart chart;
  final StreamLayout layout;

  /// The band under the finger, into [StreamChart.series]; null when none is.
  final int? touched;

  /// The period under the finger; null when the touch is away.
  final int? period;
  final TextPainterCache textCache;

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (layout.isEmpty) return;

    final labelStyle =
        chart.labelStyle ??
        const TextStyle(color: Color(0xFF15171C), fontSize: 11);
    final axisStyle =
        chart.axisStyle ??
        const TextStyle(color: Color(0xFF909196), fontSize: 10);

    for (final index in layout.stack.order) {
      final laid = layout.series[index];
      final base =
          laid.series.color ??
          chart.palette[index % math.max(1, chart.palette.length)];
      final dimmed = touched != null && chart.fadeUntouched && touched != index;
      final alpha = (chart.fillOpacity * (dimmed ? 0.35 : 1)).clamp(0.0, 1.0);
      canvas.drawPath(
        laid.shape,
        Paint()..color = base.withValues(alpha: alpha),
      );
      if (chart.strokeWidth > 0) {
        canvas.drawPath(
          laid.shape,
          Paint()
            ..color = base
            ..style = PaintingStyle.stroke
            ..strokeWidth = chart.strokeWidth,
        );
      }

      if (chart.showLabels) {
        // In the band's thickest period, where a name actually fits.
        var thickest = 0;
        for (var p = 1; p < laid.topPoints.length; p++) {
          if (laid.thicknessAt(p) > laid.thicknessAt(thickest)) thickest = p;
        }
        if (laid.thicknessAt(thickest) >= chart.minLabelThickness) {
          final painter = textCache.get(laid.series.label, labelStyle);
          final middle = Offset(
            laid.topPoints[thickest].dx,
            (laid.topPoints[thickest].dy + laid.bottomPoints[thickest].dy) / 2,
          );
          // Held a few pixels inside the plot: a band is usually thickest at
          // one of its ends, and a name flush against the edge reads as cut
          // off even when every pixel of it is there.
          const inset = 6.0;
          painter.paint(
            canvas,
            Offset(
              (middle.dx - painter.width / 2).clamp(
                inset,
                math.max(inset, size.width - painter.width - inset),
              ),
              middle.dy - painter.height / 2,
            ),
          );
        }
      }
    }

    if (chart.showAxis && chart.periodLabels.isNotEmpty) {
      for (var p = 0; p < layout.columnX.length; p++) {
        if (p >= chart.periodLabels.length) break;
        final painter = textCache.get(chart.periodLabels[p], axisStyle);
        painter.paint(
          canvas,
          Offset(
            (layout.columnX[p] - painter.width / 2).clamp(
              0.0,
              math.max(0.0, size.width - painter.width),
            ),
            layout.plotRect.bottom + 4,
          ),
        );
      }
    }

    final at = period;
    if (at != null && at < layout.columnX.length) {
      canvas.drawLine(
        Offset(layout.columnX[at], layout.plotRect.top),
        Offset(layout.columnX[at], layout.plotRect.bottom),
        Paint()
          ..color = chart.crosshairColor
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(StreamChartPainter old) =>
      old.chart != chart ||
      old.layout != layout ||
      old.touched != touched ||
      old.period != period;
}
