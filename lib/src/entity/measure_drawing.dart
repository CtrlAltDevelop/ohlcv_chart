import 'dart:ui';

import 'line.dart';
import 'two_point_drawing.dart';

/// A ruler laid over the candles: how far price moved, over how many candles,
/// and how long that took.
///
/// The busiest tool on any desk. Drag from one point to another and the box
/// reads out the move in price, in percent, in candles and in time; the wash
/// takes the up or down colour depending on which way the move went.
class MeasureDrawing extends TwoPointDrawing implements FilledDrawing {
  /// Creates a measurement anchored at ([time1], [price1]).
  MeasureDrawing({
    required super.time1,
    required super.price1,
    super.time2,
    super.price2,
    this.fillOpacity = 0.14,
    super.color = const Color(0xFF2962FF),
    super.thickness = 1.0,
    super.style,
    super.isDashed = false,
    super.locked = false,
    super.showLabel = true,
    super.hidden = false,
  });

  /// Rebuilds a measurement from [json].
  factory MeasureDrawing.fromJson(Map<String, dynamic> json) {
    final first = firstAnchorFromJson(json);
    return MeasureDrawing(
      time1: first.time,
      price1: first.price,
      time2: LineJson.time(json, 'time2'),
      price2: LineJson.maybeNumber(json, 'price2'),
      fillOpacity: LineJson.number(json, 'fillOpacity', 0.14),
      color: LineJson.color(json, const Color(0xFF2962FF)),
      thickness: LineJson.number(json, 'thickness', 1),
      style: LineJson.style(json),
      locked: LineJson.flag(json, 'locked'),
      showLabel: LineJson.flag(json, 'showLabel', true),
      hidden: LineJson.flag(json, 'hidden'),
    );
  }

  /// How solid the wash over the measured span is.
  @override
  double fillOpacity;

  /// The move in price, or null until the second point lands.
  double? get priceMove {
    final end = price2;
    return end == null ? null : end - price1;
  }

  /// The move as a fraction of where it started, or null until it can be told.
  double? get ratio {
    final move = priceMove;
    if (move == null || price1 == 0) return null;
    return move / price1;
  }

  /// How long the measured span lasted, or null until it can be told.
  Duration? get span => time2?.difference(time1).abs();

  /// Whether the measured move was upwards.
  bool get isUp => (priceMove ?? 0) >= 0;

  @override
  Map<String, dynamic> toJson() => {
        ...baseJson('measure'),
        ...anchorsJson(),
        'fillOpacity': fillOpacity,
      };
}
