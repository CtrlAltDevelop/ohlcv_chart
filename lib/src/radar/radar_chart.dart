import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';
import '../series/series_axis.dart';
import '../series/series_data.dart';

/// The colour a radar series falls back on.
const Color radarDefaultColor = Color(0xFF4C86CD);

/// The colour of the web behind the series.
const Color radarGridColor = Color(0x33909196);

/// Which shape the web is drawn in.
enum RadarShape {
  /// Straight edges from feature to feature — the usual spider web.
  polygon,

  /// Rings.
  circle,
}

/// One outline on a [RadarChart]: a value for every feature, in order.
@immutable
class RadarSeries {
  /// Creates an outline through [values].
  const RadarSeries({
    required this.values,
    this.label,
    this.color,
    this.fillColor,
    this.width = 2,
    this.dashPattern,
    this.dot,
    this.showInTooltip = true,
  });

  /// One value per feature; a value beyond the chart's range is clamped, and
  /// a null one breaks the outline at that feature.
  final List<double?> values;

  /// What the series is called, for a legend or a tooltip.
  final String? label;

  /// Outline colour; null uses [radarDefaultColor].
  final Color? color;

  /// The fill inside the outline; null fills it with a faint [color].
  final Color? fillColor;

  /// Outline width; 0 draws no outline.
  final double width;

  /// Alternating dash and gap lengths; null draws solid.
  final List<double>? dashPattern;

  /// A dot on every corner; null draws none.
  final SeriesDot? dot;

  /// Whether a touch on this series reports it.
  final bool showInTooltip;

  /// The colour the outline is drawn in.
  Color get strokeColor => color ?? radarDefaultColor;
}

/// What a touch on a [RadarChart] landed on.
@immutable
class RadarTouchDetails {
  /// Creates the details of a touch on the corner [featureIndex] of
  /// [seriesIndex].
  const RadarTouchDetails({
    required this.seriesIndex,
    required this.featureIndex,
    required this.value,
    required this.position,
  });

  /// Which of `RadarChart.series` was touched.
  final int seriesIndex;

  /// Which feature's corner it was.
  final int featureIndex;

  /// The value at that corner.
  final double value;

  /// Where the corner is, in the chart's local pixels.
  final Offset position;
}

/// The corner of a radar web: [count] features spread evenly round a circle,
/// the first one at twelve o'clock unless [startAngle] says otherwise.
Offset radarCorner({
  required Offset centre,
  required double radius,
  required int count,
  required int index,
  double startAngle = -math.pi / 2,
}) {
  if (count <= 0) return centre;
  final angle = startAngle + index * math.pi * 2 / count;
  return centre + Offset(math.cos(angle), math.sin(angle)) * radius;
}

/// A web of features with one outline per series — a radar, or spider, chart.
///
/// ```dart
/// RadarChart(
///   features: const ['Speed', 'Power', 'Range', 'Cost', 'Weight'],
///   series: [
///     RadarSeries(values: const [4, 3, 5, 2, 4], color: blue),
///     RadarSeries(values: const [3, 5, 2, 4, 3], color: amber),
///   ],
///   maxValue: 5,
/// );
/// ```
///
/// The chart fills the box it is given, and is [defaultSize] square in a box
/// that sets no size of its own.
class RadarChart extends StatefulWidget {
  /// Creates a radar of [series] over [features].
  const RadarChart({
    super.key,
    required this.series,
    this.features = const [],
    this.minValue = 0,
    this.maxValue,
    this.tickCount = 4,
    this.shape = RadarShape.polygon,
    this.startDegreeOffset = 0,
    this.gridColor = radarGridColor,
    this.gridWidth = 1,
    this.spokeColor,
    this.spokeWidth = 1,
    this.tickStyle,
    this.showTicks = false,
    this.featureStyle,
    this.featureGap = 8,
    this.radius,
    this.onTouch,
    this.touchThreshold = 24,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.defaultSize = 220,
    this.semanticLabel,
  });

  /// The outlines, bottom one first.
  final List<RadarSeries> series;

