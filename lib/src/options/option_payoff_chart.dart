import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';
import '../series/series_axis.dart';
import '../utils/axis_ticks.dart';

/// What one leg of a strategy is.
enum OptionKind {
  /// The right to buy at the strike.
  call,

  /// The right to sell at the strike.
  put,

  /// The underlying itself, bought or sold at the strike price.
  underlying,
}

/// One leg of an options strategy.
@immutable
class OptionLeg {
  /// Creates a leg.
  const OptionLeg({
    required this.kind,
    required this.strike,
    this.premium = 0,
    this.quantity = 1,
    this.contractSize = 1,
    this.label,
  });

  /// Buys [quantity] calls struck at [strike] for [premium] each.
  const OptionLeg.longCall({
    required double strike,
    double premium = 0,
    double quantity = 1,
    double contractSize = 1,
    String? label,
  }) : this(
         kind: OptionKind.call,
         strike: strike,
         premium: premium,
         quantity: quantity,
         contractSize: contractSize,
         label: label,
       );

  /// Sells [quantity] calls struck at [strike] for [premium] each.
  const OptionLeg.shortCall({
    required double strike,
    double premium = 0,
    double quantity = 1,
    double contractSize = 1,
    String? label,
  }) : this(
         kind: OptionKind.call,
         strike: strike,
         premium: premium,
         quantity: -quantity,
         contractSize: contractSize,
         label: label,
       );

  /// Buys [quantity] puts struck at [strike] for [premium] each.
  const OptionLeg.longPut({
    required double strike,
    double premium = 0,
    double quantity = 1,
    double contractSize = 1,
    String? label,
  }) : this(
         kind: OptionKind.put,
         strike: strike,
         premium: premium,
         quantity: quantity,
         contractSize: contractSize,
         label: label,
       );

  /// Sells [quantity] puts struck at [strike] for [premium] each.
  const OptionLeg.shortPut({
    required double strike,
    double premium = 0,
    double quantity = 1,
    double contractSize = 1,
    String? label,
  }) : this(
         kind: OptionKind.put,
         strike: strike,
         premium: premium,
         quantity: -quantity,
         contractSize: contractSize,
         label: label,
       );

  /// What the leg is.
  final OptionKind kind;

  /// The strike, or for [OptionKind.underlying] the price it was traded at.
  final double strike;

  /// What was paid for one contract; what was taken in, for a short leg.
  final double premium;

  /// How many contracts: negative is short.
  final double quantity;

  /// How much of the underlying one contract covers.
  final double contractSize;

  /// What the leg is called.
  final String? label;

  /// What this leg alone is worth if the underlying expires at [price].
  double payoffAt(double price) {
    final intrinsic = switch (kind) {
      OptionKind.call => math.max(0.0, price - strike),
      OptionKind.put => math.max(0.0, strike - price),
      OptionKind.underlying => price - strike,
    };
    final cost = kind == OptionKind.underlying ? 0.0 : premium;
    return (intrinsic - cost) * quantity * contractSize;
  }
}

/// What [legs] are worth together if the underlying expires at [price].
double optionPayoff(List<OptionLeg> legs, double price) {
  var total = 0.0;
  for (final leg in legs) {
    final value = leg.payoffAt(price);
    if (value.isFinite) total += value;
  }
  return total;
}

/// The price range [legs] are worth drawing over: every strike, with [pad] of
/// the spread left either side.
({double min, double max}) optionPriceRange(
  List<OptionLeg> legs, {
  double pad = 0.35,
  double? spot,
}) {
  var min = double.infinity;
  var max = double.negativeInfinity;
  for (final leg in legs) {
    if (!leg.strike.isFinite) continue;
    min = math.min(min, leg.strike);
    max = math.max(max, leg.strike);
  }
  if (spot != null && spot.isFinite) {
    min = math.min(min, spot);
    max = math.max(max, spot);
  }
  if (!min.isFinite || !max.isFinite) return (min: 0, max: 1);
  final spread = max - min;
  final room = spread == 0 ? math.max(1.0, max.abs() * 0.2) : spread * pad;
  return (min: math.max(0, min - room), max: max + room);
}

