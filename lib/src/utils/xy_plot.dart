/// The parts the charts that plot points against two numeric axes share: how
/// a range is padded, how its ticks are written, and where a tooltip sits.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';
import '../series/series_axis.dart';
import 'axis_ticks.dart';

/// Writes [value] with [formatter], or with at most two decimals.
String formatPlotNumber(double value, [String Function(double)? formatter]) {
  if (formatter != null) return formatter(value);
  if (!value.isFinite) return '–';
  final rounded = double.parse(value.toStringAsFixed(2));
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toString();
}

/// The range [values] cover, with [pad] of it left either side.
///
/// Values that are not finite are ignored. Nothing to measure gives `0..1`, and
/// a single value is given a unit either side so there is something to draw
/// against. [includeZero] widens the range to hold zero.
({double min, double max}) paddedRange(
  Iterable<double> values, {
  double pad = 0.1,
  bool includeZero = false,
}) {
  var min = double.infinity;
  var max = double.negativeInfinity;
  for (final value in values) {
    if (!value.isFinite) continue;
    min = math.min(min, value);
    max = math.max(max, value);
  }
  if (!min.isFinite || !max.isFinite) return (min: 0, max: 1);
  if (includeZero) {
    min = math.min(min, 0);
    max = math.max(max, 0);
  }
  if (min == max) return (min: min - 1, max: max + 1);
  final room = (max - min) * pad;
  return (min: min - room, max: max + room);
}

/// Where [value] falls between [min] and [max], mapped onto [from]..[to].
double mapAcross(double value, double min, double max, double from, double to) {
  final span = max - min;
  if (span == 0) return (from + to) / 2;
  return from + (value - min) / span * (to - from);
}

/// Draws the grid, the tick labels and the titles of a two-axis plot.
///
/// The bottom axis is numeric unless [xLabels] is given, in which case a label
/// is written under each whole number — a column per category.
void paintXyAxes(
  Canvas canvas,
  TextPainterCache text, {
  required Rect plot,
  required double minX,
  required double maxX,
  required double minY,
  required double maxY,
  int tickCount = 5,
  Color? gridColor,
  bool showAxes = true,
  String Function(double value)? xFormatter,
  String Function(double value)? yFormatter,
  TextStyle? labelStyle,
  String? xTitle,
  String? yTitle,
  TextStyle? titleStyle,
  double axisWidth = 44,
  double axisHeight = 18,
  List<String>? xLabels,
  bool logX = false,
  bool logY = false,
}) {
  final style = seriesAxisLabelStyle.merge(labelStyle);
  final line = gridColor == null
      ? null
      : (Paint()
          ..color = gridColor
          ..strokeWidth = 1);

  final yTicks = logY
      ? niceLogTicks(minY, maxY, target: tickCount)
      : niceTicks(minY, maxY, target: tickCount);
  for (final tick in yTicks) {
    final y = logY
        ? mapAcrossLog(tick, minY, maxY, plot.bottom, plot.top)
        : mapAcross(tick, minY, maxY, plot.bottom, plot.top);
    if (y == null) continue;
    if (line != null) {
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), line);
    }
    if (!showAxes) continue;
    final tp = text.get(formatPlotNumber(tick, yFormatter), style);
    final left = plot.left - 6 - tp.width;
    if (left >= 0) tp.paint(canvas, Offset(left, y - tp.height / 2));
  }

  var written = -double.infinity;
  void label(double x, String value) {
    final tp = text.get(value, style);
    final left = x - tp.width / 2;
    if (left < written || left < 0 || left + tp.width > plot.right + 2) return;
    tp.paint(canvas, Offset(left, plot.bottom + 3));
    written = left + tp.width + 4;
  }

  if (xLabels != null) {
    for (var i = 0; i < xLabels.length; i++) {
      final x = mapAcross(i.toDouble(), minX, maxX, plot.left, plot.right);
      if (line != null) {
        canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), line);
      }
      if (showAxes) label(x, xLabels[i]);
    }
  } else {
    final xTicks = logX
        ? niceLogTicks(minX, maxX, target: tickCount)
        : niceTicks(minX, maxX, target: tickCount);
    for (final tick in xTicks) {
      final x = logX
          ? mapAcrossLog(tick, minX, maxX, plot.left, plot.right)
          : mapAcross(tick, minX, maxX, plot.left, plot.right);
      if (x == null) continue;
      if (line != null) {
        canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), line);
      }
      if (showAxes) label(x, formatPlotNumber(tick, xFormatter));
    }
  }

  final titles = seriesAxisTitleStyle.merge(titleStyle);
  if (xTitle != null && xTitle.isNotEmpty) {
    final tp = text.get(xTitle, titles);
    tp.paint(
      canvas,
      Offset(plot.center.dx - tp.width / 2, plot.bottom + axisHeight + 2),
    );
  }
  if (yTitle != null && yTitle.isNotEmpty) {
    final tp = text.get(yTitle, titles);
    canvas
      ..save()
      ..translate(plot.left - axisWidth + tp.height, plot.center.dy)
      ..rotate(-math.pi / 2);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height));
    canvas.restore();
  }
}

/// Puts a tooltip beside [anchor] — to its right, or its left when there is no
/// room — and keeps it inside the chart.
class XyTooltipLayout extends SingleChildLayoutDelegate {
  /// Creates a layout that places the tooltip beside [anchor].
  XyTooltipLayout({required this.anchor, required this.margin});

  /// The mark the tooltip is about.
  final Rect anchor;

  /// How far from it the tooltip sits.
  final double margin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var left = anchor.right + margin;
    if (left + childSize.width > size.width) {
      left = anchor.left - margin - childSize.width;
    }
    return Offset(
      left.clamp(0.0, math.max(0.0, size.width - childSize.width)),
      (anchor.center.dy - childSize.height / 2).clamp(
        0.0,
        math.max(0.0, size.height - childSize.height),
      ),
    );
  }

  @override
  bool shouldRelayout(XyTooltipLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.margin != margin;
}

/// The base-10 logarithm of [value], or null where it has none — zero, a
/// negative number or one that is not finite.
double? log10OrNull(double value) {
  if (!value.isFinite || value <= 0) return null;
  return math.log(value) / math.ln10;
}

/// Where [value] falls between [min] and [max] on a logarithmic scale, mapped
/// onto [from]..[to]; null for a value or range a logarithm cannot take.
double? mapAcrossLog(
  double value,
  double min,
  double max,
  double from,
  double to,
) {
  final v = log10OrNull(value);
  final lo = log10OrNull(min);
  final hi = log10OrNull(max);
  if (v == null || lo == null || hi == null) return null;
  return mapAcross(v, lo, hi, from, to);
}
