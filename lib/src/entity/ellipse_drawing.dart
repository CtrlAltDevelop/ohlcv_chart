import 'dart:ui';

import 'line.dart';
import 'two_point_drawing.dart';

/// An ellipse inscribed in the box between two opposite corners.
///
/// Useful for ringing an area of the chart — a consolidation, a gap, a pattern
/// — without the hard edges of a rectangle.
class EllipseDrawing extends TwoPointDrawing
    implements LabelledDrawing, FilledDrawing {
  /// Creates an ellipse inside the box with one corner at ([time1], [price1]).
  EllipseDrawing({
    required super.time1,
    required super.price1,
    super.time2,
    super.price2,
    this.fillOpacity = 0.12,
    this.label,
    super.color = const Color(0xFF9C27B0),
    super.thickness = 1.5,
    super.style,
    super.isDashed = false,
    super.locked = false,
    super.showLabel = false,
    super.hidden = false,
  });

  /// Rebuilds an ellipse from [json].
  factory EllipseDrawing.fromJson(Map<String, dynamic> json) {
    final first = firstAnchorFromJson(json);
    return EllipseDrawing(
      time1: first.time,
      price1: first.price,
      time2: LineJson.time(json, 'time2'),
      price2: LineJson.maybeNumber(json, 'price2'),
      fillOpacity: LineJson.number(json, 'fillOpacity', 0.12),
      label: LineJson.text(json, 'label'),
      color: LineJson.color(json, const Color(0xFF9C27B0)),
      thickness: LineJson.number(json, 'thickness', 1.5),
      style: LineJson.style(json),
      locked: LineJson.flag(json, 'locked'),
      showLabel: LineJson.flag(json, 'showLabel'),
      hidden: LineJson.flag(json, 'hidden'),
    );
  }

  /// How solid the wash inside the ellipse is.
  @override
  double fillOpacity;

  /// Optional label painted at the top of the ellipse.
  String? label;

  @override
  String? get labelText => label;

  @override
  set labelText(String? value) => label = value;

  /// The wash painted inside the ellipse.
  Color get fillColor =>
      color.withValues(alpha: color.a * fillOpacity.clamp(0.0, 1.0));

  @override
  Map<String, dynamic> toJson() => {
        ...baseJson('ellipse'),
        ...anchorsJson(),
        'fillOpacity': fillOpacity,
        if (label != null) 'label': label,
      };
}
