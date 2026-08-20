import 'dart:ui';

import 'line.dart';
import 'two_point_drawing.dart';

/// Two parallel lines: a base line between the first two anchors, and a copy
/// of it running through the third.
///
/// The channel every trend is read in. Place the base line along the swings on
/// one side, then one more tap puts the parallel through the swing on the other.
class ParallelChannel extends ThreePointDrawing implements FilledDrawing {
  /// Creates a channel whose base line starts at ([time1], [price1]).
  ParallelChannel({
    required super.time1,
    required super.price1,
    super.time2,
    super.price2,
    super.time3,
    super.price3,
    this.fillOpacity = 0.08,
    this.extend = false,
    super.color = const Color(0xFF00C853),
    super.thickness = 1.5,
    super.style,
    super.isDashed = false,
    super.locked = false,
    super.showLabel = false,
    super.hidden = false,
  });

  /// Rebuilds a channel from [json].
  factory ParallelChannel.fromJson(Map<String, dynamic> json) {
    final first = firstAnchorFromJson(json);
    return ParallelChannel(
      time1: first.time,
      price1: first.price,
      time2: LineJson.time(json, 'time2'),
      price2: LineJson.maybeNumber(json, 'price2'),
      time3: LineJson.time(json, 'time3'),
      price3: LineJson.maybeNumber(json, 'price3'),
      fillOpacity: LineJson.number(json, 'fillOpacity', 0.08),
      extend: LineJson.flag(json, 'extend'),
      color: LineJson.color(json, const Color(0xFF00C853)),
      thickness: LineJson.number(json, 'thickness', 1.5),
      style: LineJson.style(json),
      locked: LineJson.flag(json, 'locked'),
      showLabel: LineJson.flag(json, 'showLabel'),
      hidden: LineJson.flag(json, 'hidden'),
    );
  }

  /// How solid the wash between the two lines is.
  @override
  double fillOpacity;

  /// Whether both lines carry on to the right edge of the chart.
  bool extend;

  /// How far the parallel sits from the base line, in price.
  ///
  /// Null until the third anchor lands.
  double? get offset {
    final end = price2;
    final through = price3;
    final at = time3;
    if (end == null || through == null || at == null) return null;
    return through - priceOnBaseLineAt(at);
  }

  /// Where the base line sits at [time], carried on past its anchors.
  ///
  /// With only one anchor placed, or with both at the same instant, the base
  /// line is flat and this is simply its first price.
  double priceOnBaseLineAt(DateTime time) {
    final endTime = time2;
    final endPrice = price2;
    if (endTime == null || endPrice == null) return price1;

    final run = endTime.difference(time1).inMicroseconds;
    if (run == 0) return price1;
    final along = time.difference(time1).inMicroseconds / run;
    return price1 + (endPrice - price1) * along;
  }

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson('channel'),
    ...threeAnchorsJson(),
    'fillOpacity': fillOpacity,
    'extend': extend,
  };
}
