import 'package:flutter/material.dart';

import '../entity/k_line_entity.dart';
import '../indicators/indicator.dart';
import '../indicators/resolved_indicator.dart';
import '../utils/number_util.dart';
import 'base_chart_renderer.dart';
import 'series_painter.dart';

/// One indicator in its own pane below the candles.
///
/// Everything it draws — the lines, the legend, the guides and the two axis
/// labels — comes from the indicator's own description and values, so a pane is
/// added by adding an indicator rather than by extending a switch.
class IndicatorPaneRenderer extends BaseChartRenderer<KLineEntity> {
  /// Creates a pane for [resolved] inside [rect].
  IndicatorPaneRenderer(
    Rect rect,
    double maxValue,
    double minValue,
    double topPadding,
    int fixedLength,
    this.chartStyle,
    this.chartColors,
    this.resolved,
  ) : super(
        chartRect: rect,
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
      );

  /// Geometry.
  final ChartStyle chartStyle;

  /// Palette.
  final ChartColors chartColors;

  /// The indicator and its values.
  final ResolvedIndicator resolved;

  /// The indicator being drawn.
  Indicator get indicator => resolved.indicator;

  @override
  String get name => indicator.name;

  @override
  double getValue(double y) => maxValue - (y - chartRect.top) / scaleY;

  @override
  String format(double? n) => formatValue(n);

  /// Writes [value] the way this indicator's numbers read best.
  String formatValue(double? value) {
    if (value == null || value.isNaN) return '--';
    return switch (indicator.format) {
      IndicatorFormat.price => value.toStringAsFixed(fixedLength),
      IndicatorFormat.decimal => value.toStringAsFixed(2),
      IndicatorFormat.compact => NumberUtil.formatCompact(value),
    };
  }

  /// Draws every line of the indicator across the visible candles.
  void drawSeries(
    Canvas canvas,
    List<KLineEntity> candles, {
    required int start,
    required int stop,
    required double Function(int index) xOf,
  }) {
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        chartRect.left,
        chartRect.top - topPadding,
        chartRect.right,
        chartRect.bottom,
      ),
    );
    paintIndicatorSeries(
      canvas,
      resolved: resolved,
      candles: candles,
      start: start,
      stop: stop,
      xOf: xOf,
      yOf: getY,
      colors: chartColors,
      strokeWidth: chartStyle.indicatorLineWidth,
      barWidth: chartStyle.macdWidth,
      zeroY: getY(0).clamp(chartRect.top, chartRect.bottom),
    );
    canvas.restore();
  }

  /// Draws the pane's legend: its label, then each line's value at [index].
  void drawLegendAt(Canvas canvas, int index, double x) {
    final spans = <InlineSpan>[
      TextSpan(
        text: '${indicator.label}    ',
        style: getTextStyle(chartColors.defaultTextColor),
      ),
    ];
    for (var line = 0; line < indicator.lines.length; line++) {
      spans.add(
        TextSpan(
          text:
              '${indicator.lines[line].label}:'
              '${formatValue(resolved.valueAt(line, index))}    ',
          style: getTextStyle(resolved.colorFor(line, chartColors)),
        ),
      );
    }

    final tp = TextPainter(
      text: TextSpan(children: spans),
      textDirection: TextDirection.ltr,
    )..layout();
    paintLegend(canvas, tp, Offset(x, chartRect.top - topPadding));
  }

  @override
  void drawVerticalText(Canvas canvas, TextStyle textStyle, int gridRows) {
    final padding = chartStyle.axisLabelPadding;

    final maxTp = TextPainter(
      text: TextSpan(text: formatValue(maxValue), style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final minTp = TextPainter(
      text: TextSpan(text: formatValue(minValue), style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    maxTp.paint(
      canvas,
      Offset(
        chartRect.width - maxTp.width - padding,
        chartRect.top - topPadding,
      ),
    );
    minTp.paint(
      canvas,
      Offset(
        chartRect.width - minTp.width - padding,
        chartRect.bottom - minTp.height,
      ),
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
    for (var i = 0; i <= gridColumns; i++) {
      canvas.drawLine(
        Offset(columnSpace * i, chartRect.top - topPadding),
        Offset(columnSpace * i, chartRect.bottom),
        gridPaint,
      );
    }

    for (final guide in indicator.guides) {
      drawHorizontalLine(canvas, guide, chartColors.gridColor);
    }
  }
}
