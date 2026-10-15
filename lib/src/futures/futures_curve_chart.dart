import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';
import '../treemap/treemap_data.dart' show treemapPalette;
import '../utils/xy_plot.dart';

/// One contract on a futures curve: its delivery month and its price.
@immutable
class FuturesContract {
  /// Creates a contract called [label] priced at [price].
  const FuturesContract({required this.label, required this.price, this.data});

  /// What the contract is called: its delivery month, `Mar 26`, or `Z5`.
  final String label;

  /// Its price; a value that is not finite leaves a gap.
  final double price;

  /// Anything the app wants back when this contract is touched.
  final Object? data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FuturesContract &&
          other.label == label &&
          other.price == price &&
          other.data == data;

  @override
  int get hashCode => Object.hash(label, price, data);
}

/// A futures curve: the prices of consecutive contracts at one moment.
@immutable
class FuturesCurve {
  /// Creates a curve called [label] through [contracts], nearest first.
  const FuturesCurve({
    required this.label,
    required this.contracts,
    this.color,
    this.dashed = false,
  });

  /// What the curve is called — `Today`, `A month ago`.
  final String label;

  /// The contracts, nearest delivery first.
  final List<FuturesContract> contracts;

  /// A colour of this curve's own; null takes one from the chart's palette.
  final Color? color;

  /// Whether the line is dashed, to set an earlier curve apart.
  final bool dashed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FuturesCurve &&
          other.label == label &&
          listEquals(other.contracts, contracts) &&
          other.color == color &&
          other.dashed == dashed;

  @override
  int get hashCode =>
      Object.hash(label, Object.hashAll(contracts), color, dashed);
}

/// The shape of a futures curve.
enum CurveShape {
  /// Later contracts cost more: the curve slopes up.
  contango,

  /// Later contracts cost less: the curve slopes down.
  backwardation,

  /// Every contract is priced alike.
  flat,

  /// The curve rises in places and falls in others.
  mixed,

  /// Fewer than two prices to compare.
  unknown,
}

/// Reads the shape of [contracts]: whether each contract costs more, less or
/// the same as the one before it.
///
/// A step smaller than [tolerance] of the price is read as flat, so noise in
/// the last decimal does not turn a contango into a mixed curve. Contracts
/// without a finite price are skipped.
CurveShape curveShape(List<FuturesContract> contracts, {double tolerance = 0}) {
  final prices = [
    for (final c in contracts)
      if (c.price.isFinite) c.price,
  ];
  if (prices.length < 2) return CurveShape.unknown;

  var up = false;
  var down = false;
  for (var i = 1; i < prices.length; i++) {
    final step = prices[i] - prices[i - 1];
    final scale = math.max(prices[i - 1].abs(), prices[i].abs());
    if (step.abs() <= scale * tolerance) continue;
    if (step > 0) up = true;
    if (step < 0) down = true;
  }
  if (up && down) return CurveShape.mixed;
  if (up) return CurveShape.contango;
  if (down) return CurveShape.backwardation;
  return CurveShape.flat;
}

/// How much the last priced contract costs over the first, as a fraction;
/// null with fewer than two prices or a first price of zero.
double? curveSlope(List<FuturesContract> contracts) {
  final prices = [
    for (final c in contracts)
      if (c.price.isFinite) c.price,
  ];
  if (prices.length < 2 || prices.first == 0) return null;
  return prices.last / prices.first - 1;
}

/// Each contract's price less the one before it — the calendar spread — with
/// null for the first contract and wherever either price is missing.
List<double?> calendarSpreads(List<FuturesContract> contracts) => [
  for (var i = 0; i < contracts.length; i++)
    i == 0 || !contracts[i].price.isFinite || !contracts[i - 1].price.isFinite
        ? null
        : contracts[i].price - contracts[i - 1].price,
];

