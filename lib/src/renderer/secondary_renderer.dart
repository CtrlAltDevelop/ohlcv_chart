import 'package:flutter/material.dart';

import '../entity/macd_entity.dart';
import '../k_chart_widget.dart' show SecondaryState;
import 'base_chart_renderer.dart';

class SecondaryRenderer extends BaseChartRenderer<MACDEntity> {
  SecondaryRenderer(
    Rect mainRect,
    double maxValue,
    double minValue,
    double topPadding,
    this.state,
    int fixedLength,
    this.chartStyle,
    this.chartColors,
  ) : super(
        chartRect: mainRect,
        maxValue: maxValue,
        minValue: minValue,
        topPadding: topPadding,
        fixedLength: fixedLength,
        gridColor: chartColors.gridColor,
      ) {
    mMACDWidth = chartStyle.macdWidth;
  }

  late double mMACDWidth;
  SecondaryState state;
  final ChartStyle chartStyle;
  final ChartColors chartColors;

  @override
  double getValue(double y) {
    return maxValue - (y - chartRect.top) / scaleY;
  }

  @override
  String get name {
    switch (state) {
      case SecondaryState.MACD:
        return 'MACD';
      case SecondaryState.RSI:
        return 'RSI';
      case SecondaryState.KDJ:
        return 'KDJ';
      case SecondaryState.WR:
        return 'WR';
      case SecondaryState.CCI:
        return 'CCI';
    }
  }

  @override
  void drawChart(
    MACDEntity lastPoint,
    MACDEntity curPoint,
    double lastX,
    double curX,
    Size size,
    Canvas canvas,
  ) {
    // First: Draw the indicator lines and bars
    switch (state) {
      case SecondaryState.MACD:
        drawMACD(curPoint, canvas, curX, lastPoint, lastX);
      case SecondaryState.KDJ:
        drawLine(
          lastPoint.k,
          curPoint.k,
          canvas,
          lastX,
          curX,
          chartColors.kColor,
        );
        drawLine(
          lastPoint.d,
          curPoint.d,
          canvas,
          lastX,
          curX,
          chartColors.dColor,
        );
        drawLine(
          lastPoint.j,
          curPoint.j,
          canvas,
          lastX,
          curX,
          chartColors.jColor,
        );
      case SecondaryState.RSI:
        drawLine(
          lastPoint.rsi,
          curPoint.rsi,
          canvas,
          lastX,
          curX,
          chartColors.rsiColor,
        );
      case SecondaryState.WR:
        drawLine(
          lastPoint.r,
          curPoint.r,
          canvas,
          lastX,
          curX,
          chartColors.rsiColor,
        );
      case SecondaryState.CCI:
        drawLine(
          lastPoint.cci,
          curPoint.cci,
          canvas,
          lastX,
          curX,
          chartColors.rsiColor,
        );
    }
  }

  void drawMACD(
    MACDEntity curPoint,
    Canvas canvas,
    double curX,
    MACDEntity lastPoint,
    double lastX,
  ) {
    final macd = curPoint.macd ?? 0;
    final macdY = getY(macd);
    final r = mMACDWidth / 2;
    final zeroy = getY(0);
    if (macd > 0) {
      canvas.drawRect(
        Rect.fromLTRB(curX - r, macdY, curX + r, zeroy),
        chartPaint..color = chartColors.upColor,
      );
    } else {
      canvas.drawRect(
        Rect.fromLTRB(curX - r, zeroy, curX + r, macdY),
        chartPaint..color = chartColors.dnColor,
      );
    }
    if (lastPoint.dif != 0) {
      drawLine(
        lastPoint.dif,
        curPoint.dif,
        canvas,
        lastX,
        curX,
        chartColors.difColor,
      );
    }
    if (lastPoint.dea != 0) {
      drawLine(
        lastPoint.dea,
        curPoint.dea,
        canvas,
        lastX,
        curX,
        chartColors.deaColor,
      );
    }
  }

