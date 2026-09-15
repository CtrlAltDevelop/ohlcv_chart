import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';

/// One row of a [DumbbellChart] — a pair of values, or a range.
@immutable
class DumbbellRow {
  /// Creates a row called [label] running from [from] to [to].
  const DumbbellRow({
    required this.label,
    required this.from,
    required this.to,
    this.fromColor,
    this.toColor,
    this.barColor,
    this.tooltip,
  });

  /// What the row is called, written in the label column.
  final String label;

  /// Where the bar starts — last quarter, the low, the before.
  final double from;

  /// Where it ends — this quarter, the high, the after.
  final double to;

  /// The colour of the dot at [from]; null takes the chart's.
  final Color? fromColor;

  /// The colour of the dot at [to]; null takes the chart's, or the chart's
  /// rise and fall colours where it has them.
  final Color? toColor;

  /// The colour of the bar between the dots; null takes the chart's.
  final Color? barColor;

  /// Shown when the row is touched; null shows the label and both values.
  final String? tooltip;

  /// How far the row moved, which is negative when it fell.
  double get change => to - from;

  /// Whether the row ended higher than it started.
  bool get rose => to >= from;
}

/// Where one row of a [DumbbellChart] sits.
@immutable
class DumbbellRowLayout {
  /// Creates the layout of the row at [index].
  const DumbbellRowLayout({
    required this.index,
    required this.row,
    required this.labelRect,
    required this.trackRect,
    required this.fromCenter,
    required this.toCenter,
  });

  /// Which row this is, into the chart's rows.
  final int index;

  /// The row itself.
  final DumbbellRow row;

  /// Where the row's label is written.
  final Rect labelRect;

  /// The band of the plot the row owns, from edge to edge.
  final Rect trackRect;

  /// The middle of the dot at the row's start.
  final Offset fromCenter;

  /// The middle of the dot at its end.
  final Offset toCenter;

  /// Whether [point] falls in the row's band.
  bool hit(Offset point) =>
      point.dy >= trackRect.top && point.dy <= trackRect.bottom;
}

/// Where every row of a [DumbbellChart] sits, and the scale they share.
@immutable
class DumbbellLayout {
  /// Creates a laid-out chart.
  const DumbbellLayout({
    required this.size,
    required this.plotRect,
    required this.rows,
    required this.min,
    required this.max,
    required this.ticks,
  });

  /// Nothing to draw.
  static const empty = DumbbellLayout(
    size: Size.zero,
    plotRect: Rect.zero,
    rows: [],
    min: 0,
    max: 0,
    ticks: [],
  );

  /// The box the chart was laid out in.
  final Size size;

  /// The part of it the bars run across.
  final Rect plotRect;

  /// The rows, in the order they were given.
  final List<DumbbellRowLayout> rows;

  /// The value at the left of the plot.
  final double min;

  /// The value at its right.
  final double max;

  /// The values of the gridlines, in the rows' units.
  final List<double> ticks;

  /// Whether there is anything to draw.
  bool get isEmpty => rows.isEmpty;

  /// Where [value] falls across the plot.
  double xOf(double value) {
    final span = max - min;
    if (!(span > 0) || !value.isFinite) return plotRect.left;
    return plotRect.left + (value - min) / span * plotRect.width;
  }

  /// The row under [point]; null when it is past the last.
  DumbbellRowLayout? rowAt(Offset point) {
    for (final row in rows) {
      if (row.hit(point)) return row;
    }
    return null;
  }
}

