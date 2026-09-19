import 'dart:ui';

import 'line.dart';
import 'two_point_drawing.dart';

/// A Fibonacci retracement between a swing low and a swing high.
///
/// The two anchors are the 0 and 1 levels; every ratio in [levels] is drawn as
/// a labelled horizontal line between them, so 0.618 sits 61.8% of the way
/// from the first anchor's price to the second's. Ratios outside 0–1 are
/// allowed and draw as extensions beyond the anchors.
class FibRetracement extends TwoPointDrawing implements AlertingDrawing {
  /// Creates a retracement anchored at ([time1], [price1]).
  FibRetracement({
    required super.time1,
    required super.price1,
    super.time2,
    super.price2,
    List<double>? levels,
    this.fillLevels = true,
    this.alert = false,
    super.color = const Color(0xFFFFC107),
    super.thickness = 1.0,
    super.style,
    super.isDashed = false,
    super.locked = false,
    super.showLabel = true,
    super.hidden = false,
  }) : levels = levels ?? List<double>.of(defaultLevels);

  /// Rebuilds a retracement from [json].
  factory FibRetracement.fromJson(Map<String, dynamic> json) {
    final first = firstAnchorFromJson(json);
    return FibRetracement(
      time1: first.time,
      price1: first.price,
      time2: LineJson.time(json, 'time2'),
      price2: LineJson.maybeNumber(json, 'price2'),
      levels: LineJson.numbers(json, 'levels'),
      fillLevels: LineJson.flag(json, 'fillLevels', true),
      alert: LineJson.flag(json, 'alert'),
      color: LineJson.color(json, const Color(0xFFFFC107)),
      thickness: LineJson.number(json, 'thickness', 1),
      style: LineJson.style(json),
      locked: LineJson.flag(json, 'locked'),
      showLabel: LineJson.flag(json, 'showLabel', true),
      hidden: LineJson.flag(json, 'hidden'),
    );
  }

  /// The ratios most charting desks draw by default.
  static const List<double> defaultLevels = [
    0,
    0.236,
    0.382,
    0.5,
    0.618,
    0.786,
    1,
  ];

  /// The ratios drawn between the two anchors, as fractions of the move.
  List<double> levels;

  /// Whether the bands between neighbouring levels are washed in.
  bool fillLevels;

  /// Whether the market crossing any of the levels fires an alert.
  @override
  bool alert;

  @override
  List<double> alertLevelsAt(DateTime time) {
    if (!hasSecondPoint) return const [];
    // The levels are read from the swing rightwards, the way a retracement is
    // used: what matters is where price goes after the move, not during it.
    final from = time1.isBefore(time2!) ? time1 : time2!;
    if (time.isBefore(from)) return const [];
    return [
      for (final ratio in levels)
        if (priceAt(ratio) case final v?) v,
    ];
  }

  /// The price at [ratio] of the way from the first anchor to the second.
  ///
  /// Null until both anchors have landed.
  double? priceAt(double ratio) {
    final end = price2;
    if (end == null) return null;
    return price1 + (end - price1) * ratio;
  }

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson('fibRetracement'),
    ...anchorsJson(),
    'levels': levels,
    'fillLevels': fillLevels,
    'alert': alert,
  };
}