  /// What each corner is called, in the order the values are given; an empty
  /// list leaves the corners unnamed.
  final List<String> features;

  /// The value at the middle of the web.
  final double minValue;

  /// The value at its outer edge; null takes the largest value given.
  final double? maxValue;

  /// How many rings the web is drawn with.
  final int tickCount;

  /// Whether the rings are straight-edged or round.
  final RadarShape shape;

  /// Where the first feature sits, in degrees clockwise from twelve o'clock.
  final double startDegreeOffset;

  /// Colour of the rings.
  final Color gridColor;

  /// Width of the rings; 0 draws none.
  final double gridWidth;

  /// Colour of the spokes out to each feature; null follows [gridColor].
  final Color? spokeColor;

  /// Width of the spokes; 0 draws none.
  final double spokeWidth;

  /// Style of the ring values, when [showTicks] is on.
  final TextStyle? tickStyle;

  /// Whether each ring is labelled with the value it stands for.
  final bool showTicks;

  /// Style of the feature names.
  final TextStyle? featureStyle;

  /// Space between the outer ring and the feature names.
  final double featureGap;

  /// How far the web reaches; null fits the box, leaving room for the names.
  final double? radius;

  /// Called when a corner is touched, and with null when the touch leaves.
  final ValueChanged<RadarTouchDetails?>? onTouch;

  /// How close a touch has to be to a corner to pick it, in logical pixels.
  final double touchThreshold;

  /// How long the outlines take to grow out of the middle; zero draws them at
  /// once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build grows in.
  final bool animateOnMount;

  /// Space kept clear around the web.
  final EdgeInsets padding;

  /// Painted behind the whole chart.
  final Color? backgroundColor;

  /// The size taken in a box that sets none.
  final double defaultSize;

  /// What a screen reader announces for the chart.
  final String? semanticLabel;

  @override
  State<RadarChart> createState() => _RadarChartState();
}

