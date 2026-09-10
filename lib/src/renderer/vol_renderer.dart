import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../entity/volume_entity.dart';
import '../extension/num_ext.dart';
import '../utils/axis_ticks.dart';
import '../utils/number_util.dart';
import 'base_chart_renderer.dart';
import 'path_batch.dart';

class VolRenderer extends BaseChartRenderer<VolumeEntity> {
  VolRenderer(
    Rect mainRect,
    double maxValue,
    double minValue,
    double topPadding,
    int fixedLength,
    this.chartStyle,
    this.chartColors, {
    super.priceAxisGutter = 0.0,
    super.priceAxisGutterOnLeft = false,
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
    mVolWidth = chartStyle.volWidth;
  }

  late double mVolWidth;
  final ChartStyle chartStyle;
  final ChartColors chartColors;

  /// The two volume averages, collected across the window and stroked once.
  final PathBatch _ma5 = PathBatch();
  final PathBatch _ma10 = PathBatch();

  /// Strokes an average.
  ///
  /// Matches what [BaseChartRenderer.drawLine] used to hand `canvas.drawLine`:
  /// the same width and antialiasing, and an explicit stroke style, which
  /// `drawLine` did not need but `drawPath` does.
  final Paint _maPaint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.high
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  @override
  void drawChart(
    VolumeEntity lastPoint,
    VolumeEntity curPoint,
    double lastX,
    double curX,
    Size size,
    Canvas canvas, {
    int index = 0,
  }) {
    final r = mVolWidth / 2;
    final bottom = chartRect.bottom;
    final top = math.min(getVolY(curPoint.vol), bottom - 1);
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
      _collect(_ma5, lastPoint.ma5Volume, curPoint.ma5Volume, lastX, curX);
    }

    if (lastPoint.ma10Volume != 0) {
      _collect(_ma10, lastPoint.ma10Volume, curPoint.ma10Volume, lastX, curX);
    }
  }

  /// Adds one stretch of an average to [batch], skipping a gap in the values
  /// the way [BaseChartRenderer.drawLine] did.
  void _collect(
    PathBatch batch,
    double? lastValue,
    double? curValue,
    double lastX,
    double curX,
  ) {
    if (lastValue == null || curValue == null) return;
    batch.addSegment(lastX, getY(lastValue), curX, getY(curValue));
  }

  /// Strokes the averages collected over the window.
  ///
  /// Called once the candle loop is done, in the same transform the segments
  /// were collected in.
  @override
  void flushSeries(Canvas canvas) {
    _ma5.flush(canvas, _maPaint..color = chartColors.ma5Color);
    _ma10.flush(canvas, _maPaint..color = chartColors.ma10Color);
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
    paintLegend(canvas, tp, Offset(x, chartRect.top - topPadding));
  }

  /// The volumes this pane rules and labels itself by.
  ///
  /// Volume runs from nothing to the tallest bar in view, so its axis only
  /// wants a couple of round marks — enough to read a bar against, without
  /// crowding a pane this short.
  List<double> get volumeTicks => _volumeTicks ??= [
    for (final value in niceTicks(0, maxValue, target: 2))
      if (value > 0) value,
  ];

  List<double>? _volumeTicks;

  @override
  void drawVerticalText(Canvas canvas, TextStyle textStyle, int gridRows) {
    final padding = chartStyle.axisLabelPadding;

    for (final value in volumeTicks) {
      final y = getVolY(value);
      if (!y.isFinite) continue;

      final TextPainter tp = TextPainter(
        text: TextSpan(text: NumberUtil.format(value), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      // The top mark is lifted onto the legend row, where the old single
      // maximum label sat; the rest ride above their own line.
      final top = chartRect.top - topPadding;
      final offsetY = (y - tp.height).clamp(top, chartRect.bottom - tp.height);

      tp.paint(canvas, Offset(axisLabelX(tp.width, padding), offsetY));
    }
  }

  @override
  void drawGrid(
    Canvas canvas,
    int gridRows,
    int gridColumns, {
    List<double>? columnXs,
  }) {
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

    // A mark part-way up gives the bars something to be read against.
    for (final value in volumeTicks) {
      final y = getVolY(value);
      if (!y.isFinite || y <= chartRect.top || y >= chartRect.bottom) continue;
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
        Offset(x, chartRect.top - topPadding),
        Offset(x, chartRect.bottom),
        columnGridPaint,
      );
    }
  }
}