/// The prices between [min] and [max] where [legs] break even.
///
/// The payoff is a straight line between strikes, so a crossing is found
/// exactly by looking either side of each strike.
List<double> optionBreakEvens(List<OptionLeg> legs, double min, double max) {
  if (legs.isEmpty || max <= min) return const [];

  final points = <double>{min, max};
  for (final leg in legs) {
    if (leg.strike > min && leg.strike < max) points.add(leg.strike);
  }
  final sorted = points.toList()..sort();

  final found = <double>[];
  for (var i = 1; i < sorted.length; i++) {
    final a = sorted[i - 1];
    final b = sorted[i];
    final pa = optionPayoff(legs, a);
    final pb = optionPayoff(legs, b);
    if (pa == 0) {
      found.add(a);
      continue;
    }
    if (pa.isNaN || pb.isNaN || (pa < 0) == (pb < 0)) continue;
    final span = pb - pa;
    if (span == 0) continue;
    found.add(a + (b - a) * (-pa / span));
  }
  if (optionPayoff(legs, max) == 0) found.add(max);
  return found;
}

/// Where an option payoff was laid out.
@immutable
class OptionPayoffLayout {
  /// Creates a layout.
  const OptionPayoffLayout({
    required this.plot,
    required this.points,
    required this.minPrice,
    required this.maxPrice,
    required this.minPayoff,
    required this.maxPayoff,
    required this.zeroY,
  });

  /// Nothing laid out.
  static const OptionPayoffLayout empty = OptionPayoffLayout(
    plot: Rect.zero,
    points: [],
    minPrice: 0,
    maxPrice: 1,
    minPayoff: 0,
    maxPayoff: 1,
    zeroY: 0,
  );

  /// The box the payoff is drawn in.
  final Rect plot;

  /// The payoff line, left to right.
  final List<Offset> points;

  /// The lowest price drawn.
  final double minPrice;

  /// The highest.
  final double maxPrice;

  /// The lowest payoff drawn.
  final double minPayoff;

  /// The highest.
  final double maxPayoff;

  /// Where a payoff of zero sits.
  final double zeroY;

  /// Whether nothing was laid out.
  bool get isEmpty => points.isEmpty;

  /// Where [price] sits across the plot.
  double xOf(double price) => maxPrice == minPrice
      ? plot.center.dx
      : plot.left + (price - minPrice) / (maxPrice - minPrice) * plot.width;

  /// Where [payoff] sits up the plot.
  double yOf(double payoff) => maxPayoff == minPayoff
      ? plot.center.dy
      : plot.bottom -
            (payoff - minPayoff) / (maxPayoff - minPayoff) * plot.height;

  /// The price at [dx].
  double priceAt(double dx) => plot.width <= 0
      ? minPrice
      : minPrice +
            ((dx - plot.left) / plot.width).clamp(0.0, 1.0) *
                (maxPrice - minPrice);
}

