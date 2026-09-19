import 'dart:ui';

import 'line.dart';
import 'two_point_drawing.dart';

/// A box between two opposite corners, marking out a price range over a span
/// of time.
///
/// The outline is stroked in [color] at [thickness] and [style]; the inside is
/// washed with the same colour at [fillOpacity].
class RectangleDrawing extends TwoPointDrawing
    implements LabelledDrawing, FilledDrawing {
  /// Creates a rectangle with one corner at ([time1], [price1]).
  RectangleDrawing({
    required super.time1,
    required super.price1,
    super.time2,
    super.price2,
    this.fillOpacity = 0.12,
    this.label,
    super.color = const Color(0xFF4DABF7),
    super.thickness = 1.5,
    super.style,
    super.isDashed = false,
    super.locked = false,
    super.showLabel = false,
    super.hidden = false,
  });

  /// Rebuilds a rectangle from [json].
  factory RectangleDrawing.fromJson(Map<String, dynamic> json) {
    final first = firstAnchorFromJson(json);
    return RectangleDrawing(
      time1: first.time,
      price1: first.price,
      time2: LineJson.time(json, 'time2'),
      price2: LineJson.maybeNumber(json, 'price2'),
      fillOpacity: LineJson.number(json, 'fillOpacity', 0.12),
      label: LineJson.text(json, 'label'),
      color: LineJson.color(json, const Color(0xFF4DABF7)),
      thickness: LineJson.number(json, 'thickness', 1.5),
      style: LineJson.style(json),
      locked: LineJson.flag(json, 'locked'),
      showLabel: LineJson.flag(json, 'showLabel'),
      hidden: LineJson.flag(json, 'hidden'),
    );
  }

  /// How solid the wash inside the box is, 0 transparent to 1 opaque.
  @override
  double fillOpacity;

  /// Optional label painted at the top of the box.
  String? label;

  @override
  String? get labelText => label;

  @override
  set labelText(String? value) => label = value;

  /// The wash painted inside the box.
  Color get fillColor =>
      color.withValues(alpha: color.a * fillOpacity.clamp(0.0, 1.0));

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson('rectangle'),
    ...anchorsJson(),
    'fillOpacity': fillOpacity,
    if (label != null) 'label': label,
  };
}
