import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';

/// One measure of a [ParallelChart] — an axis down the chart.
@immutable
class ParallelAxis {
  /// Creates an axis called [label].
  const ParallelAxis({
    required this.label,
    this.min,
    this.max,
    this.inverted = false,
    this.formatter,
  });

  /// What the measure is called, written over its axis.
  final String label;

  /// The value at the bottom of the axis; null takes the smallest in the data.
  final double? min;

  /// The value at the top; null takes the largest.
  final double? max;

  /// Whether small is good — flips the axis so the best is always at the top,
  /// which is what lets a reader compare lines without reading every scale.
  final bool inverted;

  /// Writes a value on the axis; null writes it with as few decimals as it
  /// needs.
  final String Function(double value)? formatter;
}

/// One line of a [ParallelChart] — a thing measured on every axis.
@immutable
class ParallelLine {
  /// Creates a line called [label] with one value per axis.
  ///
  /// A null value is a measure the thing has none of; its line breaks there.
  const ParallelLine({
    required this.label,
    required this.values,
    this.color,
    this.tooltip,
  });

  /// What the line is called.
  final String label;

  /// Its value on each axis, in the chart's axis order.
  final List<double?> values;

  /// What it is painted in; null takes a colour from the chart's palette.
  final Color? color;

  /// Shown when the line is touched; null shows its label and its values.
  final String? tooltip;

  /// Its value on axis [index], or null where it has none.
  double? valueAt(int index) {
    if (index < 0 || index >= values.length) return null;
    final value = values[index];
    return value != null && value.isFinite ? value : null;
  }
}

/// The ends of one axis, worked out from the data where they were not given.
@immutable
class ParallelScale {
  /// Creates a scale from [min] to [max].
  const ParallelScale({
    required this.min,
    required this.max,
    required this.inverted,
  });

  /// The value at the low end.
  final double min;

  /// The one at the high end.
  final double max;

  /// Whether the axis is flipped, so small is at the top.
  final bool inverted;

  /// Where [value] falls, from 0 at the bottom of the axis to 1 at its top.
  double fractionOf(double value) {
    final span = max - min;
    if (!(span > 0) || !value.isFinite) return 0;
    final fraction = ((value - min) / span).clamp(0.0, 1.0);
    return inverted ? 1 - fraction : fraction;
  }
}

/// Works out the scale of each of [axes] over [lines].
List<ParallelScale> parallelScales(
  List<ParallelAxis> axes,
  List<ParallelLine> lines,
) {
  final scales = <ParallelScale>[];
  for (var a = 0; a < axes.length; a++) {
    final axis = axes[a];
    var low = axis.min, high = axis.max;
    if (low == null || high == null) {
      var lo = double.infinity, hi = double.negativeInfinity;
      for (final line in lines) {
        final value = line.valueAt(a);
        if (value == null) continue;
        lo = math.min(lo, value);
        hi = math.max(hi, value);
      }
      if (lo.isFinite && hi.isFinite) {
        low ??= lo;
        high ??= hi;
      }
    }
    low ??= 0;
    high ??= 1;
    // A measure every line agrees on still needs a range to be drawn in; it
    // lands in the middle of its axis rather than at an end.
    if (!(high > low)) {
      final pad = math.max(1e-9, low.abs() * 0.05);
      low -= pad;
      high += pad;
    }
    scales.add(ParallelScale(min: low, max: high, inverted: axis.inverted));
  }
  return scales;
}

/// Where one line of a [ParallelChart] runs.
@immutable
class ParallelLineLayout {
  /// Creates the layout of the line at [index].
  const ParallelLineLayout({
    required this.index,
    required this.line,
    required this.points,
    required this.path,
  });

  /// Which line this is, into the chart's lines.
  final int index;

  /// The line itself.
  final ParallelLine line;

  /// Where it crosses each axis; null on an axis it has no value for.
  final List<Offset?> points;

  /// The line, as a path with a break wherever a value is missing.
  final Path path;

  /// How far [point] is from the line's crossing on axis [axis].
  double distanceAt(Offset point, int axis) {
    if (axis < 0 || axis >= points.length) return double.infinity;
    final at = points[axis];
    return at == null ? double.infinity : (at.dy - point.dy).abs();
  }
}

/// Where every axis and line of a [ParallelChart] sits.
@immutable
class ParallelLayout {
  /// Creates a laid-out chart.
  const ParallelLayout({
    required this.size,
    required this.plotRect,
    required this.axisX,
    required this.scales,
    required this.lines,
  });

  /// Nothing to draw.
  static const empty = ParallelLayout(
    size: Size.zero,
    plotRect: Rect.zero,
    axisX: [],
    scales: [],
    lines: [],
  );

