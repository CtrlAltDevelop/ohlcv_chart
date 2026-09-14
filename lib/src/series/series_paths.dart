import 'dart:math' as math;
import 'dart:ui';

import 'series_data.dart';

/// Appends one unbroken run of [points], in pixels and left to right, to
/// [path], joined as [curve] says.
void addSeriesRun(Path path, List<Offset> points, LineCurve curve) {
  if (points.isEmpty) return;
  path.moveTo(points.first.dx, points.first.dy);
  if (points.length == 1) return;
  switch (curve) {
    case LineCurve.linear:
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
    case LineCurve.step:
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i - 1].dy);
        path.lineTo(points[i].dx, points[i].dy);
      }
    case LineCurve.smooth:
      _smooth(path, points);
    case LineCurve.monotone:
      _monotone(path, points);
  }
}

/// A cubic through every point whose handles follow the neighbours on either
/// side, the way `fl_chart` draws `isCurved`.
void _smooth(Path path, List<Offset> points) {
  const smoothness = 0.35;
  var handle = Offset.zero;
  for (var i = 1; i < points.length; i++) {
    final previous = points[i - 1];
    final current = points[i];
    final next = i + 1 < points.length ? points[i + 1] : current;
    final control1 = previous + handle;
    handle = (next - previous) / 2 * smoothness;
    final control2 = current - handle;
    path.cubicTo(
      control1.dx,
      control1.dy,
      control2.dx,
      control2.dy,
      current.dx,
      current.dy,
    );
  }
}

/// A monotone cubic (Fritsch–Carlson): it passes through every point, and
/// between two points it never goes above the higher or below the lower.
void _monotone(Path path, List<Offset> points) {
  final tangents = monotoneTangents(points);
  for (var i = 0; i < points.length - 1; i++) {
    final a = points[i];
    final b = points[i + 1];
    final third = (b.dx - a.dx) / 3;
    path.cubicTo(
      a.dx + third,
      a.dy + tangents[i] * third,
      b.dx - third,
      b.dy - tangents[i + 1] * third,
      b.dx,
      b.dy,
    );
  }
}

/// The slope of a monotone cubic at each of [points].
List<double> monotoneTangents(List<Offset> points) {
  final n = points.length;
  if (n < 2) return List<double>.filled(n, 0);

  final secants = List<double>.filled(n - 1, 0);
  for (var i = 0; i < n - 1; i++) {
    final run = points[i + 1].dx - points[i].dx;
    secants[i] = run == 0 ? 0 : (points[i + 1].dy - points[i].dy) / run;
  }

  final tangents = List<double>.filled(n, 0);
  tangents[0] = secants[0];
  tangents[n - 1] = secants[n - 2];
  for (var i = 1; i < n - 1; i++) {
    // A peak or a trough gets a flat tangent, which is what keeps the curve
    // from swinging past it.
    tangents[i] = secants[i - 1] * secants[i] <= 0
        ? 0
        : (secants[i - 1] + secants[i]) / 2;
  }

  for (var i = 0; i < n - 1; i++) {
    if (secants[i] == 0) {
      tangents[i] = 0;
      tangents[i + 1] = 0;
      continue;
    }
    final a = tangents[i] / secants[i];
    final b = tangents[i + 1] / secants[i];
    final magnitude = a * a + b * b;
    if (magnitude > 9) {
      final scale = 3 / math.sqrt(magnitude);
      tangents[i] = scale * a * secants[i];
      tangents[i + 1] = scale * b * secants[i];
    }
  }
  return tangents;
}

/// [source] cut into dashes by [pattern] — dash, gap, dash, gap …
///
/// Returns [source] itself for an empty or all-zero pattern.
Path dashSeriesPath(Path source, List<double>? pattern) {
  if (pattern == null || pattern.isEmpty || !pattern.any((v) => v > 0)) {
    return source;
  }
  final dashed = Path();
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    var index = 0;
    while (distance < metric.length) {
      final length = math.max(0.0, pattern[index % pattern.length]);
      if (index.isEven && length > 0) {
        dashed.addPath(
          metric.extractPath(
            distance,
            math.min(distance + length, metric.length),
          ),
          Offset.zero,
        );
      }
      distance += length;
      index++;
    }
  }
  return dashed;
}

/// The shape of one bar: [left] to [right] across, from [valueY] to [baseY]
/// down the plot, rounded by [radius] on the end at [valueY].
///
/// Returns null for a bar with no height or no width.
RRect? seriesBarShape({
  required double left,
  required double right,
  required double valueY,
  required double baseY,
  required double radius,
}) {
  final width = right - left;
  final height = (baseY - valueY).abs();
  if (width <= 0 || height <= 0) return null;

  final rect = Rect.fromLTRB(
    left,
    math.min(valueY, baseY),
    right,
    math.max(valueY, baseY),
  );
  final r = Radius.circular(
    math.max(0.0, math.min(radius, math.min(width / 2, height))),
  );
  // Above the baseline the value is the top edge; below it, the bottom.
  final up = valueY <= baseY;
  return RRect.fromRectAndCorners(
    rect,
    topLeft: up ? r : Radius.zero,
    topRight: up ? r : Radius.zero,
    bottomLeft: up ? Radius.zero : r,
    bottomRight: up ? Radius.zero : r,
  );
}
