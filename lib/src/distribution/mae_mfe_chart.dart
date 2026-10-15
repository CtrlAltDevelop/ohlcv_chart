import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';
import '../utils/xy_plot.dart';

/// One trade seen from the inside: what it ended at, how far it went against
/// the trader on the way, and how far it went their way.
@immutable
class TradeExcursion {
  /// Creates a trade that made [pnl], after going [mae] against the position at
  /// worst and [mfe] in its favour at best.
  ///
  /// Both excursions are distances, so zero or more: a trade that was never
  /// under water has an [mae] of 0. They are in the same unit as [pnl] — R,
  /// points or money.
  const TradeExcursion({
    required this.pnl,
    required this.mae,
    required this.mfe,
    this.label,
    this.color,
    this.data,
  });

  /// What the trade made or lost.
  final double pnl;

  /// The most it went against the position: maximum adverse excursion.
  final double mae;

  /// The most it went in the position's favour: maximum favourable excursion.
  final double mfe;

  /// What the trade is called.
  final String? label;

  /// A colour of this trade's own, used instead of the win or loss colour.
  final Color? color;

  /// Anything the app wants back when this trade is touched.
  final Object? data;

  /// Whether the trade made money.
  bool get isWinner => pnl > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TradeExcursion &&
          other.pnl == pnl &&
          other.mae == mae &&
          other.mfe == mfe &&
          other.label == label &&
          other.color == color &&
          other.data == data;

  @override
  int get hashCode => Object.hashAll([pnl, mae, mfe, label, color, data]);
}

/// Which excursion a [MaeMfeChart] puts along its bottom axis.
enum ExcursionKind {
  /// How far each trade went against the position. A winner that went far
  /// against you was survived by a stop that was too wide to be sensible, and a
  /// stop placed where few winners reached would have cost little.
  adverse,

  /// How far each trade went in the position's favour. A target placed where
  /// the winners topped out would have caught most of what they had to give.
  favourable,
}

/// What a set of trades' excursions add up to.
@immutable
class ExcursionStats {
  /// Creates statistics from their parts; see [ExcursionStats.fromTrades].
  const ExcursionStats({
    required this.count,
    required this.winners,
    required this.losers,
    required this.averageAdverse,
    required this.averageFavourable,
  });

  /// Works the statistics out from [trades].
  ///
  /// A trade with a number that is not finite is skipped. A trade of exactly
  /// zero counts as neither a winner nor a loser.
  factory ExcursionStats.fromTrades(Iterable<TradeExcursion> trades) {
    var count = 0;
    var winners = 0;
    var losers = 0;
    var adverse = 0.0;
    var favourable = 0.0;
    for (final trade in trades) {
      if (!trade.pnl.isFinite || !trade.mae.isFinite || !trade.mfe.isFinite) {
        continue;
      }
      count++;
      if (trade.pnl > 0) winners++;
      if (trade.pnl < 0) losers++;
      adverse += trade.mae.abs();
      favourable += trade.mfe.abs();
    }
    return ExcursionStats(
      count: count,
      winners: winners,
      losers: losers,
      averageAdverse: count == 0 ? 0 : adverse / count,
      averageFavourable: count == 0 ? 0 : favourable / count,
    );
  }

  /// How many trades there were.
  final int count;

  /// How many made money.
  final int winners;

  /// How many lost it.
  final int losers;

  /// The average distance the trades went against the position.
  final double averageAdverse;

  /// The average distance they went in its favour.
  final double averageFavourable;

  /// What the trades had to give, against what they cost to hold: the average
  /// favourable excursion over the average adverse one. Above 1 the market
  /// moved more for the positions than against them; infinite when none ever
  /// went against.
  double get edgeRatio {
    if (averageAdverse <= 0) {
      return averageFavourable > 0 ? double.infinity : 0;
    }
    return averageFavourable / averageAdverse;
  }
}

/// How many of the winners among [trades] a stop [stop] away from the entry
/// would have taken out before they won — the cost of that stop.
///
/// A trade is stopped when it went at least [stop] against the position.
int winnersStoppedAt(Iterable<TradeExcursion> trades, double stop) {
  var stopped = 0;
  for (final trade in trades) {
    if (trade.isWinner && trade.mae.isFinite && trade.mae >= stop) stopped++;
  }
  return stopped;
}