  /// The box the chart was laid out in.
  final Size size;

  /// The part of it the axes run down.
  final Rect plotRect;

  /// Where each axis sits across the plot.
  final List<double> axisX;

  /// The ends of each axis.
  final List<ParallelScale> scales;

  /// The lines, in the order they were given.
  final List<ParallelLineLayout> lines;

  /// Whether there is anything to draw.
  bool get isEmpty => axisX.isEmpty || lines.isEmpty;

  /// Where [value] sits on axis [index].
  double yOf(int index, double value) {
    if (index < 0 || index >= scales.length) return plotRect.bottom;
    return plotRect.bottom - scales[index].fractionOf(value) * plotRect.height;
  }

  /// The axis nearest [x].
  int axisAt(double x) {
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < axisX.length; i++) {
      final distance = (axisX[i] - x).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    return best;
  }

  /// The line nearest [point] at the axis nearest it, within [within] pixels.
  ParallelLineLayout? lineAt(Offset point, {double within = 24}) {
    if (isEmpty) return null;
    final axis = axisAt(point.dx);
    ParallelLineLayout? best;
    var bestDistance = within;
    for (final laid in lines) {
      final distance = laid.distanceAt(point, axis);
      if (distance <= bestDistance) {
        bestDistance = distance;
        best = laid;
      }
    }
    return best;
  }
}

/// Lays out [lines] across [axes] in [size].
///
/// [legendWidth] keeps room at the left for the line names, where the chart
/// writes them; without it they would have nowhere to go but over the first
/// axis.
///
/// [progress] reveals the axes left to right, for a draw-in animation.
ParallelLayout layOutParallel(
  List<ParallelAxis> axes,
  List<ParallelLine> lines, {
  required Size size,
  double headerHeight = 0,
  double footerHeight = 0,
  double legendWidth = 0,
  bool curved = false,
  EdgeInsets padding = EdgeInsets.zero,
  double progress = 1,
}) {
  if (axes.isEmpty || lines.isEmpty) return ParallelLayout.empty;
  final box = padding.deflateRect(Offset.zero & size);
  if (box.width <= 0 || box.height <= 0) return ParallelLayout.empty;
  final plot = Rect.fromLTRB(
    box.left + math.max(0, legendWidth),
    box.top + math.max(0, headerHeight),
    box.right,
    box.bottom - math.max(0, footerHeight),
  );
  if (plot.width <= 0 || plot.height <= 0) return ParallelLayout.empty;

  final scales = parallelScales(axes, lines);
  final columns = [
    for (var a = 0; a < axes.length; a++)
      axes.length == 1
          ? plot.center.dx
          : plot.left + plot.width * a / (axes.length - 1),
  ];

  final laidOut = ParallelLayout(
    size: size,
    plotRect: plot,
    axisX: columns,
    scales: scales,
    lines: const [],
  );
  final shown = axes.length == 1
      ? plot.right
      : plot.left + plot.width * progress.clamp(0.0, 1.0);

  final laid = <ParallelLineLayout>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final points = <Offset?>[];
    for (var a = 0; a < axes.length; a++) {
      final value = line.valueAt(a);
      points.add(
        value == null || columns[a] > shown + 0.001
            ? null
            : Offset(columns[a], laidOut.yOf(a, value)),
      );
    }

    final path = Path();
    Offset? previous;
    for (final at in points) {
      if (at == null) {
        previous = null;
        continue;
      }
      if (previous == null) {
        path.moveTo(at.dx, at.dy);
      } else if (curved) {
        final midX = (previous.dx + at.dx) / 2;
        path.cubicTo(midX, previous.dy, midX, at.dy, at.dx, at.dy);
      } else {
        path.lineTo(at.dx, at.dy);
      }
      previous = at;
    }

    laid.add(
      ParallelLineLayout(index: i, line: line, points: points, path: path),
    );
  }

  return ParallelLayout(
    size: size,
    plotRect: plot,
    axisX: columns,
    scales: scales,
    lines: laid,
  );
}

