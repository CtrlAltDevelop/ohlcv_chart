import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/indicators/series_math.dart';

import 'test_utils.dart';

/// Candles whose highs and lows straddle the close by [spread].
List<KLineEntity> spreadCandles(List<double> closes, {double spread = 2}) => [
  for (var i = 0; i < closes.length; i++)
    candle(
      closes[i],
      high: closes[i] + spread,
      low: closes[i] - spread,
      minute: i,
    ),
];

void main() {
  group('channels', () {
    test('Donchian brackets the window high and low', () {
      final data = spreadCandles([10, 12, 11, 15, 13, 9]);
      final bands = donchianSeries(data, 3);

      // Nothing until the window is full.
      expect(bands.upper.take(2), everyElement(isNull));
      // Candles 3-5 (closes 11, 15, 13) span 17 down to 8 with the spread.
      expect(bands.upper[4], 17);
      expect(bands.lower[4], 9);
      expect(bands.middle[4], 13);
    });

    test('Keltner sits symmetrically around its midline', () {
      final data = spreadCandles(rampThenFall(60));
      final bands = keltnerSeries(
        data,
        period: 20,
        atrPeriod: 10,
        multiplier: 2,
      );
      final atr = atrSeries(data, 10);

      final middle = bands.middle.last!;
      expect(bands.upper.last! - middle, closeTo(atr.last! * 2, 1e-9));
      expect(middle - bands.lower.last!, closeTo(atr.last! * 2, 1e-9));
    });

    test('Supertrend follows price up and flips on the way down', () {
      final data = spreadCandles([for (var i = 0; i < 80; i++) 100.0 + i * 2]);
      final rising = supertrendSeries(data, period: 10, multiplier: 3);

      expect(rising.trend.last, 1);
      // In an uptrend the stop trails below the close.
      expect(rising.line.last, lessThan(data.last.close));

      final falling = spreadCandles([
        for (var i = 0; i < 80; i++) 100.0 + (i < 40 ? i * 2 : (80 - i) * 2),
      ]);
      final turned = supertrendSeries(falling, period: 10, multiplier: 3);
      expect(turned.trend.last, -1);
      expect(turned.line.last, greaterThan(falling.last.close));
    });
  });

  group('Ichimoku', () {
    final data = spreadCandles(rampThenFall(120));
    final series = ichimokuSeries(
      data,
      conversionPeriod: 9,
      basePeriod: 26,
      spanPeriod: 52,
      displacement: 26,
    );

    test('shifts the spans forward by the displacement', () {
      // Span B at i is the 52-candle midpoint as of 26 candles earlier.
      final unshifted = ichimokuSeries(
        data,
        conversionPeriod: 9,
        basePeriod: 26,
        spanPeriod: 52,
        displacement: 0,
      );
      expect(series.spanB[100], unshifted.spanB[74]);
      expect(series.spanB.take(26), everyElement(isNull));
    });

    test('shifts the lagging line back, leaving the newest candles empty', () {
      expect(series.lagging[50], data[76].close);
      expect(series.lagging.last, isNull);
    });
  });

  group('oscillators', () {
    test('rate of change is a percentage of the earlier close', () {
      final data = candles([100, 110, 90, 100, 120]);
      final roc = rocSeries(data, 2);

      expect(roc[0], isNull);
      expect(roc[1], isNull);
      expect(roc[2], closeTo(-10, 1e-9)); // 90 against 100
      expect(roc[4], closeTo(33.3333333, 1e-6)); // 120 against 90
    });

    test('stochastic RSI stays inside 0 to 100', () {
      final data = spreadCandles(rampThenFall(120));
      final series = stochRsiSeries(
        data,
        rsiPeriod: 14,
        period: 14,
        kSmoothing: 3,
        dSmoothing: 3,
      );

      final values = [
        ...series.k.whereType<double>(),
        ...series.d.whereType<double>(),
      ];
      expect(values, isNotEmpty);
      expect(values.every((v) => v >= 0 && v <= 100), isTrue);
    });

    test('TRIX is flat on a flat market and positive on a rising one', () {
      final flat = candles([for (var i = 0; i < 80; i++) 100.0]);
      final flatTrix = trixSeries(flat, period: 15, signalPeriod: 9);
      expect(flatTrix.trix.last, closeTo(0, 1e-9));

      final rising = candles([for (var i = 0; i < 80; i++) 100.0 + i]);
      final risingTrix = trixSeries(rising, period: 15, signalPeriod: 9);
      expect(risingTrix.trix.last!, greaterThan(0));
      expect(risingTrix.signal.last, isNotNull);
    });

    test('the awesome oscillator is the gap between midpoint averages', () {
      final data = spreadCandles(rampThenFall(80));
      final ao = awesomeSeries(data, fast: 5, slow: 34);

      expect(ao.take(33), everyElement(isNull));
      double meanMidpoint(int end, int period) {
        var sum = 0.0;
        for (var i = end - period + 1; i <= end; i++) {
          sum += (data[i].high + data[i].low) / 2;
        }
        return sum / period;
      }

      expect(ao[40], closeTo(meanMidpoint(40, 5) - meanMidpoint(40, 34), 1e-9));
    });

    test('Aroon reads how long ago the extremes fell', () {
      final data = spreadCandles([10, 12, 11, 15, 13, 9]);
      final aroon = aroonSeries(data, 3);

      // The window spans four candles, so nothing lands until index 3.
      expect(aroon.up.take(3), everyElement(isNull));
      expect(aroon.down.take(3), everyElement(isNull));

      // At 3 the high (17) is today's and the low (8) is as old as the
      // window reaches.
      expect(aroon.up[3], 100);
      expect(aroon.down[3], 0);

      // At 5 that high is two candles back, and the low is today's.
      expect(aroon.up[5], closeTo(100 * (3 - 2) / 3, 1e-9));
      expect(aroon.down[5], 100);
    });

    test('Aroon pins to 100 and 0 on a market going one way', () {
      final rising = spreadCandles([for (var i = 0; i < 40; i++) 100.0 + i]);
      final aroon = aroonSeries(rising, 14);

      // Every candle is a fresh high, and the low is always the oldest in
      // the window.
      expect(aroon.up.last, 100);
      expect(aroon.down.last, 0);

      final values = [
        ...aroon.up.whereType<double>(),
        ...aroon.down.whereType<double>(),
      ];
      expect(values, isNotEmpty);
      expect(values.every((v) => v >= 0 && v <= 100), isTrue);
    });

    test('the volume average is the mean of the window', () {
      final data = [
        for (var i = 0; i < 5; i++) candle(100, vol: (i + 1) * 10, minute: i),
      ];
      expect(volumeMaSeries(data, 3)[4], closeTo((30 + 40 + 50) / 3, 1e-9));
    });
  });

  group('session VWAP', () {
    /// Hourly candles across [hours], flat-ranged so the typical price is the
    /// close, with a volume of 1 each.
    List<KLineEntity> hours(int count, List<double> closes) => [
      for (var i = 0; i < count; i++)
        KLineEntity.fromCustom(
          open: closes[i],
          high: closes[i],
          low: closes[i],
          close: closes[i],
          vol: 1,
          dateTime: DateTime.utc(2024, 1, 1).add(Duration(hours: i)),
        ),
    ];

    test('averages the session so far, and begins again the next day', () {
      // 24 hours at 100, then 24 at 200.
      final data = hours(48, [
        for (var i = 0; i < 24; i++) 100.0,
        for (var i = 0; i < 24; i++) 200.0,
      ]);
      final series = sessionVwapSeries(data, deviations: 0);

      expect(series.vwap[23], closeTo(100, 1e-9));
      // The second day starts over rather than dragging the first behind it.
      expect(series.vwap[24], closeTo(200, 1e-9));
      expect(series.vwap.last, closeTo(200, 1e-9));
    });

    test('weights by volume, not by candle', () {
      final data = [
        KLineEntity.fromCustom(
          open: 100,
          high: 100,
          low: 100,
          close: 100,
          vol: 1,
          dateTime: DateTime.utc(2024, 1, 1),
        ),
        KLineEntity.fromCustom(
          open: 200,
          high: 200,
          low: 200,
          close: 200,
          vol: 9,
          dateTime: DateTime.utc(2024, 1, 1, 1),
        ),
      ];
      final series = sessionVwapSeries(data, deviations: 0);

      // (100*1 + 200*9) / 10 — not the 150 a plain mean would give.
      expect(series.vwap.last, closeTo(190, 1e-9));
    });

    test('a flat session has no spread to band', () {
      final data = hours(6, [for (var i = 0; i < 6; i++) 100.0]);
      final series = sessionVwapSeries(data, deviations: 2);

      expect(series.upper.last, closeTo(100, 1e-9));
      expect(series.lower.last, closeTo(100, 1e-9));
    });

    test('the bands sit symmetrically, and widen with the deviation', () {
      final data = hours(8, [100, 110, 90, 105, 95, 115, 85, 100]);
      final one = sessionVwapSeries(data, deviations: 1);
      final two = sessionVwapSeries(data, deviations: 2);

      final average = one.vwap.last!;
      expect(
        one.upper.last! - average,
        closeTo(average - one.lower.last!, 1e-9),
      );
      expect(
        two.upper.last! - average,
        closeTo((one.upper.last! - average) * 2, 1e-9),
      );
    });

    test('no deviation asked for, no bands drawn', () {
      final data = hours(4, [100, 110, 90, 105]);
      final series = sessionVwapSeries(data, deviations: 0);

      expect(series.vwap, everyElement(isNotNull));
      expect(series.upper, everyElement(isNull));
      expect(series.lower, everyElement(isNull));
    });

    test('a week restarts on the Monday, not every seven candles', () {
      // Daily candles from a Wednesday, so the first week is three long.
      final data = [
        for (var i = 0; i < 10; i++)
          KLineEntity.fromCustom(
            open: 100.0 + i,
            high: 100.0 + i,
            low: 100.0 + i,
            close: 100.0 + i,
            vol: 1,
            dateTime: DateTime.utc(2024, 1, 3).add(Duration(days: i)),
          ),
      ];
      final series = sessionVwapSeries(
        data,
        session: PivotSession.week,
        deviations: 0,
      );

      // 2024-01-03 is a Wednesday; the 8th is the following Monday, so the
      // average restarts at that candle's own price.
      expect(data[5].dateTime!.weekday, DateTime.monday);
      expect(series.vwap[5], closeTo(data[5].close, 1e-9));
      expect(series.vwap[4], isNot(closeTo(data[4].close, 1e-9)));
    });

    test('a session with no volume still says something', () {
      final data = [
        KLineEntity.fromCustom(
          open: 100,
          high: 110,
          low: 90,
          close: 105,
          vol: 0,
          dateTime: DateTime.utc(2024, 1, 1),
        ),
      ];
      final series = sessionVwapSeries(data);

      // The typical price, there being no volume to weight by.
      expect(series.vwap.single, closeTo((110 + 90 + 105) / 3, 1e-9));
    });
  });

  group('swings', () {
    /// Two clean legs up then down, well past any sensible threshold.
    final swinging = spreadCandles([
      for (var i = 0; i < 30; i++) 100.0 + i * 2, // 100 → 158
      for (var i = 0; i < 30; i++) 158.0 - i * 3, // 158 → 71
      for (var i = 0; i < 20; i++) 71.0 + i * 2, // 71 → 109
    ], spread: 0);

    test('zigzag pivots alternate between highs and lows', () {
      final pivots = zigzagPivots(swinging, 5);

      expect(pivots.length, greaterThanOrEqualTo(3));
      for (var i = 1; i < pivots.length; i++) {
        expect(
          pivots[i].isHigh,
          isNot(pivots[i - 1].isHigh),
          reason: 'pivot $i repeats the one before it',
        );
        expect(pivots[i].index, greaterThan(pivots[i - 1].index));
      }
      // The turn at the top of the first leg is found.
      expect(pivots.any((p) => p.isHigh && p.price == 158), isTrue);
    });

    test('a move smaller than the depth is not a swing', () {
      final noisy = spreadCandles([
        for (var i = 0; i < 40; i++) 100.0 + (i.isEven ? 0.5 : 0),
      ], spread: 0);

      expect(zigzagPivots(noisy, 5), isEmpty);
      expect(zigzagSeries(noisy, 5), everyElement(isNull));
    });

    test('the zigzag series carries its values only on the pivots', () {
      final series = zigzagSeries(swinging, 5);
      final pivots = zigzagPivots(swinging, 5);

      expect(series.whereType<double>().length, pivots.length);
      for (final pivot in pivots) {
        expect(series[pivot.index], pivot.price);
      }
    });

    test('Fibonacci levels run from the swing end to its start', () {
      final swing = lastSwing(swinging, 5)!;
      final levels = fibonacciSeries(swinging, 5);

      expect(levels.length, fibonacciRatios.length);
      // 0 sits at the newest pivot, 1 back at the one the leg started from.
      expect(levels.first.last, closeTo(swing.to.price, 1e-9));
      expect(levels.last.last, closeTo(swing.from.price, 1e-9));
      // A level is drawn from the swing's start onwards, not before it.
      expect(levels.first[swing.from.index - 1], isNull);
      expect(levels.first[swing.from.index], isNotNull);

      final half = levels[fibonacciRatios.indexOf(0.5)].last!;
      expect(half, closeTo((swing.from.price + swing.to.price) / 2, 1e-9));
    });

    test('Elliott labels count the pivots in order', () {
      final waves = elliottWaves(swinging, 5);

      expect(waves, isNotEmpty);
      expect(waves.length, lessThanOrEqualTo(elliottWaveLabels.length));
      expect(waves.map((w) => w.label), elliottWaveLabels.take(waves.length));
      for (var i = 1; i < waves.length; i++) {
        expect(waves[i].pivot.index, greaterThan(waves[i - 1].pivot.index));
      }
    });

    test('an auto depth finds swings a fixed percentage misses', () {
      // A quiet intraday market: it drifts, but never moves 5 percent.
      final quiet = spreadCandles([
        for (var i = 0; i < 200; i++)
          100.0 + (i ~/ 20).remainder(2) * 0.4 + i * 0.002,
      ], spread: 0.05);

      // What the old fixed default did on this market: nothing at all.
      expect(zigzagPivots(quiet, 5), isEmpty);

      final auto = zigzagPivots(quiet, 0);
      expect(auto.length, greaterThan(2));
      expect(autoSwingDepth(quiet), lessThan(5));
      expect(autoSwingDepth(quiet), greaterThan(0));

      // A market that swings hard gets a proportionally bigger threshold, so
      // both end up with a readable number of legs rather than hundreds.
      expect(autoSwingDepth(swinging), greaterThan(autoSwingDepth(quiet)));
      expect(zigzagPivots(swinging, 0).length, lessThan(20));
    });

    test('an explicit depth is used as given', () {
      expect(effectiveSwingDepth(swinging, 7.5), 7.5);
      expect(effectiveSwingDepth(swinging, 0), autoSwingDepth(swinging));
      expect(autoSwingDepth(const []), 1);
    });

    test('swings on an empty or flat list are simply absent', () {
      expect(zigzagPivots(const [], 5), isEmpty);
      expect(lastSwing(const [], 5), isNull);
      expect(elliottWaves(const [], 5), isEmpty);
      expect(
        fibonacciSeries(candles([100, 100, 100]), 5),
        everyElement(everyElement(isNull)),
      );
    });
  });

  group('as indicators', () {
    final data = spreadCandles(rampThenFall(120));

    test('every new indicator computes a value per candle', () {
      final indicators = <Indicator>[
        SupertrendIndicator(),
        KeltnerIndicator(),
        DonchianIndicator(),
        IchimokuIndicator(),
        ZigZagIndicator(),
        FibonacciIndicator(),
        ElliottWaveIndicator(),
        StochRsiIndicator(),
        RocIndicator(),
        TrixIndicator(),
        VolumeMaIndicator(),
        AwesomeIndicator(),
      ];

      for (final indicator in indicators) {
        final series = indicator.compute(data);
        expect(
          series.lines.length,
          indicator.lines.length,
          reason: '${indicator.label} draws every line it declares',
        );
        for (final line in series.lines) {
          expect(line.length, data.length, reason: indicator.label);
        }
      }
    });

    test('the Supertrend line takes the trend colour on each side', () {
      final theme = ChartColors();
      final indicator = SupertrendIndicator();
      final series = indicator.compute(data);

      final last = data.length - 1;
      final value = series.lines.first[last]!;
      final colour = indicator.colorForPoint(0, last, data[last], value, theme);
      expect(colour, value < data[last].close ? theme.upColor : theme.dnColor);
    });

    test('Elliott labels reach the painter by candle index', () {
      final swinging = spreadCandles([
        for (var i = 0; i < 30; i++) 100.0 + i * 2,
        for (var i = 0; i < 30; i++) 158.0 - i * 3,
      ], spread: 0);

      final indicator = ElliottWaveIndicator();
      final series = indicator.compute(swinging);
      final marked = [
        for (var i = 0; i < swinging.length; i++)
          if (series.lines.first[i] != null) i,
      ];

      expect(marked, isNotEmpty);
      for (final index in marked) {
        expect(indicator.markerLabel(0, index), isNotNull);
      }
      expect(indicator.markerLabel(0, marked.first), '1');
    });

    test('the Ichimoku cloud is shaded between its two spans', () {
      final indicator = IchimokuIndicator();
      expect(indicator.fills.single.line, 2);
      expect(indicator.fills.single.against, 3);

      final theme = ChartColors();
      final above = indicator.fillColor(
        indicator.fills.single,
        theme,
        isAbove: true,
      );
      final below = indicator.fillColor(
        indicator.fills.single,
        theme,
        isAbove: false,
      );
      expect(above, isNot(below));
      expect(above.a, lessThan(1));
    });

    test('a fibonacci with different ratios is a different indicator', () {
      expect(FibonacciIndicator(), FibonacciIndicator());
      expect(
        FibonacciIndicator(ratios: const [0, 0.5, 1]),
        isNot(FibonacciIndicator()),
      );
      expect(FibonacciIndicator(ratios: const [0, 0.5, 1]).lines.length, 3);
    });

    test('depth is what makes two zigzags different', () {
      expect(ZigZagIndicator(depth: 5), ZigZagIndicator(depth: 5));
      expect(ZigZagIndicator(depth: 3), isNot(ZigZagIndicator(depth: 5)));
      expect(ZigZagIndicator(depth: 2.5).label, 'ZigZag(2.5%)');
      // The default sizes itself to the market, and says so.
      expect(ZigZagIndicator().label, 'ZigZag(auto)');
      expect(FibonacciIndicator().label, 'FIB(auto)');
      expect(ElliottWaveIndicator().label, 'Elliott(auto)');
    });

    test('the swing readers draw on a quiet market too', () {
      final quiet = spreadCandles([
        for (var i = 0; i < 200; i++)
          100.0 + (i ~/ 20).remainder(2) * 0.4 + i * 0.002,
      ], spread: 0.05);

      expect(
        ZigZagIndicator().compute(quiet).lines.first.whereType<double>().length,
        greaterThan(2),
      );
      expect(
        FibonacciIndicator()
            .compute(quiet)
            .lines
            .first
            .whereType<double>()
            .length,
        greaterThan(0),
      );
      final waves = ElliottWaveIndicator()..compute(quiet);
      expect(elliottWaves(quiet, 0), isNotEmpty);
      expect(waves.label, 'Elliott(auto)');
    });
  });

  test('the maths hold up on a single candle', () {
    final one = candles([100]);
    expect(donchianSeries(one, 20).upper, [null]);
    expect(supertrendSeries(one, period: 10, multiplier: 3).line, [null]);
    expect(rocSeries(one, 12), [null]);
    expect(volumeMaSeries(one, 20), [null]);
    expect(awesomeSeries(one, fast: 5, slow: 34), [null]);
    expect(zigzagPivots(one, 5), isEmpty);
    expect(
      math.max(0, elliottWaves(one, 5).length),
      0,
      reason: 'no swings, no waves',
    );
  });
}
