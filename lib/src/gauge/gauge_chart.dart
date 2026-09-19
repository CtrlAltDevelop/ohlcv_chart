import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';
import '../series/series_axis.dart';

/// A coloured stretch of a [GaugeChart]'s track — a safe zone, a warning zone.
@immutable
class GaugeRange {
  /// Creates a range from [from] to [to], painted in [color].
  const GaugeRange({
    required this.from,
    required this.to,
    required this.color,
    this.label,
  });

  /// Where the range starts, in the gauge's values.
  final double from;

  /// Where it ends.
  final double to;

  /// What it is painted in.
  final Color color;

  /// What it is called, for a legend of your own.
  final String? label;

  /// Whether [value] falls inside it.
  bool contains(double value) =>
      value >= math.min(from, to) && value <= math.max(from, to);
}

/// The pointer of a [GaugeChart].
@immutable
class GaugeNeedle {
  /// Creates a needle.
  const GaugeNeedle({
    this.color = const Color(0xFFE9ECEF),
    this.length = 0.78,
    this.width = 6,
    this.knobRadius = 7,
    this.knobColor,
  });

  /// What the needle is painted in.
  final Color color;

  /// How far it reaches, as a share of the gauge's radius.
  final double length;

  /// How wide it is at the knob.
  final double width;

  /// The circle it turns on; 0 draws none.
  final double knobRadius;

  /// What the knob is painted in; null takes [color].
  final Color? knobColor;
}

/// The marks round a [GaugeChart].
@immutable
class GaugeTicks {
  /// Creates the tick marks.
  const GaugeTicks({
    this.interval,
    this.count = 5,
    this.minorPerMajor = 4,
    this.majorLength = 8,
    this.minorLength = 4,
    this.width = 1.5,
    this.color = const Color(0x99909196),
    this.gap = 4,
    this.showLabels = true,
    this.labelStyle,
    this.formatter,
    this.labelGap = 4,
  });

  /// No marks at all.
  static const none = GaugeTicks(count: 0, minorPerMajor: 0, showLabels: false);

  /// The value between two major marks; null divides the range into [count].
  final double? interval;

  /// How many divisions the range is split into when [interval] is null.
  final int count;

  /// Minor marks between two major ones.
  final int minorPerMajor;

  /// How long a major mark is.
  final double majorLength;

  /// How long a minor mark is.
  final double minorLength;

  /// How thick the marks are.
  final double width;

  /// What the marks are painted in.
  final Color color;

  /// Space between the track and the marks.
  final double gap;

  /// Whether the major marks are labelled.
  final bool showLabels;

  /// Style of the labels.
  final TextStyle? labelStyle;

  /// Writes a label from its value; null writes it as a whole number, or with
  /// as few decimals as it needs.
  final String Function(double value)? formatter;

  /// Space between the marks and their labels.
  final double labelGap;

  /// The values of the major marks between [min] and [max].
  List<double> majorValues(double min, double max) {
    if (!(max > min)) return const [];
    final step = interval;
    if (step != null) {
      if (!(step > 0)) return const [];
      final count = ((max - min) / step + 1e-9).floor();
      return [for (var i = 0; i <= count; i++) min + i * step];
    }
    if (count <= 0) return const [];
    final size = (max - min) / count;
    return [for (var i = 0; i <= count; i++) min + i * size];
  }

  /// The label for [value].
  String labelFor(double value) {
    final format = formatter;
    if (format != null) return format(value);
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }
}

/// Where a gauge's arc sits and which value is where on it.
@immutable
class GaugeLayout {
  /// Creates the layout of an arc round [center].
  ///
  /// [startAngle] and [sweepAngle] are in degrees, measured clockwise from
  /// twelve o'clock.
  const GaugeLayout({
    required this.center,
    required this.radius,
    required this.min,
    required this.max,
    this.startAngle = -135,
    this.sweepAngle = 270,
  });

