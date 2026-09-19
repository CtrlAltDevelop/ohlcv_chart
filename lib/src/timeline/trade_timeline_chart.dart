import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../corner_radius.dart';
import '../renderer/text_painter_cache.dart';
import '../series/series_axis.dart';
import '../trading.dart';

/// One trade on a [TradeTimelineChart]: when it was entered, when it was left,
/// and what it made.
@immutable
class TimelineTrade {
  /// Creates a trade entered at [entryTime].
  const TimelineTrade({
    required this.entryTime,
    this.exitTime,
    this.lane,
    this.side = TradeSide.buy,
    this.pnl,
    this.entryPrice,
    this.exitPrice,
    this.quantity,
    this.color,
    this.data,
  });

  /// When the trade was entered.
  final DateTime entryTime;

  /// When it was left; null while it is still open.
  final DateTime? exitTime;

  /// The row it is drawn in — usually the symbol; null puts every such trade
  /// in one unnamed lane.
  final String? lane;

  /// Long or short.
  final TradeSide side;

  /// What it made or lost, realised or not; null colours it as flat.
  final double? pnl;

  /// The price it was entered at, for the app's own tooltip.
  final double? entryPrice;

  /// The price it was left at.
  final double? exitPrice;

  /// How much was traded.
  final double? quantity;

  /// A colour of this trade's own, used instead of the profit or loss colour.
  final Color? color;

  /// Anything the app wants back when this trade is touched.
  final Object? data;

  /// Whether the trade is still open.
  bool get isOpen => exitTime == null;

  /// When the trade ends on the chart: its exit, or [now] while it is open.
  DateTime endAt(DateTime now) {
    final exit = exitTime ?? now;
    return exit.isBefore(entryTime) ? entryTime : exit;
  }
}

/// The span [trades] cover, from the first entry to the last exit.
///
/// An open trade runs to [now], which defaults to the latest time among the
/// trades. An empty list, or trades that all happen at one instant, give a
/// span a minute wide so there is always something to draw against.
({DateTime start, DateTime end}) tradeTimelineRange(
  List<TimelineTrade> trades, {
  DateTime? now,
}) {
  if (trades.isEmpty) {
    final at = now ?? DateTime.fromMillisecondsSinceEpoch(0);
    return (start: at, end: at.add(const Duration(minutes: 1)));
  }
  final clock = now ?? _latest(trades);
  var start = trades.first.entryTime;
  var end = trades.first.endAt(clock);
  for (final trade in trades) {
    if (trade.entryTime.isBefore(start)) start = trade.entryTime;
    final to = trade.endAt(clock);
    if (to.isAfter(end)) end = to;
  }
  if (!end.isAfter(start)) end = start.add(const Duration(minutes: 1));
  return (start: start, end: end);
}

DateTime _latest(List<TimelineTrade> trades) {
  var latest = trades.first.entryTime;
  for (final trade in trades) {
    if (trade.entryTime.isAfter(latest)) latest = trade.entryTime;
    final exit = trade.exitTime;
    if (exit != null && exit.isAfter(latest)) latest = exit;
  }
  return latest;
}

/// Puts each of [trades] in a row so that no two trades in a row overlap,
/// using as few rows as it can; returns each trade's row, in input order.
///
/// A trade that starts exactly as another ends shares its row.
List<int> packTradeRows(List<TimelineTrade> trades, {DateTime? now}) {
  if (trades.isEmpty) return const [];
  final clock = now ?? _latest(trades);
  final order = List<int>.generate(trades.length, (i) => i)
    ..sort((a, b) {
      final byEntry = trades[a].entryTime.compareTo(trades[b].entryTime);
      return byEntry != 0 ? byEntry : a.compareTo(b);
    });

  final rowEnds = <DateTime>[];
  final rows = List<int>.filled(trades.length, 0);
  for (final i in order) {
    final trade = trades[i];
    var row = rowEnds.indexWhere((end) => !end.isAfter(trade.entryTime));
    if (row < 0) {
      row = rowEnds.length;
      rowEnds.add(trade.endAt(clock));
    } else {
      rowEnds[row] = trade.endAt(clock);
    }
    rows[i] = row;
  }
  return rows;
}

