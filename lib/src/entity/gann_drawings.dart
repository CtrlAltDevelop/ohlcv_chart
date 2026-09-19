import 'dart:ui';

import 'line.dart';
import 'two_point_drawing.dart';

/// A fan of rays leaving the first anchor at Gann's angles.
///
/// The second anchor sets the `1×1` — the line Gann called the balance between
/// price and time — and every other ray is that slope multiplied or divided by
/// one of [ratios]. `1×2` rises twice as steeply, `2×1` half as steeply, and so
/// on out to the shallowest and sharpest of the set.
class GannFan extends TwoPointDrawing {
  /// Creates a fan whose `1×1` runs from ([time1], [price1]).
  GannFan({
    required super.time1,
    required super.price1,
    super.time2,
    super.price2,
    List<double>? ratios,
    super.color = const Color(0xFF64B5F6),
    super.thickness = 1.0,
    super.style,
    super.isDashed = false,
    super.locked = false,
    super.showLabel = true,
    super.hidden = false,
  }) : ratios = ratios ?? List<double>.of(defaultRatios);

  /// Rebuilds a fan from [json].
  factory GannFan.fromJson(Map<String, dynamic> json) {
    final first = firstAnchorFromJson(json);
    return GannFan(
      time1: first.time,
      price1: first.price,
      time2: LineJson.time(json, 'time2'),
      price2: LineJson.maybeNumber(json, 'price2'),
      ratios: LineJson.numbers(json, 'ratios'),
      color: LineJson.color(json, const Color(0xFF64B5F6)),
      thickness: LineJson.number(json, 'thickness', 1),
      style: LineJson.style(json),
      locked: LineJson.flag(json, 'locked'),
      showLabel: LineJson.flag(json, 'showLabel', true),
      hidden: LineJson.flag(json, 'hidden'),
    );
  }

  /// The eight rays of the usual Gann fan, steepest first.
  ///
  /// Each is the `1×1` slope times the ratio, so `8` is the `1×8` and `0.125`
  /// is the `8×1`.
  static const List<double> defaultRatios = [
    8,
    4,
    3,
    2,
    1,
    0.5,
    1 / 3,
    0.25,
    0.125,
  ];

  /// Multiples of the `1×1` slope this fan draws.
  List<double> ratios;

  /// What a ray at [ratio] is called: `1×1`, `1×2`, `2×1`.
  ///
  /// Gann's own notation, where the first number counts price units and the
  /// second time units, so a steeper ray is `1×n` and a shallower one `n×1`.
  static String labelFor(double ratio) {
    if (ratio == 1) return '1×1';
    if (ratio > 1) return '1×${_whole(ratio)}';
    return '${_whole(1 / ratio)}×1';
  }

  /// A ratio printed without a pointless `.0`, and rounded where it is a third.
  static String _whole(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.01) return rounded.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson('gannFan'),
    ...anchorsJson(),
    'ratios': ratios,
  };
}

/// A box between two anchors, ruled at the same fractions across and down.
///
/// Gann read a range by its own proportions rather than by absolute levels, so
/// the box is divided at [ratios] both ways: the horizontals mark those
/// fractions of the price range and the verticals the same fractions of the
/// time span. Where two of them cross is a level in both price and time.
class GannBox extends TwoPointDrawing implements FilledDrawing {
  /// Creates a box with one corner at ([time1], [price1]).
  GannBox({
    required super.time1,
    required super.price1,
    super.time2,
    super.price2,
    List<double>? ratios,
    this.showDiagonals = true,
    this.fillOpacity = 0.05,
    super.color = const Color(0xFF9575CD),
    super.thickness = 1.0,
    super.style,
    super.isDashed = false,
    super.locked = false,
    super.showLabel = true,
    super.hidden = false,
  }) : ratios = ratios ?? List<double>.of(defaultRatios);

  /// Rebuilds a box from [json].
  factory GannBox.fromJson(Map<String, dynamic> json) {
    final first = firstAnchorFromJson(json);
    return GannBox(
      time1: first.time,
      price1: first.price,
      time2: LineJson.time(json, 'time2'),
      price2: LineJson.maybeNumber(json, 'price2'),
      ratios: LineJson.numbers(json, 'ratios'),
      showDiagonals: LineJson.flag(json, 'showDiagonals', true),
      fillOpacity: LineJson.number(json, 'fillOpacity', 0.05),
      color: LineJson.color(json, const Color(0xFF9575CD)),
      thickness: LineJson.number(json, 'thickness', 1),
      style: LineJson.style(json),
      locked: LineJson.flag(json, 'locked'),
      showLabel: LineJson.flag(json, 'showLabel', true),
      hidden: LineJson.flag(json, 'hidden'),
    );
  }

  /// The eighths and thirds Gann divided a range by.
  static const List<double> defaultRatios = [
    0,
    0.25,
    1 / 3,
    0.5,
    2 / 3,
    0.75,
    1,
  ];

  /// Fractions of the box ruled both across and down.
  List<double> ratios;

  /// Whether the two corner-to-corner diagonals are drawn.
  bool showDiagonals;

  /// How solid the wash inside the box is.
  @override
  double fillOpacity;

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson('gannBox'),
    ...anchorsJson(),
    'ratios': ratios,
    'showDiagonals': showDiagonals,
    'fillOpacity': fillOpacity,
  };
}
