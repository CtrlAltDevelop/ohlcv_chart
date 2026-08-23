import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../chart_type.dart';
import '../entity/candle_entity.dart';
import '../entity/k_line_entity.dart';
import '../indicators/resolved_indicator.dart';
import '../price_axis_scale.dart';
import '../utils/axis_ticks.dart';
import 'base_chart_renderer.dart';
import 'series_painter.dart';

/// Which side of the main chart the price axis labels sit on.
enum VerticalTextAlignment {
  /// Labels are drawn against the left edge.
  left,

  /// Labels are drawn against the right edge.
  right,
}

//For TrendLine
double? trendLineMax;
double? trendLineScale;
double? trendLineContentRec;

class MainRenderer extends BaseChartRenderer<CandleEntity> {
  MainRenderer(
    Rect mainRect,
    double maxValue,
    double minValue,
    double topPadding,
    this.overlays,
    this.isLine,
    int fixedLength,
    this.chartStyle,
    this.chartColors,
    this.scaleX,
    this.verticalTextAlignment,
    this.hasPanesBelow, {
    this.priceScale = PriceAxisScale.linear,
    this.percentBase,
    this.chartType = ChartType.candles,
    this.baselinePrice,
  }) : super(
         chartRect: mainRect,
         maxValue: maxValue,
         minValue: minValue,
         topPadding: topPadding,
         fixedLength: fixedLength,
         gridColor: chartColors.gridColor,
         separatorColor: chartColors.effectiveSeparatorColor,
         gridColumnColor: chartColors.effectiveGridColumnColor,
         gridStrokeWidth: chartStyle.gridStrokeWidth,
         separatorWidth: chartStyle.separatorWidth,
         labelCornerRadius: chartStyle.labelCornerRadius,
         legendPadding: chartStyle.legendPadding,
         legendBgColor: chartColors.effectiveLegendBgColor,
       ) {
    mCandleWidth = chartStyle.candleWidth;
    mCandleLineWidth = chartStyle.candleLineWidth;
    mLinePaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = mLineStrokeWidth
      ..color = chartColors.kLineColor;
    _contentRect = Rect.fromLTRB(
      chartRect.left,
      chartRect.top + _contentPadding,
      chartRect.right,
      chartRect.bottom - _contentPadding,
    );
    if (maxValue == minValue) {
      maxValue *= 1.5;
      minValue /= 2;
    }
    scaleY = _contentRect.height / (maxValue - minValue);

    // The axis is drawn in transformed space — prices for a linear axis, their
    // logarithms for a logarithmic one — so one scale factor covers both.
    _transformedMax = _transform(maxValue);
    final span = _transformedMax - _transform(minValue);
    _transformedScaleY = span <= 0 ? scaleY : _contentRect.height / span;
  }

  /// What the candle area draws for each candle.
  final ChartType chartType;

  /// The level a [ChartType.baseline] chart is washed towards.
  final double? baselinePrice;

  /// How the price axis spaces its values.
  final PriceAxisScale priceScale;

  /// The close a [PriceAxisScale.percentage] axis measures against, which is
  /// the first candle in view.
  final double? percentBase;

  late final double _transformedMax;
  late final double _transformedScaleY;

  /// Whether prices really are spaced by ratio.
  ///
  /// A window holding zero or a negative price has no logarithm to space by, so
  /// it falls back to a linear axis rather than drawing nothing.
  bool get isLogarithmic =>
      priceScale == PriceAxisScale.logarithmic && minValue > 0;

  double _transform(double price) =>
      isLogarithmic ? math.log(price <= 0 ? _logFloor : price) : price;

  double _untransform(double value) => isLogarithmic ? math.exp(value) : value;

  /// Stands in for a price a logarithm cannot take.
  static const double _logFloor = 1e-9;

  /// Formats [price] the way the axis reads it.
  ///
  /// A percentage axis shows the move away from [percentBase]; every other
  /// axis shows the price itself.
  String formatAxis(double price) {
    final base = percentBase;
    if (priceScale != PriceAxisScale.percentage || base == null || base == 0) {
      return format(price);
    }
    final move = (price / base - 1) * 100;
    return '${move >= 0 ? '+' : ''}${move.toStringAsFixed(2)}%';
  }

  late double mCandleWidth;
  late double mCandleLineWidth;

  /// Indicators drawn over the candles, with their values.
  List<ResolvedIndicator> overlays;
  bool isLine;