/// How many of [trades] were open over time: a step each time one is entered
/// or left, in time order.
///
/// Each step gives the count from its time until the next step's.
List<({DateTime time, int count})> tradeTimelineExposure(
  List<TimelineTrade> trades, {
  DateTime? now,
}) {
  if (trades.isEmpty) return const [];
  final clock = now ?? _latest(trades);
  final events =
      <({DateTime time, int change})>[
        for (final trade in trades) ...[
          (time: trade.entryTime, change: 1),
          (time: trade.endAt(clock), change: -1),
        ],
      ]..sort((a, b) {
        final byTime = a.time.compareTo(b.time);
        // Leaving before entering at one instant keeps back-to-back trades
        // from counting twice.
        return byTime != 0 ? byTime : a.change.compareTo(b.change);
      });

  final steps = <({DateTime time, int count})>[];
  var count = 0;
  for (final event in events) {
    count += event.change;
    if (steps.isNotEmpty && steps.last.time == event.time) {
      steps[steps.length - 1] = (time: event.time, count: count);
    } else {
      steps.add((time: event.time, count: count));
    }
  }
  return steps;
}

/// One lane of a [TradeTimelineLayout].
@immutable
class TradeTimelineLane {
  /// Creates the lane at [index].
  const TradeTimelineLane({
    required this.label,
    required this.index,
    required this.rect,
    required this.rowCount,
  });

  /// What it is called; null for the unnamed lane.
  final String? label;

  /// Its position from the top.
  final int index;

  /// The area it takes.
  final Rect rect;

  /// How many rows its overlapping trades needed.
  final int rowCount;
}

/// Where one [TimelineTrade] was laid out.
@immutable
class TradeTimelineBar {
  /// Creates the bar of [trade].
  const TradeTimelineBar({
    required this.trade,
    required this.index,
    required this.lane,
    required this.row,
    required this.rect,
  });

  /// The trade it draws.
  final TimelineTrade trade;

  /// Its position in the list of trades.
  final int index;

  /// The lane it is in.
  final int lane;

  /// The row within that lane.
  final int row;

  /// The bar itself.
  final Rect rect;

  /// Whether [local] falls on the bar, counting a very thin bar as a few
  /// pixels wide so it can still be touched.
  bool contains(Offset local, {double minTouchWidth = 8}) {
    final grow = math.max(0.0, (minTouchWidth - rect.width) / 2);
    return Rect.fromLTRB(
      rect.left - grow,
      rect.top,
      rect.right + grow,
      rect.bottom,
    ).contains(local);
  }
}

/// Where a trade timeline was laid out.
@immutable
class TradeTimelineLayout {
  /// Creates a layout spanning [start] to [end] across [bounds].
  const TradeTimelineLayout({
    required this.bounds,
    required this.start,
    required this.end,
    required this.lanes,
    required this.bars,
  });

  /// The area the lanes fill.
  final Rect bounds;

  /// The time at the left edge.
  final DateTime start;

  /// The time at the right edge.
  final DateTime end;

  /// The lanes, top to bottom.
  final List<TradeTimelineLane> lanes;

  /// A bar per trade that falls inside the span, in input order.
  final List<TradeTimelineBar> bars;

  /// Whether nothing was laid out.
  bool get isEmpty => bars.isEmpty;

  /// Where [time] sits across the bounds.
  double xOf(DateTime time) {
    final span = end.difference(start).inMicroseconds;
    if (span <= 0) return bounds.left;
    return bounds.left +
        time.difference(start).inMicroseconds / span * bounds.width;
  }

  /// The time at [dx].
  DateTime timeAt(double dx) {
    if (bounds.width <= 0) return start;
    final span = end.difference(start).inMicroseconds;
    return start.add(
      Duration(
        microseconds: ((dx - bounds.left) / bounds.width * span).round(),
      ),
    );
  }

  /// The bar at [local], or null when there is none; later trades win where
  /// thin bars overlap.
  TradeTimelineBar? barAt(Offset local) {
    for (final bar in bars.reversed) {
      if (bar.contains(local)) return bar;
    }
    return null;
  }
}

