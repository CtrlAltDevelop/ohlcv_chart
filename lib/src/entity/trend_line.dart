import 'package:flutter/material.dart';

import 'line.dart';
import 'two_point_drawing.dart';

/// How far past its two anchors a line keeps going.
enum LineExtension {
  /// The line stops at both anchors: an ordinary segment.
  none,

  /// The line carries on past the second anchor to the edge of the chart: a
  /// ray.
  right,

  /// The line carries on past both anchors: an extended line.
  both,
}

/// A free-form line between two (time, price) points.
///
/// A trend line starts anchored at ([time1], [price1]); while the user is
/// still placing it, [time2] and [price2] are null. Once both ends are set the
/// line can be selected and either end dragged to a new anchor.
///
/// [extend] turns the same two anchors into a ray or an extended line, and
/// [arrow] puts an arrowhead on the far end.
class TrendLine extends TwoPointDrawing {
  /// Creates a trend line anchored at ([time1], [price1]).
  TrendLine({
    required super.time1,
    required super.price1,
    super.time2,
    super.price2,
    this.label1,
    this.label2,
    this.extend = LineExtension.none,
    this.arrow = false,
    super.color = Colors.yellow,
    super.thickness = 2.0,
    super.style,
    super.isDashed = false,
    super.locked = false,
    super.showLabel = false,
    super.hidden = false,
  });

  /// Rebuilds a trend line, ray, extended line or arrow from [json].
  factory TrendLine.fromJson(Map<String, dynamic> json) {
    final first = firstAnchorFromJson(json);
    return TrendLine(
      time1: first.time,
      price1: first.price,
      time2: LineJson.time(json, 'time2'),
      price2: LineJson.maybeNumber(json, 'price2'),
      label1: LineJson.text(json, 'label1'),
      label2: LineJson.text(json, 'label2'),
      extend: LineJson.enumValue(
        json,
        'extend',
        LineExtension.values,
        LineExtension.none,
      ),
      arrow: LineJson.flag(json, 'arrow'),
      color: LineJson.color(json, Colors.yellow),
      thickness: LineJson.number(json, 'thickness', 2),
      style: LineJson.style(json),
      locked: LineJson.flag(json, 'locked'),
      showLabel: LineJson.flag(json, 'showLabel'),
      hidden: LineJson.flag(json, 'hidden'),
    );
  }

  /// Optional label painted at the first anchor.
  String? label1;

  /// Optional label painted at the second anchor.
  String? label2;

  /// How far past its anchors the line carries on.
  LineExtension extend;

  /// Whether an arrowhead is painted at the second anchor.
  bool arrow;

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson('trend'),
    ...anchorsJson(),
    if (label1 != null) 'label1': label1,
    if (label2 != null) 'label2': label2,
    'extend': extend.name,
    'arrow': arrow,
  };
}
