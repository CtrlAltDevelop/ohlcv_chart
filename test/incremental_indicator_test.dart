import 'dart:math';

import 'package:material_ui/material_ui.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

/// Every indicator that claims it can resume, and a couple of settings each.
///
/// `extendSeries` is a shortcut for `compute`, so the only thing worth testing
/// is that it is not a different answer. Anything that returns null here is
/// recomputed in full by the chart and needs no proof.
final List<Indicator> resumable = [
  MaIndicator(period: 5),
  MaIndicator(period: 20),
  EmaIndicator(period: 5),
  EmaIndicator(period: 26),
  BollIndicator(period: 20, deviations: 2),
  BollIndicator(period: 5, deviations: 1.5),
  WrIndicator(period: 14),
  CciIndicator(period: 14),
  AtrIndicator(period: 14),
  AtrIndicator(period: 8),
  ObvIndicator(),
  MfiIndicator(period: 14),
  RocIndicator(period: 12),
  VolumeMaIndicator(period: 10),
  DonchianIndicator(period: 20),
  AroonIndicator(period: 14),
  AroonIndicator(period: 25),
  // These two out-wait their seed rather than resuming from it; the point of
  // testing them alongside the rest is that the difference does not show.
  RsiIndicator(period: 14),
  MacdIndicator(),
];

/// A deterministic random walk, so a failure can be reproduced from the seed.
List<KLineEntity> walk(int count, {int seed = 7}) {
  final random = Random(seed);
  final out = <KLineEntity>[];
  var price = 100.0;
  for (var i = 0; i < count; i++) {
    price = max(1, price * (1 + (random.nextDouble() - 0.5) * 0.04));
    final high = price * (1 + random.nextDouble() * 0.01);
    final low = price * (1 - random.nextDouble() * 0.01);
    out.add(
      KLineEntity.fromCustom(
        open: (high + low) / 2,
        high: high,
        low: low,
        close: price,
        vol: 100 + random.nextDouble() * 900,
        dateTime: DateTime.utc(2024).add(Duration(minutes: i)),
      ),
    );
  }
  return out;
}

KLineEntity retick(KLineEntity candle, double close) => KLineEntity.fromCustom(
  open: candle.open,
  high: max(candle.high, close),
  low: min(candle.low, close),
  close: close,
  vol: candle.vol + 10,
  dateTime: candle.dateTime!,
);

/// Indicators built on a running total rather than a re-added window.
///
/// `smaSeries` and `volumeMaSeries` carry their sum across the list, so a graft
/// that starts part-way along accumulates its rounding differently. Their values
/// are compared to a relative bound rather than bit-for-bit; everything else has
/// to match exactly.
bool _rollsASum(Indicator indicator) =>
    indicator is MaIndicator ||
    indicator is VolumeMaIndicator ||
    indicator is BollIndicator; // its middle band is an SMA

/// Widest relative difference a rolling sum may drift by.
///
/// Floating-point accumulation over a few hundred candles lands around 1e-16
/// relative; 1e-12 leaves room for a long series without letting a real error
/// through. A chart draws two decimals, so this is invisible either way.
const _drift = 1e-12;

void expectSameSeries(
  IndicatorSeries actual,
  IndicatorSeries expected,
  String because, {
  bool exactly = true,
}) {
  expect(actual.lines.length, expected.lines.length, reason: '$because: lines');
  for (var line = 0; line < expected.lines.length; line++) {
    if (exactly) {
      expect(
        actual.lines[line],
        expected.lines[line],
        reason: '$because: line $line',
      );
      continue;
    }
    final was = expected.lines[line];
    final now = actual.lines[line];
    expect(now.length, was.length, reason: '$because: line $line length');
    for (var i = 0; i < was.length; i++) {
      if (was[i] == null || now[i] == null) {
        expect(now[i], was[i], reason: '$because: line $line at $i');
        continue;
      }
      final scale = was[i]!.abs() < 1 ? 1.0 : was[i]!.abs();
      expect(
        (now[i]! - was[i]!).abs() / scale,
        lessThan(_drift),
        reason: '$because: line $line at $i — ${now[i]} vs ${was[i]}',
      );
    }
  }
}