/// Works out the payoff of [legs] across [bounds].
///
/// The line is sampled at every strike and at [steps] evenly spaced prices, so
/// the kinks at the strikes are exact rather than rounded off by sampling.
OptionPayoffLayout layOutOptionPayoff(
  List<OptionLeg> legs,
  Rect bounds, {
  required double minPrice,
  required double maxPrice,
  int steps = 120,
  double? minPayoff,
  double? maxPayoff,
}) {
  if (legs.isEmpty ||
      bounds.width <= 0 ||
      bounds.height <= 0 ||
      maxPrice <= minPrice) {
    return OptionPayoffLayout.empty;
  }

  final prices = <double>{minPrice, maxPrice};
  for (final leg in legs) {
    if (leg.strike > minPrice && leg.strike < maxPrice) prices.add(leg.strike);
  }
  final count = math.max(2, steps);
  for (var i = 0; i <= count; i++) {
    prices.add(minPrice + (maxPrice - minPrice) * i / count);
  }
  final sorted = prices.toList()..sort();
  final payoffs = [for (final price in sorted) optionPayoff(legs, price)];

  var low = minPayoff ?? double.infinity;
  var high = maxPayoff ?? double.negativeInfinity;
  if (minPayoff == null || maxPayoff == null) {
    for (final payoff in payoffs) {
      if (!payoff.isFinite) continue;
      if (minPayoff == null) low = math.min(low, payoff);
      if (maxPayoff == null) high = math.max(high, payoff);
    }
    // Zero is always on the chart: a payoff diagram without its break-even
    // line says nothing.
    if (minPayoff == null) low = math.min(low, 0);
    if (maxPayoff == null) high = math.max(high, 0);
  }
  if (!low.isFinite || !high.isFinite || high <= low) {
    low = -1;
    high = 1;
  } else {
    final room = (high - low) * 0.08;
    if (minPayoff == null) low -= room;
    if (maxPayoff == null) high += room;
  }

  final layout = OptionPayoffLayout(
    plot: bounds,
    points: const [],
    minPrice: minPrice,
    maxPrice: maxPrice,
    minPayoff: low,
    maxPayoff: high,
    zeroY: 0,
  );

  return OptionPayoffLayout(
    plot: bounds,
    minPrice: minPrice,
    maxPrice: maxPrice,
    minPayoff: low,
    maxPayoff: high,
    zeroY: layout.yOf(0),
    points: [
      for (var i = 0; i < sorted.length; i++)
        Offset(layout.xOf(sorted[i]), layout.yOf(payoffs[i])),
    ],
  );
}

/// What a touch on an [OptionPayoffChart] landed on.
@immutable
class OptionPayoffTouchDetails {
  /// Creates the details of a touch at [price].
  const OptionPayoffTouchDetails({
    required this.price,
    required this.payoff,
    required this.at,
  });

  /// The price under the pointer.
  final double price;

  /// What the strategy is worth there, at expiry.
  final double payoff;

  /// Where that sits, in the chart's local pixels.
  final Offset at;
}

