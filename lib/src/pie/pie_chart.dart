import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';

/// The default colour of a section that names none.
const Color pieDefaultColor = Color(0xFF4C86CD);

/// Where a section's label sits, as a share of the way out from the middle of
/// the ring to its outer edge.
const double pieDefaultLabelPosition = 0.5;

/// One wedge of a [PieChart].
///
/// [value] is a share, not an angle: the sections are added up and each one
/// gets the part of the circle its value is worth.
@immutable
class PieSection {
  /// Creates a section worth [value].
  const PieSection({
    required this.value,
    this.color,
    this.gradient,
    this.label,
    this.labelStyle,
    this.labelPosition = pieDefaultLabelPosition,
    this.radius,
    this.border,
    this.offset = 0,
    this.badge,
    this.badgePosition = 1,
  });

  /// The section's share of the circle. Zero or less draws nothing.
  final double value;

  /// Fill colour; null uses [pieDefaultColor].
  final Color? color;

  /// Fill gradient, measured over the section; it wins over [color].
  final Gradient? gradient;

  /// Written on the section; null or empty writes nothing.
  final String? label;

  /// Style of [label].
  final TextStyle? labelStyle;

  /// How far out the label sits: 0 at the inner edge, 1 at the outer one.
  final double labelPosition;

  /// How far this section reaches out from the middle; null uses the chart's
  /// own radius, so one section can stand out by asking for more.
  final double? radius;

  /// An outline round the section.
  final BorderSide? border;

  /// How far the section is pushed out of the circle, in logical pixels — the
  /// exploded slice of a pie.
  final double offset;

  /// A widget pinned to the section, such as an icon or a chip.
  final Widget? badge;

  /// How far out [badge] is pinned, the way [labelPosition] measures.
  final double badgePosition;
}

/// One section as it was laid out: which part of the circle it covers.
@immutable
class PieSlice {
  /// Creates a laid-out section.
  const PieSlice({
    required this.index,
    required this.startAngle,
    required this.sweepAngle,
    required this.innerRadius,
    required this.outerRadius,
  });

  /// Which of `PieChart.sections` this is.
  final int index;

  /// Where the section starts, in radians clockwise from three o'clock.
  final double startAngle;

  /// How much of the circle it covers, in radians.
  final double sweepAngle;

  /// The radius its inner edge sits at.
  final double innerRadius;

  /// The radius its outer edge reaches.
  final double outerRadius;

  /// The angle halfway through the section.
  double get centreAngle => startAngle + sweepAngle / 2;

  /// The direction the section points in.
  Offset get direction => Offset(math.cos(centreAngle), math.sin(centreAngle));

  /// The point [t] of the way out from the inner edge to the outer one.
  Offset pointAt(Offset centre, double t) =>
      centre + direction * (innerRadius + (outerRadius - innerRadius) * t);
}

/// Lays [sections] out round a circle.
///
/// Each section gets the share of `2π` its value is worth, starting at
/// [startAngle] and going round clockwise — or the other way with [clockwise]
/// off. [space] is taken off every section, so the wedges stand apart.
///
/// Sections worth nothing are left out; a set of sections worth nothing at
/// all lays out as nothing.
List<PieSlice> layOutPie({
  required List<PieSection> sections,
  required double radius,
  required double innerRadius,
  double startAngle = -math.pi / 2,
  double space = 0,
  bool clockwise = true,
  double animation = 1,
}) {
  var total = 0.0;
  for (final section in sections) {
    if (section.value.isFinite && section.value > 0) total += section.value;
  }
  if (total <= 0) return const [];

  final gap = radius > 0 ? space / radius : 0.0;
  final slices = <PieSlice>[];
  var covered = 0.0;
  for (var i = 0; i < sections.length; i++) {
    final section = sections[i];
    if (!section.value.isFinite || section.value <= 0) continue;
    final full = section.value / total * math.pi * 2;
    final sweep = math.max(0.0, full - gap) * animation.clamp(0.0, 1.0);
    // Going the other way, a section ends where a clockwise one would have
    // started, so it is laid out backwards from there.
    final from = clockwise ? startAngle + covered : startAngle - covered - full;
    slices.add(
      PieSlice(
        index: i,
        startAngle: from + gap / 2,
        sweepAngle: sweep,
        innerRadius: innerRadius,
        outerRadius: section.radius ?? radius,
      ),
    );
    covered += full;
  }
  return slices;
}