void main() {
  group('extendSeries agrees with compute', () {
    test('for a tick that moves the newest candle', () {
      final data = walk(400);
      for (final indicator in resumable) {
        final before = indicator.compute(data);

        final ticked = List<KLineEntity>.of(data);
        ticked[ticked.length - 1] = retick(
          ticked.last,
          ticked.last.close * 1.01,
        );

        final extended = indicator.extendSeries(
          ticked,
          before,
          ticked.length - 1,
        );
        expect(
          extended,
          isNotNull,
          reason: '${indicator.label} said it could resume',
        );
        expectSameSeries(
          extended!,
          indicator.compute(ticked),
          indicator.label,
          exactly: !_rollsASum(indicator),
        );
      }
    });

    test('for a candle appended to the series', () {
      final data = walk(400);
      for (final indicator in resumable) {
        final before = indicator.compute(data);

        final grown = List<KLineEntity>.of(data)
          ..add(
            KLineEntity.fromCustom(
              open: data.last.close,
              high: data.last.close * 1.02,
              low: data.last.close * 0.99,
              close: data.last.close * 1.005,
              vol: 500,
              dateTime: data.last.dateTime!.add(const Duration(minutes: 1)),
            ),
          );

        // The chart recomputes from the candle that was last, because the tick
        // that appended may also have settled it.
        final extended = indicator.extendSeries(grown, before, data.length - 1);
        expect(extended, isNotNull, reason: indicator.label);
        expectSameSeries(
          extended!,
          indicator.compute(grown),
          indicator.label,
          exactly: !_rollsASum(indicator),
        );
      }
    });

    test('over a whole session of ticks and rollovers', () {
      final random = Random(11);
      for (final indicator in resumable) {
        var data = walk(200);
        var series = indicator.compute(data);

        for (var step = 0; step < 120; step++) {
          final rollover = random.nextInt(5) == 0;
          final from = data.length - 1;
          if (rollover) {
            data = List<KLineEntity>.of(data)
              ..add(
                KLineEntity.fromCustom(
                  open: data.last.close,
                  high: data.last.close * 1.01,
                  low: data.last.close * 0.995,
                  close:
                      data.last.close * (1 + (random.nextDouble() - 0.5) / 50),
                  vol: 100 + random.nextDouble() * 400,
                  dateTime: data.last.dateTime!.add(const Duration(minutes: 1)),
                ),
              );
          } else {
            data = List<KLineEntity>.of(data);
            data[data.length - 1] = retick(
              data.last,
              data.last.close * (1 + (random.nextDouble() - 0.5) / 100),
            );
          }

          final extended = indicator.extendSeries(data, series, from);
          expect(extended, isNotNull, reason: indicator.label);
          series = extended!;
          expectSameSeries(
            series,
            indicator.compute(data),
            '${indicator.label} at step $step',
            exactly: !_rollsASum(indicator),
          );
        }
      }
    });

    test('from the very start of a short series', () {
      // `from` inside the warm-up is the awkward case: the shortcut has to
      // either be exact or decline, never guess.
      for (final indicator in resumable) {
        for (final length in [1, 2, 3, 5, 8, 21]) {
          final data = walk(length, seed: length);
          final before = indicator.compute(data);
          for (var from = 0; from <= data.length; from++) {
            final extended = indicator.extendSeries(data, before, from);
            if (extended == null) continue;
            expectSameSeries(
              extended,
              indicator.compute(data),
              '${indicator.label} length $length from $from',
              exactly: !_rollsASum(indicator),
            );
          }
        }
      }
    });
  });

  _cacheTests();
}

/// Counts how often it is actually asked to compute, so a test can tell a
/// reused series from a recomputed one.
class _CountingMa extends MaIndicator {
  _CountingMa() : super(period: 20);

  int computes = 0;
  int extends_ = 0;

  @override
  IndicatorSeries compute(List<KLineEntity> candles) {
    computes++;
    return super.compute(candles);
  }

  @override
  IndicatorSeries? extendSeries(
    List<KLineEntity> candles,
    IndicatorSeries previous,
    int from,
  ) {
    extends_++;
    return super.extendSeries(candles, previous, from);
  }
}

KLineEntity _at(DateTime time, double close) => KLineEntity.fromCustom(
  open: close,
  high: close + 1,
  low: close - 1,
  close: close,
  vol: 100,
  dateTime: time,
);

List<KLineEntity> _series(int count, {int from = 0}) => [
  for (var i = 0; i < count; i++)
    _at(DateTime.utc(2024).add(Duration(minutes: from + i)), 100.0 + i),
];