  /// Fits the largest arc of [startAngle] and [sweepAngle] into [box].
  ///
  /// A half-circle gauge takes a box twice as wide as it is tall, so the arc is
  /// measured rather than assumed to be a whole circle.
  factory GaugeLayout.fit(
    Rect box, {
    required double min,
    required double max,
    double startAngle = -135,
    double sweepAngle = 270,
  }) {
    final extent = arcExtent(startAngle, sweepAngle);
    final radius = box.width <= 0 || box.height <= 0
        ? 0.0
        : math.min(box.width / extent.width, box.height / extent.height);
    // Place the unit extent's centre on the box's centre.
    final center =
        box.center -
        Offset(extent.center.dx * radius, extent.center.dy * radius);
    return GaugeLayout(
      center: center,
      radius: radius,
      min: min,
      max: max,
      startAngle: startAngle,
      sweepAngle: sweepAngle,
    );
  }

  /// The centre the arc turns on.
  final Offset center;

  /// The outer radius of the arc.
  final double radius;

  /// The value at the start of the arc.
  final double min;

  /// The value at the end of it.
  final double max;

  /// Where the arc starts, in degrees clockwise from twelve o'clock.
  final double startAngle;

  /// How far it runs, in degrees.
  final double sweepAngle;

  /// How far along the arc [value] is, from 0 to 1, held to the arc.
  double fractionOf(double value) {
    if (!(max > min) || !value.isFinite) return 0;
    return ((value - min) / (max - min)).clamp(0.0, 1.0);
  }

  /// The canvas angle of [value], in radians clockwise from three o'clock.
  double angleOf(double value) =>
      _radians(startAngle + sweepAngle * fractionOf(value));

  /// The canvas angle the arc starts at.
  double get startRadians => _radians(startAngle);

  /// The point [distance] from the centre, in the direction of [value].
  Offset pointAt(double value, double distance) {
    final angle = angleOf(value);
    return center + Offset(math.cos(angle), math.sin(angle)) * distance;
  }

  static double _radians(double clockDegrees) =>
      (clockDegrees - 90) * math.pi / 180;

  /// The bounds of an arc of radius 1 round the origin, centre included.
  static Rect arcExtent(double startAngle, double sweepAngle) {
    var left = 0.0, top = 0.0, right = 0.0, bottom = 0.0;
    void include(double clockDegrees) {
      final a = _radians(clockDegrees);
      final x = math.cos(a), y = math.sin(a);
      left = math.min(left, x);
      right = math.max(right, x);
      top = math.min(top, y);
      bottom = math.max(bottom, y);
    }

    final sweep = sweepAngle.clamp(-360.0, 360.0);
    final end = startAngle + sweep;
    include(startAngle);
    include(end);
    // Every quarter turn the arc passes is an extreme of the circle.
    final low = math.min(startAngle, end), high = math.max(startAngle, end);
    for (var q = (low / 90).ceil() * 90.0; q <= high; q += 90) {
      include(q);
    }
    // Never thinner than a sliver, so a degenerate arc still fits somewhere.
    return Rect.fromLTRB(
      left,
      top,
      math.max(right, left + 1e-3),
      math.max(bottom, top + 1e-3),
    );
  }
}