/// Where one contract of one curve was laid out.
@immutable
class FuturesDot {
  /// Creates the dot of a contract.
  const FuturesDot({
    required this.curveIndex,
    required this.contractIndex,
    required this.curve,
    required this.contract,
    required this.center,
  });

  /// Which curve it is on.
  final int curveIndex;

  /// Which contract of that curve.
  final int contractIndex;

  /// The curve it is on.
  final FuturesCurve curve;

  /// The contract it draws.
  final FuturesContract contract;

  /// Where it sits, in the chart's local pixels.
  final Offset center;
}

/// The price range [curves] need, with room either side.
({double min, double max}) futuresPriceRange(List<FuturesCurve> curves) =>
    paddedRange([
      for (final curve in curves)
        for (final contract in curve.contracts) contract.price,
    ], pad: 0.12);

/// How many contract slots the longest of [curves] needs across the chart.
int futuresSlots(List<FuturesCurve> curves) {
  var slots = 0;
  for (final curve in curves) {
    slots = math.max(slots, curve.contracts.length);
  }
  return slots;
}

/// Places every contract of [curves] inside [bounds].
///
/// Contracts are spread evenly, one slot each, so the same contract sits at the
/// same place on every curve. A contract without a finite price has no dot.
List<FuturesDot> layOutFutures(
  List<FuturesCurve> curves,
  Rect bounds, {
  required double minPrice,
  required double maxPrice,
}) {
  final slots = futuresSlots(curves);
  if (slots == 0 || bounds.width <= 0 || bounds.height <= 0) return const [];
  return [
    for (var c = 0; c < curves.length; c++)
      for (var i = 0; i < curves[c].contracts.length; i++)
        if (curves[c].contracts[i].price.isFinite)
          FuturesDot(
            curveIndex: c,
            contractIndex: i,
            curve: curves[c],
            contract: curves[c].contracts[i],
            center: Offset(
              mapAcross(
                i.toDouble(),
                -0.5,
                slots - 0.5,
                bounds.left,
                bounds.right,
              ),
              mapAcross(
                curves[c].contracts[i].price,
                minPrice,
                maxPrice,
                bounds.bottom,
                bounds.top,
              ),
            ),
          ),
  ];
}

/// What a touch on a [FuturesCurveChart] landed on.
@immutable
class FuturesTouchDetails {
  /// Creates the details of a touch on [dot].
  const FuturesTouchDetails({required this.dot, required this.spread});

  /// The dot touched.
  final FuturesDot dot;

  /// The contract's price less the previous contract's on its curve; null for
  /// the first contract or where either price is missing.
  final double? spread;

  /// The contract touched.
  FuturesContract get contract => dot.contract;

  /// The curve it is on.
  FuturesCurve get curve => dot.curve;
}

