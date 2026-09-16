import 'dart:ui';

import 'line.dart';
import 'two_point_drawing.dart';

/// A note in a box, with a tail pointing at the candle it is about.
///
/// The first anchor is what the note points at; the second is where the box
/// sits, so a crowded area can be annotated without covering it. A
/// [TextAnnotation] pins text to a point; a callout puts the text somewhere
/// else and draws the line back.
class CalloutDrawing extends TwoPointDrawing
    implements LabelledDrawing, FilledDrawing {
  /// Creates a callout pointing at ([time1], [price1]).
  CalloutDrawing({
    required super.time1,
    required super.price1,
    super.time2,
    super.price2,
    this.text,
    this.fillOpacity = 0.9,
    super.color = const Color(0xFFFFF176),
    super.thickness = 1.0,
    super.style,
    super.isDashed = false,
    super.locked = false,
    super.showLabel = true,
    super.hidden = false,
  });

  /// Rebuilds a callout from [json].
  factory CalloutDrawing.fromJson(Map<String, dynamic> json) {
    final first = firstAnchorFromJson(json);
    return CalloutDrawing(
      time1: first.time,
      price1: first.price,
      time2: LineJson.time(json, 'time2'),
      price2: LineJson.maybeNumber(json, 'price2'),
      text: LineJson.text(json, 'text'),
      fillOpacity: LineJson.number(json, 'fillOpacity', 0.9),
      color: LineJson.color(json, const Color(0xFFFFF176)),
      thickness: LineJson.number(json, 'thickness', 1),
      style: LineJson.style(json),
      locked: LineJson.flag(json, 'locked'),
      showLabel: LineJson.flag(json, 'showLabel', true),
      hidden: LineJson.flag(json, 'hidden'),
    );
  }

  /// What the callout says.
  String? text;

  /// How solid the box behind the text is.
  ///
  /// Higher than the other shapes by default: a note has to be readable over
  /// whatever it is covering.
  @override
  double fillOpacity;

  @override
  String? get labelText => text;

  @override
  set labelText(String? value) => text = value;

  @override
  Map<String, dynamic> toJson() => {
        ...baseJson('callout'),
        ...anchorsJson(),
        if (text != null) 'text': text,
        'fillOpacity': fillOpacity,
      };
}

/// A pennant pinned to one candle, on a short staff.
///
/// One tap plants it. Marks a candle worth coming back to — an entry, an
/// announcement, the start of a pattern — in less room than a note takes.
class FlagDrawing extends ChartLine implements LabelledDrawing {
  /// Creates a flag on the candle at [time], flown from [price].
  FlagDrawing({
    required this.time,
    required this.price,
    this.text,
    this.staffHeight = 28,
    super.color = const Color(0xFFEF5350),
    super.thickness = 1.5,
    super.style,
    super.isDashed = false,
    super.locked = false,
    super.showLabel = true,
    super.hidden = false,
  });

  /// Rebuilds a flag from [json].
  factory FlagDrawing.fromJson(Map<String, dynamic> json) => FlagDrawing(
        time: LineJson.time(json, 'time') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        price: LineJson.number(json, 'price'),
        text: LineJson.text(json, 'text'),
        staffHeight: LineJson.number(json, 'staffHeight', 28),
        color: LineJson.color(json, const Color(0xFFEF5350)),
        thickness: LineJson.number(json, 'thickness', 1.5),
        style: LineJson.style(json),
        locked: LineJson.flag(json, 'locked'),
        showLabel: LineJson.flag(json, 'showLabel', true),
        hidden: LineJson.flag(json, 'hidden'),
      );

  /// The candle the flag is planted on.
  DateTime time;

  /// The price the staff is planted at.
  double price;

  /// What is written beside the flag, if anything.
  String? text;

  /// How tall the staff is, in logical pixels.
  ///
  /// Measured on screen rather than in price, so a flag is the same size
  /// whatever the chart is zoomed to.
  double staffHeight;

  @override
  String? get labelText => text;

  @override
  set labelText(String? value) => text = value;

  @override
  Map<String, dynamic> toJson() => {
        ...baseJson('flag'),
        'time': time.toIso8601String(),
        'price': price,
        if (text != null) 'text': text,
        'staffHeight': staffHeight,
      };
}
