import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';
import '../utils/xy_plot.dart';

/// One portfolio: how risky it is and what it is expected to return.
@immutable
class PortfolioPoint {
  /// Creates a portfolio with [risk] — volatility, or standard deviation — and
  /// [expectedReturn], both in the same period and the same unit, a fraction
  /// or a percentage.
  const PortfolioPoint({
    required this.risk,
    required this.expectedReturn,
    this.label,
    this.color,
    this.data,
  });

  /// How risky it is.
  final double risk;

  /// What it is expected to return.
  final double expectedReturn;

  /// What the portfolio is called.
  final String? label;

  /// A colour of this portfolio's own.
  final Color? color;

  /// Anything the app wants back when this portfolio is touched.
  final Object? data;

  /// Its return per unit of risk above [riskFree]; null with no risk to
  /// measure it against.
  double? sharpe([double riskFree = 0]) {
    if (!risk.isFinite || !expectedReturn.isFinite || risk <= 0) return null;
    return (expectedReturn - riskFree) / risk;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PortfolioPoint &&
          other.risk == risk &&
          other.expectedReturn == expectedReturn &&
          other.label == label &&
          other.color == color &&
          other.data == data;

  @override
  int get hashCode =>
      Object.hashAll([risk, expectedReturn, label, color, data]);
}

/// The indices of the portfolios on the efficient frontier: those no other
/// portfolio beats by returning more for no more risk. In order of rising risk.
///
/// A portfolio with a number that is not finite is never on it.
List<int> efficientFrontierIndices(List<PortfolioPoint> points) {
  final order =
      [
        for (var i = 0; i < points.length; i++)
          if (points[i].risk.isFinite && points[i].expectedReturn.isFinite) i,
      ]..sort((a, b) {
        final byRisk = points[a].risk.compareTo(points[b].risk);
        if (byRisk != 0) return byRisk;
        // At the same risk the larger return comes first, and the smaller one is
        // then beaten by it.
        return points[b].expectedReturn.compareTo(points[a].expectedReturn);
      });

  final frontier = <int>[];
  var best = double.negativeInfinity;
  for (final i in order) {
    if (points[i].expectedReturn > best) {
      frontier.add(i);
      best = points[i].expectedReturn;
    }
  }
  return frontier;
}

/// The index of the portfolio with the best return per unit of risk above
/// [riskFree]; null when none has a risk to measure against.
int? maxSharpeIndex(List<PortfolioPoint> points, {double riskFree = 0}) {
  int? best;
  var top = double.negativeInfinity;
  for (var i = 0; i < points.length; i++) {
    final ratio = points[i].sharpe(riskFree);
    if (ratio != null && ratio > top) {
      top = ratio;
      best = i;
    }
  }
  return best;
}

/// The index of the least risky portfolio; null when there is none. Of two
/// at the same risk, the one that returns more.
int? minRiskIndex(List<PortfolioPoint> points) {
  int? best;
  for (var i = 0; i < points.length; i++) {
    final p = points[i];
    if (!p.risk.isFinite || !p.expectedReturn.isFinite) continue;
    if (best == null ||
        p.risk < points[best].risk ||
        (p.risk == points[best].risk &&
            p.expectedReturn > points[best].expectedReturn)) {
      best = i;
    }
  }
  return best;
}

/// What a portfolio is, on a [EfficientFrontierChart].
enum FrontierRole {
  /// An ordinary portfolio, beaten by one on the frontier.
  portfolio,

  /// On the efficient frontier.
  frontier,

  /// The frontier portfolio with the best return per unit of risk.
  maxSharpe,

  /// The least risky portfolio.
  minRisk,

  /// The portfolio held now, passed apart from the candidates.
  current,
}

/// Where one portfolio was laid out.
@immutable
class FrontierDot {
  /// Creates the dot of [point].
  const FrontierDot({
    required this.point,
    required this.index,
    required this.center,
    required this.role,
  });

  /// The portfolio this dot draws.
  final PortfolioPoint point;

  /// Its position in the list it was given in; one past the end for the
  /// current portfolio.
  final int index;

  /// Where it sits, in the chart's local pixels.
  final Offset center;