/// Lays [trades] out in [bounds]: a lane per distinct [TimelineTrade.lane], in
/// the order lanes first appear, each with as many rows as its overlapping
/// trades need.
///
/// [start] and [end] default to [tradeTimelineRange]; open trades run to [now].
/// Rows are at most [maxRowHeight] tall, and a bar is never drawn narrower
/// than [minBarWidth]. Trades wholly outside the span are left out; the rest
/// are cut to it.
TradeTimelineLayout layOutTradeTimeline(
  List<TimelineTrade> trades,
  Rect bounds, {
  DateTime? start,
  DateTime? end,
  DateTime? now,
  double laneGap = 6,
  double rowGap = 2,
  double maxRowHeight = 22,
  double minBarWidth = 2,
}) {
  final range = tradeTimelineRange(trades, now: now);
  final from = start ?? range.start;
  var to = end ?? range.end;
  if (!to.isAfter(from)) to = from.add(const Duration(minutes: 1));

  TradeTimelineLayout emptyLayout() => TradeTimelineLayout(
    bounds: bounds,
    start: from,
    end: to,
    lanes: const [],
    bars: const [],
  );
  if (trades.isEmpty || bounds.width <= 0 || bounds.height <= 0) {
    return emptyLayout();
  }

  final clock = now ?? _latest(trades);
  final laneKeys = <String?>[];
  final laneOf = List<int>.filled(trades.length, 0);
  for (var i = 0; i < trades.length; i++) {
    var lane = laneKeys.indexOf(trades[i].lane);
    if (lane < 0) {
      lane = laneKeys.length;
      laneKeys.add(trades[i].lane);
    }
    laneOf[i] = lane;
  }

  final rowOf = List<int>.filled(trades.length, 0);
  final rowCounts = List<int>.filled(laneKeys.length, 0);
  for (var lane = 0; lane < laneKeys.length; lane++) {
    final members = [
      for (var i = 0; i < trades.length; i++)
        if (laneOf[i] == lane) i,
    ];
    final rows = packTradeRows([
      for (final i in members) trades[i],
    ], now: clock);
    for (var k = 0; k < members.length; k++) {
      rowOf[members[k]] = rows[k];
      rowCounts[lane] = math.max(rowCounts[lane], rows[k] + 1);
    }
  }

  final totalRows = rowCounts.fold(0, (sum, count) => sum + count);
  final gaps =
      math.max(0.0, laneGap) * (laneKeys.length - 1) +
      math.max(0.0, rowGap) * (totalRows - laneKeys.length);
  final rowHeight = math
      .min(maxRowHeight, (bounds.height - gaps) / totalRows)
      .toDouble();
  if (rowHeight <= 0) return emptyLayout();

  final lanes = <TradeTimelineLane>[];
  var top = bounds.top;
  for (var lane = 0; lane < laneKeys.length; lane++) {
    final rows = rowCounts[lane];
    final height = rows * rowHeight + (rows - 1) * math.max(0.0, rowGap);
    lanes.add(
      TradeTimelineLane(
        label: laneKeys[lane],
        index: lane,
        rect: Rect.fromLTWH(bounds.left, top, bounds.width, height),
        rowCount: rows,
      ),
    );
    top += height + math.max(0.0, laneGap);
  }

  final layout = TradeTimelineLayout(
    bounds: bounds,
    start: from,
    end: to,
    lanes: lanes,
    bars: const [],
  );

  final bars = <TradeTimelineBar>[];
  for (var i = 0; i < trades.length; i++) {
    final trade = trades[i];
    final exit = trade.endAt(clock);
    if (exit.isBefore(from) || trade.entryTime.isAfter(to)) continue;

    final left = math.max(bounds.left, layout.xOf(trade.entryTime));
    var right = math.min(bounds.right, layout.xOf(exit));
    if (right - left < minBarWidth) {
      right = math.min(bounds.right, left + minBarWidth);
    }
    final laneTop = lanes[laneOf[i]].rect.top;
    final rowTop = laneTop + rowOf[i] * (rowHeight + math.max(0.0, rowGap));
    bars.add(
      TradeTimelineBar(
        trade: trade,
        index: i,
        lane: laneOf[i],
        row: rowOf[i],
        rect: Rect.fromLTRB(left, rowTop, right, rowTop + rowHeight),
      ),
    );
  }

  return TradeTimelineLayout(
    bounds: bounds,
    start: from,
    end: to,
    lanes: lanes,
    bars: bars,
  );
}

