import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';
import '../series/series_axis.dart';
import '../treemap/treemap_data.dart' show treemapPalette;

/// One step of a [FunnelChart] — visitors, sign-ups, verified, deposited.
@immutable
class FunnelStage {
  /// Creates a stage worth [value].
  const FunnelStage({
    required this.value,
    this.label,
    this.color,
    this.data,
  });

  /// How many reached this stage.
  final double value;

  /// What the stage is called.
  final String? label;

  /// A colour of this stage's own.
  final Color? color;

  /// Anything the app wants back when this stage is touched.
  final Object? data;
}

/// How a [FunnelChart]'s stages join.
enum FunnelShape {
  /// Each stage narrows to the width of the next, the classic funnel.
  tapered,

  /// Each stage is a bar of its own width, centred.
  stepped,
}

/// Where one [FunnelStage] was laid out.
@immutable
class FunnelSegment {
  /// Creates the segment of [stage].
  const FunnelSegment({
    required this.stage,
    required this.index,
    required this.rect,
    required this.topWidth,
    required this.bottomWidth,
    required this.ofFirst,
    required this.ofPrevious,
  });

  /// The stage this segment draws.
  final FunnelStage stage;

  /// Its position in the funnel, from the top.
  final int index;

  /// The band the segment is drawn in: the funnel's full width, the
  /// segment's height.
  final Rect rect;

  /// How wide the segment is along its top edge.
  final double topWidth;

  /// How wide it is along its bottom edge.
  final double bottomWidth;

  /// Its value as a share of the first stage's: the overall conversion.
  final double ofFirst;

  /// Its value as a share of the stage before it: the step's conversion. The
  /// first stage is 1.
  final double ofPrevious;

  /// The segment's outline: a trapezoid centred in [rect].
  Path get path {
    final cx = rect.center.dx;
    return Path()
      ..moveTo(cx - topWidth / 2, rect.top)
      ..lineTo(cx + topWidth / 2, rect.top)
      ..lineTo(cx + bottomWidth / 2, rect.bottom)
      ..lineTo(cx - bottomWidth / 2, rect.bottom)
      ..close();
  }

  /// How wide the segment is [dy] pixels down from the top of the chart.
  double widthAt(double dy) {
    if (rect.height <= 0) return topWidth;
    final t = ((dy - rect.top) / rect.height).clamp(0.0, 1.0);
    return topWidth + (bottomWidth - topWidth) * t;
  }

  /// Whether [local] is inside the trapezoid.
  bool contains(Offset local) {
    if (local.dy < rect.top || local.dy > rect.bottom) return false;
    return (local.dx - rect.center.dx).abs() <= widthAt(local.dy) / 2;
  }
}

/// Lays [stages] out down [bounds], widest at the top.
///
/// Each stage is as wide as its value is against the largest, never narrower
/// than [minWidthFraction] of the whole width so a stage that lost almost
/// everyone is still visible. Stages share the height evenly, [gap] apart.
List<FunnelSegment> layOutFunnel(
  List<FunnelStage> stages,
  Rect bounds, {
  double gap = 0,
  double minWidthFraction = 0.08,
  FunnelShape shape = FunnelShape.tapered,
}) {
  if (stages.isEmpty || bounds.width <= 0 || bounds.height <= 0) {
    return const [];
  }

  double clean(double v) => v.isFinite && v > 0 ? v : 0;
  var largest = 0.0;
  for (final stage in stages) {
    largest = math.max(largest, clean(stage.value));
  }

  final minFraction = minWidthFraction.clamp(0.0, 1.0);
  double widthOf(int i) {
    final share = largest <= 0 ? 0.0 : clean(stages[i].value) / largest;
    return bounds.width * math.max(minFraction, share);
  }

  final spacing = math.max(0.0, gap);
  final height = math.max(
    0.0,
    (bounds.height - spacing * (stages.length - 1)) / stages.length,
  );
  final first = clean(stages.first.value);

  return [
    for (var i = 0; i < stages.length; i++)
      FunnelSegment(
        stage: stages[i],
        index: i,
        rect: Rect.fromLTWH(
          bounds.left,
          bounds.top + i * (height + spacing),
          bounds.width,
          height,
        ),
        topWidth: widthOf(i),
        bottomWidth: shape == FunnelShape.stepped || i == stages.length - 1
            ? widthOf(i)
            : widthOf(i + 1),
        ofFirst: first <= 0 ? 0 : clean(stages[i].value) / first,
        ofPrevious: i == 0
            ? 1
            : clean(stages[i - 1].value) <= 0
                ? 0
                : clean(stages[i].value) / clean(stages[i - 1].value),
      ),
  ];
}

