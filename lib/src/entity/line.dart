import 'dart:ui';

/// Shared appearance and interaction state for a user-drawn chart line.
///
/// Concrete lines are [HorizontalLine], [VerticalLine] and [TrendLine].
abstract class ChartLine {
  /// Creates a line with the given appearance.
  ChartLine({
    this.color = const Color(0xFFFFFF00),
    this.thickness = 2.0,
    this.isDashed = false,
    this.locked = false,
    this.showLabel = true,
  });

  /// Stroke colour.
  Color color;

  /// Stroke width in logical pixels.
  double thickness;

  /// Whether the line is drawn dashed rather than solid.
  bool isDashed;

  /// When true the line cannot be selected or dragged on the chart.
  bool locked;

  /// Whether the line's label is painted alongside it.
  bool showLabel;
}
