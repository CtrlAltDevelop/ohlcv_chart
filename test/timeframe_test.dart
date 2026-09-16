import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

/// Hourly candles, [count] of them, closing at 100, 101, 102, …
List<KLineEntity> hourly(int count, {int startHour = 0}) => [
      for (var i = 0; i < count; i++)
        KLineEntity.fromCustom(
          open: 100.0 + i,
          high: 100.5 + i,
          low: 99.5 + i,
          close: 100.0 + i,
          vol: 10,
          dateTime:
              DateTime.utc(2024, 1, 1).add(Duration(hours: startHour + i)),
        ),
    ];

void main() {
  group('resampling', () {
    test('aggregates a day of hourly candles into one bar', () {
      final bars = CandleTransforms.resample(
        hourly(24),
        const Duration(days: 1),
      );

      expect(bars, hasLength(1));
      expect(bars.single.open, 100); // the first open
      expect(bars.single.high, 100.5 + 23); // the highest high
      expect(bars.single.low, 99.5); // the lowest low
      expect(bars.single.close, 100.0 + 23); // the last close
      expect(bars.single.vol, 24 * 10); // the total volume
      expect(bars.single.dateTime, DateTime.utc(2024, 1, 1));
    });

    test('breaks where the day does, not every 24 candles', () {
      // Starting at 22:00 puts the first two candles in the previous day.
      final bars = CandleTransforms.resample(
        hourly(24, startHour: 22),
        const Duration(days: 1),
      );

      // Two candles land in the first day and the remaining 22 in the second.
      expect(bars, hasLength(2));
      expect(bars.first.dateTime, DateTime.utc(2024, 1, 1, 22));
      expect(bars.first.vol, 2 * 10);
      expect(bars[1].dateTime, DateTime.utc(2024, 1, 2));
      expect(bars[1].vol, 22 * 10);
    });

    test('the last bar may be partial', () {
      final bars = CandleTransforms.resample(
        hourly(30),
        const Duration(days: 1),
      );

      expect(bars, hasLength(2));
      expect(bars.last.vol, 6 * 10, reason: 'six hours into the second day');
    });

    test('a timeframe finer than the candles gives one bar each', () {
      final bars = CandleTransforms.resample(
        hourly(5),
        const Duration(minutes: 1),
      );
      expect(bars, hasLength(5));
    });

    test('no candles, no bars', () {
      expect(
        CandleTransforms.resample(const [], const Duration(days: 1)),
        isEmpty,
      );
    });
  });

  group('TimeframeIndicator', () {
    test('holds the last closed bar flat across the candles inside one', () {
      final data = hourly(72); // three whole days
      final indicator = TimeframeIndicator(
        timeframe: const Duration(days: 1),
        applied: MaIndicator(period: 1), // the daily close itself
      );

      final values = indicator.compute(data).lines.single;
      final bars = CandleTransforms.resample(data, const Duration(days: 1));

      // Day one has nothing closed behind it.
      expect(values.take(24), everyElement(isNull));
      // Every candle of day two reads day one's close, and holds it.
      expect(values.sublist(24, 48), everyElement(equals(bars.first.close)));
      // Day three reads day two's.
      expect(values.sublist(48, 72), everyElement(equals(bars[1].close)));
    });

    test('never reads a bar the candle could not have known', () {
      final data = hourly(72);
      final indicator = TimeframeIndicator(
        timeframe: const Duration(days: 1),
        applied: MaIndicator(period: 1),
      );
      final values = indicator.compute(data).lines.single;

      // Whatever a candle shows must have been settled before it opened, so it
      // can never exceed the highest close among strictly earlier candles.
      for (var i = 0; i < data.length; i++) {
        final value = values[i];
        if (value == null) continue;
        final earlier = data.sublist(0, i).map((c) => c.close);
        expect(
          value,
          lessThanOrEqualTo(earlier.reduce((a, b) => a > b ? a : b)),
          reason: 'candle $i showed a value from its own future',
        );
      }
    });

    test('does not repaint as the newest bar fills in', () {
      final full = hourly(72);
      final indicator = TimeframeIndicator(
        timeframe: const Duration(days: 1),
        applied: MaIndicator(period: 1),
      );

      // What the first 60 candles showed when only 60 had arrived has to be
      // what they still show once the day has finished.
      final partial = indicator.compute(full.sublist(0, 60)).lines.single;
      final settled = indicator.compute(full).lines.single;

      expect(partial, settled.sublist(0, 60));
    });

    test('carries the applied indicator\'s pane settings', () {
      final indicator = TimeframeIndicator(
        timeframe: const Duration(days: 1),
        applied: RsiIndicator(period: 14),
      );

      expect(indicator.placement, IndicatorPlacement.pane);
      expect(indicator.fixedRange, (0, 100));
      expect(indicator.guides, const [30, 50, 70]);
      expect(indicator.lines, hasLength(1));
    });

    test('is its own indicator, per timeframe and per applied setting', () {
      final daily = TimeframeIndicator(
        timeframe: const Duration(days: 1),
        applied: MaIndicator(period: 20),
      );

      expect(
        daily,
        TimeframeIndicator(
          timeframe: const Duration(days: 1),
          applied: MaIndicator(period: 20),
        ),
      );
      expect(
        daily,
        isNot(
          TimeframeIndicator(
            timeframe: const Duration(hours: 4),
            applied: MaIndicator(period: 20),
          ),
        ),
      );
      expect(
        daily,
        isNot(
          TimeframeIndicator(
            timeframe: const Duration(days: 1),
            applied: MaIndicator(period: 50),
          ),
        ),
      );
    });

    test('labels itself the way a platform would', () {
      expect(
        TimeframeIndicator(
          timeframe: const Duration(days: 1),
          applied: MaIndicator(period: 20),
        ).label,
        'MA(20) @ 1D',
      );
      expect(formatTimeframe(const Duration(minutes: 15)), '15m');
      expect(formatTimeframe(const Duration(hours: 4)), '4h');
      expect(formatTimeframe(const Duration(days: 7)), '1W');
      expect(formatTimeframe(const Duration(days: 90)), '3M');
      expect(formatTimeframe(const Duration(minutes: 90)), '90m');
    });

    test('draws nothing over no candles at all', () {
      final series = TimeframeIndicator(
        timeframe: const Duration(days: 1),
        applied: MaIndicator(period: 20),
      ).compute(const []);

      expect(series.lines.single, isEmpty);
    });
  });
}