/// What an options strategy makes or loses at expiry, price by price.
///
/// ```dart
/// OptionPayoffChart(
///   legs: const [
///     OptionLeg.longCall(strike: 100, premium: 4),
///     OptionLeg.shortCall(strike: 110, premium: 1.5),
///   ],
///   spot: 102,
/// );
/// ```
///
/// The chart fills the box it is given, and is [defaultHeight] high in a box
/// with no height of its own.
class OptionPayoffChart extends StatefulWidget {
  /// Creates a payoff diagram of [legs].
  const OptionPayoffChart({
    super.key,
    required this.legs,
    this.minPrice,
    this.maxPrice,
    this.minPayoff,
    this.maxPayoff,
    this.spot,
    this.steps = 120,
    this.profitColor = const Color(0xFF2F9E44),
    this.lossColor = const Color(0xFFE03131),
    this.lineWidth = 2,
    this.fillOpacity = 0.2,
    this.showStrikes = true,
    this.strikeColor = const Color(0x44FFFFFF),
    this.showBreakEvens = true,
    this.breakEvenColor = const Color(0xAAFFFFFF),
    this.spotColor = const Color(0xFFF59F00),
    this.showAxes = true,
    this.axisWidth = 52,
    this.axisHeight = 18,
    this.tickCount = 5,
    this.priceFormatter,
    this.payoffFormatter,
    this.axisLabelStyle,
    this.gridColor = const Color(0x22FFFFFF),
    this.crosshairColor = const Color(0x66FFFFFF),
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

  /// The legs of the strategy.
  final List<OptionLeg> legs;

  /// The lowest price drawn; null reads it off the strikes.
  final double? minPrice;

  /// The highest; null reads it off the strikes.
  final double? maxPrice;

  /// The bottom of the payoff axis; null reads it off the payoff.
  final double? minPayoff;

  /// The top of it; null reads it off the payoff.
  final double? maxPayoff;

  /// Where the underlying is now; null marks none.
  final double? spot;

  /// How many prices the line is sampled at, on top of the strikes.
  final int steps;

  /// The colour of the line and shading above zero.
  final Color profitColor;

  /// The colour below zero.
  final Color lossColor;

  /// How thick the payoff line is.
  final double lineWidth;

  /// How opaque the shading between the line and zero is; zero draws none.
  final double fillOpacity;

  /// Whether a line is drawn at each strike.
  final bool showStrikes;

  /// The colour of those lines.
  final Color strikeColor;

  /// Whether the break-even prices are marked and written.
  final bool showBreakEvens;

  /// The colour of those marks.
  final Color breakEvenColor;

  /// The colour of the line marking [spot].
  final Color spotColor;

  /// Whether the two axes are drawn.
  final bool showAxes;

  /// How much room the payoff axis takes.
  final double axisWidth;

  /// How much room the price axis takes.
  final double axisHeight;

  /// About how many ticks to write on each axis.
  final int tickCount;

  /// Writes a price; null writes at most two decimals.
  final String Function(double price)? priceFormatter;

  /// Writes a payoff; null writes at most two decimals with a sign.
  final String Function(double payoff)? payoffFormatter;

  /// Style of an axis label.
  final TextStyle? axisLabelStyle;

  /// Colour of the grid ruled at each tick; null rules none.
  final Color? gridColor;

  /// Colour of the line drawn at the touched price; null draws none.
  final Color? crosshairColor;

  /// Called as a touch moves across the chart, and with null when it leaves.
  final ValueChanged<OptionPayoffTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched price; null shows none.
  final Widget? Function(
    BuildContext context,
    OptionPayoffTouchDetails details,
  )?
  tooltipBuilder;

  /// How far the card sits from the line.
  final double tooltipMargin;

  /// How long the line takes to draw itself in; zero draws it at once.
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
  State<OptionPayoffChart> createState() => _OptionPayoffChartState();
}

class _OptionPayoffChartState extends State<OptionPayoffChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 64);
  OptionPayoffLayout _layout = OptionPayoffLayout.empty;
  double? _touched;

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
  void didUpdateWidget(OptionPayoffChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!identical(oldWidget.legs, widget.legs)) {
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
    if (_layout.isEmpty) return;
    final price = _layout.priceAt(local.dx);
    if (price == _touched) return;
    setState(() => _touched = price);
    widget.onTouch?.call(_detailsAt(price));
  }

