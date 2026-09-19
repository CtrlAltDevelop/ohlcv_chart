import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../entity/k_line_entity.dart';
import '../renderer/text_painter_cache.dart';
import '../series/series_axis.dart';

/// One price level of a market profile, and the periods that traded in it.
@immutable
class MarketProfileRow {
  /// Creates the level from [from] up to [to].
  const MarketProfileRow({
    required this.from,
    required this.to,
    required this.periods,
  });

  /// The bottom of the level.
  final double from;

  /// The top of it.
  final double to;

  /// Which periods touched it, in time order — the TPOs.
  final List<int> periods;

  /// The middle of the level.
  double get price => (from + to) / 2;

  /// How many periods touched it.
  int get count => periods.length;
}

/// Price levels, the level most traded, and the range around it where most of
/// the session happened.
@immutable
class MarketProfile {
  /// Creates a profile.
  const MarketProfile({
    required this.rows,
    required this.tickSize,
    required this.pointOfControl,
    required this.valueAreaLow,
    required this.valueAreaHigh,
    required this.periodCount,
  });

  /// An empty profile.
  static const MarketProfile empty = MarketProfile(
    rows: [],
    tickSize: 0,
    pointOfControl: 0,
    valueAreaLow: 0,
    valueAreaHigh: 0,
    periodCount: 0,
  );

  /// The levels, lowest first.
  final List<MarketProfileRow> rows;

  /// How tall one level is, in price.
  final double tickSize;

  /// The price of the level most periods touched.
  final double pointOfControl;

  /// The bottom of the value area.
  final double valueAreaLow;

  /// The top of it.
  final double valueAreaHigh;

  /// How many periods went into the profile.
  final int periodCount;

  /// Whether nothing was measured.
  bool get isEmpty => rows.isEmpty;

  /// The most periods any one level saw.
  int get busiest {
    var most = 0;
    for (final row in rows) {
      most = math.max(most, row.count);
    }
    return most;
  }

  /// Whether [price] is inside the value area.
  bool inValueArea(double price) =>
      price >= valueAreaLow && price <= valueAreaHigh;
}

/// Builds a market profile from [candles], one period per candle.
///
/// Every level a candle's range covers is credited to that candle, so the
/// profile counts *time at price* rather than volume. Levels are [tickSize]
/// apart, or the range split into [rowCount] when that is given instead. The
/// value area grows out from the busiest level until it holds
/// [valueAreaFraction] of all the periods counted, the usual 70%.
MarketProfile buildMarketProfile(
  List<KLineEntity> candles, {
  double? tickSize,
  int? rowCount,
  double valueAreaFraction = 0.7,
}) {
  var low = double.infinity;
  var high = double.negativeInfinity;
  for (final candle in candles) {
    final l = candle.low;
    final h = candle.high;
    if (!l.isFinite || !h.isFinite) continue;
    low = math.min(low, l);
    high = math.max(high, h);
  }
  if (!low.isFinite || !high.isFinite) return MarketProfile.empty;
  if (high == low) high = low + (tickSize ?? 1);

  final rows = math.max(1, rowCount ?? ((high - low) / (tickSize ?? 1)).ceil());
  final tick = tickSize != null && rowCount == null
      ? tickSize
      : (high - low) / rows;
  if (tick <= 0 || rows > 4000) return MarketProfile.empty;

  final periods = List.generate(rows, (_) => <int>[]);
  for (var i = 0; i < candles.length; i++) {
    final candle = candles[i];
    if (!candle.low.isFinite || !candle.high.isFinite) continue;
    final first = ((candle.low - low) / tick).floor().clamp(0, rows - 1);
    final last = ((candle.high - low) / tick).ceil().clamp(1, rows);
    for (var row = first; row < last; row++) {
      periods[row].add(i);
    }
  }

  final levels = [
    for (var i = 0; i < rows; i++)
      MarketProfileRow(
        from: low + i * tick,
        to: low + (i + 1) * tick,
        periods: periods[i],
      ),
  ];

  var poc = 0;
  var total = 0;
  for (var i = 0; i < levels.length; i++) {
    total += levels[i].count;
    if (levels[i].count > levels[poc].count) poc = i;
  }
  if (total == 0) {
    return MarketProfile(
      rows: levels,
      tickSize: tick,
      pointOfControl: levels[poc].price,
      valueAreaLow: levels.first.from,
      valueAreaHigh: levels.last.to,
      periodCount: candles.length,
    );
  }

  // The value area grows out from the busiest level, always taking whichever
  // neighbour is busier, until it holds enough of the periods.
  final want = total * valueAreaFraction.clamp(0.0, 1.0);
  var lowIndex = poc;
  var highIndex = poc;
  var held = levels[poc].count;
  while (held < want && (lowIndex > 0 || highIndex < levels.length - 1)) {
    final below = lowIndex > 0 ? levels[lowIndex - 1].count : -1;
    final above = highIndex < levels.length - 1
        ? levels[highIndex + 1].count
        : -1;
    if (above >= below) {
      highIndex++;
      held += above;
    } else {
      lowIndex--;
      held += below;
    }
  }

  return MarketProfile(
    rows: levels,
    tickSize: tick,
    pointOfControl: levels[poc].price,
    valueAreaLow: levels[lowIndex].from,
    valueAreaHigh: levels[highIndex].to,
    periodCount: candles.length,
  );
}