/// Many measures at once — a parallel coordinates plot.
///
/// One axis per measure, one line per thing, each crossing every axis at its
/// own value. Comparing strategies on return, drawdown, win rate, expectancy
/// and trade count in one picture is what this chart is for, and no other
/// chart in the package does it.
///
/// ```dart
/// ParallelChart(
///   axes: const [
///     ParallelAxis(label: 'Return'),
///     ParallelAxis(label: 'Drawdown', inverted: true),
///     ParallelAxis(label: 'Win rate'),
///   ],
///   lines: const [
///     ParallelLine(label: 'Trend', values: [34, 18, 41]),
///     ParallelLine(label: 'Revert', values: [21, 9, 63]),
///   ],
/// );
/// ```
class ParallelChart extends StatefulWidget {
  /// Creates a parallel coordinates plot of [lines] across [axes].
  const ParallelChart({
    super.key,
    required this.axes,
    required this.lines,
    this.palette = defaultPalette,
    this.lineWidth = 1.6,
    this.lineOpacity = 0.75,
    this.curved = false,
    this.dotRadius = 3,
    this.axisColor = const Color(0x33909196),
    this.axisWidth = 1,
    this.showHeaders = true,
    this.headerHeight = 22,
    this.headerStyle,
    this.showEnds = true,
    this.footerHeight = 16,
    this.endStyle,
    this.fadeUntouched = true,
    this.showLegend = false,
    this.legendWidth = 64,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.onLineTap,
    this.tooltipBuilder,
    this.defaultHeight = 260,
    this.semanticLabel,
  });

  /// The measures, drawn left to right in the order given.
  final List<ParallelAxis> axes;

  /// The things measured, one line each.
  final List<ParallelLine> lines;

  /// Colours handed to lines that name none, in order.
  final List<Color> palette;

  /// The colours used where a line names none.
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

  /// How thick the lines are.
  final double lineWidth;

  /// How solid they are painted, so a crowded chart still reads.
  final double lineOpacity;

  /// Whether the lines are eased between axes rather than straight.
  final bool curved;

  /// How large the dot at each crossing is; 0 draws none.
  final double dotRadius;

  /// What the axes are painted in.
  final Color axisColor;

  /// How thick they are.
  final double axisWidth;

  /// Whether the measures are named across the top.
  final bool showHeaders;

  /// How much room those names take.
  final double headerHeight;

  /// Style of the measure names.
  final TextStyle? headerStyle;

  /// Whether each axis' ends are written by its top and bottom.
  final bool showEnds;

  /// How much room the bottom ends take.
  final double footerHeight;

  /// Style of those numbers.
  final TextStyle? endStyle;

  /// Whether the other lines fade while one is touched.
  final bool fadeUntouched;

  /// Whether every line is labelled at the left-hand axis.
  final bool showLegend;

  /// How much room those names take, left of the first axis.
  final double legendWidth;

  /// Space kept clear around the chart.
  final EdgeInsets padding;

  /// Painted behind the whole chart.
  final Color? backgroundColor;

  /// How long the lines take to draw in; zero draws them at once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build draws the lines in.
  final bool animateOnMount;

  /// Called with a line and the axis under the finger when one is touched,
  /// and with nulls when the touch leaves.
  final void Function(ParallelLine? line, int? axis)? onLineTap;

  /// Builds the card shown over a touched line; null shows its label and its
  /// value on the axis nearest the finger.
  final Widget Function(BuildContext context, ParallelLine line, int axis)?
  tooltipBuilder;

  /// How tall the chart is in a box that sets no height.
  final double defaultHeight;

  /// What a screen reader announces for the chart.
  final String? semanticLabel;

  @override
  State<ParallelChart> createState() => _ParallelChartState();
}

