import 'dart:ui';

import 'line.dart';
import 'two_point_drawing.dart';

/// A triangle over three corners.
///
/// Three taps, one per corner. Enough to mark out a wedge, a pennant or the
/// shape of a pattern that no box would fit.
class TriangleDrawing extends ThreePointDrawing
    implements LabelledDrawing, FilledDrawing {
  /// Creates a triangle with its first corner at ([time1], [price1]).
  TriangleDrawing({
    required super.time1,
    required super.price1,
    super.time2,
    super.price2,
    super.time3,
    super.price3,
    this.fillOpacity = 0.12,
    this.label,
    super.color = const Color(0xFF00BCD4),
    super.thickness = 1.5,
    super.style,
    super.isDashed = false,
    super.locked = false,
    super.showLabel = false,
    super.hidden = false,
  });

  /// Rebuilds a triangle from [json].
  factory TriangleDrawing.fromJson(Map<String, dynamic> json) {
    final first = firstAnchorFromJson(json);
    return TriangleDrawing(
      time1: first.time,
      price1: first.price,
      time2: LineJson.time(json, 'time2'),
      price2: LineJson.maybeNumber(json, 'price2'),
      time3: LineJson.time(json, 'time3'),
      price3: LineJson.maybeNumber(json, 'price3'),
      fillOpacity: LineJson.number(json, 'fillOpacity', 0.12),
      label: LineJson.text(json, 'label'),
      color: LineJson.color(json, const Color(0xFF00BCD4)),
      thickness: LineJson.number(json, 'thickness', 1.5),
      style: LineJson.style(json),
      locked: LineJson.flag(json, 'locked'),
      showLabel: LineJson.flag(json, 'showLabel'),
      hidden: LineJson.flag(json, 'hidden'),
    );
  }

  /// How solid the wash inside the triangle is.
  @override
  double fillOpacity;

  /// Optional label painted at the first corner.
  String? label;

  @override
  String? get labelText => label;

  @override
  set labelText(String? value) => label = value;

  /// The wash painted inside the triangle.
  Color get fillColor =>
      color.withValues(alpha: color.a * fillOpacity.clamp(0.0, 1.0));

  @override
  Map<String, dynamic> toJson() => {
        ...baseJson('triangle'),
        ...threeAnchorsJson(),
        'fillOpacity': fillOpacity,
        if (label != null) 'label': label,
      };
}