/// Lays out [rows] in [size], every row on one shared scale.
///
/// [progress] runs from 0 to 1 and grows each bar out from its start, for a
/// draw-in animation.
DumbbellLayout layOutDumbbell(
  List<DumbbellRow> rows, {
  required Size size,
  double labelWidth = 92,
  double labelGap = 8,
  double rowHeight = 26,
  double dotRadius = 5,
  double axisHeight = 0,
  double? min,
  double? max,
  int tickCount = 5,
  EdgeInsets padding = EdgeInsets.zero,
  double progress = 1,
}) {
  if (rows.isEmpty) return DumbbellLayout.empty;
  final box = padding.deflateRect(Offset.zero & size);
  if (box.width <= 0 || box.height <= 0) return DumbbellLayout.empty;

  final labels = labelWidth <= 0 ? 0.0 : math.min(labelWidth, box.width * 0.5);
  final left = box.left + labels + (labels > 0 ? labelGap : 0);
  // Room for the dots, so the outermost never gets clipped by the edge.
  final plot = Rect.fromLTRB(
    left + dotRadius,
    box.top,
    box.right - dotRadius,
    math.max(box.top, box.bottom - axisHeight),
  );
  if (plot.width <= 0 || plot.height <= 0) return DumbbellLayout.empty;

  var low = min, high = max;
  if (low == null || high == null) {
    var lo = double.infinity, hi = double.negativeInfinity;
    for (final row in rows) {
      for (final value in [row.from, row.to]) {
        if (!value.isFinite) continue;
        lo = math.min(lo, value);
        hi = math.max(hi, value);
      }
    }
    if (!lo.isFinite || !hi.isFinite) return DumbbellLayout.empty;
    // A little air either side, and a range even when everything is equal.
    final pad = hi > lo ? (hi - lo) * 0.06 : (hi.abs() * 0.05 + 1);
    low ??= lo - pad;
    high ??= hi + pad;
  }
  if (!(high > low)) high = low + 1;

  final height = plot.height / rows.length;
  final t = progress.clamp(0.0, 1.0);
  final span = high - low;
  double xOf(double value) => !value.isFinite
      ? plot.left
      : plot.left + ((value - low!) / span).clamp(0.0, 1.0) * plot.width;

  final laid = <DumbbellRowLayout>[];
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final top = plot.top + i * height;
    final band = Rect.fromLTRB(plot.left, top, plot.right, top + height);
    final y = band.center.dy;
    final fromX = xOf(row.from);
    final toX = fromX + (xOf(row.to) - fromX) * t;
    laid.add(
      DumbbellRowLayout(
        index: i,
        row: row,
        labelRect: Rect.fromLTWH(box.left, top, labels, height),
        trackRect: band,
        fromCenter: Offset(fromX, y),
        toCenter: Offset(toX, y),
      ),
    );
  }

  final ticks = <double>[];
  if (tickCount > 0) {
    for (var i = 0; i <= tickCount; i++) {
      ticks.add(low + span * i / tickCount);
    }
  }

  return DumbbellLayout(
    size: size,
    plotRect: plot,
    rows: laid,
    min: low,
    max: high,
    ticks: ticks,
  );
}

/// Two values a row, joined by a bar — a dumbbell chart.
///
/// Before and after, low and high, bid and ask: the gap is the point, and a
/// bar between two dots shows it far better than two bars side by side.
///
/// ```dart
/// DumbbellChart(
///   rows: const [
///     DumbbellRow(label: 'BTC', from: 61200, to: 68400),
///     DumbbellRow(label: 'ETH', from: 3400, to: 3120),
///   ],
/// );
/// ```
class DumbbellChart extends StatefulWidget {
  /// Creates a dumbbell chart of [rows].
  const DumbbellChart({
    super.key,
    required this.rows,
    this.min,
    this.max,
    this.fromColor = const Color(0xFF909196),
    this.toColor,
    this.riseColor = const Color(0xFF2F9E44),
    this.fallColor = const Color(0xFFE03131),
    this.barColor,
    this.barWidth = 3,
    this.dotRadius = 5,
    this.labelWidth = 92,
    this.labelGap = 8,
    this.rowHeight = 26,
    this.labelStyle,
    this.showAxis = true,
    this.axisHeight = 20,
    this.tickCount = 5,
    this.axisStyle,
    this.axisFormatter,
    this.gridColor = const Color(0x18909196),
    this.showValues = false,
    this.valueStyle,
    this.valueFormatter,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.onRowTap,
    this.tooltipBuilder,
    this.semanticLabel,
  });

  /// The rows, drawn top to bottom in the order given.
  final List<DumbbellRow> rows;

  /// The value at the left of the plot; null takes the smallest, with air.
  final double? min;

  /// The value at its right; null takes the largest, with air.
  final double? max;

