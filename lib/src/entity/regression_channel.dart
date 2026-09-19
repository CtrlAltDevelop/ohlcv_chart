import 'dart:math';
import 'dart:ui';

import 'k_line_entity.dart';
import 'line.dart';
import 'two_point_drawing.dart';

/// The line of best fit through the candles between two anchors, with bands.
///
/// Where a trend line is placed by eye, this one is worked out: a least-squares
/// fit through the closes of every candle the two anchors span, with a band at
/// [deviations] standard deviations either side. Move an anchor and the fit is
/// recomputed, so the line always describes the stretch it covers rather than
/// the two points it was dropped on.
class RegressionChannel extends TwoPointDrawing implements FilledDrawing {
  /// Creates a regression over the candles from ([time1], [price1]).
  RegressionChannel({
    required super.time1,
    required super.price1,
    super.time2,
    super.price2,
    this.deviations = 2.0,
    this.showBands = true,
    this.extend = false,
    this.fillOpacity = 0.07,
    super.color = const Color(0xFF7986CB),
    super.thickness = 1.5,
    super.style,
    super.isDashed = false,
    super.locked = false,
    super.showLabel = true,
    super.hidden = false,
  });

  /// Rebuilds a regression from [json].
  factory RegressionChannel.fromJson(Map<String, dynamic> json) {
    final first = firstAnchorFromJson(json);
    return RegressionChannel(
      time1: first.time,
      price1: first.price,
      time2: LineJson.time(json, 'time2'),
      price2: LineJson.maybeNumber(json, 'price2'),
      deviations: LineJson.number(json, 'deviations', 2),
      showBands: LineJson.flag(json, 'showBands', true),
      extend: LineJson.flag(json, 'extend'),
      fillOpacity: LineJson.number(json, 'fillOpacity', 0.07),
      color: LineJson.color(json, const Color(0xFF7986CB)),
      thickness: LineJson.number(json, 'thickness', 1.5),
      style: LineJson.style(json),
      locked: LineJson.flag(json, 'locked'),
      showLabel: LineJson.flag(json, 'showLabel', true),
      hidden: LineJson.flag(json, 'hidden'),
    );
  }

  /// How many standard deviations out the bands sit.
  double deviations;

  /// Whether the bands are drawn at all, or only the fit itself.
  bool showBands;

  /// Whether the fit and its bands carry on past the second anchor.
  bool extend;

  /// How solid the wash between the bands is.
  @override
  double fillOpacity;

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson('regression'),
    ...anchorsJson(),
    'deviations': deviations,
    'showBands': showBands,
    'extend': extend,
    'fillOpacity': fillOpacity,
  };
}

/// A least-squares line through the closes of a stretch of candles, and
/// their spread about it.
///
/// `startPrice` and `endPrice` are the fit at the first and last candle, and
/// `deviation` is the root-mean-square distance of the closes from it — what
/// the bands are measured in. Fewer than two candles cannot be fitted, so
/// [fitRegression] answers null.
typedef RegressionFit = ({
  double startPrice,
  double endPrice,
  double deviation,
});

/// Fits a line through the closes of [candles] from [start] to [stop].
///
/// Both ends are inclusive, in either order. Answers null where the range
/// holds fewer than two candles, which is not enough to fit anything.
RegressionFit? fitRegression(List<KLineEntity> candles, int start, int stop) {
  // Checked before the ends are clamped: with no candles there is no range to
  // clamp them into.
  if (candles.isEmpty) return null;

  final from = min(start, stop).clamp(0, candles.length - 1);
  final to = max(start, stop).clamp(0, candles.length - 1);
  final count = to - from + 1;
  if (count < 2) return null;

  // x runs 0..count-1 over the candles in range, so the fit is in candle
  // space and does not care how wide a candle is on screen.
  var sumX = 0.0;
  var sumY = 0.0;
  var sumXY = 0.0;
  var sumXX = 0.0;
  for (var i = 0; i < count; i++) {
    final y = candles[from + i].close;
    sumX += i;
    sumY += y;
    sumXY += i * y;
    sumXX += i * i;
  }

  final denominator = count * sumXX - sumX * sumX;
  if (denominator == 0) return null;
  final slope = (count * sumXY - sumX * sumY) / denominator;
  final intercept = (sumY - slope * sumX) / count;

  var squares = 0.0;
  for (var i = 0; i < count; i++) {
    final residual = candles[from + i].close - (intercept + slope * i);
    squares += residual * residual;
  }

  return (
    startPrice: intercept,
    endPrice: intercept + slope * (count - 1),
    deviation: sqrt(squares / count),
  );
}
