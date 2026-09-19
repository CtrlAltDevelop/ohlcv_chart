import 'dart:convert';

import 'package:material_ui/material_ui.dart' show Color, Colors;
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

void main() {
  group('indicatorToJson', () {
    test('round-trips every indicator the catalog can build', () {
      for (final type in indicatorCatalog) {
        final indicator = type.create();
        final json = indicatorToJson(indicator);
        expect(json, isNotNull, reason: '${type.name} could not be written');

        final back = indicatorFromJson(json!);
        expect(back, isNotNull, reason: '${type.name} could not be read back');
        expect(
          back,
          indicator,
          reason: '${type.name} came back as a different indicator',
        );
        expect(back!.label, indicator.label, reason: type.name);
      }
    });

    test('round-trips every setting a catalog entry offers', () {
      for (final type in indicatorCatalog) {
        for (final setting in type.settings) {
          // A value away from the default, so a codec that quietly drops the
          // setting cannot pass by accident.
          final chosen = setting.coerce(
            (setting.defaultValue + setting.step * 2).clamp(
              setting.min,
              setting.max,
            ),
          );
          final values = type.defaults..[setting.key] = chosen;
          final indicator = type.create(values: values);

          final back = indicatorFromJson(indicatorToJson(indicator)!);
          expect(
            back,
            indicator,
            reason: '${type.name}.${setting.key} at $chosen',
          );
          expect(back!.label, indicator.label);
        }
      }
    });

    test('keeps the colours an indicator was given', () {
      final indicator = MaIndicator(period: 20, color: Colors.tealAccent);
      final back = indicatorFromJson(indicatorToJson(indicator)!)!;

      expect(back.colors, isNotNull);
      expect(back.colors!.first.toARGB32(), Colors.tealAccent.toARGB32());
    });

    test('leaves colours alone when none were given', () {
      final back = indicatorFromJson(indicatorToJson(MaIndicator())!)!;
      expect(back.colors, isNull, reason: 'the theme should still decide');
    });

    test('tells a weekly pivot from a daily one', () {
      // Both call themselves PIVOT, so a codec matching on the name alone would
      // turn one into the other.
      final weekly = PivotPointsIndicator(session: PivotSession.week);
      final daily = PivotPointsIndicator();
      expect(weekly, isNot(daily));

      expect(indicatorFromJson(indicatorToJson(weekly)!), weekly);
      expect(indicatorFromJson(indicatorToJson(daily)!), daily);
    });

    test('tells the three pivot methods apart', () {
      for (final method in PivotMethod.values) {
        final indicator = PivotPointsIndicator(method: method);
        expect(indicatorFromJson(indicatorToJson(indicator)!), indicator);
      }
    });

    test('declines an indicator the catalog cannot rebuild', () {
      expect(indicatorToJson(_Mine()), isNull);
    });

    test('declines a kind it does not know', () {
      expect(indicatorFromJson({'kind': 'NOT_A_THING'}), isNull);
      expect(indicatorFromJson({'values': <String, num>{}}), isNull);
    });

    test('brings an out-of-range setting into range', () {
      final back = indicatorFromJson({
        'kind': 'MA',
        'values': {'period': 1000000},
      });
      final period = indicatorCatalog
          .firstWhere((t) => t.name == 'MA')
          .settings
          .first;
      expect(back, isNotNull);
      expect(back!.label, 'MA(${period.max.toInt()})');
    });

    test('falls back to defaults for a missing setting', () {
      final back = indicatorFromJson({'kind': 'ATR'});
      expect(back, AtrIndicator(period: 14));
    });
  });

  group('ChartWorkspace', () {
    test('round-trips through JSON text', () {
      final drawings = ChartDrawings([
        HorizontalLine(price: 101.5, color: Colors.orange),
        TrendLine(
          time1: DateTime(2024, 1, 3),
          price1: 100,
          time2: DateTime(2024, 2, 9),
          price2: 120,
        ),
      ]);
      final workspace = ChartWorkspace(
        indicators: [
          MaIndicator(period: 20, color: Colors.amber),
          BollIndicator(period: 20),
          MacdIndicator(),
        ],
        drawings: drawings,
        chartType: ChartType.bars,
        priceAxisScale: PriceAxisScale.logarithmic,
        invertPriceAxis: true,
      );

      final text = jsonEncode(workspace.toJson());
      final back = ChartWorkspace.fromJson(
        jsonDecode(text) as Map<String, dynamic>,
      );

      expect(back.indicators, workspace.indicators);
      expect(
        back.indicators.first.colors!.first.toARGB32(),
        Colors.amber.toARGB32(),
      );
      expect(back.chartType, ChartType.bars);
      expect(back.priceAxisScale, PriceAxisScale.logarithmic);
      expect(back.invertPriceAxis, isTrue);
      expect(back.drawings!.length, 2);
      expect(back.drawings!.horizontalLines.single.price, 101.5);
      expect(back.drawings!.trendLines.single.price2, 120);
    });

    test('an empty workspace round-trips to an empty one', () {
      final back = ChartWorkspace.fromJson(const ChartWorkspace().toJson());
      expect(back.indicators, isEmpty);
      expect(back.drawings, isNull);
      expect(back.chartType, isNull);
      expect(back.priceAxisScale, PriceAxisScale.linear);
      expect(back.invertPriceAxis, isFalse);
    });

    test('stamps a version', () {
      expect(
        const ChartWorkspace().toJson()['version'],
        ChartWorkspace.formatVersion,
      );
    });

    test('skips what it cannot read and keeps the rest', () {
      final back = ChartWorkspace.fromJson({
        'version': 99,
        'indicators': [
          {
            'kind': 'MA',
            'values': {'period': 9},
          },
          {'kind': 'SOMETHING_NEW'},
          'not even a map',
          {'kind': 'RSI'},
        ],
        'chartType': 'someFutureType',
        'priceAxisScale': 'someFutureScale',
      });

      expect(back.indicators, [MaIndicator(period: 9), RsiIndicator()]);
      expect(back.chartType, isNull, reason: 'unknown type falls away');
      expect(back.priceAxisScale, PriceAxisScale.linear);
    });

    test('reports the indicators it cannot save, and leaves them out', () {
      final mine = _Mine();
      final workspace = ChartWorkspace(
        indicators: [MaIndicator(period: 20), mine],
      );

      expect(workspace.unsaveable, [mine]);

      final back = ChartWorkspace.fromJson(workspace.toJson());
      expect(back.indicators, [MaIndicator(period: 20)]);
    });

    test('copyWith replaces only what it is given', () {
      final workspace = ChartWorkspace(
        indicators: [MaIndicator(period: 20)],
        priceAxisScale: PriceAxisScale.logarithmic,
      );
      final moved = workspace.copyWith(indicators: [RsiIndicator()]);

      expect(moved.indicators, [RsiIndicator()]);
      expect(moved.priceAxisScale, PriceAxisScale.logarithmic);
    });
  });

  group('indicatorTypeRebuilding', () {
    test('finds the entry that rebuilds an indicator exactly', () {
      expect(indicatorTypeRebuilding(AtrIndicator(period: 8))?.name, 'ATR');
      expect(
        indicatorTypeRebuilding(
          PivotPointsIndicator(session: PivotSession.week),
        )?.name,
        'PIVOTW',
      );
    });

    test('answers null for one the catalog cannot rebuild', () {
      expect(indicatorTypeRebuilding(_Mine()), isNull);
    });

    test('indicatorTypeOf still falls back to the name', () {
      // Reachable exactly, so both agree.
      expect(indicatorTypeOf(AtrIndicator(period: 8))?.name, 'ATR');
    });
  });
}

/// An indicator of somebody's own, which the catalog knows nothing about.
class _Mine extends Indicator {
  @override
  IndicatorPlacement get placement => IndicatorPlacement.pane;

  @override
  String get name => 'MINE';

  @override
  String get label => 'MINE';

  @override
  List<IndicatorLine> get lines => [const IndicatorLine('MINE')];

  @override
  List<Object?> get settings => const ['bespoke'];

  @override
  IndicatorSeries compute(List<KLineEntity> candles) =>
      IndicatorSeries([List<double?>.filled(candles.length, 1)]);

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      theme.ma5Color;
}