  @override
  void drawText(Canvas canvas, MACDEntity data, double x) {
    List<TextSpan>? children;
    switch (state) {
      case SecondaryState.MACD:
        children = [
          TextSpan(
            text: 'MACD(12,26,9)    ',
            style: getTextStyle(chartColors.defaultTextColor),
          ),
          if (data.macd != 0)
            TextSpan(
              text: 'MACD:${format(data.macd)}    ',
              style: getTextStyle(chartColors.macdColor),
            ),
          if (data.dif != 0)
            TextSpan(
              text: 'DIF:${format(data.dif)}    ',
              style: getTextStyle(chartColors.difColor),
            ),
          if (data.dea != 0)
            TextSpan(
              text: 'DEA:${format(data.dea)}    ',
              style: getTextStyle(chartColors.deaColor),
            ),
        ];
      case SecondaryState.KDJ:
        children = [
          TextSpan(
            text: 'KDJ(9,1,3)    ',
            style: getTextStyle(chartColors.defaultTextColor),
          ),
          if (data.macd != 0)
            TextSpan(
              text: 'K:${format(data.k)}    ',
              style: getTextStyle(chartColors.kColor),
            ),
          if (data.dif != 0)
            TextSpan(
              text: 'D:${format(data.d)}    ',
              style: getTextStyle(chartColors.dColor),
            ),
          if (data.dea != 0)
            TextSpan(
              text: 'J:${format(data.j)}    ',
              style: getTextStyle(chartColors.jColor),
            ),
        ];
      case SecondaryState.RSI:
        children = [
          TextSpan(
            text: 'RSI(14):${format(data.rsi)}    ',
            style: getTextStyle(chartColors.rsiColor),
          ),
        ];
      case SecondaryState.WR:
        children = [
          TextSpan(
            text: 'WR(14):${format(data.r)}    ',
            style: getTextStyle(chartColors.rsiColor),
          ),
        ];
      case SecondaryState.CCI:
        children = [
          TextSpan(
            text: 'CCI(14):${format(data.cci)}    ',
            style: getTextStyle(chartColors.rsiColor),
          ),
        ];
    }
    final tp = TextPainter(
      text: TextSpan(children: children),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(x, chartRect.top - topPadding));
  }

  @override
  void drawVerticalText(Canvas canvas, TextStyle textStyle, int gridRows) {
    final maxTp = TextPainter(
      text: TextSpan(text: format(maxValue), style: textStyle),
      textDirection: TextDirection.ltr,
    );
    maxTp.layout();
    final minTp = TextPainter(
      text: TextSpan(text: format(minValue), style: textStyle),
      textDirection: TextDirection.ltr,
    );
    minTp.layout();

    maxTp.paint(
      canvas,
      Offset(chartRect.width - maxTp.width, chartRect.top - topPadding),
    );
    minTp.paint(
      canvas,
      Offset(chartRect.width - minTp.width, chartRect.bottom - minTp.height),
    );
  }

  @override
  void drawGrid(Canvas canvas, int gridRows, int gridColumns) {
    canvas.drawLine(
      Offset(0, chartRect.top - topPadding + 2),
      Offset(chartRect.width, chartRect.top - topPadding + 2),
      separatedPaint,
    );
    canvas.drawLine(
      Offset(0, chartRect.bottom),
      Offset(chartRect.width, chartRect.bottom),
      gridPaint,
    );
    final columnSpace = chartRect.width / gridColumns;
    for (int i = 0; i <= gridColumns; i++) {
      canvas.drawLine(
        Offset(columnSpace * i, chartRect.top - topPadding),
        Offset(columnSpace * i, chartRect.bottom),
        gridPaint,
      );
    }

    switch (state) {
      case SecondaryState.RSI:
        drawHorizontalLine(canvas, 30, chartColors.gridColor);
        drawHorizontalLine(canvas, 50, chartColors.gridColor, dashed: false);
        drawHorizontalLine(canvas, 70, chartColors.gridColor);
      case SecondaryState.WR:
        drawHorizontalLine(canvas, -30, chartColors.gridColor);
        drawHorizontalLine(canvas, -50, chartColors.gridColor);
        drawHorizontalLine(canvas, -70, chartColors.gridColor);
      case SecondaryState.KDJ:
        drawHorizontalLine(canvas, 20, chartColors.gridColor);
        drawHorizontalLine(canvas, 50, chartColors.gridColor, dashed: false);
        drawHorizontalLine(canvas, 80, chartColors.gridColor);
      case SecondaryState.MACD:
        drawHorizontalLine(canvas, 0, chartColors.gridColor, dashed: false);
      case SecondaryState.CCI:
        drawHorizontalLine(canvas, -100, chartColors.gridColor);
        drawHorizontalLine(canvas, 0, chartColors.gridColor, dashed: false);
        drawHorizontalLine(canvas, 100, chartColors.gridColor);
    }
  }
}
