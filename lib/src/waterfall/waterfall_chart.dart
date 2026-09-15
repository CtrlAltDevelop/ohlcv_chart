import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';
import '../series/series_axis.dart';
import '../utils/axis_ticks.dart';

/// Whether a step moves the running total or reports it.
enum WaterfallKind {
  /// Adds its value to what came before.
  delta,

  /// Stands on the baseline and shows the running total so far — an opening
  /// or closing balance, or a subtotal.
  total,
}

/// One step of a [WaterfallChart] — a fee, a win, a closing balance.
@immutable
class WaterfallStep {
  /// Creates a step worth [value].
  const WaterfallStep({
    required this.value,
    this.label,
    this.kind = WaterfallKind.delta,
    this.color,
    this.data,
  });

  /// Creates a step standing on the baseline: a total or subtotal.
  ///
  /// Its [value] is ignored when it is not the first step — the running total
  /// is drawn instead — so an opening balance can be given a value and a
  /// closing one need not repeat it.
  const WaterfallStep.total({
    double value = 0,
    String? label,
    Color? color,
    Object? data,
  }) : this(
          value: value,
          label: label,
          kind: WaterfallKind.total,
          color: color,
          data: data,
        );

  /// How much the step moves the total, or what a first total starts at.
  final double value;

  /// What the step is called, written under its bar.
  final String? label;

  /// Whether it moves the total or reports it.
  final WaterfallKind kind;

  /// A colour of this step's own.
  final Color? color;

  /// Anything the app wants back when this step is touched.
  final Object? data;
}

/// Where one [WaterfallStep] was laid out.
@immutable
class WaterfallBar {
  /// Creates the bar of [step].
  const WaterfallBar({
    required this.step,
    required this.index,
    required this.rect,
    required this.band,
    required this.start,
    required this.end,
  });

  /// The step this bar draws.
  final WaterfallStep step;

  /// Its position from the left.
  final int index;

  /// The bar itself.
  final Rect rect;

  /// The whole column it owns; what a touch is tested against.
  final Rect band;

  /// The running total the bar begins at.
  final double start;

  /// The running total it ends at.
  final double end;

  /// How much it moved: zero for a total, which only reports.
  double get change => end - start;

  /// Whether it reports the running total rather than moving it.
  bool get isTotal => step.kind == WaterfallKind.total;

  /// Whether [local] is in this column.
  bool contains(Offset local) => band.contains(local);
}

/// The running total after each of [steps].
///
/// A delta adds its value; a total holds whatever the running total already
/// is, except as the first step, where it sets it.
List<double> waterfallTotals(List<WaterfallStep> steps) {
  var running = 0.0;
  final out = <double>[];
  for (var i = 0; i < steps.length; i++) {
    final step = steps[i];
    final value = step.value.isFinite ? step.value : 0.0;
    if (step.kind == WaterfallKind.total) {
      if (i == 0) running = value;
    } else {
      running += value;
    }
    out.add(running);
  }
  return out;
}

/// The value range [steps] need, taking in every running total and zero.
({double min, double max}) waterfallRange(List<WaterfallStep> steps) {
  final totals = waterfallTotals(steps);
  var min = 0.0;
  var max = 0.0;
  for (final total in totals) {
    if (!total.isFinite) continue;
    min = math.min(min, total);
    max = math.max(max, total);
  }
  if (min == max) return (min: min - 1, max: max + 1);
  final room = (max - min) * 0.08;
  return (min: min - room, max: max + room);
}