/// A dial showing one value against a range — a gauge.
///
/// A speedometer for a KPI, a margin-level meter, a risk score, a fear and
/// greed index.
///
/// ```dart
/// GaugeChart(
///   value: 72,
///   ranges: const [
///     GaugeRange(from: 0, to: 40, color: Color(0xFF2F9E44)),
///     GaugeRange(from: 40, to: 75, color: Color(0xFFF59F00)),
///     GaugeRange(from: 75, to: 100, color: Color(0xFFE03131)),
///   ],
///   needle: const GaugeNeedle(),
///   label: 'Risk',
/// );
/// ```
///
/// The gauge fills the box it is given, keeping its shape, and is
/// [defaultSize] square in a box that sets no size of its own.
class GaugeChart extends StatefulWidget {
  /// Creates a gauge showing [value].
  const GaugeChart({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 100,
    this.startAngle = -135,
    this.sweepAngle = 270,
    this.thickness = 14,
    this.trackColor = const Color(0x22909196),
    this.ranges = const [],
    this.rangeThickness,
    this.showValueBar = true,
    this.valueColor,
    this.roundCaps = true,
    this.needle,
    this.ticks = const GaugeTicks(),
    this.showValue = true,
    this.valueFormatter,
    this.valueStyle,
    this.label,
    this.labelStyle,
    this.centerChild,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.defaultSize = 200,
    this.semanticLabel,
  });

  /// The value shown.
  final double value;

  /// The value at the start of the arc.
  final double min;

  /// The value at the end of it.
  final double max;

  /// Where the arc starts, in degrees clockwise from twelve o'clock.
  final double startAngle;

  /// How far it runs, in degrees: 270 for a dial, 180 for a half circle.
  final double sweepAngle;

  /// How thick the track is.
  final double thickness;

  /// The track under everything else.
  final Color trackColor;

  /// Coloured stretches of the track.
  final List<GaugeRange> ranges;

  /// How thick the ranges are; null takes [thickness].
  final double? rangeThickness;

  /// Whether the track fills from [min] up to the value.
  final bool showValueBar;

  /// What the value bar is painted in; null takes the colour of the range the
  /// value is in, or a blue when it is in none.
  final Color? valueColor;

  /// Whether the track and value bar have rounded ends.
  final bool roundCaps;

  /// The pointer; null draws none.
  final GaugeNeedle? needle;

  /// The marks round the arc; [GaugeTicks.none] for none.
  final GaugeTicks ticks;

  /// Whether the value is written in the middle.
  final bool showValue;

  /// Writes the value; null writes it with as few decimals as it needs.
  final String Function(double value)? valueFormatter;

  /// Style of the value.
  final TextStyle? valueStyle;

  /// Written under the value.
  final String? label;

  /// Style of [label].
  final TextStyle? labelStyle;

  /// A widget put in the middle instead of the written value and label.
  final Widget? centerChild;

  /// How long the gauge takes to move to a new value; zero moves at once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build sweeps up from [min].
  final bool animateOnMount;

  /// Space kept clear around the gauge.
  final EdgeInsets padding;

  /// Painted behind the whole chart.
  final Color? backgroundColor;

  /// The size taken in a box that sets none.
  final double defaultSize;

  /// What a screen reader announces for the chart; null announces the value.
  final String? semanticLabel;

  @override
  State<GaugeChart> createState() => _GaugeChartState();
}

class _GaugeChartState extends State<GaugeChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 64);

  /// Where the current sweep started from.
  late double _from;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
      value: 1,
    )..addListener(() => setState(() {}));
    _from = widget.value;
    if (widget.animateOnMount && widget.animationDuration > Duration.zero) {
      _from = widget.min;
      _animation.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(GaugeChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (oldWidget.value != widget.value) {
      if (widget.animationDuration > Duration.zero) {
        // Carry on from wherever the needle is now, not from where it was
        // headed, so a value changing mid-sweep does not jump.
        _from = _shown(oldWidget.value);
        _animation.forward(from: 0);
      } else {
        _from = widget.value;
      }
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _animation.dispose();
    super.dispose();
  }

  double _shown(double target) {
    final t = widget.animationCurve.transform(_animation.value);
    return _from + (target - _from) * t;
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown(widget.value);

    Widget chart = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : widget.defaultSize;
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : widget.defaultSize;
        final size = Size(width, height);
        final layout = GaugeLayout.fit(
          widget.padding.deflateRect(Offset.zero & size),
          min: widget.min,
          max: widget.max,
          startAngle: widget.startAngle,
          sweepAngle: widget.sweepAngle,
        );

        final center = widget.centerChild;
        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: GaugeChartPainter(
                    chart: widget,
                    layout: layout,
                    shownValue: shown,
                    textCache: _text,
                  ),
                ),
              ),
              if (center != null)
                Positioned(
                  left: layout.center.dx - layout.radius,
                  top: layout.center.dy - layout.radius,
                  width: layout.radius * 2,
                  height: layout.radius * 2,
                  child: Center(child: center),
                ),
            ],
          ),
        );
      },
    );

    return Semantics(
      container: true,
      label: widget.semanticLabel ?? widget.label,
      value: _format(widget, widget.value),
      child: chart,
    );
  }
}

