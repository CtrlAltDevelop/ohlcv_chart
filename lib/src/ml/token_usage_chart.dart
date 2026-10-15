import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../utils/axis_ticks.dart';
import '../utils/plot_scaffold.dart';
import '../utils/xy_plot.dart';

/// The tokens a model served over one interval, and what they cost.
@immutable
class UsageBucket {
  /// Creates a bucket for the interval starting at [time].
  const UsageBucket({
    required this.time,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cachedTokens = 0,
    this.cost,
    this.data,
  });

  /// When the interval began.
  final DateTime time;

  /// Prompt tokens that were processed.
  final double inputTokens;

  /// Tokens the model generated.
  final double outputTokens;

  /// Prompt tokens served from a cache, which cost less and run faster. Counted
  /// apart from [inputTokens], not inside it.
  final double cachedTokens;

  /// What the interval cost, in the unit of your choice; null draws no point.
  final double? cost;

  /// Anything the app wants back when this bucket is touched.
  final Object? data;

  /// Every token of the interval.
  double get total =>
      _finite(inputTokens) + _finite(outputTokens) + _finite(cachedTokens);

  /// The share of prompt tokens that came from the cache, 0 to 1; zero with no
  /// prompt.
  double get cacheHitRate {
    final prompt = _finite(inputTokens) + _finite(cachedTokens);
    return prompt <= 0 ? 0 : _finite(cachedTokens) / prompt;
  }

  static double _finite(double v) => v.isFinite && v > 0 ? v : 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UsageBucket &&
          other.time == time &&
          other.inputTokens == inputTokens &&
          other.outputTokens == outputTokens &&
          other.cachedTokens == cachedTokens &&
          other.cost == cost &&
          other.data == data;

  @override
  int get hashCode =>
      Object.hash(time, inputTokens, outputTokens, cachedTokens, cost, data);
}

/// What [buckets] add up to.
@immutable
class UsageTotals {
  /// Creates totals from their parts; see [usageTotals].
  const UsageTotals({
    required this.input,
    required this.output,
    required this.cached,
    required this.cost,
  });

  /// Prompt tokens processed.
  final double input;

  /// Tokens generated.
  final double output;

  /// Prompt tokens served from the cache.
  final double cached;

  /// The total cost of the buckets that have one.
  final double cost;

  /// Every token.
  double get tokens => input + output + cached;

  /// The share of prompt tokens served from the cache, 0 to 1.
  double get cacheHitRate {
    final prompt = input + cached;
    return prompt <= 0 ? 0 : cached / prompt;
  }
}

/// Adds [buckets] up. A value that is not finite, or negative, counts as zero.
UsageTotals usageTotals(Iterable<UsageBucket> buckets) {
  var input = 0.0, output = 0.0, cached = 0.0, cost = 0.0;
  for (final b in buckets) {
    input += UsageBucket._finite(b.inputTokens);
    output += UsageBucket._finite(b.outputTokens);
    cached += UsageBucket._finite(b.cachedTokens);
    final c = b.cost;
    if (c != null && c.isFinite) cost += c;
  }
  return UsageTotals(input: input, output: output, cached: cached, cost: cost);
}

