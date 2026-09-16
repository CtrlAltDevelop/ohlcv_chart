import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';

/// Which way a position was, and so which way its liquidation pushes.
enum LiquiditySide {
  /// A long, liquidated by a fall — its stop sells into the market below.
  long,

  /// A short, liquidated by a rise — its stop buys above.
  short,
}

/// A position, or a cluster of them, that would be closed at one price.
@immutable
class LiquidityLevel {
  /// Creates a level of [size] that closes at [price].
  const LiquidityLevel({
    required this.price,
    required this.size,
    required this.side,
    this.leverage,
    this.label,
  });

  /// Where it would be closed.
  final double price;

  /// How large it is, in whatever unit the chart is counting — notional,
  /// contracts, coins. Negatives and nonsense count as nothing.
  final double size;

  /// Whether it is a long or a short.
  final LiquiditySide side;

  /// The leverage it was opened at, where it is known — the usual way these
  /// are bucketed on an exchange.
  final double? leverage;

  /// What it is called in a tooltip; null names the price and size.
  final String? label;

  /// The size actually counted.
  double get drawnSize => size.isFinite && size > 0 ? size : 0;
}

/// One price bucket of a [LiquidityMapChart].
@immutable
class LiquidityBin {
  /// Creates a bucket from [from] to [to].
  const LiquidityBin({
    required this.from,
    required this.to,
    required this.longSize,
    required this.shortSize,
    required this.levels,
  });

  /// The bottom of the bucket.
  final double from;

  /// Its top.
  final double to;

  /// How much long size would be liquidated in it.
  final double longSize;

  /// How much short size would be.
  final double shortSize;

  /// The levels that fell in it.
  final List<LiquidityLevel> levels;

  /// The middle of the bucket.
  double get mid => (from + to) / 2;

  /// Everything in it, either way.
  double get total => longSize + shortSize;

  /// Which side dominates it, and by how much, from -1 (all long) to 1 (all
  /// short).
  double get imbalance => total > 0 ? (shortSize - longSize) / total : 0;
}

/// Buckets [levels] into [binCount] price bands between [min] and [max].
///
/// Left without bounds, the range is the levels' own, with a little air. This
/// is the same bucketing a volume profile uses, so a liquidity map and a
/// profile drawn over the same range line up band for band.
List<LiquidityBin> liquidityBins(
  List<LiquidityLevel> levels, {
  int binCount = 48,
  double? min,
  double? max,
}) {
  final priced = [
    for (final level in levels)
      if (level.price.isFinite && level.drawnSize > 0) level,
  ];
  if (priced.isEmpty || binCount <= 0) return const [];

  var low = min, high = max;
  if (low == null || high == null) {
    var lo = double.infinity, hi = double.negativeInfinity;
    for (final level in priced) {
      lo = math.min(lo, level.price);
      hi = math.max(hi, level.price);
    }
    final pad = hi > lo ? (hi - lo) * 0.02 : math.max(1e-9, hi.abs() * 0.01);
    low ??= lo - pad;
    high ??= hi + pad;
  }
  if (!(high > low)) high = low + 1;

  final width = (high - low) / binCount;
  final longs = List<double>.filled(binCount, 0);
  final shorts = List<double>.filled(binCount, 0);
  final inside = [for (var i = 0; i < binCount; i++) <LiquidityLevel>[]];
  for (final level in priced) {
    if (level.price < low || level.price > high) continue;
    // The top price belongs to the last bucket rather than one past the end.
    final index = math.min(binCount - 1, ((level.price - low) / width).floor());
    if (index < 0) continue;
    if (level.side == LiquiditySide.long) {
      longs[index] += level.drawnSize;
    } else {
      shorts[index] += level.drawnSize;
    }
    inside[index].add(level);
  }

  return [
    for (var i = 0; i < binCount; i++)
      LiquidityBin(
        from: low + width * i,
        to: low + width * (i + 1),
        longSize: longs[i],
        shortSize: shorts[i],
        levels: inside[i],
      ),
  ];
}

