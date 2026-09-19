import 'dart:ui';

import 'line.dart';
import 'two_point_drawing.dart';

/// A planned trade drawn on the chart: entry, target and stop, with the reward
/// against the risk worked out.
///
/// Three taps place it — entry, then target, then stop — and it reads long or
/// short from which side of the entry the target landed on. The target band
/// takes the profit colour and the stop band the loss colour, and the label
/// carries the risk-to-reward ratio.
class PositionDrawing extends ThreePointDrawing implements FilledDrawing {
  /// Creates a position entered at ([time1], [price1]).
  PositionDrawing({
    required super.time1,
    required super.price1,
    super.time2,
    super.price2,
    super.time3,
    super.price3,
    this.fillOpacity = 0.16,
    this.profitColor = const Color(0xFF26A69A),
    this.lossColor = const Color(0xFFEF5350),
    super.color = const Color(0xFF9E9E9E),
    super.thickness = 1.0,
    super.style,
    super.isDashed = false,
    super.locked = false,
    super.showLabel = true,
    super.hidden = false,
  });

  /// Rebuilds a position from [json].
  factory PositionDrawing.fromJson(Map<String, dynamic> json) {
    final first = firstAnchorFromJson(json);
    return PositionDrawing(
      time1: first.time,
      price1: first.price,
      time2: LineJson.time(json, 'time2'),
      price2: LineJson.maybeNumber(json, 'price2'),
      time3: LineJson.time(json, 'time3'),
      price3: LineJson.maybeNumber(json, 'price3'),
      fillOpacity: LineJson.number(json, 'fillOpacity', 0.16),
      profitColor: LineJson.color(json, const Color(0xFF26A69A), 'profitColor'),
      lossColor: LineJson.color(json, const Color(0xFFEF5350), 'lossColor'),
      color: LineJson.color(json, const Color(0xFF9E9E9E)),
      thickness: LineJson.number(json, 'thickness', 1),
      style: LineJson.style(json),
      locked: LineJson.flag(json, 'locked'),
      showLabel: LineJson.flag(json, 'showLabel', true),
      hidden: LineJson.flag(json, 'hidden'),
    );
  }

  /// How solid the target and stop bands are.
  @override
  double fillOpacity;

  /// Colour of the band between entry and target.
  Color profitColor;

  /// Colour of the band between entry and stop.
  Color lossColor;

  /// The price the trade is entered at.
  double get entryPrice => price1;

  /// The price the trade takes profit at, or null while it is being placed.
  double? get targetPrice => price2;

  /// The price the trade is stopped out at, or null while it is being placed.
  double? get stopPrice => price3;

  /// Whether the trade is a long: its target sits above its entry.
  bool get isLong => (targetPrice ?? entryPrice) >= entryPrice;

  /// How far the target is from the entry, or null until it has one.
  double? get reward {
    final target = targetPrice;
    return target == null ? null : (target - entryPrice).abs();
  }

  /// How far the stop is from the entry, or null until it has one.
  double? get risk {
    final stop = stopPrice;
    return stop == null ? null : (stop - entryPrice).abs();
  }

  /// Reward over risk, or null when either is missing or the risk is zero.
  double? get riskReward {
    final r = risk;
    final gain = reward;
    if (r == null || gain == null || r == 0) return null;
    return gain / r;
  }

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson('position'),
    ...threeAnchorsJson(),
    'fillOpacity': fillOpacity,
    'profitColor': profitColor.toARGB32(),
    'lossColor': lossColor.toARGB32(),
  };
}