/// The ranges [trades] need on the two axes of a chart of [kind].
///
/// The bottom axis runs from zero to the longest excursion; the side axis holds
/// every result and zero, with room either side.
({double minX, double maxX, double minY, double maxY}) excursionRange(
  List<TradeExcursion> trades,
  ExcursionKind kind,
) {
  var longest = 0.0;
  final results = <double>[];
  for (final trade in trades) {
    final reach = kind == ExcursionKind.adverse ? trade.mae : trade.mfe;
    if (!reach.isFinite || !trade.pnl.isFinite) continue;
    longest = math.max(longest, reach.abs());
    results.add(trade.pnl);
  }
  final y = paddedRange(results, includeZero: true);
  return (
    minX: 0,
    maxX: longest <= 0 ? 1 : longest * 1.08,
    minY: y.min,
    maxY: y.max,
  );
}

/// Where one [TradeExcursion] was laid out.
@immutable
class ExcursionDot {
  /// Creates the dot of [trade].
  const ExcursionDot({
    required this.trade,
    required this.index,
    required this.center,
  });

  /// The trade this dot draws.
  final TradeExcursion trade;

  /// Its position in the list it was given in.
  final int index;

  /// Where it sits, in the chart's local pixels.
  final Offset center;
}

/// Places [trades] inside [bounds] against the ranges given.
///
/// A trade whose numbers are not finite is left out, so the returned dots may
/// be fewer than the trades; each keeps its [ExcursionDot.index].
List<ExcursionDot> layOutExcursions(
  List<TradeExcursion> trades,
  Rect bounds, {
  required ExcursionKind kind,
  required double minX,
  required double maxX,
  required double minY,
  required double maxY,
}) {
  if (trades.isEmpty || bounds.width <= 0 || bounds.height <= 0) {
    return const [];
  }
  return [
    for (var i = 0; i < trades.length; i++)
      if (trades[i].pnl.isFinite &&
          (kind == ExcursionKind.adverse ? trades[i].mae : trades[i].mfe)
              .isFinite)
        ExcursionDot(
          trade: trades[i],
          index: i,
          center: Offset(
            mapAcross(
              (kind == ExcursionKind.adverse ? trades[i].mae : trades[i].mfe)
                  .abs(),
              minX,
              maxX,
              bounds.left,
              bounds.right,
            ),
            mapAcross(trades[i].pnl, minY, maxY, bounds.bottom, bounds.top),
          ),
        ),
  ];
}

/// The dot nearest [local] within [reach] pixels, or null when none is.
ExcursionDot? excursionDotAt(
  List<ExcursionDot> dots,
  Offset local, {
  double reach = 10,
}) {
  ExcursionDot? best;
  var closest = reach;
  for (final dot in dots) {
    final distance = (dot.center - local).distance;
    if (distance > closest) continue;
    closest = distance;
    best = dot;
  }
  return best;
}

/// What a touch on a [MaeMfeChart] landed on.
@immutable
class ExcursionTouchDetails {
  /// Creates the details of a touch on [dot].
  const ExcursionTouchDetails({required this.dot});

  /// The dot touched.
  final ExcursionDot dot;

  /// The trade it draws.
  TradeExcursion get trade => dot.trade;
}

