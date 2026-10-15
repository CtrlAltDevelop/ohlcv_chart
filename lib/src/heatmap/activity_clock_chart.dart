import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';
import '../series/series_axis.dart';
import 'heatmap_data.dart';
import 'seasonality_chart.dart';

/// Where one square of an [ActivityClockChart] was laid out: a segment of a
/// ring.
@immutable
class ClockSegment {
  /// Creates the segment at [row] and [column].
  const ClockSegment({
    required this.row,
    required this.column,
    required this.innerRadius,
    required this.outerRadius,
    required this.startAngle,
    required this.sweep,
  });

  /// Which ring, counted from the inside.
  final int row;

  /// Which hour, counted from the top, clockwise.
  final int column;

  /// How far from the centre it begins.
  final double innerRadius;

  /// How far from the centre it ends.
  final double outerRadius;

  /// Where it starts, in radians, as the canvas reads them: 0 is three
  /// o'clock and the angle grows clockwise.
  final double startAngle;

  /// How far round it goes, in radians.
  final double sweep;

  /// The angle of its middle.
  double get midAngle => startAngle + sweep / 2;

  /// The radius of its middle.
  double get midRadius => (innerRadius + outerRadius) / 2;
}

/// Lays a clock of [rows] rings of [columns] segments inside [bounds].
///
/// The clock is the largest circle that fits, centred; its rings run from
/// [innerFraction] of the radius out to the edge, with [ringGap] pixels
/// between them. The first column starts at twelve o'clock and they run
/// clockwise, so the hours of a day read as a clock face.
///
/// Returns an empty list when there is no room or nothing to lay out.
List<ClockSegment> layOutClock(
  int rows,
  int columns,
  Rect bounds, {
  double innerFraction = 0.25,
  double ringGap = 2,
  double angleGap = 0.01,
}) {
  if (rows <= 0 || columns <= 0 || bounds.width <= 0 || bounds.height <= 0) {
    return const [];
  }
  final radius = math.min(bounds.width, bounds.height) / 2;
  if (radius <= 0) return const [];

  final inner = radius * innerFraction.clamp(0.0, 0.9);
  final pitch = (radius - inner) / rows;
  final step = 2 * math.pi / columns;
  final sweep = math.max(0.0, step - angleGap);
  return [
    for (var r = 0; r < rows; r++)
      for (var c = 0; c < columns; c++)
        ClockSegment(
          row: r,
          column: c,
          innerRadius: inner + r * pitch + (r == 0 ? 0 : ringGap / 2),
          outerRadius:
              inner + (r + 1) * pitch - (r == rows - 1 ? 0 : ringGap / 2),
          startAngle: -math.pi / 2 + c * step + angleGap / 2,
          sweep: sweep,
        ),
  ];
}

/// The segment under [local] on a clock centred at [center], or null when the
/// point is in the hole in the middle, outside the rings, or in a gap.
ClockSegment? clockSegmentAt(
  List<ClockSegment> segments,
  Offset center,
  Offset local,
) {
  if (segments.isEmpty) return null;
  final delta = local - center;
  final radius = delta.distance;
  // The angle clockwise from twelve o'clock, in 0..2π.
  var angle = math.atan2(delta.dy, delta.dx) + math.pi / 2;
  while (angle < 0) {
    angle += 2 * math.pi;
  }
  angle %= 2 * math.pi;

  for (final segment in segments) {
    if (radius < segment.innerRadius || radius > segment.outerRadius) continue;
    var from = segment.startAngle + math.pi / 2;
    while (from < 0) {
      from += 2 * math.pi;
    }
    from %= 2 * math.pi;
    var offset = angle - from;
    if (offset < 0) offset += 2 * math.pi;
    if (offset <= segment.sweep) return segment;
  }
  return null;
}

/// What a touch on an [ActivityClockChart] landed on.
@immutable
class ActivityClockTouchDetails {
  /// Creates the details of a touch on the segment at [weekday] and [hour].
  const ActivityClockTouchDetails({
    required this.weekday,
    required this.hour,
    required this.weekdayLabel,
    required this.value,
    required this.count,
  });