/// Which section [local] is inside, or null for the hole or the space around
/// the circle.
int? pieSectionAt({
  required Offset local,
  required Offset centre,
  required List<PieSlice> slices,
}) {
  final delta = local - centre;
  final distance = delta.distance;
  var angle = math.atan2(delta.dy, delta.dx);
  for (final slice in slices) {
    if (distance < slice.innerRadius || distance > slice.outerRadius) continue;
    // Both ends are brought into one turn of the circle so a section that
    // crosses three o'clock still matches.
    var from = slice.startAngle;
    while (angle < from) {
      angle += math.pi * 2;
    }
    while (angle > from + math.pi * 2) {
      from += math.pi * 2;
    }
    if (angle <= from + slice.sweepAngle) return slice.index;
  }
  return null;
}

/// What a touch on a [PieChart] landed on.
@immutable
class PieTouchDetails {
  /// Creates the details of a touch on [index].
  const PieTouchDetails({
    required this.index,
    required this.section,
    required this.localPosition,
  });

  /// Which of `PieChart.sections` was touched, or -1 for none of them.
  final int index;

  /// The section touched; null when the touch missed them all.
  final PieSection? section;

  /// Where the touch was, in the chart's local pixels.
  final Offset localPosition;
}

/// A ring of sections, each as wide as its share of the whole — a pie chart,
/// or a doughnut when the middle is left open.
///
/// ```dart
/// PieChart(
///   sections: [
///     PieSection(value: 40, color: blue, label: '40%'),
///     PieSection(value: 35, color: green, label: '35%'),
///     PieSection(value: 25, color: amber, label: '25%'),
///   ],
///   centerSpaceRadius: 40,
///   centerChild: Text('Total'),
/// );
/// ```
///
/// The chart fills the box it is given, and is [defaultSize] square in a box
/// that sets no size of its own.
class PieChart extends StatefulWidget {
  /// Creates a pie of [sections].
  const PieChart({
    super.key,
    required this.sections,
    this.radius,
    this.centerSpaceRadius = 0,
    this.centerSpaceColor,
    this.centerChild,
    this.sectionsSpace = 0,
    this.startDegreeOffset = 0,
    this.clockwise = true,
    this.touchedSectionGrowth = 8,
    this.onTouch,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.defaultSize = 200,
    this.semanticLabel,
  });

  /// The wedges, going round from [startDegreeOffset].
  final List<PieSection> sections;

  /// How far the sections reach; null fills the box.
  final double? radius;

  /// The hole in the middle; 0 draws a full pie.
  final double centerSpaceRadius;

  /// Painted in the hole; null leaves it clear.
  final Color? centerSpaceColor;

  /// A widget centred in the hole — a total, a title, a button.
  final Widget? centerChild;

  /// The gap between two sections, in logical pixels round the outer edge.
  final double sectionsSpace;

  /// Where the first section starts, in degrees clockwise from twelve
  /// o'clock.
  final double startDegreeOffset;

  /// Whether the sections go round clockwise.
  final bool clockwise;

  /// How much further the section under the finger reaches; 0 leaves it be.
  final double touchedSectionGrowth;

  /// Called as a touch moves over the sections, and with null when it leaves.
  final ValueChanged<PieTouchDetails?>? onTouch;

  /// How long the sections take to sweep in; zero draws them at once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build sweeps in.
  final bool animateOnMount;

  /// Space kept clear around the circle.
  final EdgeInsets padding;

  /// Painted behind the whole chart.
  final Color? backgroundColor;

  /// The size taken in a box that sets none.
  final double defaultSize;

  /// What a screen reader announces for the chart.
  final String? semanticLabel;

  @override
  State<PieChart> createState() => _PieChartState();
}