/// What a touch on a [TradeTimelineChart] landed on.
@immutable
class TradeTimelineTouchDetails {
  /// Creates the details of a touch on [bar] at [time].
  const TradeTimelineTouchDetails({required this.bar, required this.time});

  /// The bar touched.
  final TradeTimelineBar bar;

  /// The time under the pointer.
  final DateTime time;

  /// The trade it draws.
  TimelineTrade get trade => bar.trade;
}

/// When an account was in the market: each trade a bar from entry to exit,
/// coloured by what it made, a lane per symbol.
///
/// ```dart
/// TradeTimelineChart(
///   trades: [
///     TimelineTrade(
///       lane: 'BTCUSDT',
///       entryTime: DateTime(2026, 9, 1, 9, 30),
///       exitTime: DateTime(2026, 9, 1, 14),
///       side: TradeSide.buy,
///       pnl: 412.5,
///     ),
///   ],
/// );
/// ```
///
/// The chart fills the box it is given, and is [defaultHeight] high in a box
/// with no height of its own.
class TradeTimelineChart extends StatefulWidget {
  /// Creates a timeline of [trades].
  const TradeTimelineChart({
    super.key,
    required this.trades,
    this.start,
    this.end,
    this.now,
    this.laneGap = 6,
    this.rowGap = 2,
    this.maxRowHeight = 22,
    this.minBarWidth = 2,
    this.barRadius = const BorderRadius.all(Radius.circular(3)),
    this.profitColor = const Color(0xFF2F9E44),
    this.lossColor = const Color(0xFFE03131),
    this.flatColor = const Color(0xFF868E96),
    this.shadeByPnl = true,
    this.showSideMarkers = true,
    this.markerColor = const Color(0xCCFFFFFF),
    this.showPnl = true,
    this.pnlFormatter,
    this.pnlStyle,
    this.showLaneLabels = true,
    this.laneLabelWidth = 72,
    this.laneLabelStyle,
    this.laneBandColor = const Color(0x0AFFFFFF),
    this.showExposure = true,
    this.exposureHeight = 22,
    this.exposureColor = const Color(0xFF4C86CD),
    this.showTimeAxis = true,
    this.timeAxisHeight = 16,
    this.timeFormatter,
    this.axisLabelStyle,
    this.gridColor = const Color(0x22FFFFFF),
    this.nowColor = const Color(0x99F59F00),
    this.crosshairColor = const Color(0x66FFFFFF),
    this.onTouch,
    this.tooltipBuilder,
    this.tooltipMargin = 8,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.defaultHeight = 240,
    this.semanticLabel,
  });

  /// The trades to draw, in any order.
  final List<TimelineTrade> trades;

  /// The time at the left edge; null starts at the first entry.
  final DateTime? start;

  /// The time at the right edge; null ends at the last exit.
  final DateTime? end;

  /// The time open trades run to; null uses the latest time among the trades.
  final DateTime? now;

  /// The gap between lanes.
  final double laneGap;

  /// The gap between rows inside a lane.
  final double rowGap;

  /// The tallest a row is drawn.
  final double maxRowHeight;

  /// The narrowest a bar is drawn, so a quick trade still shows.
  final double minBarWidth;

  /// The rounding of each bar's corners, as drawn on the screen. A bar runs
  /// left to right, and an open trade has not ended, so its right-hand
  /// corners are left square whatever this says.
  final BorderRadius barRadius;

  /// The colour of a trade that made money.
  final Color profitColor;

  /// The colour of one that lost it.
  final Color lossColor;

  /// The colour of one that made nothing, or whose result is not known.
  final Color flatColor;

  /// Whether bigger wins and losses are drawn stronger than small ones.
  final bool shadeByPnl;

  /// Whether a small arrow at the entry shows long or short.
  final bool showSideMarkers;

  /// The colour of that arrow.
  final Color markerColor;

  /// Whether the result is written inside bars wide enough to hold it.
  final bool showPnl;