  /// What the dot at the start of a bar is painted in.
  final Color fromColor;

  /// What the dot at the end is painted in; null takes [riseColor] where the
  /// row rose and [fallColor] where it fell.
  final Color? toColor;

  /// The end dot of a row that rose, where [toColor] is null.
  final Color riseColor;

  /// The end dot of a row that fell, where [toColor] is null.
  final Color fallColor;

  /// What the bar between the dots is painted in; null takes the end dot's
  /// colour, faded.
  final Color? barColor;

  /// How thick that bar is.
  final double barWidth;

  /// How large the dots are.
  final double dotRadius;

  /// How wide the label column is; 0 writes no labels.
  final double labelWidth;

  /// Space between the labels and the plot.
  final double labelGap;

  /// How tall one row is.
  final double rowHeight;

  /// Style of the row labels.
  final TextStyle? labelStyle;

  /// Whether the value axis is written under the plot.
  final bool showAxis;

  /// How much room that axis takes.
  final double axisHeight;

  /// How many gaps the axis is divided into; 0 draws no gridlines.
  final int tickCount;

  /// Style of the axis labels.
  final TextStyle? axisStyle;

  /// Writes an axis label; null writes the value with as few decimals as it
  /// needs.
  final String Function(double value)? axisFormatter;

  /// The vertical gridlines behind the rows.
  final Color gridColor;

  /// Whether each row's ends are written beside its dots.
  final bool showValues;

  /// Style of those values.
  final TextStyle? valueStyle;

  /// Writes a row's value; null writes it with as few decimals as it needs.
  final String Function(double value)? valueFormatter;

  /// Space kept clear around the chart.
  final EdgeInsets padding;

  /// Painted behind the whole chart.
  final Color? backgroundColor;

  /// How long the bars take to grow out; zero draws them at once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build grows the bars out.
  final bool animateOnMount;

  /// Called with a row when it is touched, and with null when the touch
  /// leaves the rows.
  final void Function(DumbbellRow? row)? onRowTap;

  /// Builds the card shown over a touched row; null shows its label and ends.
  final Widget Function(BuildContext context, DumbbellRow row)? tooltipBuilder;

  /// What a screen reader announces for the chart.
  final String? semanticLabel;

  /// How tall the chart is in a box that sets no height.
  double get intrinsicHeight =>
      padding.vertical +
      rows.length * rowHeight +
      (showAxis ? axisHeight : 0);

  @override
  State<DumbbellChart> createState() => _DumbbellChartState();
}

class _DumbbellChartState extends State<DumbbellChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 128);
  DumbbellLayout _layout = DumbbellLayout.empty;
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
  void didUpdateWidget(DumbbellChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!identical(oldWidget.rows, widget.rows) &&
        widget.animationDuration > Duration.zero) {
      _animation.forward(from: 0);
    }
    if (_touched != null && _touched! >= widget.rows.length) _touched = null;
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void _touch(Offset point) {
    final row = _layout.rowAt(point);
    if (row?.index == _touched) return;
    setState(() => _touched = row?.index);
    widget.onRowTap?.call(row?.row);
  }

  void _clear() {
    if (_touched == null) return;
    setState(() => _touched = null);
    widget.onRowTap?.call(null);
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
              constraints.hasBoundedWidth ? constraints.maxWidth : 360.0;
          final height = constraints.hasBoundedHeight &&
                  constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : widget.intrinsicHeight;
          _layout = layOutDumbbell(
            widget.rows,
            size: Size(width, height),
            labelWidth: widget.labelWidth,
            labelGap: widget.labelGap,
            rowHeight: widget.rowHeight,
            dotRadius: widget.dotRadius,
            axisHeight: widget.showAxis ? widget.axisHeight : 0,
            min: widget.min,
            max: widget.max,
            tickCount: widget.tickCount,
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
                      painter: DumbbellChartPainter(
                        chart: widget,
                        layout: _layout,
                        touched: touched,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (touched != null && touched < _layout.rows.length)
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
    final laid = _layout.rows[index];
    final row = laid.row;
    final build = widget.tooltipBuilder;
    final child = build != null
        ? build(context, row)
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xEE1B1D22),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              row.tooltip ??
                  '${row.label}  ${_number(widget, row.from)} → '
                      '${_number(widget, row.to)}',
              style: const TextStyle(color: Color(0xFFE9ECEF), fontSize: 11),
            ),
          );
    return Positioned(
      left: math.min(laid.fromCenter.dx, laid.toCenter.dx),
      top: math.max(0, laid.trackRect.top - 24),
      child: IgnorePointer(child: child),
    );
  }
}

