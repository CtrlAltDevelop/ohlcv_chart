import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

void main() {
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
