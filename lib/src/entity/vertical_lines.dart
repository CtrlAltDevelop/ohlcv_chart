import 'dart:ui';

import 'line.dart';

/// A vertical line pinned to a [time], spanning the full chart height.
///
/// Useful for marking a session open, a news event or an order timestamp.
class VerticalLine extends ChartLine implements LabelledDrawing {
  /// Creates a vertical line at [time].
  VerticalLine({
    required this.time,
    this.title,
    super.color = const Color(0xFFFFFF00),
    super.thickness = 2.0,
    super.locked = false,
    super.style,
    super.isDashed = false,
    super.showLabel = false,
    super.hidden = false,
  });

  /// Rebuilds a vertical line from [json].
  factory VerticalLine.fromJson(Map<String, dynamic> json) => VerticalLine(
    time:
        LineJson.time(json, 'time') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    title: LineJson.text(json, 'title'),
    color: LineJson.color(json),
    thickness: LineJson.number(json, 'thickness', 2),
    style: LineJson.style(json),
    locked: LineJson.flag(json, 'locked'),
    showLabel: LineJson.flag(json, 'showLabel'),
    hidden: LineJson.flag(json, 'hidden'),
  );

  /// The instant the line sits at.
  DateTime time;

  /// Optional label painted next to the line when `showLabel` is true.
  String? title;

  @override
  String? get labelText => title;

  @override
  set labelText(String? value) => title = value;

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson('vertical'),
    'time': time.toIso8601String(),
    if (title != null) 'title': title,
  };
}
