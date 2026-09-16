import 'package:flutter/foundation.dart';

import 'line.dart';

/// A drawing anchored to two (time, price) points on the chart.
///
/// While the user is still placing one, [time2] and [price2] are null: the
/// first point has landed and the second is still following the pointer. Once
/// both are set the drawing can be selected, and either point — or the whole
/// shape — dragged somewhere else.
///
/// Anchoring to times rather than pixels is what keeps a drawing on the same
/// candles when the chart is panned, zoomed or reloaded.
abstract class TwoPointDrawing extends ChartLine {
  /// Creates a drawing anchored at ([time1], [price1]).
  TwoPointDrawing({
    required this.time1,
    required this.price1,
    this.time2,
    this.price2,
    super.color,
    super.thickness,
    super.style,
    super.isDashed,
    super.locked,
    super.showLabel,
    super.hidden,
  });

  /// Time of the first anchor.
  DateTime time1;

  /// Time of the second anchor, or null while the drawing is being placed.
  DateTime? time2;

  /// Price of the first anchor.
  double price1;

  /// Price of the second anchor, or null while the drawing is being placed.
  double? price2;

  /// Whether the second anchor has landed.
  bool get hasSecondPoint => time2 != null && price2 != null;

  /// Whether every anchor has landed.
  ///
  /// Shapes that take a third point — a channel, a position, a triangle —
  /// override this with the point they are still waiting for.
  bool get isComplete => hasSecondPoint;

  /// How many points the user places to draw this shape.
  ///
  /// Two for most of them; three for the ones that need a width or a level as
  /// well as a base line.
  int get pointCount => 2;

  /// Where the line through both anchors sits at [time], carried on past them.
  ///
  /// Useful to any shape whose geometry is "a sloping line and some offset from
  /// it": a trend line's own price at a candle, a channel's base, a
  /// regression's anchors. With only one anchor placed, or with both at the
  /// same instant, the line is flat and this is simply [price1].
  double priceOnLineAt(DateTime time) {
    final endTime = time2;
    final endPrice = price2;
    if (endTime == null || endPrice == null) return price1;

    final run = endTime.difference(time1).inMicroseconds;
    if (run == 0) return price1;
    final along = time.difference(time1).inMicroseconds / run;
    return price1 + (endPrice - price1) * along;
  }

  /// Both anchors, ready to be merged into a subclass's JSON map.
  @protected
  Map<String, dynamic> anchorsJson() => <String, dynamic>{
        'time1': time1.toIso8601String(),
        'price1': price1,
        if (time2 != null) 'time2': time2!.toIso8601String(),
        if (price2 != null) 'price2': price2,
      };
}

/// The first anchor of a serialised two-point drawing.
///
/// A drawing whose first anchor is missing cannot be placed at all, so it falls
/// back to the epoch and a price of zero rather than failing the whole load.
({DateTime time, double price}) firstAnchorFromJson(
  Map<String, dynamic> json,
) =>
    (
      time: LineJson.time(json, 'time1') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      price: LineJson.number(json, 'price1'),
    );

/// A drawing anchored to three (time, price) points.
///
/// The first two are placed like any other shape; the third arrives on one more
/// tap, and is what gives a channel its width, a position its stop and a
/// triangle its last corner.
abstract class ThreePointDrawing extends TwoPointDrawing {
  /// Creates a drawing anchored at ([time1], [price1]).
  ThreePointDrawing({
    required super.time1,
    required super.price1,
    super.time2,
    super.price2,
    this.time3,
    this.price3,
    super.color,
    super.thickness,
    super.style,
    super.isDashed,
    super.locked,
    super.showLabel,
    super.hidden,
  });

  /// Time of the third anchor, or null while it is still being placed.
  DateTime? time3;

  /// Price of the third anchor, or null while it is still being placed.
  double? price3;

  @override
  bool get isComplete => hasSecondPoint && time3 != null && price3 != null;

  @override
  int get pointCount => 3;

  /// All three anchors, ready to be merged into a subclass's JSON map.
  @protected
  Map<String, dynamic> threeAnchorsJson() => <String, dynamic>{
        ...anchorsJson(),
        if (time3 != null) 'time3': time3!.toIso8601String(),
        if (price3 != null) 'price3': price3,
      };
}
