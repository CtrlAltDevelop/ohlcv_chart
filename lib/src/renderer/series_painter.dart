import 'package:flutter/material.dart';

import '../chart_style.dart';
import '../entity/k_line_entity.dart';
import '../indicators/indicator.dart';
import '../indicators/resolved_indicator.dart';

/// Draws one indicator's lines, dots and histogram bars.
///
/// Works in view space — [xOf] and [yOf] map a candle index and a value to
/// pixels — so the same code draws a pane and an overlay, and a stroke keeps its
/// width at every zoom level.
void paintIndicatorSeries(
  Canvas canvas, {
  required ResolvedIndicator resolved,
  required List<KLineEntity> candles,
  required int start,
  required int stop,
  required double Function(int index) xOf,
  required double Function(double value) yOf,
  required ChartColors colors,
  required double strokeWidth,
  required double barWidth,
  double dotRadius = 2.0,
  double? zeroY,
}) {
  final indicator = resolved.indicator;

  for (final fill in indicator.fills) {
    _paintFill(
      canvas,
      resolved: resolved,
      fill: fill,
      start: start,
      stop: stop,
      xOf: xOf,
      yOf: yOf,
      colors: colors,
    );
  }

  for (var line = 0; line < indicator.lines.length; line++) {
    final shape = indicator.lines[line].shape;
    final color = resolved.colorFor(line, colors);

    switch (shape) {
      case IndicatorShape.line:
      case IndicatorShape.pivotLine:
        _paintLine(
          canvas,
          resolved: resolved,
          line: line,
          start: start,
          stop: stop,
          xOf: xOf,
          yOf: yOf,
          color: color,
          strokeWidth: strokeWidth,
          bridgeGaps: shape == IndicatorShape.pivotLine,
        );
      case IndicatorShape.dots:
        _paintPoints(
          canvas,
          resolved: resolved,
          candles: candles,
          line: line,
          start: start,
          stop: stop,
          xOf: xOf,
          yOf: yOf,
          color: color,
          colors: colors,
          radius: dotRadius,
          strokeWidth: strokeWidth,
        );
      case IndicatorShape.markers:
        _paintMarkers(
          canvas,
          resolved: resolved,
          line: line,
          start: start,
          stop: stop,
          xOf: xOf,
          yOf: yOf,
          color: color,
          radius: dotRadius,
        );
      case IndicatorShape.histogram:
        _paintHistogram(
          canvas,
          resolved: resolved,
          candles: candles,
          line: line,
          start: start,
          stop: stop,
          xOf: xOf,
          yOf: yOf,
          color: color,
          colors: colors,
          barWidth: barWidth,
          zeroY: zeroY ?? yOf(0),
        );
    }
  }
}

void _paintLine(
  Canvas canvas, {
  required ResolvedIndicator resolved,
  required int line,
  required int start,
  required int stop,
  required double Function(int) xOf,
  required double Function(double) yOf,
  required Color color,
  required double strokeWidth,
  bool bridgeGaps = false,
}) {
  final path = Path();
  var open = false;
  var points = 0;

  var from = start;
  var to = stop;
  if (bridgeGaps) {
    // A line defined only at its corners needs the corners either side of the
    // window too, or a leg that spans the whole view has nothing to draw
    // between. The canvas is clipped to the chart, so the overshoot is free.
    from = _anchorBefore(resolved, line, start) ?? start;
    to = _anchorAfter(resolved, line, stop) ?? stop;
  }

  for (var i = from; i <= to; i++) {
    final value = resolved.valueAt(line, i);
    if (value == null || !value.isFinite) {
      // A gap in the values breaks the stroke rather than closing over it,
      // unless the line is only defined at its corners.
      if (!bridgeGaps) open = false;
      continue;
    }
    final point = Offset(xOf(i), yOf(value));
    if (open) {
      path.lineTo(point.dx, point.dy);
    } else {
      path.moveTo(point.dx, point.dy);
      open = true;
    }
    points++;
  }

  // An indicator that has no values in view has nothing to stroke.
  if (points == 0) return;

  canvas.drawPath(
    path,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true,
  );
}

/// The last index at or before [start] that has a value.
int? _anchorBefore(ResolvedIndicator resolved, int line, int start) {
  for (var i = start; i >= 0; i--) {
    final value = resolved.valueAt(line, i);
    if (value != null && value.isFinite) return i;
  }
  return null;
}

/// The first index at or after [stop] that has a value.
int? _anchorAfter(ResolvedIndicator resolved, int line, int stop) {
  final length = resolved.series.lines[line].length;
  for (var i = stop; i < length; i++) {
    final value = resolved.valueAt(line, i);
    if (value != null && value.isFinite) return i;
  }
  return null;
}