/// Where one [MarketProfileRow] was laid out.
@immutable
class MarketProfileBar {
  /// Creates the bar of [row].
  const MarketProfileBar({
    required this.row,
    required this.index,
    required this.rect,
    required this.band,
    required this.blockWidth,
  });

  /// The level this bar draws.
  final MarketProfileRow row;

  /// Its position from the bottom of the profile.
  final int index;

  /// The bar itself, as wide as the level was busy.
  final Rect rect;

  /// The whole row across the chart; what a touch is tested against.
  final Rect band;

  /// How wide one period's block is.
  final double blockWidth;

  /// Whether [local] is in this row.
  bool contains(Offset local) => band.contains(local);
}

/// Lays [profile] out across [bounds], one bar per level, growing right.
List<MarketProfileBar> layOutMarketProfile(
  MarketProfile profile,
  Rect bounds, {
  double rowSpacing = 1,
  double? blockWidth,
}) {
  if (profile.isEmpty || bounds.width <= 0 || bounds.height <= 0) {
    return const [];
  }

  final height = bounds.height / profile.rows.length;
  final busiest = profile.busiest;
  final block =
      blockWidth ?? (busiest <= 0 ? bounds.width : bounds.width / busiest);
  final spacing = math.min(math.max(0.0, rowSpacing), height);

  return [
    for (var i = 0; i < profile.rows.length; i++)
      () {
        final row = profile.rows[i];
        // Row 0 is the lowest price, so it is drawn at the bottom.
        final top = bounds.bottom - (i + 1) * height;
        return MarketProfileBar(
          row: row,
          index: i,
          blockWidth: block,
          band: Rect.fromLTWH(bounds.left, top, bounds.width, height),
          rect: Rect.fromLTWH(
            bounds.left,
            top,
            math.min(bounds.width, block * row.count),
            math.max(0.0, height - spacing),
          ),
        );
      }(),
  ];
}

/// The row under [local], or null when there is none.
MarketProfileBar? marketProfileBarAt(
  List<MarketProfileBar> bars,
  Offset local,
) {
  for (final bar in bars) {
    if (bar.contains(local)) return bar;
  }
  return null;
}

/// What a touch on a [MarketProfileChart] landed on.
@immutable
class MarketProfileTouchDetails {
  /// Creates the details of a touch on [bar].
  const MarketProfileTouchDetails({required this.bar});

  /// The row touched.
  final MarketProfileBar bar;

  /// The level it draws.
  MarketProfileRow get row => bar.row;
}

/// The letters periods are written by, in order.
const String defaultTpoLetters =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

