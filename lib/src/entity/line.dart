import 'dart:ui';

/// How a user-drawn line's stroke is painted.
enum LineStyle {
  /// One continuous stroke.
  solid,

  /// Evenly spaced dashes, sized by `DrawingStyle.dashLength` and
  /// `DrawingStyle.dashGap`.
  dashed,

  /// Round dots, spaced by `DrawingStyle.dotGap`.
  dotted,
}

/// Shared appearance and interaction state for a user-drawn chart line.
///
/// Concrete lines are [HorizontalLine], [VerticalLine] and [TrendLine]. What
/// the user may change, and which values the editing toolbar offers, is
/// configured with `DrawingStyle`.
abstract class ChartLine {
  /// Creates a line with the given appearance.
  ///
  /// [style] wins over [isDashed]; pass either one.
  ChartLine({
    this.color = const Color(0xFFFFFF00),
    this.thickness = 2.0,
    LineStyle? style,
    bool isDashed = false,
    this.locked = false,
    this.showLabel = true,
  }) : style = style ?? (isDashed ? LineStyle.dashed : LineStyle.solid);

  /// Stroke colour. Its alpha channel doubles as the line's [opacity].
  Color color;

  /// Stroke width in logical pixels.
  double thickness;

  /// Whether the stroke is solid, dashed or dotted.
  LineStyle style;

  /// When true the line cannot be selected or dragged on the chart.
  bool locked;

  /// Whether the line's label is painted alongside it.
  bool showLabel;

  /// Whether the stroke is broken rather than continuous.
  ///
  /// Reads true for both [LineStyle.dashed] and [LineStyle.dotted]; writing it
  /// picks between [LineStyle.dashed] and [LineStyle.solid]. Prefer [style],
  /// which distinguishes the two broken styles.
  bool get isDashed => style != LineStyle.solid;

  set isDashed(bool value) =>
      style = value ? LineStyle.dashed : LineStyle.solid;

  /// Stroke opacity, 0 transparent to 1 opaque.
  ///
  /// Backed by the alpha channel of [color], so the two always agree.
  double get opacity => color.a;

  set opacity(double value) =>
      color = color.withValues(alpha: value.clamp(0.0, 1.0));
}