  /// Writes a result; null writes it to two places with a sign.
  final String Function(double pnl)? pnlFormatter;

  /// Style of the result text.
  final TextStyle? pnlStyle;

  /// Whether lane names are written down the left, when any trade has one.
  final bool showLaneLabels;

  /// How much room the lane names take.
  final double laneLabelWidth;

  /// Style of a lane name.
  final TextStyle? laneLabelStyle;

  /// Colour of the band behind every other lane; null draws none.
  final Color? laneBandColor;

  /// Whether a strip under the lanes shows how many trades were open.
  final bool showExposure;

  /// How tall that strip is.
  final double exposureHeight;

  /// Its colour.
  final Color exposureColor;

  /// Whether times are written along the bottom.
  final bool showTimeAxis;

  /// How much room the time axis takes.
  final double timeAxisHeight;

  /// Writes a time; null picks hours, days or months to suit the span.
  final String Function(DateTime time)? timeFormatter;

  /// Style of an axis label.
  final TextStyle? axisLabelStyle;

  /// Colour of the lines ruled at each time; null rules none.
  final Color? gridColor;

  /// Colour of the line drawn at [now], when it is inside the span; null draws
  /// none.
  final Color? nowColor;

  /// Colour of the line following the pointer; null draws none.
  final Color? crosshairColor;

  /// Called as a touch moves over a trade, and with null when it leaves one.
  final ValueChanged<TradeTimelineTouchDetails?>? onTouch;

  /// Builds a card shown by the touched trade; null shows none.
  final Widget? Function(
    BuildContext context,
    TradeTimelineTouchDetails details,
  )?
  tooltipBuilder;

  /// How far the card sits from the bar.
  final double tooltipMargin;

  /// How long the bars take to draw in; zero draws them at once.
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
  State<TradeTimelineChart> createState() => _TradeTimelineChartState();
}