/// How long the market spent at each price — a market profile, or TPO chart.
///
/// Every candle is one period, and each price level it covered is credited to
/// it. The busiest level is the point of control, and the range holding most of
/// the session is the value area.
///
/// ```dart
/// MarketProfileChart(
///   profile: buildMarketProfile(candles, rowCount: 40),
/// );
/// ```
///
/// The chart fills the box it is given, and is [defaultHeight] high in a box
/// with no height of its own.
class MarketProfileChart extends StatefulWidget {
  /// Creates a chart of [profile].
  const MarketProfileChart({
    super.key,
    required this.profile,
    this.blockColor = const Color(0xFF4C86CD),
    this.valueAreaColor = const Color(0xFF7950F2),
    this.pointOfControlColor = const Color(0xFFF59F00),
    this.showLetters = true,
    this.letters = defaultTpoLetters,
    this.letterStyle,
    this.rowSpacing = 1,
    this.blockWidth,
    this.showPriceAxis = true,
    this.axisWidth = 56,
    this.priceLabelEvery = 5,
    this.priceFormatter,
    this.axisLabelStyle,
    this.hoverColor = const Color(0x14FFFFFF),
    this.onTouch,
    this.tooltipBuilder,
    this.tooltipMargin = 10,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.defaultHeight = 320,
    this.semanticLabel,
  });

  /// The profile to draw, from [buildMarketProfile] or built by hand.
  final MarketProfile profile;

  /// The colour of a block outside the value area.
  final Color blockColor;

  /// The colour of a block inside it.
  final Color valueAreaColor;

  /// The colour of the line at the point of control.
  final Color pointOfControlColor;

  /// Whether each period is written as its letter when there is room; false
  /// draws plain blocks.
  final bool showLetters;

  /// The letters periods are written by, in order; periods past the end of it
  /// start again from the beginning.
  final String letters;

  /// Style of a letter.
  final TextStyle? letterStyle;

  /// The gap left between two rows.
  final double rowSpacing;

  /// How wide one period's block is; null fits the busiest row to the width.
  final double? blockWidth;

  /// Whether prices are written down the left.
  final bool showPriceAxis;

  /// How much room the price axis takes.
  final double axisWidth;

  /// One price is written every this many rows.
  final int priceLabelEvery;

  /// Writes a price; null writes at most two decimals.
  final String Function(double price)? priceFormatter;

  /// Style of a price label.
  final TextStyle? axisLabelStyle;

  /// Painted behind the row under the pointer; null marks none.
  final Color? hoverColor;

  /// Called as a touch moves over the rows, and with null when it leaves.
  final ValueChanged<MarketProfileTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched row; null shows none.
  final Widget? Function(
    BuildContext context,
    MarketProfileTouchDetails details,
  )?
  tooltipBuilder;

  /// How far the card sits from the row.
  final double tooltipMargin;

  /// How long the rows take to grow out; zero draws them at once.
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
  State<MarketProfileChart> createState() => _MarketProfileChartState();
}

