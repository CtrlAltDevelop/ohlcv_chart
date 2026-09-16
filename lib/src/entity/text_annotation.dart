import 'dart:ui';

import 'line.dart';

/// A note pinned to one point on the chart.
///
/// One tap places it and the editor's text field names it. Handy for marking
/// what happened — an announcement, a fill, a reason for the trade — where it
/// happened.
class TextAnnotation extends ChartLine implements LabelledDrawing {
  /// Creates a note at ([time], [price]).
  TextAnnotation({
    required this.time,
    required this.price,
    this.text,
    this.pointer = true,
    super.color = const Color(0xFFFFFFFF),
    super.thickness = 1.0,
    super.style,
    super.isDashed = false,
    super.locked = false,
    super.showLabel = true,
    super.hidden = false,
  });

  /// Rebuilds a note from [json].
  factory TextAnnotation.fromJson(Map<String, dynamic> json) => TextAnnotation(
        time: LineJson.time(json, 'time') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        price: LineJson.number(json, 'price'),
        text: LineJson.text(json, 'text'),
        pointer: LineJson.flag(json, 'pointer', true),
        color: LineJson.color(json, const Color(0xFFFFFFFF)),
        thickness: LineJson.number(json, 'thickness', 1),
        style: LineJson.style(json),
        locked: LineJson.flag(json, 'locked'),
        showLabel: LineJson.flag(json, 'showLabel', true),
        hidden: LineJson.flag(json, 'hidden'),
      );

  /// The candle the note is pinned to.
  DateTime time;

  /// The price the note is pinned at.
  double price;

  /// What the note says.
  String? text;

  /// Whether a short leader line joins the note to the point it marks.
  bool pointer;

  @override
  String? get labelText => text;

  @override
  set labelText(String? value) => text = value;

  @override
  Map<String, dynamic> toJson() => {
        ...baseJson('text'),
        'time': time.toIso8601String(),
        'price': price,
        if (text != null) 'text': text,
        'pointer': pointer,
      };
}