/// Lays [steps] out across [bounds], each bar picking up where the last left
/// off.
List<WaterfallBar> layOutWaterfall(
  List<WaterfallStep> steps,
  Rect bounds, {
  required double min,
  required double max,
  double barWidthFraction = 0.6,
  double maxBarWidth = 72,
  double minBarHeight = 1,
}) {
  if (steps.isEmpty || bounds.width <= 0 || bounds.height <= 0) {
    return const [];
  }

  final totals = waterfallTotals(steps);
  final span = max - min;
  double y(double value) => span <= 0
      ? bounds.center.dy
      : bounds.bottom - (value - min) / span * bounds.height;

  final column = bounds.width / steps.length;
  final width = math.min(
    maxBarWidth,
    column * barWidthFraction.clamp(0.05, 1.0),
  );

  return [
    for (var i = 0; i < steps.length; i++)
      () {
        final step = steps[i];
        final end = totals[i];
        final start = step.kind == WaterfallKind.total
            ? 0.0
            : (i == 0 ? 0.0 : totals[i - 1]);
        final centerX = bounds.left + column * (i + 0.5);
        final top = math.min(y(start), y(end));
        final bottom = math.max(y(start), y(end));
        return WaterfallBar(
          step: step,
          index: i,
          start: start,
          end: end,
          band: Rect.fromLTWH(
            bounds.left + column * i,
            bounds.top,
            column,
            bounds.height,
          ),
          rect: Rect.fromLTRB(
            centerX - width / 2,
            top,
            centerX + width / 2,
            math.max(bottom, top + math.max(0.0, minBarHeight)),
          ),
        );
      }(),
  ];
}

/// The bar whose column holds [local], or null when there is none.
WaterfallBar? waterfallBarAt(List<WaterfallBar> bars, Offset local) {
  for (final bar in bars) {
    if (bar.contains(local)) return bar;
  }
  return null;
}

/// What a touch on a [WaterfallChart] landed on.
@immutable
class WaterfallTouchDetails {
  /// Creates the details of a touch on [bar].
  const WaterfallTouchDetails({required this.bar});

  /// The bar touched.
  final WaterfallBar bar;

  /// The step it draws.
  WaterfallStep get step => bar.step;
}