class _PieChartState extends State<PieChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 64);
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
  void didUpdateWidget(PieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (oldWidget.sections.length != widget.sections.length &&
        widget.animationDuration > Duration.zero) {
      _animation.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _animation.dispose();
    super.dispose();
  }

  void _handle(Offset local, Offset centre, List<PieSlice> slices) {
    final index = pieSectionAt(local: local, centre: centre, slices: slices);
    if (index == _touched) return;
    setState(() => _touched = index);
    widget.onTouch?.call(
      index == null
          ? null
          : PieTouchDetails(
              index: index,
              section: widget.sections[index],
              localPosition: local,
            ),
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

    Widget chart = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : widget.defaultSize;
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : widget.defaultSize;
        final size = Size(width, height);
        final box = widget.padding.deflateRect(Offset.zero & size);
        final centre = box.center;
        final room = math.max(0.0, box.shortestSide / 2);
        final radius = math.max(
          0.0,
          (widget.radius ?? room) - widget.touchedSectionGrowth,
        );
        final inner = widget.centerSpaceRadius.clamp(0.0, radius);
        final slices = layOutPie(
          sections: widget.sections,
          radius: radius,
          innerRadius: inner.toDouble(),
          startAngle: (widget.startDegreeOffset - 90) * math.pi / 180,
          space: widget.sectionsSpace,
          clockwise: widget.clockwise,
          animation: t,
        );

        return SizedBox(
          width: width,
          height: height,
          child: MouseRegion(
            onHover: (e) => _handle(e.localPosition, centre, slices),
            onExit: (_) => _leave(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _handle(d.localPosition, centre, slices),
              onTapUp: (_) => _leave(),
              onTapCancel: _leave,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: PieChartPainter(
                        sections: widget.sections,
                        slices: slices,
                        centre: centre,
                        touched: _touched,
                        touchedGrowth: widget.touchedSectionGrowth,
                        centerSpaceColor: widget.centerSpaceColor,
                        centerSpaceRadius: inner.toDouble(),
                        backgroundColor: widget.backgroundColor,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (widget.centerChild != null)
                    Positioned(
                      left: centre.dx - inner,
                      top: centre.dy - inner,
                      width: inner * 2,
                      height: inner * 2,
                      child: Center(child: widget.centerChild),
                    ),
                  for (final slice in slices)
                    if (widget.sections[slice.index].badge != null)
                      _badge(slice, centre),
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

  Widget _badge(PieSlice slice, Offset centre) {
    final section = widget.sections[slice.index];
    final at =
        slice.pointAt(centre, section.badgePosition) +
        slice.direction * section.offset;
    return Positioned(
      left: at.dx,
      top: at.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: section.badge,
      ),
    );
  }
}

/// Paints a [PieChart]'s sections and their labels.
class PieChartPainter extends CustomPainter {
  /// Creates the painter for [slices], which lay [sections] out.
  PieChartPainter({
    required this.sections,
    required this.slices,
    required this.centre,
    required this.touched,
    required this.touchedGrowth,
    required this.centerSpaceColor,
    required this.centerSpaceRadius,
    required this.backgroundColor,
    required this.textCache,
  });

  final List<PieSection> sections;
  final List<PieSlice> slices;
  final Offset centre;
  final int? touched;
  final double touchedGrowth;
  final Color? centerSpaceColor;
  final double centerSpaceRadius;
  final Color? backgroundColor;
  final TextPainterCache textCache;

  static const TextStyle _labelStyle = TextStyle(
    fontSize: 12,
    color: Color(0xFFFFFFFF),
    fontWeight: FontWeight.w600,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final background = backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }

    final hole = centerSpaceColor;
    if (hole != null && centerSpaceRadius > 0) {
      canvas.drawCircle(centre, centerSpaceRadius, Paint()..color = hole);
    }

    for (final slice in slices) {
      final section = sections[slice.index];
      final grown = slice.index == touched ? touchedGrowth : 0.0;
      final outer = slice.outerRadius + grown;
      if (outer <= 0 || slice.sweepAngle <= 0) continue;
      final shift = slice.direction * section.offset;
      final path = _sectionPath(slice, outer, shift);

      final gradient = section.gradient;
      final paint = Paint()..isAntiAlias = true;
      if (gradient != null) {
        paint.shader = gradient.createShader(path.getBounds());
      } else {
        paint.color = section.color ?? pieDefaultColor;
      }
      canvas.drawPath(path, paint);

      final border = section.border;
      if (border != null &&
          border.style != BorderStyle.none &&
          border.width > 0) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = border.width
            ..color = border.color
            ..isAntiAlias = true,
        );
      }

      final label = section.label;
      if (label == null || label.isEmpty) continue;
      final tp = textCache.get(label, _labelStyle.merge(section.labelStyle));
      final at =
          centre +
          shift +
          slice.direction *
              (slice.innerRadius +
                  (outer - slice.innerRadius) * section.labelPosition);
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }
  }

  /// The wedge of one section: the outer arc, the inner arc back, closed.
  Path _sectionPath(PieSlice slice, double outer, Offset shift) {
    final inner = slice.innerRadius;
    final path = Path();
    final outerRect = Rect.fromCircle(center: centre + shift, radius: outer);
    if (inner <= 0) {
      path
        ..moveTo(centre.dx + shift.dx, centre.dy + shift.dy)
        ..arcTo(outerRect, slice.startAngle, slice.sweepAngle, false)
        ..close();
      return path;
    }
    final innerRect = Rect.fromCircle(center: centre + shift, radius: inner);
    path
      ..arcTo(outerRect, slice.startAngle, slice.sweepAngle, true)
      ..arcTo(
        innerRect,
        slice.startAngle + slice.sweepAngle,
        -slice.sweepAngle,
        false,
      )
      ..close();
    return path;
  }

  @override
  bool shouldRepaint(PieChartPainter oldDelegate) => true;
}