  // The content area to be drawn
  late Rect _contentRect;
  final _contentPadding = 5.0;
  final ChartStyle chartStyle;
  final ChartColors chartColors;
  final double mLineStrokeWidth = 1.0;
  double scaleX;
  late Paint mLinePaint;
  final VerticalTextAlignment verticalTextAlignment;

  /// Whether a volume or indicator pane is stacked under the main chart.
  ///
  /// When one is, the bottom-most price label is left out: it would sit on that
  /// pane's own legend, and the low of the range is already marked on the
  /// candle that set it.
  final bool hasPanesBelow;

  /// Draws the overlay legends, one row per kind of indicator.
  ///
  /// Repeated averages share a row — `MA5 MA10 MA20` reads as one line — while
  /// a different indicator starts a new one. [startRow] leaves room above for
  /// rows someone else has already taken, such as the OHLC legend.
  void drawLegends(Canvas canvas, int index, double x, {int startRow = 0}) {
    if (isLine) return;

    final rows = <String, List<InlineSpan>>{};
    for (final overlay in overlays) {
      final spans = rows.putIfAbsent(overlay.indicator.group, () => []);
      for (var line = 0; line < overlay.indicator.lines.length; line++) {
        final value = overlay.valueAt(line, index);
        if (value == null || !value.isFinite) continue;
        spans.add(
          TextSpan(
            text:
                '${overlay.indicator.lines[line].label}:'
                '${format(value)}    ',
            style: getTextStyle(overlay.colorFor(line, chartColors)),
          ),
        );
      }
    }

    var row = startRow;
    for (final spans in rows.values) {
      if (spans.isEmpty) continue;
      final tp = TextPainter(
        text: TextSpan(children: spans),
        textDirection: TextDirection.ltr,
      )..layout();
      paintLegend(
        canvas,
        tp,
        Offset(
          x,
          chartRect.top -
              topPadding +
              row * (tp.height + chartStyle.legendSpacing),
        ),
      );
      row++;
    }
  }

