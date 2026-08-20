import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/renderer/chart_painter.dart';
import 'package:ohlcv_chart/src/renderer/main_renderer.dart';

import 'test_utils.dart';

const _rect = Rect.fromLTRB(0, 20, 400, 320);

MainRenderer _renderer({
  required double max,
  required double min,
  PriceAxisScale scale = PriceAxisScale.linear,
  double? percentBase,
}) => MainRenderer(
  _rect,
  max,
  min,
  20,
  const [],
  false,
  2,
  const ChartStyle(),
  ChartColors(),
  1,
  VerticalTextAlignment.left,
  false,
  priceScale: scale,
  percentBase: percentBase,
);

Widget _chart({
  PriceAxisScale scale = PriceAxisScale.linear,
  List<double>? closes,
}) {
  final data = candles(closes ?? rampThenFall(60));
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
          watermarkAssetPath: 'assets/none.svg',
          timeFrame: const Duration(minutes: 15),
          priceAxisScale: scale,
        ),
      ),
    ),
  );
}

ChartPainter _painterOf(WidgetTester tester) {
  final dynamic state = tester.state(find.byType(KChartWidget));
  // ignore: avoid_dynamic_calls
  return state.painter as ChartPainter;
}

void main() {
  group('linear axis', () {
    test('maps the range onto the content area', () {
      final renderer = _renderer(max: 200, min: 100);

      // The content area is inset by 5 at each end.
      expect(renderer.getY(200), closeTo(_rect.top + 5, 1e-9));
      expect(renderer.getY(100), closeTo(_rect.bottom - 5, 1e-9));
      expect(renderer.getY(150), closeTo((_rect.top + _rect.bottom) / 2, 1e-9));
    });

    test('getValue is the exact inverse of getY', () {
      final renderer = _renderer(max: 200, min: 100);

      for (final price in [100.0, 123.45, 150.0, 200.0]) {
        expect(renderer.getValue(renderer.getY(price)), closeTo(price, 1e-9));
      }
    });
  });

  group('logarithmic axis', () {
    test('gives equal ratios equal space', () {
      final renderer = _renderer(
        max: 1000,
        min: 10,
        scale: PriceAxisScale.logarithmic,
      );

      // 10 → 100 and 100 → 1000 are both tenfold, so they take the same room.
      final top = renderer.getY(1000);
      final middle = renderer.getY(100);
      final bottom = renderer.getY(10);

      expect(middle - top, closeTo(bottom - middle, 1e-6));
      expect(middle, closeTo((top + bottom) / 2, 1e-6));
    });

    test('the geometric mean lands in the middle', () {
      final renderer = _renderer(
        max: 400,
        min: 100,
        scale: PriceAxisScale.logarithmic,
      );

      expect(
        renderer.getY(math.sqrt(400 * 100)),
        closeTo((_rect.top + 5 + _rect.bottom - 5) / 2, 1e-6),
      );
    });

    test('getValue is the exact inverse of getY', () {
      final renderer = _renderer(
        max: 1000,
        min: 10,
        scale: PriceAxisScale.logarithmic,
      );

      for (final price in [10.0, 42.0, 100.0, 999.0]) {
        expect(renderer.getValue(renderer.getY(price)), closeTo(price, 1e-6));
      }
    });

    test('a window holding zero falls back to a linear axis', () {
      final renderer = _renderer(
        max: 100,
        min: 0,
        scale: PriceAxisScale.logarithmic,
      );

      expect(renderer.isLogarithmic, isFalse);
      expect(renderer.getY(50), closeTo((_rect.top + _rect.bottom) / 2, 1e-9));
    });

    test('a negative low falls back too', () {
      final renderer = _renderer(
        max: 10,
        min: -10,
        scale: PriceAxisScale.logarithmic,
      );

      expect(renderer.isLogarithmic, isFalse);
      expect(renderer.getValue(renderer.getY(-3)), closeTo(-3, 1e-9));
    });
  });

  group('percentage axis', () {
    test('reads out the move away from the base', () {
      final renderer = _renderer(
        max: 200,
        min: 100,
        scale: PriceAxisScale.percentage,
        percentBase: 100,
      );

      expect(renderer.formatAxis(100), '+0.00%');
      expect(renderer.formatAxis(150), '+50.00%');
      expect(renderer.formatAxis(90), '-10.00%');
    });

    test('is spaced like a linear axis', () {
      final linear = _renderer(max: 200, min: 100);
      final percent = _renderer(
        max: 200,
        min: 100,
        scale: PriceAxisScale.percentage,
        percentBase: 100,
      );

      expect(percent.getY(150), closeTo(linear.getY(150), 1e-9));
    });

    test('falls back to prices with no base to measure from', () {
      final renderer = _renderer(
        max: 200,
        min: 100,
        scale: PriceAxisScale.percentage,
      );

      expect(renderer.formatAxis(150), '150.00');
    });
  });

  group('the chart', () {
    testWidgets('draws every axis without blowing up', (tester) async {
      for (final scale in PriceAxisScale.values) {
        await tester.pumpWidget(_chart(scale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('a logarithmic axis still places a price where it belongs', (
      tester,
    ) async {
      // A tenfold range: linear spacing and ratio spacing disagree sharply.
      final closes = [for (var i = 0; i < 40; i++) 10.0 * math.pow(1.06, i)];
      await tester.pumpWidget(
        _chart(scale: PriceAxisScale.logarithmic, closes: closes),
      );
      await tester.pumpAndSettle();

      final painter = _painterOf(tester);
      final price = 40.0;
      expect(
        painter.calculatePrice(painter.getMainY(price)),
        closeTo(price, 1e-6),
      );
    });

    testWidgets('a percentage axis reports percentages to the crosshair', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(scale: PriceAxisScale.percentage));
      await tester.pumpAndSettle();

      final painter = _painterOf(tester);
      expect(
        painter.mMainRenderer.formatAxis(painter.mMainMaxValue),
        endsWith('%'),
      );
    });
  });
}