/// Where one bucket of a [LiquidityMapChart] sits.
@immutable
class LiquidityBinLayout {
  /// Creates the layout of the bucket at [index].
  const LiquidityBinLayout({
    required this.index,
    required this.bin,
    required this.rowRect,
    required this.longRect,
    required this.shortRect,
  });

  /// Which bucket this is, into the chart's bins.
  final int index;

  /// The bucket itself.
  final LiquidityBin bin;

  /// The whole band of the plot it owns.
  final Rect rowRect;

  /// The long side's bar; empty where it has none.
  final Rect longRect;

  /// The short side's bar.
  final Rect shortRect;

  /// Whether [point] falls in the bucket's band.
  bool hit(Offset point) =>
      point.dy >= rowRect.top && point.dy <= rowRect.bottom;
}

/// Where every bucket of a [LiquidityMapChart] sits.
@immutable
class LiquidityMapLayout {
  /// Creates a laid-out chart.
  const LiquidityMapLayout({
    required this.size,
    required this.plotRect,
    required this.bins,
    required this.min,
    required this.max,
    required this.largest,
    required this.currentPrice,
    required this.priceY,
  });

  /// Nothing to draw.
  static const empty = LiquidityMapLayout(
    size: Size.zero,
    plotRect: Rect.zero,
    bins: [],
    min: 0,
    max: 0,
    largest: 0,
    currentPrice: null,
    priceY: null,
  );

  /// The box the chart was laid out in.
  final Size size;

  /// The part of it the bars run in.
  final Rect plotRect;

  /// The buckets, bottom price first.
  final List<LiquidityBinLayout> bins;

  /// The lowest price shown.
  final double min;

  /// The highest.
  final double max;

  /// The largest size in any one bucket, which the bars are scaled to.
  final double largest;

  /// The price the chart was told is current; null when it was not.
  final double? currentPrice;

  /// Where that price sits down the plot; null when none was given.
  final double? priceY;

  /// Whether there is anything to draw.
  bool get isEmpty => bins.isEmpty;

  /// Where [price] sits down the plot.
  double yOf(double price) {
    final span = max - min;
    if (!(span > 0) || !price.isFinite) return plotRect.bottom;
    final fraction = ((price - min) / span).clamp(0.0, 1.0);
    return plotRect.bottom - fraction * plotRect.height;
  }

  /// The bucket under [point]; null when it is off the plot.
  LiquidityBinLayout? binAt(Offset point) {
    for (final bin in bins) {
      if (bin.hit(point)) return bin;
    }
    return null;
  }

  /// Everything that would be liquidated between the current price and
  /// [price], which is what a move that far would set off.
  double exposureTo(double price) {
    final from = currentPrice;
    if (from == null) return 0;
    final low = math.min(from, price), high = math.max(from, price);
    var sum = 0.0;
    for (final laid in bins) {
      if (laid.bin.mid < low || laid.bin.mid > high) continue;
      // A fall sets off longs; a rise sets off shorts.
      sum += price < from ? laid.bin.longSize : laid.bin.shortSize;
    }
    return sum;
  }
}