  /// Draws every overlay's lines and dots across the visible candles.
  void drawOverlays(
    Canvas canvas,
    List<KLineEntity> candles, {
    required int start,
    required int stop,
    required double Function(int index) xOf,
  }) {
    if (isLine || overlays.isEmpty) return;

    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        chartRect.left,
        chartRect.top - topPadding,
        chartRect.right,
        chartRect.bottom,
      ),
    );
    for (final overlay in overlays) {
      paintIndicatorSeries(
        canvas,
        resolved: overlay,
        candles: candles,
        start: start,
        stop: stop,
        xOf: xOf,
        yOf: getY,
        colors: chartColors,
        strokeWidth: chartStyle.indicatorLineWidth,
        barWidth: chartStyle.candleWidth,
      );
    }
    canvas.restore();
  }

  /// Draws every overlay's volume profile, behind the candles.
  ///
  /// The bars run in from the far side of the chart — the side the price
  /// labels are not on — so they sit behind the newest candles rather than
  /// over the ones being read. Each is as long as its share of the busiest
  /// band, split into the volume that traded on rising candles and the volume
  /// that traded on falling ones, with the point of control picked out and the
  /// value area shaded across the whole width.
  void drawProfiles(Canvas canvas) {
    for (final overlay in overlays) {
      final profile = overlay.profile;
      if (profile == null || profile.isEmpty) continue;

      final peak = profile.peakVolume;
      final widest = chartRect.width * chartStyle.profileWidth.clamp(0.0, 1.0);
      final fromLeft = verticalTextAlignment == VerticalTextAlignment.right;
      final up = Paint()
        ..isAntiAlias = true
        ..color = chartColors.effectiveProfileUpColor;
      final down = Paint()
        ..isAntiAlias = true
        ..color = chartColors.effectiveProfileDownColor;
      final pocPaint = Paint()
        ..isAntiAlias = true
        ..color = overlay.colorFor(0, chartColors);

      final areaTop = profile.valueAreaHigh;
      final areaBottom = profile.valueAreaLow;
      if (areaTop != null && areaBottom != null) {
        canvas.drawRect(
          Rect.fromLTRB(
            chartRect.left,
            getY(areaTop),
            chartRect.right,
            getY(areaBottom),
          ),
          Paint()..color = chartColors.effectiveProfileValueAreaColor,
        );
      }

      for (var i = 0; i < profile.bins.length; i++) {
        final bin = profile.bins[i];
        if (bin.volume <= 0) continue;

        final top = getY(bin.high);
        final bottom = getY(bin.low);
        // A hairline gap keeps neighbouring bands legible as bands.
        final height = (bottom - top - 1).clamp(1.0, double.infinity);
        final length = widest * bin.volume / peak;
        // The busiest band is drawn whole in its own colour, so it reads as
        // one level rather than as the widest of a run of split bars.
        if (i == profile.pointOfControl) {
          canvas.drawRect(
            _profileBar(fromLeft, top, height, 0, length),
            pocPaint,
          );
          continue;
        }

        // The rising share runs from the outside in, so the split sits at the
        // same place on every band and the two colours read as one bar.
        final rising = length * (bin.upVolume / bin.volume).clamp(0.0, 1.0);
        if (rising > 0) {
          canvas.drawRect(_profileBar(fromLeft, top, height, 0, rising), up);
        }
        if (length - rising > 0) {
          canvas.drawRect(
            _profileBar(fromLeft, top, height, rising, length),
            down,
          );
        }
      }
    }
  }

  /// One slice of a profile bar, [from] to [to] pixels along its length.
  ///
  /// [fromLeft] measures the length from the left edge of the chart rather
  /// than from the right, so the bars grow away from the price labels.
  Rect _profileBar(
    bool fromLeft,
    double top,
    double height,
    double from,
    double to,
  ) => fromLeft
      ? Rect.fromLTWH(chartRect.left + from, top, to - from, height)
      : Rect.fromLTWH(chartRect.right - to, top, to - from, height);

  @override
  void drawChart(
    CandleEntity lastPoint,
    CandleEntity curPoint,
    double lastX,
    double curX,
    Size size,
    Canvas canvas,
  ) {
    switch (chartType) {
      case ChartType.candles:
        drawCandle(curPoint, canvas, curX);
      case ChartType.bars:
        drawBar(curPoint, canvas, curX);
      case ChartType.line:
        drawPolyline(
          lastPoint.close,
          curPoint.close,
          canvas,
          lastX,
          curX,
          fill: false,
        );
      case ChartType.area:
        drawPolyline(lastPoint.close, curPoint.close, canvas, lastX, curX);
      case ChartType.baseline:
        drawBaselineSegment(
          lastPoint.close,
          curPoint.close,
          canvas,
          lastX,
          curX,
        );
    }
  }

  /// Draws one OHLC bar: the high-low range, with the open ticked left and the
  /// close ticked right.
  void drawBar(CandleEntity point, Canvas canvas, double curX) {
    final high = getY(point.high);
    final low = getY(point.low);
    final open = getY(point.open);
    final close = getY(point.close);
    // In screen space a rising bar closes above where it opened.
    final rising = open >= close;
    final tick = mCandleWidth / 2;

    chartPaint
      ..color = rising ? chartColors.upColor : chartColors.dnColor
      ..strokeWidth = mCandleLineWidth
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTRB(
        curX - mCandleLineWidth / 2,
        high,
        curX + mCandleLineWidth / 2,
        low,
      ),
      chartPaint,
    );
    canvas.drawRect(
      Rect.fromLTRB(
        curX - tick,
        open - mCandleLineWidth / 2,
        curX,
        open + mCandleLineWidth / 2,
      ),
      chartPaint,
    );
    canvas.drawRect(
      Rect.fromLTRB(
        curX,
        close - mCandleLineWidth / 2,
        curX + tick,
        close + mCandleLineWidth / 2,
      ),
      chartPaint,
    );
  }

  /// Draws one segment of a baseline chart: the stretch of line between two
  /// closes, washed towards the baseline in the colour of the side it is on.
  void drawBaselineSegment(
    double lastPrice,
    double curPrice,
    Canvas canvas,
    double lastXO,
    double curX,
  ) {
    final baseline = baselinePrice;
    if (baseline == null) {
      drawPolyline(lastPrice, curPrice, canvas, lastXO, curX);
      return;
    }

    final lastX = lastXO == curX ? 0.0 : lastXO;
    final baseY = getY(baseline);
    final lastY = getY(lastPrice);
    final curY = getY(curPrice);

    // Which side of the level this stretch sits on decides its colour; a
    // stretch that straddles it takes the side it ends on.
    final above = curPrice >= baseline;
    final color = above ? chartColors.upColor : chartColors.dnColor;

    canvas.drawPath(
      Path()
        ..moveTo(lastX, baseY)
        ..lineTo(lastX, lastY)
        ..lineTo(curX, curY)
        ..lineTo(curX, baseY)
        ..close(),
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
    canvas.drawLine(
      Offset(lastX, lastY),
      Offset(curX, curY),
      Paint()
        ..color = color
        ..strokeWidth = (mLineStrokeWidth / scaleX).clamp(0.1, 1.0)
        ..isAntiAlias = true,
    );
  }

  Shader? mLineFillShader;
  Path? mLinePath;
  Path? mLineFillPath;
  Paint mLineFillPaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  // Draw a line graph
  void drawPolyline(
    double lastPrice,
    double curPrice,
    Canvas canvas,
    double lastXO,
    double curX, {
    bool fill = true,
  }) {
    double lastX = lastXO;
    //    drawLine(lastPrice + 100, curPrice + 100, canvas, lastX, curX, ChartColors.kLineColor);
    mLinePath ??= Path();

    //    if (lastX == curX) {
    //      mLinePath.moveTo(lastX, getY(lastPrice));
    //    } else {
    ////      mLinePath.lineTo(curX, getY(curPrice));
    //      mLinePath.cubicTo(
    //          (lastX + curX) / 2, getY(lastPrice), (lastX + curX) / 2, getY(curPrice), curX, getY(curPrice));
    //    }
    if (lastX == curX) lastX = 0; // Fill at the starting position
    mLinePath!.moveTo(lastX, getY(lastPrice));
    mLinePath!.cubicTo(
      (lastX + curX) / 2,
      getY(lastPrice),
      (lastX + curX) / 2,
      getY(curPrice),
      curX,
      getY(curPrice),
    );

    if (!fill) {
      canvas.drawPath(
        mLinePath!,
        mLinePaint..strokeWidth = (mLineStrokeWidth / scaleX).clamp(0.1, 1.0),
      );
      mLinePath!.reset();
      return;
    }

    // Draw shadows
    mLineFillShader ??=
        LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          tileMode: TileMode.clamp,
          colors: [chartColors.lineFillColor, chartColors.lineFillInsideColor],
        ).createShader(
          Rect.fromLTRB(
            chartRect.left,
            chartRect.top,
            chartRect.right,
            chartRect.bottom,
          ),
        );
    mLineFillPaint.shader = mLineFillShader;

    mLineFillPath ??= Path();

    mLineFillPath!.moveTo(lastX, chartRect.height + chartRect.top);
    mLineFillPath!.lineTo(lastX, getY(lastPrice));
    mLineFillPath!.cubicTo(
      (lastX + curX) / 2,
      getY(lastPrice),
      (lastX + curX) / 2,
      getY(curPrice),
      curX,
      getY(curPrice),
    );
    mLineFillPath!.lineTo(curX, chartRect.height + chartRect.top);
    mLineFillPath!.close();

    canvas.drawPath(mLineFillPath!, mLineFillPaint);
    mLineFillPath!.reset();

    canvas.drawPath(
      mLinePath!,
      mLinePaint..strokeWidth = (mLineStrokeWidth / scaleX).clamp(0.1, 1.0),
    );
    mLinePath!.reset();
  }

  void drawCandle(CandleEntity curPoint, Canvas canvas, double curX) {
    final high = getY(curPoint.high);
    final low = getY(curPoint.low);
    final open = getY(curPoint.open);
    final close = getY(curPoint.close);
    final double r = mCandleWidth / 2;
    final double lineR = mCandleLineWidth / 2;

    // In screen space a rising candle closes above where it opened, so its
    // close carries the smaller y.
    final isRising = open >= close;
    var bodyTop = isRising ? close : open;
    var bodyBottom = isRising ? open : close;

    // A doji would otherwise vanish; keep it one stroke tall.
    if (bodyBottom - bodyTop < mCandleLineWidth) {
      final centre = (bodyTop + bodyBottom) / 2;
      bodyTop = centre - mCandleLineWidth / 2;
      bodyBottom = centre + mCandleLineWidth / 2;
    }

    chartPaint
      ..color = isRising ? chartColors.upColor : chartColors.dnColor
      ..style = PaintingStyle.fill;

    // The wick spans the whole high-low range, behind the body.
    canvas.drawRect(
      Rect.fromLTRB(curX - lineR, high, curX + lineR, low),
      chartPaint,
    );

    final body = Rect.fromLTRB(curX - r, bodyTop, curX + r, bodyBottom);
    if (chartStyle.hollowUpCandles &&
        isRising &&
        bodyBottom - bodyTop > mCandleLineWidth * 3) {
      // Clear the wick out of the body, then outline it.
      canvas.drawRect(body, Paint()..color = chartColors.bgColor);
      canvas.drawRect(
        body.deflate(mCandleLineWidth / 2),
        chartPaint
          ..style = PaintingStyle.stroke
          ..strokeWidth = mCandleLineWidth,
      );
      chartPaint.style = PaintingStyle.fill;
    } else {
      canvas.drawRect(body, chartPaint);
    }
  }

  List<double>? _priceTicks;

  /// The prices this axis rules and labels itself by.
  ///
  /// Round numbers chosen first, then placed wherever they fall — so the axis
  /// reads `69000, 69500, 70000` rather than whatever prices happen to land on
  /// evenly spaced pixels. A logarithmic axis steps by ratio, a percentage one
  /// picks round percentages and converts them back to prices.
  List<double> priceTicks(int gridRows) {
    final cached = _priceTicks;
    if (cached != null) return cached;

    final target = math.max(2, gridRows ~/ 2);
    final base = percentBase;
    final List<double> ticks;
    if (priceScale == PriceAxisScale.percentage && base != null && base != 0) {
      final low = (minValue / base - 1) * 100;
      final high = (maxValue / base - 1) * 100;
      ticks = [
        for (final move in niceTicks(low, high, target: target))
          base * (1 + move / 100),
      ];
    } else if (isLogarithmic) {
      ticks = niceLogTicks(minValue, maxValue, target: target);
    } else {
      ticks = niceTicks(minValue, maxValue, target: target);
    }

    // A range too flat to divide would otherwise leave the axis blank; fall
    // back to the two ends it does have.
    return _priceTicks = ticks.isEmpty ? [minValue, maxValue] : ticks;
  }

  @override
  void drawVerticalText(Canvas canvas, TextStyle textStyle, int gridRows) {
    final padding = chartStyle.axisLabelPadding;

    for (final value in priceTicks(gridRows)) {
      final y = getY(value);
      if (!y.isFinite) continue;

      final TextSpan span = TextSpan(text: formatAxis(value), style: textStyle);
      final TextPainter tp = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      )..layout();

      // The label sits above its own line, and is nudged back inside the pane
      // at either end so the top one clears the legend and the bottom one is
      // not clipped away.
      final offsetY = (y - tp.height).clamp(
        chartRect.top - topPadding,
        chartRect.bottom - tp.height,
      );

      // With a pane stacked underneath, a label near the bottom edge would
      // print over that pane's legend.
      if (hasPanesBelow && chartRect.bottom - y < tp.height) continue;

      final double offsetX = switch (verticalTextAlignment) {
        VerticalTextAlignment.left => padding,
        VerticalTextAlignment.right => chartRect.width - tp.width - padding,
      };

      if (chartStyle.axisLabelBackground) {
        canvas.drawRRect(
          RRect.fromLTRBR(
            offsetX - padding / 2,
            offsetY,
            offsetX + tp.width + padding / 2,
            offsetY + tp.height,
            Radius.circular(chartStyle.labelCornerRadius),
          ),
          Paint()..color = chartColors.effectiveAxisLabelBgColor,
        );
      }
      tp.paint(canvas, Offset(offsetX, offsetY));
    }
  }

  @override
  void drawGrid(
    Canvas canvas,
    int gridRows,
    int gridColumns, {
    List<double>? columnXs,
  }) {
    // Rule the pane where the labels are, not on evenly spaced pixels.
    for (final value in priceTicks(gridRows)) {
      final y = getY(value);
      if (!y.isFinite || y < chartRect.top || y > chartRect.bottom) continue;
      canvas.drawLine(Offset(0, y), Offset(chartRect.width, y), gridPaint);
    }

    final columns =
        columnXs ??
        [
          for (int i = 0; i <= gridColumns; i++)
            chartRect.width / gridColumns * i,
        ];
    for (final x in columns) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, chartRect.bottom),
        columnGridPaint,
      );
    }
  }

  /// The price at [y], the exact inverse of [getY].
  @override
  double getValue(double y) => _untransform(
    _transformedMax - (y - _contentRect.top) / _transformedScaleY,
  );

  @override
  String get name => 'Price';

  @override
  double getY(double y) {
    //For TrendLine
    updateTrendLineData();
    return (_transformedMax - _transform(y)) * _transformedScaleY +
        _contentRect.top;
  }

  void updateTrendLineData() {
    trendLineMax = maxValue;
    trendLineScale = scaleY;
    trendLineContentRec = _contentRect.top;
  }
}
