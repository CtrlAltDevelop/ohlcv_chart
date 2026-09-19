import 'dart:ui';

import 'line.dart';
import 'two_point_drawing.dart';

/// A fan of rays from the first anchor at Fibonacci fractions of the move.
///
/// The two anchors box a swing. Each ratio in [levels] draws a ray from the
/// first anchor through the point that fraction of the way down the far edge
/// of the box, so the fan spreads between the flat `0` and the diagonal `1`.
/// Where a retracement gives horizontal support, a fan gives support that
/// slopes with time.
class FibFan extends TwoPointDrawing {
  /// Creates a fan over the swing starting at ([time1], [price1]).
  FibFan({
    required super.time1,
    required super.price1,
    super.time2,
    super.price2,
    List<double>? levels,
    super.color = const Color(0xFFFFB74D),
    super.thickness = 1.0,
    super.style,
    super.isDashed = false,
    super.locked = false,
    super.showLabel = true,
    super.hidden = false,
  }) : levels = levels ?? List<double>.of(defaultLevels);

  /// Rebuilds a fan from [json].
  factory FibFan.fromJson(Map<String, dynamic> json) {
    final first = firstAnchorFromJson(json);
    return FibFan(
      time1: first.time,
      price1: first.price,
      time2: LineJson.time(json, 'time2'),
      price2: LineJson.maybeNumber(json, 'price2'),
      levels: LineJson.numbers(json, 'levels'),
      color: LineJson.color(json, const Color(0xFFFFB74D)),
      thickness: LineJson.number(json, 'thickness', 1),
      style: LineJson.style(json),
      locked: LineJson.flag(json, 'locked'),
      showLabel: LineJson.flag(json, 'showLabel', true),
      hidden: LineJson.flag(json, 'hidden'),
    );
  }

  /// The fractions of the swing the rays are drawn through.
  static const List<double> defaultLevels = [
    0,
    0.236,
    0.382,
    0.5,
    0.618,
    0.786,
    1,
  ];

  /// The fractions of the move each ray passes through.
  List<double> levels;

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson('fibFan'),
    ...anchorsJson(),
    'levels': levels,
  };
}

/// Vertical lines at Fibonacci multiples of the span between two anchors.
///
/// The anchors set one unit of time. Every ratio in [levels] marks that many
/// units on from the first anchor, so a swing that took ten candles projects
/// lines at candles 10, 20, 30, 50, 80 and so on — the dates a turn is due,
/// rather than the prices.
class FibTimeZones extends TwoPointDrawing {
  /// Creates time zones whose unit starts at ([time1], [price1]).
  FibTimeZones({
    required super.time1,
    required super.price1,
    super.time2,
    super.price2,
    List<double>? levels,
    super.color = const Color(0xFF4DD0E1),
    super.thickness = 1.0,
    super.style,
    super.isDashed = false,
    super.locked = false,
    super.showLabel = true,
    super.hidden = false,
  }) : levels = levels ?? List<double>.of(defaultLevels);

  /// Rebuilds time zones from [json].
  factory FibTimeZones.fromJson(Map<String, dynamic> json) {
    final first = firstAnchorFromJson(json);
    return FibTimeZones(
      time1: first.time,
      price1: first.price,
      time2: LineJson.time(json, 'time2'),
      price2: LineJson.maybeNumber(json, 'price2'),
      levels: LineJson.numbers(json, 'levels'),
      color: LineJson.color(json, const Color(0xFF4DD0E1)),
      thickness: LineJson.number(json, 'thickness', 1),
      style: LineJson.style(json),
      locked: LineJson.flag(json, 'locked'),
      showLabel: LineJson.flag(json, 'showLabel', true),
      hidden: LineJson.flag(json, 'hidden'),
    );
  }

  /// The Fibonacci numbers themselves, as multiples of the unit span.
  static const List<double> defaultLevels = [0, 1, 2, 3, 5, 8, 13, 21, 34];

  /// Multiples of the unit span each line is drawn at.
  List<double> levels;

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson('fibTimeZones'),
    ...anchorsJson(),
    'levels': levels,
  };
}

/// A Fibonacci projection from a three-leg move.
///
/// The first two anchors are the impulse — the move being extended — and the
/// third is where the retracement ended. Each ratio in [levels] projects that
/// multiple of the impulse on from the third anchor, so `1` targets a move of
/// the same size again and `1.618` the usual extension.
///
/// This is the trend-based extension, not a retracement: the levels sit beyond
/// the third anchor rather than between the first two.
class FibExtension extends ThreePointDrawing {
  /// Creates an extension whose impulse starts at ([time1], [price1]).
  FibExtension({
    required super.time1,
    required super.price1,
    super.time2,
    super.price2,
    super.time3,
    super.price3,
    List<double>? levels,
    super.color = const Color(0xFFFFD54F),
    super.thickness = 1.0,
    super.style,
    super.isDashed = false,
    super.locked = false,
    super.showLabel = true,
    super.hidden = false,
  }) : levels = levels ?? List<double>.of(defaultLevels);

  /// Rebuilds an extension from [json].
  factory FibExtension.fromJson(Map<String, dynamic> json) {
    final first = firstAnchorFromJson(json);
    return FibExtension(
      time1: first.time,
      price1: first.price,
      time2: LineJson.time(json, 'time2'),
      price2: LineJson.maybeNumber(json, 'price2'),
      time3: LineJson.time(json, 'time3'),
      price3: LineJson.maybeNumber(json, 'price3'),
      levels: LineJson.numbers(json, 'levels'),
      color: LineJson.color(json, const Color(0xFFFFD54F)),
      thickness: LineJson.number(json, 'thickness', 1),
      style: LineJson.style(json),
      locked: LineJson.flag(json, 'locked'),
      showLabel: LineJson.flag(json, 'showLabel', true),
      hidden: LineJson.flag(json, 'hidden'),
    );
  }

  /// The multiples of the impulse most desks project.
  static const List<double> defaultLevels = [
    0,
    0.618,
    1,
    1.618,
    2,
    2.618,
    4.236,
  ];

  /// Multiples of the impulse each level is projected at.
  List<double> levels;

  /// The price [ratio] of the impulse projects to, from the third anchor.
  ///
  /// Null until all three anchors have landed.
  double? priceAt(double ratio) {
    final end = price2;
    final from = price3;
    if (end == null || from == null) return null;
    return from + (end - price1) * ratio;
  }

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson('fibExtension'),
    ...threeAnchorsJson(),
    'levels': levels,
  };
}