/// Lays out [bins] in [size], bars growing in from the side they belong to.
///
/// [progress] runs from 0 to 1 and grows the bars in, for a draw-in animation.
LiquidityMapLayout layOutLiquidityMap(
  List<LiquidityBin> bins, {
  required Size size,
  double? currentPrice,
  double? largest,
  double barGap = 1,
  double axisWidth = 0,
  EdgeInsets padding = EdgeInsets.zero,
  double progress = 1,
}) {
  if (bins.isEmpty) return LiquidityMapLayout.empty;
  final box = padding.deflateRect(Offset.zero & size);
  if (box.width <= 0 || box.height <= 0) return LiquidityMapLayout.empty;
  final plot = Rect.fromLTRB(
    box.left,
    box.top,
    box.right - math.max(0, axisWidth),
    box.bottom,
  );
  if (plot.width <= 0 || plot.height <= 0) return LiquidityMapLayout.empty;

  final min = bins.first.from;
  final max = bins.last.to;
  if (!(max > min)) return LiquidityMapLayout.empty;

  var peak = largest ?? 0;
  if (!(peak > 0)) {
    for (final bin in bins) {
      peak = math.max(peak, math.max(bin.longSize, bin.shortSize));
    }
  }
  if (!(peak > 0)) peak = 1;

  final rowHeight = plot.height / bins.length;
  final t = progress.clamp(0.0, 1.0);
  // Longs grow in from the left, shorts from the right: the two sides of the
  // book read apart at a glance.
  final half = plot.width / 2;

  final laid = <LiquidityBinLayout>[];
  for (var i = 0; i < bins.length; i++) {
    final bin = bins[i];
    // Bin 0 is the lowest price, so it sits at the bottom of the plot.
    final top = plot.bottom - rowHeight * (i + 1);
    final row = Rect.fromLTWH(plot.left, top, plot.width, rowHeight);
    final barTop = row.top + barGap / 2;
    final barBottom = math.max(barTop, row.bottom - barGap / 2);

    final longWidth = half * (bin.longSize / peak).clamp(0.0, 1.0) * t;
    final shortWidth = half * (bin.shortSize / peak).clamp(0.0, 1.0) * t;
    laid.add(
      LiquidityBinLayout(
        index: i,
        bin: bin,
        rowRect: row,
        longRect: Rect.fromLTRB(
          plot.left + half - longWidth,
          barTop,
          plot.left + half,
          barBottom,
        ),
        shortRect: Rect.fromLTRB(
          plot.left + half,
          barTop,
          plot.left + half + shortWidth,
          barBottom,
        ),
      ),
    );
  }

  final span = max - min;
  final priceY = currentPrice == null || !currentPrice.isFinite
      ? null
      : plot.bottom -
          ((currentPrice - min) / span).clamp(0.0, 1.0) * plot.height;

  return LiquidityMapLayout(
    size: size,
    plotRect: plot,
    bins: laid,
    min: min,
    max: max,
    largest: peak,
    currentPrice:
        currentPrice != null && currentPrice.isFinite ? currentPrice : null,
    priceY: priceY,
  );
}

/// Where the stops are — a liquidation, or liquidity, map.
///
/// Leveraged positions do not close quietly: each one is a market order
/// waiting at a price. Stacked up the price axis, they show where a move would
/// find fuel, which is the thing a depth chart cannot say because those orders
/// are not in the book yet.
///
/// ```dart
/// LiquidityMapChart(
///   bins: liquidityBins(levels, binCount: 48),
///   currentPrice: 68_400,
/// );
/// ```
class LiquidityMapChart extends StatefulWidget {
  /// Creates a liquidity map of [bins].
  const LiquidityMapChart({
    super.key,
    required this.bins,
    this.currentPrice,
    this.largest,
    this.longColor = const Color(0xFF2F9E44),
    this.shortColor = const Color(0xFFE03131),
    this.barGap = 1,
    this.showAxis = true,
    this.axisWidth = 56,
    this.axisSteps = 5,
    this.axisStyle,
    this.priceFormatter,
    this.sizeFormatter,
    this.priceLineColor = const Color(0xCCE9ECEF),
    this.gridColor = const Color(0x10909196),
    this.showPeakLabel = true,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.onBinTap,
    this.tooltipBuilder,
    this.defaultHeight = 280,
    this.semanticLabel,
  });

  /// The price buckets, lowest first — `liquidityBins` makes them.
  final List<LiquidityBin> bins;

  /// Where the market is now; null draws no price line and reports no
  /// exposure.
  final double? currentPrice;

  /// The size the bars are scaled to; null takes the largest bucket, which
  /// makes one chart's bars incomparable with another's — give it to pin the
  /// scale across reloads.
  final double? largest;

  /// What long liquidations are painted in.
  final Color longColor;