class _MarketProfileChartState extends State<MarketProfileChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 128);
  List<MarketProfileBar> _bars = const [];
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
  void didUpdateWidget(MarketProfileChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!identical(oldWidget.profile, widget.profile)) {
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
    final index = marketProfileBarAt(_bars, local)?.index;
    if (index == _touched) return;
    setState(() => _touched = index);
    widget.onTouch?.call(
      index == null ? null : MarketProfileTouchDetails(bar: _bars[index]),
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
        final box = widget.padding.deflateRect(Offset.zero & size);
        final plot = Rect.fromLTRB(
          box.left + (widget.showPriceAxis ? widget.axisWidth : 0),
          box.top,
          box.right,
          box.bottom,
        );
        _bars = layOutMarketProfile(
          widget.profile,
          plot,
          rowSpacing: widget.rowSpacing,
          blockWidth: widget.blockWidth,
        );

        final touched = _touched;
        final details = touched == null || touched >= _bars.length
            ? null
            : MarketProfileTouchDetails(bar: _bars[touched]);
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
                      painter: MarketProfileChartPainter(
                        chart: widget,
                        bars: _bars,
                        plot: plot,
                        touched: details?.bar.index,
                        animation: t,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (tooltip != null && details != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomSingleChildLayout(
                          delegate: _MarketProfileTooltipLayout(
                            anchor: details.bar.rect,
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

/// Puts the tooltip to the right of the touched row, or to its left when there
/// is no room, kept inside the chart.
class _MarketProfileTooltipLayout extends SingleChildLayoutDelegate {
  _MarketProfileTooltipLayout({required this.anchor, required this.margin});

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
  bool shouldRelayout(_MarketProfileTooltipLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.margin != margin;
}

/// Paints a [MarketProfileChart]: the rows, the value area and the prices.
class MarketProfileChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [bars] inside [plot].
  MarketProfileChartPainter({
    required this.chart,
    required this.bars,
    required this.plot,
    required this.touched,
    required this.animation,
    required this.textCache,
  });

  final MarketProfileChart chart;
  final List<MarketProfileBar> bars;
  final Rect plot;
  final int? touched;
  final double animation;
  final TextPainterCache textCache;

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (bars.isEmpty) return;

    final hover = chart.hoverColor;
    final at = touched;
    if (at != null && at < bars.length && hover != null) {
      canvas.drawRect(bars[at].band, Paint()..color = hover);
    }

    final t = animation.clamp(0.0, 1.0);
    final profile = chart.profile;
    final fill = Paint()..isAntiAlias = true;
    final style =
        chart.letterStyle ??
        TextStyle(
          fontSize: math.min(10, bars.first.band.height),
          height: 1,
          color: const Color(0xFFFFFFFF),
        );

    for (final bar in bars) {
      if (bar.row.count == 0) continue;
      final inside = profile.inValueArea(bar.row.price);
      final color = inside ? chart.valueAreaColor : chart.blockColor;
      final shown = math.max(1, (bar.row.count * t).ceil());
      final letters =
          chart.showLetters && bar.blockWidth >= 6 && bar.rect.height >= 7;

      for (var i = 0; i < shown; i++) {
        final left = bar.rect.left + i * bar.blockWidth;
        if (left >= plot.right) break;
        final block = Rect.fromLTWH(
          left,
          bar.rect.top,
          math.min(bar.blockWidth, plot.right - left),
          bar.rect.height,
        );
        if (!letters) {
          fill.color = color;
          canvas.drawRect(block, fill);
          continue;
        }
        fill.color = color.withValues(alpha: 0.45);
        canvas.drawRect(block, fill);
        final tp = textCache.get(_letterFor(bar.row.periods[i]), style);
        if (tp.width <= block.width && tp.height <= block.height) {
          tp.paint(canvas, block.center - Offset(tp.width / 2, tp.height / 2));
        }
      }

      _paintPrice(canvas, bar);
    }

    if (t >= 1) _paintPointOfControl(canvas);
  }

  String _letterFor(int period) {
    final letters = chart.letters;
    if (letters.isEmpty) return '';
    return letters[period % letters.length];
  }

  void _paintPointOfControl(Canvas canvas) {
    final poc = chart.profile.pointOfControl;
    for (final bar in bars) {
      if (poc < bar.row.from || poc > bar.row.to) continue;
      canvas.drawLine(
        Offset(plot.left, bar.band.center.dy),
        Offset(plot.right, bar.band.center.dy),
        Paint()
          ..color = chart.pointOfControlColor
          ..strokeWidth = 1.5,
      );
      return;
    }
  }

  void _paintPrice(Canvas canvas, MarketProfileBar bar) {
    if (!chart.showPriceAxis) return;
    final every = math.max(1, chart.priceLabelEvery);
    if (bar.index % every != 0) return;
    final style = seriesAxisLabelStyle.merge(chart.axisLabelStyle);
    final tp = textCache.get(_formatPrice(bar.row.price), style);
    final left = plot.left - 6 - tp.width;
    if (left < 0) return;
    tp.paint(canvas, Offset(left, bar.band.center.dy - tp.height / 2));
  }

  String _formatPrice(double price) {
    final format = chart.priceFormatter;
    if (format != null) return format(price);
    final rounded = double.parse(price.toStringAsFixed(2));
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toString();
  }

  @override
  bool shouldRepaint(MarketProfileChartPainter oldDelegate) =>
      !identical(oldDelegate.chart, chart) ||
      !identical(oldDelegate.bars, bars) ||
      oldDelegate.plot != plot ||
      oldDelegate.touched != touched ||
      oldDelegate.animation != animation;
}
