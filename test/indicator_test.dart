import 'package:material_ui/material_ui.dart' show Colors;
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

import 'test_utils.dart';

void main() {
  group('indicator identity', () {
    test('same kind and settings are equal, whatever colour they carry', () {
      expect(AtrIndicator(period: 14), AtrIndicator(period: 14));
      expect(
        AtrIndicator(period: 14, color: Colors.red),
        AtrIndicator(period: 14, color: Colors.blue),
      );
      expect(
        AtrIndicator(period: 14).hashCode,
        AtrIndicator(period: 14, color: Colors.blue).hashCode,
      );
    });

    test('different settings are different indicators', () {
      expect(AtrIndicator(period: 8), isNot(AtrIndicator(period: 14)));
      expect(MaIndicator(period: 14), isNot(AtrIndicator(period: 14)));
      expect(
        MacdIndicator(fast: 12, slow: 26, signal: 9),
        isNot(MacdIndicator(fast: 5, slow: 26, signal: 9)),
      );
    });

    test('labels carry the settings', () {
      expect(AtrIndicator(period: 8).label, 'ATR(8)');
      expect(MacdIndicator().label, 'MACD(12,26,9)');
      expect(BollIndicator(period: 20, deviations: 2.5).label, 'BOLL(20,2.5)');
    });
  });

  group('editing a list of indicators', () {
    test('upsert adds a new indicator and replaces an equal one in place', () {
      final indicators = <Indicator>[
        AtrIndicator(period: 8),
        AtrIndicator(period: 14),
        AtrIndicator(period: 20),
      ];

      expect(indicators.upsert(AtrIndicator(period: 5)), isFalse);
      expect(indicators.length, 4);

      // Re-adding ATR(14) in a new colour restyles it where it already sits.
      expect(
        indicators.upsert(AtrIndicator(period: 14, color: Colors.purple)),
        isTrue,
      );
      expect(indicators.length, 4);
      expect(indicators[1].label, 'ATR(14)');
      expect(indicators[1].colors, [Colors.purple]);
    });

    test('toggle adds then removes', () {
      final indicators = <Indicator>[];
      expect(indicators.toggle(RsiIndicator()), isTrue);
      expect(indicators.single.label, 'RSI(14)');
      expect(indicators.toggle(RsiIndicator(color: Colors.teal)), isFalse);
      expect(indicators, isEmpty);
    });
  });

  group('resolving indicators for the painters', () {
    final data = candles(rampThenFall(60));

    test('splits overlays from panes and counts the legend rows', () {
      final resolved = resolveIndicators([
        MaIndicator(period: 5),
        MaIndicator(period: 20),
        EmaIndicator(period: 10),
        AtrIndicator(period: 14),
        MacdIndicator(),
      ], data);

      expect(resolved.overlays.map((r) => r.indicator.label), [
        'MA(5)',
        'MA(20)',
        'EMA(10)',
      ]);
      expect(resolved.panes.map((r) => r.indicator.label), [
        'ATR(14)',
        'MACD(12,26,9)',
      ]);
      // MA and EMA are separate groups; the two averages share a row.
      expect(resolved.legendRowCount, 2);
    });

    test('keeps the last of an equal pair, in the first one\'s place', () {
      final resolved = resolveIndicators([
        AtrIndicator(period: 8),
        RsiIndicator(),
        AtrIndicator(period: 8, color: Colors.orange),
      ], data);

      expect(resolved.panes.map((r) => r.indicator.label), [
        'ATR(8)',
        'RSI(14)',
      ]);
      expect(resolved.panes.first.colorFor(0, ChartColors()), Colors.orange);
    });

    test('repeated averages take different theme colours', () {
      final theme = ChartColors();
      final resolved = resolveIndicators([
        MaIndicator(period: 5),
        MaIndicator(period: 20),
      ], data);

      expect(
        resolved.overlays.first.colorFor(0, theme),
        isNot(resolved.overlays.last.colorFor(0, theme)),
      );
    });

    test('an explicit colour beats the theme', () {
      final resolved = resolveIndicators([
        MaIndicator(period: 5, color: Colors.pink),
      ], data);
      expect(resolved.overlays.single.colorFor(0, ChartColors()), Colors.pink);
    });

    test('computes a value per candle, warming up with nulls', () {
      final resolved = resolveIndicators([MaIndicator(period: 5)], data);
      final series = resolved.overlays.single.series.lines.single;

      expect(series.length, data.length);
      expect(series.first, isNull);
      expect(series.last, isNotNull);
    });

    test('handles no candles at all', () {
      final resolved = resolveIndicators([MacdIndicator()], null);
      expect(resolved.panes.single.valueAt(0, 0), isNull);
    });
  });

  group('the catalog', () {
    test('describes every indicator with buildable defaults', () {
      for (final type in indicatorCatalog) {
        final indicator = type.create();
        expect(indicator.name, type.name, reason: type.name);
        expect(indicator.placement, type.placement, reason: type.name);
        expect(
          type.valuesOf(indicator),
          type.defaults,
          reason: '${type.name} round-trips its settings',
        );
        expect(
          type.lineLabels().length,
          indicator.lines.length,
          reason: type.name,
        );
        expect(
          type.defaultColors(ChartColors()).length,
          indicator.lines.length,
          reason: type.name,
        );
      }
    });

    test('builds an indicator from edited settings', () {
      final type = indicatorCatalog.firstWhere((t) => t.name == 'ATR');
      final values = type.defaults..['period'] = 8;

      final indicator = type.create(values: values, colors: [Colors.purple]);
      expect(indicator, AtrIndicator(period: 8));
      expect(indicator.colorFor(0, ChartColors()), Colors.purple);
      expect(type.valuesOf(indicator), {'period': 8});
    });

    test('settings are clamped and rounded to what they accept', () {
      final type = indicatorCatalog.firstWhere((t) => t.name == 'RSI');
      expect(type.create(values: {'period': 0}).label, 'RSI(2)');
      expect(type.create(values: {'period': 9999}).label, 'RSI(200)');
      expect(type.create(values: {'period': 7.6}).label, 'RSI(8)');
    });

    test('a fractional setting keeps its decimals', () {
      final type = indicatorCatalog.firstWhere((t) => t.name == 'BOLL');
      final indicator = type.create(values: {'period': 20, 'deviations': 2.5});
      expect(indicator, BollIndicator(period: 20, deviations: 2.5));
    });

    test('finds the entry describing an existing indicator', () {
      expect(indicatorTypeOf(AtrIndicator(period: 8))?.name, 'ATR');
      expect(
        indicatorTypeOf(
          AtrIndicator(period: 8),
        )?.valuesOf(AtrIndicator(period: 8)),
        {'period': 8},
      );
    });

    test('every catalog entry computes over a short history', () {
      final short = candles(rampThenFall(6));
      for (final type in indicatorCatalog) {
        final series = type.create().compute(short);
        expect(series.lines, isNotEmpty, reason: type.name);
        for (final line in series.lines) {
          expect(line.length, short.length, reason: type.name);
        }
      }
    });
  });
}