  /// What short liquidations are painted in.
  final Color shortColor;

  /// Space between one bucket's bar and the next.
  final double barGap;

  /// Whether the price axis is written down the right.
  final bool showAxis;

  /// How much room it takes.
  final double axisWidth;

  /// How many gaps the axis is divided into; 0 draws no gridlines.
  final int axisSteps;

  /// Style of the axis labels.
  final TextStyle? axisStyle;

  /// Writes a price; null writes it with as few decimals as it needs.
  final String Function(double price)? priceFormatter;

  /// Writes a size; null writes it with as few decimals as it needs.
  final String Function(double size)? sizeFormatter;

  /// The line drawn at [currentPrice].
  final Color priceLineColor;

  /// The horizontal gridlines.
  final Color gridColor;

  /// Whether the largest bucket is labelled with its size.
  final bool showPeakLabel;

  /// Space kept clear around the chart.
  final EdgeInsets padding;

  /// Painted behind the whole chart.
  final Color? backgroundColor;

  /// How long the bars take to grow in; zero draws them at once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build grows the bars in.
  final bool animateOnMount;

  /// Called with a bucket when it is touched, and with null when the touch
  /// leaves the plot.
  final void Function(LiquidityBin? bin)? onBinTap;

  /// Builds the card shown over a touched bucket; null shows its price, both
  /// sides' sizes and what a move there would set off.
  final Widget Function(BuildContext context, LiquidityBin bin, double toThere)?
      tooltipBuilder;

  /// How tall the chart is in a box that sets no height.
  final double defaultHeight;

  /// What a screen reader announces for the chart.
  final String? semanticLabel;

  @override
  State<LiquidityMapChart> createState() => _LiquidityMapChartState();
}

class _LiquidityMapChartState extends State<LiquidityMapChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 256);
  LiquidityMapLayout _layout = LiquidityMapLayout.empty;
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
  void didUpdateWidget(LiquidityMapChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!identical(oldWidget.bins, widget.bins) &&
        widget.animationDuration > Duration.zero) {
      _animation.forward(from: 0);
    }
    if (_touched != null && _touched! >= widget.bins.length) _touched = null;
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void _touch(Offset point) {
    final bin = _layout.binAt(point);
    if (bin?.index == _touched) return;
    setState(() => _touched = bin?.index);
    widget.onBinTap?.call(bin?.bin);
  }

  void _clear() {
    if (_touched == null) return;
    setState(() => _touched = null);
    widget.onBinTap?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.animationCurve.transform(_animation.value);

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width =
              constraints.hasBoundedWidth ? constraints.maxWidth : 360.0;
          final height =
              constraints.hasBoundedHeight && constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : widget.defaultHeight;
          _layout = layOutLiquidityMap(
            widget.bins,
            size: Size(width, height),
            currentPrice: widget.currentPrice,
            largest: widget.largest,
            barGap: widget.barGap,
            axisWidth: widget.showAxis ? widget.axisWidth : 0,
            padding: widget.padding,
            progress: progress,
          );

          final touched = _touched;
          return SizedBox(
            width: width,
            height: height,
            child: Listener(
              onPointerDown: (event) => _touch(event.localPosition),
              onPointerMove: (event) => _touch(event.localPosition),
              onPointerUp: (_) => _clear(),
              onPointerCancel: (_) => _clear(),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: LiquidityMapChartPainter(
                        chart: widget,
                        layout: _layout,
                        touched: touched,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (touched != null && touched < _layout.bins.length)
                    _tooltip(context, touched),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tooltip(BuildContext context, int index) {
    final laid = _layout.bins[index];
    final toThere = _layout.exposureTo(laid.bin.mid);
    final build = widget.tooltipBuilder;
    final child = build != null
        ? build(context, laid.bin, toThere)
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xEE1B1D22),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${_price(widget, laid.bin.mid)}  '
              'L ${_size(widget, laid.bin.longSize)}  '
              'S ${_size(widget, laid.bin.shortSize)}'
              '${toThere > 0 ? '\nto here ${_size(widget, toThere)}' : ''}',
              style: const TextStyle(color: Color(0xFFE9ECEF), fontSize: 11),
            ),
          );
    return Positioned(
      left: 8,
      top: math.max(0, laid.rowRect.top - 34),
      child: IgnorePointer(child: child),
    );
  }
}