String _number(DumbbellChart chart, double value) {
  final format = chart.valueFormatter;
  if (format != null) return format(value);
  if (!value.isFinite) return '';
  if (value == value.roundToDouble() && value.abs() < 1e15) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}

/// Paints a [DumbbellChart]: the gridlines, the bars, the dots and the labels.
class DumbbellChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [layout].
  DumbbellChartPainter({
    required this.chart,
    required this.layout,
    required this.touched,
    required this.textCache,
  });

  final DumbbellChart chart;
  final DumbbellLayout layout;

  /// The row under the finger, into [DumbbellChart.rows]; null when none is.
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
    final valueStyle = chart.valueStyle ??
        const TextStyle(color: Color(0xFFE9ECEF), fontSize: 10);

    // The gridlines, and the axis under them.
    final grid = Paint()
      ..color = chart.gridColor
      ..strokeWidth = 1;
    for (final tick in layout.ticks) {
      final x = layout.xOf(tick);
      canvas.drawLine(
        Offset(x, layout.plotRect.top),
        Offset(x, layout.plotRect.bottom),
        grid,
      );
      if (chart.showAxis && chart.axisHeight > 0) {
        final text = chart.axisFormatter?.call(tick) ?? _number(chart, tick);
        final painter = textCache.get(text, axisStyle);
        painter.paint(
          canvas,
          Offset(
            (x - painter.width / 2)
                .clamp(0.0, math.max(0.0, size.width - painter.width)),
            layout.plotRect.bottom + 4,
          ),
        );
      }
    }

    for (final laid in layout.rows) {
      final row = laid.row;
      final end = row.toColor ??
          (row.rose ? chart.riseColor : chart.fallColor);
      final start = row.fromColor ?? chart.fromColor;

      if (touched == laid.index) {
        canvas.drawRect(
          laid.trackRect,
          Paint()..color = const Color(0x14FFFFFF),
        );
      }

      canvas.drawLine(
        laid.fromCenter,
        laid.toCenter,
        Paint()
          ..color = row.barColor ??
              chart.barColor ??
              Color.lerp(end, const Color(0x00000000), 0.45)!
          ..strokeWidth = chart.barWidth
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        laid.fromCenter,
        chart.dotRadius,
        Paint()..color = start,
      );
      canvas.drawCircle(laid.toCenter, chart.dotRadius, Paint()..color = end);

      if (laid.labelRect.width > 4) {
        final painter = textCache.get(row.label, labelStyle);
        canvas.save();
        canvas.clipRect(laid.labelRect);
        painter.paint(
          canvas,
          Offset(
            laid.labelRect.right - painter.width,
            laid.labelRect.center.dy - painter.height / 2,
          ),
        );
        canvas.restore();
      }

      if (chart.showValues) {
        // Written on the outside of each dot, so the bar stays clear.
        final leftFirst = laid.fromCenter.dx <= laid.toCenter.dx;
        _value(canvas, row.from, laid.fromCenter, valueStyle, left: leftFirst);
        _value(canvas, row.to, laid.toCenter, valueStyle, left: !leftFirst);
      }
    }
  }

  void _value(
    Canvas canvas,
    double value,
    Offset at,
    TextStyle style, {
    required bool left,
  }) {
    final text = _number(chart, value);
    if (text.isEmpty) return;
    final painter = textCache.get(text, style);
    final gap = chart.dotRadius + 4;
    painter.paint(
      canvas,
      Offset(
        left ? at.dx - gap - painter.width : at.dx + gap,
        at.dy - painter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(DumbbellChartPainter old) =>
      old.chart != chart || old.layout != layout || old.touched != touched;
}