/// Writes a token count compactly: `950`, `12.4k`, `3.1M`, `2B`.
String compactCount(double value) {
  if (!value.isFinite) return '–';
  final abs = value.abs();
  String trim(double v) {
    final text = v.toStringAsFixed(v.abs() >= 100 ? 0 : 1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  if (abs >= 1e12) return '${trim(value / 1e12)}T';
  if (abs >= 1e9) return '${trim(value / 1e9)}B';
  if (abs >= 1e6) return '${trim(value / 1e6)}M';
  if (abs >= 1e3) return '${trim(value / 1e3)}k';
  return trim(value);
}

/// What a touch on a [TokenUsageChart] landed on.
@immutable
class UsageTouchDetails {
  /// Creates the details of a touch on the bucket at [index].
  const UsageTouchDetails({required this.index, required this.bucket});

  /// The bucket's position.
  final int index;

  /// The bucket.
  final UsageBucket bucket;
}

/// Token use over time as stacked columns — cached, input and output — with the
/// cost drawn as a line against its own axis.
///
/// ```dart
/// TokenUsageChart(
///   buckets: [
///     for (final d in days)
///       UsageBucket(
///         time: d.date,
///         inputTokens: d.prompt,
///         outputTokens: d.completion,
///         cachedTokens: d.cacheRead,
///         cost: d.dollars,
///       ),
///   ],
///   costFormatter: (v) => '\$${v.toStringAsFixed(0)}',
/// );
/// ```
///
/// The chart fills the box it is given, and is [defaultHeight] high in a box
/// with no height of its own.
class TokenUsageChart extends StatelessWidget {
  /// Creates a chart of [buckets], in time order.
  const TokenUsageChart({
    super.key,
    required this.buckets,
    this.showCost = true,
    this.inputColor = const Color(0xFF4C86CD),
    this.outputColor = const Color(0xFF9775FA),
    this.cachedColor = const Color(0xFF3BC9DB),
    this.costColor = const Color(0xFFF2B01E),
    this.barSpacing = 2,
    this.barRadius = const BorderRadius.vertical(top: Radius.circular(2)),
    this.showLegend = true,
    this.legendStyle,
    this.showAxes = true,
    this.axisWidth = 44,
    this.costAxisWidth = 44,
    this.axisHeight = 18,
    this.tickCount = 5,
    this.tokenFormatter,
    this.costFormatter,
    this.timeFormatter,
    this.axisLabelStyle,
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

  /// The intervals, in time order.
  final List<UsageBucket> buckets;

  /// Whether the cost line and its axis are drawn.
  final bool showCost;

  /// The colour of prompt tokens.
  final Color inputColor;

  /// The colour of generated tokens.
  final Color outputColor;

  /// The colour of cached prompt tokens.
  final Color cachedColor;

  /// The colour of the cost line.
  final Color costColor;

  /// Pixels taken off each side of a column.
  final double barSpacing;

  /// The rounding of a column's top corners.
  final BorderRadius barRadius;

  /// Whether the series are named in the corner.
  final bool showLegend;

  /// Style of the legend.
  final TextStyle? legendStyle;

  /// Whether the axes are drawn.
  final bool showAxes;

  /// Room held for the token axis.
  final double axisWidth;

  /// Room held for the cost axis, when [showCost] and a bucket has a cost.
  final double costAxisWidth;

  /// Room held for the time axis.
  final double axisHeight;

  /// About how many ticks to write on each value axis.
  final int tickCount;

  /// Writes a token count; null writes `12.4k`, `3.1M`.
  final String Function(double value)? tokenFormatter;

  /// Writes a cost; null writes at most two decimals.
  final String Function(double value)? costFormatter;

  /// Writes a time under a column; null writes `HH:mm`, or `MMM d` for buckets
  /// a day or more apart.
  final String Function(DateTime time)? timeFormatter;

  /// Style of an axis label.
  final TextStyle? axisLabelStyle;

  /// Colour of the grid ruled at each tick; null rules none.
  final Color? gridColor;

  /// The colour behind the column under the pointer.
  final Color hoverColor;

  /// Called as a touch moves over the columns, and with null when it leaves.
  final ValueChanged<UsageTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched column; null shows none.
  final Widget? Function(BuildContext context, UsageTouchDetails details)?
  tooltipBuilder;

  /// How far the card sits from the column.
  final double tooltipMargin;

  /// How long the columns take to grow in; zero draws them at once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build animates.
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
  Widget build(BuildContext context) {
    var maxTokens = 0.0;
    var maxCost = 0.0;
    var anyCost = false;
    for (final b in buckets) {
      maxTokens = math.max(maxTokens, b.total);
      final c = b.cost;
      if (c != null && c.isFinite && c > 0) {
        maxCost = math.max(maxCost, c);
        anyCost = true;
      }
    }
    final withCost = showCost && anyCost;
    final tokenMax = maxTokens <= 0 ? 1.0 : maxTokens * 1.08;
    final costMax = maxCost <= 0 ? 1.0 : maxCost * 1.08;

    Rect columnOf(int i, Rect plot) {
      final width = plot.width / buckets.length;
      return Rect.fromLTWH(plot.left + i * width, plot.top, width, plot.height);
    }

    UsageTouchDetails? hit(Offset local, Rect plot) {
      if (buckets.isEmpty ||
          plot.width <= 0 ||
          local.dx < plot.left ||
          local.dx > plot.right ||
          local.dy < plot.top ||
          local.dy > plot.bottom + 1) {
        return null;
      }
      final i = (((local.dx - plot.left) / plot.width) * buckets.length)
          .floor()
          .clamp(0, buckets.length - 1);
      return UsageTouchDetails(index: i, bucket: buckets[i]);
    }

    return PlotScaffold<UsageTouchDetails>(
      restartKey: Object.hashAll([...buckets, showCost]),
      insets: EdgeInsets.fromLTRB(
        showAxes ? axisWidth : 0,
        0,
        showAxes && withCost ? costAxisWidth : 0,
        showAxes ? axisHeight : 0,
      ),
      padding: padding,
      backgroundColor: backgroundColor,
      defaultHeight: defaultHeight,
      animationDuration: animationDuration,
      animationCurve: animationCurve,
      animateOnMount: animateOnMount,
      semanticLabel: semanticLabel,
      tooltipMargin: tooltipMargin,
      onTouch: onTouch,
      tooltipBuilder: tooltipBuilder,
      hitTest: hit,
      keyOf: (d) => d.index,
      anchorOf: (d, plot) => columnOf(d.index, plot),
      painter: (plot, t, text, hovered) => _UsagePainter(
        chart: this,
        tokenMax: tokenMax,
        costMax: costMax,
        withCost: withCost,
        hovered: hovered?.index,
        plot: plot,
        animation: t,
        text: text,
        backgroundColor: backgroundColor,
      ),
    );
  }
}

class _UsagePainter extends PlotPainter {
  _UsagePainter({
    required this.chart,
    required this.tokenMax,
    required this.costMax,
    required this.withCost,
    required this.hovered,
    required super.plot,
    required super.animation,
    required super.text,
    super.backgroundColor,
  });

  final TokenUsageChart chart;
  final double tokenMax;
  final double costMax;
  final bool withCost;
  final int? hovered;

  @override
  void paintPlot(Canvas canvas, Size size) {
    final buckets = chart.buckets;
    final t = animation.clamp(0.0, 1.0);
    final labelStyle = const TextStyle(
      fontSize: 10,
      color: Color(0xFF8B95A1),
    ).merge(chart.axisLabelStyle);

    // Grid and the token axis.
    final grid = chart.gridColor == null
        ? null
        : (Paint()
            ..color = chart.gridColor!
            ..strokeWidth = 1);
    for (final tick in niceTicks(0, tokenMax, target: chart.tickCount)) {
      final y = mapAcross(tick, 0, tokenMax, plot.bottom, plot.top);
      if (grid != null) {
        canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      }
      if (!chart.showAxes) continue;
      final tp = text.get(
        (chart.tokenFormatter ?? compactCount)(tick),
        labelStyle,
      );
      if (plot.left - 6 - tp.width >= 0) {
        tp.paint(canvas, Offset(plot.left - 6 - tp.width, y - tp.height / 2));
      }
    }

    if (buckets.isEmpty) return;
    final width = plot.width / buckets.length;

    // Columns: cached at the bottom, then input, then output.
    for (var i = 0; i < buckets.length; i++) {
      final b = buckets[i];
      final x = plot.left + i * width;
      if (hovered == i) {
        canvas.drawRect(
          Rect.fromLTWH(x, plot.top, width, plot.height),
          Paint()..color = chart.hoverColor,
        );
      }
      final inset = math.min(chart.barSpacing, width / 3);
      var base = plot.bottom;
      final parts = [
        (UsageBucket._finite(b.cachedTokens), chart.cachedColor),
        (UsageBucket._finite(b.inputTokens), chart.inputColor),
        (UsageBucket._finite(b.outputTokens), chart.outputColor),
      ];
      final tops = parts.where((p) => p.$1 > 0).length;
      var drawn = 0;
      for (final (value, color) in parts) {
        if (value <= 0) continue;
        drawn++;
        final h = value / tokenMax * plot.height * t;
        final rect = Rect.fromLTRB(
          x + inset,
          base - h,
          x + width - inset,
          base,
        );
        final radius = drawn == tops
            ? BorderRadius.only(
                topLeft: chart.barRadius.topLeft,
                topRight: chart.barRadius.topRight,
              )
            : BorderRadius.zero;
        canvas.drawRRect(
          radius.toRRect(rect),
          Paint()
            ..color = color
            ..isAntiAlias = true,
        );
        base -= h;
      }
    }

    // Time labels, thinned so they do not collide.
    if (chart.showAxes) {
      var written = -double.infinity;
      final days = buckets.length > 1
          ? buckets[1].time.difference(buckets[0].time).inHours >= 24
          : false;
      for (var i = 0; i < buckets.length; i++) {
        final label = text.get(_time(buckets[i].time, days), labelStyle);
        final left = plot.left + (i + 0.5) * width - label.width / 2;
        if (left < written || left + label.width > plot.right + 4) continue;
        label.paint(canvas, Offset(left, plot.bottom + 3));
        written = left + label.width + 6;
      }
    }

    if (withCost) _paintCost(canvas, width, t, labelStyle);
    _paintLegend(canvas);
  }

  String _time(DateTime time, bool days) {
    if (chart.timeFormatter != null) return chart.timeFormatter!(time);
    String two(int n) => n.toString().padLeft(2, '0');
    if (days) {
      const m = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${m[time.month - 1]} ${time.day}';
    }
    return '${two(time.hour)}:${two(time.minute)}';
  }

  void _paintCost(Canvas canvas, double width, double t, TextStyle style) {
    final points = <Offset>[];
    for (var i = 0; i < chart.buckets.length; i++) {
      final c = chart.buckets[i].cost;
      if (c == null || !c.isFinite) continue;
      points.add(
        Offset(
          plot.left + (i + 0.5) * width,
          mapAcross(c, 0, costMax, plot.bottom, plot.top),
        ),
      );
    }
    if (points.isNotEmpty) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final o in points.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      canvas
        ..save()
        ..clipRect(
          Rect.fromLTRB(
            plot.left,
            plot.top,
            plot.left + plot.width * t,
            plot.bottom + 2,
          ),
        )
        ..drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeJoin = StrokeJoin.round
            ..color = chart.costColor
            ..isAntiAlias = true,
        );
      for (final o in points) {
        canvas.drawCircle(
          o,
          3,
          Paint()
            ..color = chart.costColor
            ..isAntiAlias = true,
        );
      }
      canvas.restore();
    }
    if (chart.showAxes) {
      for (final tick in niceTicks(0, costMax, target: chart.tickCount)) {
        final y = mapAcross(tick, 0, costMax, plot.bottom, plot.top);
        final tp = text.get(
          formatPlotNumber(tick, chart.costFormatter),
          style.copyWith(color: chart.costColor),
        );
        tp.paint(canvas, Offset(plot.right + 6, y - tp.height / 2));
      }
    }
  }

  void _paintLegend(Canvas canvas) {
    if (!chart.showLegend) return;
    final style = const TextStyle(
      fontSize: 10,
      color: Color(0xCCFFFFFF),
    ).merge(chart.legendStyle);
    var top = plot.top + 4;
    for (final (name, color) in [
      ('Output', chart.outputColor),
      ('Input', chart.inputColor),
      ('Cached', chart.cachedColor),
      if (withCost) ('Cost', chart.costColor),
    ]) {
      final tp = text.get(name, style);
      final left = plot.left + 8;
      canvas.drawRect(
        Rect.fromLTWH(left, top + tp.height / 2 - 4, 8, 8),
        Paint()..color = color,
      );
      tp.paint(canvas, Offset(left + 13, top));
      top += tp.height + 3;
    }
  }
}