/// Every trade as a point: how far it went against you, or for you, and what it
/// finally made — a MAE or MFE scatter.
///
/// ```dart
/// MaeMfeChart(
///   trades: [
///     for (final t in backtest.trades)
///       TradeExcursion(pnl: t.r, mae: t.maxAdverseR, mfe: t.maxFavourableR),
///   ],
///   xReferenceLines: const [1], // the stop used
/// );
/// ```
///
/// Winners and losers take their own colours. A line marks the limit no trade
/// can pass — a result never beats its favourable excursion, nor loses more
/// than its adverse one. The chart fills the box it is given, and is
/// [defaultHeight] high in a box with no height of its own.
class MaeMfeChart extends StatefulWidget {
  /// Creates a scatter of [trades].
  const MaeMfeChart({
    super.key,
    required this.trades,
    this.kind = ExcursionKind.adverse,
    this.minX,
    this.maxX,
    this.minY,
    this.maxY,
    this.winnerColor = const Color(0xFF2F9E44),
    this.loserColor = const Color(0xFFE03131),
    this.dotRadius = 4,
    this.dotOpacity = 0.75,
    this.showLimit = true,
    this.limitColor = const Color(0x55FFFFFF),
    this.showZeroLine = true,
    this.showAxes = true,
    this.axisWidth = 44,
    this.axisHeight = 18,
    this.tickCount = 5,
    this.xFormatter,
    this.yFormatter,
    this.axisLabelStyle,
    this.xAxisTitle,
    this.yAxisTitle,
    this.axisTitleStyle,
    this.gridColor = const Color(0x22FFFFFF),
    this.xReferenceLines = const [],
    this.referenceColor = const Color(0x99FFFFFF),
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

  /// The trades, one dot each.
  final List<TradeExcursion> trades;

  /// Which excursion runs along the bottom axis.
  final ExcursionKind kind;

  /// The left of the bottom axis; null starts it at zero.
  final double? minX;

  /// The right of the bottom axis; null reaches the longest excursion.
  final double? maxX;

  /// The bottom of the side axis; null reads it off the results.
  final double? minY;

  /// The top of the side axis; null reads it off the results.
  final double? maxY;

  /// The colour of a trade that made money.
  final Color winnerColor;

  /// The colour of a trade that lost it.
  final Color loserColor;

  /// The radius of a dot.
  final double dotRadius;

  /// How opaque a dot is, so a crowd of them shows where it is densest.
  final double dotOpacity;

  /// Whether the line no trade can cross is drawn.
  final bool showLimit;

  /// The colour of that line.
  final Color limitColor;

  /// Whether a line marks a result of zero.
  final bool showZeroLine;

  /// Whether the two axes are drawn.
  final bool showAxes;

  /// How much room the side axis takes.
  final double axisWidth;

  /// How much room the bottom axis takes.
  final double axisHeight;

  /// About how many ticks to write on each axis.
  final int tickCount;

  /// Writes a value on the bottom axis; null writes at most two decimals.
  final String Function(double value)? xFormatter;

  /// Writes a value on the side axis; null writes at most two decimals.
  final String Function(double value)? yFormatter;

  /// Style of an axis label.
  final TextStyle? axisLabelStyle;

  /// Written under the bottom axis; null names the excursion.
  final String? xAxisTitle;

  /// Written up the side axis; null writes nothing.
  final String? yAxisTitle;

  /// Style of an axis title.
  final TextStyle? axisTitleStyle;

  /// Colour of the grid ruled at each tick; null rules none.
  final Color? gridColor;

  /// Excursions marked with a vertical line — the stop in use, a target.
  final List<double> xReferenceLines;

  /// The colour of those lines.
  final Color referenceColor;

  /// Drawn round the dot under the pointer; null marks none.
  final BorderSide? hoverBorder;

  /// Called as a touch moves over the dots, and with null when it leaves.
  final ValueChanged<ExcursionTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched dot; null shows none.
  final Widget? Function(BuildContext context, ExcursionTouchDetails details)?
  tooltipBuilder;

  /// How far the card sits from the dot.
  final double tooltipMargin;

  /// How long the dots take to grow in; zero draws them at once.
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
  State<MaeMfeChart> createState() => _MaeMfeChartState();
}

class _MaeMfeChartState extends State<MaeMfeChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 64);
  List<ExcursionDot> _dots = const [];
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
  void didUpdateWidget(MaeMfeChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!listEquals(oldWidget.trades, widget.trades)) {
      if (_touched != null && _touched! >= widget.trades.length) {
        _touched = null;
      }
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

  void _handle(Offset local) {
    final index = excursionDotAt(
      _dots,
      local,
      reach: widget.dotRadius + 6,
    )?.index;
    if (index == _touched) return;
    setState(() => _touched = index);
    widget.onTouch?.call(
      index == null
          ? null
          : ExcursionTouchDetails(
              dot: _dots.firstWhere((d) => d.index == index),
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
    final range = excursionRange(widget.trades, widget.kind);
    final minX = widget.minX ?? range.minX;
    final maxX = widget.maxX ?? range.maxX;
    final minY = widget.minY ?? range.minY;
    final maxY = widget.maxY ?? range.maxY;

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
        _dots = layOutExcursions(
          widget.trades,
          plot,
          kind: widget.kind,
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
        );

        final touched = _touched;
        final dot = touched == null
            ? null
            : _dots.where((d) => d.index == touched).firstOrNull;
        final details = dot == null ? null : ExcursionTouchDetails(dot: dot);
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
                      painter: MaeMfeChartPainter(
                        chart: widget,
                        dots: _dots,
                        plot: plot,
                        minX: minX,
                        maxX: maxX,
                        minY: minY,
                        maxY: maxY,
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

/// Paints a [MaeMfeChart]: the grid, the axes, the limit line and the dots.
class MaeMfeChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [dots] inside [plot].
  MaeMfeChartPainter({
    required this.chart,
    required this.dots,
    required this.plot,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.touched,
    required this.animation,
    required this.textCache,
  });

  /// The chart being painted.
  final MaeMfeChart chart;

  /// Where each trade sits.
  final List<ExcursionDot> dots;

  /// The area the dots are drawn in.
  final Rect plot;

  /// The ranges of the two axes.
  final double minX, maxX, minY, maxY;

  /// The index of the trade under the pointer.
  final int? touched;

  /// How far the entry animation has got, from 0 to 1.
  final double animation;

  /// Where the labels are laid out.
  final TextPainterCache textCache;

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
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      tickCount: chart.tickCount,
      gridColor: chart.gridColor,
      showAxes: chart.showAxes,
      xFormatter: chart.xFormatter,
      yFormatter: chart.yFormatter,
      labelStyle: chart.axisLabelStyle,
      xTitle:
          chart.xAxisTitle ??
          (chart.kind == ExcursionKind.adverse
              ? 'Max adverse excursion'
              : 'Max favourable excursion'),
      yTitle: chart.yAxisTitle,
      titleStyle: chart.axisTitleStyle,
      axisWidth: chart.axisWidth,
      axisHeight: chart.axisHeight,
    );

    canvas
      ..save()
      ..clipRect(plot);
    _paintLines(canvas);
    canvas.restore();

    final t = animation.clamp(0.0, 1.0);
    final radius = chart.dotRadius * t;
    final alpha = chart.dotOpacity.clamp(0.0, 1.0);
    for (final dot in dots) {
      if (!dot.center.dx.isFinite || !dot.center.dy.isFinite) continue;
      final color =
          dot.trade.color ??
          (dot.trade.isWinner ? chart.winnerColor : chart.loserColor);
      canvas.drawCircle(
        dot.center,
        radius,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..isAntiAlias = true,
      );
    }

    final hover = chart.hoverBorder;
    final at = touched;
    if (at != null && hover != null && hover.width > 0) {
      for (final dot in dots) {
        if (dot.index != at) continue;
        canvas.drawCircle(
          dot.center,
          radius + hover.width + 1,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = hover.width
            ..color = hover.color
            ..isAntiAlias = true,
        );
      }
    }
  }

  void _paintLines(Canvas canvas) {
    if (chart.showZeroLine && minY < 0 && maxY > 0) {
      final y = mapAcross(0, minY, maxY, plot.bottom, plot.top);
      canvas.drawLine(
        Offset(plot.left, y),
        Offset(plot.right, y),
        Paint()
          ..color = const Color(0x66FFFFFF)
          ..strokeWidth = 1,
      );
    }

    if (chart.showLimit) {
      // No result beats its favourable excursion, and none loses more than its
      // adverse one: the dots all sit on one side of this line.
      final sign = chart.kind == ExcursionKind.adverse ? -1.0 : 1.0;
      canvas.drawLine(
        Offset(
          plot.left,
          mapAcross(sign * minX, minY, maxY, plot.bottom, plot.top),
        ),
        Offset(
          plot.right,
          mapAcross(sign * maxX, minY, maxY, plot.bottom, plot.top),
        ),
        Paint()
          ..color = chart.limitColor
          ..strokeWidth = 1,
      );
    }

    final pen = Paint()
      ..color = chart.referenceColor
      ..strokeWidth = 1;
    for (final value in chart.xReferenceLines) {
      if (!value.isFinite || value < minX || value > maxX) continue;
      final x = mapAcross(value, minX, maxX, plot.left, plot.right);
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), pen);
    }
  }

  @override
  bool shouldRepaint(MaeMfeChartPainter oldDelegate) =>
      !identical(oldDelegate.chart, chart) ||
      !identical(oldDelegate.dots, dots) ||
      oldDelegate.plot != plot ||
      oldDelegate.minX != minX ||
      oldDelegate.maxX != maxX ||
      oldDelegate.minY != minY ||
      oldDelegate.maxY != maxY ||
      oldDelegate.touched != touched ||
      oldDelegate.animation != animation;
}
