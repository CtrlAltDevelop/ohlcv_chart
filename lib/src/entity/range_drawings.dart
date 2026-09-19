import 'dart:ui';

import 'line.dart';
import 'two_point_drawing.dart';

/// A bracket over a stretch of price, reading out how far it is.
///
/// Where a measurement reads price and time together, this reads price alone:
/// two levels, a bracket between them, and a label giving the move in price and
/// in percent. Both anchors take their time from wherever they were dropped,
/// which fixes where the bracket is drawn but not what it says.
class PriceRangeDrawing extends TwoPointDrawing implements FilledDrawing {
  /// Creates a price bracket anchored at ([time1], [price1]).
  PriceRangeDrawing({
    required super.time1,
    required super.price1,
    super.time2,
    super.price2,
    this.fillOpacity = 0.1,
    super.color = const Color(0xFF26C6DA),
    super.thickness = 1.0,
    super.style,
    super.isDashed = false,
    super.locked = false,
    super.showLabel = true,
    super.hidden = false,
  });

  /// Rebuilds a price bracket from [json].
  factory PriceRangeDrawing.fromJson(Map<String, dynamic> json) {
    final first = firstAnchorFromJson(json);
    return PriceRangeDrawing(
      time1: first.time,
      price1: first.price,
      time2: LineJson.time(json, 'time2'),
      price2: LineJson.maybeNumber(json, 'price2'),
      fillOpacity: LineJson.number(json, 'fillOpacity', 0.1),
      color: LineJson.color(json, const Color(0xFF26C6DA)),
      thickness: LineJson.number(json, 'thickness', 1),
      style: LineJson.style(json),
      locked: LineJson.flag(json, 'locked'),
      showLabel: LineJson.flag(json, 'showLabel', true),
      hidden: LineJson.flag(json, 'hidden'),
    );
  }

  /// How solid the wash between the two levels is.
  @override
  double fillOpacity;

  /// The move in price, or null until the second anchor lands.
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

  /// Whether the bracketed move was upwards.
  bool get isUp => (priceMove ?? 0) >= 0;

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson('priceRange'),
    ...anchorsJson(),
    'fillOpacity': fillOpacity,
  };
}

/// A bracket under a stretch of time, reading out how long it is.
///
/// The mirror of [PriceRangeDrawing]: two verticals, a bracket between them,
/// and a label giving the span in candles and in time. The prices the anchors
/// were dropped at fix where the bracket sits, not what it says.
class DateRangeDrawing extends TwoPointDrawing implements FilledDrawing {
  /// Creates a date bracket anchored at ([time1], [price1]).
  DateRangeDrawing({
    required super.time1,
    required super.price1,
    super.time2,
    super.price2,
    this.fillOpacity = 0.1,
    super.color = const Color(0xFF26C6DA),
    super.thickness = 1.0,
    super.style,
    super.isDashed = false,
    super.locked = false,
    super.showLabel = true,
    super.hidden = false,
  });

  /// Rebuilds a date bracket from [json].
  factory DateRangeDrawing.fromJson(Map<String, dynamic> json) {
    final first = firstAnchorFromJson(json);
    return DateRangeDrawing(
      time1: first.time,
      price1: first.price,
      time2: LineJson.time(json, 'time2'),
      price2: LineJson.maybeNumber(json, 'price2'),
      fillOpacity: LineJson.number(json, 'fillOpacity', 0.1),
      color: LineJson.color(json, const Color(0xFF26C6DA)),
      thickness: LineJson.number(json, 'thickness', 1),
      style: LineJson.style(json),
      locked: LineJson.flag(json, 'locked'),
      showLabel: LineJson.flag(json, 'showLabel', true),
      hidden: LineJson.flag(json, 'hidden'),
    );
  }

  /// How solid the wash between the two verticals is.
  @override
  double fillOpacity;

  /// How long the bracketed span lasted, or null until it can be told.
  Duration? get span => time2?.difference(time1).abs();

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson('dateRange'),
    ...anchorsJson(),
    'fillOpacity': fillOpacity,
  };
}