class _RadarChartState extends State<RadarChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 64);

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
  void didUpdateWidget(RadarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  /// How many corners the web has: as many as the longest series, or as many
  /// as there are names when there are more of those.
  int get _featureCount {
    var count = widget.features.length;
    for (final s in widget.series) {
      count = math.max(count, s.values.length);
    }
    return count;
  }

  double get _maxValue {
    final given = widget.maxValue;
    if (given != null) return given;
    var high = widget.minValue;
    for (final s in widget.series) {
      for (final v in s.values) {
        if (v != null && v.isFinite) high = math.max(high, v);
      }
    }
    return high > widget.minValue ? high : widget.minValue + 1;
  }

  void _handle(Offset local, RadarLayout layout) {
    final onTouch = widget.onTouch;
    if (onTouch == null) return;
    RadarTouchDetails? best;
    var bestDistance = widget.touchThreshold * widget.touchThreshold;
    for (var i = 0; i < widget.series.length; i++) {
      final s = widget.series[i];
      if (!s.showInTooltip) continue;
      for (var j = 0; j < s.values.length; j++) {
        final value = s.values[j];
        if (value == null || !value.isFinite) continue;
        final at = layout.cornerFor(j, value);
        final distance = (at - local).distanceSquared;
        if (distance <= bestDistance) {
          bestDistance = distance;
          best = RadarTouchDetails(
            seriesIndex: i,
            featureIndex: j,
            value: value,
            position: at,
          );
        }
      }
    }
    onTouch(best);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.animationCurve.transform(_animation.value);

    Widget chart = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : widget.defaultSize;
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : widget.defaultSize;
        final box = widget.padding.deflateRect(
          Offset.zero & Size(width, height),
        );
        // The names are written outside the web, so it gives up the room they
        // need unless a radius was asked for.
        final names = widget.features.isEmpty
            ? 0.0
            : _text
                    .get(
                      widget.features.reduce(
                        (a, b) => a.length >= b.length ? a : b,
                      ),
                      seriesAxisLabelStyle.merge(widget.featureStyle),
                    )
                    .width /
                2;
        final radius = math.max(
          0.0,
          widget.radius ??
              box.shortestSide / 2 - widget.featureGap - names.clamp(0.0, 60.0),
        );
        final layout = RadarLayout(
          centre: box.center,
          radius: radius,
          count: _featureCount,
          minValue: widget.minValue,
          maxValue: _maxValue,
          startAngle: (widget.startDegreeOffset - 90) * math.pi / 180,
        );

        return SizedBox(
          width: width,
          height: height,
          child: MouseRegion(
            onHover: (e) => _handle(e.localPosition, layout),
            onExit: (_) => widget.onTouch?.call(null),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _handle(d.localPosition, layout),
              onTapUp: (_) => widget.onTouch?.call(null),
              onTapCancel: () => widget.onTouch?.call(null),
              child: CustomPaint(
                painter: RadarChartPainter(
                  chart: widget,
                  layout: layout,
                  animation: t,
                  textCache: _text,
                ),
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

/// Where a radar web sits and how its values turn into pixels.
@immutable
class RadarLayout {
  /// Creates the layout of a web of [count] features.
  const RadarLayout({
    required this.centre,
    required this.radius,
    required this.count,
    required this.minValue,
    required this.maxValue,
    required this.startAngle,
  });

  /// The middle of the web.
  final Offset centre;

  /// How far the outer ring reaches.
  final double radius;

  /// How many corners it has.
  final int count;

  /// The value at the middle.
  final double minValue;

  /// The value at the outer ring.
  final double maxValue;

  /// Where the first feature sits, in radians from three o'clock.
  final double startAngle;

  /// How far out [value] sits, from nothing at the middle to [radius].
  double radiusFor(double value) {
    final span = maxValue - minValue;
    if (span <= 0) return 0;
    return ((value - minValue) / span).clamp(0.0, 1.0) * radius;
  }

  /// The corner of feature [index] at [value].
  Offset cornerFor(int index, double value) => radarCorner(
        centre: centre,
        radius: radiusFor(value),
        count: count,
        index: index,
        startAngle: startAngle,
      );

  /// The corner of feature [index] on the ring at [t] of the way out.
  Offset ringCorner(int index, double t) => radarCorner(
        centre: centre,
        radius: radius * t,
        count: count,
        index: index,
        startAngle: startAngle,
      );
}

/// Paints a [RadarChart]: the web, the feature names and the outlines.
class RadarChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [layout] says.
  RadarChartPainter({
    required this.chart,
    required this.layout,
    required this.animation,
    required this.textCache,
  });

  final RadarChart chart;
  final RadarLayout layout;
  final double animation;
  final TextPainterCache textCache;

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (layout.radius <= 0 || layout.count < 3) return;

    _paintWeb(canvas);
    _paintFeatures(canvas, size);
    for (final series in chart.series) {
      _paintSeries(canvas, series);
    }
  }

  void _paintWeb(Canvas canvas) {
    if (chart.gridWidth > 0 && chart.tickCount > 0) {
      final paint = _stroke(chart.gridColor, chart.gridWidth);
      for (var ring = 1; ring <= chart.tickCount; ring++) {
        final t = ring / chart.tickCount;
        if (chart.shape == RadarShape.circle) {
          canvas.drawCircle(layout.centre, layout.radius * t, paint);
          continue;
        }
        final path = Path();
        for (var i = 0; i < layout.count; i++) {
          final at = layout.ringCorner(i, t);
          if (i == 0) {
            path.moveTo(at.dx, at.dy);
          } else {
            path.lineTo(at.dx, at.dy);
          }
        }
        canvas.drawPath(path..close(), paint);
      }
    }

    if (chart.spokeWidth > 0) {
      final paint = _stroke(
        chart.spokeColor ?? chart.gridColor,
        chart.spokeWidth,
      );
      for (var i = 0; i < layout.count; i++) {
        canvas.drawLine(layout.centre, layout.ringCorner(i, 1), paint);
      }
    }

    if (!chart.showTicks || chart.tickCount <= 0) return;
    final style = seriesAxisLabelStyle.merge(chart.tickStyle);
    for (var ring = 1; ring <= chart.tickCount; ring++) {
      final t = ring / chart.tickCount;
      final value = chart.minValue + (layout.maxValue - chart.minValue) * t;
      final tp = textCache.get(_number(value), style);
      // Written up the first spoke, where the outlines cross it least.
      final at = layout.ringCorner(0, t);
      tp.paint(canvas, at + const Offset(4, -2));
    }
  }

  void _paintFeatures(Canvas canvas, Size size) {
    if (chart.features.isEmpty) return;
    final style = seriesAxisLabelStyle.merge(chart.featureStyle);
    for (var i = 0; i < chart.features.length && i < layout.count; i++) {
      final name = chart.features[i];
      if (name.isEmpty) continue;
      final tp = textCache.get(name, style);
      final corner = layout.ringCorner(i, 1);
      final direction = corner - layout.centre;
      final distance = direction.distance;
      final out =
          distance == 0 ? Offset.zero : direction / distance * chart.featureGap;
      // Pushed clear of the web by half the label, so a name on the left ends
      // where the web starts rather than lying over it.
      final at = corner +
          out +
          Offset(
            (direction.dx / (distance == 0 ? 1 : distance)) * tp.width / 2,
            (direction.dy / (distance == 0 ? 1 : distance)) * tp.height / 2,
          );
      tp.paint(
        canvas,
        Offset(
          (at.dx - tp.width / 2).clamp(
            0.0,
            math.max(0.0, size.width - tp.width),
          ),
          (at.dy - tp.height / 2).clamp(
            0.0,
            math.max(0.0, size.height - tp.height),
          ),
        ),
      );
    }
  }

  void _paintSeries(Canvas canvas, RadarSeries series) {
    final corners = <Offset>[];
    for (var i = 0; i < series.values.length && i < layout.count; i++) {
      final value = series.values[i];
      if (value == null || !value.isFinite) continue;
      final grown =
          chart.minValue + (value - chart.minValue) * animation.clamp(0.0, 1.0);
      corners.add(layout.cornerFor(i, grown));
    }
    if (corners.length < 2) {
      for (final at in corners) {
        final dot = series.dot;
        if (dot != null) _paintDot(canvas, at, dot, series.strokeColor);
      }
      return;
    }

    final path = Path()..moveTo(corners.first.dx, corners.first.dy);
    for (final at in corners.skip(1)) {
      path.lineTo(at.dx, at.dy);
    }
    path.close();

    final fill = series.fillColor ?? series.strokeColor.withValues(alpha: 0.2);
    canvas.drawPath(path, Paint()..color = fill);
    if (series.width > 0) {
      canvas.drawPath(
        _dashed(path, series.dashPattern),
        _stroke(series.strokeColor, series.width),
      );
    }
    final dot = series.dot;
    if (dot != null) {
      for (final at in corners) {
        _paintDot(canvas, at, dot, series.strokeColor);
      }
    }
  }

  void _paintDot(Canvas canvas, Offset at, SeriesDot dot, Color fallback) {
    if (dot.radius <= 0) return;
    canvas.drawCircle(
      at,
      dot.radius,
      Paint()
        ..color = dot.color ?? fallback
        ..isAntiAlias = true,
    );
    final ring = dot.strokeColor;
    if (ring != null && dot.strokeWidth > 0) {
      canvas.drawCircle(
        at,
        dot.radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = dot.strokeWidth
          ..color = ring
          ..isAntiAlias = true,
      );
    }
  }

  static Path _dashed(Path source, List<double>? pattern) {
    if (pattern == null || pattern.isEmpty || !pattern.any((v) => v > 0)) {
      return source;
    }
    final dashed = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var index = 0;
      while (distance < metric.length) {
        final length = math.max(0.0, pattern[index % pattern.length]);
        if (index.isEven && length > 0) {
          dashed.addPath(
            metric.extractPath(
              distance,
              math.min(distance + length, metric.length),
            ),
            Offset.zero,
          );
        }
        distance += length;
        index++;
      }
    }
    return dashed;
  }

  static Paint _stroke(Color color, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..color = color
    ..strokeWidth = width
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  static String _number(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  @override
  bool shouldRepaint(RadarChartPainter oldDelegate) => true;
}