  OptionPayoffTouchDetails _detailsAt(double price) {
    final payoff = optionPayoff(widget.legs, price);
    return OptionPayoffTouchDetails(
      price: price,
      payoff: payoff,
      at: Offset(_layout.xOf(price), _layout.yOf(payoff)),
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
    final range = optionPriceRange(widget.legs, spot: widget.spot);
    final minPrice = widget.minPrice ?? range.min;
    final maxPrice = widget.maxPrice ?? range.max;

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
        _layout = layOutOptionPayoff(
          widget.legs,
          plot,
          minPrice: minPrice,
          maxPrice: maxPrice,
          steps: widget.steps,
          minPayoff: widget.minPayoff,
          maxPayoff: widget.maxPayoff,
        );

        final price = _touched;
        final details = price == null || _layout.isEmpty
            ? null
            : _detailsAt(price);
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
                      painter: OptionPayoffChartPainter(
                        chart: widget,
                        layout: _layout,
                        touched: details?.price,
                        animation: t,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (tooltip != null && details != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomSingleChildLayout(
                          delegate: _OptionTooltipLayout(
                            anchor: details.at,
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

/// Puts the tooltip beside the touched price, kept inside the chart.
class _OptionTooltipLayout extends SingleChildLayoutDelegate {
  _OptionTooltipLayout({required this.anchor, required this.margin});

  final Offset anchor;
  final double margin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var left = anchor.dx + margin;
    if (left + childSize.width > size.width) {
      left = anchor.dx - margin - childSize.width;
    }
    return Offset(
      left.clamp(0.0, math.max(0.0, size.width - childSize.width)),
      (anchor.dy - childSize.height - margin).clamp(
        0.0,
        math.max(0.0, size.height - childSize.height),
      ),
    );
  }

  @override
  bool shouldRelayout(_OptionTooltipLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.margin != margin;
}

/// Paints an [OptionPayoffChart]: the axes, the strikes and the payoff line.
class OptionPayoffChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [layout].
  OptionPayoffChartPainter({
    required this.chart,
    required this.layout,
    required this.touched,
    required this.animation,
    required this.textCache,
  });

  final OptionPayoffChart chart;
  final OptionPayoffLayout layout;
  final double? touched;
  final double animation;
  final TextPainterCache textCache;

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (layout.isEmpty) return;

    _paintAxes(canvas);
    _paintStrikes(canvas);

    final t = animation.clamp(0.0, 1.0);
    final shown = math.max(2, (layout.points.length * t).ceil());
    _paintPayoff(canvas, shown);

    if (t >= 1) {
      _paintSpot(canvas);
      if (chart.showBreakEvens) _paintBreakEvens(canvas);
      _paintCrosshair(canvas);
    }
  }

  void _paintPayoff(Canvas canvas, int shown) {
    final points = layout.points.take(shown).toList();
    final zero = layout.zeroY;

    if (chart.fillOpacity > 0) {
      // Above zero is profit, below is loss: the two are shaded apart by
      // clipping the same filled path.
      final fill = Path()..moveTo(points.first.dx, zero);
      for (final point in points) {
        fill.lineTo(point.dx, point.dy);
      }
      fill
        ..lineTo(points.last.dx, zero)
        ..close();
      final alpha = chart.fillOpacity.clamp(0.0, 1.0);
      for (final (color, band) in [
        (
          chart.profitColor,
          Rect.fromLTRB(
            layout.plot.left,
            layout.plot.top,
            layout.plot.right,
            zero,
          ),
        ),
        (
          chart.lossColor,
          Rect.fromLTRB(
            layout.plot.left,
            zero,
            layout.plot.right,
            layout.plot.bottom,
          ),
        ),
      ]) {
        if (band.height <= 0) continue;
        canvas
          ..save()
          ..clipRect(band)
          ..drawPath(fill, Paint()..color = color.withValues(alpha: alpha))
          ..restore();
      }
    }

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = chart.lineWidth
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    for (final (color, band) in [
      (
        chart.profitColor,
        Rect.fromLTRB(
          layout.plot.left,
          layout.plot.top,
          layout.plot.right,
          zero,
        ),
      ),
      (
        chart.lossColor,
        Rect.fromLTRB(
          layout.plot.left,
          zero,
          layout.plot.right,
          layout.plot.bottom,
        ),
      ),
    ]) {
      if (band.height <= 0) continue;
      canvas
        ..save()
        ..clipRect(band)
        ..drawPath(line, pen..color = color)
        ..restore();
    }

    canvas.drawLine(
      Offset(layout.plot.left, zero),
      Offset(layout.plot.right, zero),
      Paint()
        ..color = const Color(0x66FFFFFF)
        ..strokeWidth = 1,
    );
  }

  void _paintStrikes(Canvas canvas) {
    if (!chart.showStrikes) return;
    final pen = Paint()
      ..color = chart.strikeColor
      ..strokeWidth = 1;
    for (final leg in chart.legs) {
      if (leg.kind == OptionKind.underlying) continue;
      if (leg.strike < layout.minPrice || leg.strike > layout.maxPrice) {
        continue;
      }
      final x = layout.xOf(leg.strike);
      canvas.drawLine(
        Offset(x, layout.plot.top),
        Offset(x, layout.plot.bottom),
        pen,
      );
    }
  }

  void _paintSpot(Canvas canvas) {
    final spot = chart.spot;
    if (spot == null || spot < layout.minPrice || spot > layout.maxPrice) {
      return;
    }
    final x = layout.xOf(spot);
    canvas.drawLine(
      Offset(x, layout.plot.top),
      Offset(x, layout.plot.bottom),
      Paint()
        ..color = chart.spotColor
        ..strokeWidth = 1.5,
    );
    final tp = textCache.get(
      _formatPrice(spot),
      seriesAxisLabelStyle
          .merge(chart.axisLabelStyle)
          .copyWith(color: chart.spotColor),
    );
    tp.paint(
      canvas,
      Offset(
        math.min(x + 3, layout.plot.right - tp.width),
        layout.plot.top + 2,
      ),
    );
  }

  void _paintBreakEvens(Canvas canvas) {
    final prices = optionBreakEvens(
      chart.legs,
      layout.minPrice,
      layout.maxPrice,
    );
    if (prices.isEmpty) return;
    final style = seriesAxisLabelStyle
        .merge(chart.axisLabelStyle)
        .copyWith(color: chart.breakEvenColor);
    for (final price in prices) {
      final x = layout.xOf(price);
      canvas.drawCircle(
        Offset(x, layout.zeroY),
        3,
        Paint()
          ..color = chart.breakEvenColor
          ..isAntiAlias = true,
      );
      final tp = textCache.get(_formatPrice(price), style);
      final left = (x - tp.width / 2).clamp(
        layout.plot.left,
        math.max(layout.plot.left, layout.plot.right - tp.width),
      );
      tp.paint(canvas, Offset(left.toDouble(), layout.zeroY + 5));
    }
  }

  void _paintCrosshair(Canvas canvas) {
    final price = touched;
    final color = chart.crosshairColor;
    if (price == null || color == null) return;
    final x = layout.xOf(price);
    final payoff = optionPayoff(chart.legs, price);
    canvas
      ..drawLine(
        Offset(x, layout.plot.top),
        Offset(x, layout.plot.bottom),
        Paint()
          ..color = color
          ..strokeWidth = 1,
      )
      ..drawCircle(
        Offset(x, layout.yOf(payoff)),
        3,
        Paint()
          ..color = payoff < 0 ? chart.lossColor : chart.profitColor
          ..isAntiAlias = true,
      );
  }

  void _paintAxes(Canvas canvas) {
    final grid = chart.gridColor;
    if (!chart.showAxes && grid == null) return;
    final style = seriesAxisLabelStyle.merge(chart.axisLabelStyle);
    final line = grid == null
        ? null
        : (Paint()
            ..color = grid
            ..strokeWidth = 1);

    for (final tick in niceTicks(
      layout.minPayoff,
      layout.maxPayoff,
      target: chart.tickCount,
    )) {
      final y = layout.yOf(tick);
      if (line != null) {
        canvas.drawLine(
          Offset(layout.plot.left, y),
          Offset(layout.plot.right, y),
          line,
        );
      }
      if (!chart.showAxes) continue;
      final tp = textCache.get(_formatPayoff(tick), style);
      final left = layout.plot.left - 6 - tp.width;
      if (left >= 0) tp.paint(canvas, Offset(left, y - tp.height / 2));
    }

    var written = -double.infinity;
    for (final tick in niceTicks(
      layout.minPrice,
      layout.maxPrice,
      target: chart.tickCount,
    )) {
      final x = layout.xOf(tick);
      if (line != null) {
        canvas.drawLine(
          Offset(x, layout.plot.top),
          Offset(x, layout.plot.bottom),
          line,
        );
      }
      if (!chart.showAxes) continue;
      final tp = textCache.get(_formatPrice(tick), style);
      final left = x - tp.width / 2;
      if (left < written || left + tp.width > layout.plot.right) continue;
      tp.paint(canvas, Offset(left, layout.plot.bottom + 3));
      written = left + tp.width + 4;
    }
  }

  String _formatPrice(double price) {
    final format = chart.priceFormatter;
    if (format != null) return format(price);
    return _short(price);
  }

  String _formatPayoff(double payoff) {
    final format = chart.payoffFormatter;
    if (format != null) return format(payoff);
    final text = _short(payoff);
    return payoff > 0 ? '+$text' : text;
  }

  String _short(double value) {
    final rounded = double.parse(value.toStringAsFixed(2));
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toString();
  }

  @override
  bool shouldRepaint(OptionPayoffChartPainter oldDelegate) =>
      !identical(oldDelegate.chart, chart) ||
      !identical(oldDelegate.layout, layout) ||
      oldDelegate.touched != touched ||
      oldDelegate.animation != animation;
}