  /// The weekday, 0 for Monday to 6 for Sunday.
  final int weekday;

  /// The hour of the day, 0 to 23.
  final int hour;

  /// What the weekday is called.
  final String weekdayLabel;

  /// The segment's value; null where no sample fell.
  final double? value;

  /// How many samples fell there.
  final int count;
}

/// A week as a clock face: an hour of the day round the dial, a weekday on
/// each ring, every segment coloured by what happened then.
///
/// ```dart
/// ActivityClockChart(
///   samples: [for (final t in trades) SeasonalSample(time: t.openedAt, value: t.pnl)],
///   aggregate: SeasonalityAggregate.mean,
/// );
/// ```
///
/// Where [SeasonalityChart] lays the same numbers out in a grid, this wraps the
/// day round so the quiet night and the busy open are a shape rather than a
/// column. Twelve o'clock is midnight and the hours run clockwise; Monday is
/// the innermost ring. The chart fills the largest square its box allows, and is
/// [defaultHeight] high in a box with no height of its own.
class ActivityClockChart extends StatefulWidget {
  /// Creates a clock of [samples].
  const ActivityClockChart({
    super.key,
    required this.samples,
    this.aggregate = SeasonalityAggregate.mean,
    this.weekdayLabels = seasonalityWeekdayLabels,
    this.scale = const HeatmapGradientScale(
      colors: [Color(0x224C86CD), Color(0xFF4C86CD)],
    ),
    this.minValue,
    this.maxValue,
    this.innerFraction = 0.28,
    this.ringGap = 2,
    this.showHourLabels = true,
    this.hourLabelStep = 3,
    this.showWeekdayLabels = true,
    this.labelStyle,
    this.hoverBorder = const BorderSide(color: Color(0xCCFFFFFF), width: 1.5),
    this.onTouch,
    this.tooltipBuilder,
    this.tooltipMargin = 10,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.defaultHeight = 300,
    this.semanticLabel,
  });

  /// The values to gather, each placed in time.
  final List<SeasonalSample> samples;

  /// How the samples falling in one segment are made into its value.
  final SeasonalityAggregate aggregate;

  /// The weekday names, Monday first.
  final List<String> weekdayLabels;

  /// How a value becomes a colour.
  final HeatmapScale scale;

  /// The value painted at the low end of [scale]; null takes the lowest
  /// segment (zero for counts).
  final double? minValue;

  /// The value painted at the high end; null takes the highest segment.
  final double? maxValue;

  /// How much of the radius the empty hole in the middle takes.
  final double innerFraction;

  /// The gap between rings, in pixels.
  final double ringGap;

  /// Whether the hours are written round the outside.
  final bool showHourLabels;

  /// Write an hour every this many hours.
  final int hourLabelStep;

  /// Whether the weekdays are written up the twelve o'clock line.
  final bool showWeekdayLabels;

  /// Style of the hour and weekday labels.
  final TextStyle? labelStyle;

  /// Drawn round the segment under the pointer; null marks none.
  final BorderSide? hoverBorder;

  /// Called as a touch moves over the segments, and with null when it leaves.
  final ValueChanged<ActivityClockTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched segment; null shows none.
  final Widget? Function(
    BuildContext context,
    ActivityClockTouchDetails details,
  )?
  tooltipBuilder;

  /// How far the card sits from the segment.
  final double tooltipMargin;

  /// How long the segments take to fade in; zero draws them at once.
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
  State<ActivityClockChart> createState() => _ActivityClockChartState();
}

