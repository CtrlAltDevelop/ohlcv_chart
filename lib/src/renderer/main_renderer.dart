import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../chart_type.dart';
import '../entity/candle_entity.dart';
import '../entity/k_line_entity.dart';
import '../indicators/resolved_indicator.dart';
import '../price_axis_scale.dart';
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

  @override
  void drawVerticalText(Canvas canvas, TextStyle textStyle, int gridRows) {
    final double rowSpace = chartRect.height / gridRows;
    for (var i = 0; i <= gridRows; ++i) {
      if (i == gridRows && hasPanesBelow) continue;
      // Read the price off the grid line the label belongs to, so a
      // logarithmic axis labels itself as correctly as a linear one.
      final double value = getValue(chartRect.top + rowSpace * i);
      final TextSpan span = TextSpan(text: formatAxis(value), style: textStyle);
      final TextPainter tp = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      );
      tp.layout();

      final padding = chartStyle.axisLabelPadding;
      final double offsetX = switch (verticalTextAlignment) {
        VerticalTextAlignment.left => padding,
        VerticalTextAlignment.right => chartRect.width - tp.width - padding,
      };
      final double offsetY = i == 0
          ? topPadding
          : rowSpace * i - tp.height + topPadding;

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
  void drawGrid(Canvas canvas, int gridRows, int gridColumns) {
    // final int gridRows = 4, gridColumns = 4;
    final double rowSpace = chartRect.height / gridRows;
    for (int i = 0; i <= gridRows; i++) {
      canvas.drawLine(
        Offset(0, rowSpace * i + topPadding),
        Offset(chartRect.width, rowSpace * i + topPadding),
        gridPaint,
      );
    }
    final double columnSpace = chartRect.width / gridColumns;
    for (int i = 0; i <= gridColumns; i++) {
      canvas.drawLine(
        Offset(columnSpace * i, 0),
        Offset(columnSpace * i, chartRect.bottom),
        gridPaint,
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
