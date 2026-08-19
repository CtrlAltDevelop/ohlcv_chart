import 'dart:math' as math;
import 'dart:ui';

import '../entity/line.dart';

/// Strokes [start] to [end] honouring [style].
///
/// Shared by the chart painter and the editing toolbar's previews, so a line
/// looks the same in both places.
void paintStyledLine(
  Canvas canvas,
  Offset start,
  Offset end,
  Paint paint, {
  LineStyle style = LineStyle.solid,
  double dashLength = 6.0,
  double dashGap = 4.0,
  double dotGap = 3.0,
}) {
  switch (style) {
    case LineStyle.solid:
      canvas.drawLine(start, end, paint);
    case LineStyle.dashed:
      _paintDashes(canvas, start, end, paint, dashLength, dashGap);
    case LineStyle.dotted:
      _paintDots(canvas, start, end, paint, dotGap);
  }
}

void _paintDashes(
  Canvas canvas,
  Offset start,
  Offset end,
  Paint paint,
  double dashLength,
  double gapLength,
) {
  final total = (end - start).distance;
  if (total <= 0 || dashLength <= 0) {
    canvas.drawLine(start, end, paint);
    return;
  }

  final direction = (end - start) / total;
  final step = dashLength + math.max(gapLength, 0.0);
  for (var travelled = 0.0; travelled < total; travelled += step) {
    final dashEnd = math.min(travelled + dashLength, total);
    canvas.drawLine(
      start + direction * travelled,
      start + direction * dashEnd,
      paint,
    );
  }
}

void _paintDots(
  Canvas canvas,
  Offset start,
  Offset end,
  Paint paint,
  double gapLength,
) {
  final radius = math.max(paint.strokeWidth, 0.5) / 2;
  final dot = Paint()
    ..color = paint.color
    ..isAntiAlias = true
    ..style = PaintingStyle.fill;

  final total = (end - start).distance;
  if (total <= 0) {
    canvas.drawCircle(start, radius, dot);
    return;
  }

  final direction = (end - start) / total;
  final step = radius * 2 + math.max(gapLength, 0.5);
  for (var travelled = 0.0; travelled <= total; travelled += step) {
    canvas.drawCircle(start + direction * travelled, radius, dot);
  }
}
