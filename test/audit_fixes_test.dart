import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/indicators/series_math.dart';

import 'test_utils.dart';

void main() {
  group('option break-evens', () {
    test('a payoff that crosses zero on a strike is reported once', () {
      final legs = [const OptionLeg(kind: OptionKind.underlying, strike: 100)];

      expect(optionBreakEvens(legs, 50, 150), [100]);
    });
  });

  group('market profile', () {
    test('a candle with no range on a level edge still counts', () {
      final data = [
        candle(100, high: 100, low: 100),
        candle(105, high: 105, low: 105),
        candle(110, high: 110, low: 110),
      ];

      final profile = buildMarketProfile(data, tickSize: 1);
      final counts = [for (final row in profile.rows) row.count];

      expect(counts.reduce((a, b) => a + b), 3);
    });

    test('a tick that is not positive is read as none', () {
      final data = [candle(100, high: 101, low: 99), candle(102)];

      expect(() => buildMarketProfile(data, tickSize: 0), returnsNormally);
      expect(() => buildMarketProfile(data, tickSize: -1), returnsNormally);
    });
  });

  group('histogram bins', () {
    test('a decimal bin width does not earn an extra empty bin', () {
      final bins = histogramBins(
        [0.0, 0.35, 0.7],
        binWidth: 0.1,
        min: 0,
        max: 0.7,
      );

      expect(bins, hasLength(7));
    });
  });

  group('time buckets', () {
    test('weeks start on a Monday', () {
      const week = Duration(days: 7);
      // 2026-01-05 is a Monday; the Sunday before it closes the previous week.
      final sunday = timeBucket(DateTime.utc(2026, 1, 4, 23), week);
      final monday = timeBucket(DateTime.utc(2026, 1, 5), week);
      final friday = timeBucket(DateTime.utc(2026, 1, 9), week);

      expect(monday, isNot(sunday));
      expect(friday, monday);
    });

    test('half a year is six months, not three', () {
      const half = Duration(days: 180);
      final jan = timeBucket(DateTime.utc(2026, 1, 15), half);
      final may = timeBucket(DateTime.utc(2026, 5, 15), half);
      final jul = timeBucket(DateTime.utc(2026, 7, 15), half);

      expect(may, jan);
      expect(jul, isNot(jan));
    });
  });

  group('treemap', () {
    test('an item with an infinite value is left out, not spread over all', () {
      final tiles = layOutTreemap(const [
        TreemapItem(value: double.infinity),
        TreemapItem(value: 2),
        TreemapItem(value: 2),
      ], const Rect.fromLTWH(0, 0, 100, 100));

      expect(tiles, hasLength(2));
      expect(tiles.every((t) => t.rect.width.isFinite), isTrue);
    });
  });

  group('pair hedge ratio', () {
    test('finds the slope of prices quoted in tiny numbers', () {
      final points = [
        for (var i = 0; i < 20; i++)
          PairPoint(
            time: DateTime.utc(2024).add(Duration(days: i)),
            a: 2e-7 * (i + 1),
            b: 1e-7 * (i + 1),
          ),
      ];

      expect(pairHedgeRatio(points), closeTo(2, 1e-6));
    });
  });

  group('moving average', () {
    test('one candle with no close leaves only its own windows empty', () {
      final data = candles([10, 20, double.nan, 40, 50, 60, 70]);

      final average = smaSeries(data, 3);

      // The three windows holding the NaN have no average; the ones after it
      // are as good as ever instead of being NaN from then on.
      expect(average[2], isNull);
      expect(average[3], isNull);
      expect(average[4], isNull);
      expect(average[5], closeTo(50, 1e-9));
      expect(average[6], closeTo(60, 1e-9));
    });
  });

  group('candle transforms', () {
    test('a brick far smaller than the move stops at the limit', () {
      final data = [candle(100), candle(1e9)];

      final bricks = CandleTransforms.renko(data, brickSize: 1e-6);

      expect(bricks.length, CandleTransforms.maxBlocks);
    });

    test('range bars stop at the limit too', () {
      final data = [candle(100), candle(1e9)];

      final bars = CandleTransforms.rangeBars(data, range: 1e-6);

      expect(bars.length, CandleTransforms.maxBlocks);
    });
  });

  group('replay interval', () {
    test('a zero interval is held to a millisecond', () {
      final replay = ChartReplayController(interval: Duration.zero);
      expect(replay.interval, const Duration(milliseconds: 1));

      replay.setInterval(const Duration(milliseconds: -5));
      expect(replay.interval, const Duration(milliseconds: 1));
      replay.dispose();
    });
  });
}