  /// What it is on the chart.
  final FrontierRole role;
}

/// The ranges [points] need on the two axes: risk from zero, return with room.
({double minRisk, double maxRisk, double minReturn, double maxReturn})
frontierRange(Iterable<PortfolioPoint> points, {double riskFree = 0}) {
  final risks = <double>[0];
  final returns = <double>[];
  for (final point in points) {
    if (!point.risk.isFinite || !point.expectedReturn.isFinite) continue;
    risks.add(point.risk);
    returns.add(point.expectedReturn);
  }
  if (riskFree.isFinite) returns.add(riskFree);
  final x = paddedRange(risks, pad: 0.08);
  final y = paddedRange(returns);
  return (
    minRisk: 0,
    maxRisk: x.max <= 0 ? 1 : x.max,
    minReturn: y.min,
    maxReturn: y.max,
  );
}

/// What a touch on an [EfficientFrontierChart] landed on.
@immutable
class FrontierTouchDetails {
  /// Creates the details of a touch on [dot].
  const FrontierTouchDetails({required this.dot, required this.sharpe});

  /// The dot touched.
  final FrontierDot dot;

  /// Its return per unit of risk above the chart's risk-free rate.
  final double? sharpe;

  /// The portfolio it draws.
  PortfolioPoint get point => dot.point;
}

/// Portfolios by risk and return, with the efficient frontier traced through
/// the best of them.
///
/// ```dart
/// EfficientFrontierChart(
///   points: [
///     for (final w in candidateWeights)
///       PortfolioPoint(risk: w.volatility, expectedReturn: w.mean),
///   ],
///   riskFreeRate: 0.02,
///   current: PortfolioPoint(risk: 0.14, expectedReturn: 0.07, label: 'Now'),
/// );
/// ```
///
/// The frontier joins the portfolios nothing beats; the one with the best
/// return per unit of risk is marked, and so is the least risky. A line from
/// the risk-free rate through the best of them is the capital market line.
/// The chart fills the box it is given, and is [defaultHeight] high in a box
/// with no height of its own.
class EfficientFrontierChart extends StatefulWidget {
  /// Creates a risk-return plot of [points].
  const EfficientFrontierChart({
    super.key,
    required this.points,
    this.current,
    this.riskFreeRate = 0,
    this.showFrontier = true,
    this.showMaxSharpe = true,
    this.showMinRisk = true,
    this.showCapitalMarketLine = true,
    this.portfolioColor = const Color(0x884C86CD),
    this.frontierColor = const Color(0xFF2F9E44),
    this.maxSharpeColor = const Color(0xFFF2B01E),
    this.minRiskColor = const Color(0xFF3FA7D6),
    this.currentColor = const Color(0xFFE03131),
    this.lineColor = const Color(0x66FFFFFF),
    this.dotRadius = 3.5,
    this.markerSize = 7,
    this.frontierWidth = 2,
    this.showMarkerLabels = true,
    this.maxSharpeLabel = 'Max Sharpe',
    this.minRiskLabel = 'Min risk',
    this.currentLabel = 'Current',
    this.markerLabelStyle,
    this.showAxes = true,
    this.axisWidth = 44,
    this.axisHeight = 18,
    this.tickCount = 5,
    this.riskFormatter,
    this.returnFormatter,
    this.axisLabelStyle,
    this.riskAxisTitle = 'Risk',
    this.returnAxisTitle = 'Return',
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
    this.defaultHeight = 280,
    this.semanticLabel,
  });

  /// The candidate portfolios.
  final List<PortfolioPoint> points;

  /// The portfolio held now, drawn apart from the candidates; null draws none.
  final PortfolioPoint? current;

  /// The return with no risk at all, in the same unit as the returns.
  final double riskFreeRate;

  /// Whether the frontier is traced.
  final bool showFrontier;

  /// Whether the best return per unit of risk is marked.
  final bool showMaxSharpe;

  /// Whether the least risky portfolio is marked.
  final bool showMinRisk;

  /// Whether the line from the risk-free rate through the best portfolio is
  /// drawn. Needs [showMaxSharpe]'s portfolio to exist.
  final bool showCapitalMarketLine;

  /// The colour of an ordinary portfolio.
  final Color portfolioColor;

  /// The colour of the frontier and the portfolios on it.
  final Color frontierColor;

  /// The colour of the best-Sharpe marker.
  final Color maxSharpeColor;

  /// The colour of the least-risk marker.
  final Color minRiskColor;

  /// The colour of the current portfolio.
  final Color currentColor;

