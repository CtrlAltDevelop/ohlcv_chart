import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';

/// One reading of open interest and funding.
@immutable
class OpenInterestPoint {
  /// Creates a reading at [time].
  const OpenInterestPoint({
    required this.time,
    required this.openInterest,
    this.funding,
    this.price,
  });

  /// When it was taken, in milliseconds since the epoch.
  final int time;

  /// How much was open then, in contracts or notional. A non-finite value is
  /// a gap in the line.
  final double openInterest;

  /// The funding rate at that time, as a fraction — 0.0001 is one basis
  /// point. Null is a time with no funding reading.
  final double? funding;

  /// The price then, where you want it drawn over the panel; null draws none.
  final double? price;

  /// The funding rate, or null when it is missing or nonsense.
  double? get drawnFunding {
    final rate = funding;
    return rate != null && rate.isFinite ? rate : null;
  }
}

/// What open interest and price did together over one step.
///
/// The four cases traders read off this pairing: rising interest with a rising
/// price is new longs, falling interest with a falling price is longs closing,
/// rising interest with a falling price is new shorts, and falling interest
/// with a rising price is shorts covering.
enum OpenInterestMove {
  /// Price up, interest up — new money, long.
  newLongs,

  /// Price down, interest down — longs closing out.
  longsClosing,

  /// Price down, interest up — new money, short.
  newShorts,

  /// Price up, interest down — shorts covering.
  shortsCovering,

  /// One of the two did not move, or is not known.
  flat,
}

/// Reads [points] for what interest and price did at each step.
///
/// The first point has nothing before it, so it is always [OpenInterestMove.flat].
List<OpenInterestMove> openInterestMoves(List<OpenInterestPoint> points) {
  final moves = <OpenInterestMove>[];
  for (var i = 0; i < points.length; i++) {
    if (i == 0) {
      moves.add(OpenInterestMove.flat);
      continue;
    }
    final before = points[i - 1], now = points[i];
    final priceBefore = before.price, priceNow = now.price;
    if (priceBefore == null ||
        priceNow == null ||
        !priceBefore.isFinite ||
        !priceNow.isFinite ||
        !before.openInterest.isFinite ||
        !now.openInterest.isFinite) {
      moves.add(OpenInterestMove.flat);
      continue;
    }
    final priceUp = priceNow > priceBefore;
    final priceDown = priceNow < priceBefore;
    final interestUp = now.openInterest > before.openInterest;
    final interestDown = now.openInterest < before.openInterest;
    if (priceUp && interestUp) {
      moves.add(OpenInterestMove.newLongs);
    } else if (priceDown && interestDown) {
      moves.add(OpenInterestMove.longsClosing);
    } else if (priceDown && interestUp) {
      moves.add(OpenInterestMove.newShorts);
    } else if (priceUp && interestDown) {
      moves.add(OpenInterestMove.shortsCovering);
    } else {
      moves.add(OpenInterestMove.flat);
    }
  }
  return moves;
}

/// Where a [OpenInterestChart]'s two panels sit.
@immutable
class OpenInterestLayout {
  /// Creates a laid-out chart.
  const OpenInterestLayout({
    required this.size,
    required this.interestRect,
    required this.fundingRect,
    required this.columnX,
    required this.interestPoints,
    required this.pricePoints,
    required this.fundingBars,
    required this.interestMin,
    required this.interestMax,
    required this.priceMin,
    required this.priceMax,
    required this.fundingMax,
    required this.zeroY,
  });

  /// Nothing to draw.
  static const empty = OpenInterestLayout(
    size: Size.zero,
    interestRect: Rect.zero,
    fundingRect: Rect.zero,
    columnX: [],
    interestPoints: [],
    pricePoints: [],
    fundingBars: [],
    interestMin: 0,
    interestMax: 0,
    priceMin: 0,
    priceMax: 0,
    fundingMax: 0,
    zeroY: 0,
  );

  /// The box the chart was laid out in.
  final Size size;

  /// The upper panel, where open interest and price are drawn.
  final Rect interestRect;

  /// The lower one, where funding is.
  final Rect fundingRect;

  /// Where each reading sits across both panels.
  final List<double> columnX;

  /// The open interest line; null at a reading with no value.
  final List<Offset?> interestPoints;

  /// The price line over the same panel; null where there is no price.
  final List<Offset?> pricePoints;

  /// The funding bars, by reading; null where there is no funding.
  final List<Rect?> fundingBars;