class _TradeTimelineChartState extends State<TradeTimelineChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 128);
  TradeTimelineLayout? _layout;
  Offset? _pointer;
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
  void didUpdateWidget(TradeTimelineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!identical(oldWidget.trades, widget.trades)) {
      _touched = null;
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
    final layout = _layout;
    if (layout == null) return;
    final bar = layout.barAt(local);
    final index = bar?.index;
    final changed = index != _touched;
    setState(() {
      _pointer = local;
      _touched = index;
    });
    if (changed || bar != null) {
      widget.onTouch?.call(
        bar == null
            ? null
            : TradeTimelineTouchDetails(
                bar: bar,
                time: layout.timeAt(local.dx),
              ),
      );
    }
  }

  void _leave() {
    final had = _touched != null;
    setState(() {
      _pointer = null;
      _touched = null;
    });
    if (had) widget.onTouch?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.animationCurve.transform(_animation.value);
    final named =
        widget.showLaneLabels &&
        widget.trades.any((trade) => trade.lane != null);

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
        final below =
            (widget.showTimeAxis ? widget.timeAxisHeight : 0) +
            (widget.showExposure ? widget.exposureHeight + 4 : 0);
        final plot = Rect.fromLTRB(
          box.left + (named ? widget.laneLabelWidth : 0),
          box.top,
          math.max(box.left, box.right),
          math.max(box.top, box.bottom - below),
        );
        final layout = _layout = layOutTradeTimeline(
          widget.trades,
          plot,
          start: widget.start,
          end: widget.end,
          now: widget.now,
          laneGap: widget.laneGap,
          rowGap: widget.rowGap,
          maxRowHeight: widget.maxRowHeight,
          minBarWidth: widget.minBarWidth,
        );

        final touched = _touched;
        TradeTimelineBar? bar;
        if (touched != null) {
          for (final candidate in layout.bars) {
            if (candidate.index == touched) bar = candidate;
          }
        }
        final pointer = _pointer;
        final builder = widget.tooltipBuilder;
        final tooltip = bar == null || builder == null
            ? null
            : builder(
                context,
                TradeTimelineTouchDetails(
                  bar: bar,
                  time: layout.timeAt(pointer?.dx ?? bar.rect.left),
                ),
              );

        return SizedBox(
          width: width,
          height: height,
          child: MouseRegion(
            onHover: (e) => _handle(e.localPosition),
            onExit: (_) => _leave(),
            // Raw pointer events so the crosshair follows a drag at once.
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e) => _handle(e.localPosition),
              onPointerMove: (e) => _handle(e.localPosition),
              onPointerUp: (_) => _leave(),
              onPointerCancel: (_) => _leave(),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: TradeTimelineChartPainter(
                        chart: widget,
                        layout: layout,
                        labelLeft: box.left,
                        exposureTop: plot.bottom + 4,
                        touched: touched,
                        pointerX: pointer?.dx,
                        animation: t,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (tooltip != null && bar != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomSingleChildLayout(
                          delegate: _TimelineTooltipLayout(
                            anchor: bar.rect,
                            pointerX: pointer?.dx ?? bar.rect.center.dx,
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

/// Puts the tooltip above the touched bar, beside the pointer, kept inside the
/// chart; below the bar when there is no room above.
class _TimelineTooltipLayout extends SingleChildLayoutDelegate {
  _TimelineTooltipLayout({
    required this.anchor,
    required this.pointerX,
    required this.margin,
  });

  final Rect anchor;
  final double pointerX;
  final double margin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var top = anchor.top - margin - childSize.height;
    if (top < 0) top = anchor.bottom + margin;
    return Offset(
      (pointerX - childSize.width / 2).clamp(
        0.0,
        math.max(0.0, size.width - childSize.width),
      ),
      top.clamp(0.0, math.max(0.0, size.height - childSize.height)),
    );
  }

  @override
  bool shouldRelayout(_TimelineTooltipLayout oldDelegate) =>
      oldDelegate.anchor != anchor ||
      oldDelegate.pointerX != pointerX ||
      oldDelegate.margin != margin;
}

/// Paints a [TradeTimelineChart]: the lanes, the trades, the exposure strip
/// and the time axis.
class TradeTimelineChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [layout].
  TradeTimelineChartPainter({
    required this.chart,
    required this.layout,
    required this.labelLeft,
    required this.exposureTop,
    required this.touched,
    required this.pointerX,
    required this.animation,
    required this.textCache,
  });

  final TradeTimelineChart chart;
  final TradeTimelineLayout layout;
  final double labelLeft;
  final double exposureTop;
  final int? touched;
  final double? pointerX;
  final double animation;
  final TextPainterCache textCache;

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    final bounds = layout.bounds;
    if (bounds.width <= 0) return;

    final ticks = _ticks();
    _paintGrid(canvas, ticks);
    _paintLanes(canvas);
    _paintBars(canvas);
    if (chart.showExposure) _paintExposure(canvas);
    _paintTimeAxis(canvas, ticks);
    _paintNow(canvas);
    _paintCrosshair(canvas);
  }

  double get _bottom => chart.showExposure
      ? exposureTop + chart.exposureHeight
      : layout.bounds.bottom;

  List<DateTime> _ticks() {
    final count = math.max(2, (layout.bounds.width / 110).floor() + 1);
    final span = layout.end.difference(layout.start).inMicroseconds;
    return [
      for (var i = 0; i < count; i++)
        layout.start.add(
          Duration(microseconds: (span * i / (count - 1)).round()),
        ),
    ];
  }

  void _paintGrid(Canvas canvas, List<DateTime> ticks) {
    final grid = chart.gridColor;
    if (grid == null) return;
    final paint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final tick in ticks) {
      final x = layout.xOf(tick);
      canvas.drawLine(Offset(x, layout.bounds.top), Offset(x, _bottom), paint);
    }
  }

  void _paintLanes(Canvas canvas) {
    final band = chart.laneBandColor;
    final named =
        chart.showLaneLabels && layout.lanes.any((lane) => lane.label != null);
    final style = seriesAxisLabelStyle.merge(chart.laneLabelStyle);
    for (final lane in layout.lanes) {
      if (band != null && lane.index.isOdd) {
        canvas.drawRect(
          Rect.fromLTRB(
            named ? labelLeft : lane.rect.left,
            lane.rect.top - chart.laneGap / 2,
            lane.rect.right,
            lane.rect.bottom + chart.laneGap / 2,
          ),
          Paint()..color = band,
        );
      }
      final label = lane.label;
      if (!named || label == null) continue;
      final tp = textCache.get(label, style);
      canvas
        ..save()
        ..clipRect(
          Rect.fromLTRB(
            labelLeft,
            lane.rect.top - chart.laneGap / 2,
            lane.rect.left - 6,
            lane.rect.bottom + chart.laneGap / 2,
          ),
        );
      tp.paint(canvas, Offset(labelLeft, lane.rect.center.dy - tp.height / 2));
      canvas.restore();
    }
  }

  Color _colorOf(TimelineTrade trade, double largest) {
    final own = trade.color;
    if (own != null) return own;
    final pnl = trade.pnl;
    if (pnl == null || !pnl.isFinite || pnl == 0) return chart.flatColor;
    final base = pnl > 0 ? chart.profitColor : chart.lossColor;
    if (!chart.shadeByPnl || largest <= 0) return base;
    final strength = 0.4 + 0.6 * (pnl.abs() / largest).clamp(0.0, 1.0);
    return base.withValues(alpha: base.a * strength);
  }

  void _paintBars(Canvas canvas) {
    var largest = 0.0;
    for (final bar in layout.bars) {
      final pnl = bar.trade.pnl;
      if (pnl != null && pnl.isFinite) largest = math.max(largest, pnl.abs());
    }

    final t = animation.clamp(0.0, 1.0);
    final fill = Paint()..isAntiAlias = true;
    final pnlStyle = seriesAxisLabelStyle
        .copyWith(color: const Color(0xFFFFFFFF))
        .merge(chart.pnlStyle);

    for (final bar in layout.bars) {
      final rect = Rect.fromLTWH(
        bar.rect.left,
        bar.rect.top,
        math.max(
          chart.minBarWidth.clamp(0.0, bar.rect.width),
          bar.rect.width * t,
        ),
        bar.rect.height,
      );
      final open = bar.trade.isOpen;
      // An open trade has not ended, so its right edge is left square.
      final corners = open
          ? chart.barRadius.copyWith(
              topRight: Radius.zero,
              bottomRight: Radius.zero,
            )
          : chart.barRadius;
      fill.color = _colorOf(bar.trade, largest);
      canvas.drawRRect(roundedBox(rect, corners), fill);

      if (bar.index == touched) {
        canvas.drawRRect(
          roundedBox(rect.inflate(1), corners),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xDDFFFFFF)
            ..isAntiAlias = true,
        );
      }
      if (t < 1) continue;

      if (open && rect.width >= 6) {
        // A notch at the right edge: still running.
        final mid = rect.center.dy;
        final h = rect.height / 2;
        canvas.drawPath(
          Path()
            ..moveTo(rect.right, rect.top)
            ..lineTo(rect.right + math.min(6, h), mid)
            ..lineTo(rect.right, rect.bottom)
            ..close(),
          fill,
        );
      }

      var textLeft = rect.left + 4;
      if (chart.showSideMarkers && rect.width >= 12 && rect.height >= 8) {
        final size = math.min(4.0, rect.height / 3);
        final cx = rect.left + 4 + size;
        final cy = rect.center.dy;
        final up = bar.trade.side == TradeSide.buy;
        canvas.drawPath(
          Path()
            ..moveTo(cx, up ? cy - size : cy + size)
            ..lineTo(cx - size, up ? cy + size : cy - size)
            ..lineTo(cx + size, up ? cy + size : cy - size)
            ..close(),
          Paint()
            ..color = chart.markerColor
            ..isAntiAlias = true,
        );
        textLeft = cx + size + 4;
      }

      final pnl = bar.trade.pnl;
      if (!chart.showPnl || pnl == null || !pnl.isFinite) continue;
      final tp = textCache.get(_formatPnl(pnl), pnlStyle);
      if (textLeft + tp.width + 4 > rect.right || tp.height > rect.height) {
        continue;
      }
      tp.paint(canvas, Offset(textLeft, rect.center.dy - tp.height / 2));
    }
  }

  void _paintExposure(Canvas canvas) {
    final strip = Rect.fromLTRB(
      layout.bounds.left,
      exposureTop,
      layout.bounds.right,
      exposureTop + chart.exposureHeight,
    );
    if (strip.height <= 0) return;
    final steps = tradeTimelineExposure(chart.trades, now: chart.now);
    var peak = 0;
    for (final step in steps) {
      peak = math.max(peak, step.count);
    }
    canvas.drawLine(
      strip.bottomLeft,
      strip.bottomRight,
      Paint()
        ..color = chart.exposureColor.withValues(alpha: 0.4)
        ..strokeWidth = 1,
    );
    if (peak == 0) return;

    final path = Path()..moveTo(strip.left, strip.bottom);
    var y = strip.bottom;
    for (final step in steps) {
      final x = layout.xOf(step.time).clamp(strip.left, strip.right);
      path
        ..lineTo(x, y)
        ..lineTo(x, y = strip.bottom - step.count / peak * strip.height);
    }
    path
      ..lineTo(strip.right, y)
      ..lineTo(strip.right, strip.bottom)
      ..close();

    canvas
      ..save()
      ..clipRect(strip)
      ..drawPath(
        path,
        Paint()..color = chart.exposureColor.withValues(alpha: 0.35),
      )
      ..restore();

    final tp = textCache.get(
      'max $peak',
      seriesAxisLabelStyle.merge(chart.axisLabelStyle),
    );
    if (labelLeft + tp.width < strip.left - 6) {
      tp.paint(canvas, Offset(labelLeft, strip.center.dy - tp.height / 2));
    }
  }

  void _paintTimeAxis(Canvas canvas, List<DateTime> ticks) {
    if (!chart.showTimeAxis) return;
    final style = seriesAxisLabelStyle.merge(chart.axisLabelStyle);
    final span = layout.end.difference(layout.start);
    var written = -double.infinity;
    for (final tick in ticks) {
      final tp = textCache.get(_formatTime(tick, span), style);
      final left = (layout.xOf(tick) - tp.width / 2).clamp(
        layout.bounds.left,
        math.max(layout.bounds.left, layout.bounds.right - tp.width),
      );
      if (left < written) continue;
      tp.paint(canvas, Offset(left.toDouble(), _bottom + 3));
      written = left + tp.width + 8;
    }
  }

  void _paintNow(Canvas canvas) {
    final color = chart.nowColor;
    final now = chart.now;
    if (color == null || now == null) return;
    if (now.isBefore(layout.start) || now.isAfter(layout.end)) return;
    final x = layout.xOf(now);
    canvas.drawLine(
      Offset(x, layout.bounds.top),
      Offset(x, _bottom),
      Paint()
        ..color = color
        ..strokeWidth = 1,
    );
  }

  void _paintCrosshair(Canvas canvas) {
    final color = chart.crosshairColor;
    final x = pointerX;
    if (color == null || x == null) return;
    if (x < layout.bounds.left || x > layout.bounds.right) return;
    canvas.drawLine(
      Offset(x, layout.bounds.top),
      Offset(x, _bottom),
      Paint()
        ..color = color
        ..strokeWidth = 1,
    );
  }

  String _formatPnl(double pnl) {
    final format = chart.pnlFormatter;
    if (format != null) return format(pnl);
    return '${pnl > 0 ? '+' : ''}${pnl.toStringAsFixed(2)}';
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatTime(DateTime time, Duration span) {
    final format = chart.timeFormatter;
    if (format != null) return format(time);
    String two(int n) => n.toString().padLeft(2, '0');
    final month = _months[time.month - 1];
    if (span <= const Duration(days: 1)) {
      return '${two(time.hour)}:${two(time.minute)}';
    }
    if (span <= const Duration(days: 4)) {
      return '${time.day} $month ${two(time.hour)}:${two(time.minute)}';
    }
    if (span <= const Duration(days: 180)) return '${time.day} $month';
    return '$month ${time.year}';
  }

  @override
  bool shouldRepaint(TradeTimelineChartPainter oldDelegate) =>
      !identical(oldDelegate.chart, chart) ||
      !identical(oldDelegate.layout, layout) ||
      oldDelegate.touched != touched ||
      oldDelegate.pointerX != pointerX ||
      oldDelegate.animation != animation;
}
