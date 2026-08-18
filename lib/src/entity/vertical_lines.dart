import 'dart:ui';

import 'line.dart';

/// A vertical line pinned to a [time], spanning the full chart height.
///
/// Useful for marking a session open, a news event or an order timestamp.
class VerticalLine extends ChartLine {
  /// Creates a vertical line at [time].
  VerticalLine({
    required this.time,
    this.title,
    super.color = const Color(0xFFFFFF00),
    super.thickness = 2.0,
    super.locked = false,
    super.isDashed = false,
    super.showLabel = false,
  });

  /// The instant the line sits at.
  DateTime time;

  /// Optional label painted next to the line when `showLabel` is true.
  String? title;
}