  /// The bottom of the open interest scale.
  final double interestMin;

  /// Its top.
  final double interestMax;

  /// The bottom of the price scale.
  final double priceMin;

  /// Its top.
  final double priceMax;

  /// The largest funding rate either way, which the bars are scaled to.
  final double fundingMax;

  /// Where zero funding sits in the lower panel.
  final double zeroY;

  /// Whether there is anything to draw.
  bool get isEmpty => columnX.isEmpty;

  /// The reading nearest [x].
  int indexAt(double x) {
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < columnX.length; i++) {
      final distance = (columnX[i] - x).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    return best;
  }
}

/// Lays out [points] as two stacked panels in [size].
///
/// [fundingShare] is how much of the height the funding panel takes.
/// [progress] reveals the readings left to right, for a draw-in animation.
OpenInterestLayout layOutOpenInterest(
  List<OpenInterestPoint> points, {
  required Size size,
  double fundingShare = 0.32,
  double panelGap = 8,
  double axisWidth = 0,
  double barWidth = 0.6,
  double? fundingMax,
  EdgeInsets padding = EdgeInsets.zero,
  double progress = 1,
}) {
  if (points.isEmpty) return OpenInterestLayout.empty;
  final box = padding.deflateRect(Offset.zero & size);
  if (box.width <= 0 || box.height <= 0) return OpenInterestLayout.empty;

  final plotWidth = box.width - math.max(0, axisWidth);
  if (plotWidth <= 0) return OpenInterestLayout.empty;
  final share = fundingShare.clamp(0.0, 0.8);
  final fundingHeight = (box.height - panelGap) * share;
  final interestHeight = box.height - panelGap - fundingHeight;
  if (interestHeight <= 0) return OpenInterestLayout.empty;

  final interest = Rect.fromLTWH(
    box.left,
    box.top,
    plotWidth,
    interestHeight,
  );
  final funding = Rect.fromLTWH(
    box.left,
    interest.bottom + panelGap,
    plotWidth,
    math.max(0, fundingHeight),
  );

  var interestLow = double.infinity, interestHigh = double.negativeInfinity;
  var priceLow = double.infinity, priceHigh = double.negativeInfinity;
  var peak = fundingMax ?? 0;
  for (final point in points) {
    if (point.openInterest.isFinite) {
      interestLow = math.min(interestLow, point.openInterest);
      interestHigh = math.max(interestHigh, point.openInterest);
    }
    final price = point.price;
    if (price != null && price.isFinite) {
      priceLow = math.min(priceLow, price);
      priceHigh = math.max(priceHigh, price);
    }
    final rate = point.drawnFunding;
    if (rate != null && fundingMax == null) {
      peak = math.max(peak, rate.abs());
    }
  }
  if (!interestLow.isFinite || !interestHigh.isFinite) {
    return OpenInterestLayout.empty;
  }
  // Open interest is read for its swings, not its level, so the panel is
  // scaled to the range it actually covers rather than down to zero.
  if (!(interestHigh > interestLow)) {
    final pad = math.max(1e-9, interestLow.abs() * 0.05);
    interestLow -= pad;
    interestHigh += pad;
  }
  if (!priceLow.isFinite || !priceHigh.isFinite) {
    priceLow = 0;
    priceHigh = 1;
  } else if (!(priceHigh > priceLow)) {
    final pad = math.max(1e-9, priceLow.abs() * 0.05);
    priceLow -= pad;
    priceHigh += pad;
  }
  if (!(peak > 0)) peak = 1e-9;

  final columns = [
    for (var i = 0; i < points.length; i++)
      points.length == 1
          ? interest.center.dx
          : interest.left + interest.width * i / (points.length - 1),
  ];
  final shown = points.length == 1
      ? interest.right
      : interest.left + interest.width * progress.clamp(0.0, 1.0);

  double yIn(Rect panel, double value, double low, double high) =>
      panel.bottom - ((value - low) / (high - low)).clamp(0.0, 1.0) *
          panel.height;

  final interestPoints = <Offset?>[];
  final pricePoints = <Offset?>[];
  final bars = <Rect?>[];
  final zeroY = funding.center.dy;
  final step = points.length > 1
      ? interest.width / math.max(1, points.length - 1)
      : interest.width;
  final barHalf = math.max(0.5, step * barWidth.clamp(0.05, 1.0) / 2);

  for (var i = 0; i < points.length; i++) {
    final point = points[i];
    final x = columns[i];
    final past = x > shown + 0.001;

    interestPoints.add(
      past || !point.openInterest.isFinite
          ? null
          : Offset(
              x,
              yIn(interest, point.openInterest, interestLow, interestHigh),
            ),
    );

    final price = point.price;
    pricePoints.add(
      past || price == null || !price.isFinite
          ? null
          : Offset(x, yIn(interest, price, priceLow, priceHigh)),
    );

    final rate = point.drawnFunding;
    if (past || rate == null || funding.height <= 0) {
      bars.add(null);
      continue;
    }
    // Bars grow off the zero line the way every exchange draws them:
    // positive funding — longs paying — above it, negative below.
    final reach = (rate.abs() / peak).clamp(0.0, 1.0) * funding.height / 2;
    bars.add(
      Rect.fromLTRB(
        x - barHalf,
        rate >= 0 ? zeroY - reach : zeroY,
        x + barHalf,
        rate >= 0 ? zeroY : zeroY + reach,
      ),
    );
  }

  return OpenInterestLayout(
    size: size,
    interestRect: interest,
    fundingRect: funding,
    columnX: columns,
    interestPoints: interestPoints,
    pricePoints: pricePoints,
    fundingBars: bars,
    interestMin: interestLow,
    interestMax: interestHigh,
    priceMin: priceLow,
    priceMax: priceHigh,
    fundingMax: peak,
    zeroY: zeroY,
  );
}