/// How a total was got to, step by step — a waterfall, or bridge chart.
///
/// Each bar picks up where the last left off, so gains and losses are read
/// against the running total rather than against zero.
///
/// ```dart
/// WaterfallChart(
///   steps: const [
///     WaterfallStep.total(value: 10000, label: 'Opening'),
///     WaterfallStep(value: 2400, label: 'Wins'),
///     WaterfallStep(value: -1600, label: 'Losses'),
///     WaterfallStep(value: -180, label: 'Fees'),
///     WaterfallStep.total(label: 'Closing'),
///   ],
/// );
/// ```
///
/// The chart fills the box it is given, and is [defaultHeight] high in a box
/// with no height of its own.
class WaterfallChart extends StatefulWidget {
  /// Creates a waterfall of [steps], left to right.
  const WaterfallChart({
    super.key,
    required this.steps,
    this.min,
    this.max,
    this.barWidthFraction = 0.6,
    this.maxBarWidth = 72,
    this.riseColor = const Color(0xFF2F9E44),
    this.fallColor = const Color(0xFFE03131),
    this.totalColor = const Color(0xFF4C86CD),
    this.barRadius = 2,
    this.showConnectors = true,
    this.connectorColor = const Color(0x55FFFFFF),
    this.showValues = true,
    this.valueStyle,
    this.valueFormatter,
    this.showLabels = true,
    this.labelStyle,
    this.labelHeight = 18,
    this.showValueAxis = true,
    this.axisWidth = 52,
    this.tickCount = 5,
    this.axisLabelStyle,
    this.gridColor = const Color(0x22FFFFFF),
    this.baselineColor = const Color(0x66FFFFFF),
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

  /// The steps, left to right.
  final List<WaterfallStep> steps;

  /// The bottom of the value axis; null reads it off the steps.
  final double? min;

  /// The top of it; null reads it off the steps.
  final double? max;

  /// How much of its column a bar takes.
  final double barWidthFraction;

  /// The widest a bar is drawn.
  final double maxBarWidth;

  /// The colour of a step that added.
  final Color riseColor;

  /// The colour of one that took away.
  final Color fallColor;

  /// The colour of a total or subtotal.
  final Color totalColor;

  /// How rounded a bar is.
  final double barRadius;

  /// Whether a line joins each bar to the next.
  final bool showConnectors;

  /// The colour of those lines.
  final Color connectorColor;

  /// Whether each step's change is written above or below its bar.
  final bool showValues;

  /// Style of that number.
  final TextStyle? valueStyle;

  /// Writes a value; null groups thousands and signs deltas.
  final String Function(double value)? valueFormatter;

  /// Whether the step names are written under the bars.
  final bool showLabels;

  /// Style of a step name.
  final TextStyle? labelStyle;

  /// How much room the names take.
  final double labelHeight;

  /// Whether the value axis is written down the left.
  final bool showValueAxis;

  /// How much room it takes.
  final double axisWidth;

  /// About how many ticks to write.
  final int tickCount;

  /// Style of an axis label.
  final TextStyle? axisLabelStyle;

  /// Colour of the grid ruled at each tick; null rules none.
  final Color? gridColor;

  /// Colour of the line at zero; null draws none.
  final Color? baselineColor;

  /// Painted behind the column under the pointer; null marks none.
  final Color? hoverColor;

  /// Called as a touch moves over the steps, and with null when it leaves.
  final ValueChanged<WaterfallTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched step; null shows none.
  final Widget? Function(BuildContext context, WaterfallTouchDetails details)?
      tooltipBuilder;

  /// How far the card sits from the bar.
  final double tooltipMargin;

  /// How long the bars take to grow into place; zero draws them at once.
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
  State<WaterfallChart> createState() => _WaterfallChartState();
}

class _WaterfallChartState extends State<WaterfallChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 64);
  List<WaterfallBar> _bars = const [];
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
  void didUpdateWidget(WaterfallChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!identical(oldWidget.steps, widget.steps)) {
      if (_touched != null && _touched! >= widget.steps.length) {
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
    final index = waterfallBarAt(_bars, local)?.index;
    if (index == _touched) return;
    setState(() => _touched = index);
    widget.onTouch?.call(
      index == null ? null : WaterfallTouchDetails(bar: _bars[index]),
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
    final range = waterfallRange(widget.steps);
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
          box.left + (widget.showValueAxis ? widget.axisWidth : 0),
          box.top,
          box.right,
          math.max(
            box.top,
            box.bottom - (widget.showLabels ? widget.labelHeight : 0),
          ),
        );
        _bars = layOutWaterfall(
          widget.steps,
          plot,
          min: min,
          max: max,
          barWidthFraction: widget.barWidthFraction,
          maxBarWidth: widget.maxBarWidth,
        );

        final touched = _touched;
        final details = touched == null || touched >= _bars.length
            ? null
            : WaterfallTouchDetails(bar: _bars[touched]);
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
                      painter: WaterfallChartPainter(
                        chart: widget,
                        bars: _bars,
                        plot: plot,
                        min: min,
                        max: max,
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
                          delegate: _WaterfallTooltipLayout(
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
class _WaterfallTooltipLayout extends SingleChildLayoutDelegate {
  _WaterfallTooltipLayout({required this.anchor, required this.margin});

  final Rect anchor;
  final double margin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var top = anchor.top - margin - childSize.height;
    if (top < 0) top = anchor.bottom + margin;
    return Offset(
      (anchor.center.dx - childSize.width / 2).clamp(
        0.0,
        math.max(0.0, size.width - childSize.width),
      ),
      top.clamp(0.0, math.max(0.0, size.height - childSize.height)),
    );
  }

  @override
  bool shouldRelayout(_WaterfallTooltipLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.margin != margin;
}

/// Paints a [WaterfallChart]: the axis, the bars, the connectors and the
/// labels.
class WaterfallChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [bars] inside [plot].
  WaterfallChartPainter({
    required this.chart,
    required this.bars,
    required this.plot,
    required this.min,
    required this.max,
    required this.touched,
    required this.animation,
    required this.textCache,
  });

  final WaterfallChart chart;
  final List<WaterfallBar> bars;
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
    if (bars.isEmpty) return;

    _paintAxis(canvas);

    final hover = chart.hoverColor;
    final at = touched;
    if (at != null && at < bars.length && hover != null) {
      canvas.drawRect(bars[at].band, Paint()..color = hover);
    }

    final t = animation.clamp(0.0, 1.0);
    final radius = Radius.circular(math.max(0, chart.barRadius));
    final fill = Paint()..isAntiAlias = true;

    for (final bar in bars) {
      // Each bar grows out of the total it starts from.
      final anchor = bar.isTotal ? bar.rect.bottom : _y(bar.start);
      final rect = Rect.fromLTRB(
        bar.rect.left,
        anchor + (bar.rect.top - anchor) * t,
        bar.rect.right,
        anchor + (bar.rect.bottom - anchor) * t,
      );
      fill.color = _colorOf(bar);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), fill);
      if (t >= 1) _paintValue(canvas, bar);
      if (chart.showLabels) _paintLabel(canvas, bar);
    }

    if (chart.showConnectors && t >= 1) _paintConnectors(canvas);
  }

  double _y(double value) {
    final span = max - min;
    return span <= 0
        ? plot.center.dy
        : plot.bottom - (value - min) / span * plot.height;
  }

  Color _colorOf(WaterfallBar bar) {
    final own = bar.step.color;
    if (own != null) return own;
    if (bar.isTotal) return chart.totalColor;
    return bar.change >= 0 ? chart.riseColor : chart.fallColor;
  }

  void _paintConnectors(Canvas canvas) {
    final pen = Paint()
      ..color = chart.connectorColor
      ..strokeWidth = 1;
    for (var i = 0; i < bars.length - 1; i++) {
      final y = _y(bars[i].end);
      canvas.drawLine(
        Offset(bars[i].rect.right, y),
        Offset(bars[i + 1].rect.left, y),
        pen,
      );
    }
  }

  void _paintValue(Canvas canvas, WaterfallBar bar) {
    if (!chart.showValues) return;
    final value = bar.isTotal ? bar.end : bar.change;
    final style = chart.valueStyle ??
        seriesAxisLabelStyle.copyWith(fontWeight: FontWeight.w600);
    final tp = textCache.get(_format(value, signed: !bar.isTotal), style);
    if (tp.width > bar.band.width) return;
    // Above a bar that rose, below one that fell, so the number never sits on
    // the bar it belongs to.
    final rising = bar.isTotal || bar.change >= 0;
    final top = rising ? bar.rect.top - tp.height - 2 : bar.rect.bottom + 2;
    if (top < plot.top || top + tp.height > plot.bottom) return;
    tp.paint(canvas, Offset(bar.rect.center.dx - tp.width / 2, top));
  }

  void _paintLabel(Canvas canvas, WaterfallBar bar) {
    final name = bar.step.label;
    if (name == null || name.isEmpty) return;
    final style = seriesAxisLabelStyle.merge(chart.labelStyle);
    final tp = textCache.get(name, style);
    if (tp.width > bar.band.width) return;
    tp.paint(
      canvas,
      Offset(bar.rect.center.dx - tp.width / 2, plot.bottom + 3),
    );
  }

  void _paintAxis(Canvas canvas) {
    final grid = chart.gridColor;
    if (chart.showValueAxis || grid != null) {
      final style = seriesAxisLabelStyle.merge(chart.axisLabelStyle);
      final line = grid == null
          ? null
          : (Paint()
            ..color = grid
            ..strokeWidth = 1);
      for (final tick in niceTicks(min, max, target: chart.tickCount)) {
        final y = _y(tick);
        if (line != null) {
          canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), line);
        }
        if (!chart.showValueAxis) continue;
        final tp = textCache.get(_format(tick), style);
        final left = plot.left - 6 - tp.width;
        if (left >= 0) tp.paint(canvas, Offset(left, y - tp.height / 2));
      }
    }

    final baseline = chart.baselineColor;
    if (baseline == null || min > 0 || max < 0) return;
    final y = _y(0);
    canvas.drawLine(
      Offset(plot.left, y),
      Offset(plot.right, y),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );
  }

  String _format(double value, {bool signed = false}) {
    final format = chart.valueFormatter;
    if (format != null) return format(value);
    final whole = value.round();
    final grouped = whole.abs().toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => ',',
        );
    if (whole < 0) return '-$grouped';
    return signed && whole > 0 ? '+$grouped' : grouped;
  }

  @override
  bool shouldRepaint(WaterfallChartPainter oldDelegate) =>
      !identical(oldDelegate.chart, chart) ||
      !identical(oldDelegate.bars, bars) ||
      oldDelegate.plot != plot ||
      oldDelegate.min != min ||
      oldDelegate.max != max ||
      oldDelegate.touched != touched ||
      oldDelegate.animation != animation;
}
