import 'package:flutter/material.dart';

import '../entity/candle_entity.dart';
import '../entity/k_line_entity.dart';
import '../indicators/resolved_indicator.dart';
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
    this.hasPanesBelow,
  ) : super(
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
  /// a different indicator starts a new one.
  void drawLegends(Canvas canvas, int index, double x) {
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

    var row = 0;
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
    if (isLine) {
      drawPolyline(lastPoint.close, curPoint.close, canvas, lastX, curX);
    } else {
      drawCandle(curPoint, canvas, curX);
    }
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
    double curX,
  ) {
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
      final double value = (gridRows - i) * rowSpace / scaleY + minValue;
      final TextSpan span = TextSpan(text: format(value), style: textStyle);
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

  @override
  double getValue(double y) {
    return maxValue - (y - chartRect.top) / scaleY;
  }

  @override
  String get name => 'Price';

  @override
  double getY(double y) {
    //For TrendLine
    updateTrendLineData();
    return (maxValue - y) * scaleY + _contentRect.top;
  }

  void updateTrendLineData() {
    trendLineMax = maxValue;
    trendLineScale = scaleY;
    trendLineContentRec = _contentRect.top;
  }
}