/// Open interest over price, funding beneath — the perpetual futures pair.
///
/// Open interest says how much money is in the trade and funding says which
/// side is paying to be there. Together with price they separate a rally that
/// is new buying from one that is shorts covering, and they mark the crowded
/// positioning that unwinds badly.
///
/// ```dart
/// OpenInterestChart(
///   points: [
///     for (final reading in readings)
///       OpenInterestPoint(
///         time: reading.time,
///         openInterest: reading.oi,
///         funding: reading.funding,
///         price: reading.close,
///       ),
///   ],
/// );
/// ```
class OpenInterestChart extends StatefulWidget {
  /// Creates an open interest and funding chart of [points].
  const OpenInterestChart({
    super.key,
    required this.points,
    this.interestColor = const Color(0xFF4C86CD),
    this.interestFillOpacity = 0.14,
    this.priceColor = const Color(0x99E9ECEF),
    this.showPrice = true,
    this.positiveFundingColor = const Color(0xFF2F9E44),
    this.negativeFundingColor = const Color(0xFFE03131),
    this.fundingShare = 0.32,
    this.panelGap = 8,
    this.barWidth = 0.6,
    this.fundingMax,
    this.lineWidth = 1.8,
    this.zeroLineColor = const Color(0x33909196),
    this.gridColor = const Color(0x10909196),
    this.showAxis = true,
    this.axisWidth = 56,
    this.axisSteps = 3,
    this.axisStyle,
    this.interestFormatter,
    this.fundingFormatter,
    this.crosshairColor = const Color(0x66E9ECEF),
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.onTouch,
    this.tooltipBuilder,
    this.defaultHeight = 220,
    this.semanticLabel,
  });

  /// The readings, oldest first.
  final List<OpenInterestPoint> points;

  /// What the open interest line is painted in.
  final Color interestColor;

  /// How solid the wash under it is; 0 draws none.
  final double interestFillOpacity;

  /// What the price line over the panel is painted in.
  final Color priceColor;

  /// Whether that price line is drawn at all.
  final bool showPrice;

  /// What funding the longs are paying is painted in.
  final Color positiveFundingColor;

  /// What funding the shorts are paying is painted in.
  final Color negativeFundingColor;

  /// How much of the height the funding panel takes.
  final double fundingShare;

  /// Space between the two panels.
  final double panelGap;

  /// How wide a funding bar is, as a share of the space per reading.
  final double barWidth;

  /// The rate the funding bars are scaled to; null takes the largest either
  /// way, which makes one chart's bars incomparable with another's.
  final double? fundingMax;

  /// How thick the lines are.
  final double lineWidth;

  /// The zero line through the funding panel.
  final Color zeroLineColor;

  /// The gridlines behind the upper panel.
  final Color gridColor;

  /// Whether the open interest axis is written down the right.
  final bool showAxis;

  /// How much room it takes.
  final double axisWidth;

  /// How many gaps it is divided into; 0 draws no gridlines.
  final int axisSteps;

  /// Style of the axis labels.
  final TextStyle? axisStyle;

