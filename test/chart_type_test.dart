import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

import 'test_utils.dart';

Widget _chart({ChartType? type, bool isLine = false, double? baseline}) {
  final data = candles(rampThenFall(60));
  DataUtil.calculate(data);

  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 500,
        height: 600,
        child: KChartWidget(
          data,
          ChartColors(),
          isTrendLine: false,
          timeFrame: const Duration(minutes: 15),
          chartType: type,
          isLine: isLine,
          baselinePrice: baseline,
        ),
      ),
    ),
  );
}

void main() {
  group('chart types', () {
    testWidgets('every one draws without blowing up', (tester) async {
      for (final type in ChartType.values) {
        await tester.pumpWidget(_chart(type: type));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$type');
      }
    });

    testWidgets('a baseline chart takes the level it is given', (tester) async {
      await tester.pumpWidget(_chart(type: ChartType.baseline, baseline: 120));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('isLine still means an area chart', (tester) async {
      await tester.pumpWidget(_chart(isLine: true));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('a column chart takes the level it is given', (tester) async {
      await tester.pumpWidget(_chart(type: ChartType.columns, baseline: 120));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('the ones that show a range keep their overlays', (
      tester,
    ) async {
      // An HLC area and a column chart both say something per bar, so an
      // average over them still has something to sit on; a plain line chart
      // does not draw one.
      final data = candles(rampThenFall(60));
      DataUtil.calculate(data);

      Widget chart(ChartType type) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            height: 600,
            child: KChartWidget(
              data,
              ChartColors(),
              isTrendLine: false,
              timeFrame: const Duration(minutes: 15),
              chartType: type,
              indicators: [MaIndicator(period: 5)],
            ),
          ),
        ),
      );

      for (final type in [
        ChartType.hlcArea,
        ChartType.columns,
        ChartType.stepLine,
        ChartType.line,
      ]) {
        await tester.pumpWidget(chart(type));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$type');
      }
    });
  });

  group('Heikin-Ashi', () {
    test('averages each candle with the one before it', () {
      final data = [
        candle(10, open: 10, high: 12, low: 8, minute: 0),
        candle(14, open: 11, high: 15, low: 10, minute: 1),
      ];

      final ha = CandleTransforms.heikinAshi(data);

      // The first candle has nothing before it: its open is (open + close) / 2.
      expect(ha.first.open, closeTo(10, 1e-9));
      expect(ha.first.close, closeTo((10 + 12 + 8 + 10) / 4, 1e-9));

      // The second opens midway through the first Heikin-Ashi candle.
      expect(ha[1].open, closeTo((ha.first.open + ha.first.close) / 2, 1e-9));
      expect(ha[1].close, closeTo((11 + 15 + 10 + 14) / 4, 1e-9));
      expect(ha[1].high, closeTo(15, 1e-9));
    });

    test('keeps one candle per candle, at the same times', () {
      final data = candles(rampThenFall(30));
      final ha = CandleTransforms.heikinAshi(data);

      expect(ha, hasLength(data.length));
      for (var i = 0; i < data.length; i++) {
        expect(ha[i].dateTime, data[i].dateTime);
      }
    });

    test('a high and low always hold the body', () {
      final ha = CandleTransforms.heikinAshi(candles(rampThenFall(40)));

      for (final bar in ha) {
        expect(bar.high, greaterThanOrEqualTo(bar.open));
        expect(bar.high, greaterThanOrEqualTo(bar.close));
        expect(bar.low, lessThanOrEqualTo(bar.open));
        expect(bar.low, lessThanOrEqualTo(bar.close));
      }
    });

    test('leaves the original candles alone', () {
      final data = candles([10, 11, 12]);
      CandleTransforms.heikinAshi(data);

      expect(data[1].close, 11);
      expect(data[1].open, 11);
    });

    test('an empty list transforms to an empty list', () {
      expect(CandleTransforms.heikinAshi([]), isEmpty);
    });
  });

  group('Renko', () {
    test('lays a brick for every whole step of the move', () {
      final data = candles([100, 101, 102, 103, 104]);
      final bricks = CandleTransforms.renko(data, brickSize: 2);

      // From the 100 grid line: bricks at 102 and 104.
      expect(bricks, hasLength(2));
      expect(bricks[0].open, 100);
      expect(bricks[0].close, 102);
      expect(bricks[1].open, 102);
      expect(bricks[1].close, 104);
    });

    test('lays nothing while price wobbles inside one brick', () {
      final data = candles([100, 100.5, 99.8, 100.9, 100.2]);

      expect(CandleTransforms.renko(data, brickSize: 2), isEmpty);
    });

    test('a reversal costs two bricks', () {
      // Up to 104, then back through 102 and 100: the first brick down only
      // arrives once two brick-widths have been given back.
      final data = candles([100, 104, 99]);
      final bricks = CandleTransforms.renko(data, brickSize: 2);

      expect(bricks.map((b) => b.close).toList(), [102, 104, 100]);
      expect(bricks.last.open, 102);
    });

    test('every brick has a time of its own', () {
      final data = candles([100, 110]);
      final bricks = CandleTransforms.renko(data, brickSize: 2);

      expect(bricks.length, greaterThan(1));
      final times = bricks.map((b) => b.dateTime).toSet();
      expect(times, hasLength(bricks.length));
    });

    test('carries the volume of the candles a brick covers', () {
      final data = [
        candle(100, vol: 5, minute: 0),
        candle(100.5, vol: 7, minute: 1),
        candle(102, vol: 3, minute: 2),
      ];

      final bricks = CandleTransforms.renko(data, brickSize: 2);

      expect(bricks, hasLength(1));
      expect(bricks.single.vol, 15);
    });

    test('a non-positive brick size lays nothing', () {
      expect(CandleTransforms.renko(candles([1, 2, 3]), brickSize: 0), isEmpty);
      expect(
        CandleTransforms.renko(candles([1, 2, 3]), brickSize: -1),
        isEmpty,
      );
    });

    test('the chart draws bricks like any other candles', () async {
      final data = candles(rampThenFall(60));
      final bricks = CandleTransforms.renko(data, brickSize: 1);
      DataUtil.calculate(bricks);

      expect(bricks, isNotEmpty);
    });
  });

  group('atrBrickSize', () {
    test('sizes a brick from the market', () {
      final size = CandleTransforms.atrBrickSize(candles(rampThenFall(40)));

      expect(size, isNotNull);
      expect(size, greaterThan(0));
    });

    test('is null without enough data', () {
      expect(CandleTransforms.atrBrickSize(candles([1, 2])), isNull);
      expect(
        CandleTransforms.atrBrickSize(candles(rampThenFall(40)), period: 0),
        isNull,
      );
    });

    test('is null for a market that never moves', () {
      final flat = [
        for (var i = 0; i < 30; i++)
          KLineEntity.fromCustom(
            open: 10,
            high: 10,
            low: 10,
            close: 10,
            vol: 1,
            dateTime: DateTime.utc(2024).add(Duration(minutes: i)),
          ),
      ];

      expect(CandleTransforms.atrBrickSize(flat), isNull);
    });
  });
}