/// Futures prices against delivery month — one or more curves, so the market's
/// term structure and how it has moved can be read at a glance.
///
/// ```dart
/// FuturesCurveChart(
///   curves: [
///     FuturesCurve(label: 'Today', contracts: today),
///     FuturesCurve(label: 'A month ago', contracts: before, dashed: true),
///   ],
/// );
/// ```
///
/// The first curve is the one read for the shape badge — contango or
/// backwardation, with its slope. The chart fills the box it is given, and is
/// [defaultHeight] high in a box with no height of its own.
class FuturesCurveChart extends StatefulWidget {
  /// Creates a chart of [curves].
  const FuturesCurveChart({
    super.key,
    required this.curves,
    this.palette = treemapPalette,
    this.lineWidth = 2,
    this.dotRadius = 3.5,
    this.showDots = true,
    this.showShapeBadge = true,
    this.contangoLabel = 'Contango',
    this.backwardationLabel = 'Backwardation',
    this.flatLabel = 'Flat',
    this.mixedLabel = 'Mixed',
    this.shapeTolerance = 0.0005,
    this.badgeStyle,
    this.showLegend = true,
    this.legendStyle,
    this.showAxes = true,
    this.axisWidth = 48,
    this.axisHeight = 18,
    this.tickCount = 5,
    this.priceFormatter,
    this.axisLabelStyle,
    this.priceAxisTitle,
    this.axisTitleStyle,
    this.gridColor = const Color(0x22FFFFFF),
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

  /// The curves, the first being the one the badge reads.
  final List<FuturesCurve> curves;

  /// Colours taken in turn by curves that name none.
  final List<Color> palette;

  /// How thick a curve is drawn.
  final double lineWidth;

  /// The radius of a contract's dot.
  final double dotRadius;

  /// Whether each contract is marked with a dot.
  final bool showDots;

  /// Whether the first curve's shape and slope are written in the corner.
  final bool showShapeBadge;

  /// What a rising curve is called.
  final String contangoLabel;

  /// What a falling curve is called.
  final String backwardationLabel;

  /// What an even curve is called.
  final String flatLabel;

  /// What a curve that both rises and falls is called.
  final String mixedLabel;

  /// The share of price a step must exceed to count as a rise or a fall.
  final double shapeTolerance;

  /// Style of the badge.
  final TextStyle? badgeStyle;

  /// Whether the curves' names are listed in the corner.
  final bool showLegend;

  /// Style of the legend.
  final TextStyle? legendStyle;

  /// Whether the two axes are drawn.
  final bool showAxes;

  /// How much room the price axis takes.
  final double axisWidth;

  /// How much room the contract axis takes.
  final double axisHeight;

  /// About how many ticks to write on the price axis.
  final int tickCount;

  /// Writes a price; null writes at most two decimals.
  final String Function(double value)? priceFormatter;

  /// Style of an axis label.
  final TextStyle? axisLabelStyle;

  /// Written up the price axis.
  final String? priceAxisTitle;

  /// Style of an axis title.
  final TextStyle? axisTitleStyle;

  /// Colour of the grid ruled at each tick; null rules none.
  final Color? gridColor;

  /// Drawn round the dot under the pointer; null marks none.
  final BorderSide? hoverBorder;

  /// Called as a touch moves over the contracts, and with null when it leaves.
  final ValueChanged<FuturesTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched contract; null shows none.
  final Widget? Function(BuildContext context, FuturesTouchDetails details)?
  tooltipBuilder;

  /// How far the card sits from the dot.
  final double tooltipMargin;

  /// How long the curves take to draw in; zero draws them at once.
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
  State<FuturesCurveChart> createState() => _FuturesCurveChartState();
}

class _FuturesCurveChartState extends State<FuturesCurveChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 64);
  List<FuturesDot> _dots = const [];
  ({int curve, int contract})? _touched;

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
  void didUpdateWidget(FuturesCurveChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!listEquals(oldWidget.curves, widget.curves)) {
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

  FuturesDot? _dotAt(Offset local) {
    FuturesDot? best;
    var closest = widget.dotRadius + 10;
    for (final dot in _dots) {
      final distance = (dot.center - local).distance;
      if (distance > closest) continue;
      closest = distance;
      best = dot;
    }
    return best;
  }

  FuturesTouchDetails _details(FuturesDot dot) {
    final spreads = calendarSpreads(dot.curve.contracts);
    return FuturesTouchDetails(dot: dot, spread: spreads[dot.contractIndex]);
  }

  void _handle(Offset local) {
    final dot = _dotAt(local);
    final key = dot == null
        ? null
        : (curve: dot.curveIndex, contract: dot.contractIndex);
    if (key == _touched) return;
    setState(() => _touched = key);
    widget.onTouch?.call(dot == null ? null : _details(dot));
  }

  void _leave() {
    if (_touched == null) return;
    setState(() => _touched = null);
    widget.onTouch?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.animationCurve.transform(_animation.value);
    final range = futuresPriceRange(widget.curves);

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
          box.left + (widget.showAxes ? widget.axisWidth : 0),
          box.top,
          box.right,
          math.max(
            box.top,
            box.bottom - (widget.showAxes ? widget.axisHeight : 0),
          ),
        );
        _dots = layOutFutures(
          widget.curves,
          plot,
          minPrice: range.min,
          maxPrice: range.max,
        );

        final touched = _touched;
        final dot = touched == null
            ? null
            : _dots
                  .where(
                    (d) =>
                        d.curveIndex == touched.curve &&
                        d.contractIndex == touched.contract,
                  )
                  .firstOrNull;
        final builder = widget.tooltipBuilder;
        final tooltip = dot == null || builder == null
            ? null
            : builder(context, _details(dot));

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
                      painter: FuturesCurveChartPainter(
                        chart: widget,
                        dots: _dots,
                        plot: plot,
                        minPrice: range.min,
                        maxPrice: range.max,
                        touched: touched,
                        animation: t,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (tooltip != null && dot != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomSingleChildLayout(
                          delegate: XyTooltipLayout(
                            anchor: Rect.fromCircle(
                              center: dot.center,
                              radius: widget.dotRadius,
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

/// Paints a [FuturesCurveChart]: the axes, the curves, the dots and the badge.
class FuturesCurveChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [dots] inside [plot].
  FuturesCurveChartPainter({
    required this.chart,
    required this.dots,
    required this.plot,
    required this.minPrice,
    required this.maxPrice,
    required this.touched,
    required this.animation,
    required this.textCache,
  });

  /// The chart being painted.
  final FuturesCurveChart chart;

  /// Where each contract sits.
  final List<FuturesDot> dots;

  /// The area the curves are drawn in.
  final Rect plot;

  /// The ends of the price axis.
  final double minPrice, maxPrice;

  /// The contract under the pointer.
  final ({int curve, int contract})? touched;

  /// How far the entry animation has got, from 0 to 1.
  final double animation;

  /// Where the labels are laid out.
  final TextPainterCache textCache;

  Color _colorOf(int curveIndex) {
    final own = chart.curves[curveIndex].color;
    if (own != null) return own;
    final palette = chart.palette;
    if (palette.isEmpty) return const Color(0xFF4C86CD);
    return palette[curveIndex % palette.length];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (dots.isEmpty) return;

    final slots = futuresSlots(chart.curves);
    final longest = chart.curves.firstWhere(
      (c) => c.contracts.length == slots,
      orElse: () => chart.curves.first,
    );
    paintXyAxes(
      canvas,
      textCache,
      plot: plot,
      minX: -0.5,
      maxX: slots - 0.5,
      minY: minPrice,
      maxY: maxPrice,
      tickCount: chart.tickCount,
      gridColor: chart.gridColor,
      showAxes: chart.showAxes,
      yFormatter: chart.priceFormatter,
      labelStyle: chart.axisLabelStyle,
      yTitle: chart.priceAxisTitle,
      titleStyle: chart.axisTitleStyle,
      axisWidth: chart.axisWidth,
      axisHeight: chart.axisHeight,
      xLabels: [for (final c in longest.contracts) c.label],
    );

    final t = animation.clamp(0.0, 1.0);
    // Curves are drawn last first, so the first stays on top.
    for (var c = chart.curves.length - 1; c >= 0; c--) {
      _paintCurve(canvas, c, t);
    }

    final at = touched;
    final hover = chart.hoverBorder;
    if (at != null && hover != null && hover.width > 0) {
      for (final dot in dots) {
        if (dot.curveIndex != at.curve || dot.contractIndex != at.contract) {
          continue;
        }
        canvas.drawCircle(
          dot.center,
          chart.dotRadius + hover.width + 2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = hover.width
            ..color = hover.color
            ..isAntiAlias = true,
        );
      }
    }

    _paintBadge(canvas);
  }

  void _paintCurve(Canvas canvas, int curveIndex, double t) {
    final mine = [
      for (final dot in dots)
        if (dot.curveIndex == curveIndex) dot,
    ];
    if (mine.isEmpty) return;
    final color = _colorOf(curveIndex);
    final dashed = chart.curves[curveIndex].dashed;

    // The line grows in from the left: only the first `t` of its length shows.
    final reach = plot.left + plot.width * t;
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = chart.lineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color
      ..isAntiAlias = true;

    canvas
      ..save()
      ..clipRect(Rect.fromLTRB(0, 0, reach + chart.dotRadius, plot.bottom + 8));
    for (var i = 1; i < mine.length; i++) {
      // A gap in the prices breaks the line rather than bridging it.
      if (mine[i].contractIndex != mine[i - 1].contractIndex + 1) continue;
      _segment(canvas, mine[i - 1].center, mine[i].center, pen, dashed);
    }
    if (chart.showDots) {
      for (final dot in mine) {
        canvas.drawCircle(
          dot.center,
          chart.dotRadius,
          Paint()
            ..color = color
            ..isAntiAlias = true,
        );
      }
    }
    canvas.restore();
  }

  void _segment(Canvas canvas, Offset a, Offset b, Paint pen, bool dashed) {
    if (!dashed) {
      canvas.drawLine(a, b, pen);
      return;
    }
    const dash = 6.0;
    const gap = 4.0;
    final total = (b - a).distance;
    if (total <= 0) return;
    final direction = (b - a) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final end = math.min(travelled + dash, total);
      canvas.drawLine(a + direction * travelled, a + direction * end, pen);
      travelled += dash + gap;
    }
  }

  void _paintBadge(Canvas canvas) {
    var top = plot.top + 4;
    if (chart.showShapeBadge && chart.curves.isNotEmpty) {
      final contracts = chart.curves.first.contracts;
      final shape = curveShape(contracts, tolerance: chart.shapeTolerance);
      final name = switch (shape) {
        CurveShape.contango => chart.contangoLabel,
        CurveShape.backwardation => chart.backwardationLabel,
        CurveShape.flat => chart.flatLabel,
        CurveShape.mixed => chart.mixedLabel,
        CurveShape.unknown => null,
      };
      if (name != null) {
        final slope = curveSlope(contracts);
        final text = slope == null
            ? name
            : '$name ${slope >= 0 ? '+' : ''}'
                  '${(slope * 100).toStringAsFixed(1)}%';
        final style = TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: switch (shape) {
            CurveShape.contango => const Color(0xFF2F9E44),
            CurveShape.backwardation => const Color(0xFFE03131),
            _ => const Color(0xCCFFFFFF),
          },
        ).merge(chart.badgeStyle);
        final tp = textCache.get(text, style);
        tp.paint(canvas, Offset(plot.left + 8, top));
        top += tp.height + 4;
      }
    }

    if (chart.showLegend && chart.curves.length > 1) {
      final style = const TextStyle(
        fontSize: 10,
        color: Color(0xCCFFFFFF),
      ).merge(chart.legendStyle);
      for (var c = 0; c < chart.curves.length; c++) {
        final tp = textCache.get(chart.curves[c].label, style);
        final y = top + c * (tp.height + 3);
        canvas.drawLine(
          Offset(plot.left + 8, y + tp.height / 2),
          Offset(plot.left + 24, y + tp.height / 2),
          Paint()
            ..color = _colorOf(c)
            ..strokeWidth = 2,
        );
        tp.paint(canvas, Offset(plot.left + 30, y));
      }
    }
  }

  @override
  bool shouldRepaint(FuturesCurveChartPainter oldDelegate) =>
      !identical(oldDelegate.chart, chart) ||
      !identical(oldDelegate.dots, dots) ||
      oldDelegate.plot != plot ||
      oldDelegate.minPrice != minPrice ||
      oldDelegate.maxPrice != maxPrice ||
      oldDelegate.touched != touched ||
      oldDelegate.animation != animation;
}