String _format(GaugeChart chart, double value) {
  final format = chart.valueFormatter;
  if (format != null) return format(value);
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

/// Paints a [GaugeChart]: the track, ranges, value bar, ticks, needle and
/// the value in the middle.
class GaugeChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [layout].
  GaugeChartPainter({
    required this.chart,
    required this.layout,
    required this.shownValue,
    required this.textCache,
  });

  final GaugeChart chart;
  final GaugeLayout layout;

  /// The value drawn this frame, part-way through a sweep while animating.
  final double shownValue;
  final TextPainterCache textCache;

  static const Color _defaultValueColor = Color(0xFF4C86CD);

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (layout.radius <= 0) return;

    final thickness = math.min(chart.thickness, layout.radius);
    final arcRadius = layout.radius - thickness / 2;
    final arcRect = Rect.fromCircle(center: layout.center, radius: arcRadius);
    final sweep = chart.sweepAngle * math.pi / 180;

    // The track.
    canvas.drawArc(
      arcRect,
      layout.startRadians,
      sweep,
      false,
      _stroke(chart.trackColor, thickness, round: chart.roundCaps),
    );

    // The ranges, each a butt-ended arc so neighbours meet cleanly.
    final rangeThickness = math.min(
      chart.rangeThickness ?? thickness,
      layout.radius,
    );
    final rangeRect = Rect.fromCircle(
      center: layout.center,
      radius: layout.radius - rangeThickness / 2,
    );
    for (final range in chart.ranges) {
      final start = layout.angleOf(math.min(range.from, range.to));
      final end = layout.angleOf(math.max(range.from, range.to));
      if (end == start) continue;
      canvas.drawArc(
        rangeRect,
        start,
        end - start,
        false,
        _stroke(range.color, rangeThickness, round: false),
      );
    }

    // The value bar.
    if (chart.showValueBar) {
      final fraction = layout.fractionOf(shownValue);
      if (fraction > 0) {
        canvas.drawArc(
          arcRect,
          layout.startRadians,
          sweep * fraction,
          false,
          _stroke(_valueColor(), thickness, round: chart.roundCaps),
        );
      }
    }

    final tickOuter = layout.radius - thickness - chart.ticks.gap;
    _paintTicks(canvas, tickOuter);

    final needle = chart.needle;
    if (needle != null) _paintNeedle(canvas, needle);

    if (chart.centerChild == null) _paintCentreText(canvas, tickOuter);
  }

  Paint _stroke(Color color, double width, {required bool round}) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = round ? StrokeCap.round : StrokeCap.butt
    ..isAntiAlias = true;

  Color _valueColor() {
    final own = chart.valueColor;
    if (own != null) return own;
    for (final range in chart.ranges) {
      if (range.contains(shownValue)) return range.color;
    }
    return _defaultValueColor;
  }

  void _paintTicks(Canvas canvas, double outer) {
    final ticks = chart.ticks;
    final majors = ticks.majorValues(chart.min, chart.max);
    if (majors.isEmpty || outer <= 0) return;

    final paint = Paint()
      ..color = ticks.color
      ..strokeWidth = ticks.width
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    for (var i = 0; i < majors.length; i++) {
      final value = majors[i];
      canvas.drawLine(
        layout.pointAt(value, outer),
        layout.pointAt(value, math.max(0, outer - ticks.majorLength)),
        paint,
      );

      if (i < majors.length - 1 && ticks.minorPerMajor > 0) {
        final step = (majors[i + 1] - value) / (ticks.minorPerMajor + 1);
        for (var m = 1; m <= ticks.minorPerMajor; m++) {
          final minor = value + step * m;
          canvas.drawLine(
            layout.pointAt(minor, outer),
            layout.pointAt(minor, math.max(0, outer - ticks.minorLength)),
            paint,
          );
        }
      }

      if (!ticks.showLabels) continue;
      final style = seriesAxisLabelStyle.merge(ticks.labelStyle);
      final tp = textCache.get(ticks.labelFor(value), style);
      // Pushed in by half the label's diagonal so it clears the mark whichever
      // way round the dial it faces.
      final distance =
          outer -
          ticks.majorLength -
          ticks.labelGap -
          math.sqrt(tp.width * tp.width + tp.height * tp.height) / 2;
      if (distance <= 0) continue;
      final at = layout.pointAt(value, distance);
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _paintNeedle(Canvas canvas, GaugeNeedle needle) {
    final angle = layout.angleOf(shownValue);
    final direction = Offset(math.cos(angle), math.sin(angle));
    final normal = Offset(-direction.dy, direction.dx);
    final tip = layout.center + direction * (layout.radius * needle.length);
    final half = needle.width / 2;

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        layout.center.dx + normal.dx * half,
        layout.center.dy + normal.dy * half,
      )
      ..lineTo(
        layout.center.dx - direction.dx * half - normal.dx * half * 0.4,
        layout.center.dy - direction.dy * half - normal.dy * half * 0.4,
      )
      ..lineTo(
        layout.center.dx - normal.dx * half,
        layout.center.dy - normal.dy * half,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = needle.color
        ..isAntiAlias = true,
    );

    if (needle.knobRadius > 0) {
      canvas.drawCircle(
        layout.center,
        needle.knobRadius,
        Paint()
          ..color = needle.knobColor ?? needle.color
          ..isAntiAlias = true,
      );
    }
  }

  void _paintCentreText(Canvas canvas, double room) {
    final valueText = chart.showValue ? _format(chart, chart.value) : null;
    final label = chart.label;
    if (valueText == null && (label == null || label.isEmpty)) return;

    // Scaled to the dial, so a small gauge does not overflow with a big number.
    final base = (layout.radius * 0.32).clamp(12.0, 44.0);
    final valueTp = valueText == null
        ? null
        : textCache.get(
            valueText,
            TextStyle(
              fontSize: base,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFE9ECEF),
            ).merge(chart.valueStyle),
          );
    final labelTp = label == null || label.isEmpty
        ? null
        : textCache.get(
            label,
            seriesAxisLabelStyle
                .copyWith(fontSize: (base * 0.36).clamp(10.0, 16.0))
                .merge(chart.labelStyle),
          );

    final height = (valueTp?.height ?? 0) + (labelTp?.height ?? 0);
    // With a needle the text sits below the knob rather than under it.
    final below = chart.needle == null
        ? 0.0
        : chart.needle!.knobRadius + layout.radius * 0.12;
    var top = layout.center.dy - (chart.needle == null ? height / 2 : -below);

    for (final tp in [valueTp, labelTp]) {
      if (tp == null) continue;
      if (tp.width <= room * 2) {
        tp.paint(canvas, Offset(layout.center.dx - tp.width / 2, top));
      }
      top += tp.height;
    }
  }

  @override
  bool shouldRepaint(GaugeChartPainter oldDelegate) =>
      !identical(oldDelegate.chart, chart) ||
      oldDelegate.shownValue != shownValue ||
      oldDelegate.layout.center != layout.center ||
      oldDelegate.layout.radius != layout.radius;
}
