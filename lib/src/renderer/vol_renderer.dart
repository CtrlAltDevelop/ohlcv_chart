import 'package:flutter/material.dart';

import '../entity/volume_entity.dart';
import '../extension/num_ext.dart';
import '../utils/number_util.dart';
import 'base_chart_renderer.dart';

class VolRenderer extends BaseChartRenderer<VolumeEntity> {
  VolRenderer(
    Rect mainRect,
    double maxValue,
    double minValue,
    double topPadding,
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
    mVolWidth = chartStyle.volWidth;
  }

  late double mVolWidth;
  final ChartStyle chartStyle;
  final ChartColors chartColors;

  @override
  void drawChart(
    VolumeEntity lastPoint,
    VolumeEntity curPoint,
    double lastX,
    double curX,
    Size size,
    Canvas canvas,
  ) {
    final r = mVolWidth / 2;
    final top = getVolY(curPoint.vol);
    final bottom = chartRect.bottom;
    if (curPoint.vol != 0) {
      canvas.drawRect(
        Rect.fromLTRB(curX - r, top, curX + r, bottom),
        chartPaint
          ..color = curPoint.close > curPoint.open
              ? chartColors.upColor
              : chartColors.dnColor,
      );
    }

    if (lastPoint.ma5Volume != 0) {
      drawLine(
        lastPoint.ma5Volume,
        curPoint.ma5Volume,
        canvas,
        lastX,
        curX,
        chartColors.ma5Color,
      );
    }

    if (lastPoint.ma10Volume != 0) {
      drawLine(
        lastPoint.ma10Volume,
        curPoint.ma10Volume,
        canvas,
        lastX,
        curX,
        chartColors.ma10Color,
      );
    }
  }

  @override
  double getValue(double y) {
    return maxValue - (y - chartRect.top) / scaleY;
  }

  @override
  String get name => 'VOL';

  double getVolY(double value) =>
      (maxValue - value) * (chartRect.height / maxValue) + chartRect.top;

  @override
  void drawText(Canvas canvas, VolumeEntity data, double x) {
    final TextSpan span = TextSpan(
      children: [
        TextSpan(
          text: 'VOL:${NumberUtil.format(data.vol)}    ',
          style: getTextStyle(chartColors.volColor),
        ),
        if (data.ma5Volume.notNullOrZero)
          TextSpan(
            text: 'MA5:${NumberUtil.format(data.ma5Volume)}    ',
            style: getTextStyle(chartColors.ma5Color),
          ),
        if (data.ma10Volume.notNullOrZero)
          TextSpan(
            text: 'MA10:${NumberUtil.format(data.ma10Volume)}    ',
            style: getTextStyle(chartColors.ma10Color),
          ),
      ],
    );
    final TextPainter tp = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(x, chartRect.top - topPadding));
  }

  @override
  void drawVerticalText(Canvas canvas, TextStyle textStyle, int gridRows) {
    final TextSpan span = TextSpan(
      text: NumberUtil.format(maxValue),
      style: textStyle,
    );
    final TextPainter tp = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(
      canvas,
      Offset(chartRect.width - tp.width, chartRect.top - topPadding),
    );
  }

  @override
  void drawGrid(Canvas canvas, int gridRows, int gridColumns) {
    // Add top line for better separation
    canvas.drawLine(
      Offset(0, chartRect.top - topPadding),
      Offset(chartRect.width, chartRect.top - topPadding),
      separatedPaint,
    );
    canvas.drawLine(
      Offset(0, chartRect.bottom),
      Offset(chartRect.width, chartRect.bottom),
      gridPaint,
    );
    final double columnSpace = chartRect.width / gridColumns;
    for (int i = 0; i <= columnSpace; i++) {
      //vol vertical line
      canvas.drawLine(
        Offset(columnSpace * i, chartRect.top - topPadding),
        Offset(columnSpace * i, chartRect.bottom),
        gridPaint,
      );
    }
  }
}
