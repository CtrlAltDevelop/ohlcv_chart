import 'package:flutter/material.dart';

export '../chart_style.dart';

abstract class BaseChartRenderer<T> {
  BaseChartRenderer({
    required this.chartRect,
    required this.maxValue,
    required this.minValue,
    required this.topPadding,
    required this.fixedLength,
    required Color gridColor,
    Color? separatorColor,
    Color? gridColumnColor,
    double gridStrokeWidth = 0.5,
    double separatorWidth = 1.0,
    this.labelCornerRadius = 3.0,
    this.legendPadding = 4.0,
    this.legendBgColor,
    this.priceAxisGutter = 0.0,
    this.priceAxisGutterOnLeft = false,
  }) {
    if (maxValue == minValue) {
      maxValue *= 1.5;
      minValue /= 2;
    }
    scaleY = chartRect.height / (maxValue - minValue);
    gridPaint
      ..color = gridColor
      ..strokeWidth = gridStrokeWidth;
    separatedPaint
      ..color = separatorColor ?? gridColor
      ..strokeWidth = separatorWidth;
    columnGridPaint
      ..color = gridColumnColor ?? gridColor
      ..strokeWidth = gridStrokeWidth;
  }

  /// Corner radius of the legend pill.
  final double labelCornerRadius;

  /// Space between the legend pill and its text.
  final double legendPadding;

  /// Fill of the legend pill; null leaves the legend unbacked.
  final Color? legendBgColor;

  /// Width held back beside [chartRect] for the price axis labels.
  ///
  /// Already resolved by the painter, so it is never wider than the canvas can
  /// spare. 0 means there is no gutter and the labels are drawn over the plot,
  /// which is the long-standing behaviour.
  final double priceAxisGutter;

  /// Which side [priceAxisGutter] is held back on.
  final bool priceAxisGutterOnLeft;

  /// Where a price axis label [width] wide starts, [padding] in from its edge.
  ///
  /// With a gutter the label goes in it, on whichever side it was held back,
  /// so the plot never runs underneath. Without one the label is drawn just
  /// inside the plot, against [onLeft] — which is how the axis has always been
  /// drawn, and what every pane still does by default.
  double axisLabelX(double width, double padding, {bool onLeft = false}) {
    if (priceAxisGutter > 0) {
      return priceAxisGutterOnLeft
          ? chartRect.left - priceAxisGutter + padding
          : chartRect.right + padding;
    }
    return onLeft
        ? chartRect.left + padding
        : chartRect.right - width - padding;
  }

  double maxValue;
  double minValue;
  late double scaleY;
  double topPadding;
  Rect chartRect;
  int fixedLength;
  Paint chartPaint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.high
    ..strokeWidth = 1.0
    ..color = Colors.red;
  Paint gridPaint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.high
    ..strokeWidth = 0.5
    ..color = const Color(0xff4c5c74);

  /// Paints the vertical grid lines, which mark time rather than price.
  ///
  /// Kept apart from [gridPaint] so the time columns can sit behind the price
  /// rows, the way a chart is actually read.
  Paint columnGridPaint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.high
    ..strokeWidth = 0.5
    ..color = const Color(0xff4c5c74);
  Paint separatedPaint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.high
    ..strokeWidth = 1.0
    ..color = const Color(0xFFD1D3DB);

  double getValue(double y);

  String get name;

  double getY(double y) => (maxValue - y) * scaleY + chartRect.top;

  String format(double? n) {
    if (n == null || n.isNaN) {
      return '0.00';
    } else {
      return n.toStringAsFixed(fixedLength);
    }
  }

  /// Rules the pane.
  ///
  /// [columnXs] carries the x of every time tick, shared by every pane so the
  /// columns line up down the whole stack and meet their date labels. A null
  /// list falls back to [gridColumns] evenly spaced bands.
  void drawGrid(
    Canvas canvas,
    int gridRows,
    int gridColumns, {
    List<double>? columnXs,
  });

  void drawVerticalText(Canvas canvas, TextStyle textStyle, int gridRows);

  /// Draws this renderer's legend for the candle at [data].
  ///
  /// Renderers that read their values from a precomputed series draw their
  /// legend from the candle index instead, and leave this alone.
  void drawText(Canvas canvas, T data, double x) {}

  /// Draws the part of the series between two neighbouring candles.
  ///
  /// Only the candle and volume renderers work this way; indicators draw their
  /// whole visible range in one pass.
  void drawChart(
    T lastPoint,
    T curPoint,
    double lastX,
    double curX,
    Size size,
    Canvas canvas, {
    int index = 0,
  }) {}

  /// Draws whatever this renderer collected over the visible window.
  ///
  /// A renderer that draws a series a candle at a time collects the pieces
  /// instead and puts them down in one call; one that draws each candle
  /// outright has nothing to flush.
  void flushSeries(Canvas canvas) {}

  void drawLine(
    double? lastPrice,
    double? curPrice,
    Canvas canvas,
    double lastX,
    double curX,
    Color color,
  ) {
    if (lastPrice == null || curPrice == null) {
      return;
    }
    final double lastY = getY(lastPrice);
    final double curY = getY(curPrice);
    canvas.drawLine(
      Offset(lastX, lastY),
      Offset(curX, curY),
      chartPaint..color = color,
    );
  }

  void drawCircle(Canvas canvas, double curX, double curY, Color color) {
    canvas.drawCircle(
      Offset(curX, getY(curY)),
      2.0,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = color,
    );
  }

  TextStyle getTextStyle(Color color) {
    return TextStyle(fontSize: 10.0, color: color);
  }

  /// Paints an indicator legend at [offset] on a rounded, translucent pill, so
  /// it stays readable wherever the series happens to run.
  void paintLegend(Canvas canvas, TextPainter tp, Offset offset) {
    final background = legendBgColor;
    if (background != null && background.a > 0) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          offset.dx - legendPadding,
          offset.dy - legendPadding / 2,
          offset.dx + tp.width + legendPadding,
          offset.dy + tp.height + legendPadding / 2,
          Radius.circular(labelCornerRadius),
        ),
        Paint()..color = background,
      );
    }
    tp.paint(canvas, offset);
  }

  void drawHorizontalLine(
    Canvas canvas,
    double value,
    Color color, {
    bool dashed = true,
    bool showLabel = true,
  }) {
    final y = getY(value);
    if (y.isNaN || !y.isFinite || y < chartRect.top || y > chartRect.bottom) {
      return;
    }

    final paint = Paint()
      ..color = color.withAlpha(200)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final startX = chartRect.left;
    final endX = chartRect.right;

    final textOffset = showLabel ? 20 : 0;
    if (dashed) {
      const double dashWidth = 4;
      const double dashSpace = 4;
      final path = Path();
      double currentX = startX;
      while (currentX < endX - textOffset) {
        path.moveTo(currentX, y);
        final nextX = (currentX + dashWidth).clamp(startX, endX);
        path.lineTo(nextX, y);
        currentX += dashWidth + dashSpace;
      }
      canvas.drawPath(path, paint);
    } else {
      canvas.drawLine(Offset(startX, y), Offset(endX - textOffset, y), paint);
    }

    if (showLabel) {
      final String label = value % 1 == 0
          ? value.toInt().toString()
          : value.toStringAsFixed(1);
      final tp = TextPainter(
        text: TextSpan(text: label, style: getTextStyle(color.withAlpha(255))),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      final labelX = endX - tp.width - 4;
      final labelY = y - tp.height / 2;
      tp.paint(canvas, Offset(labelX, labelY));
    }
  }
}