  /// The colour of the capital market line.
  final Color lineColor;

  /// The radius of an ordinary dot.
  final double dotRadius;

  /// Half the size of a marker.
  final double markerSize;

  /// How thick the frontier is.
  final double frontierWidth;

  /// Whether the markers are named beside them.
  final bool showMarkerLabels;

  /// What the best-Sharpe marker is called.
  final String maxSharpeLabel;

  /// What the least-risk marker is called.
  final String minRiskLabel;

  /// What the current portfolio is called.
  final String currentLabel;

  /// Style of a marker's name.
  final TextStyle? markerLabelStyle;

  /// Whether the two axes are drawn.
  final bool showAxes;

  /// How much room the side axis takes.
  final double axisWidth;

  /// How much room the bottom axis takes.
  final double axisHeight;

  /// About how many ticks to write on each axis.
  final int tickCount;

  /// Writes a risk on the bottom axis; null writes at most two decimals.
  final String Function(double value)? riskFormatter;

  /// Writes a return on the side axis; null writes at most two decimals.
  final String Function(double value)? returnFormatter;

  /// Style of an axis label.
  final TextStyle? axisLabelStyle;

  /// Written under the bottom axis.
  final String? riskAxisTitle;

  /// Written up the side axis.
  final String? returnAxisTitle;

  /// Style of an axis title.
  final TextStyle? axisTitleStyle;

  /// Colour of the grid ruled at each tick; null rules none.
  final Color? gridColor;

  /// Drawn round the dot under the pointer; null marks none.
  final BorderSide? hoverBorder;

  /// Called as a touch moves over the dots, and with null when it leaves.
  final ValueChanged<FrontierTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched dot; null shows none.
  final Widget? Function(BuildContext context, FrontierTouchDetails details)?
  tooltipBuilder;

  /// How far the card sits from the dot.
  final double tooltipMargin;

