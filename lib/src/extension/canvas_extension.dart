import 'dart:math';
import 'dart:ui';

extension CanvasExtension on Canvas {
  void drawDashLine(
    Offset begin,
    Offset end,
    Paint paint, [
    double space = 3.0,
    double width = 4.0,
  ]) {
    if (begin.dx == end.dx) {
      /// draw vertical line
      double startDy = begin.dy;
      while (startDy < end.dy) {
        drawLine(
          Offset(begin.dx, startDy),
          Offset(begin.dx, min(startDy + width, end.dy)),
          paint,
        );
        startDy += space + width;
      }
    }

    if (begin.dy == end.dy) {
      /// draw horizontal line
      double startDx = begin.dx;
      while (startDx < end.dy) {
        drawLine(
          Offset(startDx, begin.dy),
          Offset(min(startDx + width, end.dy), begin.dy),
          paint,
        );
        startDx += space + width;
      }
    }
  }
}