void _cacheTests() {
  group('IndicatorCache', () {
    test('extends the series when the newest candle moves', () {
      final cache = IndicatorCache();
      final indicator = _CountingMa();
      final data = _series(500);

      cache.seriesFor(indicator, data);
      expect(cache.fullComputations, 1);

      // A tick on the newest candle.
      final ticked = List<KLineEntity>.of(data);
      ticked[ticked.length - 1] = _at(data.last.dateTime!, 999);
      cache.seriesFor(indicator, ticked);

      expect(cache.extensions, 1);
      expect(cache.fullComputations, 1, reason: 'no second full pass');
      expect(indicator.computes, 1);
    });

    test('extends when a candle is appended', () {
      final cache = IndicatorCache();
      final indicator = _CountingMa();
      final data = _series(300);
      cache.seriesFor(indicator, data);

      final grown = List<KLineEntity>.of(data)
        ..add(_at(data.last.dateTime!.add(const Duration(minutes: 1)), 42));
      cache.seriesFor(indicator, grown);

      expect(cache.extensions, 1);
      expect(cache.fullComputations, 1);
    });

    test('serves an unchanged chart without computing at all', () {
      final cache = IndicatorCache();
      final indicator = _CountingMa();
      final data = _series(200);

      cache.seriesFor(indicator, data);
      cache.seriesFor(indicator, data);
      cache.seriesFor(indicator, data);

      expect(cache.fullComputations, 1);
      expect(cache.extensions, 0);
      expect(cache.hits, 2);
    });

    test('recomputes when only the volume of the newest candle moves', () {
      final cache = IndicatorCache();
      final indicator = VolumeMaIndicator(period: 5);
      final data = _series(50);

      final before = cache.seriesFor(indicator, data).valueAt(0, 49);
      // The same list and the same close: a trade at the price already printed.
      data.last.vol = 10100;
      final after = cache.seriesFor(indicator, data).valueAt(0, 49);

      expect(cache.hits, 0, reason: 'the stale series was served');
      expect(after, isNot(before));
    });

    test('recomputes when history is paged in at the front', () {
      final cache = IndicatorCache();
      final indicator = _CountingMa();
      final data = _series(200, from: 100);
      cache.seriesFor(indicator, data);

      // Older candles arriving push every index along, so nothing lines up.
      final paged = [..._series(100), ...data];
      cache.seriesFor(indicator, paged);

      expect(cache.extensions, 0, reason: 'the indices no longer line up');
      expect(cache.fullComputations, 2);
    });

    test('recomputes when a replay rewinds', () {
      final cache = IndicatorCache();
      final indicator = _CountingMa();
      final data = _series(300);
      cache.seriesFor(indicator, data);

      cache.seriesFor(indicator, data.sublist(0, 120));

      expect(cache.extensions, 0);
      expect(cache.fullComputations, 2);
    });

    test('recomputes for a new instance while the candles sit still', () {
      // Equal settings make two indicators the same as far as the chart is
      // concerned, but a fresh object may still compute something else — an
      // indicator reading a series handed in from outside. Values are only
      // reused for the very same object.
      final cache = IndicatorCache();
      final data = _series(200);

      cache.seriesFor(_CountingMa(), data);
      cache.seriesFor(_CountingMa(), data);

      expect(cache.hits, 0);
      expect(cache.fullComputations, 2);
    });

    test('reuses values across a recolour', () {
      final cache = IndicatorCache();
      final data = _series(400);

      final plain = MaIndicator(period: 20);
      cache.seriesFor(plain, data);

      // Colour is not part of what makes an indicator distinct, and does not
      // change a single value, so the tick after a recolour still extends.
      final ticked = List<KLineEntity>.of(data);
      ticked[ticked.length - 1] = _at(data.last.dateTime!, 555);
      cache.seriesFor(
        MaIndicator(period: 20, color: const Color(0xFF00FF00)),
        ticked,
      );

      expect(cache.extensions, 1);
      expect(cache.fullComputations, 1);
    });

    test('a changed period is a different indicator', () {
      final cache = IndicatorCache();
      final data = _series(200);

      cache.seriesFor(MaIndicator(period: 20), data);
      cache.seriesFor(MaIndicator(period: 50), data);

      expect(cache.fullComputations, 2);
    });

    test('forgets indicators taken off the chart', () {
      final cache = IndicatorCache();
      final data = _series(100);
      final kept = MaIndicator(period: 20);

      cache.seriesFor(kept, data);
      cache.seriesFor(MaIndicator(period: 50), data);
      cache.retain([kept]);

      // The one still on the chart is remembered; the other has to start again.
      cache.seriesFor(kept, data);
      final before = cache.fullComputations;
      cache.seriesFor(MaIndicator(period: 50), data);
      expect(cache.fullComputations, before + 1);
    });

    test('an indicator that cannot resume is recomputed in full', () {
      // A zigzag reads the whole series to find its swings, so there is no tail
      // to extend and it declines — computed from the first candle every time.
      final cache = IndicatorCache();
      final data = _series(300);
      final zigzag = ZigZagIndicator();

      cache.seriesFor(zigzag, data);
      final ticked = List<KLineEntity>.of(data);
      ticked[ticked.length - 1] = _at(data.last.dateTime!, 777);
      cache.seriesFor(zigzag, ticked);

      expect(cache.extensions, 0);
      expect(cache.fullComputations, 2);
    });

    test('the values a cache serves match a cold computation', () {
      // The whole point: whatever route the cache takes, the answer is the one
      // a fresh full pass would give.
      final cache = IndicatorCache();
      final indicators = [...resumable, ZigZagIndicator()];
      var data = _series(250);
      for (final indicator in indicators) {
        cache.seriesFor(indicator, data);
      }

      final random = Random(3);
      for (var step = 0; step < 40; step++) {
        data = List<KLineEntity>.of(data);
        if (random.nextInt(4) == 0) {
          data.add(
            _at(
              data.last.dateTime!.add(const Duration(minutes: 1)),
              data.last.close * 1.002,
            ),
          );
        } else {
          data[data.length - 1] = _at(
            data.last.dateTime!,
            data.last.close * (1 + (random.nextDouble() - 0.5) / 50),
          );
        }

        for (final indicator in indicators) {
          expectSameSeries(
            cache.seriesFor(indicator, data),
            indicator.compute(data),
            '${indicator.label} at step $step',
            exactly: !_rollsASum(indicator),
          );
        }
      }
    });
  });
}