  /// How long the plot takes to grow in; zero draws it at once.
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
  State<EfficientFrontierChart> createState() => _EfficientFrontierChartState();
}

class _EfficientFrontierChartState extends State<EfficientFrontierChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 64);
  List<FrontierDot> _dots = const [];
  List<int> _frontier = const [];
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
  void didUpdateWidget(EfficientFrontierChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!listEquals(oldWidget.points, widget.points) ||
        oldWidget.current != widget.current) {
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

  FrontierDot? _dotAt(Offset local) {
    FrontierDot? best;
    var closest = widget.dotRadius + widget.markerSize + 4;
    for (final dot in _dots) {
      final distance = (dot.center - local).distance;
      if (distance > closest) continue;
      closest = distance;
      best = dot;
    }
    return best;
  }

  FrontierTouchDetails _details(FrontierDot dot) => FrontierTouchDetails(
    dot: dot,
    sharpe: dot.point.sharpe(widget.riskFreeRate),
  );

  void _handle(Offset local) {
    final dot = _dotAt(local);
    final index = dot?.index;
    if (index == _touched) return;
    setState(() => _touched = index);
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
    final everything = [
      ...widget.points,
      if (widget.current != null) widget.current!,
    ];
    final range = frontierRange(everything, riskFree: widget.riskFreeRate);

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
            box.bottom - (widget.showAxes ? widget.axisHeight + 14 : 0),
          ),
        );

        _frontier = efficientFrontierIndices(widget.points);
        final sharpe = maxSharpeIndex(
          widget.points,
          riskFree: widget.riskFreeRate,
        );
        final minRisk = minRiskIndex(widget.points);
        final onFrontier = _frontier.toSet();
        _dots = [
          if (plot.width > 0 && plot.height > 0)
            for (var i = 0; i < widget.points.length; i++)
              if (widget.points[i].risk.isFinite &&
                  widget.points[i].expectedReturn.isFinite)
                FrontierDot(
                  point: widget.points[i],
                  index: i,
                  center: Offset(
                    mapAcross(
                      widget.points[i].risk,
                      range.minRisk,
                      range.maxRisk,
                      plot.left,
                      plot.right,
                    ),
                    mapAcross(
                      widget.points[i].expectedReturn,
                      range.minReturn,
                      range.maxReturn,
                      plot.bottom,
                      plot.top,
                    ),
                  ),
                  role: i == sharpe && widget.showMaxSharpe
                      ? FrontierRole.maxSharpe
                      : i == minRisk && widget.showMinRisk
                      ? FrontierRole.minRisk
                      : onFrontier.contains(i) && widget.showFrontier
                      ? FrontierRole.frontier
                      : FrontierRole.portfolio,
                ),
          if (plot.width > 0 &&
              plot.height > 0 &&
              widget.current != null &&
              widget.current!.risk.isFinite &&
              widget.current!.expectedReturn.isFinite)
            FrontierDot(
              point: widget.current!,
              index: widget.points.length,
              center: Offset(
                mapAcross(
                  widget.current!.risk,
                  range.minRisk,
                  range.maxRisk,
                  plot.left,
                  plot.right,
                ),
                mapAcross(
                  widget.current!.expectedReturn,
                  range.minReturn,
                  range.maxReturn,
                  plot.bottom,
                  plot.top,
                ),
              ),
              role: FrontierRole.current,
            ),
        ];

        final touched = _touched;
        final dot = touched == null
            ? null
            : _dots.where((d) => d.index == touched).firstOrNull;
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
                      painter: EfficientFrontierChartPainter(
                        chart: widget,
                        dots: _dots,
                        frontier: _frontier,
                        plot: plot,
                        range: range,
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
                              radius: widget.dotRadius + widget.markerSize,
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

/// Paints an [EfficientFrontierChart]: the axes, the capital market line, the
/// frontier and the portfolios.
class EfficientFrontierChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [dots] inside [plot].
  EfficientFrontierChartPainter({
    required this.chart,
    required this.dots,
    required this.frontier,
    required this.plot,
    required this.range,
    required this.touched,
    required this.animation,
    required this.textCache,
  });

  /// The chart being painted.
  final EfficientFrontierChart chart;

  /// Where each portfolio sits.
  final List<FrontierDot> dots;

  /// The indices of the frontier portfolios, by rising risk.
  final List<int> frontier;

  /// The area the dots are drawn in.
  final Rect plot;

  /// The ranges of the two axes.
  final ({double minRisk, double maxRisk, double minReturn, double maxReturn})
  range;

  /// The index of the portfolio under the pointer.
  final int? touched;

  /// How far the entry animation has got, from 0 to 1.
  final double animation;

  /// Where the labels are laid out.
  final TextPainterCache textCache;

  Offset _at(double risk, double expectedReturn) => Offset(
    mapAcross(risk, range.minRisk, range.maxRisk, plot.left, plot.right),
    mapAcross(
      expectedReturn,
      range.minReturn,
      range.maxReturn,
      plot.bottom,
      plot.top,
    ),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (dots.isEmpty) return;

    paintXyAxes(
      canvas,
      textCache,
      plot: plot,
      minX: range.minRisk,
      maxX: range.maxRisk,
      minY: range.minReturn,
      maxY: range.maxReturn,
      tickCount: chart.tickCount,
      gridColor: chart.gridColor,
      showAxes: chart.showAxes,
      xFormatter: chart.riskFormatter,
      yFormatter: chart.returnFormatter,
      labelStyle: chart.axisLabelStyle,
      xTitle: chart.riskAxisTitle,
      yTitle: chart.returnAxisTitle,
      titleStyle: chart.axisTitleStyle,
      axisWidth: chart.axisWidth,
      axisHeight: chart.axisHeight,
    );

    final t = animation.clamp(0.0, 1.0);
    canvas
      ..save()
      ..clipRect(plot.inflate(chart.markerSize + 2));

    _paintCapitalMarketLine(canvas);
    _paintFrontier(canvas, t);

    for (final dot in dots) {
      if (!dot.center.dx.isFinite || !dot.center.dy.isFinite) continue;
      _paintDot(canvas, dot, t);
    }
    canvas.restore();

    final at = touched;
    final hover = chart.hoverBorder;
    if (at != null && hover != null && hover.width > 0) {
      for (final dot in dots) {
        if (dot.index != at) continue;
        canvas.drawCircle(
          dot.center,
          chart.dotRadius + chart.markerSize * 0.5 + hover.width + 2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = hover.width
            ..color = hover.color
            ..isAntiAlias = true,
        );
      }
    }
  }

  void _paintCapitalMarketLine(Canvas canvas) {
    if (!chart.showCapitalMarketLine || !chart.showMaxSharpe) return;
    final best = dots
        .where((d) => d.role == FrontierRole.maxSharpe)
        .firstOrNull;
    if (best == null || best.point.risk <= 0) return;

    // The line from (0, riskFree) through the best portfolio, run on to the
    // right-hand edge of the plot.
    final slope =
        (best.point.expectedReturn - chart.riskFreeRate) / best.point.risk;
    final from = _at(0, chart.riskFreeRate);
    final to = _at(range.maxRisk, chart.riskFreeRate + slope * range.maxRisk);
    const dash = 5.0;
    const gap = 4.0;
    final total = (to - from).distance;
    if (!total.isFinite || total <= 0) return;
    final direction = (to - from) / total;
    final pen = Paint()
      ..color = chart.lineColor
      ..strokeWidth = 1;
    var travelled = 0.0;
    while (travelled < total) {
      final end = math.min(travelled + dash, total);
      canvas.drawLine(
        from + direction * travelled,
        from + direction * end,
        pen,
      );
      travelled += dash + gap;
    }
  }

  void _paintFrontier(Canvas canvas, double t) {
    if (!chart.showFrontier || frontier.length < 2) return;
    final path = Path();
    var first = true;
    for (final index in frontier) {
      final dot = dots.where((d) => d.index == index).firstOrNull;
      if (dot == null) continue;
      if (first) {
        path.moveTo(dot.center.dx, dot.center.dy);
        first = false;
      } else {
        path.lineTo(dot.center.dx, dot.center.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = chart.frontierWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = chart.frontierColor.withValues(alpha: t)
        ..isAntiAlias = true,
    );
  }

  void _paintDot(Canvas canvas, FrontierDot dot, double t) {
    final own = dot.point.color;
    final marker = chart.markerSize * t;
    switch (dot.role) {
      case FrontierRole.portfolio:
        canvas.drawCircle(
          dot.center,
          chart.dotRadius * t,
          Paint()
            ..color = own ?? chart.portfolioColor
            ..isAntiAlias = true,
        );
      case FrontierRole.frontier:
        canvas.drawCircle(
          dot.center,
          chart.dotRadius * t,
          Paint()
            ..color = own ?? chart.frontierColor
            ..isAntiAlias = true,
        );
      case FrontierRole.maxSharpe:
        _paintDiamond(canvas, dot.center, marker, own ?? chart.maxSharpeColor);
        _paintName(canvas, dot, chart.maxSharpeLabel, t);
      case FrontierRole.minRisk:
        canvas.drawRect(
          Rect.fromCenter(
            center: dot.center,
            width: marker * 1.6,
            height: marker * 1.6,
          ),
          Paint()
            ..color = own ?? chart.minRiskColor
            ..isAntiAlias = true,
        );
        _paintName(canvas, dot, chart.minRiskLabel, t);
      case FrontierRole.current:
        canvas.drawCircle(
          dot.center,
          marker,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = own ?? chart.currentColor
            ..isAntiAlias = true,
        );
        canvas.drawCircle(
          dot.center,
          chart.dotRadius * t,
          Paint()
            ..color = own ?? chart.currentColor
            ..isAntiAlias = true,
        );
        _paintName(canvas, dot, dot.point.label ?? chart.currentLabel, t);
    }
  }

  void _paintDiamond(Canvas canvas, Offset c, double r, Color color) {
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - r)
        ..lineTo(c.dx + r, c.dy)
        ..lineTo(c.dx, c.dy + r)
        ..lineTo(c.dx - r, c.dy)
        ..close(),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  void _paintName(Canvas canvas, FrontierDot dot, String name, double t) {
    if (!chart.showMarkerLabels || name.isEmpty || t < 1) return;
    final style = const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: Color(0xCCFFFFFF),
    ).merge(chart.markerLabelStyle);
    final tp = textCache.get(name, style);
    var left = dot.center.dx + chart.markerSize + 4;
    if (left + tp.width > plot.right + chart.markerSize) {
      left = dot.center.dx - chart.markerSize - 4 - tp.width;
    }
    tp.paint(canvas, Offset(left, dot.center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(EfficientFrontierChartPainter oldDelegate) =>
      !identical(oldDelegate.chart, chart) ||
      !identical(oldDelegate.dots, dots) ||
      oldDelegate.plot != plot ||
      oldDelegate.range != range ||
      oldDelegate.touched != touched ||
      oldDelegate.animation != animation;
}
