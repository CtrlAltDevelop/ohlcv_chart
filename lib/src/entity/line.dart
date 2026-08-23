import 'dart:ui';

import 'package:flutter/foundation.dart';

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
/// Concrete drawings are [HorizontalLine] and [VerticalLine], plus the
/// two-anchor family built on `TwoPointDrawing`: [TrendLine] — which also
/// covers rays, extended lines and arrows — `RectangleDrawing`,
/// `EllipseDrawing`, `FibRetracement`, `MeasureDrawing`, `ParallelChannel`,
/// `PositionDrawing` and `TriangleDrawing` — and the point-anchored
/// `TextAnnotation` and `FreehandDrawing`. What the user may change, and which
/// values the editing toolbar offers, is configured with `DrawingStyle`.
///
/// A drawing that can be alerted on mixes in `AlertingDrawing`, and one whose
/// interior is washed `FilledDrawing`; a drawing the user can name mixes in
/// `LabelledDrawing`.
///
/// Every drawing serialises: [toJson] round-trips through `drawingFromJson`,
/// which is how a chart's drawings are persisted and restored.
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
    this.hidden = false,
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

  /// When true the drawing is left unpainted and cannot be selected.
  ///
  /// Toggled from the drawing manager, so a layout can be put aside without
  /// deleting it.
  bool hidden;

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

  /// This drawing as a JSON-encodable map, tagged with its kind.
  ///
  /// `drawingFromJson` turns the map back into the same drawing, so a saved
  /// layout survives a restart, and `copyDrawing` uses the pair to clone one.
  Map<String, dynamic> toJson();

  /// The fields every drawing shares, tagged as [type].
  ///
  /// Subclasses build their own map on top of this one.
  @protected
  Map<String, dynamic> baseJson(String type) => <String, dynamic>{
    'type': type,
    'color': color.toARGB32(),
    'thickness': thickness,
    'style': style.name,
    'locked': locked,
    'showLabel': showLabel,
    'hidden': hidden,
  };
}

/// Readers for the values a drawing's JSON map holds.
///
/// Every one of them tolerates a missing or malformed field: a layout saved by
/// an older version, or hand-edited, still loads.
abstract final class LineJson {
  /// The colour at [key], or [fallback] when it is missing.
  static Color color(
    Map<String, dynamic> json, [
    Color fallback = const Color(0xFFFFFF00),
    String key = 'color',
  ]) {
    final value = json[key];
    return value is num ? Color(value.toInt()) : fallback;
  }

  /// The number at [key], or [fallback] when it is missing.
  static double number(
    Map<String, dynamic> json,
    String key, [
    double fallback = 0,
  ]) {
    final value = json[key];
    return value is num ? value.toDouble() : fallback;
  }

  /// The number at [key], or null when it is missing.
  static double? maybeNumber(Map<String, dynamic> json, String key) {
    final value = json[key];
    return value is num ? value.toDouble() : null;
  }

  /// The flag at [key], or [fallback] when it is missing.
  static bool flag(
    Map<String, dynamic> json,
    String key, [
    bool fallback = false,
  ]) {
    final value = json[key];
    return value is bool ? value : fallback;
  }

  /// The string at [key], or null when it is missing or empty.
  static String? text(Map<String, dynamic> json, String key) {
    final value = json[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  /// The stroke style at [key], or [fallback] when it is missing.
  static LineStyle style(
    Map<String, dynamic> json, [
    LineStyle fallback = LineStyle.solid,
    String key = 'style',
  ]) {
    final value = json[key];
    return LineStyle.values.firstWhere(
      (candidate) => candidate.name == value,
      orElse: () => fallback,
    );
  }

  /// The enum value named at [key], or [fallback] when it is missing.
  static T enumValue<T extends Enum>(
    Map<String, dynamic> json,
    String key,
    List<T> values,
    T fallback,
  ) {
    final value = json[key];
    return values.firstWhere(
      (candidate) => candidate.name == value,
      orElse: () => fallback,
    );
  }

  /// The instant at [key], or null when it is missing or unparseable.
  static DateTime? time(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String) return DateTime.tryParse(value);
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
    }
    return null;
  }

  /// The list of numbers at [key], or null when it is missing.
  static List<double>? numbers(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! List) return null;
    return [
      for (final entry in value)
        if (entry is num) entry.toDouble(),
    ];
  }
}

/// A drawing with a label the user can type.
///
/// The line editor's text field writes through this, so every drawing that can
/// be named is named the same way.
abstract mixin class LabelledDrawing implements ChartLine {
  /// The label's text, or null when it has none.
  String? get labelText;

  set labelText(String? value);
}

/// A drawing whose levels the market can cross, and be reported for.
///
/// Set [alert] and the chart watches every level the drawing has at the newest
/// candle, reporting through `KChartWidget.onDrawingAlert` whenever the close
/// moves from one side of one of them to the other. A horizontal level has one
/// level and it never moves; a trend line's moves with time; a retracement or a
/// channel has several at once.
///
/// [alertLevelsAt] is asked for the levels at one instant, so a sloping line
/// answers for where it is at that candle rather than where it was drawn.
abstract mixin class AlertingDrawing implements ChartLine {
  /// Whether crossing one of this drawing's levels fires an alert.
  bool get alert;

  set alert(bool value);

  /// The prices this drawing sits at, at [time].
  ///
  /// Empty where the drawing has nothing to cross there: a half-placed shape,
  /// or a ray at a candle before it starts.
  List<double> alertLevelsAt(DateTime time);
}

/// A drawing with an interior washed in its own colour.
///
/// The line editor's fill slider writes through this.
abstract mixin class FilledDrawing implements ChartLine {
  /// How solid the wash is, 0 transparent to 1 opaque.
  double get fillOpacity;

  set fillOpacity(double value);
}