  /// Writes an open interest value; null writes it with as few decimals as it
  /// needs.
  final String Function(double value)? interestFormatter;

  /// Writes a funding rate; null writes it in basis points.
  final String Function(double rate)? fundingFormatter;

  /// The line drawn down the reading under the finger.
  final Color crosshairColor;

  /// Space kept clear around the chart.
  final EdgeInsets padding;

  /// Painted behind the whole chart.
  final Color? backgroundColor;

  /// How long the lines take to draw in; zero draws them at once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build draws the lines in.
  final bool animateOnMount;

  /// Called with a reading and what it did when one is touched, and with
  /// nulls when the touch leaves.
  final void Function(OpenInterestPoint? point, OpenInterestMove? move)?
      onTouch;

  /// Builds the card shown over a touched reading; null shows its open
  /// interest, its funding and what the pair did.
  final Widget Function(
    BuildContext context,
    OpenInterestPoint point,
    OpenInterestMove move,
  )? tooltipBuilder;

  /// How tall the chart is in a box that sets no height.
  final double defaultHeight;

  /// What a screen reader announces for the chart.
  final String? semanticLabel;

  @override
  State<OpenInterestChart> createState() => _OpenInterestChartState();
}

class _OpenInterestChartState extends State<OpenInterestChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 256);
  OpenInterestLayout _layout = OpenInterestLayout.empty;
  List<OpenInterestMove> _moves = const [];
  int? _touched;

  @override
  void initState() {
    super.initState();
    _moves = openInterestMoves(widget.points);
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
  void didUpdateWidget(OpenInterestChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!identical(oldWidget.points, widget.points)) {
      _moves = openInterestMoves(widget.points);
      if (widget.animationDuration > Duration.zero) {
        _animation.forward(from: 0);
      }
    }
    if (_touched != null && _touched! >= widget.points.length) _touched = null;
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void _touch(Offset point) {
    if (_layout.isEmpty) return;
    final index = _layout.indexAt(point.dx);
    if (index == _touched) return;
    setState(() => _touched = index);
    widget.onTouch?.call(
      widget.points[index],
      index < _moves.length ? _moves[index] : OpenInterestMove.flat,
    );
  }

  void _clear() {
    if (_touched == null) return;
    setState(() => _touched = null);
    widget.onTouch?.call(null, null);
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
              constraints.hasBoundedWidth ? constraints.maxWidth : 420.0;
          final height = constraints.hasBoundedHeight &&
                  constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : widget.defaultHeight;
          _layout = layOutOpenInterest(
            widget.points,
            size: Size(width, height),
            fundingShare: widget.fundingShare,
            panelGap: widget.panelGap,
            axisWidth: widget.showAxis ? widget.axisWidth : 0,
            barWidth: widget.barWidth,
            fundingMax: widget.fundingMax,
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
                      painter: OpenInterestChartPainter(
                        chart: widget,
                        layout: _layout,
                        touched: touched,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (touched != null && touched < widget.points.length)
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
    final point = widget.points[index];
    final move = index < _moves.length ? _moves[index] : OpenInterestMove.flat;
    final build = widget.tooltipBuilder;
    final rate = point.drawnFunding;
    final child = build != null
        ? build(context, point, move)
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xEE1B1D22),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'OI ${_interest(widget, point.openInterest)}'
              '${rate == null ? '' : '   ${_funding(widget, rate)}'}'
              '\n${moveLabel(move)}',
              style: const TextStyle(color: Color(0xFFE9ECEF), fontSize: 11),
            ),
          );
    return Positioned(
      left: math.max(
        0,
        math.min(
          _layout.columnX[index] - 40,
          _layout.size.width - 140,
        ),
      ),
      top: 4,
      child: IgnorePointer(child: child),
    );
  }
}

/// What a [OpenInterestMove] is called, for a tooltip or a legend.
String moveLabel(OpenInterestMove move) => switch (move) {
      OpenInterestMove.newLongs => 'New longs',
      OpenInterestMove.longsClosing => 'Longs closing',
      OpenInterestMove.newShorts => 'New shorts',
      OpenInterestMove.shortsCovering => 'Shorts covering',
      OpenInterestMove.flat => '—',
    };

