import 'dart:ui';

import 'line.dart';
import 'two_point_drawing.dart';

/// How a pitchfork's handle and tines are worked out from its three anchors.
enum PitchforkKind {
  /// Andrews': the median line runs from the first anchor through the midpoint
  /// of the other two, and the tines are parallel to it.
  andrews,

  /// Schiff: the same, with the handle's start lifted to the midpoint of the
  /// first two anchors, which takes some of the trend out of the slope.
  schiff,

  /// Modified Schiff: Schiff's lift, taken in time as well as in price.
  modifiedSchiff,
}

/// Three swings turned into a median line and a pair of tines.
///
/// The first anchor is the pivot the handle leaves from; the second and third
/// are the swing either side of the move. The median runs through the midpoint
/// between them and each ratio in [levels] draws a tine parallel to it, at
/// that fraction of the distance out to the anchors — `1` being the anchors
/// themselves.
class PitchforkDrawing extends ThreePointDrawing implements FilledDrawing {
  /// Creates a pitchfork whose handle starts at ([time1], [price1]).
  PitchforkDrawing({
    required super.time1,
    required super.price1,
    super.time2,
    super.price2,
    super.time3,
    super.price3,
    this.kind = PitchforkKind.andrews,
    List<double>? levels,
    this.fillOpacity = 0.06,
    super.color = const Color(0xFF4DB6AC),
    super.thickness = 1.5,
    super.style,
    super.isDashed = false,
    super.locked = false,
    super.showLabel = true,
    super.hidden = false,
  }) : levels = levels ?? List<double>.of(defaultLevels);

  /// Rebuilds a pitchfork from [json].
  factory PitchforkDrawing.fromJson(Map<String, dynamic> json) {
    final first = firstAnchorFromJson(json);
    return PitchforkDrawing(
      time1: first.time,
      price1: first.price,
      time2: LineJson.time(json, 'time2'),
      price2: LineJson.maybeNumber(json, 'price2'),
      time3: LineJson.time(json, 'time3'),
      price3: LineJson.maybeNumber(json, 'price3'),
      kind: LineJson.enumValue(
        json,
        'kind',
        PitchforkKind.values,
        PitchforkKind.andrews,
      ),
      levels: LineJson.numbers(json, 'levels'),
      fillOpacity: LineJson.number(json, 'fillOpacity', 0.06),
      color: LineJson.color(json, const Color(0xFF4DB6AC)),
      thickness: LineJson.number(json, 'thickness', 1.5),
      style: LineJson.style(json),
      locked: LineJson.flag(json, 'locked'),
      showLabel: LineJson.flag(json, 'showLabel', true),
      hidden: LineJson.flag(json, 'hidden'),
    );
  }

  /// The median and the two outer tines, which is the plain pitchfork.
  static const List<double> defaultLevels = [0, 1];

  /// How the handle is worked out from the anchors.
  PitchforkKind kind;

  /// Fractions of the way out to the anchors each tine is drawn at.
  ///
  /// `0` is the median line itself and `1` the tines through the second and
  /// third anchors. Add `0.5` for the quartile lines, or `1.5` and `2` for the
  /// projections outside the fork.
  List<double> levels;

  /// How solid the wash between the outermost tines is.
  @override
  double fillOpacity;

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson('pitchfork'),
    ...threeAnchorsJson(),
    'kind': kind.name,
    'levels': levels,
    'fillOpacity': fillOpacity,
  };
}
