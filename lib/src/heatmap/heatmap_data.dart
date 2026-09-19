import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The colour a heatmap falls back on when its scale names none.
const Color heatmapDefaultColor = Color(0xFF4C86CD);

/// The colour of a square with no value in it.
const Color heatmapEmptyColor = Color(0x14909196);

/// One square of a [HeatmapChart]: the value at column [x], row [y].
///
/// [x] and [y] are whole positions in the grid, counted from zero — the
/// column and the row, not pixels.
@immutable
class HeatmapCell {
  /// Creates the square at ([x], [y]).
  const HeatmapCell({
    required this.x,
    required this.y,
    required this.value,
    this.color,
    this.label,
  });

  /// The column, counted from the left.
  final int x;

  /// The row, counted from the top.
  final int y;

  /// The value the square is coloured by; null leaves it empty.
  final double? value;

  /// A colour of this square's own, which the scale does not overrule.
  final Color? color;

  /// Written in the square; null asks `HeatmapChart.labelBuilder`.
  final String? label;

  /// Whether there is no value here to colour.
  bool get isEmpty {
    final v = value;
    return v == null || !v.isFinite;
  }

  @override
  bool operator ==(Object other) =>
      other is HeatmapCell &&
      other.x == x &&
      other.y == y &&
      other.value == value &&
      other.color == color &&
      other.label == label;

  @override
  int get hashCode => Object.hash(x, y, value, color, label);

  @override
  String toString() => 'HeatmapCell($x, $y, $value)';
}

/// Turns a value into the colour its square is painted.
sealed class HeatmapScale {
  /// Creates a scale.
  const HeatmapScale({this.emptyColor = heatmapEmptyColor});

  /// The colour of a square with no value.
  final Color emptyColor;

  /// The colour for [value], where the values run from [min] to [max].
  Color colorAt(double value, double min, double max);

  /// The colours this scale runs through, lowest first — what a legend draws.
  List<Color> get colors;
}

/// A scale that fades from one colour to the next.
///
/// The values are spread over [colors] evenly, or at [stops] when those are
/// given — each a share of the way from the lowest value to the highest.
final class HeatmapGradientScale extends HeatmapScale {
  /// Creates a scale fading through [colors].
  const HeatmapGradientScale({
    required this.colors,
    this.stops,
    super.emptyColor,
  });

  /// A single colour deepening from [lowOpacity] to full — the contribution
  /// graph's scale.
  HeatmapGradientScale.of(
    Color color, {
    double lowOpacity = 0.12,
    super.emptyColor,
  }) : colors = [color.withValues(alpha: lowOpacity), color],
       stops = null;

  @override
  final List<Color> colors;

  /// Where each colour sits, from 0 at the lowest value to 1 at the highest;
  /// null spreads them evenly.
  final List<double>? stops;

  @override
  Color colorAt(double value, double min, double max) {
    if (colors.isEmpty) return heatmapDefaultColor;
    if (colors.length == 1) return colors.first;
    final span = max - min;
    final t = span <= 0 ? 1.0 : ((value - min) / span).clamp(0.0, 1.0);
    final at = stops ?? _evenStops(colors.length);
    for (var i = 1; i < at.length && i < colors.length; i++) {
      if (t > at[i]) continue;
      final width = at[i] - at[i - 1];
      final local = width <= 0 ? 1.0 : (t - at[i - 1]) / width;
      return Color.lerp(colors[i - 1], colors[i], local.clamp(0.0, 1.0))!;
    }
    return colors.last;
  }

  static List<double> _evenStops(int count) => [
    for (var i = 0; i < count; i++)
      count < 2 ? 0.0 : lerpDouble(0, 1, i / (count - 1))!,
  ];
}

/// One band of a [HeatmapStepScale].
@immutable
class HeatmapStep {
  /// Paints every value from [from] up to the next step in [color].
  const HeatmapStep(this.from, this.color, {this.label});

  /// The lowest value this band covers.
  final double from;

  /// What that band is painted.
  final Color color;

  /// What the band is called, for a legend.
  final String? label;
}

/// A scale that paints whole bands rather than a fade — under 0, 0 to 5, and
/// so on.
///
/// The steps are read in order; a value below the first one takes the first
/// step's colour.
final class HeatmapStepScale extends HeatmapScale {
  /// Creates a scale of [steps], lowest first.
  const HeatmapStepScale({required this.steps, super.emptyColor});

  /// The bands, lowest first.
  final List<HeatmapStep> steps;

  @override
  List<Color> get colors => [for (final step in steps) step.color];

  @override
  Color colorAt(double value, double min, double max) {
    if (steps.isEmpty) return heatmapDefaultColor;
    var chosen = steps.first.color;
    for (final step in steps) {
      if (value < step.from) break;
      chosen = step.color;
    }
    return chosen;
  }
}

/// The lowest and the highest value among [cells], or (0, 1) when there is
/// nothing to measure.
(double, double) heatmapValueRange(List<HeatmapCell> cells) {
  var low = double.infinity;
  var high = double.negativeInfinity;
  for (final cell in cells) {
    if (cell.isEmpty) continue;
    low = math.min(low, cell.value!);
    high = math.max(high, cell.value!);
  }
  if (low > high) return (0, 1);
  return (low, high);
}

/// Reads [values] — a list of rows, each a list of columns — as cells.
///
/// A row shorter than the widest one simply has no cells past its end, so a
/// ragged table is drawn as the gaps it is.
List<HeatmapCell> heatmapCellsOf(List<List<double?>> values) => [
  for (var y = 0; y < values.length; y++)
    for (var x = 0; x < values[y].length; x++)
      HeatmapCell(x: x, y: y, value: values[y][x]),
];