class _ParallelChartState extends State<ParallelChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 256);
  ParallelLayout _layout = ParallelLayout.empty;
  int? _touched;
  int _axis = 0;

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
  void didUpdateWidget(ParallelChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!identical(oldWidget.lines, widget.lines) &&
        widget.animationDuration > Duration.zero) {
      _animation.forward(from: 0);
    }
    if (_touched != null && _touched! >= widget.lines.length) _touched = null;
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void _touch(Offset point) {
    if (_layout.isEmpty) return;
    final found = _layout.lineAt(point);
    final axis = _layout.axisAt(point.dx);
    if (found?.index == _touched && axis == _axis) return;
    setState(() {
      _touched = found?.index;
      _axis = axis;
    });
    widget.onLineTap?.call(found?.line, found == null ? null : axis);
  }

  void _clear() {
    if (_touched == null) return;
    setState(() => _touched = null);
    widget.onLineTap?.call(null, null);
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
          _layout = layOutParallel(
            widget.axes,
            widget.lines,
            size: Size(width, height),
            headerHeight: widget.showHeaders ? widget.headerHeight : 0,
            footerHeight: widget.showEnds ? widget.footerHeight : 0,
            legendWidth: widget.showLegend ? widget.legendWidth : 0,
            curved: widget.curved,
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
                      painter: ParallelChartPainter(
                        chart: widget,
                        layout: _layout,
                        touched: touched,
                        axis: _axis,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (touched != null && touched < _layout.lines.length)
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
    final laid = _layout.lines[index];
    final axis = _axis.clamp(0, math.max(0, widget.axes.length - 1)).toInt();
    final at = laid.points[axis] ?? _layout.plotRect.center;
    final value = laid.line.valueAt(axis);
    final build = widget.tooltipBuilder;
    final child = build != null
        ? build(context, laid.line, axis)
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xEE1B1D22),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              laid.line.tooltip ??
                  '${laid.line.label}  ${widget.axes[axis].label} '
                      '${value == null ? '—' : _number(widget.axes[axis], value)}',
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

String _number(ParallelAxis axis, double value) {
  final format = axis.formatter;
  if (format != null) return format(value);
  if (!value.isFinite) return '';
  if (value == value.roundToDouble() && value.abs() < 1e15) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}

/// Paints a [ParallelChart]: the axes, their names and ends, and the lines.
class ParallelChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [layout].
  ParallelChartPainter({
    required this.chart,
    required this.layout,
    required this.touched,
    required this.axis,
    required this.textCache,
  });

  final ParallelChart chart;
  final ParallelLayout layout;

  /// The line under the finger, into [ParallelChart.lines]; null when none is.
  final int? touched;

  /// The axis nearest the finger.
  final int axis;
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
    final endStyle =
        chart.endStyle ??
        const TextStyle(color: Color(0xFF909196), fontSize: 10);

    for (var a = 0; a < layout.axisX.length; a++) {
      final x = layout.axisX[a];
      canvas.drawLine(
        Offset(x, layout.plotRect.top),
        Offset(x, layout.plotRect.bottom),
        Paint()
          ..color = chart.axisColor
          ..strokeWidth = chart.axisWidth,
      );

      if (chart.showHeaders && chart.headerHeight > 0) {
        final label =
            chart.axes[a].label + (chart.axes[a].inverted ? ' ↓' : '');
        final painter = textCache.get(label, headerStyle);
        painter.paint(
          canvas,
          Offset(
            (x - painter.width / 2).clamp(
              0.0,
              math.max(0.0, size.width - painter.width),
            ),
            math.max(0, layout.plotRect.top - painter.height - 4),
          ),
        );
      }

      if (chart.showEnds) {
        final scale = layout.scales[a];
        // The top of the axis is the larger value unless the axis is flipped.
        final top = scale.inverted ? scale.min : scale.max;
        final bottom = scale.inverted ? scale.max : scale.min;
        for (final pair in [
          (_number(chart.axes[a], top), layout.plotRect.top + 2),
          (_number(chart.axes[a], bottom), layout.plotRect.bottom + 2),
        ]) {
          final painter = textCache.get(pair.$1, endStyle);
          // Centred on its axis, except on the first one when the lines are
          // named there: the names own that corner, so the numbers step
          // right of the axis rather than sitting under them.
          final left = a == 0 && chart.showLegend
              ? x + 4
              : x - painter.width / 2;
          painter.paint(
            canvas,
            Offset(
              left.clamp(0.0, math.max(0.0, size.width - painter.width)),
              pair.$2,
            ),
          );
        }
      }
    }

    // The held line last, so it is drawn over the rest.
    final order = [
      for (var i = 0; i < layout.lines.length; i++)
        if (i != touched) i,
      if (touched != null) touched!,
    ];
    for (final i in order) {
      final laid = layout.lines[i];
      final base =
          laid.line.color ??
          chart.palette[i % math.max(1, chart.palette.length)];
      final dimmed = touched != null && chart.fadeUntouched && touched != i;
      final color = base.withValues(
        alpha: (chart.lineOpacity * (dimmed ? 0.2 : 1)).clamp(0.0, 1.0),
      );
      canvas.drawPath(
        laid.path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = touched == i ? chart.lineWidth + 1 : chart.lineWidth
          ..strokeJoin = StrokeJoin.round,
      );

      if (chart.dotRadius > 0) {
        for (final at in laid.points) {
          if (at == null) continue;
          canvas.drawCircle(at, chart.dotRadius, Paint()..color = color);
        }
      }

      if (chart.showLegend) {
        final first = laid.points.firstWhere(
          (point) => point != null,
          orElse: () => null,
        );
        if (first != null) {
          final painter = textCache.get(
            laid.line.label,
            headerStyle.copyWith(color: base),
          );
          painter.paint(
            canvas,
            Offset(
              math.max(0, first.dx - painter.width - 6),
              first.dy - painter.height / 2,
            ),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(ParallelChartPainter old) =>
      old.chart != chart ||
      old.layout != layout ||
      old.touched != touched ||
      old.axis != axis;
}
