import 'dart:math' as math;

import '../entity/k_line_entity.dart';
import 'axis_ticks.dart';

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

  /// Turns [candles] into three-line-break blocks.
  ///
  /// A block is drawn every time price closes beyond the last one, and time is
  /// thrown away in between — so what is left is the sequence of moves that
  /// were big enough to matter. Reversing takes a close beyond the extreme of
  /// the last [lines] blocks, which is what stops a market going sideways from
  /// drawing anything at all.
  ///
  /// Each block runs from where the last one ended to the close that drew it,
  /// so the blocks are contiguous and read as one staircase. Blocks a single
  /// candle draws are spaced [spacing] apart from that candle's own time, so
  /// each has a time of its own for the axis. Volume is carried across from the
  /// candles a block covers.
  ///
  /// Returns an empty list for a non-positive [lines].
  static List<KLineEntity> lineBreak(
    List<KLineEntity> candles, {
    int lines = 3,
    Duration spacing = const Duration(milliseconds: 1),
  }) {
    if (lines <= 0 || candles.isEmpty) return [];

    final blocks = <KLineEntity>[];
    // What each block spanned, kept alongside so the reversal threshold can be
    // read off the last few without going back through the entities.
    final spans = <({double low, double high, bool up})>[];
    var volume = 0.0;
    double? level;

    for (final candle in candles) {
      volume += candle.vol;
      final time = candle.dateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      var drawn = 0;

      void draw(double open, double close) {
        blocks.add(
          KLineEntity.fromCustom(
            open: open,
            high: math.max(open, close),
            low: math.min(open, close),
            close: close,
            vol: volume,
            dateTime: time.add(spacing * drawn),
          ),
        );
        spans.add((
          low: math.min(open, close),
          high: math.max(open, close),
          up: close > open,
        ));
        drawn++;
        volume = 0;
        level = close;
      }

      final close = candle.close;
      if (level == null) {
        // The first candle only sets where the first block will start from;
        // nothing is drawn until price has moved off it.
        level = candle.open;
        if (close != candle.open) draw(candle.open, close);
        continue;
      }
      if (spans.isEmpty) {
        if (close != level) draw(level!, close);
        continue;
      }

      final recent =
          spans.length <= lines ? spans : spans.sublist(spans.length - lines);
      var highest = recent.first.high;
      var lowest = recent.first.low;
      for (final span in recent) {
        highest = math.max(highest, span.high);
        lowest = math.min(lowest, span.low);
      }

      final last = spans.last;
      if (last.up) {
        // Carrying on takes one more tick beyond the last block; turning round
        // takes a close under the whole run of them.
        if (close > level!) {
          draw(level!, close);
        } else if (close < lowest) {
          draw(level!, close);
        }
      } else {
        if (close < level!) {
          draw(level!, close);
        } else if (close > highest) {
          draw(level!, close);
        }
      }
    }

    return blocks;
  }

  /// Turns [candles] into Kagi segments, reversing on a move of [reversal].
  ///
  /// A Kagi line runs with the market and turns round only when price retraces
  /// [reversal] from the extreme it reached — so a trend is one long segment
  /// however many bars it took, and the chop inside it draws nothing. Set
  /// [asPercent] to measure the reversal as a fraction of the extreme rather
  /// than in price, which is the usual way to size one.
  ///
  /// Each segment is returned as a candle from where the turn happened to the
  /// extreme it ran to, so the chart draws the line as a run of blocks. A
  /// rising segment reads as an up candle and a falling one as a down candle;
  /// the thick-and-thin yang and yin of a hand-drawn Kagi is not something a
  /// candle can say.
  ///
  /// Returns an empty list for a non-positive [reversal].
  static List<KLineEntity> kagi(
    List<KLineEntity> candles, {
    required double reversal,
    bool asPercent = false,
    Duration spacing = const Duration(milliseconds: 1),
  }) {
    if (reversal <= 0 || candles.isEmpty) return [];

    final segments = <KLineEntity>[];
    var start = candles.first.close;
    var extreme = candles.first.close;
    var direction = 0;
    var volume = 0.0;

    /// How far price has to come back from [from] to count as a turn.
    double threshold(double from) =>
        asPercent ? from.abs() * reversal : reversal;

    for (final candle in candles) {
      volume += candle.vol;
      final time = candle.dateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final close = candle.close;

      void turn() {
        segments.add(
          KLineEntity.fromCustom(
            open: start,
            high: math.max(start, extreme),
            low: math.min(start, extreme),
            close: extreme,
            vol: volume,
            dateTime: time.add(spacing * segments.length),
          ),
        );
        volume = 0;
        start = extreme;
        extreme = close;
      }

      switch (direction) {
        case 0:
          // Which way the line runs is not known until price has moved far
          // enough for a turn to mean anything.
          if (close >= extreme + threshold(extreme)) {
            direction = 1;
            extreme = close;
          } else if (close <= extreme - threshold(extreme)) {
            direction = -1;
            extreme = close;
          }
        case 1:
          if (close > extreme) {
            extreme = close;
          } else if (close <= extreme - threshold(extreme)) {
            turn();
            direction = -1;
          }
        default:
          if (close < extreme) {
            extreme = close;
          } else if (close >= extreme + threshold(extreme)) {
            turn();
            direction = 1;
          }
      }
    }

    // The segment still running when the data ran out is worth drawing: it is
    // where the market is now.
    if (direction != 0 && extreme != start) {
      final time =
          candles.last.dateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      segments.add(
        KLineEntity.fromCustom(
          open: start,
          high: math.max(start, extreme),
          low: math.min(start, extreme),
          close: extreme,
          vol: volume,
          dateTime: time.add(spacing * segments.length),
        ),
      );
    }

    return segments;
  }

  /// Turns [candles] into point-and-figure columns of [boxSize].
  ///
  /// Price is filed into boxes and only whole boxes are recorded, so noise
  /// smaller than one box draws nothing at all. A column carries on while price
  /// keeps making boxes its own way, and a new one starts when price comes back
  /// [reversalBoxes] boxes against it — three, traditionally.
  ///
  /// Read from the highs and lows rather than the closes, which is how a
  /// point-and-figure chart is built: what matters is how far price travelled,
  /// not where it happened to settle. Each column is returned as a candle from
  /// its first box to its last, so a rising column reads as an up candle.
  ///
  /// Returns an empty list for a non-positive [boxSize] or [reversalBoxes].
  static List<KLineEntity> pointAndFigure(
    List<KLineEntity> candles, {
    required double boxSize,
    int reversalBoxes = 3,
    Duration spacing = const Duration(milliseconds: 1),
  }) {
    if (boxSize <= 0 || reversalBoxes <= 0 || candles.isEmpty) return [];

    final columns = <KLineEntity>[];
    // Boxes are counted off a grid, so the same data always files into the same
    // boxes however much of it is fed in.
    int boxOf(double price) => (price / boxSize).floor();

    var direction = 0;
    var start = boxOf(candles.first.close);
    var end = start;
    var volume = 0.0;
    DateTime? openedAt;

    void close(DateTime time) {
      columns.add(
        KLineEntity.fromCustom(
          open: start * boxSize,
          high: math.max(start, end) * boxSize,
          low: math.min(start, end) * boxSize,
          close: end * boxSize,
          vol: volume,
          dateTime: (openedAt ?? time).add(spacing * columns.length),
        ),
      );
      volume = 0;
      openedAt = time;
    }

    for (final candle in candles) {
      volume += candle.vol;
      final time = candle.dateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      openedAt ??= time;

      final high = boxOf(candle.high);
      final low = boxOf(candle.low);

      switch (direction) {
        case 0:
          if (high > start) {
            direction = 1;
            end = high;
          } else if (low < start) {
            direction = -1;
            end = low;
          }
        case 1:
          if (high > end) {
            end = high;
          } else if (low <= end - reversalBoxes) {
            close(time);
            direction = -1;
            // The new column starts one box back from where the last ended,
            // which is what keeps the two from overlapping.
            start = end - 1;
            end = low;
          }
        default:
          if (low < end) {
            end = low;
          } else if (high >= end + reversalBoxes) {
            close(time);
            direction = 1;
            start = end + 1;
            end = high;
          }
      }
    }

    // The column still open when the data ran out is where the market is now.
    if (direction != 0 && end != start) {
      close(candles.last.dateTime ?? DateTime.fromMillisecondsSinceEpoch(0));
    }

    return columns;
  }

  /// Turns [candles] into bars that each cover [range] of price.
  ///
  /// A bar closes as soon as price has travelled [range] from where the bar
  /// opened, and the next one opens exactly there — so every bar covers the
  /// same distance and a busy stretch draws more of them than a quiet one. Time
  /// is kept only as the instant each bar closed.
  ///
  /// Driven from the closes: a candle's high and low say where price reached but
  /// not in what order, so which side of the bar was touched first is not
  /// knowable from OHLC. What the highs and lows do decide is how tall each bar
  /// is drawn — a bar is at least [range] tall, and taller where the candles it
  /// covered reached further.
  ///
  /// Returns an empty list for a non-positive [range].
  static List<KLineEntity> rangeBars(
    List<KLineEntity> candles, {
    required double range,
    Duration spacing = const Duration(milliseconds: 1),
  }) {
    if (range <= 0 || candles.isEmpty) return [];

    final bars = <KLineEntity>[];
    var open = candles.first.open;
    var high = open;
    var low = open;
    var volume = 0.0;

    for (final candle in candles) {
      volume += candle.vol;
      high = math.max(high, candle.high);
      low = math.min(low, candle.low);
      final close = candle.close;
      final time = candle.dateTime ?? DateTime.fromMillisecondsSinceEpoch(0);

      // One candle may carry price through several bars' worth of range, so the
      // move is drained a bar at a time. Each pass moves the open a whole
      // range towards the close, so the loop always gets shorter.
      while ((close - open).abs() >= range) {
        final up = close > open;
        final end = up ? open + range : open - range;

        bars.add(
          KLineEntity.fromCustom(
            open: open,
            high: math.max(high, math.max(open, end)),
            low: math.min(low, math.min(open, end)),
            close: end,
            vol: volume,
            dateTime: time.add(spacing * bars.length),
          ),
        );

        volume = 0;
        open = end;
        // The bar that just closed used up what the candles had reached; the
        // next one starts fresh from where it opened.
        high = open;
        low = open;
      }
    }

    return bars;
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

  /// Which [timeframe] bucket each of [candles] falls in, numbered from zero
  /// and rising with time.
  ///
  /// Two candles share a number when they belong to the same higher-timeframe
  /// bar, which is what lets a value computed over the coarser series be read
  /// back against the finer one. The bucketing is the chart's own — a calendar
  /// month rather than thirty days, and the wall clock rather than the
  /// underlying instant — so a daily bucket breaks where the chart draws its
  /// day divider.
  ///
  /// A candle with no time of its own is kept with the one before it, having
  /// nothing to be bucketed by.
  static List<int> bucketIndices(
    List<KLineEntity> candles,
    Duration timeframe,
  ) {
    final out = List<int>.filled(candles.length, 0);
    if (candles.isEmpty || timeframe <= Duration.zero) return out;

    var bucket = -1;
    int? previous;
    for (var i = 0; i < candles.length; i++) {
      final time = candles[i].dateTime;
      if (time == null) {
        out[i] = math.max(bucket, 0);
        continue;
      }
      final key = timeBucket(time, timeframe);
      if (previous == null || key != previous) {
        bucket++;
        previous = key;
      }
      out[i] = bucket;
    }
    return out;
  }

  /// Aggregates [candles] up to [timeframe] — fifteen-minute candles into
  /// hourly ones, daily into weekly.
  ///
  /// Each bar takes the first open, the highest high, the lowest low, the last
  /// close and the total volume of the candles that fell in it, and is stamped
  /// with the time the bucket opened. The last bar may be partial, exactly as
  /// the newest candle of any live series is.
  ///
  /// Nothing here interpolates: a timeframe finer than the candles themselves
  /// gives one bar per candle rather than inventing any.
  static List<KLineEntity> resample(
    List<KLineEntity> candles,
    Duration timeframe,
  ) {
    if (candles.isEmpty) return [];

    final buckets = bucketIndices(candles, timeframe);
    final out = <KLineEntity>[];

    var current = -1;
    var open = 0.0;
    var high = 0.0;
    var low = 0.0;
    var close = 0.0;
    var volume = 0.0;
    DateTime? opened;

    void flush() {
      if (current < 0) return;
      out.add(
        KLineEntity.fromCustom(
          open: open,
          high: high,
          low: low,
          close: close,
          vol: volume,
          dateTime:
              opened ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        ),
      );
    }

    for (var i = 0; i < candles.length; i++) {
      final candle = candles[i];
      if (buckets[i] != current) {
        flush();
        current = buckets[i];
        open = candle.open;
        high = candle.high;
        low = candle.low;
        volume = 0;
        opened = candle.dateTime;
      }
      high = math.max(high, candle.high);
      low = math.min(low, candle.low);
      close = candle.close;
      volume += candle.vol;
    }
    flush();

    return out;
  }
}