class _ActivityClockChartState extends State<ActivityClockChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 64);
  List<ClockSegment> _segments = const [];
  Offset _center = Offset.zero;
  ({int row, int column})? _touched;

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
  void didUpdateWidget(ActivityClockChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!listEquals(oldWidget.samples, widget.samples)) {
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

  // Gathering the samples is a pass over all of them, and build runs on every
  // frame of the animation, so the table is kept until its inputs change.
  SeasonalityTable? _table;
  List<SeasonalSample>? _tableSamples;
  int _tableLength = -1;
  SeasonalityAggregate? _tableAggregate;
  List<String>? _tableLabels;

  SeasonalityTable _tableFor() {
    final samples = widget.samples;
    final cached = _table;
    if (cached == null ||
        !identical(_tableSamples, samples) ||
        _tableLength != samples.length ||
        _tableAggregate != widget.aggregate ||
        !identical(_tableLabels, widget.weekdayLabels)) {
      _tableSamples = samples;
      _tableLength = samples.length;
      _tableAggregate = widget.aggregate;
      _tableLabels = widget.weekdayLabels;
      return _table = seasonalityTable(
        samples,
        grid: SeasonalityGrid.weekdayByHour,
        aggregate: widget.aggregate,
        weekdayLabels: widget.weekdayLabels,
      );
    }
    return cached;
  }

  ActivityClockTouchDetails _details(
    SeasonalityTable table,
    ClockSegment segment,
  ) => ActivityClockTouchDetails(
    weekday: segment.row,
    hour: segment.column,
    weekdayLabel: table.rowLabels[segment.row],
    value: table.values[segment.row][segment.column],
    count: table.counts[segment.row][segment.column],
  );

  void _handle(Offset local, SeasonalityTable table) {
    final segment = clockSegmentAt(_segments, _center, local);
    final key = segment == null
        ? null
        : (row: segment.row, column: segment.column);
    if (key == _touched) return;
    setState(() => _touched = key);
    widget.onTouch?.call(segment == null ? null : _details(table, segment));
  }

  void _leave() {
    if (_touched == null) return;
    setState(() => _touched = null);
    widget.onTouch?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.animationCurve.transform(_animation.value);
    final table = _tableFor();

    // The value the scale runs between: the largest segment, and zero for a
    // count or the smallest segment otherwise.
    double? low;
    double? high;
    for (final row in table.values) {
      for (final value in row) {
        if (value == null || !value.isFinite) continue;
        low = low == null ? value : math.min(low, value);
        high = high == null ? value : math.max(high, value);
      }
    }
    final minValue =
        widget.minValue ??
        (widget.aggregate == SeasonalityAggregate.count ? 0.0 : low ?? 0.0);
    final maxValue = widget.maxValue ?? high ?? 1.0;

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
        // Room round the dial for the hour labels.
        final margin = widget.showHourLabels ? 20.0 : 2.0;
        final dial = box.deflate(margin);
        final diameter = math.max(0.0, math.min(dial.width, dial.height));
        final dialRect = Rect.fromCenter(
          center: box.center,
          width: diameter,
          height: diameter,
        );
        _center = dialRect.center;
        _segments = layOutClock(
          table.rowCount,
          table.columnCount,
          dialRect,
          innerFraction: widget.innerFraction,
          ringGap: widget.ringGap,
        );

        final touched = _touched;
        final segment = touched == null
            ? null
            : _segments
                  .where(
                    (s) => s.row == touched.row && s.column == touched.column,
                  )
                  .firstOrNull;
        final builder = widget.tooltipBuilder;
        final tooltip = segment == null || builder == null
            ? null
            : builder(context, _details(table, segment));

        return SizedBox(
          width: width,
          height: height,
          child: MouseRegion(
            onHover: (e) => _handle(e.localPosition, table),
            onExit: (_) => _leave(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _handle(d.localPosition, table),
              onTapUp: (_) => _leave(),
              onTapCancel: _leave,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: ActivityClockChartPainter(
                        chart: widget,
                        table: table,
                        segments: _segments,
                        center: _center,
                        minValue: minValue,
                        maxValue: maxValue,
                        touched: touched,
                        animation: t,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (tooltip != null && segment != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomSingleChildLayout(
                          delegate: _ClockTooltipLayout(
                            anchor: Rect.fromCircle(
                              center:
                                  _center +
                                  Offset.fromDirection(
                                    segment.midAngle,
                                    segment.midRadius,
                                  ),
                              radius: 4,
                            ),
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

class _ClockTooltipLayout extends SingleChildLayoutDelegate {
  _ClockTooltipLayout({required this.anchor, required this.margin});

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
  bool shouldRelayout(_ClockTooltipLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.margin != margin;
}

/// Paints an [ActivityClockChart]: the rings, the hours and the weekdays.
class ActivityClockChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [segments] round [center].
  ActivityClockChartPainter({
    required this.chart,
    required this.table,
    required this.segments,
    required this.center,
    required this.minValue,
    required this.maxValue,
    required this.touched,
    required this.animation,
    required this.textCache,
  });

  /// The chart being painted.
  final ActivityClockChart chart;

  /// What fell in each segment.
  final SeasonalityTable table;

  /// Where each segment sits.
  final List<ClockSegment> segments;

  /// The middle of the dial.
  final Offset center;

  /// The values the colour scale runs between.
  final double minValue, maxValue;

  /// The segment under the pointer.
  final ({int row, int column})? touched;

  /// How far the entry animation has got, from 0 to 1.
  final double animation;

  /// Where the labels are laid out.
  final TextPainterCache textCache;

  Path _pathOf(ClockSegment s) {
    final outer = Rect.fromCircle(center: center, radius: s.outerRadius);
    final inner = Rect.fromCircle(center: center, radius: s.innerRadius);
    return Path()
      ..arcTo(outer, s.startAngle, s.sweep, true)
      ..arcTo(inner, s.startAngle + s.sweep, -s.sweep, false)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (segments.isEmpty) return;

    final t = animation.clamp(0.0, 1.0);
    for (final segment in segments) {
      final value = table.values[segment.row][segment.column];
      var color = value == null || !value.isFinite
          ? chart.scale.emptyColor
          : chart.scale.colorAt(value, minValue, maxValue);
      color = color.withValues(alpha: color.a * t);
      canvas.drawPath(
        _pathOf(segment),
        Paint()
          ..color = color
          ..isAntiAlias = true,
      );
    }

    final at = touched;
    final hover = chart.hoverBorder;
    if (at != null && hover != null && hover.width > 0) {
      for (final segment in segments) {
        if (segment.row != at.row || segment.column != at.column) continue;
        canvas.drawPath(
          _pathOf(segment),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = hover.width
            ..color = hover.color
            ..isAntiAlias = true,
        );
      }
    }

    _paintLabels(canvas);
  }

  void _paintLabels(Canvas canvas) {
    final style = seriesAxisLabelStyle.merge(chart.labelStyle);
    final outer = segments.map((s) => s.outerRadius).reduce(math.max);
    final inner = segments.map((s) => s.innerRadius).reduce(math.min);

    if (chart.showHourLabels && chart.hourLabelStep > 0) {
      for (
        var hour = 0;
        hour < table.columnCount;
        hour += chart.hourLabelStep
      ) {
        final angle =
            -math.pi / 2 + (hour + 0.5) * 2 * math.pi / table.columnCount;
        final tp = textCache.get(table.columnLabels[hour], style);
        final at = center + Offset.fromDirection(angle, outer + 9);
        tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
      }
    }

    if (chart.showWeekdayLabels) {
      // Written up the twelve o'clock line, a ring each, at the left of it.
      for (final segment in segments.where((s) => s.column == 0)) {
        final pitch = segment.outerRadius - segment.innerRadius;
        final tp = textCache.get(table.rowLabels[segment.row], style);
        if (tp.height > pitch + 2 || inner <= 0) continue;
        tp.paint(
          canvas,
          Offset(
            center.dx - 4 - tp.width,
            center.dy - segment.midRadius - tp.height / 2,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(ActivityClockChartPainter oldDelegate) =>
      !identical(oldDelegate.chart, chart) ||
      !identical(oldDelegate.segments, segments) ||
      !identical(oldDelegate.table, table) ||
      oldDelegate.center != center ||
      oldDelegate.minValue != minValue ||
      oldDelegate.maxValue != maxValue ||
      oldDelegate.touched != touched ||
      oldDelegate.animation != animation;
}
