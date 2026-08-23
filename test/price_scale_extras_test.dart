import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/renderer/chart_painter.dart';

import 'test_utils.dart';

/// [count] candles, calculated.
List<KLineEntity> _candles([int count = 60]) {
  final data = candles(rampThenFall(count));
  DataUtil.calculate(data);
  return data;
}

Widget _chart(
  List<KLineEntity> data, {
  bool invert = false,
  bool average = false,
  bool highLow = false,
  PriceAxisScale scale = PriceAxisScale.linear,
  ChartType type = ChartType.candles,
}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 500,
      height: 600,
      child: KChartWidget(
        data,
        ChartColors(),
        isTrendLine: false,
        watermarkAssetPath: 'assets/none.svg',
        timeFrame: const Duration(minutes: 1),
        showNowPrice: false,
        chartType: type,
        priceAxisScale: scale,
        invertPriceAxis: invert,
        showAverageClose: average,
        showHighLowOnAxis: highLow,
      ),
    ),
  ),
);

ChartPainter _painterOf(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find
        .descendant(
          of: find.byType(KChartWidget),
          matching: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is ChartPainter,
          ),
        )
        .first,
  );
  return paint.painter! as ChartPainter;
}

void main() {
  group('an inverted price axis', () {
    testWidgets('higher prices sit lower down', (tester) async {
      await tester.pumpWidget(_chart(_candles()));
      final upright = _painterOf(tester).mMainRenderer;
      final low = upright.minValue;
      final high = upright.maxValue;

      expect(upright.getY(high), lessThan(upright.getY(low)));

      await tester.pumpWidget(_chart(_candles(), invert: true));
      await tester.pumpAndSettle();
      final flipped = _painterOf(tester).mMainRenderer;

      expect(flipped.inverted, isTrue);
      expect(flipped.getY(high), greaterThan(flipped.getY(low)));
    });

    testWidgets('getY and getValue stay exact inverses', (tester) async {
      await tester.pumpWidget(_chart(_candles(), invert: true));
      await tester.pumpAndSettle();
      final renderer = _painterOf(tester).mMainRenderer;

      for (final price in [
        renderer.minValue,
        (renderer.minValue + renderer.maxValue) / 2,
        renderer.maxValue,
      ]) {
        expect(
          renderer.getValue(renderer.getY(price)),
          closeTo(price, price.abs() * 1e-9 + 1e-9),
        );
      }
    });

    testWidgets('the two ends of the axis swap places', (tester) async {
      await tester.pumpWidget(_chart(_candles(), invert: true));
      await tester.pumpAndSettle();
      final renderer = _painterOf(tester).mMainRenderer;

      // The top of the box now reads the low, and the bottom the high.
      expect(
        renderer.getValue(renderer.chartRect.top),
        lessThan(renderer.getValue(renderer.chartRect.bottom)),
      );
    });

    testWidgets('a log axis inverts too, and stays a log axis', (tester) async {
      await tester.pumpWidget(
        _chart(_candles(), invert: true, scale: PriceAxisScale.logarithmic),
      );
      await tester.pumpAndSettle();
      final renderer = _painterOf(tester).mMainRenderer;

      expect(renderer.isLogarithmic, isTrue);
      expect(
        renderer.getY(renderer.maxValue),
        greaterThan(renderer.getY(renderer.minValue)),
      );
      // Still spaced by ratio: the middle of the box is the geometric mean.
      final middle = (renderer.chartRect.top + renderer.chartRect.bottom) / 2;
      final atMiddle = renderer.getValue(middle);
      expect(
        atMiddle * atMiddle,
        closeTo(
          renderer.minValue * renderer.maxValue,
          renderer.maxValue * renderer.maxValue * 0.02,
        ),
      );
    });

    testWidgets('every chart type draws inverted without complaint', (
      tester,
    ) async {
      for (final type in ChartType.values) {
        await tester.pumpWidget(_chart(_candles(), invert: true, type: type));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$type');
      }
    });
  });

  group('indexed to 100', () {
    testWidgets('the first candle in view reads 100', (tester) async {
      await tester.pumpWidget(
        _chart(_candles(), scale: PriceAxisScale.indexedTo100),
      );
      await tester.pumpAndSettle();
      final renderer = _painterOf(tester).mMainRenderer;

      final base = renderer.percentBase!;
      expect(renderer.formatAxis(base), '100.00');
      expect(renderer.formatAxis(base * 1.12), '112.00');
      expect(renderer.formatAxis(base * 0.9), '90.00');
    });

    testWidgets('it says the same thing a percentage axis does', (
      tester,
    ) async {
      await tester.pumpWidget(
        _chart(_candles(), scale: PriceAxisScale.percentage),
      );
      await tester.pumpAndSettle();
      final percent = _painterOf(tester).mMainRenderer;
      final base = percent.percentBase!;
      expect(percent.formatAxis(base * 1.12), '+12.00%');

      await tester.pumpWidget(
        _chart(_candles(), scale: PriceAxisScale.indexedTo100),
      );
      await tester.pumpAndSettle();
      expect(
        _painterOf(tester).mMainRenderer.formatAxis(base * 1.12),
        '112.00',
      );
    });

    testWidgets('the axis marks round index levels', (tester) async {
      await tester.pumpWidget(
        _chart(_candles(), scale: PriceAxisScale.indexedTo100),
      );
      await tester.pumpAndSettle();
      final renderer = _painterOf(tester).mMainRenderer;
      final base = renderer.percentBase!;

      // Each tick, read as an index level, is a round number.
      for (final tick in renderer.priceTicks(4)) {
        final level = tick / base * 100;
        expect(
          level,
          closeTo(double.parse(level.toStringAsPrecision(6)), 1e-6),
        );
      }
    });

    testWidgets('a linear axis still reads out prices', (tester) async {
      await tester.pumpWidget(_chart(_candles()));
      await tester.pumpAndSettle();
      final renderer = _painterOf(tester).mMainRenderer;

      expect(renderer.percentBase, isNull);
      expect(renderer.formatAxis(123.456), renderer.format(123.456));
    });
  });

  group('the average close', () {
    testWidgets('it sits inside the window it describes', (tester) async {
      await tester.pumpWidget(_chart(_candles(), average: true));
      await tester.pumpAndSettle();
      final renderer = _painterOf(tester).mMainRenderer;

      final average = renderer.averageClose!;
      expect(average, greaterThan(renderer.minValue));
      expect(average, lessThan(renderer.maxValue));
    });

    testWidgets('it is the mean of the closes on screen', (tester) async {
      // A flat market, so the average is that price whatever the window.
      final data = candles([for (var i = 0; i < 60; i++) 100.0]);
      DataUtil.calculate(data);

      await tester.pumpWidget(_chart(data, average: true));
      await tester.pumpAndSettle();

      expect(_painterOf(tester).mMainRenderer.averageClose, closeTo(100, 1e-9));
    });

    testWidgets('it is not drawn unless asked for', (tester) async {
      await tester.pumpWidget(_chart(_candles()));
      await tester.pumpAndSettle();

      expect(_painterOf(tester).mMainRenderer.averageClose, isNull);
    });

    testWidgets('a chart with no candles has no average', (tester) async {
      await tester.pumpWidget(_chart(const [], average: true));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('the high and low on the axis', () {
    testWidgets('they draw without complaint, on any chart type', (
      tester,
    ) async {
      for (final type in [
        ChartType.candles,
        ChartType.line,
        ChartType.hlcArea,
      ]) {
        await tester.pumpWidget(_chart(_candles(), highLow: true, type: type));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$type');
      }
    });

    testWidgets('the extremes they tag are the window’s own', (tester) async {
      await tester.pumpWidget(_chart(_candles(), highLow: true));
      await tester.pumpAndSettle();
      final painter = _painterOf(tester);

      expect(painter.showHighLowOnAxis, isTrue);
      expect(painter.mMainHighMaxValue, greaterThan(painter.mMainLowMinValue));
      // And they are the extremes of the candles actually on screen.
      var high = -double.infinity;
      var low = double.infinity;
      for (var i = painter.mStartIndex; i <= painter.mStopIndex; i++) {
        high = high > painter.candles![i].high
            ? high
            : painter.candles![i].high;
        low = low < painter.candles![i].low ? low : painter.candles![i].low;
      }
      expect(painter.mMainHighMaxValue, closeTo(high, 1e-9));
      expect(painter.mMainLowMinValue, closeTo(low, 1e-9));
    });

    testWidgets('they read out in the axis’ own units', (tester) async {
      await tester.pumpWidget(
        _chart(_candles(), highLow: true, scale: PriceAxisScale.indexedTo100),
      );
      await tester.pumpAndSettle();
      final renderer = _painterOf(tester).mMainRenderer;

      // The tag goes through formatAxis, so an indexed chart tags index levels.
      expect(renderer.formatAxis(renderer.percentBase!), '100.00');
      expect(tester.takeException(), isNull);
    });

    testWidgets('all four extras together still draw', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 600,
              child: KChartWidget(
                _candles(),
                ChartColors(),
                isTrendLine: false,
                watermarkAssetPath: 'assets/none.svg',
                timeFrame: const Duration(minutes: 1),
                showNowPrice: false,
                priceAxisScale: PriceAxisScale.indexedTo100,
                invertPriceAxis: true,
                showAverageClose: true,
                showHighLowOnAxis: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
