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
  }) {
    if (maxValue == minValue) {
      maxValue *= 1.5;
      minValue /= 2;
    }
    scaleY = chartRect.height / (maxValue - minValue);
    gridPaint.color = gridColor;
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
  Paint separatedPaint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.high
    ..strokeWidth = 0.5
    ..color = Colors.amber;

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

  void drawGrid(Canvas canvas, int gridRows, int gridColumns);

  void drawText(Canvas canvas, T data, double x);

  void drawVerticalText(Canvas canvas, TextStyle textStyle, int gridRows);

  void drawChart(
    T lastPoint,
    T curPoint,
    double lastX,
    double curX,
    Size size,
    Canvas canvas,
  );

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