String _price(LiquidityMapChart chart, double value) {
  final format = chart.priceFormatter;
  if (format != null) return format(value);
  return _number(value);
}

String _size(LiquidityMapChart chart, double value) {
  final format = chart.sizeFormatter;
  if (format != null) return format(value);
  return _number(value);
}

String _number(double value) {
  if (!value.isFinite) return '';
  if (value.abs() >= 1000) return value.toStringAsFixed(0);
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

/// Paints a [LiquidityMapChart]: the two sides' bars, the price line and the
/// price axis.
class LiquidityMapChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [layout].
  LiquidityMapChartPainter({
    required this.chart,
    required this.layout,
    required this.touched,
    required this.textCache,
  });

  final LiquidityMapChart chart;
  final LiquidityMapLayout layout;

  /// The bucket under the finger; null when none is.
  final int? touched;
  final TextPainterCache textCache;

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (layout.isEmpty) return;

    final axisStyle = chart.axisStyle ??
        const TextStyle(color: Color(0xFF909196), fontSize: 10);

    if (chart.axisSteps > 0) {
      final grid = Paint()
        ..color = chart.gridColor
        ..strokeWidth = 1;
      for (var i = 0; i <= chart.axisSteps; i++) {
        final price =
            layout.min + (layout.max - layout.min) * i / chart.axisSteps;
        final y = layout.yOf(price);
        canvas.drawLine(
          Offset(layout.plotRect.left, y),
          Offset(layout.plotRect.right, y),
          grid,
        );
        if (chart.showAxis && chart.axisWidth > 0) {
          final painter = textCache.get(_price(chart, price), axisStyle);
          painter.paint(
            canvas,
            Offset(
              layout.plotRect.right + 6,
              (y - painter.height / 2)
                  .clamp(0.0, math.max(0.0, size.height - painter.height)),
            ),
          );
        }
      }
    }

    var peakIndex = 0;
    for (final laid in layout.bins) {
      if (laid.bin.total > layout.bins[peakIndex].bin.total) {
        peakIndex = laid.index;
      }
      final lit = touched == laid.index;
      if (lit) {
        canvas.drawRect(
          laid.rowRect,
          Paint()..color = const Color(0x14FFFFFF),
        );
      }
      if (laid.longRect.width > 0) {
        canvas.drawRect(
          laid.longRect,
          Paint()
            ..color =
                lit ? chart.longColor : chart.longColor.withValues(alpha: 0.75),
        );
      }
      if (laid.shortRect.width > 0) {
        canvas.drawRect(
          laid.shortRect,
          Paint()
            ..color = lit
                ? chart.shortColor
                : chart.shortColor.withValues(alpha: 0.75),
        );
      }
    }

    if (chart.showPeakLabel && layout.bins.isNotEmpty) {
      final peak = layout.bins[peakIndex];
      if (peak.bin.total > 0) {
        final painter = textCache.get(
          _size(chart, peak.bin.total),
          axisStyle.copyWith(color: const Color(0xFFE9ECEF)),
        );
        painter.paint(
          canvas,
          Offset(
            layout.plotRect.center.dx - painter.width / 2,
            peak.rowRect.center.dy - painter.height / 2,
          ),
        );
      }
    }

    final y = layout.priceY;
    if (y != null) {
      canvas.drawLine(
        Offset(layout.plotRect.left, y),
        Offset(layout.plotRect.right, y),
        Paint()
          ..color = chart.priceLineColor
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(LiquidityMapChartPainter old) =>
      old.chart != chart || old.layout != layout || old.touched != touched;
}