void _paintPoints(
  Canvas canvas, {
  required ResolvedIndicator resolved,
  required List<KLineEntity> candles,
  required int line,
  required int start,
  required int stop,
  required double Function(int) xOf,
  required double Function(double) yOf,
  required Color color,
  required ChartColors colors,
  required double radius,
  required double strokeWidth,
}) {
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..isAntiAlias = true;

  for (var i = start; i <= stop; i++) {
    final value = resolved.valueAt(line, i);
    if (value == null || !value.isFinite || i >= candles.length) continue;

    paint.color =
        resolved.indicator.colorForPoint(line, i, candles[i], value, colors) ??
        color;
    canvas.drawCircle(Offset(xOf(i), yOf(value)), radius, paint);
  }
}

void _paintHistogram(
  Canvas canvas, {
  required ResolvedIndicator resolved,
  required List<KLineEntity> candles,
  required int line,
  required int start,
  required int stop,
  required double Function(int) xOf,
  required double Function(double) yOf,
  required Color color,
  required ChartColors colors,
  required double barWidth,
  required double zeroY,
}) {
  final paint = Paint()..isAntiAlias = true;
  final half = barWidth / 2;

  for (var i = start; i <= stop; i++) {
    final value = resolved.valueAt(line, i);
    if (value == null || !value.isFinite || i >= candles.length) continue;

    paint.color =
        resolved.indicator.colorForPoint(line, i, candles[i], value, colors) ??
        color;

    final x = xOf(i);
    final y = yOf(value);
    // Bars shorter than a hairline would vanish at the zero line.
    final top = y < zeroY ? y : zeroY;
    final bottom = y < zeroY ? zeroY : y;
    canvas.drawRect(
      Rect.fromLTRB(
        x - half,
        top,
        x + half,
        bottom < top + 1 ? top + 1 : bottom,
      ),
      paint,
    );
  }
}

/// Shades the area between two of an indicator's lines.
///
/// The band is split wherever the two lines cross, so each stretch takes the
/// colour of whichever line is on top there.
void _paintFill(
  Canvas canvas, {
  required ResolvedIndicator resolved,
  required IndicatorFill fill,
  required int start,
  required int stop,
  required double Function(int) xOf,
  required double Function(double) yOf,
  required ChartColors colors,
}) {
  final indicator = resolved.indicator;
  final paint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  var upper = <Offset>[];
  var lower = <Offset>[];
  bool? isAbove;

  void flush() {
    final above = isAbove;
    if (upper.length < 2 || above == null) {
      upper = [];
      lower = [];
      return;
    }
    final path = Path()..moveTo(upper.first.dx, upper.first.dy);
    for (final point in upper.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    for (final point in lower.reversed) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    paint.color = indicator.fillColor(fill, colors, isAbove: above);
    canvas.drawPath(path, paint);
    upper = [];
    lower = [];
  }

  for (var i = start; i <= stop; i++) {
    final a = resolved.valueAt(fill.line, i);
    final b = resolved.valueAt(fill.against, i);
    if (a == null || b == null || !a.isFinite || !b.isFinite) {
      flush();
      isAbove = null;
      continue;
    }

    final above = a >= b;
    if (isAbove != null && above != isAbove) {
      // Carry the crossing point into both stretches so they meet.
      final x = xOf(i);
      upper.add(Offset(x, yOf(a)));
      lower.add(Offset(x, yOf(b)));
      flush();
      upper.add(Offset(x, yOf(a)));
      lower.add(Offset(x, yOf(b)));
    }
    isAbove = above;

    final x = xOf(i);
    upper.add(Offset(x, yOf(a)));
    lower.add(Offset(x, yOf(b)));
  }
  flush();
}

/// Draws a dot per value with the indicator's own text above it.
void _paintMarkers(
  Canvas canvas, {
  required ResolvedIndicator resolved,
  required int line,
  required int start,
  required int stop,
  required double Function(int) xOf,
  required double Function(double) yOf,
  required Color color,
  required double radius,
}) {
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  for (var i = start; i <= stop; i++) {
    final value = resolved.valueAt(line, i);
    if (value == null || !value.isFinite) continue;

    final point = Offset(xOf(i), yOf(value));
    canvas.drawCircle(point, radius, paint);

    final label = resolved.indicator.markerLabel(line, i);
    if (label == null) continue;

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(point.dx - tp.width / 2, point.dy - tp.height - radius - 2),
    );
  }
}