/// The segment under [local], or null when there is none.
FunnelSegment? funnelSegmentAt(List<FunnelSegment> segments, Offset local) {
  for (final segment in segments) {
    if (segment.contains(local)) return segment;
  }
  return null;
}

/// What a touch on a [FunnelChart] landed on.
@immutable
class FunnelTouchDetails {
  /// Creates the details of a touch on [segment].
  const FunnelTouchDetails({required this.segment});

  /// The segment touched.
  final FunnelSegment segment;

  /// The stage it draws.
  FunnelStage get stage => segment.stage;
}

/// Stages narrowing from the first to the last — a funnel.
///
/// It shows where people drop out of a sequence: visitors to sign-ups to
/// verified accounts to first deposits.
///
/// ```dart
/// FunnelChart(
///   stages: const [
///     FunnelStage(value: 12000, label: 'Visited'),
///     FunnelStage(value: 4800, label: 'Signed up'),
///     FunnelStage(value: 2100, label: 'Verified'),
///     FunnelStage(value: 900, label: 'Deposited'),
///   ],
/// );
/// ```
///
/// The chart fills the box it is given, and is [defaultHeight] high in a box
/// with no height of its own.
class FunnelChart extends StatefulWidget {
  /// Creates a funnel of [stages], from the top.
  const FunnelChart({
    super.key,
    required this.stages,
    this.shape = FunnelShape.tapered,
    this.gap = 3,
    this.minWidthFraction = 0.08,
    this.palette = treemapPalette,
    this.labelBuilder,
    this.valueFormatter,
    this.labelStyle,
    this.sideLabelStyle,
    this.hoverBorder = const BorderSide(color: Color(0xCCFFFFFF), width: 1.5),
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

  /// The stages, from the top.
  final List<FunnelStage> stages;

  /// Whether stages taper into each other or stand as separate bars.
  final FunnelShape shape;

  /// The gap left between two stages.
  final double gap;

  /// The narrowest a stage is drawn, as a share of the chart's width.
  final double minWidthFraction;

  /// Colours taken in turn by stages that name none.
  final List<Color> palette;

  /// Writes a stage's label; null writes its name, value and share of the
  /// first stage.
  final String? Function(FunnelSegment segment)? labelBuilder;

  /// Writes a value in the default label; null groups thousands.
  final String Function(double value)? valueFormatter;

  /// Style of a label inside its stage; null picks black or white by how dark
  /// the stage is.
  final TextStyle? labelStyle;

  /// Style of a label moved beside a stage too narrow to hold it.
  final TextStyle? sideLabelStyle;

  /// Drawn round the stage under the pointer; null marks none.
  final BorderSide? hoverBorder;

  /// Called as a touch moves over the stages, and with null when it leaves.
  final ValueChanged<FunnelTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched stage; null shows none.
  final Widget? Function(BuildContext context, FunnelTouchDetails details)?
      tooltipBuilder;

  /// How far the card sits from the stage.
  final double tooltipMargin;

  /// How long the stages take to widen into place; zero draws them at once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build widens in.
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
  State<FunnelChart> createState() => _FunnelChartState();
}

class _FunnelChartState extends State<FunnelChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 64);
  List<FunnelSegment> _segments = const [];
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
  void didUpdateWidget(FunnelChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!identical(oldWidget.stages, widget.stages)) {
      if (_touched != null && _touched! >= widget.stages.length) {
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
    final index = funnelSegmentAt(_segments, local)?.index;
    if (index == _touched) return;
    setState(() => _touched = index);
    widget.onTouch?.call(
      index == null ? null : FunnelTouchDetails(segment: _segments[index]),
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
            : MediaQuery.maybeSizeOf(context)?.width ?? 300;
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : widget.defaultHeight;
        final size = Size(width, height);
        _segments = layOutFunnel(
          widget.stages,
          widget.padding.deflateRect(Offset.zero & size),
          gap: widget.gap,
          minWidthFraction: widget.minWidthFraction,
          shape: widget.shape,
        );

        final touched = _touched;
        final details = touched == null || touched >= _segments.length
            ? null
            : FunnelTouchDetails(segment: _segments[touched]);
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
                      painter: FunnelChartPainter(
                        chart: widget,
                        segments: _segments,
                        touched: details?.segment.index,
                        animation: t,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (tooltip != null && details != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomSingleChildLayout(
                          delegate: _FunnelTooltipLayout(
                            anchor: Rect.fromCenter(
                              center: details.segment.rect.center,
                              width: details.segment.topWidth,
                              height: details.segment.rect.height,
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

/// Puts the tooltip to the right of the touched stage, or to its left when
/// there is no room, kept inside the chart.
class _FunnelTooltipLayout extends SingleChildLayoutDelegate {
  _FunnelTooltipLayout({required this.anchor, required this.margin});

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
  bool shouldRelayout(_FunnelTooltipLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.margin != margin;
}

/// Paints a [FunnelChart]: the stages and their labels.
class FunnelChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [segments].
  FunnelChartPainter({
    required this.chart,
    required this.segments,
    required this.touched,
    required this.animation,
    required this.textCache,
  });

  final FunnelChart chart;
  final List<FunnelSegment> segments;
  final int? touched;
  final double animation;
  final TextPainterCache textCache;

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (segments.isEmpty) return;

    final t = animation.clamp(0.0, 1.0);
    final fill = Paint()..isAntiAlias = true;

    for (final segment in segments) {
      final shown = t >= 1
          ? segment
          : FunnelSegment(
              stage: segment.stage,
              index: segment.index,
              rect: segment.rect,
              topWidth: segment.topWidth * t,
              bottomWidth: segment.bottomWidth * t,
              ofFirst: segment.ofFirst,
              ofPrevious: segment.ofPrevious,
            );
      final color = _colorOf(segment);
      fill.color = color;
      canvas.drawPath(shown.path, fill);
      if (t >= 1) _paintLabel(canvas, size, segment, color);
    }

    final hover = chart.hoverBorder;
    final at = touched;
    if (at != null &&
        at < segments.length &&
        hover != null &&
        hover.style != BorderStyle.none &&
        hover.width > 0) {
      canvas.drawPath(
        segments[at].path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = hover.width
          ..strokeJoin = StrokeJoin.round
          ..color = hover.color
          ..isAntiAlias = true,
      );
    }
  }

  Color _colorOf(FunnelSegment segment) {
    final own = segment.stage.color;
    if (own != null) return own;
    final palette = chart.palette;
    if (palette.isEmpty) return const Color(0xFF4C86CD);
    return palette[segment.index % palette.length];
  }

  String _formatValue(double value) {
    final format = chart.valueFormatter;
    if (format != null) return format(value);
    final whole = value.round();
    final digits = whole.abs().toString();
    final grouped = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return whole < 0 ? '-$grouped' : grouped;
  }

  String? _labelOf(FunnelSegment segment) {
    final builder = chart.labelBuilder;
    if (builder != null) return builder(segment);
    final name = segment.stage.label;
    final value = _formatValue(segment.stage.value);
    final share = segment.index == 0
        ? ''
        : ' · ${(segment.ofFirst * 100).toStringAsFixed(1)}%';
    return name == null || name.isEmpty ? '$value$share' : '$name\n$value$share';
  }

  void _paintLabel(
    Canvas canvas,
    Size size,
    FunnelSegment segment,
    Color color,
  ) {
    final text = _labelOf(segment);
    if (text == null || text.isEmpty) return;

    final inside = chart.labelStyle ??
        TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color.computeLuminance() > 0.5
              ? const Color(0xDD000000)
              : const Color(0xFFFFFFFF),
        );
    final tp = textCache.get(text, inside.copyWith(height: 1.2));
    final narrowest = math.min(segment.topWidth, segment.bottomWidth) - 8;
    final center = segment.rect.center;

    if (tp.width <= narrowest && tp.height <= segment.rect.height) {
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
      return;
    }

    // Too narrow to hold it: written beside the stage when there is room.
    final side = seriesAxisLabelStyle
        .copyWith(fontSize: 11, height: 1.2)
        .merge(chart.sideLabelStyle);
    final sideTp = textCache.get(text, side);
    final left = center.dx + segment.topWidth / 2 + 8;
    if (left + sideTp.width > size.width ||
        sideTp.height > segment.rect.height + chart.gap) {
      return;
    }
    sideTp.paint(canvas, Offset(left, center.dy - sideTp.height / 2));
  }

  @override
  bool shouldRepaint(FunnelChartPainter oldDelegate) =>
      !identical(oldDelegate.chart, chart) ||
      !identical(oldDelegate.segments, segments) ||
      oldDelegate.touched != touched ||
      oldDelegate.animation != animation;
}