String _interest(OpenInterestChart chart, double value) {
  final format = chart.interestFormatter;
  if (format != null) return format(value);
  if (!value.isFinite) return '';
  if (value.abs() >= 1000) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

String _funding(OpenInterestChart chart, double rate) {
  final format = chart.fundingFormatter;
  if (format != null) return format(rate);
  if (!rate.isFinite) return '';
  // Basis points: the unit funding is quoted in everywhere.
  return '${(rate * 10000).toStringAsFixed(2)} bp';
}

/// Paints an [OpenInterestChart]: the interest line, the price over it and
/// the funding bars beneath.
class OpenInterestChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [layout].
  OpenInterestChartPainter({
    required this.chart,
    required this.layout,
    required this.touched,
    required this.textCache,
  });

  final OpenInterestChart chart;
  final OpenInterestLayout layout;

  /// The reading under the finger; null when none is.
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
        final value = layout.interestMin +
            (layout.interestMax - layout.interestMin) * i / chart.axisSteps;
        final y = layout.interestRect.bottom -
            layout.interestRect.height * i / chart.axisSteps;
        canvas.drawLine(
          Offset(layout.interestRect.left, y),
          Offset(layout.interestRect.right, y),
          grid,
        );
        if (chart.showAxis && chart.axisWidth > 0) {
          final painter = textCache.get(_interest(chart, value), axisStyle);
          painter.paint(
            canvas,
            Offset(
              layout.interestRect.right + 6,
              (y - painter.height / 2)
                  .clamp(0.0, math.max(0.0, size.height - painter.height)),
            ),
          );
        }
      }
    }

    // The interest line, with a wash under it.
    _line(
      canvas,
      layout.interestPoints,
      chart.interestColor,
      fillTo: chart.interestFillOpacity > 0
          ? layout.interestRect.bottom
          : null,
      fillOpacity: chart.interestFillOpacity,
    );
    if (chart.showPrice) {
      _line(canvas, layout.pricePoints, chart.priceColor);
    }

    // Funding: the zero line, then the bars hanging off it.
    if (layout.fundingRect.height > 0) {
      canvas.drawLine(
        Offset(layout.fundingRect.left, layout.zeroY),
        Offset(layout.fundingRect.right, layout.zeroY),
        Paint()
          ..color = chart.zeroLineColor
          ..strokeWidth = 1,
      );
      for (var i = 0; i < layout.fundingBars.length; i++) {
        final bar = layout.fundingBars[i];
        if (bar == null) continue;
        final rate = chart.points[i].drawnFunding ?? 0;
        final color = rate >= 0
            ? chart.positiveFundingColor
            : chart.negativeFundingColor;
        canvas.drawRect(
          bar,
          Paint()
            ..color = touched == null || touched == i
                ? color
                : color.withValues(alpha: 0.6),
        );
      }
    }

    final at = touched;
    if (at != null && at < layout.columnX.length) {
      canvas.drawLine(
        Offset(layout.columnX[at], layout.interestRect.top),
        Offset(layout.columnX[at], layout.fundingRect.bottom),
        Paint()
          ..color = chart.crosshairColor
          ..strokeWidth = 1,
      );
      final point = layout.interestPoints[at];
      if (point != null) {
        canvas.drawCircle(
          point,
          3,
          Paint()..color = chart.interestColor,
        );
      }
    }
  }

  void _line(
    Canvas canvas,
    List<Offset?> points,
    Color color, {
    double? fillTo,
    double fillOpacity = 0,
  }) {
    final path = Path();
    final fill = Path();
    Offset? previous;
    Offset? runStart;
    for (final at in points) {
      if (at == null) {
        if (fillTo != null && runStart != null && previous != null) {
          fill
            ..lineTo(previous.dx, fillTo)
            ..lineTo(runStart.dx, fillTo)
            ..close();
        }
        previous = null;
        runStart = null;
        continue;
      }
      if (previous == null) {
        path.moveTo(at.dx, at.dy);
        fill.moveTo(at.dx, at.dy);
        runStart = at;
      } else {
        path.lineTo(at.dx, at.dy);
        fill.lineTo(at.dx, at.dy);
      }
      previous = at;
    }
    if (fillTo != null && runStart != null && previous != null) {
      fill
        ..lineTo(previous.dx, fillTo)
        ..lineTo(runStart.dx, fillTo)
        ..close();
    }

    if (fillTo != null && fillOpacity > 0) {
      canvas.drawPath(
        fill,
        Paint()..color = color.withValues(alpha: fillOpacity),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = chart.lineWidth
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(OpenInterestChartPainter old) =>
      old.chart != chart || old.layout != layout || old.touched != touched;
}
