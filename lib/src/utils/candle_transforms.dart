import 'dart:math' as math;

import '../entity/k_line_entity.dart';

/// Rewrites a list of candles into one the chart draws as candles, but which
/// says something different about the market.
///
/// Both transforms return a fresh list and leave the original alone. Indicator
/// fields are not carried over — run [DataUtil.calculate] over the result
/// before handing it to the chart:
///
/// ```dart
/// final ha = CandleTransforms.heikinAshi(candles);
/// DataUtil.calculate(ha);
/// KChartWidget(ha, colors, /* … */);
/// ```
abstract final class CandleTransforms {
  /// Smooths [candles] into Heikin-Ashi candles.
  ///
  /// Each candle is averaged with the one before it, which strips most of the
  /// noise out of a trend: runs of one colour last longer and turn later, which
  /// is the whole point of reading them.
  ///
  /// The result has one candle per input candle, at the same times, so drawings
  /// anchored to a candle stay where they were.
  static List<KLineEntity> heikinAshi(List<KLineEntity> candles) {
    final out = <KLineEntity>[];
    double? previousOpen;
    double? previousClose;

    for (final candle in candles) {
      final close = (candle.open + candle.high + candle.low + candle.close) / 4;
      final open = previousOpen == null || previousClose == null
          ? (candle.open + candle.close) / 2
          : (previousOpen + previousClose) / 2;

      out.add(
        KLineEntity.fromCustom(
          open: open,
          high: math.max(candle.high, math.max(open, close)),
          low: math.min(candle.low, math.min(open, close)),
          close: close,
          vol: candle.vol,
          dateTime: candle.dateTime ?? DateTime.fromMillisecondsSinceEpoch(0),
          amount: candle.amount,
        ),
      );

      previousOpen = open;
      previousClose = close;
    }

    return out;
  }

  /// Turns [candles] into Renko bricks of [brickSize].
  ///
  /// A brick is laid every time price closes a whole [brickSize] beyond the last
  /// one, and time is thrown away in between: what is left is the shape of the
  /// move, with the chop taken out. Reversing takes two bricks, as it
  /// traditionally does, so a wobble around one level lays nothing at all.
  ///
  /// The bricks a single candle lays are spaced [brickSpacing] apart, starting
  /// at that candle's own time, so every brick still has a time of its own for
  /// the axis and for anything drawn on it. Volume is carried across from the
  /// candles a brick covers.
  ///
  /// Returns an empty list for a non-positive [brickSize].
  static List<KLineEntity> renko(
    List<KLineEntity> candles, {
    required double brickSize,
    Duration brickSpacing = const Duration(milliseconds: 1),
  }) {
    if (brickSize <= 0 || candles.isEmpty) return [];

    final bricks = <KLineEntity>[];
    // Bricks sit on a grid of brickSize, so the same data always lays the same
    // bricks however much of it you feed in.
    var level = (candles.first.close / brickSize).floorToDouble() * brickSize;
    var direction = 0;
    var volume = 0.0;

    for (final candle in candles) {
      volume += candle.vol;
      final time = candle.dateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      var laid = 0;

      void lay(double open, double close) {
        bricks.add(
          KLineEntity.fromCustom(
            open: open,
            high: math.max(open, close),
            low: math.min(open, close),
            close: close,
            vol: volume,
            dateTime: time.add(brickSpacing * laid),
          ),
        );
        laid++;
        volume = 0;
        level = close;
        direction = close > open ? 1 : -1;
      }

      // A reversal has to clear two bricks: one to undo the last, one to lay
      // the first of the other side.
      while (candle.close >= level + brickSize * (direction < 0 ? 2 : 1)) {
        final open = direction < 0 ? level + brickSize : level;
        lay(open, open + brickSize);
      }
      while (candle.close <= level - brickSize * (direction > 0 ? 2 : 1)) {
        final open = direction > 0 ? level - brickSize : level;
        lay(open, open - brickSize);
      }
    }

    return bricks;
  }

  /// A brick size taken from the market itself: the average true range over
  /// [period] candles.
  ///
  /// The usual way to size Renko bricks — big enough that noise lays nothing,
  /// small enough that a real move still shows. Returns null when there is not
  /// enough data, or when the range works out at zero.
  static double? atrBrickSize(List<KLineEntity> candles, {int period = 14}) {
    if (candles.length <= period || period <= 0) return null;

    var sum = 0.0;
    for (var i = candles.length - period; i < candles.length; i++) {
      final candle = candles[i];
      final previousClose = candles[i - 1].close;
      sum += math.max(
        candle.high - candle.low,
        math.max(
          (candle.high - previousClose).abs(),
          (candle.low - previousClose).abs(),
        ),
      );
    }

    final atr = sum / period;
    return atr > 0 ? atr : null;
  }
}
